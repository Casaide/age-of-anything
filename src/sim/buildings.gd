extends RefCounted
## Every building in the sim, as parallel arrays sorted by id (like units.gd).
## Buildings share the World's id counter with units, so an id names exactly one thing.
## A building with done == 0 is a foundation: builders raise `progress` to `build_ticks`.

var id := PackedInt32Array()
var owner := PackedInt32Array()
var kind := PackedInt32Array()        # index into World.btypes
var cx := PackedInt32Array()          # top-left cell
var cy := PackedInt32Array()
var size := PackedInt32Array()        # footprint is size x size cells
var hp := PackedInt32Array()
var progress := PackedInt32Array()    # builder-ticks put in so far
var done := PackedInt32Array()        # 1 once built
var train := PackedInt32Array()       # ticks into the unit at the head of the queue
var rally_x := PackedInt32Array()     # milli-tiles, or -1 for none
var rally_y := PackedInt32Array()
var research := PackedInt32Array()   # what it's researching: an index into tech.research, Tech.AGE_UP, or -1
var research_t := PackedInt32Array() # ticks into it
var queue: Array = []                 # per building: Array of unit type indexes, head first


func count() -> int:
	return id.size()


func add(bid: int, p_owner: int, p_kind: int, p_cx: int, p_cy: int, p_size: int, p_hp: int) -> int:
	assert(id.is_empty() or bid > id[id.size() - 1], "Building ids must grow")
	id.append(bid)
	owner.append(p_owner)
	kind.append(p_kind)
	cx.append(p_cx)
	cy.append(p_cy)
	size.append(p_size)
	hp.append(p_hp)
	progress.append(0)
	done.append(0)
	train.append(0)
	rally_x.append(-1)
	rally_y.append(-1)
	queue.append([])
	research.append(-1)
	research_t.append(0)
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
	size.remove_at(i)
	hp.remove_at(i)
	progress.remove_at(i)
	done.remove_at(i)
	train.remove_at(i)
	rally_x.remove_at(i)
	rally_y.remove_at(i)
	queue.remove_at(i)
	research.remove_at(i)
	research_t.remove_at(i)


## The cells under building slot i, row by row.
func footprint(i: int, map_width: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for y in range(cy[i], cy[i] + size[i]):
		for x in range(cx[i], cx[i] + size[i]):
			out.append(y * map_width + x)
	return out
