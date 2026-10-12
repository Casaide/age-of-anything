extends RefCounted
## Fog of war: per player, a byte per cell: 0 never seen, 1 explored (seen before), 2 visible
## now. Allies share sight. Stamped from every unit's and finished building's sight radius (rules.fog,
## in tiles) as integer circles, every rules.fog.every ticks: one team at a time, the teams'
## turns spread over those ticks (two teams: one every other tick), so no tick does them all.
## Derived from the units and buildings, so it isn't hashed; the AI reads it to play fair, and the view draws it.
##
## Each player also remembers the map as they last saw it (the genre's remembered state): the
## ground per cell (`fog_ground`, a terrain index, and `fog_left`, what was left there) starts as
## the map as made and follows the truth only where the player sees now, so a farm sown in the
## dark stays grass to them until they look; and the enemy buildings they've seen (`fog_seen`,
## id -> [kind, owner, cx, cy, sx, done, progress, age, sy, diag]), kept as last seen until they see the
## spot empty. Only cells that held a resource or ever changed (`fog_watch`) are compared.

const Buildings := preload("res://src/sim/buildings.gd")

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
	w.fog_lit = []
	w.fog_ground = []
	w.fog_left = []
	w.fog_seen = []
	w.fog_watch = PackedByteArray()
	w.fog_watch.resize(w.map.width * w.map.height)
	w.fog_watch_cells = PackedInt32Array()
	for c in w.map.resource_cells:
		_watch(w, c)
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
		w.fog_lit.append(PackedInt32Array())
	_update(w)


static func tick(w) -> void:
	for c in w.map.fresh:   # cells that changed this tick (before the World clears the list)
		_watch(w, c)
	var every: int = w.fog_cfg.every
	var teams := _teams(w)
	for k in teams.size():
		if w.tick % every == k * every / teams.size():   # each team on its own tick of the cycle
			_update_team(w, teams[k])


static func _watch(w, c: int) -> void:
	if w.fog_watch[c] == 0:
		w.fog_watch[c] = 1
		w.fog_watch_cells.append(c)


## The players of each team, teams in order of their first player.
static func _teams(w) -> Array:
	var out := []
	var at := {}
	for p in w.races.size():
		if not at.has(w.teams[p]):
			at[w.teams[p]] = out.size()
			out.append([])
		out[at[w.teams[p]]].append(p)
	return out


## Is (x, y) in milli-tiles visible to this player right now?
static func visible(w, player: int, x: int, y: int) -> bool:
	return w.fog[player][w.map.cell_of(x, y)] == VISIBLE


static func explored(w, player: int, cx: int, cy: int) -> bool:
	return w.fog[player][cy * w.map.width + cx] != UNSEEN


## Does this player see any tile of the cx, cy, sx by sy footprint right now? (`diag`: only the
## cells of a diagonal gate, Buildings.cells.)
static func sees_area(w, player: int, cx: int, cy: int, sx: int, sy: int, diag := 0) -> bool:
	var g: PackedByteArray = w.fog[player]
	if diag != 0:
		for c in Buildings.cells(cx, cy, sx, sy, diag, w.map.width):
			if g[c] == VISIBLE:
				return true
		return false
	for y in range(cy, cy + sy):
		for x in range(cx, cx + sx):
			if g[y * w.map.width + x] == VISIBLE:
				return true
	return false


static func _update(w) -> void:
	for team in _teams(w):
		_update_team(w, team)


## Restamp one team's sight. Allies share sight, so they also remember the same: the first
## player's grid and memory are worked out, the others' copied from it.
static func _update_team(w, team: Array) -> void:
	var cfg: Dictionary = w.fog_cfg
	var p: int = team[0]
	var g: PackedByteArray = w.fog[p]
	for c in w.fog_lit[p]:   # what was in sight is explored now (only those cells, not the whole map)
		g[c] = EXPLORED
	var lit := PackedInt32Array()
	var stamped := {}   # cell * 64 + radius: units standing together see the same circle once
	for i in w.units.count():
		if w.teams[w.units.owner[i]] == w.teams[p]:
			var t: Dictionary = w.types[w.units.kind[i]]
			var r: int = (cfg.worker if t.worker else cfg.unit) + int(t.sight_add)   # research adds sight (Tech.retype)
			if w.map.has_heights:
				r += w.map.level_at(w.units.x[i], w.units.y[i]) * int(w.high.sight_unit)   # high ground sees further
			var key: int = (w.units.y[i] / 1000 * w.map.width + w.units.x[i] / 1000) * 64 + r
			if stamped.has(key):
				continue
			stamped[key] = true
			_stamp(w, g, lit, w.units.x[i] / 1000, w.units.y[i] / 1000, r)
	var bs = w.buildings
	for b in bs.count():
		if w.teams[bs.owner[b]] == w.teams[p] and bs.done[b] == 1:   # a foundation sees nothing: laid in the dark, it stays dark (Dominic)
			var t: Dictionary = w.btypes[bs.kind[b]]
			var r: int = t.sight if t.sight > 0 else (cfg.tower if t.attack.size() > 0 and t.arrows > 0 else cfg.building)   # data's own sight, else by kind
			r += int(w.bmods[bs.owner[b]][bs.kind[b]].add.get("sight", 0))   # research (Tech.refresh)
			if w.map.has_heights:
				r += w.map.level[bs.cy[b] * w.map.width + bs.cx[b]] * int(w.high.sight_building)   # a tower on a hill sees further
			_stamp(w, g, lit, bs.cx[b] + bs.sx[b] / 2, bs.cy[b] + bs.sy[b] / 2, r + maxi(bs.sx[b], bs.sy[b]) / 2)
	w.fog[p] = g
	w.fog_lit[p] = lit
	_remember(w, p)
	for k in range(1, team.size()):
		var a: int = team[k]
		w.fog[a] = g.duplicate()
		w.fog_lit[a] = lit
		w.fog_ground[a] = w.fog_ground[p].duplicate()
		w.fog_left[a] = w.fog_left[p].duplicate()
		w.fog_seen[a] = w.fog_seen[p].duplicate(true)


