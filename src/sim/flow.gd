extends RefCounted
## A flow field: for every cell, the cost to reach a set of source cells (a move
## target, a reed tile, a building's footprint) and the next cell to step to. One
## solve serves every unit heading there. Sources may be blocked (a tree, a
## building): the field leads to the tiles next to them. A cost cutoff limits the
## solve to the neighbourhood, which is what short gathering trips need.
## A field is a pure function of (map, target). Which fields exist at a given
## tick is sim state (World queues one solve per tick); the fields' contents never vary.
##
## Dijkstra with a bucket queue: costs are 10 straight and 14 diagonal, and
## diagonals may not cut a blocked corner. Neighbours are visited in a fixed
## order and the first equal-cost route wins, so ties are deterministic.

const SimMap := preload("res://src/sim/sim_map.gd")
const Fixed := preload("res://src/sim/fixed.gd")

const INF := 1 << 30
const STRAIGHT := 10
const DIAGONAL := 14
const RING := DIAGONAL + 1
const TILE := 1000
const LINE_STEP := 333        # milli-tiles between line-of-sight samples

var sources := PackedInt32Array()
var max_cost := INF
var pops := 0                    # cells settled: the work this solve took
var dist := PackedInt32Array()   # cost to the nearest source, INF if unreachable (or past the cutoff)
var next := PackedInt32Array()   # next cell towards a source, -1 at a source or if unreachable


static func solve(map: SimMap, source_cells: PackedInt32Array, cutoff := INF, k := 0) -> RefCounted:
	var f = new()
	var w := map.width
	var h := map.height
	var n := w * h
	var walk: PackedByteArray = map.walks[k]
	var dist := PackedInt32Array()
	var next := PackedInt32Array()
	dist.resize(n)
	dist.fill(INF)
	next.resize(n)
	next.fill(-1)
	var ring := []
	for i in RING:
		ring.append([])
	var pending := 0
	for src in source_cells:
		dist[src] = 0
		ring[0].append(src)
		pending += 1
	var pops := 0
	var cost := 0
	while pending > 0 and cost <= cutoff:
		var bucket: Array = ring[cost % RING]
		for c: int in bucket:
			pending -= 1
			if dist[c] != cost:
				continue   # a cheaper route got here first
			pops += 1
			var cx := c % w
			var cy := c / w
			var up := cy > 0 and walk[c - w] == 1
			var down := cy < h - 1 and walk[c + w] == 1
			var left := cx > 0 and walk[c - 1] == 1
			var right := cx < w - 1 and walk[c + 1] == 1
			# A blocked source (a bush, a building) is worked from any cell touching it, corners
			# included, so its diagonals open whatever its sides: nobody walks through it.
			var from_blocked := walk[c] == 0
			var ne := (up and right) or (from_blocked and cy > 0 and cx < w - 1)
			var se := (down and right) or (from_blocked and cy < h - 1 and cx < w - 1)
			var sw := (down and left) or (from_blocked and cy < h - 1 and cx > 0)
			var nw := (up and left) or (from_blocked and cy > 0 and cx > 0)
			var s := cost + STRAIGHT
			var d := cost + DIAGONAL
			var bs: Array = ring[s % RING]
			var bd: Array = ring[d % RING]
			var n_ := c - w
			var e_ := c + 1
			var s_ := c + w
			var w_ := c - 1
			# N, E, S, W, then NE, SE, SW, NW. Diagonals need both sides open.
			if up and s < dist[n_]:
				dist[n_] = s; next[n_] = c; bs.append(n_); pending += 1
			if right and s < dist[e_]:
				dist[e_] = s; next[e_] = c; bs.append(e_); pending += 1
			if down and s < dist[s_]:
				dist[s_] = s; next[s_] = c; bs.append(s_); pending += 1
			if left and s < dist[w_]:
				dist[w_] = s; next[w_] = c; bs.append(w_); pending += 1
			if ne and walk[n_ + 1] == 1 and d < dist[n_ + 1]:
				dist[n_ + 1] = d; next[n_ + 1] = c; bd.append(n_ + 1); pending += 1
			if se and walk[s_ + 1] == 1 and d < dist[s_ + 1]:
				dist[s_ + 1] = d; next[s_ + 1] = c; bd.append(s_ + 1); pending += 1
			if sw and walk[s_ - 1] == 1 and d < dist[s_ - 1]:
				dist[s_ - 1] = d; next[s_ - 1] = c; bd.append(s_ - 1); pending += 1
			if nw and walk[n_ - 1] == 1 and d < dist[n_ - 1]:
				dist[n_ - 1] = d; next[n_ - 1] = c; bd.append(n_ - 1); pending += 1
		bucket.clear()
		cost += 1
	f.sources = source_cells
	f.max_cost = cutoff
	f.pops = pops
	f.dist = dist
	f.next = next
	return f


