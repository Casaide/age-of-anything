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
var stuck := PackedInt32Array()    # ticks a move has made no progress (net of pushes; see World._move)
var prog := PackedInt32Array()     # how far from its target it was at the last progress check (-1: none yet)
var fkey := PackedInt32Array()     # flow field key being followed (see World.field_key)
var reach := PackedInt32Array()    # 0: arrive at the point (tx, ty); 1: arrive next to the rect below
var rx0 := PackedInt32Array()      # target rect (milli-tiles, inclusive) when reach == 1
var ry0 := PackedInt32Array()
var rx1 := PackedInt32Array()
var ry1 := PackedInt32Array()
var task := PackedInt32Array()     # Economy.NONE / GATHER / RETURN / BUILD
var target := PackedInt32Array()   # resource cell (GATHER) or building id (RETURN, BUILD)
var home := PackedInt32Array()     # resource cell to go back to after a drop-off, or -1
var carry_kind := PackedInt32Array()   # 0 nothing, 1 food, 2 wood
var carry := PackedInt32Array()
var work := PackedInt32Array()     # ticks into the current gather
var speed := PackedInt32Array()    # milli-tiles per tick
var radius := PackedInt32Array()   # milli-tiles
var hp := PackedInt32Array()
var foe := PackedInt32Array()      # unit or building id being fought, or 0
var cooldown := PackedInt32Array() # ticks until the next blow
var stance := PackedInt32Array()   # what it is doing: Combat.NONE / ORDERED / AUTO / ATTACK_MOVE / RETURN
var posture := PackedInt32Array()  # the player-set stance: Combat.AGGRESSIVE / DEFENSIVE / STAND / PASSIVE
var gx := PackedInt32Array()       # where it stood when it last went for a foe on its own (defensive units walk back)
var gy := PackedInt32Array()
var amx := PackedInt32Array()      # attack-move destination (milli-tiles)
var amy := PackedInt32Array()
var mclass := PackedInt32Array()   # movement class (SimMap.CLASSES)
var orders: Array = []             # per unit: queued orders [{type, args}] (shift-queued), oldest first


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
	prog.append(-1)
	fkey.append(-1)
	reach.append(0)
	rx0.append(0)
	ry0.append(0)
	rx1.append(0)
	ry1.append(0)
	task.append(0)
	target.append(-1)
	home.append(-1)
	carry_kind.append(0)
	carry.append(0)
	work.append(0)
	speed.append(p_speed)
	radius.append(p_radius)
	hp.append(p_hp)
	foe.append(0)
	cooldown.append(0)
	stance.append(0)
	posture.append(0)
	gx.append(p_x)
	gy.append(p_y)
	amx.append(0)
	amy.append(0)
	orders.append([])
	mclass.append(0)
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
	prog.remove_at(i)
	fkey.remove_at(i)
	reach.remove_at(i)
	rx0.remove_at(i)
	ry0.remove_at(i)
	rx1.remove_at(i)
	ry1.remove_at(i)
	task.remove_at(i)
	target.remove_at(i)
	home.remove_at(i)
	carry_kind.remove_at(i)
	carry.remove_at(i)
	work.remove_at(i)
	speed.remove_at(i)
	radius.remove_at(i)
	hp.remove_at(i)
	foe.remove_at(i)
	cooldown.remove_at(i)
	stance.remove_at(i)
	posture.remove_at(i)
	gx.remove_at(i)
	gy.remove_at(i)
	amx.remove_at(i)
	amy.remove_at(i)
	orders.remove_at(i)
	mclass.remove_at(i)


func save_prev() -> void:
	px = x.duplicate()
	py = y.duplicate()
