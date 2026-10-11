extends RefCounted
## The economy half of the sim: building types, the match setup, worker tasks
## (gather -> carry -> drop off -> back), construction, training and pop.
## Static functions over the World `w`, so world.gd stays about ticks and movement.
## Same rules as the rest of src/sim/: integers only, ascending ids, no Nodes.

const SimMap := preload("res://src/sim/sim_map.gd")
const Commands := preload("res://src/sim/commands.gd")
const Fixed := preload("res://src/sim/fixed.gd")

enum { NONE, GATHER, RETURN, BUILD }

const REACH := 250                    # milli-tiles between a body's edge and what it works on
const SEARCH_TILES := 8               # how far a worker looks for more of the same resource
const SPREAD_TILES := 2               # sent to a busy tile, a worker takes a quieter one this close
const BUSY_COST := 4000000            # one more gatherer on a tile weighs like 2 tiles of distance
const GIVE_UP := 60                   # mirrors World.STUCK_LIMIT


## Resource ids in their fixed order. A unit's carry_kind is a resource's index + 1 (0: nothing).
static func load_resources() -> Array:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/resources.json"))
	assert(d != null, "Bad or missing data/resources.json")
	return d.resources.map(func(r): return r.id)


## carry_kind for a resource id (0 if it isn't one).
static func kind_of(w, resource: String) -> int:
	return w.resources.find(resource) + 1


## A cost dict ({"food": 30, ...}) as an int vector in resource order.
static func cost_vector(resources: Array, cost: Dictionary) -> PackedInt32Array:
	var v := PackedInt32Array()
	for r in resources:
		v.append(int(cost.get(r, 0)))
	return v


## Building types from data/buildings.json, sorted by id, numbers as ints.
static func load_btypes(resources: Array) -> Array:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/buildings.json"))
	assert(d != null, "Bad or missing data/buildings.json")
	var ids: Array = d.buildings.keys()
	ids.sort()
	var out := []
	for id in ids:
		var b: Dictionary = d.buildings[id]
		out.append({
			"id": id, "name": b.name, "size": int(b.size), "hp": int(b.hp),
			"cost": cost_vector(resources, b.cost), "drop": PackedByteArray(resources.map(func(r): return 1 if r in b.drop_off else 0)),
			"build_ticks": int(b.build_time) * 20, "pop": int(b.pop), "house": bool(b.house),
			"trains": b.trains.duplicate(), "age": int(b.age), "armour": b.get("armour", {}).duplicate(),
		})
	return out


static func btype_of(w, id: String) -> int:
	for k in w.btypes.size():
		if w.btypes[k].id == id:
			return k
	return -1


# ------------------------------------------------------------------ setup

## Starting resources, a finished Town Center on each start, and the starting workers.
static func setup(w) -> void:
	var start: Dictionary = w.econ.start
	for r in w.resources:
		var s := PackedInt32Array()
		var g := PackedInt32Array()
		for p in w.races.size():
			s.append(int(start.get(r, 0)))
			g.append(0)
		w.stock.append(s)
		w.gathered.append(g)
	for p in w.races.size():
		w.pop.append(0)
		w.pop_cap.append(0)
		w.lost.append(0)
	for p in w.races.size():
		if start.buildings.is_empty() and int(start.workers) == 0:
			continue   # nothing to put down (tests and sandboxes; maps may have fewer starts than players)
		var s: Array = w.map.starts[p]
		for bid in start.buildings:
			var k := btype_of(w, bid)
			assert(k >= 0, "Unknown start building %s" % bid)
			var size: int = w.btypes[k].size
			var cx: int = s[0] / SimMap.TILE - size / 2
			var cy: int = s[1] / SimMap.TILE - size / 2
			assert(w.map.can_build(cx, cy, size), "No room for a %s at start %d" % [bid, p])
			var i := place(w, p, k, cx, cy)
			w.buildings.done[i] = 1
			w.buildings.hp[i] = w.btypes[k].hp
		var worker: int = w.type_of(p, "worker")
		if w.buildings.count() > 0 and worker >= 0:
			var tc: int = w.buildings.count() - 1
			for n in int(start.workers):
				spawn_at(w, tc, worker)
	update_pop(w)


