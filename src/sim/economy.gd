extends RefCounted
## The economy half of the sim: building types, the match setup, worker tasks
## (gather -> carry -> drop off -> back), construction, training and pop.
## Static functions over the World `w`, so world.gd stays about ticks and movement.
## Same rules as the rest of src/sim/: integers only, ascending ids, no Nodes.

const SimMap := preload("res://src/sim/sim_map.gd")
const Commands := preload("res://src/sim/commands.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const Bridges := preload("res://src/sim/bridges.gd")
const Pens := preload("res://src/sim/pens.gd")
const Buildings := preload("res://src/sim/buildings.gd")
const Identity := preload("res://src/identity.gd")
const Heroes := preload("res://src/sim/heroes.gd")

enum { NONE, GATHER, RETURN, BUILD, GARRISON, TRADE, CLIMB, REPAIR }   # GARRISON: walking into a building to shelter (garrison.gd); TRADE: a cart on its route (trade.gd); CLIMB: walking to a way up onto a wall and climbing it (walls.gd); REPAIR: mending a building or an engine (repair.gd)

const REACH := 250                    # milli-tiles between a body's edge and what it works on
const SEARCH_TILES := 8               # how far a worker looks for more of the same resource
const SPREAD_TILES := 2               # sent to a busy tile, a worker takes a quieter one this close
const BUSY_COST := 4000000            # one more gatherer on a tile weighs like 2 tiles of distance
const GIVE_UP := 60                   # mirrors World.STUCK_LIMIT
const NEXT_BUILD_TILES := 5            # a builder done with nothing queued goes on to your foundations this close
const BACK_TO_WORK_TILES := 10         # ... else back to what it gathered before, if that's this close (else it stays by the building)
const WAIT_TICKS := 20                 # a worker waiting by a full farm looks again this often
# Gather spots (Dominic, 2026-10-13: "food gathering needs to be more organised like with the unit
# formations"): a tile of a resource with "spots" (data/resources.json; food: bushes and carcasses,
# not farms) offers SPOTS places to stand round it, N, NE, E, SE, S, SW, W, NW; a gatherer holds
# one while it works the tile (carrying home included), walks to it and stands there, so a crowd
# spreads round the bush instead of heaping up on the near side. Held spots are derived (home +
# gspot of everyone gathering or carrying), so leaving, dying or a new order frees them.
# Wood (data "spots": "sides") offers only the four side spots, on open ground: a woodcutter stands
# at the forest edge facing its own tree, and woodcutters spread along the edge, a tree each
# (Dominic, 2026-10-13: three on one spot, "trying to reach one further back?"). Stone and gold
# offer all eight. A spotted tile with no open ground beside it is never picked (a tree behind trees).
const SPOTS := 8
const SIDES := 2                       # gather_spots value for "sides" (1: all eight)
const SPOT_GAP := 100                  # between a body and its tile at an edge spot (World.SPOT_GAP)
const SPOT_NEAR := 150                 # a gatherer this close to its spot (or stopped in reach) is at work
const SPOT_DX := [0, 1, 1, 1, 0, -1, -1, -1]
const SPOT_DY := [-1, -1, 0, 1, 1, 1, 0, -1]


## Resource ids in their fixed order. A unit's carry_kind is a resource's index + 1 (0: nothing).
static func load_resources() -> Array:
	return _resource_data().map(func(r): return r.id)


## Per resource, in order: 1 if its gatherers stand at spots round a tile (its "spots": true),
## SIDES if only at the four sides ("sides"), 0 if anywhere in reach.
static func load_gather_spots() -> PackedByteArray:
	return PackedByteArray(_resource_data().map(func(r): return SIDES if r.get("spots", false) is String and r.spots == "sides" else (1 if r.get("spots", false) == true else 0)))


static func _resource_data() -> Array:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/resources.json"))
	assert(d != null, "Bad or missing data/resources.json")
	return d.resources


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
			"food": int(b.get("food", 0)), "workers": int(b.get("workers", 0)), "reseed": cost_vector(resources, b.get("reseed", {})),
			"build_ticks": int(b.build_time) * 20, "pop": int(b.pop), "house": bool(b.house),
			"trains": b.trains.duplicate(), "age": int(b.age), "armour": b.get("armour", {}).duplicate(),
			"attack": b.get("attack", {}).duplicate(), "gate": bool(b.get("gate", false)),
			"line": bool(b.get("line", false)), "replaces": b.get("replaces", []).duplicate(),
			"pen": _pen_ticks(b.get("pen", {})),
			"idle_note": b.get("idle_note", ""),
			"garrison": int(b.get("garrison", 0)), "sight": int(b.get("sight", 0)), "more_from_age": int(b.get("more_from_age", 0)),
			"arrows": int(b.get("attack", {}).get("arrows", 1)),
			"walkway": int(b.get("walkway", 0)), "stairs": bool(b.get("stairs", false)), "joins": bool(b.get("joins", false)),   # walls you stand on (walls.gd)
			"ladder": bool(b.get("ladder", false)),
			"pour": _ints_of(b.get("pour", {})),   # the defenders' tools (combat.gd _pour)
		})
	return out


