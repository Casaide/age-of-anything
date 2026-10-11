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
const BOAR_SOLDIERS := 3       # idle soldiers at home that join a boar party (they lead; workers make up the rest)
var AGE_WORKERS := 16          # with this many workers, stop training and save for the next age

var player: int
var _next_train := 0
var _next_house := 0
var _next_claim := 0
var _ordered := {}             # unit ids given an order this think (later orders leave them be)


func _init(p_player: int) -> void:
	player = p_player


func think(w) -> void:
	if w.tick % THINK_EVERY != 0:
		return
	var tc := _town_center(w)
	if tc < 0:
		return
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
				elif w.units.moving[i] == 0:
					idle.append(i)
	var bs = w.buildings
	# Idle hands: back to work on whatever we're shortest of.
	for i in idle:
		var kind := _short_of(w, n, w.units.x[i], w.units.y[i])
		if kind > 0:
			w.issue(player, Commands.GATHER, {"ids": [w.units.id[i]], "cell": _nearest_resource(w, w.units.x[i], w.units.y[i], kind)})
			n[kind - 1] += 1
	# New workers go where we're short.
	var rally_kind := _short_of(w, n, bs.cx[tc] * 1000 + 1500, bs.cy[tc] * 1000 + 1500)
	var rally := _nearest_resource(w, bs.cx[tc] * 1000 + 1500, bs.cy[tc] * 1000 + 1500, rally_kind) if rally_kind > 0 else -1
	if rally >= 0 and w.map.cell_of(bs.rally_x[tc], bs.rally_y[tc]) != rally:
		w.issue(player, Commands.RALLY, {"building": bs.id[tc], "x": (rally % w.map.width) * 1000 + 500, "y": (rally / w.map.width) * 1000 + 500})
	# Meat first (the orders below then leave these hunters be), and no foundation left alone.
	_ordered.clear()
	_herd(w, tc, workers)
	_hunt(w, tc, workers)
	_finish_foundations(w, workers)
	# Age up: with enough workers, save up and click it.
	var saving: bool = w.ages[player] == 1 and workers.size() >= AGE_WORKERS
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
	if not saving and w.tick >= _next_train and bs.queue[tc].size() < 2 and workers.size() + bs.queue[tc].size() < MAX_WORKERS \
			and w.can_afford(player, t.cost):
		w.issue(player, Commands.TRAIN, {"building": bs.id[tc], "slot": "worker"})
		_next_train = w.tick + TRAIN_COOLDOWN
	# A house before we're stuck.
	var house: int = Economy.btype_of(w, "house")
	var queued_pop: int = bs.queue[tc].size() * t.pop
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
		var x: int = bs.cx[b] * 1000 + bs.size[b] * 500
		var y: int = bs.cy[b] * 1000 + bs.size[b] * 500
		var best := -1
		var best_d2 := 1 << 62
		for i in workers:
			if _ordered.has(u.id[i]) or u.foe[i] != 0 or u.task[i] == Economy.BUILD:
				continue
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
		if u.owner[i] != w.gaia or w.types[u.kind[i]].get("behaviour", "") != "herd":
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
				or Fixed.dist2(hx, hy, (c % m.width) * 1000 + 500, (c / m.width) * 1000 + 500) > near:
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
				and u.foe[i] == 0 and u.moving[i] == 0 and Fixed.dist2(hx, hy, u.x[i], u.y[i]) <= near:
			guards.append(u.id[i])
	var target := -1
	for want in ["herd", "flee", "fight"]:   # sheep, deer, boar
		if workers.size() < HUNT_WORKERS[want]:
			continue
		var best_d2 := HUNT_RADIUS * HUNT_RADIUS * 1000000
		for i in u.count():
			var t: Dictionary = w.types[u.kind[i]]
			var mine: bool = u.owner[i] == player and want == "herd"
			var wild: bool = u.owner[i] == w.gaia and want != "herd"
			if not (mine or wild) or t.get("behaviour", "") != want:
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
## feeds; worked-out farms reseeded (the idle hands then pick them up as the nearest food).
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
	if farms >= n[food - 1] - wild / WILD_PER_WORKER or w.stock[food - 1][player] >= FARM_BELOW or _building_underway(w) or not w.can_afford(player, ft.cost):
		return
	var builder := _pick_builder(w, workers)
	var spot := _house_spot(w, bs.cx[tc] + 1, bs.cy[tc] + 1, ft.size)
	if builder >= 0 and spot.x >= 0:
		w.issue(player, Commands.BUILD, {"ids": [w.units.id[builder]], "building": "farm", "cx": spot.x, "cy": spot.y})


