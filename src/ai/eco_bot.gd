extends RefCounted
## A scripted economy player: keeps the Town Center training workers, splits
## them between resources by a mix per age (60/40 food/wood to start; gold and stone later), puts idle workers back to work and builds houses
## before pop runs out. It only reads sim state and issues commands through the
## queue, like a person would, so it's deterministic. This is the seed of the
## milestone 8 AI.

const Economy := preload("res://src/sim/economy.gd")
const Commands := preload("res://src/sim/commands.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const Tech := preload("res://src/sim/tech.gd")
const Reach := preload("res://src/ai/reach.gd")
const Pens := preload("res://src/sim/pens.gd")
const Garrison := preload("res://src/sim/garrison.gd")

const THINK_EVERY := 20        # ticks (1 s)
var MIX := {1: {"food": 60, "wood": 40}}   # age -> share of workers per resource (data/ai.json when a full bot runs this)
var MAX_WORKERS := 30
const TRAIN_COOLDOWN := 20     # ticks between train orders (commands land two turns later)
const HOUSE_COOLDOWN := 200
const HOUSE_HEADROOM := 2      # build a house when free pop drops to this
const FARM_RADIUS := 10        # tiles from the Town Center that count as home for wild food
const WILD_PER_WORKER := 150   # wild food near home that keeps one food worker off the farms
const FARM_BELOW := 400        # new farms only while the food stock is below this
const PLENTY := 1000           # a stock this big takes no new gatherers while another resource is wanted
const HUNT_RADIUS := 16        # tiles from the Town Center the bot claims sheep and hunts in
const CLAIM_COOLDOWN := 200    # ticks between errands to claim a sheep
const MEAT_LEFT := 40          # a carcass down to this much: time to bring down the next animal
const HUNT_PARTY := {"herd": 3, "flee": 3, "fight": 8}      # hunters sent, by animal behaviour: sheep, deer, boar
const HUNT_WORKERS := {"herd": 0, "flee": 8, "fight": 12}   # workers we need before hunting each
const PEN_SHEEP := 3           # sheep of ours near home worth a pen for: build one in age 1 (the first are slaughtered meanwhile)
const BOAR_SOLDIERS := 3       # idle soldiers at home that join a boar party (they lead; workers make up the rest)
const BOAR_LEAD := 2           # no boar hunt without at least this many of them
var AGE_WORKERS := 16          # with this many workers, stop training and save for the next age
var REBALANCE := 0             # ticks between moving one gatherer from a resource we have enough of to one we're short of (0: never)
const GOAL_SPARE := 100        # a resource counts as saved up once its stock is this much over the goal

var player: int
var _next_train := 0
var _next_house := 0
var _next_claim := 0
var _ordered := {}             # unit ids given an order this think (later orders leave them be)
var reach := Reach.new()       # where our workers can walk to (no sending them at a walled-off ford)
var wln := 0                   # our workers' lane (movement class and team)
var home := 0                  # the area round our Town Center (Reach); 0 until the first think
var held := {}                 # worker id -> tick: kept out of the way until then (the bot pulled it from a fight)
var goal := PackedInt32Array() # what we're saving for (the next age, a Castle): set by the full bot; empty: nothing
var push := 100                # how hard the shares lean to the goal: a hundred shares split by what it lacks (100: the rest halved too)
var _next_rebalance := 0


func _init(p_player: int) -> void:
	player = p_player


func think(w) -> void:
	if w.tick % THINK_EVERY != 0:
		return
	var tc := _town_center(w)
	if tc < 0:
		return
	var bs = w.buildings
	wln = w.lane_base[player] + Economy.builder_class(w, player)
	home = reach.area_at(w, wln, bs.cx[tc] * 1000 + bs.sx[tc] * 500, bs.cy[tc] * 1000 + bs.sy[tc] * 500)
	var workers := []
	var n := PackedInt32Array()   # workers on each resource (by resource index)
	n.resize(w.resources.size())
	var idle := []
	for i in w.units.count():
		if w.units.owner[i] != player or not w.types[w.units.kind[i]].worker:
			continue
		workers.append(i)
		match w.units.task[i]:
			Economy.GATHER, Economy.RETURN:
				if w.units.carry_kind[i] > 0:
					n[w.units.carry_kind[i] - 1] += 1
			Economy.NONE:
				if w.units.foe[i] != 0:
					n[Economy.kind_of(w, "food") - 1] += 1   # hunting: food on the hoof
				elif w.units.moving[i] == 0 and int(held.get(w.units.id[i], 0)) <= w.tick:
					idle.append(i)
	var count: int = workers.size() + sheltered(w)   # (workers sheltering from a raid still count)
	# Idle hands: back to work on whatever we're shortest of, that they can get to.
	for i in idle:
		var area := reach.area_of_unit(w, i)
		var kind := _short_of(w, n, w.units.x[i], w.units.y[i], area)
		if kind > 0:
			w.issue(player, Commands.GATHER, {"ids": [w.units.id[i]], "cell": _nearest_resource(w, w.units.x[i], w.units.y[i], kind, true, area)})
			n[kind - 1] += 1
	# New workers go where we're short.
	var rally_kind := _short_of(w, n, bs.cx[tc] * 1000 + 1500, bs.cy[tc] * 1000 + 1500)
	var rally := _nearest_resource(w, bs.cx[tc] * 1000 + 1500, bs.cy[tc] * 1000 + 1500, rally_kind, true) if rally_kind > 0 else -1
	if rally >= 0 and w.map.cell_of(bs.rally_x[tc], bs.rally_y[tc]) != rally:
		w.issue(player, Commands.RALLY, {"building": bs.id[tc], "x": (rally % w.map.width) * 1000 + 500, "y": (rally / w.map.width) * 1000 + 500})
	# Meat first (the orders below then leave these hunters be), and no foundation left alone.
	_ordered.clear()
	for i in workers:
		if int(held.get(w.units.id[i], 0)) > w.tick:
			_ordered[w.units.id[i]] = true   # pulled from a fight: not a builder or a hunter for now
	_herd(w, tc, workers)
	_pen(w, tc, workers)
	_hunt(w, tc, workers)
	_finish_foundations(w, workers)
	_rebalance(w, workers, n)
	# Age up: with enough workers, save up and click it.
	var saving: bool = w.ages[player] == 1 and count >= AGE_WORKERS
	if saving and not Tech.has_building(w, player, "barracks") and not _building_underway(w):
		var bk: int = Economy.btype_of(w, "barracks")
		if w.can_afford(player, w.btypes[bk].cost):
			var spot := _house_spot(w, bs.cx[tc] + 1, bs.cy[tc] + 1, w.btypes[bk].size)
			var builders := workers.filter(func(i): return not _ordered.has(w.units.id[i])).slice(0, 3).map(func(i): return w.units.id[i])
			if spot.x >= 0:
				w.issue(player, Commands.BUILD, {"ids": builders, "building": "barracks", "cx": spot.x, "cy": spot.y})
				_next_house = w.tick + HOUSE_COOLDOWN
	if saving and Tech.why_not(w, player, tc, "") == "":
		w.issue(player, Commands.AGE_UP, {"building": bs.id[tc]})
	# Keep the Town Center busy.
	var worker_type: int = w.type_of(player, "worker")
	var t: Dictionary = w.types[worker_type]
	if not saving and w.tick >= _next_train and bs.queue[tc].size() < 2 and count + bs.queue[tc].size() < MAX_WORKERS \
			and w.can_afford(player, t.cost):
		w.issue(player, Commands.TRAIN, {"building": bs.id[tc], "slot": "worker"})
		_next_train = w.tick + TRAIN_COOLDOWN
	# A house before we're stuck.
	var house: int = Economy.btype_of(w, "house")
	var queued_pop: int = bs.queue[tc].filter(func(e): return e >= 0).size() * t.pop   # units, not the age-up
	if w.tick >= _next_house and w.pop_cap[player] < int(w.econ.pop_max) \
			and w.pop[player] + queued_pop + HOUSE_HEADROOM >= w.pop_cap[player] \
			and w.can_afford(player, w.btypes[house].cost) \
			and not _building_underway(w):
		var builder := _pick_builder(w, workers)
		var spot := _house_spot(w, bs.cx[tc] + 1, bs.cy[tc] + 1, w.btypes[house].size)
		if builder >= 0 and spot.x >= 0:
			w.issue(player, Commands.BUILD, {"ids": [w.units.id[builder]], "building": "house", "cx": spot.x, "cy": spot.y})
			_next_house = w.tick + HOUSE_COOLDOWN
	_farms(w, tc, workers, n)


## A foundation of ours nobody is building (its builder was called away by an order that
## landed later): the nearest free worker goes to finish it, or every later building waits.
func _finish_foundations(w, workers: Array) -> void:
	var u = w.units
	var bs = w.buildings
	for b in bs.count():
		if bs.owner[b] != player or bs.done[b] == 1:
			continue
		var bid: int = bs.id[b]
		if workers.any(func(i): return u.task[i] == Economy.BUILD and u.target[i] == bid):
			continue
		var x: int = bs.cx[b] * 1000 + bs.sx[b] * 500
		var y: int = bs.cy[b] * 1000 + bs.sy[b] * 500
		var best := -1
		var best_d2 := 1 << 62
		for i in workers:
			if _ordered.has(u.id[i]) or u.foe[i] != 0 or u.task[i] == Economy.BUILD \
					or not reach.reaches_building(w, wln, reach.area_of_unit(w, i), b):
				continue   # (a foundation nobody can get to waits; nobody queues at the wall)
			var d2 := Fixed.dist2(x, y, u.x[i], u.y[i])
			if d2 < best_d2:
				best_d2 = d2
				best = i
		if best >= 0:
			w.issue(player, Commands.HELP_BUILD, {"ids": [u.id[best]], "target": bid})
			_ordered[u.id[best]] = true


## Sheep nobody owns near home: the nearest food gatherer walks over to claim one (a claimed
## sheep walks to our Town Center on its own). One errand at a time.
func _herd(w, tc: int, workers: Array) -> void:
	if w.tick < _next_claim:
		return
	var u = w.units
	var hx: int = w.buildings.cx[tc] * 1000 + 1500
	var hy: int = w.buildings.cy[tc] * 1000 + 1500
	var sheep := -1
	var best_d2 := HUNT_RADIUS * HUNT_RADIUS * 1000000
	for i in u.count():
		if u.owner[i] != w.gaia or w.types[u.kind[i]].get("behaviour", "") != "herd" or reach.area_at(w, wln, u.x[i], u.y[i]) != home:
			continue
		var d2 := Fixed.dist2(hx, hy, u.x[i], u.y[i])
		if d2 < best_d2:
			best_d2 = d2
			sheep = i
	if sheep < 0:
		return
	var party := _nearest_food_workers(w, workers, u.x[sheep], u.y[sheep], 1)
	if not party.is_empty():
		w.issue(player, Commands.MOVE, {"ids": party, "x": u.x[sheep], "y": u.y[sheep]})
		_ordered[party[0]] = true
		_next_claim = w.tick + CLAIM_COOLDOWN


## Sheep for the long run (Dominic: penned, they feed you slowly instead of once): with
## PEN_SHEEP or more of ours near home in age 1 (claimed faster than we slaughter them: the first
## ones still feed the early game) and no pen, build one; once it stands, our sheep
## outside it go in (while it has room). A bot with a pen doesn't slaughter its sheep (_hunt).
func _pen(w, tc: int, workers: Array) -> void:
	var u = w.units
	var bs = w.buildings
	var pen := -1
	for b in bs.count():
		if pen < 0 and bs.owner[b] == player and Pens.is_pen(w, b):
			pen = b
	if pen < 0:
		var hx: int = bs.cx[tc] * 1000 + 1500
		var hy: int = bs.cy[tc] * 1000 + 1500
		var near := 0
		for i in u.count():
			if u.owner[i] == player and w.types[u.kind[i]].get("behaviour", "") == "herd" \
					and Fixed.dist2(hx, hy, u.x[i], u.y[i]) <= HUNT_RADIUS * HUNT_RADIUS * 1000000:
				near += 1
		var k: int = Economy.btype_of(w, "pen")
		var ageing: bool = push >= 100 and not goal.is_empty()   # (its wood waits while the full bot saves for the age)
		if w.ages[player] <= 2 and not ageing and near >= PEN_SHEEP and w.can_afford(player, w.btypes[k].cost) and not _building_underway(w):
			var builder := _pick_builder(w, workers)
			var spot := _house_spot(w, bs.cx[tc] + 1, bs.cy[tc] + 1, w.btypes[k].size)
			if builder >= 0 and spot.x >= 0:
				w.issue(player, Commands.BUILD, {"ids": [u.id[builder]], "building": "pen", "cx": spot.x, "cy": spot.y})
				_ordered[u.id[builder]] = true
		return
	if bs.done[pen] == 0:
		return
	var heading: Array = Pens.animals(w, pen)
	var out := []
	for i in u.count():
		if u.owner[i] == player and w.types[u.kind[i]].get("behaviour", "") == "herd" and Pens.pen_at(w, i) < 0 and not heading.has(i):
			out.append(u.id[i])
	if not out.is_empty() and Pens.room(w, pen):
		w.issue(player, Commands.PEN, {"ids": out, "building": bs.id[pen]})


## Do we have a pen (built or going up)?
func _has_pen(w) -> bool:
	for b in w.buildings.count():
		if w.buildings.owner[b] == player and Pens.is_pen(w, b):
			return true
	return false


## Hunting, one animal at a time while nothing else is being hunted or butchered: our own
## sheep first (they wait by the Town Center), then deer near home once there are a few
## workers, then boar (they fight back) only with a big party, soldiers joining if any are idle
## at home (it still gores a worker or two: 320 food is worth it). The hunters gather the carcass
## themselves (animals.gd); meat near home that nobody gathers gets workers sent to it.
func _hunt(w, tc: int, workers: Array) -> void:
	var u = w.units
	var m = w.map
	for i in u.count():
		if u.owner[i] == player and u.foe[i] != 0:
			var j: int = u.index_of(u.foe[i])
			if j >= 0 and w.types[u.kind[j]].has("animal"):
				return   # a hunt is on
	var hx: int = w.buildings.cx[tc] * 1000 + 1500
	var hy: int = w.buildings.cy[tc] * 1000 + 1500
	var near := FARM_RADIUS * FARM_RADIUS * 1000000
	for c in m.resource_cells:   # meat near home nobody's gathering (soldiers brought it down): butcher it
		if m.terrain_ids[m.terrain[c]] != "carcass" or m.amount[c] <= MEAT_LEFT \
				or Fixed.dist2(hx, hy, (c % m.width) * 1000 + 500, (c / m.width) * 1000 + 500) > near or not reach.reaches_cell(w, wln, home, c):
			continue
		if workers.any(func(i): return u.home[i] == c and (u.task[i] == Economy.GATHER or u.task[i] == Economy.RETURN)):
			continue
		var cooks := _nearest_food_workers(w, workers, (c % m.width) * 1000 + 500, (c / m.width) * 1000 + 500, HUNT_PARTY.fight)
		if not cooks.is_empty():
			w.issue(player, Commands.GATHER, {"ids": cooks, "cell": c})
			for id in cooks:
				_ordered[id] = true
		return
	for i in workers:
		var h: int = u.home[i]
		if (u.task[i] == Economy.GATHER or u.task[i] == Economy.RETURN) and h >= 0 \
				and m.terrain_ids[m.terrain[h]] == "carcass" and m.amount[h] > MEAT_LEFT \
				and Fixed.dist2(hx, hy, (h % m.width) * 1000 + 500, (h / m.width) * 1000 + 500) <= near:
			return   # still butchering the last one by home (a deer that died far off is its hunters' job)
	var guards := []   # idle soldiers at home: they join a boar hunt (it fights back)
	for i in u.count():
		if u.owner[i] == player and not w.types[u.kind[i]].worker and not w.types[u.kind[i]].has("animal") \
				and not w.types[u.kind[i]].healer and u.foe[i] == 0 and u.moving[i] == 0 and Fixed.dist2(hx, hy, u.x[i], u.y[i]) <= near:
			guards.append(u.id[i])
	var target := -1
	var penning := _has_pen(w)
	for want in ["herd", "flee", "fight"]:   # sheep, deer, boar
		if workers.size() < HUNT_WORKERS[want] or (want == "herd" and penning):
			continue   # (sheep with a pen to go to are kept)
		if want == "fight" and guards.size() < BOAR_LEAD:
			continue   # a boar gores workers that take it on alone (seven in one hunt): soldiers lead
		var best_d2 := HUNT_RADIUS * HUNT_RADIUS * 1000000
		for i in u.count():
			var t: Dictionary = w.types[u.kind[i]]
			var mine: bool = u.owner[i] == player and want == "herd"
			var wild: bool = u.owner[i] == w.gaia and want != "herd"
			if not (mine or wild) or t.get("behaviour", "") != want or reach.area_at(w, wln, u.x[i], u.y[i]) != home:
				continue
			var d2 := Fixed.dist2(hx, hy, u.x[i], u.y[i])
			if d2 < best_d2:
				best_d2 = d2
				target = i
		if target >= 0:
			break
	if target < 0:
		return
	var want: String = w.types[u.kind[target]].behaviour
	# A boar fights back: a big party, idle soldiers at home first, workers making up the rest.
	var ids: Array = guards.slice(0, BOAR_SOLDIERS) if want == "fight" else []
	ids.append_array(_nearest_food_workers(w, workers, u.x[target], u.y[target], HUNT_PARTY[want] - ids.size()))
	if not ids.is_empty():
		w.issue(player, Commands.ATTACK, {"ids": ids, "target": u.id[target]})
		for id in ids:
			_ordered[id] = true


## Up to `count` ids of food gatherers (or idle workers) nearest a point; ties go to the lower id.
func _nearest_food_workers(w, workers: Array, x: int, y: int, count: int) -> Array:
	var u = w.units
	var food: int = Economy.kind_of(w, "food")
	var pool := []
	for i in workers:
		var gathering: bool = (u.task[i] == Economy.GATHER or u.task[i] == Economy.RETURN) and u.carry_kind[i] == food
		var idle: bool = u.task[i] == Economy.NONE and u.foe[i] == 0
		if (gathering or idle) and not _ordered.has(u.id[i]):
			pool.append([Fixed.dist2(x, y, u.x[i], u.y[i]), u.id[i]])
	pool.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))   # nearest, then lower id
	return pool.slice(0, count).map(func(e): return e[1])


