extends RefCounted
## Pens (data/buildings.json "pen"): the long-term use of herd animals (Dominic: "just slower
## return than killing them all: long term vs short term"). A finished pen is walked into; each
## of its owner's herd animals standing inside it, up to the pen's cap, adds a little food to
## the owner's stock now and then with no worker, and two or more breed a new one now and then.
## Who's penned is read from where the animals stand (no state of its own). A rival steals a
## penned animal only from inside the pen (animals.gd), or once the pen is torn down and its
## animals stand in the open. Integers only.

const SimMap := preload("res://src/sim/sim_map.gd")

const GAP := 850   # milli-tiles between the places in a pen (a sheep is ~810 across)


static func is_pen(w, b: int) -> bool:
	return not w.btypes[w.buildings.kind[b]].pen.is_empty()


## Finished: its fence goes up round open ground, so animals (and anyone) can walk in.
static func opened(w, b: int) -> void:
	w.map.set_walk_over(w.buildings.footprint(b, w.map.width), true)


## Torn down (before its footprint is cleared): the ground is plain ground again. Its animals
## spill out, standing where they were, in the open.
static func gone(w, b: int) -> void:
	if is_pen(w, b) and w.buildings.done[b] == 1:
		w.map.set_walk_over(w.buildings.footprint(b, w.map.width), false)


## The centre of building b, [x, y] in milli-tiles.
static func centre(w, b: int) -> Array:
	var bs = w.buildings
	return [bs.cx[b] * SimMap.TILE + bs.sx[b] * SimMap.TILE / 2, bs.cy[b] * SimMap.TILE + bs.sy[b] * SimMap.TILE / 2]


static func _inside(w, b: int, x: int, y: int) -> bool:
	var bs = w.buildings
	return x >= bs.cx[b] * SimMap.TILE and y >= bs.cy[b] * SimMap.TILE \
		and x < (bs.cx[b] + bs.sx[b]) * SimMap.TILE and y < (bs.cy[b] + bs.sy[b]) * SimMap.TILE


static func _herd(w, i: int) -> bool:
	return w.types[w.units.kind[i]].get("behaviour", "") == "herd"


## The finished pen of its own owner that herd animal i stands in, or -1.
static func pen_at(w, i: int) -> int:
	var u = w.units
	var bs = w.buildings
	for b in bs.count():
		if bs.owner[b] == u.owner[i] and bs.done[b] == 1 and is_pen(w, b) and _inside(w, b, u.x[i], u.y[i]):
			return b
	return -1


## Is unit j inside building b's footprint?
static func inside(w, b: int, j: int) -> bool:
	return _inside(w, b, w.units.x[j], w.units.y[j])


## Pen b's owner's herd animals in it (standing inside, or on their way to a place inside),
## lowest ids first.
static func animals(w, b: int, standing_only := false) -> Array:
	var u = w.units
	var out := []
	for i in u.count():
		if u.owner[i] != w.buildings.owner[b] or not _herd(w, i):
			continue
		var there: bool = _inside(w, b, u.x[i], u.y[i]) and u.moving[i] == 0
		if there or (not standing_only and u.moving[i] == 1 and _inside(w, b, u.tx[i], u.ty[i])):
			out.append(i)
	return out


## Room for another animal in pen b?
static func room(w, b: int) -> bool:
	return w.buildings.done[b] == 1 and animals(w, b).size() < int(w.btypes[w.buildings.kind[b]].pen.animals)


## The nearest finished pen of player's with room, from (x, y), or -1.
static func nearest_with_room(w, player: int, x: int, y: int) -> int:
	var bs = w.buildings
	var best := -1
	var best_d := 1 << 62
	for b in bs.count():
		if bs.owner[b] != player or not is_pen(w, b) or not room(w, b):
			continue
		var c := centre(w, b)
		var d: int = absi(c[0] - x) + absi(c[1] - y)
		if d < best_d:
			best_d = d
			best = b
	return best