## The resource (1-based kind) furthest below its share in this age's mix that has some left
## on the map, or 0. Ties go to the earlier resource.
func _short_of(w, n: PackedInt32Array, x: int, y: int) -> int:
	var mix: Dictionary = MIX[1]
	var keys := MIX.keys()
	keys.sort()
	for age in keys:
		if int(age) <= w.ages[player]:
			mix = MIX[age]
	var total := 1
	for v in n:
		total += v
	var best := 0
	var best_gap := -(1 << 30)
	for r in w.resources.size():
		var pct: int = int(mix.get(w.resources[r], 0))
		if pct <= 0:
			continue
		var gap := pct * total - n[r] * 100
		if w.stock[r][player] >= PLENTY:
			gap -= 1 << 20   # piling up: the others first
		if gap > best_gap and _nearest_resource(w, x, y, r + 1) >= 0:
			best_gap = gap
			best = r + 1
	return best


func _town_center(w) -> int:
	var tc_kind: int = Economy.btype_of(w, "town_center")
	for b in w.buildings.count():
		if w.buildings.owner[b] == player and w.buildings.kind[b] == tc_kind and w.buildings.done[b] == 1:
			return b
	return -1


func _building_underway(w) -> bool:
	for b in w.buildings.count():
		if w.buildings.owner[b] == player and w.buildings.done[b] == 0:
			return true
	return false


## A wood gatherer (lowest id), else any worker.
func _pick_builder(w, workers: Array) -> int:
	var free := workers.filter(func(i): return not _ordered.has(w.units.id[i]))
	for i in free:
		if w.units.task[i] != Economy.BUILD and w.units.carry_kind[i] == 2:
			return i
	return free[0] if not free.is_empty() else -1


## Nearest cell with that resource left, anywhere on the map (ties: lower cell).
func _nearest_resource(w, x: int, y: int, kind: int) -> int:
	var best := -1
	var best_d2 := 1 << 62
	for c in w.map.resource_cells:
		if w.map.amount[c] <= 0 or Economy.kind_of(w, w.map.resource_at(c)) != kind:
			continue
		var d2 := Fixed.dist2(x, y, (c % w.map.width) * 1000 + 500, (c / w.map.width) * 1000 + 500)
		if d2 < best_d2:
			best_d2 = d2
			best = c
	return best


## A free size x size spot with a tile of space around it, spiralling out from (cx, cy).
func _house_spot(w, cx: int, cy: int, size: int) -> Vector2i:
	for r in range(3, 14):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				if w.map.can_build(cx + dx - 1, cy + dy - 1, size + 2) and not _blocks_resource(w, cx + dx - 1, cy + dy - 1, size + 2):
					return Vector2i(cx + dx, cy + dy)
	return Vector2i(-1, -1)


## Don't wall in a resource: keep the margin box clear of resource tiles' neighbours.
func _blocks_resource(w, x0: int, y0: int, n: int) -> bool:
	for y in range(y0 - 1, y0 + n + 1):
		for x in range(x0 - 1, x0 + n + 1):
			if x >= 0 and y >= 0 and x < w.map.width and y < w.map.height and w.map.amount[y * w.map.width + x] > 0:
				return true
	return false