## Put a building (unbuilt) on the map and return its slot.
static func place(w, player: int, k: int, cx: int, cy: int) -> int:
	var t: Dictionary = w.btypes[k]
	var i: int = w.buildings.add(w.next_id, player, k, cx, cy, t.size, 1)
	w.next_id += 1
	w.map.occupy(w.buildings.footprint(i, w.map.width), w.buildings.id[i])
	return i


# ------------------------------------------------------------------ commands

static func cmd_gather(w, player: int, a: Dictionary) -> void:
	var cell: int = a.cell
	var kind := kind_of(w, w.map.resource_at(cell))
	for uid in a.ids:
		var i: int = w.units.index_of(uid)
		if i < 0 or w.units.owner[i] != player:
			continue
		if kind <= 0 or not w.types[w.units.kind[i]].worker:
			w.order_move(i, (cell % w.map.width) * 1000 + 500, (cell / w.map.width) * 1000 + 500, 200, 0)
			continue
		start_gather(w, i, cell, kind)


static func cmd_build(w, player: int, a: Dictionary) -> void:
	var k := btype_of(w, a.building)
	if k < 0:
		return
	var t: Dictionary = w.btypes[k]
	var builders := _own_workers(w, player, a.ids)
	if builders.is_empty() or not w.can_afford(player, t.cost):
		return
	if not w.map.can_build(a.cx, a.cy, t.size):
		return
	w.pay(player, t.cost)
	var b := place(w, player, k, a.cx, a.cy)
	for i in builders:
		start_build(w, i, w.buildings.id[b])


static func cmd_help_build(w, player: int, a: Dictionary) -> void:
	var b: int = w.buildings.index_of(a.target)
	if b < 0 or w.buildings.owner[b] != player or w.buildings.done[b] == 1:
		return
	for i in _own_workers(w, player, a.ids):
		start_build(w, i, a.target)


static func cmd_train(w, player: int, a: Dictionary) -> void:
	var b: int = w.buildings.index_of(a.building)
	if b < 0 or w.buildings.owner[b] != player or w.buildings.done[b] == 0:
		return
	if not a.slot in w.btypes[w.buildings.kind[b]].trains:
		return
	var k: int = w.type_of(player, a.slot)
	if k < 0 or w.buildings.queue[b].size() >= int(w.econ.queue_max):
		return
	var t: Dictionary = w.types[k]
	if not w.can_afford(player, t.cost):
		return
	w.pay(player, t.cost)
	w.buildings.queue[b].append(k)


static func cmd_cancel(w, player: int, a: Dictionary) -> void:
	var b: int = w.buildings.index_of(a.building)
	if b < 0 or w.buildings.owner[b] != player:
		return
	var q: Array = w.buildings.queue[b]
	var n: int = a.index
	if n < 0 or n >= q.size():
		return
	var t: Dictionary = w.types[q[n]]
	w.refund(player, t.cost)
	q.remove_at(n)
	if n == 0:
		w.buildings.train[b] = 0


static func cmd_rally(w, player: int, a: Dictionary) -> void:
	var b: int = w.buildings.index_of(a.building)
	if b < 0 or w.buildings.owner[b] != player:
		return
	w.buildings.rally_x[b] = clampi(a.x, 0, w.map.width * SimMap.TILE - 1)
	w.buildings.rally_y[b] = clampi(a.y, 0, w.map.height * SimMap.TILE - 1)


static func _own_workers(w, player: int, ids: Array) -> Array:
	var out := []
	for uid in ids:
		var i: int = w.units.index_of(uid)
		if i >= 0 and w.units.owner[i] == player and w.types[w.units.kind[i]].worker:
			out.append(i)
	return out


# ------------------------------------------------------------------ tasks

static func start_gather(w, i: int, cell: int, kind: int) -> void:
	var u = w.units
	cell = least_busy(w, cell, kind)
	if u.carry[i] > 0 and u.carry_kind[i] != kind:
		u.carry[i] = 0   # dropped: you can't carry reeds and bugs at once
	u.carry_kind[i] = kind
	u.task[i] = GATHER
	u.target[i] = cell
	u.home[i] = cell
	u.work[i] = 0
	_approach_cell(w, i, cell)


