extends RefCounted
## Every unit in the sim, stored as parallel packed int arrays (one slot per unit).
## Slots stay sorted by ascending id: ids only ever grow and removal keeps order,
## so a plain index loop is the deterministic iteration order.
##
## Hot loops should copy an array to a local, edit it, and assign it back once
## (packed arrays are copy-on-write, so writing through a local doesn't stick).

var id := PackedInt32Array()
var owner := PackedInt32Array()
var kind := PackedInt32Array()     # index into World.types
var x := PackedInt32Array()        # milli-tiles
var y := PackedInt32Array()
var px := PackedInt32Array()       # position at the start of the current tick, for views
var py := PackedInt32Array()
var tx := PackedInt32Array()       # move target
var ty := PackedInt32Array()
var moving := PackedInt32Array()   # 1 while heading for (tx, ty)
var arrive := PackedInt32Array()   # stop once this close to the target (milli-tiles)
var wx := PackedInt32Array()       # current waypoint (from the flow field) towards the target
var wy := PackedInt32Array()
var group := PackedInt32Array()    # move group: one per MOVE command, 0 if never ordered
var stuck := PackedInt32Array()    # consecutive ticks a move made no progress
var speed := PackedInt32Array()    # milli-tiles per tick
var radius := PackedInt32Array()   # milli-tiles
var hp := PackedInt32Array()


func count() -> int:
	return id.size()


func add(uid: int, p_owner: int, p_kind: int, p_x: int, p_y: int, p_speed: int, p_radius: int, p_hp: int) -> int:
	assert(id.is_empty() or uid > id[id.size() - 1], "Unit ids must grow")
	id.append(uid)
	owner.append(p_owner)
	kind.append(p_kind)
	x.append(p_x)
	y.append(p_y)
	px.append(p_x)
	py.append(p_y)
	tx.append(p_x)
	ty.append(p_y)
	moving.append(0)
	arrive.append(0)
	wx.append(p_x)
	wy.append(p_y)
	group.append(0)
	stuck.append(0)
	speed.append(p_speed)
	radius.append(p_radius)
	hp.append(p_hp)
	return id.size() - 1


## Slot of a unit id, or -1 if it doesn't exist (any more).
func index_of(uid: int) -> int:
	var i := id.bsearch(uid)
	if i < id.size() and id[i] == uid:
		return i
	return -1


func remove_at(i: int) -> void:
	# Field by field: packed arrays put in an Array literal would be copies.
	id.remove_at(i)
	owner.remove_at(i)
	kind.remove_at(i)
	x.remove_at(i)
	y.remove_at(i)
	px.remove_at(i)
	py.remove_at(i)
	tx.remove_at(i)
	ty.remove_at(i)
	moving.remove_at(i)
	arrive.remove_at(i)
	wx.remove_at(i)
	wy.remove_at(i)
	group.remove_at(i)
	stuck.remove_at(i)
	speed.remove_at(i)
	radius.remove_at(i)
	hp.remove_at(i)


func save_prev() -> void:
	px = x.duplicate()
	py = y.duplicate()
