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
const NEXT_BUILD_TILES := 8            # a builder done with nothing queued goes on to your foundations this close


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


## Building types from data/buildings.json, sorted by id, numbers as ints. Planned buildings
## ("status": "planned": only on the tech tree page so far) are left out.
static func load_btypes(resources: Array) -> Array:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/buildings.json"))
	assert(d != null, "Bad or missing data/buildings.json")
	var ids: Array = d.buildings.keys().filter(func(id): return d.buildings[id].get("status", "") != "planned")
	ids.sort()
	var out := []
	for id in ids:
		var b: Dictionary = d.buildings[id]
		out.append({
			"id": id, "name": b.name, "desc": b.get("desc", ""), "hotkey": b.get("hotkey", ""), "size": int(b.size), "length": int(b.get("length", b.size)), "hp": int(b.hp),
			"cost": cost_vector(resources, b.cost), "drop": PackedByteArray(resources.map(func(r): return 1 if r in b.drop_off else 0)),
			"water": bool(b.get("water", false)), "becomes": b.get("becomes", {}).duplicate(),
			"food": int(b.get("food", 0)), "reseed": cost_vector(resources, b.get("reseed", {})),
			"build_ticks": int(b.build_time) * 20, "pop": int(b.pop), "house": bool(b.house),
			"trains": b.trains.duplicate(), "age": int(b.age), "armour": b.get("armour", {}).duplicate(),
			"attack": b.get("attack", {}).duplicate(), "gate": bool(b.get("gate", false)),
			"line": bool(b.get("line", false)), "replaces": b.get("replaces", []).duplicate(),
		})
	return out


## A building type's footprint in cells (x, y): size x size, but a gate is `length` long along
## its wall line, which runs along sim x (along 0) or sim y (along 1).
static func dims(t: Dictionary, along := 0) -> Vector2i:
	return Vector2i(t.length, t.size) if along == 0 else Vector2i(t.size, t.length)


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


## Put a building (unbuilt) on the map and return its slot (`along`: which way a gate runs, see dims).
static func place(w, player: int, k: int, cx: int, cy: int, along := 0) -> int:
	var t: Dictionary = w.btypes[k]
	var d := dims(t, along)
	var i: int = w.buildings.add(w.next_id, player, k, cx, cy, d.x, d.y, 1)
	w.next_id += 1
	w.map.occupy(w.buildings.footprint(i, w.map.width), w.buildings.id[i], w.teams[player] if t.gate else -1)
	if t.gate:
		w.refresh_lanes()   # the team's first gate gives it lanes of its own
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
	var bid := lay_foundation(w, player, a)
	if bid == 0:
		return
	for i in _own_workers(w, player, a.ids):
		start_build(w, i, bid)


## Pay for and place a BUILD's foundation; its id, or 0 when it can't be built there (or by
## these units, or yet). A shift-queued build lays its foundation at once (World._run), so you
## see what's planned and the workers come to it in turn, as in the genre.
static func lay_foundation(w, player: int, a: Dictionary) -> int:
	var k := btype_of(w, a.building)
	if k < 0:
		return 0
	var t: Dictionary = w.btypes[k]
	if _own_workers(w, player, a.ids).is_empty() or not w.can_afford(player, t.cost) or w.ages[player] < t.age:
		return 0
	var along := int(a.get("along", 0))
	if not can_place(w, player, k, a.cx, a.cy, along):
		return 0
	w.pay(player, t.cost)
	for c in _footprint(w, a.cx, a.cy, dims(t, along)):
		if _replaceable(w, player, t, c):
			demolish(w, w.buildings.index_of(w.map.occupied[c]))   # a gate dropped into a wall takes its place
	return w.buildings.id[place(w, player, k, a.cx, a.cy, along)]


## Can this player put a building of type k here? On open ground as usual, or (a gate) over
## its own wall tiles of the types it `replaces`.
static func can_place(w, player: int, k: int, cx: int, cy: int, along := 0) -> bool:
	var t: Dictionary = w.btypes[k]
	var mc := builder_class(w, player)
	var d := dims(t, along)
	for y in range(cy, cy + d.y):
		for x in range(cx, cx + d.x):
			var ok: bool = w.map.can_build(x, y, 1, mc, t.water)
			if not ok and not (x >= 0 and y >= 0 and x < w.map.width and y < w.map.height and _replaceable(w, player, t, y * w.map.width + x)):
				return false
	return true