static func start_build(w, i: int, bid: int) -> void:
	var u = w.units
	u.task[i] = BUILD
	u.target[i] = bid
	u.home[i] = -1
	u.work[i] = 0
	_approach_building(w, i, w.buildings.index_of(bid))


## A plain MOVE ends whatever the unit was doing (it keeps what it carries).
static func clear_task(w, i: int) -> void:
	w.units.task[i] = NONE
	w.units.target[i] = -1
	w.units.home[i] = -1
	w.units.work[i] = 0


## One tick of every worker's job. Runs before movement, so it sees start-of-tick positions.
static func work(w) -> void:
	var u = w.units
	var carry_max: int = w.econ.carry
	for i in u.count():
		match u.task[i]:
			GATHER:
				_gather(w, i, carry_max)
			RETURN:
				_return(w, i)
			BUILD:
				_build(w, i)


static func _gather(w, i: int, carry_max: int) -> void:
	var u = w.units
	if u.carry[i] >= carry_max:
		_to_drop_off(w, i)
		return
	var cell: int = u.target[i]
	var kind: int = u.carry_kind[i]
	if kind_of(w, w.map.resource_at(cell)) != kind:
		var more := nearest_resource(w, u.x[i], u.y[i], kind)
		if more >= 0:
			u.target[i] = more
			u.home[i] = more
			u.work[i] = 0
			_approach_cell(w, i, more)
		elif u.carry[i] > 0:
			u.home[i] = -1
			_to_drop_off(w, i)
		else:
			clear_task(w, i)
		return
	if _in_reach(w, i, _cell_rect(w, cell)):
		u.moving[i] = 0
		u.work[i] += 1
		if u.work[i] >= int(w.econ.gather_ticks[w.resources[kind - 1]]):
			u.work[i] = 0
			w.map.take(cell)
			u.carry[i] += 1
	elif u.moving[i] == 0:
		if u.stuck[i] >= GIVE_UP:
			clear_task(w, i)   # can't get there
		else:
			_approach_cell(w, i, cell)


static func _to_drop_off(w, i: int) -> void:
	var u = w.units
	var b := nearest_drop_off(w, i)
	if b < 0:
		clear_task(w, i)
		return
	u.task[i] = RETURN
	u.target[i] = w.buildings.id[b]
	u.work[i] = 0
	_approach_building(w, i, b)


static func _return(w, i: int) -> void:
	var u = w.units
	var b: int = w.buildings.index_of(u.target[i])
	if b < 0 or w.buildings.done[b] == 0:
		_to_drop_off(w, i)
		return
	if _in_reach(w, i, _building_rect(w, b)):
		var p: int = u.owner[i]
		if u.carry_kind[i] > 0:
			w.stock[u.carry_kind[i] - 1][p] += u.carry[i]
			w.gathered[u.carry_kind[i] - 1][p] += u.carry[i]
		u.carry[i] = 0
		u.moving[i] = 0
		if u.home[i] >= 0:
			u.task[i] = GATHER
			u.target[i] = u.home[i]
			_approach_cell(w, i, u.home[i])
		else:
			clear_task(w, i)
	elif u.moving[i] == 0:
		if u.stuck[i] >= GIVE_UP:
			clear_task(w, i)
		else:
			_approach_building(w, i, b)


static func _build(w, i: int) -> void:
	var u = w.units
	var bs = w.buildings
	var b: int = bs.index_of(u.target[i])
	if b < 0 or bs.done[b] == 1:
		clear_task(w, i)
		return
	if _in_reach(w, i, _building_rect(w, b)):
		u.moving[i] = 0
		var t: Dictionary = w.btypes[bs.kind[b]]
		bs.progress[b] += 1
		bs.hp[b] = maxi(1, t.hp * bs.progress[b] / t.build_ticks)
		if bs.progress[b] >= t.build_ticks:
			bs.done[b] = 1
			bs.hp[b] = t.hp
	elif u.moving[i] == 0:
		if u.stuck[i] >= GIVE_UP:
			clear_task(w, i)
		else:
			_approach_building(w, i, b)