## Farms: as the wild food near home runs out, a farm for each food worker it no longer
## feeds (one farmer per farm); worked-out farms reseeded (the idle hands then pick them up
## as the nearest food). A food worker waiting by a full farm builds the next one, so it
## becomes that farm's farmer.
func _farms(w, tc: int, workers: Array, n: PackedInt32Array) -> void:
	var bs = w.buildings
	var food: int = Economy.kind_of(w, "food")
	var fk: int = Economy.btype_of(w, "farm")
	var ft: Dictionary = w.btypes[fk]
	var farms := 0
	for b in bs.count():
		if bs.owner[b] != player or bs.kind[b] != fk:
			continue
		farms += 1
		if bs.done[b] == 1 and w.map.left_at(bs.cy[b] * w.map.width + bs.cx[b]) <= 0 and w.can_afford(player, ft.reseed):
			w.issue(player, Commands.RESEED, {"ids": [], "building": bs.id[b]})
	var hx: int = bs.cx[tc] * 1000 + 1500
	var hy: int = bs.cy[tc] * 1000 + 1500
	var wild := 0
	for c in w.map.resource_cells:
		if w.map.pool[c] >= 0 or w.map.amount[c] <= 0 or Economy.kind_of(w, w.map.resource_at(c)) != food:
			continue
		if Fixed.dist2(hx, hy, (c % w.map.width) * 1000 + 500, (c / w.map.width) * 1000 + 500) <= FARM_RADIUS * FARM_RADIUS * 1000000:
			wild += w.map.amount[c]
	for i in w.units.count():   # and the meat still walking about near home: our sheep, wild deer and boar
		var t: Dictionary = w.types[w.units.kind[i]]
		if t.has("animal") and (w.units.owner[i] == player or w.units.owner[i] == w.gaia) \
				and Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i]) <= HUNT_RADIUS * HUNT_RADIUS * 1000000:
			wild += int(t.food)
	# Farmers wanted: those on food now, or the share of workers food should have (with the wild
	# food gone, nobody gathers food and no farm would ever go up).
	var mix := shares(w)
	var total := 0
	for v in n:
		total += v
	var want: int = maxi(n[food - 1], mix[food - 1] * total / _sum(mix))
	if farms >= want - wild / WILD_PER_WORKER or w.stock[food - 1][player] >= FARM_BELOW or _farm_underway(w, fk) or not w.can_afford(player, ft.cost):
		return
	var builder := -1
	for i in workers:
		if w.units.task[i] == Economy.GATHER and w.units.home[i] < 0 and w.units.carry_kind[i] == food and not _ordered.has(w.units.id[i]):
			builder = i   # waiting for a farm: it builds its own
			break
	if builder < 0:
		builder = _pick_builder(w, workers)
	var spot := _house_spot(w, bs.cx[tc] + 1, bs.cy[tc] + 1, ft.size)
	if builder >= 0 and spot.x >= 0:
		w.issue(player, Commands.BUILD, {"ids": [w.units.id[builder]], "building": "farm", "cx": spot.x, "cy": spot.y})