## Does a building of type t, placed by this player, take the place of what stands on cell c?
static func _replaceable(w, player: int, t: Dictionary, c: int) -> bool:
	var id: int = w.map.occupied[c]
	if id == 0 or t.replaces.is_empty():
		return false
	var b: int = w.buildings.index_of(id)
	return b >= 0 and w.buildings.owner[b] == player and w.btypes[w.buildings.kind[b]].id in t.replaces


static func _footprint(w, cx: int, cy: int, d: Vector2i) -> PackedInt32Array:
	var out := PackedInt32Array()
	for y in range(cy, cy + d.y):
		for x in range(cx, cx + d.x):
			out.append(y * w.map.width + x)
	return out


## Take a building away without a fight (a wall tile a gate replaces). Its builders stop.
static func demolish(w, b: int) -> void:
	w.map.occupy(w.buildings.footprint(b, w.map.width), 0)
	w.buildings.remove_at(b)


static func cmd_help_build(w, player: int, a: Dictionary) -> void:
	var b: int = w.buildings.index_of(a.target)
	if b < 0 or w.buildings.owner[b] != player or w.buildings.done[b] == 1:
		return
	for i in _own_workers(w, player, a.ids):
		start_build(w, i, a.target)


## Right-click your own drop-off with workers carrying something it takes: they walk there,
## drop it off and go back to what they were gathering (their `home` cell, if they had one).
## Units with nothing it takes just walk up to it.
static func cmd_drop_off(w, player: int, a: Dictionary) -> void:
	var b: int = w.buildings.index_of(a.building)
	if b < 0 or w.buildings.owner[b] != player or w.buildings.done[b] == 0:
		return
	var t: Dictionary = w.btypes[w.buildings.kind[b]]
	var u = w.units
	for uid in a.ids:
		var i: int = u.index_of(uid)
		if i < 0 or u.owner[i] != player:
			continue
		if not can_drop(w, i, t):
			clear_task(w, i)
			_approach_building(w, i, b)
			continue
		if u.task[i] != GATHER and u.task[i] != RETURN:
			u.home[i] = -1   # a builder or an idle carrier: nothing to go back to
		u.task[i] = RETURN
		u.target[i] = a.building
		u.work[i] = 0
		_approach_building(w, i, b)


## Does unit i carry something a building of type t takes in?
static func can_drop(w, i: int, t: Dictionary) -> bool:
	var u = w.units
	return w.types[u.kind[i]].worker and u.carry[i] > 0 and u.carry_kind[i] > 0 and t.drop[u.carry_kind[i] - 1] == 1


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
	if not w.can_afford(player, t.cost) or w.ages[player] < int(t.line[0].age):
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
	w.refund(player, w.queued_cost(player, q[n]))   # a unit, or research / the age-up (Tech.entry)
	q.remove_at(n)
	if n == 0:
		w.buildings.train[b] = 0


static func cmd_rally(w, player: int, a: Dictionary) -> void:
	var b: int = w.buildings.index_of(a.building)
	if b < 0 or w.buildings.owner[b] != player:
		return
	var x: int = clampi(a.x, 0, w.map.width * SimMap.TILE - 1)
	var y: int = clampi(a.y, 0, w.map.height * SimMap.TILE - 1)
	var cell: int = w.map.cell_of(x, y)
	if w.map.resource_at(cell) != "":   # on a tree, rock, bush or carcass: its middle (Dominic)
		x = (cell % w.map.width) * SimMap.TILE + SimMap.TILE / 2
		y = (cell / w.map.width) * SimMap.TILE + SimMap.TILE / 2
	w.buildings.rally_x[b] = x
	w.buildings.rally_y[b] = y


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
	var carry_max := PackedInt32Array()   # per player: a creature's economy can carry more (centaurs) or less
	for p in w.races.size():
		carry_max.append(int(w.econ.carry) * int(w.races[p].economy.get("carry_pct", 100)) / 100)
	for i in u.count():
		match u.task[i]:
			GATHER:
				_gather(w, i, carry_max[u.owner[i]])
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
		u.stuck[i] = 0   # at its job (pushed there by the crowd, maybe): a stale count isn't a give-up
		u.work[i] += 1
		if u.work[i] >= w.gather_ticks[u.owner[i]][kind - 1]:
			u.work[i] = 0
			w.map.take(cell)
			u.carry[i] += 1
	elif u.moving[i] == 0:
		if u.stuck[i] >= GIVE_UP:
			# Can't get there (a crowd planted round the bush, or no way through): another
			# tile of the clump, the least busy, and only give up when there is none.
			var other := least_busy(w, cell, kind, cell)
			if other != cell:
				u.target[i] = other
				u.home[i] = other
				_approach_cell(w, i, other)
			else:
				clear_task(w, i)
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
		var nb := _nearby_foundation(w, i) if u.orders[i].is_empty() else -1
		if nb < 0:
			clear_task(w, i)
			return
		u.target[i] = bs.id[nb]   # on to the next unfinished building nearby, as the genre's builders do (Dominic)
		_approach_building(w, i, nb)
		return
	if _in_reach(w, i, _building_rect(w, b)):
		u.moving[i] = 0
		u.stuck[i] = 0
		var t: Dictionary = w.btypes[bs.kind[b]]
		bs.progress[b] += 1
		bs.hp[b] = maxi(1, t.hp * bs.progress[b] / t.build_ticks)
		if bs.progress[b] >= t.build_ticks:
			bs.done[b] = 1
			bs.hp[b] = t.hp
			if not t.becomes.is_empty():
				_become_ground(w, b, i)
			else:
				_gather_after_camp(w, b)
	elif u.moving[i] == 0:
		if u.stuck[i] >= GIVE_UP:
			clear_task(w, i)
		else:
			_approach_building(w, i, b)