static func _approach_cell(w, i: int, cell: int) -> void:
	w.order_reach(i, _cell_rect(w, cell), w.cell_field(cell, true, w.units.mclass[i]))


static func _approach_building(w, i: int, b: int) -> void:
	w.order_reach(i, _building_rect(w, b), w.building_field(w.buildings.id[b], true, w.units.mclass[i]))


static func _cell_rect(w, cell: int) -> Rect2i:
	var x: int = (cell % w.map.width) * SimMap.TILE
	var y: int = (cell / w.map.width) * SimMap.TILE
	return Rect2i(x, y, SimMap.TILE - 1, SimMap.TILE - 1)


static func _building_rect(w, b: int) -> Rect2i:
	var bs = w.buildings
	var s: int = bs.size[b] * SimMap.TILE
	return Rect2i(bs.cx[b] * SimMap.TILE, bs.cy[b] * SimMap.TILE, s - 1, s - 1)


## Is unit i's body within REACH of the rect?
static func _in_reach(w, i: int, r: Rect2i) -> bool:
	var u = w.units
	var dx: int = maxi(maxi(r.position.x - u.x[i], 0), u.x[i] - r.end.x)
	var dy: int = maxi(maxi(r.position.y - u.y[i], 0), u.y[i] - r.end.y)
	var reach: int = u.radius[i] + REACH
	return dx * dx + dy * dy <= reach * reach


## The tile of this resource near `cell` (within SPREAD_TILES) with the fewest
## gatherers, nearer ones first; ties go to the lower cell. Spreads a crowd over a
## clump of bushes or a reed bed instead of piling everyone onto one tile.
static func least_busy(w, cell: int, kind: int) -> int:
	var m = w.map
	var u = w.units
	var cx: int = cell % m.width
	var cy: int = cell / m.width
	var best := cell
	var best_score := 1 << 62
	for yy in range(maxi(cy - SPREAD_TILES, 0), mini(cy + SPREAD_TILES + 1, m.height)):
		for xx in range(maxi(cx - SPREAD_TILES, 0), mini(cx + SPREAD_TILES + 1, m.width)):
			var c: int = yy * m.width + xx
			if m.amount[c] <= 0 or kind_of(w, m.resource_at(c)) != kind:
				continue
			var busy := 0
			for j in u.count():
				if u.home[j] == c and (u.task[j] == GATHER or u.task[j] == RETURN):
					busy += 1
			var score: int = busy * BUSY_COST + Fixed.dist2(cx * 1000, cy * 1000, xx * 1000, yy * 1000)
			if score < best_score:
				best_score = score
				best = c
	return best


## The nearest cell with this resource within SEARCH_TILES, or -1. Ties go to the lower cell.
static func nearest_resource(w, x: int, y: int, kind: int) -> int:
	var m = w.map
	var cx: int = x / SimMap.TILE
	var cy: int = y / SimMap.TILE
	var best := -1
	var best_d2 := 1 << 62
	for yy in range(maxi(cy - SEARCH_TILES, 0), mini(cy + SEARCH_TILES + 1, m.height)):
		for xx in range(maxi(cx - SEARCH_TILES, 0), mini(cx + SEARCH_TILES + 1, m.width)):
			var c: int = yy * m.width + xx
			if m.amount[c] <= 0 or kind_of(w, m.resource_at(c)) != kind:
				continue
			var d2 := Fixed.dist2(x, y, xx * SimMap.TILE + 500, yy * SimMap.TILE + 500)
			if d2 < best_d2:
				best_d2 = d2
				best = c
	return best