## This age's mix as a share per resource index.
func _mix(w) -> PackedInt32Array:
	var mix: Dictionary = MIX[1]
	var keys := MIX.keys()
	keys.sort()
	for age in keys:
		if int(age) <= w.ages[player]:
			mix = MIX[age]
	var out := PackedInt32Array()
	for res in w.resources:
		out.append(int(mix.get(res, 0)))
	return out


## The share of workers we want on each resource (by resource index): this age's mix, plus, for
## the ones the goal still lacks, `push` more split by how much each lacks (so stone for a
## Castle comes in an age whose mix has little); with a full push (an age-up) the ones saved up
## for it are halved while another still falls short; none on a stock of PLENTY. With nothing
## left wanted, the plain mix.
func shares(w) -> PackedInt32Array:
	var base := _mix(w)
	var lack := 0   # all the goal still lacks
	for r in goal.size():
		lack += maxi(0, goal[r] - w.stock[r][player])
	var out := base.duplicate()
	var any := false
	for r in base.size():
		var s: int = w.stock[r][player]
		if r < goal.size() and s < goal[r]:
			out[r] = base[r] + push * (goal[r] - s) / lack
		elif lack > 0 and push >= 100 and (r >= goal.size() or s >= goal[r] + GOAL_SPARE):
			out[r] = base[r] / 2
		if s >= PLENTY:
			out[r] = 0
		any = any or out[r] > 0
	return out if any else base