## The nearest unfinished building of the worker's owner within NEXT_BUILD_TILES of it (lowest
## index on ties), or -1.
static func _nearby_foundation(w, i: int) -> int:
	var u = w.units
	var bs = w.buildings
	var best := -1
	var best_d2: int = NEXT_BUILD_TILES * NEXT_BUILD_TILES * SimMap.TILE * SimMap.TILE + 1
	for b in bs.count():
		if bs.owner[b] != u.owner[i] or bs.done[b] == 1:
			continue
		var d2 := Fixed.dist2(u.x[i], u.y[i], bs.cx[b] * SimMap.TILE + bs.sx[b] * SimMap.TILE / 2, bs.cy[b] * SimMap.TILE + bs.sy[b] * SimMap.TILE / 2)
		if d2 < best_d2:
			best_d2 = d2
			best = b
	return best


## A finished camp (a building taking in some resources, not all, like a mill or lumber
## camp): its builders with nothing queued go and gather the nearest of what it takes in
## (Dominic). The Town Center takes everything, so building one sends nobody anywhere.
static func _gather_after_camp(w, b: int) -> void:
	var bs = w.buildings
	var t: Dictionary = w.btypes[bs.kind[b]]
	var kinds := []
	for r in t.drop.size():
		if t.drop[r] == 1:
			kinds.append(r + 1)
	if kinds.is_empty() or kinds.size() == t.drop.size():
		return
	var u = w.units
	var bid: int = bs.id[b]
	for j in u.count():
		if u.task[j] != BUILD or u.target[j] != bid or not u.orders[j].is_empty():
			continue
		var best := -1
		var best_kind := 0
		var best_d2 := 1 << 62
		for kind in kinds:   # the nearest of any of them (a mining camp: stone or gold)
			var c := nearest_resource(w, u.x[j], u.y[j], kind)
			if c < 0:
				continue
			var d2 := Fixed.dist2(u.x[j], u.y[j], (c % w.map.width) * SimMap.TILE + 500, (c / w.map.width) * SimMap.TILE + 500)
			if d2 < best_d2:
				best_d2 = d2
				best = c
				best_kind = kind
		if best >= 0:
			start_gather(w, j, best, best_kind)


## The movement class a player's builders have (their worker's), for where they may build.
static func builder_class(w, player: int) -> int:
	var k: int = w.type_of(player, "worker")
	return w.types[k].mclass if k >= 0 else 0


## A finished farm turns its ground into crops (a field on land, a paddy in water): one farm,
## one pool of food over its tiles. The farm stays (it can be reseeded when it runs out);
## the builder who finished it starts the harvest.
static func _become_ground(w, b: int, i: int) -> void:
	var bs = w.buildings
	var t: Dictionary = w.btypes[bs.kind[b]]
	var cells: PackedInt32Array = bs.footprint(b, w.map.width)
	var land: bool = w.map.terrain_walk[w.map.terrain[cells[0]]]   # grass under it, or shallows
	w.map.make_pool(cells, w.map.terrain_ids.find(t.becomes.land if land else t.becomes.water), t.food)
	if w.units.orders[i].is_empty():
		start_gather(w, i, cells[0], kind_of(w, "food"))
	else:
		clear_task(w, i)   # told what to do after (shift): that comes first, not farming forever


