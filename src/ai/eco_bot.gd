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
var AGE_WORKERS := 16          # with this many workers, stop training and save for the next age

var player: int
var _next_train := 0
var _next_house := 0


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
				if w.units.moving[i] == 0:
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
	# Age up: with enough workers, save up and click it.
	var saving: bool = w.ages[player] == 1 and workers.size() >= AGE_WORKERS
	if saving and not Tech.has_building(w, player, "barracks") and not _building_underway(w):
		var bk: int = Economy.btype_of(w, "barracks")
		if w.can_afford(player, w.btypes[bk].cost):
			var spot := _house_spot(w, bs.cx[tc] + 1, bs.cy[tc] + 1, w.btypes[bk].size)
			var builders := workers.slice(0, 3).map(func(i): return w.units.id[i])
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
	for i in workers:
		if w.units.task[i] != Economy.BUILD and w.units.carry_kind[i] == 2:
			return i
	return workers[0] if not workers.is_empty() else -1


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