## The owner's nearest finished building that takes what unit i carries, or -1.
static func nearest_drop_off(w, i: int) -> int:
	var u = w.units
	var bs = w.buildings
	var best := -1
	var best_d2 := 1 << 62
	for b in bs.count():
		if bs.owner[b] != u.owner[i] or bs.done[b] == 0:
			continue
		var t: Dictionary = w.btypes[bs.kind[b]]
		if u.carry_kind[i] <= 0 or t.drop[u.carry_kind[i] - 1] == 0:
			continue
		var half: int = bs.size[b] * SimMap.TILE / 2
		var d2 := Fixed.dist2(u.x[i], u.y[i], bs.cx[b] * SimMap.TILE + half, bs.cy[b] * SimMap.TILE + half)
		if d2 < best_d2:
			best_d2 = d2
			best = b
	return best


# ------------------------------------------------------------------ buildings

## Pop and pop cap per player, from live units and finished buildings.
static func update_pop(w) -> void:
	for p in w.races.size():
		w.pop[p] = 0
		w.pop_cap[p] = 0
	for i in w.units.count():
		w.pop[w.units.owner[i]] += w.types[w.units.kind[i]].pop
	for b in w.buildings.count():
		if w.buildings.done[b] == 1:
			var p: int = w.buildings.owner[b]
			var t: Dictionary = w.btypes[w.buildings.kind[b]]
			var add: int = t.pop
			if t.house:
				add = int(w.races[p].economy.get("house_pop", t.pop))
			w.pop_cap[p] += add
	for p in w.races.size():
		w.pop_cap[p] = mini(w.pop_cap[p], int(w.econ.pop_max))


## Advance every building's train queue. Training waits while the owner is at the pop cap.
static func train(w) -> void:
	update_pop(w)
	var bs = w.buildings
	for b in bs.count():
		var q: Array = bs.queue[b]
		if bs.done[b] == 0 or q.is_empty():
			continue
		var p: int = bs.owner[b]
		var t: Dictionary = w.types[q[0]]
		if bs.train[b] == 0 and w.pop[p] + t.pop > w.pop_cap[p]:
			continue   # housed
		bs.train[b] += 1
		if bs.train[b] < t.train_ticks:
			continue
		bs.train[b] = 0
		var k: int = q.pop_front()
		var i := spawn_at(w, b, k)
		w.pop[p] += t.pop
		_go_to_rally(w, b, i)


static func _go_to_rally(w, b: int, i: int) -> void:
	var bs = w.buildings
	if bs.rally_x[b] < 0:
		return
	var cell: int = w.map.cell_of(bs.rally_x[b], bs.rally_y[b])
	var kind := kind_of(w, w.map.resource_at(cell))
	if kind > 0 and w.types[w.units.kind[i]].worker:
		start_gather(w, i, cell, kind)
	else:
		w.order_move(i, bs.rally_x[b], bs.rally_y[b], 200, 0)


## A new unit of type k on the walkable tile beside building b that's nearest its
## rally point (or its front corner). Returns the unit's slot.
static func spawn_at(w, b: int, k: int) -> int:
	var bs = w.buildings
	var m = w.map
	var cx: int = bs.cx[b]
	var cy: int = bs.cy[b]
	var s: int = bs.size[b]
	var gx: int = bs.rally_x[b] if bs.rally_x[b] >= 0 else (cx + s) * SimMap.TILE
	var gy: int = bs.rally_y[b] if bs.rally_x[b] >= 0 else (cy + s) * SimMap.TILE
	var best := -1
	var best_d2 := 1 << 62
	for y in range(cy - 1, cy + s + 1):
		for x in range(cx - 1, cx + s + 1):
			var edge: bool = x == cx - 1 or x == cx + s or y == cy - 1 or y == cy + s
			if not edge or not m.cell_walkable(x, y, w.types[k].mclass):
				continue
			var d2 := Fixed.dist2(gx, gy, x * SimMap.TILE + 500, y * SimMap.TILE + 500)
			if d2 < best_d2:
				best_d2 = d2
				best = y * m.width + x
	assert(best >= 0, "Building %d is walled in; nowhere to spawn" % bs.id[b])
	var t: Dictionary = w.types[k]
	var i: int = w.units.add(w.next_id, bs.owner[b], k, (best % m.width) * SimMap.TILE + 500,
		(best / m.width) * SimMap.TILE + 500, t.speed, t.radius, t.hp)
	w.units.mclass[i] = t.mclass
	w.next_id += 1
	return i