## A cell opened (walkable now in lane k; nothing closed): lower the costs it shortens. Opening
## only adds ways, so costs only fall: recompute the cell and its neighbours from their
## neighbours, then carry any fall outwards (label-correcting, in a FIFO). Moves follow solve's
## rules (diagonals need both sides open; a blocked source is worked from any side). Cells
## past a near field's cutoff take a cost but aren't expanded, as in solve. Deterministic: the
## same cells in the same order. The caller drops the field instead if `cell` is a source.
func patch(map: SimMap, cell: int, k := 0) -> void:
	var w := map.width
	var h := map.height
	var walk: PackedByteArray = map.walks[k]
	var queue := PackedInt32Array()
	var cx := cell % w
	var cy := cell / w
	for y in range(maxi(cy - 1, 0), mini(cy + 2, h)):
		for x in range(maxi(cx - 1, 0), mini(cx + 2, w)):
			var s := y * w + x
			if walk[s] == 0 or dist[s] == 0:
				continue
			for ny in range(maxi(y - 1, 0), mini(y + 2, h)):
				for nx in range(maxi(x - 1, 0), mini(x + 2, w)):
					var n := ny * w + nx
					if n == s or dist[n] >= INF or (dist[n] > max_cost):
						continue
					var step := _step(map, walk, n, s)
					if step > 0 and dist[n] + step < dist[s]:
						dist[s] = dist[n] + step
						next[s] = n
			if dist[s] < INF and dist[s] <= max_cost:
				queue.append(s)
	var head := 0
	while head < queue.size():
		var c: int = queue[head]
		head += 1
		var x0 := c % w
		var y0 := c / w
		for ny in range(maxi(y0 - 1, 0), mini(y0 + 2, h)):
			for nx in range(maxi(x0 - 1, 0), mini(x0 + 2, w)):
				var n := ny * w + nx
				if n == c or walk[n] == 0:
					continue
				var step := _step(map, walk, c, n)
				if step > 0 and dist[c] + step < dist[n]:
					dist[n] = dist[c] + step
					next[n] = c
					if dist[n] <= max_cost:
						queue.append(n)
		pops += 1


## The cost of the field spreading from c to its neighbour n (n walkable): straight 10,
## diagonal 14 if both cells beside the corner are open, or always from a blocked source; 0 if
## the move isn't allowed.
func _step(map: SimMap, walk: PackedByteArray, c: int, n: int) -> int:
	var w := map.width
	var dx := n % w - c % w
	var dy := n / w - c / w
	if dx == 0 or dy == 0:
		return STRAIGHT
	if walk[c] == 0 and dist[c] == 0:
		return DIAGONAL   # a blocked source: worked from any cell touching it
	if walk[c + dx] == 1 and walk[c + dy * w] == 1:
		return DIAGONAL
	return 0