## The resource (1-based kind) furthest below its share (shares) that has some left on the map
## (else by the plain mix), or 0. Ties go to the earlier resource.
func _short_of(w, n: PackedInt32Array, x: int, y: int, area := -1) -> int:
	for mix in [shares(w), _mix(w)]:
		var sum := _sum(mix)
		var total := 1
		for v in n:
			total += v
		var best := 0
		var best_gap := -(1 << 62)
		for r in w.resources.size():
			if mix[r] <= 0:
				continue
			var gap: int = mix[r] * total - n[r] * sum
			if gap > best_gap and _nearest_resource(w, x, y, r + 1, false, area) >= 0:
				best_gap = gap
				best = r + 1
		if best > 0:
			return best
	return 0


static func _sum(a: PackedInt32Array) -> int:
	var t := 0
	for v in a:
		t += v
	return maxi(1, t)


## Workers stay where they were sent, so when the shares change (a new age, a stock saved up, a
## pile grown) one gatherer moves every REBALANCE ticks: from the resource most over its share (by
## a worker or more) to the one most under it, the over-resource's gatherer nearest the other.
func _rebalance(w, workers: Array, n: PackedInt32Array) -> void:
	if REBALANCE <= 0 or w.tick < _next_rebalance:
		return
	_next_rebalance = w.tick + REBALANCE
	var mix := shares(w)
	var sum := _sum(mix)
	var total := 0
	for v in n:
		total += v
	var over := -1
	var most := 0
	var unders := []   # [how far under, resource], most under first
	for r in w.resources.size():
		var gap: int = n[r] * sum - mix[r] * total   # in workers, times sum
		if gap >= sum and gap > most:
			most = gap
			over = r
		if mix[r] > 0 and -gap >= sum:
			unders.append([-gap, r])
	unders.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	if over < 0 or unders.is_empty():
		return
	var u = w.units
	var tc := _town_center(w)
	var under := -1
	var to := -1
	for e in unders:   # the most under that has a patch free (food may wait for its farms)
		to = _nearest_resource(w, w.buildings.cx[tc] * 1000 + 1500, w.buildings.cy[tc] * 1000 + 1500, e[1] + 1, true)
		if to >= 0:
			under = e[1]
			break
	if to < 0:
		return
	var tx: int = (to % w.map.width) * 1000 + 500
	var ty: int = (to / w.map.width) * 1000 + 500
	var best := -1
	var best_d2 := 1 << 62
	for i in workers:
		if _ordered.has(u.id[i]) or u.carry_kind[i] != over + 1 or not (u.task[i] == Economy.GATHER or u.task[i] == Economy.RETURN):
			continue
		var d2 := Fixed.dist2(u.x[i], u.y[i], tx, ty)
		if d2 < best_d2:
			best_d2 = d2
			best = i
	if best < 0:
		return
	var cell := _nearest_resource(w, u.x[best], u.y[best], under + 1, true, reach.area_of_unit(w, best))
	if cell >= 0:
		w.issue(player, Commands.GATHER, {"ids": [u.id[best]], "cell": cell})
		_ordered[u.id[best]] = true