static func _ints_of(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = int(d[k])
	return out


## A pen's numbers (pens.gd) as ints, its times in ticks; {} for any other building.
static func _pen_ticks(p: Dictionary) -> Dictionary:
	if p.is_empty():
		return {}
	return {"animals": int(p.animals), "food": int(p.food), "food_ticks": int(p.food_every) * 20, "breed_ticks": int(p.breed_every) * 20}


## A building type's footprint in cells (x, y): size x size, but a gate is `length` long along
## its wall line, which runs along sim x (along 0), sim y (along 1), or a diagonal (along 2: x and y
## grow together; along 3: x falls as y grows), where it takes `length` cells corner to corner
## across a `length` square (diag_of, Buildings.cells).
static func dims(t: Dictionary, along := 0) -> Vector2i:
	if along >= 2:
		return Vector2i(t.length, t.length)
	return Vector2i(t.length, t.size) if along == 0 else Vector2i(t.size, t.length)


## Which diagonal a footprint laid `along` takes (Buildings.diag): 0 for a rect.
static func diag_of(along: int) -> int:
	return along - 1 if along >= 2 else 0


## A BUILD's `along` for type t: only gates turn (0..3); anything else is 0.
static func along_for(t: Dictionary, along: int) -> int:
	return along if t.gate and along >= 0 and along <= 3 else 0


static func btype_of(w, id: String) -> int:
	for k in w.btypes.size():
		if w.btypes[k].id == id:
			return k
	return -1


## The building type a player gets when ordering type k: k, or what its research turned it into
## (tech.json {"building": "watchtower", "becomes": "bastion"}, Tech._upgrade_buildings), following a chain.
static func upgraded(w, player: int, k: int) -> int:
	for r in w.tech.research.size():
		if w.researched[player][r] == 0:
			continue
		for fx in w.tech.research[r].effects:
			if fx.has("becomes") and w.btypes[k].id == fx.building:
				var to := btype_of(w, fx.becomes)
				assert(to >= 0, "Research turns %s into unknown building %s" % [fx.building, fx.becomes])
				return upgraded(w, player, to)
	return k


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
	for p in w.races.size():   # race bonuses with more at the start (the Nile's granary, an ally's too)
		for fx in w.ident[p].fx:
			if fx.has("start"):
				w.stock[w.resources.find(fx.start)][p] += int(fx.add)
	for p in w.races.size():
		w.pop.append(0)
		w.pop_cap.append(0)
		w.lost.append(0)
		w.auto_reseed.append(1)   # the genre's auto-reseed, on until the player turns it off
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
			w.buildings.hp[i] = w.bmods[p][k].hp
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
	var i: int = w.buildings.add(w.next_id, player, k, cx, cy, d.x, d.y, 1, diag_of(along))
	w.next_id += 1
	if not w.rubble.is_empty():   # built over a breach: the rubble goes (walls.gd)
		for c in w.buildings.footprint(i, w.map.width):
			if w.rubble.has(c):
				w.map.set_terrain(c, w.rubble[c][0])
				w.rubble.erase(c)
	w.map.occupy(w.buildings.footprint(i, w.map.width), w.buildings.id[i], w.teams[player] if t.gate else -1)
	if t.ladder:
		w.map.set_walk_over(w.buildings.footprint(i, w.map.width), true)   # walked over at the wall's foot (walls.gd)
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
	k = upgraded(w, player, k)   # a Watchtower ordered after the Bastion research is a Bastion
	var t: Dictionary = w.btypes[k]
	if _own_workers(w, player, a.ids).is_empty() or why_not_build(w, player, k) != "":
		return 0
	var along := along_for(t, int(a.get("along", 0)))
	if not can_place(w, player, k, a.cx, a.cy, along):
		return 0
	var cost: PackedInt32Array = repair_cost(w, player, k, _footprint(w, a.cx, a.cy, dims(t, along), along))
	if not w.can_afford(player, cost):
		return 0
	w.pay(player, cost)
	for c in _footprint(w, a.cx, a.cy, dims(t, along), along):
		if _replaceable(w, player, t, c):
			demolish(w, w.buildings.index_of(w.map.occupied[c]))   # a gate dropped into a wall takes its place
	return w.buildings.id[place(w, player, k, a.cx, a.cy, along)]


## What a building of type k costs this player over these cells: its cost, or, rebuilt over its
## own breach (every cell rubble of the player's: walls.gd), breach.repair_pct of it.
static func repair_cost(w, player: int, k: int, cells: PackedInt32Array) -> PackedInt32Array:
	var cost: PackedInt32Array = bcost(w, player, k)
	if w.rubble.is_empty() or cells.is_empty():
		return cost
	for c in cells:
		if not w.rubble.has(c) or w.rubble[c][1] != player:
			return cost
	var out := PackedInt32Array()
	for v in cost:
		out.append(v * int(w.walk_cfg.repair_pct) / 100)
	return out


## Why this player can't start a building of type k anywhere just now (its age; another Town
## Center before `more_from_age`), or "". Cost and place are checked apart.
static func why_not_build(w, player: int, k: int) -> String:
	var t: Dictionary = w.btypes[k]
	if lacks(w, player, t.id):
		return "not in this race's tech tree"   # milestone 14: centaurs build no walls
	if w.ages[player] < t.age:
		return "needs age %d" % t.age
	if t.more_from_age > 0 and w.ages[player] < t.more_from_age:
		var bs = w.buildings
		for b in bs.count():
			if bs.owner[b] == player and bs.kind[b] == k:
				return "another needs age %d" % t.more_from_age
	return ""


## What a building of type k costs this player: its price, less the race's and research's
## building `cost` pct (bugs' houses, spiders' walls: Tech.refresh).
static func bcost(w, player: int, k: int) -> PackedInt32Array:
	var pct := int(w.bmods[player][k].pct.get("cost", 0))
	if pct == 0:
		return w.btypes[k].cost
	var cost: PackedInt32Array = w.btypes[k].cost.duplicate()
	for r in cost.size():
		cost[r] = cost[r] * (100 + pct) / 100
	return cost


## Does this player's race lack that building, line (slot) or "trade"? (src/identity.gd; lifted by
## the host's full_tech_tree rule.)
static func lacks(w, player: int, id: String) -> bool:
	return Identity.lacks(w.ident[player], id, w.rules)


## Can this player put a building of type k here? On open ground as usual, or (a gate) over
## its own wall tiles of the types it `replaces`. Wall pieces (`line`) also go on cliffs and ramps,
## so a wall runs straight over a hill (D-154); a gate never stands on a cliff.
static func can_place(w, player: int, k: int, cx: int, cy: int, along := 0) -> bool:
	var t: Dictionary = w.btypes[k]
	var mc := builder_class(w, player)
	var d := dims(t, along)
	if cx < 0 or cy < 0 or cx + d.x > w.map.width or cy + d.y > w.map.height:
		return false
	for c in _footprint(w, cx, cy, d, along):
		var x: int = c % w.map.width
		var y: int = c / w.map.width
		if not w.map.can_build(x, y, 1, mc, t.water, t.line) and not _replaceable(w, player, t, c):
			return false
		if t.gate and w.map.cliff[c] == 1:
			return false
	if t.ladder and not _against_enemy_wall(w, player, cy * w.map.width + cx):
		return false   # a ladder only leans on an enemy walkway (walls.gd)
	return true


## Is cell c beside (N E S W) a finished walkway cell of an enemy of `player` (a ladder's place)?
static func _against_enemy_wall(w, player: int, c: int) -> bool:
	var mw: int = w.map.width
	for n in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var x: int = c % mw + n.x
		var y: int = c / mw + n.y
		if x < 0 or y < 0 or x >= mw or y >= w.map.height:
			continue
		var b: int = w.buildings.index_of(w.map.occupied[y * mw + x])
		if b >= 0 and w.buildings.done[b] == 1 and w.btypes[w.buildings.kind[b]].walkway > 0 and w.is_enemy(w.buildings.owner[b], player):
			return true
	return false


## Does a building of type t, placed by this player, take the place of what stands on cell c?
static func _replaceable(w, player: int, t: Dictionary, c: int) -> bool:
	var id: int = w.map.occupied[c]
	if id == 0 or t.replaces.is_empty():
		return false
	var b: int = w.buildings.index_of(id)
	return b >= 0 and w.buildings.owner[b] == player and w.btypes[w.buildings.kind[b]].id in t.replaces


## The cells a footprint of d laid `along` covers (a diagonal gate's, only its diagonal), row by row.
static func _footprint(w, cx: int, cy: int, d: Vector2i, along := 0) -> PackedInt32Array:
	return Buildings.cells(cx, cy, d.x, d.y, diag_of(along), w.map.width)


## Take a building away without a fight (a wall tile a gate replaces). Its builders stop.
static func demolish(w, b: int) -> void:
	Pens.gone(w, b)
	w.map.occupy(w.buildings.footprint(b, w.map.width), 0)
	w.buildings.remove_at(b)


static func cmd_help_build(w, player: int, a: Dictionary) -> void:
	if Bridges.cmd_help(w, player, a, _own_workers(w, player, a.ids)):
		return   # a map bridge: rebuilt by anyone (bridges.gd)
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
	var k: int = w.type_for(player, a)   # (the hero line: the hero named, heroes.gd)
	if k < 0 or w.buildings.queue[b].size() >= int(w.econ.queue_max) or lacks(w, player, a.slot):
		return
	var t: Dictionary = w.types[k]
	var cost: PackedInt32Array = w.queued_cost(player, k)   # (a hero revived: its share of the price, heroes.gd)
	if not w.can_afford(player, cost) or w.ages[player] < int(t.line[0].age):
		return
	if t.hero and Heroes.why_not(w, player, k) != "":
		return   # one of each hero out at a time, and a fallen one waits to be revived
	w.pay(player, cost)
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

## Send worker i to gather `kind` at `cell`. A farm already worked by as many as it takes
## sends it to a free farm nearby, else other food nearby; with neither it walks to the farm
## and waits there (task GATHER, home -1) until one frees up.
static func start_gather(w, i: int, cell: int, kind: int) -> void:
	var u = w.units
	var c := _pick(w, i, cell, kind)
	if u.carry[i] > 0 and u.carry_kind[i] != kind:
		u.carry[i] = 0   # dropped: you can't carry reeds and bugs at once
	u.carry_kind[i] = kind
	u.task[i] = GATHER
	u.target[i] = c if c >= 0 else cell
	u.home[i] = c
	u.gspot[i] = -1
	u.work[i] = 0
	_approach_cell(w, i, u.target[i])


## Where worker i gathers when sent to `cell`: the least busy tile there; if that's a full
## farm, the nearest farm with room, else the nearest other tile of the resource; -1 if none.
static func _pick(w, i: int, cell: int, kind: int) -> int:
	var c := least_busy(w, cell, kind, -1, i)
	var to_farm: bool = w.map.pool[cell] >= 0
	if spotted(w, c) and free_spot(w, i, c) < 0:
		# Every place round the clump is held: the nearest tile of it with room, if any.
		var x: int = (cell % w.map.width) * SimMap.TILE + SimMap.TILE / 2
		var y: int = (cell / w.map.width) * SimMap.TILE + SimMap.TILE / 2
		var roomy := nearest_resource(w, x, y, kind, i, false, true)
		if roomy >= 0:
			return roomy
	if not taken(w, c, i) and (not to_farm or w.map.pool[c] >= 0):
		return c
	var x: int = (cell % w.map.width) * SimMap.TILE + SimMap.TILE / 2
	var y: int = (cell / w.map.width) * SimMap.TILE + SimMap.TILE / 2
	var farm := nearest_resource(w, x, y, kind, i, true)
	if farm >= 0:
		return farm
	return c if not taken(w, c, i) else nearest_resource(w, x, y, kind, i)


## Is this cell's ground (a farm's pool) worked by as many workers as it takes, not counting
## unit i, or not unit i's own farm? A worker works the pool its `home` is on while it gathers or carries from it, so
## one who leaves, dies or is sent elsewhere frees its place. Plain resource tiles never fill.
static func taken(w, cell: int, i := -1) -> bool:
	var m = w.map
	if cell < 0 or m.pool[cell] < 0:
		return false
	var b: int = w.buildings.index_of(m.occupied[cell])
	if b >= 0 and i >= 0 and w.buildings.owner[b] != w.units.owner[i]:
		return true   # someone else's farm: never yours to work
	var limit: int = w.btypes[w.buildings.kind[b]].workers if b >= 0 else 0
	if limit <= 0:
		return false
	var u = w.units
	var n := 0
	for j in u.count():
		if j != i and u.home[j] >= 0 and m.pool[u.home[j]] == m.pool[cell] and (u.task[j] == GATHER or u.task[j] == RETURN):
			n += 1
	return n >= limit


## Worker i builds `bid`. A gatherer keeps its `home` (what it gathered) to go back to after.
static func start_build(w, i: int, bid: int) -> void:
	var u = w.units
	if u.task[i] != GATHER and u.task[i] != RETURN:
		u.home[i] = -1
	u.task[i] = BUILD
	u.target[i] = bid
	u.gspot[i] = -1
	u.work[i] = 0
	_approach_building(w, i, w.buildings.index_of(bid))


## A plain MOVE ends whatever the unit was doing (it keeps what it carries).
static func clear_task(w, i: int) -> void:
	w.units.task[i] = NONE
	w.units.target[i] = -1
	w.units.home[i] = -1
	w.units.gspot[i] = -1
	w.units.work[i] = 0


## One tick of every worker's job. Runs before movement, so it sees start-of-tick positions.
static func work(w) -> void:
	var u = w.units
	for i in u.count():
		match u.task[i]:
			GATHER:
				_gather(w, i, int(w.econ.carry) + int(w.types[u.kind[i]].carry_add))   # research and race bonuses add to it (Tech.retype: centaurs carry 60% more)
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
	if kind_of(w, w.map.resource_at(cell)) != kind and u.home[i] == cell and farm_at(w, cell, u.owner[i]) >= 0:
		_fallow(w, i, cell, kind)
		return
	if kind_of(w, w.map.resource_at(cell)) != kind:
		var more := nearest_resource(w, u.x[i], u.y[i], kind, i, false, true, true)
		if more < 0:
			more = nearest_resource(w, u.x[i], u.y[i], kind, i, false, false, true)
		if more >= 0:
			u.target[i] = more
			u.home[i] = more
			u.gspot[i] = -1
			u.work[i] = 0
			_approach_cell(w, i, more)
		elif u.carry[i] > 0:
			u.home[i] = -1
			_to_drop_off(w, i)
		else:
			clear_task(w, i)
		return
	if u.home[i] < 0:
		_wait(w, i, cell, kind)
		return
	# At work once in reach; one making for its spot gets there first (or stops on the way).
	if _in_reach(w, i, _cell_rect(w, cell)) and (u.reach[i] == 1 or u.moving[i] == 0 \
			or Fixed.dist2(u.x[i], u.y[i], u.tx[i], u.ty[i]) <= SPOT_NEAR * SPOT_NEAR):
		u.moving[i] = 0
		u.stuck[i] = 0   # at its job (pushed there by the crowd, maybe): a stale count isn't a give-up
		u.work[i] += 1
		if u.work[i] >= w.gather_ticks[u.owner[i]][kind - 1]:
			u.work[i] = 0
			w.map.take(cell)
			u.carry[i] += 1
			if w.map.pool[cell] >= 0 and w.map.left_at(cell) <= 0:
				_farm_done(w, i, cell)
	elif u.moving[i] == 0:
		if u.stuck[i] >= GIVE_UP:
			# Can't get there (a crowd planted round the bush, or no way through): another
			# tile of the clump, the least busy, and only give up when there is none.
			var other := least_busy(w, cell, kind, cell, i)
			if other != cell and not taken(w, other, i):
				u.target[i] = other
				u.home[i] = other
				u.gspot[i] = -1
				_approach_cell(w, i, other)
			else:
				clear_task(w, i)
		elif u.reach[i] == 0 and u.gspot[i] >= 0:
			# Stopped short of its spot (crowded off it, or close enough to call it there): in the
			# old way this trip, anywhere in reach (it keeps the spot for the next).
			w.order_reach(i, _cell_rect(w, cell), w.cell_field(cell, true, w.lane(i)))
		else:
			_approach_cell(w, i, cell)


## Waiting by a full farm: every WAIT_TICKS, look again (this farm, a free one nearby, other
## food) and go to work as soon as there's room.
static func _wait(w, i: int, cell: int, kind: int) -> void:
	var u = w.units
	if u.moving[i] == 0:
		u.stuck[i] = 0
	u.work[i] += 1
	if u.work[i] < WAIT_TICKS:
		return
	u.work[i] = 0
	var c := _pick(w, i, cell, kind)
	if c >= 0:
		u.target[i] = c
		u.home[i] = c
		u.gspot[i] = -1
		_approach_cell(w, i, c)


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
	if b < 0:
		var br := Bridges.index_of(w, u.target[i])
		if br >= 0:
			if not Bridges.work(w, i, br, _in_reach(w, i, w.bridge_rect[br])):
				clear_task(w, i)
			return
	if b < 0 or bs.done[b] == 1:
		var nb := _nearby_foundation(w, i) if u.orders[i].is_empty() else -1
		if nb >= 0:
			u.target[i] = bs.id[nb]   # on to the next unfinished building nearby, as the genre's builders do (Dominic)
			_approach_building(w, i, nb)
		elif not u.orders[i].is_empty() or not _back_to_work(w, i):
			clear_task(w, i)   # stays by the building: never off into the dark (Dominic: a builder vanished into the fog)
		return
	if _in_reach(w, i, _building_rect(w, b)):
		u.moving[i] = 0
		u.stuck[i] = 0
		var t: Dictionary = w.btypes[bs.kind[b]]
		var max_hp: int = w.bmods[bs.owner[b]][bs.kind[b]].hp
		var pct: int = w.types[u.kind[i]].build_pct   # research: a tick's work counts for more (an extra tick every 100 / pct)
		var step := 1
		if pct != 0:
			u.work[i] += 1
			step += u.work[i] * pct / 100 - (u.work[i] - 1) * pct / 100
		bs.progress[b] = mini(t.build_ticks, bs.progress[b] + step)
		bs.hp[b] = maxi(1, max_hp * bs.progress[b] / t.build_ticks)
		if bs.progress[b] >= t.build_ticks:
			bs.done[b] = 1
			bs.hp[b] = max_hp
			if not t.becomes.is_empty():
				_become_ground(w, b, i)
			elif not t.pen.is_empty():
				Pens.opened(w, b)   # a pen: walked into
			else:
				_gather_after_camp(w, b)
	elif u.moving[i] == 0:
		if u.stuck[i] >= GIVE_UP:
			clear_task(w, i)
		else:
			_approach_building(w, i, b)


## The nearest unfinished building of the worker's owner within NEXT_BUILD_TILES of it, on
## ground its owner has explored (lowest index on ties), or -1.
static func _nearby_foundation(w, i: int) -> int:
	var u = w.units
	var bs = w.buildings
	var best := -1
	var best_d2: int = NEXT_BUILD_TILES * NEXT_BUILD_TILES * SimMap.TILE * SimMap.TILE + 1
	for b in bs.count():
		if bs.owner[b] != u.owner[i] or bs.done[b] == 1 or not _explored(w, u.owner[i], (bs.cy[b] + bs.sy[b] / 2) * w.map.width + bs.cx[b] + bs.sx[b] / 2):
			continue
		var d2 := Fixed.dist2(u.x[i], u.y[i], bs.cx[b] * SimMap.TILE + bs.sx[b] * SimMap.TILE / 2, bs.cy[b] * SimMap.TILE + bs.sy[b] * SimMap.TILE / 2)
		if d2 < best_d2:
			best_d2 = d2
			best = b
	return best


## A builder done (nothing queued, no foundation near): back to the resource it gathered before
## building (its `home`; another tile of it near there if that one's used up) when that's within
## BACK_TO_WORK_TILES of it. Whether it went.
static func _back_to_work(w, i: int) -> bool:
	var u = w.units
	var h: int = u.home[i]
	var kind: int = u.carry_kind[i]
	if h < 0 or kind <= 0:
		return false
	var hx: int = (h % w.map.width) * SimMap.TILE + SimMap.TILE / 2
	var hy: int = (h / w.map.width) * SimMap.TILE + SimMap.TILE / 2
	var far := BACK_TO_WORK_TILES * SimMap.TILE
	if Fixed.dist2(u.x[i], u.y[i], hx, hy) > far * far:
		return false
	if kind_of(w, w.map.resource_at(h)) != kind or w.map.amount[h] <= 0:
		h = nearest_resource(w, hx, hy, kind, i, false, false, true)
		if h < 0:
			return false
	start_gather(w, i, h, kind)
	return true


## Has this player ever seen cell c? (Automatic choices never send a worker into the unknown.)
static func _explored(w, player: int, c: int) -> bool:
	return player >= w.fog.size() or w.fog[player][c] != 0


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
			var c := nearest_resource(w, u.x[j], u.y[j], kind, j, false, false, true)
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
	w.map.make_pool(cells, w.map.terrain_ids.find(t.becomes.land if land else t.becomes.water), farm_food(w, bs.owner[b], bs.kind[b]))
	if w.units.orders[i].is_empty():
		start_gather(w, i, cells[0], kind_of(w, "food"))
	else:
		clear_task(w, i)   # told what to do after (shift): that comes first, not farming forever


## Reseed a worked-out farm: pay, crops again, the workers start the harvest.
static func cmd_reseed(w, player: int, a: Dictionary) -> void:
	var b: int = w.buildings.index_of(int(a.building))
	if b < 0 or w.buildings.owner[b] != player or not reseed(w, b):
		return
	var cells: PackedInt32Array = w.buildings.footprint(b, w.map.width)
	for i in _own_workers(w, player, a.ids):
		start_gather(w, i, cells[0], kind_of(w, "food"))


## Reseed finished farm b if it's worked out and its owner can pay: crops again. Whether it was.
static func reseed(w, b: int) -> bool:
	var p: int = w.buildings.owner[b]
	var t: Dictionary = w.btypes[w.buildings.kind[b]]
	var cells: PackedInt32Array = w.buildings.footprint(b, w.map.width)
	var to: int = w.map.terrain_reseed[w.map.terrain[cells[0]]]
	if w.buildings.done[b] == 0 or t.becomes.is_empty() or w.map.left_at(cells[0]) > 0 or to < 0 or not w.can_afford(p, t.reseed):
		return false
	w.pay(p, t.reseed)
	w.map.make_pool(cells, to, farm_food(w, p, w.buildings.kind[b]))
	return true


## The finished farm of `player` whose crops cover `cell`, or -1.
static func farm_at(w, cell: int, player: int) -> int:
	if w.map.pool[cell] < 0:
		return -1
	var b: int = w.buildings.index_of(w.map.occupied[cell])
	if b < 0 or w.buildings.owner[b] != player or w.buildings.done[b] == 0 or w.btypes[w.buildings.kind[b]].becomes.is_empty():
		return -1
	return b


## Farmer i just took the last of its farm's food: the farm-done event (a sound and a line for
## its owner) and, with auto-reseed on and the wood there, crops again at once; the farmer
## keeps farming. Otherwise it lies fallow and the farmer waits by it (_fallow).
static func _farm_done(w, i: int, cell: int) -> void:
	var b := farm_at(w, cell, w.units.owner[i])
	if b < 0:
		return
	var p: int = w.buildings.owner[b]
	var again: bool = w.auto_reseed[p] == 1 and reseed(w, b)
	var bs = w.buildings
	w.events.append({"type": "farm_done", "player": p, "building": bs.id[b], "reseeded": again,
		"x": bs.cx[b] * SimMap.TILE + bs.sx[b] * SimMap.TILE / 2, "y": bs.cy[b] * SimMap.TILE + bs.sy[b] * SimMap.TILE / 2})


## A farmer by its worked-out farm takes what it carries home first (and comes back), then
## waits by the farm, its place there kept (one farmer per farm). Every WAIT_TICKS it looks
## again: reseeded meanwhile (by hand, or auto-reseed can pay now), it farms on; else a free
## farm with crops nearby, it goes there. It never wanders off to other work (Dominic).
static func _fallow(w, i: int, cell: int, kind: int) -> void:
	var u = w.units
	if u.carry[i] > 0:
		_to_drop_off(w, i)
		return
	if _in_reach(w, i, _cell_rect(w, cell)):
		u.moving[i] = 0
		u.stuck[i] = 0
	elif u.moving[i] == 0 and u.stuck[i] < GIVE_UP:
		_approach_cell(w, i, cell)
	u.work[i] += 1
	if u.work[i] < WAIT_TICKS:
		return
	u.work[i] = 0
	if w.auto_reseed[u.owner[i]] == 1 and reseed(w, farm_at(w, cell, u.owner[i])):
		return   # crops again: back to work next tick
	var other := nearest_resource(w, u.x[i], u.y[i], kind, i, true, false, true)
	if other >= 0:
		start_gather(w, i, other, kind)


## The food a player's farm of type k holds when sown or reseeded (research: its `food` pct).
static func farm_food(w, player: int, k: int) -> int:
	return int(w.btypes[k].food) * (100 + int(w.bmods[player][k].pct.get("food", 0))) / 100


## A farm torn down leaves plain ground (or water) behind.
static func clear_farm(w, b: int) -> void:
	var t: Dictionary = w.btypes[w.buildings.kind[b]]
	if t.becomes.is_empty() or w.buildings.done[b] == 0:
		return
	var cells: PackedInt32Array = w.buildings.footprint(b, w.map.width)
	var to: int = w.map.terrain_cleared[w.map.terrain[cells[0]]]
	if to >= 0:
		w.map.clear_pool(cells, to)


## Walk up to a resource tile: to the worker's own spot round it while it gathers there (taking
## the nearest free one if it holds none, or lost it), else anywhere in reach (a farm, or no room).
static func _approach_cell(w, i: int, cell: int) -> void:
	var u = w.units
	if u.home[i] == cell and spotted(w, cell):
		if u.gspot[i] < 0 or _spot_held(w, cell, u.gspot[i], i):
			u.gspot[i] = free_spot(w, i, cell)
		if u.gspot[i] >= 0:
			var p := spot_at(w, i, cell, u.gspot[i])
			w.order_move(i, p.x, p.y, w.SLOT_ARRIVE, 0, -1, -1, 0, true)   # by the spot's own field: round the clump if need be
			return
	w.order_reach(i, _cell_rect(w, cell), w.cell_field(cell, true, w.lane(i)))


## Do gatherers at this tile stand at spots round it? Not on a farm (its farmer works it from
## anywhere); otherwise as its resource says (data/resources.json "spots").
static func spotted(w, cell: int) -> bool:
	if w.map.pool[cell] >= 0:
		return false
	var k := kind_of(w, w.map.resource_at(cell))
	return k > 0 and w.gather_spots[k - 1] != 0


## Only the four side spots round this tile (a tree: "spots": "sides")?
static func _sides_only(w, cell: int) -> bool:
	var k := kind_of(w, w.map.resource_at(cell))
	return k > 0 and w.gather_spots[k - 1] == SIDES


## Is there open ground to stand on beside this spotted tile (a side, or for an eight-spot
## resource a corner too) in unit i's lane (lane 0 without one)? A tree with trees all round
## it can't be worked: only the forest's edge can.
static func _open(w, cell: int, i := -1) -> bool:
	var ln: int = w.lane(i) if i >= 0 else 0
	var x: int = cell % w.map.width
	var y: int = cell / w.map.width
	var step := 2 if _sides_only(w, cell) else 1
	for k in range(0, SPOTS, step):
		if w.map.cell_walkable(x + SPOT_DX[k], y + SPOT_DY[k], ln):
			return true
	return false


## Where worker i stands at spot k round resource tile `cell`: off the middle of an edge, or off
## a corner, its body clear of the tile and in reach of it; (-1, -1) if that ground is blocked.
static func spot_at(w, i: int, cell: int, k: int) -> Vector2i:
	var t := SimMap.TILE
	var r: int = w.units.radius[i]
	var dx: int = SPOT_DX[k]
	var dy: int = SPOT_DY[k]
	var off := r + SPOT_GAP
	if dx != 0 and dy != 0:
		off = (r + REACH - 60) * 707 / 1000   # a corner: as far out on the diagonal as reach allows
	var x0: int = (cell % w.map.width) * t
	var y0: int = (cell / w.map.width) * t
	var x: int = x0 + t / 2 if dx == 0 else (x0 - off if dx < 0 else x0 + t - 1 + off)
	var y: int = y0 + t / 2 if dy == 0 else (y0 - off if dy < 0 else y0 + t - 1 + off)
	var ln: int = w.lane(i)
	if not w.map.walkable(x, y, ln):
		return Vector2i(-1, -1)
	var p: Vector2i = w._off_walls(x, y, r, ln)
	var ex := maxi(maxi(x0 - p.x, 0), p.x - (x0 + t - 1))
	var ey := maxi(maxi(y0 - p.y, 0), p.y - (y0 + t - 1))
	if ex * ex + ey * ey > (r + REACH - 20) * (r + REACH - 20):
		return Vector2i(-1, -1)   # pushed off a wall out of reach
	return p


## Does another gatherer hold spot k round `cell`, or one so close it would stand in it (a spot
## of a neighbouring tile of the clump)?
static func _spot_held(w, cell: int, k: int, i: int) -> bool:
	var p := spot_at(w, i, cell, k)
	return p.x < 0 or _crowded(w, i, p, _held_near(w, cell, i))


## The spots held round tiles within two of `cell` by gatherers other than i, and where builders
## at work stand near it: [x, y, radius] each.
static func _held_near(w, cell: int, i: int) -> Array:
	var u = w.units
	var mw: int = w.map.width
	var out := []
	for j in u.count():
		if j == i:
			continue
		var h: int = u.home[j]
		if h >= 0 and u.gspot[j] >= 0 and (u.task[j] == GATHER or u.task[j] == RETURN):
			if absi(h % mw - cell % mw) <= 2 and absi(h / mw - cell / mw) <= 2:
				var q := spot_at(w, j, h, u.gspot[j])
				out.append([q.x, q.y, u.radius[j]])
		elif u.task[j] == BUILD and u.moving[j] == 0:
			var c: int = w.map.cell_of(u.x[j], u.y[j])
			if absi(c % mw - cell % mw) <= 2 and absi(c / mw - cell / mw) <= 2:
				out.append([u.x[j], u.y[j], u.radius[j]])
	return out


## Would a body of unit i at p stand in a held spot (overlapping it by more than SPOT_GAP)?
static func _crowded(w, i: int, p: Vector2i, held: Array) -> bool:
	var r: int = w.units.radius[i]
	for q in held:
		var rr: int = r + q[2] - SPOT_GAP
		if Fixed.dist2(p.x, p.y, q[0], q[1]) < rr * rr:
			return true
	return false


## The free spot round `cell` nearest worker i (lowest k on ties), or -1 (a farm, or all held or blocked).
static func free_spot(w, i: int, cell: int) -> int:
	if not spotted(w, cell):
		return -1
	var u = w.units
	var held := _held_near(w, cell, i)
	var best := -1
	var best_d := 1 << 62
	for k in range(0, SPOTS, 2 if _sides_only(w, cell) else 1):
		var p := spot_at(w, i, cell, k)
		if p.x < 0 or _crowded(w, i, p, held):
			continue
		var d := Fixed.dist2(u.x[i], u.y[i], p.x, p.y)
		if d < best_d:
			best_d = d
			best = k
	return best


static func _approach_building(w, i: int, b: int) -> void:
	w.order_reach(i, _building_rect(w, b), w.building_field(w.buildings.id[b], true, w.lane(i)))


static func _cell_rect(w, cell: int) -> Rect2i:
	var x: int = (cell % w.map.width) * SimMap.TILE
	var y: int = (cell / w.map.width) * SimMap.TILE
	return Rect2i(x, y, SimMap.TILE - 1, SimMap.TILE - 1)


## The rect a unit works on or attacks building b from: its footprint, or a diagonal gate's middle
## cell (its square's corners are open ground on either side of the wall; every cell beside the
## middle one is beside the gate).
static func _building_rect(w, b: int) -> Rect2i:
	var bs = w.buildings
	if bs.diag[b] != 0:
		return _cell_rect(w, (bs.cy[b] + bs.sy[b] / 2) * w.map.width + bs.cx[b] + bs.sx[b] / 2)
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
## clump of bushes or a reed bed instead of piling everyone onto one tile. A farm full
## without unit i is passed over.
static func least_busy(w, cell: int, kind: int, except := -1, i := -1) -> int:
	var m = w.map
	var u = w.units
	var cx: int = cell % m.width
	var cy: int = cell / m.width
	var best := cell
	var best_score := 1 << 62
	var busy := {}   # cell -> gatherers working it
	for j in u.count():
		if u.home[j] >= 0 and (u.task[j] == GATHER or u.task[j] == RETURN):
			busy[u.home[j]] = int(busy.get(u.home[j], 0)) + 1
	for yy in range(maxi(cy - SPREAD_TILES, 0), mini(cy + SPREAD_TILES + 1, m.height)):
		for xx in range(maxi(cx - SPREAD_TILES, 0), mini(cx + SPREAD_TILES + 1, m.width)):
			var c: int = yy * m.width + xx
			if c == except or m.amount[c] <= 0 or kind_of(w, m.resource_at(c)) != kind or taken(w, c, i):
				continue
			if spotted(w, c) and not _open(w, c, i):
				continue   # no ground beside it to stand on
			var score: int = int(busy.get(c, 0)) * BUSY_COST + Fixed.dist2(cx * 1000, cy * 1000, xx * 1000, yy * 1000)
			if i >= 0 and busy.has(c) and spotted(w, c) and free_spot(w, i, c) < 0:
				score += 1 << 40   # no room round it: only if no tile near has any
			if score < best_score:
				best_score = score
				best = c
	return best


## The nearest cell with this resource within SEARCH_TILES, or -1. Ties go to the lower cell.
## Spotted tiles with no open ground beside them are passed over. With a worker i, farms full
## without it are too, and with `seen` tiles its owner has never explored (a worker's own pick, away
## from where it was sent: it never wanders off into the dark on its own); `farms` keeps to farms; `roomy`
## keeps to tiles with a free spot round them for it (tiles without spots, as farms, count as roomy).
static func nearest_resource(w, x: int, y: int, kind: int, i := -1, farms := false, roomy := false, seen := false) -> int:
	var m = w.map
	var cx: int = x / SimMap.TILE
	var cy: int = y / SimMap.TILE
	var best := -1
	var best_d2 := 1 << 62
	for yy in range(maxi(cy - SEARCH_TILES, 0), mini(cy + SEARCH_TILES + 1, m.height)):
		for xx in range(maxi(cx - SEARCH_TILES, 0), mini(cx + SEARCH_TILES + 1, m.width)):
			var c: int = yy * m.width + xx
			if m.amount[c] <= 0 or kind_of(w, m.resource_at(c)) != kind or (farms and m.pool[c] < 0):
				continue
			var d2 := Fixed.dist2(x, y, xx * SimMap.TILE + 500, yy * SimMap.TILE + 500)
			if d2 >= best_d2 or (i >= 0 and taken(w, c, i)) or (seen and not _explored(w, w.units.owner[i], c)) or (spotted(w, c) and not _open(w, c, i)):
				continue   # (`seen`: only ground its owner has explored; a tile with ground beside it to stand on)
			if roomy and spotted(w, c) and free_spot(w, i, c) < 0:
				continue   # (roomy: a tile with a free spot round it)
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
	for b in w.buildings.count():   # those sheltering inside (garrison.gd) still count
		for rec in w.buildings.inside[b]:
			w.pop[w.buildings.owner[b]] += w.types[rec[1]].pop   # Garrison.REC_KIND
	for b in w.buildings.count():
		if w.buildings.done[b] == 1:
			var p: int = w.buildings.owner[b]
			var t: Dictionary = w.btypes[w.buildings.kind[b]]
			var add: int = t.pop
			if add > 0:
				add += int(w.bmods[p][w.buildings.kind[b]].add.get("pop", 0))   # (rodents' houses hold 6: Tech.refresh)
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
		if t.hero:
			Heroes.spawned(w, i)
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
	var best := spawn_cell(w, b, k)
	var t: Dictionary = w.types[k]
	var i: int = w.units.add(w.next_id, bs.owner[b], k, (best % m.width) * SimMap.TILE + 500,
		(best / m.width) * SimMap.TILE + 500, t.speed, t.radius, t.hp)
	w.units.mclass[i] = t.mclass
	w.units.posture[i] = t.posture
	w.next_id += 1
	return i


## The walkable cell beside building b nearest its rally point (or its front corner), for a
## unit of type k coming out of it; -1 when it's walled in and not `strict`.
static func spawn_cell(w, b: int, k: int, strict := true) -> int:
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
	assert(best >= 0 or not strict, "Building %d is walled in; nowhere to spawn" % bs.id[b])
	return best
