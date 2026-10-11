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
			if up and right and walk[n_ + 1] == 1 and d < dist[n_ + 1]:
				dist[n_ + 1] = d; next[n_ + 1] = c; bd.append(n_ + 1); pending += 1
			if down and right and walk[s_ + 1] == 1 and d < dist[s_ + 1]:
				dist[s_ + 1] = d; next[s_ + 1] = c; bd.append(s_ + 1); pending += 1
			if down and left and walk[s_ - 1] == 1 and d < dist[s_ - 1]:
				dist[s_ - 1] = d; next[s_ - 1] = c; bd.append(s_ - 1); pending += 1
			if up and left and walk[n_ - 1] == 1 and d < dist[n_ - 1]:
				dist[n_ - 1] = d; next[n_ - 1] = c; bd.append(n_ - 1); pending += 1
		bucket.clear()
		cost += 1
	f.sources = source_cells
	f.max_cost = cutoff
	f.pops = pops
	f.dist = dist
	f.next = next
	return f


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
	for i in range(1, steps + 1):
		if not map.walkable(ax + dx * i / steps, ay + dy * i / steps, k):
			return false
	return true


static func centre(map: SimMap, cell: int) -> Vector2i:
	return Vector2i((cell % map.width) * TILE + TILE / 2, (cell / map.width) * TILE + TILE / 2)