## Our workers sheltering inside buildings (out of the units arrays while a raid passes).
func sheltered(w) -> int:
	var n := 0
	for b in w.buildings.count():
		if w.buildings.owner[b] == player:
			for rec in w.buildings.inside[b]:
				if w.types[rec[Garrison.REC_KIND]].worker:
					n += 1
	return n


func _town_center(w) -> int:
	var tc_kind: int = Economy.btype_of(w, "town_center")
	for b in w.buildings.count():
		if w.buildings.owner[b] == player and w.buildings.kind[b] == tc_kind and w.buildings.done[b] == 1:
			return b
	return -1


## A foundation of ours waiting to be built, one our workers can get to (one cut off by a
## walled ford doesn't hold every later building back).
func _building_underway(w) -> bool:
	for b in w.buildings.count():
		if w.buildings.owner[b] == player and w.buildings.done[b] == 0 and reach.reaches_building(w, wln, home, b) \
				and not w.btypes[w.buildings.kind[b]].id in ["wonder", "farm"]:   # (a Wonder takes minutes: houses and the rest go on meanwhile; farms go up apart)
			return true
	return false


## A farm of ours going up (one at a time; other foundations don't hold farms back: a Castle
## takes minutes, and the farmers it waited for were starving the age).
func _farm_underway(w, fk: int) -> bool:
	for b in w.buildings.count():
		if w.buildings.owner[b] == player and w.buildings.kind[b] == fk and w.buildings.done[b] == 0:
			return true
	return false


