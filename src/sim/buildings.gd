extends RefCounted
## Every building in the sim, as parallel arrays sorted by id (like units.gd).
## Buildings share the World's id counter with units, so an id names exactly one thing.
## A building with done == 0 is a foundation: builders raise `progress` to `build_ticks`.

const Fixed := preload("res://src/sim/fixed.gd")

var id := PackedInt32Array()
var owner := PackedInt32Array()
var kind := PackedInt32Array()        # index into World.btypes
var cx := PackedInt32Array()          # top-left cell
var cy := PackedInt32Array()
var sx := PackedInt32Array()          # footprint: sx cells along x by sy along y (square but for gates)
var sy := PackedInt32Array()
var diag := PackedInt32Array()        # 0: the whole rect; 1 or 2: a diagonal gate, the cells on one diagonal of its square (cells())
var hp := PackedInt32Array()
var progress := PackedInt32Array()    # builder-ticks put in so far
var done := PackedInt32Array()        # 1 once built
var train := PackedInt32Array()       # ticks into the unit or tech at the head of the queue
var rally_x := PackedInt32Array()     # milli-tiles, or -1 for none
var rally_y := PackedInt32Array()
var cooldown := PackedInt32Array()   # towers: ticks until the next shot
var queue: Array = []                 # per building, head first: unit type indexes (>= 0) and techs (Tech.entry)
var inside: Array = []                # per building: the units sheltering in it (garrison.gd), each a PackedInt32Array record, by id


func count() -> int:
	return id.size()


func add(bid: int, p_owner: int, p_kind: int, p_cx: int, p_cy: int, p_sx: int, p_sy: int, p_hp: int, p_diag := 0) -> int:
	assert(id.is_empty() or bid > id[id.size() - 1], "Building ids must grow")
	id.append(bid)
	owner.append(p_owner)
	kind.append(p_kind)
	cx.append(p_cx)
	cy.append(p_cy)
	sx.append(p_sx)
	sy.append(p_sy)
	diag.append(p_diag)
	hp.append(p_hp)
	progress.append(0)
	done.append(0)
	train.append(0)
	rally_x.append(-1)
	rally_y.append(-1)
	queue.append([])
	inside.append([])
	cooldown.append(0)
	return id.size() - 1


func index_of(bid: int) -> int:
	var i := id.bsearch(bid)
	if i < id.size() and id[i] == bid:
		return i
	return -1


func remove_at(i: int) -> void:
	# Field by field: packed arrays put in an Array literal would be copies.
	id.remove_at(i)
	owner.remove_at(i)
	kind.remove_at(i)
	cx.remove_at(i)
	cy.remove_at(i)
	sx.remove_at(i)
	sy.remove_at(i)
	diag.remove_at(i)
	hp.remove_at(i)
	progress.remove_at(i)
	done.remove_at(i)
	train.remove_at(i)
	rally_x.remove_at(i)
	rally_y.remove_at(i)
	queue.remove_at(i)
	inside.remove_at(i)
	cooldown.remove_at(i)


## The cells under building slot i, row by row.
func footprint(i: int, map_width: int) -> PackedInt32Array:
	return cells(cx[i], cy[i], sx[i], sy[i], diag[i], map_width)


## The cells of a footprint with its top-left on (x0, y0), row by row: the whole w x h rect, or
## (`d` 1 or 2, a square) the cells on one of its diagonals, each touching the next at a corner.
static func cells(x0: int, y0: int, w: int, h: int, d: int, map_width: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for y in range(y0, y0 + h):
		if d != 0:
			out.append(y * map_width + (x0 + y - y0 if d == 1 else x0 + w - 1 - (y - y0)))
			continue
		for x in range(x0, x0 + w):
			out.append(y * map_width + x)
	return out


## The edge-to-edge gap from a point (milli-tiles) to building slot i's footprint, 0 inside it:
## to its rect, or to the nearest of a diagonal gate's cells.
func gap(i: int, x: int, y: int) -> int:
	var best := 1 << 30
	var n: int = sy[i] if diag[i] != 0 else 1
	for k in n:
		var x0: int = (cx[i] + (0 if diag[i] == 0 else (k if diag[i] == 1 else sx[i] - 1 - k))) * 1000
		var y0: int = (cy[i] + k) * 1000
		var x1: int = x0 + (sx[i] if diag[i] == 0 else 1) * 1000
		var y1: int = y0 + (sy[i] if diag[i] == 0 else 1) * 1000
		var dx: int = maxi(maxi(x0 - x, 0), x - x1)
		var dy: int = maxi(maxi(y0 - y, 0), y - y1)
		best = mini(best, Fixed.isqrt(dx * dx + dy * dy))
	return best
