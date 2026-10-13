extends RefCounted
## Game modes (milestone 16) on the match rules (milestone 18's contract, its first piece): the host's
## rules carry `mode`, an id in data/modes.json (none, or "standard": the usual match). Applied once
## at World setup, after the usual start (Economy.setup) and before the match's own bookkeeping
## (Match.setup: a side set up without a Town Center isn't knocked out for having none); the
## mode's win rules on Match's check beat (Match.tick calls tick here). Static functions over the
## World `w`, integers only, slot order, no Nodes.
##
## Fortress: every side the same start (walls, garrison, age, stock). Siege: player 0's team
## defends (data `defend`), everyone else attacks (`attack`); the attackers are out once they've
## nothing left; the defenders win when hold_minutes run out.

const SimMap := preload("res://src/sim/sim_map.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const Flow := preload("res://src/sim/flow.gd")
const Economy := preload("res://src/sim/economy.gd")
const Tech := preload("res://src/sim/tech.gd")
const Fortify := preload("res://src/sim/fortify.gd")
const Walls := preload("res://src/sim/walls.gd")


static func load_modes() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/modes.json"))
	assert(d != null and d.schema == "aow.modes/1", "Bad or missing data/modes.json")
	return d.modes


## The mode's start for every side. Sets w.mode and w.mode_cfg (the mode's data).
static func setup(w) -> void:
	var id: String = w.rules.get("mode", "")
	if id == "" or id == "standard":
		return
	var modes := load_modes()
	assert(modes.has(id), "Unknown mode %s" % id)
	w.mode = id
	w.mode_cfg = _ints(modes[id])
	_lift_lacks(w, w.mode_cfg.get("lift_lacks", []))
	for p in w.races.size():
		if p >= w.map.starts.size():
			continue
		_start(w, p, side_of(w, p))


## The mode fills the gap (Dominic, 2026-10-13: "just in siege mode we fill the gap"): every side
## can build and repair what the mode lists (walls, gates, wall towers) whatever its race lacks in a
## normal match. Each side's identity is its own copy (Identity.of shares one per race).
static func _lift_lacks(w, ids: Array) -> void:
	if ids.is_empty():
		return
	for p in w.ident.size():
		var ident: Dictionary = w.ident[p].duplicate(true)
		for id in ids:
			ident.lacks.erase(id)
		w.ident[p] = ident


## A side's start in the mode: the mode itself, or its defend / attack part.
static func side_of(w, p: int) -> Dictionary:
	var m: Dictionary = w.mode_cfg
	if not m.has("defend"):
		return m
	return m.defend if w.teams[p] == w.teams[0] else m.attack


## Numbers as ints, the rest as it is (as the World's own _ints).
static func _ints(v):
	match typeof(v):
		TYPE_FLOAT:
			return int(v)
		TYPE_ARRAY:
			return v.map(_ints)
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[k] = _ints(v[k])
			return out
	return v


static func _start(w, p: int, s: Dictionary) -> void:
	var start: Array = w.map.starts[p]
	var cx: int = start[0] / SimMap.TILE
	var cy: int = start[1] / SimMap.TILE
	if s.has("age") and int(s.age) > w.ages[p]:
		w.ages[p] = int(s.age)
		Tech.retype(w, p)
		Tech.refresh(w, p)
	for r in s.get("stock", {}):
		var k: int = w.resources.find(r)
		if k >= 0:
			w.stock[k][p] = int(s.stock[r])
	if not bool(s.get("town", true)):
		_no_town(w, p)
	if s.has("walls"):
		Fortify.ring(w, p, cx, cy, int(s.walls.radius), s.walls)
	var tc := -1
	for b in w.buildings.count():
		if w.buildings.owner[b] == p and w.btypes[w.buildings.kind[b]].id == "town_center":
			tc = b
			break
	var worker: int = w.type_of(p, "worker")
	for n in int(s.get("workers", 0)):
		if tc >= 0:
			Economy.spawn_at(w, tc, worker)
		else:
			_put(w, p, worker, start[0], start[1])
	var foe := _enemy_start(w, p)
	var posts := _posts(w, p, foe)
	var slots: Array = s.get("garrison", {}).keys()
	slots.sort()
	var k := 0
	for slot in slots:
		var t: int = w.type_of(p, slot)
		if t < 0:
			continue
		for n in int(s.garrison[slot]):
			var i := _put(w, p, t, start[0], start[1])
			if k < posts.size() and Walls.can_climb(w, i):
				Walls.set_on(w, i, posts[k])
				k += 1
	slots = s.get("army", {}).keys()
	slots.sort()
	for slot in slots:
		var t: int = w.type_of(p, slot)
		if t < 0:
			continue
		for n in int(s.army[slot]):
			_put(w, p, t, start[0], start[1])
	Economy.update_pop(w)


## The side's Town Center and its starting workers go: it starts with what the mode gives it.
static func _no_town(w, p: int) -> void:
	for b in range(w.buildings.count() - 1, -1, -1):
		if w.buildings.owner[b] == p:
			Economy.demolish(w, b)
	for i in range(w.units.count() - 1, -1, -1):
		if w.units.owner[i] == p:
			w.units.remove_at(i)


## A unit of type k for player p near (x, y): jittered like a SPAWN, on open ground in its lane.
static func _put(w, p: int, k: int, x0: int, y0: int) -> int:
	var t: Dictionary = w.types[k]
	var x: int = x0 + w.rng.range_int(-2500, 2500)
	var y: int = y0 + w.rng.range_int(-2500, 2500)
	var ln: int = w.lane_base[p] + t.mclass
	if not w.map.walkable(x, y, ln):
		var c := Flow.centre(w.map, Flow.nearest_walkable(w.map, w.map.cell_of(x, y), ln))
		x = c.x
		y = c.y
	var i: int = w.units.add(w.next_id, p, k, x, y, t.speed, t.radius, t.hp)
	w.units.mclass[i] = t.mclass
	w.units.posture[i] = t.posture
	w.next_id += 1
	return i


## The nearest enemy start to p's (milli-tiles), or p's own if it has none.
static func _enemy_start(w, p: int) -> Vector2i:
	var s: Array = w.map.starts[p]
	var best := Vector2i(s[0], s[1])
	var best_d := 1 << 62
	for q in w.races.size():
		if q < w.map.starts.size() and w.is_enemy(p, q):
			var o: Array = w.map.starts[q]
			var d := Fixed.dist2(s[0], s[1], o[0], o[1])
			if d < best_d:
				best_d = d
				best = Vector2i(o[0], o[1])
	return best


## p's walkway cells, nearest `to` first (a place each, as many as the cell holds): where its
## garrison stands at the start.
static func _posts(w, p: int, to: Vector2i) -> Array:
	var cells := []
	var bs = w.buildings
	for b in bs.count():
		if bs.owner[b] == p and bs.done[b] == 1 and w.btypes[bs.kind[b]].walkway > 0:
			for c in bs.footprint(b, w.map.width):
				cells.append(c)
	var d := func(c: int) -> int: return Fixed.dist2((c % w.map.width) * SimMap.TILE + 500, (c / w.map.width) * SimMap.TILE + 500, to.x, to.y)
	cells.sort_custom(func(a, b): return d.call(a) < d.call(b) or (d.call(a) == d.call(b) and a < b))
	var out := []
	for c in cells:
		for n in Walls.places(w, c):
			out.append(c)
	return out


## The mode's win rules, on Match's beat: in Siege, an attacker with nothing left (no units, no
## buildings) is out, and when hold_minutes run out every attacker is.
static func tick(w) -> void:
	if not w.mode_cfg.has("defend"):
		return
	var over: bool = w.tick >= int(w.mode_cfg.get("hold_minutes", 0)) * 1200 and int(w.mode_cfg.get("hold_minutes", 0)) > 0
	for p in w.races.size():
		if w.defeated[p] != 0 or w.teams[p] == w.teams[0]:
			continue
		if over or not _has_anything(w, p):
			w.defeated[p] = w.tick + 1
			w.events.append({"type": "defeated", "player": p, "why": "time" if over else "routed"})


static func _has_anything(w, p: int) -> bool:
	for i in w.units.count():
		if w.units.owner[i] == p and not w.types[w.units.kind[i]].has("animal"):
			return true
	for b in w.buildings.count():
		if w.buildings.owner[b] == p:
			return true
	return false