## A wood gatherer (lowest id), else any worker.
func _pick_builder(w, workers: Array) -> int:
	var free := workers.filter(func(i): return not _ordered.has(w.units.id[i]))
	for i in free:
		if w.units.task[i] != Economy.BUILD and w.units.carry_kind[i] == 2:
			return i
	return free[0] if not free.is_empty() else -1


## Nearest cell with that resource left, anywhere on the map our workers in `area` can get to
## (-1: the home area; ties: lower cell). `free` passes over farms already worked by as many as they take.
func _nearest_resource(w, x: int, y: int, kind: int, free := false, area := -1) -> int:
	if area < 0:
		area = home
	var best := -1
	var best_d2 := 1 << 62
	for c in w.map.resource_cells:
		if w.map.amount[c] <= 0 or Economy.kind_of(w, w.map.resource_at(c)) != kind or (free and Economy.taken(w, c)):
			continue
		if not reach.reaches_cell(w, wln, area, c):
			continue
		var d2 := Fixed.dist2(x, y, (c % w.map.width) * 1000 + 500, (c / w.map.width) * 1000 + 500)
		if d2 < best_d2:
			best_d2 = d2
			best = c
	return best


## A free size x size spot with a tile of space around it, spiralling out from (cx, cy).
## A strict pass first (a clear margin round it and its neighbours off resources); if that finds
## nothing (forests and groves near home: the rats' barracks never went up on Reed Meadow), a
## looser, wider one that only keeps the building itself off resources.
func _house_spot(w, cx: int, cy: int, size: int) -> Vector2i:
	for strict in [true, false]:
		for r in range(3, 14 if strict else 22):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if maxi(absi(dx), absi(dy)) != r:
						continue
					var ok: bool = w.map.can_build(cx + dx - 1, cy + dy - 1, size + 2) if strict else w.map.can_build(cx + dx, cy + dy, size)
					if ok and (not strict or not _blocks_resource(w, cx + dx - 1, cy + dy - 1, size + 2)) \
							and reach.touches(w, wln, home, cx + dx, cy + dy, size, size) and not _seals(w, cx + dx, cy + dy, size):
						return Vector2i(cx + dx, cy + dy)
	return Vector2i(-1, -1)


