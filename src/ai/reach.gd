extends RefCounted
## Where a bot's units can get to: the map's walkable cells split into areas (connected by
## 4-neighbour steps, as movement can't slip between two corners), one label per area, per
## lane (movement class and team). Two cells in one area have a path; a target touching no
## cell of a unit's area has none (a river whose fords are walled off, an island). The bot
## checks targets against this before it sends anyone, so it never queues workers at a wall.
## Relabelled at most every REFRESH ticks when the map has changed. Read-only over the sim;
## integers and ascending cells only, so the bots stay deterministic.

const REFRESH := 100        # ticks (5 s): a wall going up is noticed this late at most
const SEARCH := 3           # cells round a blocked spot (inside a building) to find its area

var _labels := {}           # lane -> PackedInt32Array per cell: area label, 0 where blocked
var _at := {}               # lane -> [tick, map version] of the labels


## The area labels for lane `ln`, fresh enough.
func labels(w, ln: int) -> PackedInt32Array:
	var got = _at.get(ln)
	if got == null or (got[1] != w.map.version and w.tick >= got[0] + REFRESH):
		_labels[ln] = _label(w.map, ln)
		_at[ln] = [w.tick, w.map.version]
	return _labels[ln]


static func _label(m, ln: int) -> PackedInt32Array:
	var walk: PackedByteArray = m.walks[ln]
	var wd: int = m.width
	var n: int = wd * m.height
	var out := PackedInt32Array()
	out.resize(n)
	var queue := PackedInt32Array()
	queue.resize(n)
	var next := 1
	for start in n:
		if walk[start] == 0 or out[start] != 0:
			continue
		out[start] = next
		var head := 0
		var tail := 1
		queue[0] = start
		while head < tail:   # 4-neighbour flood fill (no lists built per cell: this runs over the whole map)
			var c: int = queue[head]
			head += 1
			var x: int = c % wd
			if c >= wd and walk[c - wd] == 1 and out[c - wd] == 0:
				out[c - wd] = next
				queue[tail] = c - wd
				tail += 1
			if c + wd < n and walk[c + wd] == 1 and out[c + wd] == 0:
				out[c + wd] = next
				queue[tail] = c + wd
				tail += 1
			if x > 0 and walk[c - 1] == 1 and out[c - 1] == 0:
				out[c - 1] = next
				queue[tail] = c - 1
				tail += 1
			if x < wd - 1 and walk[c + 1] == 1 and out[c + 1] == 0:
				out[c + 1] = next
				queue[tail] = c + 1
				tail += 1
		next += 1
	return out


## The area of the walkable cell at (or nearest, within SEARCH) a point in milli-tiles; 0 if none.
func area_at(w, ln: int, x: int, y: int) -> int:
	var lab := labels(w, ln)
	var m = w.map
	var cx: int = clampi(x / 1000, 0, m.width - 1)
	var cy: int = clampi(y / 1000, 0, m.height - 1)
	for r in SEARCH + 1:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var xx := cx + dx
				var yy := cy + dy
				if xx >= 0 and yy >= 0 and xx < m.width and yy < m.height and lab[yy * m.width + xx] != 0:
					return lab[yy * m.width + xx]
	return 0


## The area a unit stands in.
func area_of_unit(w, i: int) -> int:
	return area_at(w, w.lane(i), w.units.x[i], w.units.y[i])


## Can a unit in `area` get next to the rect of cells (cx, cy, sx, sy)? Any cell in it or round
## it (corners too: a worker reaches a tree from a diagonal) in that area. Area 0 (unknown) says yes.
func touches(w, ln: int, area: int, cx: int, cy: int, sx := 1, sy := 1) -> bool:
	if area == 0:
		return true
	var lab := labels(w, ln)
	var m = w.map
	for y in range(maxi(cy - 1, 0), mini(cy + sy + 1, m.height)):
		for x in range(maxi(cx - 1, 0), mini(cx + sx + 1, m.width)):
			if lab[y * m.width + x] == area:
				return true
	return false


## Can a unit in `area` get next to this cell?
func reaches_cell(w, ln: int, area: int, cell: int) -> bool:
	return touches(w, ln, area, cell % w.map.width, cell / w.map.width)


## Can a unit in `area` get next to building b?
func reaches_building(w, ln: int, area: int, b: int) -> bool:
	var bs = w.buildings
	return touches(w, ln, area, bs.cx[b], bs.cy[b], bs.sx[b], bs.sy[b])


## The middle of the cell of `area` nearest (x, y), in milli-tiles (lowest cell on ties): where
## to go when the place itself can't be reached (the near bank, the outside of a wall). (-1, -1)
## if the area is empty.
func nearest_in(w, ln: int, area: int, x: int, y: int) -> Vector2i:
	var lab := labels(w, ln)
	var m = w.map
	var best := -1
	var best_d2 := 1 << 62
	for c in lab.size():
		if lab[c] != area:
			continue
		var dx: int = (c % m.width) * 1000 + 500 - x
		var dy: int = (c / m.width) * 1000 + 500 - y
		var d2 := dx * dx + dy * dy
		if d2 < best_d2:
			best_d2 = d2
			best = c
	if best < 0:
		return Vector2i(-1, -1)
	return Vector2i((best % m.width) * 1000 + 500, (best / m.width) * 1000 + 500)
