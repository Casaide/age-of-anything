extends RefCounted
## Fog of war: per player, a byte per cell: 0 never seen, 1 explored (seen before), 2 visible
## now. Allies share sight. Stamped from every unit's and building's sight radius (rules.fog,
## in tiles) as integer circles, every rules.fog.every ticks. Derived from the units and
## buildings, so it isn't hashed; the AI reads it to play fair, and the view draws it.
##
## Each player also remembers the map as they last saw it (the genre's remembered state): the
## ground per cell (`fog_ground`, a terrain index, and `fog_left`, what was left there) starts as
## the map as made and follows the truth only where the player sees now, so a farm sown in the
## dark stays grass to them until they look; and the enemy buildings they've seen (`fog_seen`,
## id -> [kind, owner, cx, cy, sx, done, progress, age, sy]), kept as last seen until they see the
## spot empty. Only cells that held a resource or ever changed (`fog_watch`) are compared.

const UNSEEN := 0
const EXPLORED := 1
const VISIBLE := 2

static var _circles := {}   # radius -> PackedInt32Array of (dx, dy) pairs
static var _rays := {}      # radius -> [offsets (dx, dy) pairs, nearest ring first; parent index per offset]


static func setup(w) -> void:
	var f: Dictionary = w.rules.get("fog", {})
	w.fog_cfg = {"every": int(f.get("every", 4)), "unit": int(f.get("unit", 6)), "worker": int(f.get("worker", 4)),
		"building": int(f.get("building", 4)), "tower": int(f.get("tower", 8))}
	w.fog = []
	w.fog_ground = []
	w.fog_left = []
	w.fog_seen = []
	w.fog_watch = {}
	for c in w.map.resource_cells:
		w.fog_watch[c] = true
	var left := PackedInt32Array()
	for c in w.map.width * w.map.height:
		left.append(w.map.left_at(c))
	for p in w.races.size():
		var g := PackedByteArray()
		g.resize(w.map.width * w.map.height)
		w.fog.append(g)
		w.fog_ground.append(w.map.terrain.duplicate())
		w.fog_left.append(left.duplicate())
		w.fog_seen.append({})
	_update(w)


static func tick(w) -> void:
	for c in w.map.fresh:   # cells that changed this tick (before the World clears the list)
		w.fog_watch[c] = true
	if w.tick % int(w.fog_cfg.every) == 0:
		_update(w)


## Is (x, y) in milli-tiles visible to this player right now?
static func visible(w, player: int, x: int, y: int) -> bool:
	return w.fog[player][w.map.cell_of(x, y)] == VISIBLE


static func explored(w, player: int, cx: int, cy: int) -> bool:
	return w.fog[player][cy * w.map.width + cx] != UNSEEN


## Does this player see any tile of the cx, cy, sx by sy footprint right now?
static func sees_area(w, player: int, cx: int, cy: int, sx: int, sy: int) -> bool:
	var g: PackedByteArray = w.fog[player]
	for y in range(cy, cy + sy):
		for x in range(cx, cx + sx):
			if g[y * w.map.width + x] == VISIBLE:
				return true
	return false


static func _update(w) -> void:
	var cfg: Dictionary = w.fog_cfg
	for p in w.races.size():
		var g: PackedByteArray = w.fog[p]
		for c in g.size():
			if g[c] == VISIBLE:
				g[c] = EXPLORED
		for i in w.units.count():
			if w.teams[w.units.owner[i]] == w.teams[p]:
				var t: Dictionary = w.types[w.units.kind[i]]
				var r: int = (cfg.worker if t.worker else cfg.unit) + int(t.sight_add)   # research adds sight (Tech.retype)
				_stamp(w, g, w.units.x[i] / 1000, w.units.y[i] / 1000, r)
		var bs = w.buildings
		for b in bs.count():
			if w.teams[bs.owner[b]] == w.teams[p]:
				var t: Dictionary = w.btypes[bs.kind[b]]
				var r: int = cfg.tower if t.get("attack", {}).size() > 0 else cfg.building
				r += int(w.bmods[bs.owner[b]][bs.kind[b]].add.get("sight", 0))   # research (Tech.refresh)
				_stamp(w, g, bs.cx[b] + bs.sx[b] / 2, bs.cy[b] + bs.sy[b] / 2, r + maxi(bs.sx[b], bs.sy[b]) / 2)
		w.fog[p] = g
		_remember(w, p)


