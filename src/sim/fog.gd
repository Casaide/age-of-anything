extends RefCounted
## Fog of war: per player, a byte per cell: 0 never seen, 1 explored (seen before), 2 visible
## now. Allies share sight. Stamped from every unit's and building's sight radius (rules.fog,
## in tiles) as integer circles, every rules.fog.every ticks. Derived from the units and
## buildings, so it isn't hashed; the AI reads it to play fair, and the view draws it.

const UNSEEN := 0
const EXPLORED := 1
const VISIBLE := 2

static var _circles := {}   # radius -> PackedInt32Array of (dx, dy) pairs


static func setup(w) -> void:
	var f: Dictionary = w.rules.get("fog", {})
	w.fog_cfg = {"every": int(f.get("every", 4)), "unit": int(f.get("unit", 6)), "worker": int(f.get("worker", 4)),
		"building": int(f.get("building", 4)), "tower": int(f.get("tower", 8))}
	w.fog = []
	for p in w.races.size():
		var g := PackedByteArray()
		g.resize(w.map.width * w.map.height)
		w.fog.append(g)
	_update(w)


static func tick(w) -> void:
	if w.tick % int(w.fog_cfg.every) == 0:
		_update(w)


## Is (x, y) in milli-tiles visible to this player right now?
static func visible(w, player: int, x: int, y: int) -> bool:
	return w.fog[player][w.map.cell_of(x, y)] == VISIBLE


static func explored(w, player: int, cx: int, cy: int) -> bool:
	return w.fog[player][cy * w.map.width + cx] != UNSEEN


static func _update(w) -> void:
	var cfg: Dictionary = w.fog_cfg
	for p in w.races.size():
		var g: PackedByteArray = w.fog[p]
		for c in g.size():
			if g[c] == VISIBLE:
				g[c] = EXPLORED
		for i in w.units.count():
			if w.teams[w.units.owner[i]] == w.teams[p]:
				var r: int = cfg.worker if w.types[w.units.kind[i]].worker else cfg.unit
				_stamp(w, g, w.units.x[i] / 1000, w.units.y[i] / 1000, r)
		var bs = w.buildings
		for b in bs.count():
			if w.teams[bs.owner[b]] == w.teams[p]:
				var t: Dictionary = w.btypes[bs.kind[b]]
				var r: int = cfg.tower if t.get("attack", {}).size() > 0 else cfg.building
				var half: int = bs.size[b] / 2
				_stamp(w, g, bs.cx[b] + half, bs.cy[b] + half, r + half)
		w.fog[p] = g


static func _stamp(w, g: PackedByteArray, cx: int, cy: int, r: int) -> void:
	var offs := _circle(r)
	var wd: int = w.map.width
	var ht: int = w.map.height
	for k in range(0, offs.size(), 2):
		var x := cx + offs[k]
		var y := cy + offs[k + 1]
		if x >= 0 and y >= 0 and x < wd and y < ht:
			g[y * wd + x] = VISIBLE


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
