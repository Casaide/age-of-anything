extends RefCounted
## Generates each player's paths, styled by their culture (families.json "paths"):
## from the main building's door to its other buildings, the nearest resources
## and the shoreline. A* on a half-tile grid that avoids blocked ground; cells
## already on a path are cheap, so routes merge into trunk roads. A route that
## reaches an existing path stops drawing and joins it (the first road keeps
## its style, and no stretch is drawn twice). Then smoothed.
## Cosmetic (view side), but deterministic: same map and buildings, same paths.

const STYLES := ["trail", "boardwalk", "cobble", "road"]   # mask channels R, G, B, A
const SUB := 2                                             # grid cells per tile
const REACH := 10.0                                        # tiles: how far a culture builds paths


## blocked: Callable(t: Vector2) -> bool, for a point in tile coordinates.
## owners: [{style, width, hub: Vector2, targets: [Vector2]}]
## Returns [{style, width, points: PackedVector2Array}] in tile coordinates.
## memo: pass the same Dictionary to every plan of one match and the paths grow instead of being
## planned afresh: a route already laid (same owner style, hub and target) stays exactly where it
## is, and only new targets add branches, joining what's there. (Replanning everything with each
## new building moved roads that had stood for minutes; Dominic: "roads seem to be moving around".)
static func plan(w: int, h: int, blocked: Callable, owners: Array, memo := {}) -> Array:
	var gw := w * SUB
	var gh := h * SUB
	if memo.is_empty():
		var fresh := PackedByteArray()
		fresh.resize(gw * gh)
		memo.used = fresh
		memo.out = []
		memo.done = {}
	var used: PackedByteArray = memo.used
	var out: Array = memo.out
	for o in owners:
		var mine := STYLES.find(o.style) + 1
		for target in o.targets:
			if o.hub.distance_to(target) > REACH:
				continue
			var key := "%d|%s|%s" % [mine, o.hub, target]
			if memo.done.has(key):
				continue   # laid before: it stays put
			memo.done[key] = true
			var cells := _route(gw, gh, blocked, used, o.hub, target)
			# Draw only the new stretches: any existing path (ours or another culture's)
			# ends a run, keeping one cell of overlap so the two meet. That way every
			# stretch belongs to exactly one path, and its boards or stones line up.
			var run := PackedInt32Array()
			for c in cells:
				if used[c] != 0:
					if run.size() > 0:
						run.append(c)
						_emit(out, o, run, gw)
					run = PackedInt32Array()
					continue
				run.append(c)
			_emit(out, o, run, gw)
			for c in cells:
				if used[c] == 0:
					used[c] = mine
	memo.used = used   # (a packed array is a value: hand the marks back)
	return out


static func _emit(out: Array, o: Dictionary, run: PackedInt32Array, gw: int) -> void:
	if run.size() < 2:
		return
	var pts := PackedVector2Array()
	for c in run:
		pts.append((Vector2(c % gw, c / gw) + Vector2(0.5, 0.5)) / SUB)
	out.append({"style": o.style, "width": o.width, "points": _smooth(_smooth(pts))})


static func _route(gw: int, gh: int, blocked: Callable, used: PackedByteArray, from: Vector2, to: Vector2) -> PackedInt32Array:
	var start := _cell(gw, gh, from)
	var goal := _cell(gw, gh, to)
	var dist := {start: 0.0}
	var prev := {}
	var open := [[_heur(gw, start, goal), start]]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var seen := 0
	while not open.is_empty() and seen < 20000:
		open.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		var cur: int = open.pop_front()[1]
		seen += 1
		if cur == goal:
			break
		var cx := cur % gw
		var cy := cur / gw
		for d in dirs:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if nx < 0 or ny < 0 or nx >= gw or ny >= gh:
				continue
			var nc := ny * gw + nx
			var p := (Vector2(nx, ny) + Vector2(0.5, 0.5)) / SUB
			if nc != goal and blocked.call(p):
				continue
			var step := 1.414 if d.x != 0 and d.y != 0 else 1.0
			var nd: float = dist[cur] + step * (0.35 if used[nc] != 0 else 1.0)
			if not dist.has(nc) or nd < dist[nc]:
				dist[nc] = nd
				prev[nc] = cur
				open.append([nd + _heur(gw, nc, goal), nc])
	if not prev.has(goal):
		return PackedInt32Array()
	var cells := PackedInt32Array([goal])
	var c: int = goal
	while prev.has(c):
		c = prev[c]
		cells.append(c)
	cells.reverse()
	return cells


static func _cell(gw: int, gh: int, t: Vector2) -> int:
	return clampi(int(t.y * SUB), 0, gh - 1) * gw + clampi(int(t.x * SUB), 0, gw - 1)


static func _heur(gw: int, a: int, b: int) -> float:
	return Vector2(a % gw, a / gw).distance_to(Vector2(b % gw, b / gw))


## Chaikin corner cutting: one pass rounds every corner.
static func _smooth(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array([pts[0]])
	for i in pts.size() - 1:
		out.append(pts[i].lerp(pts[i + 1], 0.25))
		out.append(pts[i].lerp(pts[i + 1], 0.75))
	out.append(pts[pts.size() - 1])
	return out


## Rasterize planned paths: an RGBA mask (one channel per style) at k samples per
## tile, and an arc-length image (distance along the nearest path, at `fine`
## samples per tile) so boards can be laid across the walk, even round bends.
## Returns [mask, arc_length]. Each segment only touches pixels near it.
static func mask(w: int, h: int, k: int, planned: Array, fine := 16) -> Array:
	var img := Image.create(w * k, h * k, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var arc := Image.create(w * fine, h * fine, false, Image.FORMAT_RF)
	var best := PackedFloat32Array()
	best.resize(w * fine * h * fine)
	best.fill(INF)
	for p in planned:
		var ch := STYLES.find(p.style)
		var pts: PackedVector2Array = p.points
		var r: float = p.width
		var along := 0.0
		for i in range(1, pts.size()):
			var a := pts[i - 1]
			var b := pts[i]
			var box := Rect2(a, Vector2.ZERO).expand(b).grow(r + 0.3)
			for y in range(maxi(int(box.position.y * k), 0), mini(int(box.end.y * k) + 1, h * k)):
				for x in range(maxi(int(box.position.x * k), 0), mini(int(box.end.x * k) + 1, w * k)):
					var q := (Vector2(x, y) + Vector2(0.5, 0.5)) / k
					if Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q) < r:
						var c := img.get_pixel(x, y)
						c[ch] = 1.0
						img.set_pixel(x, y, c)
			for y in range(maxi(int(box.position.y * fine), 0), mini(int(box.end.y * fine) + 1, h * fine)):
				for x in range(maxi(int(box.position.x * fine), 0), mini(int(box.end.x * fine) + 1, w * fine)):
					var q := (Vector2(x, y) + Vector2(0.5, 0.5)) / fine
					var on := Geometry2D.get_closest_point_to_segment(q, a, b)
					var d := on.distance_to(q)
					var idx := y * w * fine + x
					if d < r + 0.3 and d < best[idx]:
						best[idx] = d
						arc.set_pixel(x, y, Color(along + on.distance_to(a), 0, 0))
			along += a.distance_to(b)
	return [img, arc]