## Reseed a worked-out farm: pay, crops again, the workers start the harvest.
static func cmd_reseed(w, player: int, a: Dictionary) -> void:
	var b: int = w.buildings.index_of(int(a.building))
	if b < 0 or w.buildings.owner[b] != player or w.buildings.done[b] == 0:
		return
	var t: Dictionary = w.btypes[w.buildings.kind[b]]
	var cells: PackedInt32Array = w.buildings.footprint(b, w.map.width)
	var to: int = w.map.terrain_reseed[w.map.terrain[cells[0]]]
	if t.becomes.is_empty() or w.map.left_at(cells[0]) > 0 or to < 0 or not w.can_afford(player, t.reseed):
		return
	w.pay(player, t.reseed)
	w.map.make_pool(cells, to, t.food)
	for i in _own_workers(w, player, a.ids):
		start_gather(w, i, cells[0], kind_of(w, "food"))


## A farm torn down leaves plain ground (or water) behind.
static func clear_farm(w, b: int) -> void:
	var t: Dictionary = w.btypes[w.buildings.kind[b]]
	if t.becomes.is_empty() or w.buildings.done[b] == 0:
		return
	var cells: PackedInt32Array = w.buildings.footprint(b, w.map.width)
	var to: int = w.map.terrain_cleared[w.map.terrain[cells[0]]]
	if to >= 0:
		w.map.clear_pool(cells, to)


static func _approach_cell(w, i: int, cell: int) -> void:
	w.order_reach(i, _cell_rect(w, cell), w.cell_field(cell, true, w.lane(i)))


static func _approach_building(w, i: int, b: int) -> void:
	w.order_reach(i, _building_rect(w, b), w.building_field(w.buildings.id[b], true, w.lane(i)))


static func _cell_rect(w, cell: int) -> Rect2i:
	var x: int = (cell % w.map.width) * SimMap.TILE
	var y: int = (cell / w.map.width) * SimMap.TILE
	return Rect2i(x, y, SimMap.TILE - 1, SimMap.TILE - 1)


static func _building_rect(w, b: int) -> Rect2i:
	var bs = w.buildings
	return Rect2i(bs.cx[b] * SimMap.TILE, bs.cy[b] * SimMap.TILE, bs.sx[b] * SimMap.TILE - 1, bs.sy[b] * SimMap.TILE - 1)


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
static func least_busy(w, cell: int, kind: int, except := -1) -> int:
	var m = w.map
	var u = w.units
	var cx: int = cell % m.width
	var cy: int = cell / m.width
	var best := cell
	var best_score := 1 << 62
	for yy in range(maxi(cy - SPREAD_TILES, 0), mini(cy + SPREAD_TILES + 1, m.height)):
		for xx in range(maxi(cx - SPREAD_TILES, 0), mini(cx + SPREAD_TILES + 1, m.width)):
			var c: int = yy * m.width + xx
			if c == except or m.amount[c] <= 0 or kind_of(w, m.resource_at(c)) != kind:
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
		var d2 := Fixed.dist2(u.x[i], u.y[i], bs.cx[b] * SimMap.TILE + bs.sx[b] * SimMap.TILE / 2, bs.cy[b] * SimMap.TILE + bs.sy[b] * SimMap.TILE / 2)
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
		if w.units.owner[i] != w.gaia:
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
		if bs.done[b] == 0 or q.is_empty() or q[0] < 0:
			continue   # unbuilt, nothing queued, or ageing up / researching (Tech.tick)
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
	var sx: int = bs.sx[b]
	var sy: int = bs.sy[b]
	var gx: int = bs.rally_x[b] if bs.rally_x[b] >= 0 else (cx + sx) * SimMap.TILE
	var gy: int = bs.rally_y[b] if bs.rally_x[b] >= 0 else (cy + sy) * SimMap.TILE
	var best := -1
	var best_d2 := 1 << 62
	for y in range(cy - 1, cy + sy + 1):
		for x in range(cx - 1, cx + sx + 1):
			var edge: bool = x == cx - 1 or x == cx + sx or y == cy - 1 or y == cy + sy
			if not edge or not m.cell_walkable(x, y, w.lane_base[bs.owner[b]] + w.types[k].mclass):
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