## What player p sees now overwrites what they remember: the ground, and enemy buildings
## (seen ones kept as they are now; remembered ones whose spot is seen empty forgotten).
static func _remember(w, p: int) -> void:
	var g: PackedByteArray = w.fog[p]
	var m = w.map
	var ground: PackedByteArray = w.fog_ground[p]
	var left: PackedInt32Array = w.fog_left[p]
	# Only cells that hold a resource or ever changed (watched) can differ from the map as made;
	# of those, the ones in sight: walk whichever list is shorter.
	var lit: PackedInt32Array = w.fog_lit[p]
	var watch: PackedByteArray = w.fog_watch
	if lit.size() < w.fog_watch_cells.size():
		for c in lit:
			if watch[c] == 1:
				ground[c] = m.terrain[c]
				left[c] = m.amount[m.pool[c]] if m.pool[c] >= 0 else m.amount[c]
	else:
		for c in w.fog_watch_cells:
			if g[c] == VISIBLE:
				ground[c] = m.terrain[c]
				left[c] = m.amount[m.pool[c]] if m.pool[c] >= 0 else m.amount[c]
	w.fog_ground[p] = ground
	w.fog_left[p] = left
	var seen: Dictionary = w.fog_seen[p]
	var bs = w.buildings
	for b in bs.count():
		if w.teams[bs.owner[b]] != w.teams[p] and sees_area(w, p, bs.cx[b], bs.cy[b], bs.sx[b], bs.sy[b], bs.diag[b]):
			seen[bs.id[b]] = PackedInt32Array([bs.kind[b], bs.owner[b], bs.cx[b], bs.cy[b], bs.sx[b], bs.done[b], bs.progress[b], w.ages[bs.owner[b]], bs.sy[b], bs.diag[b]])
	var gone := []
	for id in seen:
		var s: PackedInt32Array = seen[id]
		if bs.index_of(id) < 0 and sees_area(w, p, s[2], s[3], s[4], s[8], s[9]):
			gone.append(id)
	for id in gone:
		seen.erase(id)


## Light a sight circle in grid g; cells newly lit go on `lit` (they turn explored next time).
static func _stamp(w, g: PackedByteArray, lit: PackedInt32Array, cx: int, cy: int, r: int) -> void:
	var wd: int = w.map.width
	var ht: int = w.map.height
	var v: int = w.map.level[cy * wd + cx]
	if _blocked_near(w.map, cx, cy, r, v):
		_stamp_los(w.map, g, lit, cx, cy, r, v)
		return
	var offs := _circle(r)
	for k in range(0, offs.size(), 2):
		var x := cx + offs[k]
		var y := cy + offs[k + 1]
		if x >= 0 and y >= 0 and x < wd and y < ht:
			var c := y * wd + x
			if g[c] != VISIBLE:
				g[c] = VISIBLE
				lit.append(c)


## Is there anything that blocks sight (a tree, or ground higher than the viewer's level v)
## within r of (cx, cy)? Counted per chunk, so open country costs a few lookups and the plain
## stamp runs.
static func _blocked_near(m, cx: int, cy: int, r: int, v: int) -> bool:
	var C: int = m.CHUNK
	var cw: int = (m.width + C - 1) / C
	var ch: int = (m.height + C - 1) / C
	for y in range(maxi(cy - r, 0) / C, mini((cy + r) / C, ch - 1) + 1):
		for x in range(maxi(cx - r, 0) / C, mini((cx + r) / C, cw - 1) + 1):
			if m.opaque_chunks[y * cw + x] > 0 or m.level_chunks[y * cw + x] > v:
				return true
	return false


## The circle with line of sight: a cell is seen if the cell before it on the line from the
## centre was seen and doesn't block (the first tree of a forest is seen, not what's behind it).
## Ground higher than the viewer's level v blocks like a tree: from below you see a hill's rim,
## not what stands on it beyond the edge.
static func _stamp_los(m, g: PackedByteArray, lit: PackedInt32Array, cx: int, cy: int, r: int, v: int) -> void:
	var rays: Array = _ray_table(r)
	var offs: PackedInt32Array = rays[0]
	var par: PackedInt32Array = rays[1]
	var wd: int = m.width
	var ht: int = m.height
	var op: PackedByteArray = m.opaque
	var lv: PackedByteArray = m.level
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
		if g[c] != VISIBLE:
			g[c] = VISIBLE
			lit.append(c)
		seen[k] = 1 if (op[c] == 1 or lv[c] > v) and k > 0 else 2


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
