extends RefCounted
## Route sense for the bots (milestone 15 phase 7): a whole-map search a player does by looking
## at the map, not the sim's flow fields. Per cell a price to walk it (by the lane's walk grid,
## slowed on ground it wades: rules.movement.terrain_speed), plus extras the bot adds: trees it
## could fell (a road), ground under enemy archers on a hill, the walkers' own route (a flank).
## Dijkstra with a bucket ring like Flow's: 8 neighbours, diagonals only between two cells that
## are really open (a road felled through trees is a staircase units can walk). Integers, cells
## in a fixed order: deterministic. Read-only over the sim.

const INF := 1 << 30
const STEP := 10            # the price of a straight step on open ground (diagonal 14)
const RING := 1024          # bucket ring: more than the dearest step
const DX := [0, 1, 0, -1, 1, 1, -1, -1]   # N, E, S, W, then the diagonals (land.gd's clumps)
const DY := [-1, 0, 1, 0, -1, 1, 1, -1]


## The price per cell for lane `ln` (0: can't): open ground STEP, slower ground dearer (a ford
## for walkers), and with `tree` > 0, trees standing on the lane's ground at that price (felled,
## they'd open: a road). A broken bridge's cells at `bridge` > 0 (as if rebuilt).
static func prices(w, ln: int, tree := 0, bridge := 0) -> PackedInt32Array:
	var m = w.map
	var walk: PackedByteArray = m.walks[ln]
	var n: int = m.width * m.height
	var cls: int = ln % m.CLASSES.size()
	var speed: Array = w.move_pct[cls]
	var tree_t: int = m.terrain_ids.find("tree")
	var out := PackedInt32Array()
	out.resize(n)
	for c in n:
		if walk[c] == 1:
			out[c] = STEP * 100 / maxi(10, int(speed[m.terrain[c]])) if m.deck[c] == 0 else STEP
		elif tree > 0 and m.terrain[c] == tree_t and m.amount[c] > 0 and m.occupied[c] == 0 and not (m.has_heights and m.cliff[c] == 1):
			out[c] = tree
	if bridge > 0:
		for k in w.bridge_id.size():
			if w.bridge_up[k] == 0:
				for c in w.bridge_cells[k]:
					out[c] = bridge
	return out


## Costs from `from` (a cell) to every cell over `price` (0: blocked). `open`: the cells that
## are really open (diagonal steps need both sides open there). Returns [dist, prev].
static func search(m, price: PackedInt32Array, open: PackedByteArray, from: int) -> Array:
	var s := Search.new(m, price, open, from)
	s.step(1 << 30)
	return s.result()


## A search that runs a slice at a time (`step`, so many cells settled a call): a bot spreads one
## over a few thinks instead of spending a whole search on one tick.
class Search extends RefCounted:
	var dist := PackedInt32Array()
	var prev := PackedInt32Array()
	var price: PackedInt32Array
	var open: PackedByteArray
	var ring := []
	var pending := 1
	var cost := 0
	var head := 0          # where in the current bucket we are
	var wd: int
	var h: int
	var steps: PackedInt32Array
	var done := false

	func _init(m, p_price: PackedInt32Array, p_open: PackedByteArray, from: int) -> void:
		wd = m.width
		h = m.height
		price = p_price
		open = p_open
		dist.resize(wd * h)
		dist.fill(INF)
		prev.resize(wd * h)
		prev.fill(-1)
		for k in RING:
			ring.append([])
		dist[from] = 0
		ring[0].append(from)
		steps = PackedInt32Array([-wd, 1, wd, -1, -wd + 1, wd + 1, wd - 1, -wd - 1])   # N, E, S, W, NE, SE, SW, NW

	## Settle up to `budget` cells; true once the search is done.
	func step(budget: int) -> bool:
		while pending > 0 and budget > 0:
			var bucket: Array = ring[cost % RING]
			while head < bucket.size() and budget > 0:
				var c: int = bucket[head]
				head += 1
				pending -= 1
				if dist[c] != cost:
					continue   # a cheaper way got here first
				budget -= 1
				var cx := c % wd
				var cy := c / wd
				var up := cy > 0
				var down := cy < h - 1
				var left := cx > 0
				var right := cx < wd - 1
				# The four sides, then the diagonals only between two really open sides.
				var ok := [up, right, down, left,
					up and right and open[c - wd] == 1 and open[c + 1] == 1,
					down and right and open[c + wd] == 1 and open[c + 1] == 1,
					down and left and open[c + wd] == 1 and open[c - 1] == 1,
					up and left and open[c - wd] == 1 and open[c - 1] == 1]
				for d in 8:
					if not ok[d]:
						continue
					var nc: int = c + steps[d]
					var p: int = price[nc]
					if p <= 0 or (d >= 4 and open[nc] == 0):
						continue
					var nd: int = cost + (p * 14 / 10 if d >= 4 else p)
					if nd < dist[nc]:
						dist[nc] = nd
						prev[nc] = c
						ring[nd % RING].append(nc)
						pending += 1
			if head >= bucket.size():
				bucket.clear()
				head = 0
				cost += 1
		done = pending <= 0
		return done

	func result() -> Array:
		return [dist, prev]


## The cells from the search's start to `to` (start first), or empty if unreached.
static func path(found: Array, to: int) -> PackedInt32Array:
	var prev: PackedInt32Array = found[1]
	if found[0][to] >= INF:
		return PackedInt32Array()
	var out := PackedInt32Array()
	var c := to
	while c >= 0:
		out.append(c)
		c = prev[c]
	out.reverse()
	return out


## The cell of `cells` with the lowest cost in the search (lowest cell on ties), or -1.
static func cheapest(found: Array, cells: PackedInt32Array) -> int:
	var best := -1
	var dist: PackedInt32Array = found[0]
	for c in cells:
		if dist[c] < INF and (best < 0 or dist[c] < dist[best] or (dist[c] == dist[best] and c < best)):
			best = c
	return best


## The cells round a building or a point that the search reached: the goal cells for a route to
## something blocked (a Town Center) — every open cell within `r` cells of (cx, cy).
static func ring_round(m, open: PackedByteArray, cx: int, cy: int, r: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for y in range(maxi(0, cy - r), mini(m.height, cy + r + 1)):
		for x in range(maxi(0, cx - r), mini(m.width, cx + r + 1)):
			if open[y * m.width + x] == 1:
				out.append(y * m.width + x)
	return out
