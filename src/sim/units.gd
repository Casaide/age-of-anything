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
var reach := PackedInt32Array()    # 0: arrive at the point (tx, ty); 1: arrive next to the rect below;
                                   # 2: arrive at the point (tx, ty), its own place beside the rect (World.order_beside)
var rx0 := PackedInt32Array()      # target rect (milli-tiles, inclusive) when reach == 1
var ry0 := PackedInt32Array()
var rx1 := PackedInt32Array()
var ry1 := PackedInt32Array()
var task := PackedInt32Array()     # Economy.NONE / GATHER / RETURN / BUILD
var target := PackedInt32Array()   # resource cell (GATHER) or building id (RETURN, BUILD)
var home := PackedInt32Array()     # resource cell to go back to after a drop-off, or -1
var gspot := PackedInt32Array()    # its standing spot round `home` (Economy.SPOTS), held while it works there, or -1
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
var patient := PackedInt32Array()  # healers: the unit id being healed (or walked to), or 0 (heal.gd)
var pace := PackedInt32Array()     # a group move's pace (its slowest member's speed), or 0: own speed
var amc := PackedInt32Array()      # an attack-move's centre cell (its field), or -1; amx/amy is the unit's own slot
var route := PackedInt32Array()    # trade carts: the home market's id (target is the far one; trade.gd), or 0
var ready := PackedInt32Array()    # packing engines (the great sling): ticks stood unpacking (>= its unpack: set up),
                                   # or below 0 while packing up (counts up to 0; World._pack)
# Walls you stand on (walls.gd). Cells are stored + 1, so 0 means none.
var perch := PackedInt32Array()    # the walkway cell it stands on, + 1 (0: on the ground)
var wgoal := PackedInt32Array()    # on a wall: the walkway cell it is walking to, + 1; climbing (Economy.CLIMB): where it goes once up
var wnext := PackedInt32Array()    # on a wall: the next cell on its way, + 1
var wexit := PackedInt32Array()    # on a wall: the way down it is leaving by (a building or siege tower id), or 0
var wtime := PackedInt32Array()    # on a wall: ticks left climbing down at its way down, or 0
var changes := 0                   # bumped on every add, insert and removal (World.step rebuilds its buckets)
var orders: Array = []             # per unit: queued orders [{type, args}] (shift-queued), oldest first


func count() -> int:
	return id.size()


func add(uid: int, p_owner: int, p_kind: int, p_x: int, p_y: int, p_speed: int, p_radius: int, p_hp: int) -> int:
	assert(id.is_empty() or uid > id[id.size() - 1], "Unit ids must grow")
	return _put(id.size(), uid, p_owner, p_kind, p_x, p_y, p_speed, p_radius, p_hp)


## A unit back in the arrays under an id it had before (out of a building it sheltered in,
## garrison.gd), in its place by id, so slots stay sorted. Returns its slot.
func insert(uid: int, p_owner: int, p_kind: int, p_x: int, p_y: int, p_speed: int, p_radius: int, p_hp: int) -> int:
	var at := id.bsearch(uid)
	assert(at >= id.size() or id[at] != uid, "Unit %d is already out" % uid)
	return _put(at, uid, p_owner, p_kind, p_x, p_y, p_speed, p_radius, p_hp)


func _put(at: int, uid: int, p_owner: int, p_kind: int, p_x: int, p_y: int, p_speed: int, p_radius: int, p_hp: int) -> int:
	changes += 1
	id.insert(at, uid)
	owner.insert(at, p_owner)
	kind.insert(at, p_kind)
	x.insert(at, p_x)
	y.insert(at, p_y)
	px.insert(at, p_x)
	py.insert(at, p_y)
	tx.insert(at, p_x)
	ty.insert(at, p_y)
	moving.insert(at, 0)
	arrive.insert(at, 0)
	wx.insert(at, p_x)
	wy.insert(at, p_y)
	group.insert(at, 0)
	stuck.insert(at, 0)
	prog.insert(at, -1)
	fkey.insert(at, -1)
	reach.insert(at, 0)
	rx0.insert(at, 0)
	ry0.insert(at, 0)
	rx1.insert(at, 0)
	ry1.insert(at, 0)
	task.insert(at, 0)
	target.insert(at, -1)
	home.insert(at, -1)
	gspot.insert(at, -1)
	carry_kind.insert(at, 0)
	carry.insert(at, 0)
	work.insert(at, 0)
	speed.insert(at, p_speed)
	radius.insert(at, p_radius)
	hp.insert(at, p_hp)
	foe.insert(at, 0)
	cooldown.insert(at, 0)
	stance.insert(at, 0)
	posture.insert(at, 0)
	gx.insert(at, p_x)
	gy.insert(at, p_y)
	amx.insert(at, 0)
	amy.insert(at, 0)
	orders.insert(at, [])
	mclass.insert(at, 0)
	patient.insert(at, 0)
	pace.insert(at, 0)
	amc.insert(at, -1)
	route.insert(at, 0)
	ready.insert(at, 0)
	perch.insert(at, 0)
	wgoal.insert(at, 0)
	wnext.insert(at, 0)
	wexit.insert(at, 0)
	wtime.insert(at, 0)
	return at


## Slot of a unit id, or -1 if it doesn't exist (any more).
func index_of(uid: int) -> int:
	var i := id.bsearch(uid)
	if i < id.size() and id[i] == uid:
		return i
	return -1


func remove_at(i: int) -> void:
	changes += 1
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
	gspot.remove_at(i)
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
	patient.remove_at(i)
	pace.remove_at(i)
	amc.remove_at(i)
	route.remove_at(i)
	ready.remove_at(i)
	perch.remove_at(i)
	wgoal.remove_at(i)
	wnext.remove_at(i)
	wexit.remove_at(i)
	wtime.remove_at(i)


func save_prev() -> void:
	px = x.duplicate()
	py = y.duplicate()
