extends RefCounted
## Every building in the sim, as parallel arrays sorted by id (like units.gd).
## Buildings share the World's id counter with units, so an id names exactly one thing.
## A building with done == 0 is a foundation: builders raise `progress` to `build_ticks`.

var id := PackedInt32Array()
var owner := PackedInt32Array()
var kind := PackedInt32Array()        # index into World.btypes
var cx := PackedInt32Array()          # top-left cell
var cy := PackedInt32Array()
var sx := PackedInt32Array()          # footprint: sx cells along x by sy along y (square but for gates)
var sy := PackedInt32Array()
var hp := PackedInt32Array()
var progress := PackedInt32Array()    # builder-ticks put in so far
var done := PackedInt32Array()        # 1 once built
var train := PackedInt32Array()       # ticks into the unit or tech at the head of the queue
var rally_x := PackedInt32Array()     # milli-tiles, or -1 for none
var rally_y := PackedInt32Array()
var cooldown := PackedInt32Array()   # towers: ticks until the next shot
var queue: Array = []                 # per building, head first: unit type indexes (>= 0) and techs (Tech.entry)


func count() -> int:
	return id.size()


func add(bid: int, p_owner: int, p_kind: int, p_cx: int, p_cy: int, p_sx: int, p_sy: int, p_hp: int) -> int:
	assert(id.is_empty() or bid > id[id.size() - 1], "Building ids must grow")
	id.append(bid)
	owner.append(p_owner)
	kind.append(p_kind)
	cx.append(p_cx)
	cy.append(p_cy)
	sx.append(p_sx)
	sy.append(p_sy)
	hp.append(p_hp)
	progress.append(0)
	done.append(0)
	train.append(0)
	rally_x.append(-1)
	rally_y.append(-1)
	queue.append([])
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
	hp.remove_at(i)
	progress.remove_at(i)
	done.remove_at(i)
	train.remove_at(i)
	rally_x.remove_at(i)
	rally_y.remove_at(i)
	queue.remove_at(i)
	cooldown.remove_at(i)


## The cells under building slot i, row by row.
func footprint(i: int, map_width: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for y in range(cy[i], cy[i] + sy[i]):
		for x in range(cx[i], cx[i] + sx[i]):
			out.append(y * map_width + x)
	return out