## Does a change at `cell` possibly alter this field? Only if the solve reached it or a neighbour.
func touches(map: SimMap, cell: int) -> bool:
	var cx := cell % map.width
	var cy := cell / map.width
	for y in range(maxi(cy - 1, 0), mini(cy + 2, map.height)):
		for x in range(maxi(cx - 1, 0), mini(cx + 2, map.width)):
			if dist[y * map.width + x] < INF:
				return true
	return false


## The walkable cell closest to `cell` (itself if walkable). Ties go to the lower index.
static func nearest_walkable(map: SimMap, cell: int, k := 0) -> int:
	if map.walks[k][cell] == 1:
		return cell
	var cx := cell % map.width
	var cy := cell / map.width
	for r in range(1, maxi(map.width, map.height)):
		var best := -1
		var best_d2 := INF
		for y in range(cy - r, cy + r + 1):
			for x in range(cx - r, cx + r + 1):
				if maxi(absi(x - cx), absi(y - cy)) != r or not map.cell_walkable(x, y, k):
					continue
				var d2 := (x - cx) * (x - cx) + (y - cy) * (y - cy)
				if d2 < best_d2:
					best_d2 = d2
					best = y * map.width + x
		if best >= 0:
			return best
	assert(false, "Map %s has no walkable cells" % map.id)
	return -1


## True if a straight walk from a to b (milli-tiles) stays on walkable ground.
static func clear_line(map: SimMap, ax: int, ay: int, bx: int, by: int, k := 0) -> bool:
	var dx := bx - ax
	var dy := by - ay
	var steps := maxi(absi(dx), absi(dy)) / LINE_STEP + 1
	var px := ax
	var py := ay
	for i in range(1, steps + 1):
		var x := ax + dx * i / steps
		var y := ay + dy * i / steps
		if not map.walkable(x, y, k):
			return false
		if x / TILE != px / TILE and y / TILE != py / TILE and not (map.walkable(x, py, k) and map.walkable(px, y, k)):
			return false   # no slipping between two corners (see clear_path)
		px = x
		py = y
	return true


## clear_line for a body of radius r: the centre line and the two lines a body's width
## either side of it must all stay on walkable ground, so a waypoint never cuts a corner the
## body can't pass (the centre could, the shoulders couldn't; the clamp then shoved it back).
static func clear_path(map: SimMap, ax: int, ay: int, bx: int, by: int, r: int, k := 0) -> bool:
	var dx := bx - ax
	var dy := by - ay
	var len := maxi(1, Fixed.isqrt(dx * dx + dy * dy))
	var ox := -dy * r / len
	var oy := dx * r / len
	var walk: PackedByteArray = map.walks[k]
	var w := map.width
	var h := map.height
	var steps := maxi(absi(dx), absi(dy)) / LINE_STEP + 1
	var px := ax
	var py := ay
	for i in range(1, steps + 1):
		var x := ax + dx * i / steps
		var y := ay + dy * i / steps
		# The centre line, then a body's width either side of it. (Sampling the sides every
		# other step saved 0.2 ms a tick at 143 units and doubled the jitter: not worth it.)
		if _blocked(walk, w, h, x, y) or _blocked(walk, w, h, x + ox, y + oy) or _blocked(walk, w, h, x - ox, y - oy):
			return false
		# Into a diagonal neighbour cell: both cells beside the corner must be open (as World._move
		# steps), else the line slips between two blocks touching at a corner (a diagonal wall).
		if x / TILE != px / TILE and y / TILE != py / TILE and (_blocked(walk, w, h, x, py) or _blocked(walk, w, h, px, y)):
			return false
		px = x
		py = y
	return true


static func _blocked(walk: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	if x < 0 or y < 0:
		return true
	var cx := x / TILE
	var cy := y / TILE
	return cx >= w or cy >= h or walk[cy * w + cx] == 0


static func centre(map: SimMap, cell: int) -> Vector2i:
	return Vector2i((cell % map.width) * TILE + TILE / 2, (cell / map.width) * TILE + TILE / 2)