## What player p sees now overwrites what they remember: the ground, and enemy buildings
## (seen ones kept as they are now; remembered ones whose spot is seen empty forgotten).
static func _remember(w, p: int) -> void:
	var g: PackedByteArray = w.fog[p]
	var m = w.map
	var ground: PackedByteArray = w.fog_ground[p]
	var left: PackedInt32Array = w.fog_left[p]
	for c in w.fog_watch:   # only cells that hold a resource or ever changed can differ from the map as made
		if g[c] == VISIBLE:
			ground[c] = m.terrain[c]
			left[c] = m.amount[m.pool[c]] if m.pool[c] >= 0 else m.amount[c]
	w.fog_ground[p] = ground
	w.fog_left[p] = left
	var seen: Dictionary = w.fog_seen[p]
	var bs = w.buildings
	for b in bs.count():
		if w.teams[bs.owner[b]] != w.teams[p] and sees_area(w, p, bs.cx[b], bs.cy[b], bs.sx[b], bs.sy[b]):
			seen[bs.id[b]] = PackedInt32Array([bs.kind[b], bs.owner[b], bs.cx[b], bs.cy[b], bs.sx[b], bs.done[b], bs.progress[b], w.ages[bs.owner[b]], bs.sy[b]])
	var gone := []
	for id in seen:
		var s: PackedInt32Array = seen[id]
		if bs.index_of(id) < 0 and sees_area(w, p, s[2], s[3], s[4], s[8]):
			gone.append(id)
	for id in gone:
		seen.erase(id)


static func _stamp(w, g: PackedByteArray, cx: int, cy: int, r: int) -> void:
	var wd: int = w.map.width
	var ht: int = w.map.height
	if _blocked_near(w.map, cx, cy, r):
		_stamp_los(w.map, g, cx, cy, r)
		return
	var offs := _circle(r)
	for k in range(0, offs.size(), 2):
		var x := cx + offs[k]
		var y := cy + offs[k + 1]
		if x >= 0 and y >= 0 and x < wd and y < ht:
			g[y * wd + x] = VISIBLE


## Is there anything that blocks sight (a tree) within r of (cx, cy)? Counted per chunk, so
## open country costs a few lookups and the plain stamp runs.
static func _blocked_near(m, cx: int, cy: int, r: int) -> bool:
	var C: int = m.CHUNK
	var cw: int = (m.width + C - 1) / C
	var ch: int = (m.height + C - 1) / C
	for y in range(maxi(cy - r, 0) / C, mini((cy + r) / C, ch - 1) + 1):
		for x in range(maxi(cx - r, 0) / C, mini((cx + r) / C, cw - 1) + 1):
			if m.opaque_chunks[y * cw + x] > 0:
				return true
	return false


## The circle with line of sight: a cell is seen if the cell before it on the line from the
## centre was seen and doesn't block (the first tree of a forest is seen, not what's behind it).
static func _stamp_los(m, g: PackedByteArray, cx: int, cy: int, r: int) -> void:
	var rays: Array = _ray_table(r)
	var offs: PackedInt32Array = rays[0]
	var par: PackedInt32Array = rays[1]
	var wd: int = m.width
	var ht: int = m.height
	var op: PackedByteArray = m.opaque
	var n := par.size()
	var seen := PackedByteArray()   # per offset: 1 seen, 2 seen and sight carries on past it
	seen.resize(n)
	for k in n:
		var x := cx + offs[k * 2]
		var y := cy + offs[k * 2 + 1]
		if x < 0 or y < 0 or x >= wd or y >= ht:
			continue
		if k > 0 and seen[par[k]] != 2:
			continue
		var c := y * wd + x
		g[c] = VISIBLE
		seen[k] = 1 if op[c] == 1 and k > 0 else 2


## Offsets of the sight circle ordered ring by ring (Chebyshev distance), each with the index
## of the offset one step nearer the centre on the line to it.
static func _ray_table(r: int) -> Array:
	if not _rays.has(r):
		var offs := _circle(r)
		var order := []
		for k in range(0, offs.size(), 2):
			order.append([maxi(absi(offs[k]), absi(offs[k + 1])), offs[k + 1], offs[k]])
		order.sort()
		var sorted := PackedInt32Array()
		var index := {}
		for o in order:
			index[Vector2i(o[2], o[1])] = sorted.size() / 2
			sorted.append(o[2])
			sorted.append(o[1])
		var par := PackedInt32Array()
		for k in order.size():
			var dx: int = sorted[k * 2]
			var dy: int = sorted[k * 2 + 1]
			var steps := maxi(absi(dx), absi(dy))
			if steps == 0:
				par.append(0)
				continue
			# One step back along the line, rounded half away from zero.
			var px := _round_div(dx * (steps - 1), steps)
			var py := _round_div(dy * (steps - 1), steps)
			par.append(index[Vector2i(px, py)])
		_rays[r] = [sorted, par]
	return _rays[r]


static func _round_div(a: int, b: int) -> int:
	return (a * 2 + (b if a >= 0 else -b)) / (2 * b)


static func _circle(r: int) -> PackedInt32Array:
	if not _circles.has(r):
		var offs := PackedInt32Array()
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dy * dy <= r * r + r:
					offs.append(dx)
					offs.append(dy)
		_circles[r] = offs
	return _circles[r]