## Would a building here shut a pocket off (its own houses, a forest and a cliff round a barracks
## whose soldiers then came out into a dead end and never left; workers shut in)? The walkable
## cells round the footprint must still join up, and reach out of a window SEAL_MARGIN tiles
## round it, without crossing the footprint (4-neighbour steps, as units move).
const SEAL_MARGIN := 5

func _seals(w, cx: int, cy: int, size: int) -> bool:
	var m = w.map
	var walk: PackedByteArray = m.walks[wln]
	var x0 := maxi(0, cx - SEAL_MARGIN)
	var y0 := maxi(0, cy - SEAL_MARGIN)
	var x1 := mini(m.width - 1, cx + size - 1 + SEAL_MARGIN)
	var y1 := mini(m.height - 1, cy + size - 1 + SEAL_MARGIN)
	var inside := func(x: int, y: int) -> bool: return x >= cx and y >= cy and x < cx + size and y < cy + size
	var ring := []
	for y in range(cy - 1, cy + size + 1):
		for x in range(cx - 1, cx + size + 1):
			if x < 0 or y < 0 or x >= m.width or y >= m.height or inside.call(x, y):
				continue
			if (x == cx - 1 or x == cx + size) and (y == cy - 1 or y == cy + size):
				continue   # corners: not a step from the footprint's sides
			if walk[y * m.width + x] == 1:
				ring.append(y * m.width + x)
	if ring.is_empty():
		return true
	var seen := {ring[0]: true}
	var queue := [ring[0]]
	var out := false   # reached the window's edge (the way on)
	var head := 0
	while head < queue.size():
		var c: int = queue[head]
		head += 1
		var x: int = c % m.width
		var y: int = c / m.width
		if x == x0 or y == y0 or x == x1 or y == y1:
			out = true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < x0 or ny < y0 or nx > x1 or ny > y1 or inside.call(nx, ny):
				continue
			var n: int = ny * m.width + nx
			if walk[n] == 1 and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return not out or ring.any(func(c): return not seen.has(c))


## Don't wall in a resource: keep the margin box clear of resource tiles' neighbours.
func _blocks_resource(w, x0: int, y0: int, n: int) -> bool:
	for y in range(y0 - 1, y0 + n + 1):
		for x in range(x0 - 1, x0 + n + 1):
			if x >= 0 and y >= 0 and x < w.map.width and y < w.map.height and w.map.amount[y * w.map.width + x] > 0:
				return true
	return false