## Where herd animal i stands in a pen (or by a Town Center) whose middle is `at`: the first of
## a 3 x 3 grid of places (then round again, offset) no other herd animal of its owner is
## heading for or standing at.
static func slot(w, at: Array, i: int) -> Array:
	var u = w.units
	var taken := {}
	for j in u.count():
		if j != i and u.owner[j] == u.owner[i] and _herd(w, j):
			taken[[u.tx[j], u.ty[j]]] = true
	var first := []
	for n in 18:
		var k: int = n % 9
		var p := [at[0] + (k % 3 - 1) * GAP + (n / 9) * GAP / 2, at[1] + (k / 3 - 1) * GAP + (n / 9) * GAP / 2]
		if first.is_empty():
			first = p
		if not taken.has(p):
			return p
	return first


## Send herd animal i into pen b (forgetting anything else it was told).
static func send(w, i: int, b: int) -> void:
	var u = w.units
	u.orders[i] = []
	var p := slot(w, centre(w, b), i)
	w.order_move(i, p[0], p[1], 200, 0)


## Commands.PEN {ids, building}: these herd animals of the player's go into its pen, while it has room.
static func cmd_pen(w, player: int, a: Dictionary) -> void:
	var b: int = w.buildings.index_of(a.building)
	if b < 0 or w.buildings.owner[b] != player or not is_pen(w, b):
		return
	for uid in a.ids:
		var i: int = w.units.index_of(uid)
		if i >= 0 and w.units.owner[i] == player and _herd(w, i) and room(w, b) and not (inside(w, b, i) and w.units.moving[i] == 0):
			send(w, i, b)


## Commands.RELEASE {building}: every animal in the player's pen walks out to stand in front of it.
static func cmd_release(w, player: int, a: Dictionary) -> void:
	var b: int = w.buildings.index_of(a.building)
	if b < 0 or w.buildings.owner[b] != player or not is_pen(w, b):
		return
	var c := centre(w, b)
	var out := [c[0], c[1] + (w.buildings.sy[b] / 2 + 2) * SimMap.TILE]   # in front (south on the map)
	for i in animals(w, b):
		w.units.orders[i] = []
		var p := slot(w, out, i)
		w.order_move(i, p[0], p[1], 200, 0)


## Each tick: penned animals feed their owner (every food_ticks) and breed (every breed_ticks).
static func tick(w) -> void:
	var bs = w.buildings
	var food: int = w.resources.find("food")
	for b in bs.count():
		if bs.done[b] == 0 or not is_pen(w, b):
			continue
		var p: Dictionary = w.btypes[bs.kind[b]].pen
		var feed: bool = w.tick % int(p.food_ticks) == 0
		var breed: bool = w.tick % int(p.breed_ticks) == 0
		if not feed and not breed:
			continue
		var herd := animals(w, b, true)
		var n: int = mini(herd.size(), int(p.animals))
		if feed and n > 0:
			w.stock[food][bs.owner[b]] += n * int(p.food)
			w.gathered[food][bs.owner[b]] += n * int(p.food)
		if breed and n >= 2 and animals(w, b).size() < int(p.animals):
			_born(w, b, herd[0])


## A new animal, like `parent`, in pen b.
static func _born(w, b: int, parent: int) -> void:
	var u = w.units
	var k: int = u.kind[parent]
	var t: Dictionary = w.types[k]
	var c := centre(w, b)
	var slot_i: int = u.add(w.next_id, u.owner[parent], k, c[0], c[1], t.speed, t.radius, t.hp)
	u.mclass[slot_i] = t.mclass
	w.next_id += 1
	w.events.append({"type": "born", "id": u.id[slot_i], "x": c[0], "y": c[1], "owner": u.owner[slot_i]})
	var p := slot(w, c, slot_i)
	w.order_move(slot_i, p[0], p[1], 200, 0)
