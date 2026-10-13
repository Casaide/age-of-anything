extends RefCounted
## Walls put up finished at the start (milestone 16): a square ring round a point, with a gate
## in the middle of the sides asked for and wall towers on the corners and every few tiles. The
## Fortress and Siege modes start from it (data/modes.json `walls`), and so do the siege bench
## and tests. Cells that can't be built on (trees, stone, water) are left out: the ring follows
## the land. Static functions over the World `w`, integers only.

const Economy := preload("res://src/sim/economy.gd")
const SimMap := preload("res://src/sim/sim_map.gd")

const SIDES := ["n", "e", "s", "w"]


## A finished ring for `player` round cell (cx, cy), `r` tiles out (the ring's cells are the edge
## of the (2r+1)-square). spec: {"wall": type id, "gate": type id or "", "tower": type id or "",
## "tower_every": tiles between towers along a side (0: corners only), "gates": sides ["n", "e",
## "s", "w"]}. Returns the ids of everything it put up, in the order placed.
static func ring(w, player: int, cx: int, cy: int, r: int, spec: Dictionary) -> Array:
	var wk := Economy.btype_of(w, spec.wall)
	assert(wk >= 0, "Fortify: unknown wall %s" % spec.wall)
	var gk := Economy.btype_of(w, spec.get("gate", "")) if spec.get("gate", "") != "" else -1
	var tk := Economy.btype_of(w, spec.get("tower", "")) if spec.get("tower", "") != "" else -1
	var every: int = int(spec.get("tower_every", 0))
	var gates: Array = spec.get("gates", []) if gk >= 0 else []
	var ids := []
	var lo := Vector2i(cx - r, cy - r)
	var hi := Vector2i(cx + r, cy + r)
	var gate_cells := {}   # cell -> [gx, gy, along] of the gate covering it (its top-left)
	for s in gates:
		assert(s in SIDES, "Fortify: unknown side %s" % s)
		var g: Array
		match s:
			"n": g = [cx - 1, lo.y, 0]
			"s": g = [cx - 1, hi.y, 0]
			"w": g = [lo.x, cy - 1, 1]
			"e": g = [hi.x, cy - 1, 1]
		for k in 3:
			var c: int = (g[1] + (k if g[2] == 1 else 0)) * w.map.width + g[0] + (k if g[2] == 0 else 0)
			gate_cells[c] = g
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			if x != lo.x and x != hi.x and y != lo.y and y != hi.y:
				continue
			if x < 0 or y < 0 or x >= w.map.width or y >= w.map.height:
				continue
			var c: int = y * w.map.width + x
			if gate_cells.has(c) or not w.map.can_build(x, y, 1):
				continue
			var corner: bool = (x == lo.x or x == hi.x) and (y == lo.y or y == hi.y)
			var along: int = (x - lo.x) if (y == lo.y or y == hi.y) else (y - lo.y)
			var tower: bool = tk >= 0 and (corner or (every > 0 and along % every == 0))
			ids.append(_put(w, player, tk if tower else wk, x, y, 0))
	var done := {}
	for c in gate_cells:
		var g: Array = gate_cells[c]
		var key: int = g[1] * w.map.width + g[0]
		if done.has(key):
			continue
		done[key] = true
		var ok := true
		var d := Economy.dims(w.btypes[gk], g[2])
		for fc in Economy._footprint(w, g[0], g[1], d, g[2]):
			if not w.map.can_build(fc % w.map.width, fc / w.map.width, 1):
				ok = false
		if ok:
			ids.append(_put(w, player, gk, g[0], g[1], g[2]))
	return ids


## Put one finished building down; its id.
static func _put(w, player: int, k: int, x: int, y: int, along: int) -> int:
	var b := Economy.place(w, player, k, x, y, along)
	w.buildings.done[b] = 1
	w.buildings.progress[b] = w.btypes[k].build_ticks
	w.buildings.hp[b] = w.bmods[player][k].hp
	return w.buildings.id[b]
