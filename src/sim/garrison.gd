extends RefCounted
## Garrisons (milestone 12): units sheltering inside their own buildings. A building type with
## "garrison": N (data/buildings.json: the Town Center, the towers, the Castle) holds up to N of
## its owner's units, none with a tag in the top-level garrison.not (riders and giants; workers always fit). Inside, a
## unit is out of the units arrays altogether: nothing sees it, hits it, pushes it or is seen by
## it (fog: the building sees only its own radius). It's kept on the building as a record (REC_*)
## and healed 1 hp every garrison.heal_every ticks; each one adds an arrow to the building's
## volley (combat.gd _towers). Coming out (ungarrison, back to work, or the building falling) it
## takes its old id and slot back (Units.insert), beside the building. Pop counts it all along.
##
## The Town Center's call to arms sends its owner's workers within garrison.call_range tiles of
## it into the nearest building with room; back to work brings every worker out again, each to
## the resource it was gathering (its `home`, kept while it shelters).
##
## Static functions over the World `w`, like economy.gd. Integers only, slot order, no Nodes.

const SimMap := preload("res://src/sim/sim_map.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const Economy := preload("res://src/sim/economy.gd")
const Flow := preload("res://src/sim/flow.gd")

## A sheltering unit's record (a PackedInt32Array): its id, type, health, stance, what it
## carries, and the resource cell it was gathering (-1: none).
enum { REC_ID, REC_KIND, REC_HP, REC_POSTURE, REC_CARRY_KIND, REC_CARRY, REC_HOME, REC_SIZE }


## Rules from data/buildings.json "garrison", as ints.
static func setup(w) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/buildings.json"))
	var g: Dictionary = d.get("garrison", {})
	w.garrison_cfg = {"heal_every": int(g.get("heal_every", 20)), "call_range": int(g.get("call_range", 16)), "not": g.get("not", []).duplicate()}


## How many building b holds once built (0: none).
static func capacity(w, b: int) -> int:
	return w.btypes[w.buildings.kind[b]].garrison if w.buildings.done[b] == 1 else 0


## Can unit i shelter in building b at all (its owner's, built, takes people, not an animal,
## none of the barred tags)? Room is checked apart.
static func can_hold(w, b: int, i: int) -> bool:
	var u = w.units
	if capacity(w, b) <= 0 or w.buildings.owner[b] != u.owner[i]:
		return false
	var t: Dictionary = w.types[u.kind[i]]
	if t.has("animal"):
		return false
	if t.worker:
		return true   # every race's workers fit (centaur workers are large too)
	for tag in w.garrison_cfg.not:
		if tag in t.eval.tags:
			return false
	return true


## Places left in building b: its capacity less those inside and those on their way in.
static func room(w, b: int) -> int:
	var bid: int = w.buildings.id[b]
	var u = w.units
	var coming := 0
	for i in u.count():
		if u.task[i] == Economy.GARRISON and u.target[i] == bid:
			coming += 1
	return capacity(w, b) - w.buildings.inside[b].size() - coming


## Send unit i into building b (it walks up and goes in). A worker keeps its `home`, the
## resource it was gathering, for back to work.
static func send(w, i: int, b: int) -> void:
	var u = w.units
	var home: int = u.home[i] if u.task[i] == Economy.GATHER or u.task[i] == Economy.RETURN else -1
	u.foe[i] = 0
	u.stance[i] = 0
	u.patient[i] = 0
	u.task[i] = Economy.GARRISON
	u.target[i] = w.buildings.id[b]
	u.home[i] = home
	u.work[i] = 0
	Economy._approach_building(w, i, b)


## Commands.GARRISON {ids, building}: these units go into the player's building, while it has room.
static func cmd_garrison(w, player: int, a: Dictionary) -> void:
	var b: int = w.buildings.index_of(a.building)
	if b < 0 or w.buildings.owner[b] != player:
		return
	for uid in a.ids:
		var i: int = w.units.index_of(uid)
		if i >= 0 and w.units.owner[i] == player and can_hold(w, b, i) and room(w, b) > 0:
			send(w, i, b)


## Commands.UNGARRISON {building}: everyone inside comes out, and makes for the rally point if it has one.
static func cmd_ungarrison(w, player: int, a: Dictionary) -> void:
	var b: int = w.buildings.index_of(a.building)
	if b < 0 or w.buildings.owner[b] != player:
		return
	for i in empty(w, b):
		Economy._go_to_rally(w, b, i)


## Commands.CALL_TO_ARMS {building}: the player's workers within call_range tiles of the building
## (a Town Center) each go into the nearest of the player's buildings with room, in id order.
static func cmd_call_to_arms(w, player: int, a: Dictionary) -> void:
	var b: int = w.buildings.index_of(a.building)
	if b < 0 or w.buildings.owner[b] != player:
		return
	var bs = w.buildings
	var u = w.units
	var r: int = int(w.garrison_cfg.call_range) * SimMap.TILE
	var c := _centre(w, b)
	var left := {}   # building slot -> places left, counted down as workers are sent
	for k in bs.count():
		if bs.owner[k] == player and capacity(w, k) > 0:
			left[k] = room(w, k)
	for i in u.count():
		if u.owner[i] != player or not w.types[u.kind[i]].worker or u.task[i] == Economy.GARRISON:
			continue
		if Fixed.dist2(u.x[i], u.y[i], c.x, c.y) > r * r:
			continue
		var best := -1
		var best_d := 1 << 62
		for k in bs.count():   # ascending slots: the lowest id wins a tie
			if left.get(k, 0) <= 0 or not can_hold(w, k, i):
				continue
			var kc := _centre(w, k)
			var d := Fixed.dist2(u.x[i], u.y[i], kc.x, kc.y)
			if d < best_d:
				best_d = d
				best = k
		if best >= 0:
			left[best] -= 1
			send(w, i, best)


## Commands.BACK_TO_WORK {}: every one of the player's workers inside a building, or on its way
## in, goes back to the resource it was gathering (else stands where it came out).
static func cmd_back_to_work(w, player: int, _a: Dictionary) -> void:
	var u = w.units
	for i in u.count():
		if u.owner[i] == player and u.task[i] == Economy.GARRISON and w.types[u.kind[i]].worker:
			_resume(w, i)
	var bs = w.buildings
	for b in bs.count():
		if bs.owner[b] != player:
			continue
		var recs: Array = bs.inside[b]
		for k in range(recs.size() - 1, -1, -1):
			if w.types[recs[k][REC_KIND]].worker:
				_resume(w, out(w, b, k))


## A worker back to its job: the resource it was gathering (or the nearest of the same nearby),
## else idle.
static func _resume(w, i: int) -> void:
	var u = w.units
	var home: int = u.home[i]
	Economy.clear_task(w, i)
	u.moving[i] = 0
	if home < 0:
		return
	var kind := Economy.kind_of(w, w.map.resource_at(home))
	if kind <= 0:
		kind = u.carry_kind[i]
		home = Economy.nearest_resource(w, u.x[i], u.y[i], kind, i, false, false, true) if kind > 0 else -1
	if home >= 0:
		Economy.start_gather(w, i, home, kind)


## Everyone inside building b comes out; their slots, in id order.
static func empty(w, b: int) -> Array:
	var ids := []
	while not w.buildings.inside[b].is_empty():
		ids.append(w.units.id[out(w, b, w.buildings.inside[b].size() - 1)])
	ids.sort()
	return ids.map(func(id): return w.units.index_of(id))


## The units inside building b come out (it was destroyed): they stand beside its ruins.
static func spill(w, b: int) -> void:
	empty(w, b)


## Record k of building b comes out, beside the building (nearest its rally point), with its
## old id, health, stance and load. Returns its slot.
static func out(w, b: int, k: int) -> int:
	var bs = w.buildings
	var rec: PackedInt32Array = bs.inside[b][k]
	bs.inside[b].remove_at(k)
	var kind: int = rec[REC_KIND]
	var t: Dictionary = w.types[kind]
	var cell := Economy.spawn_cell(w, b, kind, false)
	if cell < 0:   # a tower walled in: the nearest open ground
		cell = Flow.nearest_walkable(w.map, bs.cy[b] * w.map.width + bs.cx[b], w.lane_base[bs.owner[b]] + t.mclass)
	var i: int = w.units.insert(rec[REC_ID], bs.owner[b], kind, (cell % w.map.width) * SimMap.TILE + SimMap.TILE / 2,
		(cell / w.map.width) * SimMap.TILE + SimMap.TILE / 2, t.speed, t.radius, rec[REC_HP])
	var u = w.units
	u.mclass[i] = t.mclass
	u.posture[i] = rec[REC_POSTURE]
	u.carry_kind[i] = rec[REC_CARRY_KIND]
	u.carry[i] = rec[REC_CARRY]
	u.home[i] = rec[REC_HOME]
	w.events.append({"type": "ungarrison", "id": rec[REC_ID], "building": bs.id[b]})
	return i


## Unit i goes inside building b: out of the arrays, onto the building's record.
static func _enter(w, i: int, b: int) -> void:
	var u = w.units
	var rec := PackedInt32Array()
	rec.resize(REC_SIZE)
	rec[REC_ID] = u.id[i]
	rec[REC_KIND] = u.kind[i]
	rec[REC_HP] = u.hp[i]
	rec[REC_POSTURE] = u.posture[i]
	rec[REC_CARRY_KIND] = u.carry_kind[i]
	rec[REC_CARRY] = u.carry[i]
	rec[REC_HOME] = u.home[i]
	var recs: Array = w.buildings.inside[b]
	var at := 0
	while at < recs.size() and recs[at][REC_ID] < rec[REC_ID]:
		at += 1
	recs.insert(at, rec)
	w.events.append({"type": "garrison", "id": u.id[i], "building": w.buildings.id[b], "x": u.x[i], "y": u.y[i]})
	u.remove_at(i)


## One tick: units on their way in go in once beside their building (or give up when it's
## gone, full or out of reach); those inside heal. Runs after worker jobs, before the spatial
## buckets are built.
static func tick(w) -> void:
	var u = w.units
	var bs = w.buildings
	for i in range(u.count() - 1, -1, -1):
		if u.task[i] != Economy.GARRISON:
			continue
		var b: int = bs.index_of(u.target[i])
		if b < 0 or not can_hold(w, b, i) or bs.inside[b].size() >= capacity(w, b):
			Economy.clear_task(w, i)
			u.moving[i] = 0
		elif Economy._in_reach(w, i, Economy._building_rect(w, b)):
			_enter(w, i, b)
		elif u.moving[i] == 0:
			if u.stuck[i] >= Economy.GIVE_UP:
				Economy.clear_task(w, i)
			else:
				Economy._approach_building(w, i, b)
	if w.tick % int(w.garrison_cfg.heal_every) != 0:
		return
	for b in bs.count():
		var recs: Array = bs.inside[b]
		for k in recs.size():
			var rec: PackedInt32Array = recs[k]
			if rec[REC_HP] < w.types[rec[REC_KIND]].hp:
				rec[REC_HP] += 1
				recs[k] = rec   # a packed array is a copy once out of its Array


## Everyone sheltering in a player's buildings, as records (pop counts them).
static func count_pop(w, player: int) -> int:
	var n := 0
	var bs = w.buildings
	for b in bs.count():
		if bs.owner[b] == player:
			for rec in bs.inside[b]:
				n += w.types[rec[REC_KIND]].pop
	return n


static func _centre(w, b: int) -> Vector2i:
	var bs = w.buildings
	return Vector2i(bs.cx[b] * SimMap.TILE + bs.sx[b] * SimMap.TILE / 2, bs.cy[b] * SimMap.TILE + bs.sy[b] * SimMap.TILE / 2)
