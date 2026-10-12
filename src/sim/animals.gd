extends RefCounted
## Animals (data/animals.json): deer to hunt (they bolt when hurt), boar (they turn on whoever
## hurts them) and sheep to herd (they belong to the first player whose unit comes close, and
## follow orders like units; a claimed one walks into its owner's pen (pens.gd) if it has one
## with room, else to a spot by their Town Center, and stands there grazing). Nobody owns them at first: their owner is the world's `gaia`,
## one past the last player, on a team of its own. A dead animal leaves a carcass where it
## fell, food to gather, and the hunters who brought it down start gathering it. Integers only.

const SimMap := preload("res://src/sim/sim_map.gd")
const Economy := preload("res://src/sim/economy.gd")
const Flow := preload("res://src/sim/flow.gd")
const Pens := preload("res://src/sim/pens.gd")

const CLAIM_EVERY := 10    # ticks between checks for whose sheep is whose


static func load_data() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals.json"))
	assert(d != null, "Bad or missing data/animals.json")
	return d


## Animal unit types (owned by gaia), after the players' types.
static func add_types(w, d: Dictionary) -> void:
	w.claim_tiles = int(d.claim_tiles)
	var ids: Array = d.animals.keys()
	ids.sort()
	for id in ids:
		var a: Dictionary = d.animals[id]
		var arm := {}
		for k in a.armour:
			arm[k] = int(a.armour[k])
		var e := {"hp": int(a.hp), "attack": maxi(1, int(a.attack)), "damage": "melee", "armour": arm, "range": 1,
			"speed": int(a.speed), "bonus": {}, "tags": ["animal", id], "points": 0, "cost": {}, "train_time": 1, "pop": 0}
		var t: Dictionary = w._make_type(w.gaia, {"recipe": a.recipe, "eval": e})
		t.animal = id
		t.food = int(a.food)
		t.behaviour = a.behaviour
		t.flee = int(a.get("flee_tiles", 0)) * SimMap.TILE
		t.harmless = int(a.attack) == 0
		t.min_damage = int(a.get("slaughter_damage", 0))   # every blow does at least this (a sheep is quick work)
		w.types.append(t)


static func type_of(w, id: String) -> int:
	for k in w.types.size():
		if w.types[k].get("animal", "") == id:
			return k
	return -1


## Sheep and boar round each start, deer herds out on the open map (seeded: the same map
## and seed always give the same animals). A map may bring its own spawn (same shape); an
## entry with "size" places herds: one animal on the ring, the rest beside it. On a map with
## "symmetry": "rotate" the second start gets the first one's animals turned half a turn, and
## each wild herd gets a twin turned the same way, so both sides find the same meat.
static func place(w, spawn: Dictionary) -> void:
	var m = w.map
	if not m.animals.is_empty():
		spawn = m.animals
	# A map turned half a turn lists its starts in mirror pairs (0 and 1, 2 and 3: a 2v2's teams
	# are 0, 2 against 1, 3), and each odd start gets the mirror image of its partner's animals.
	var mirror: bool = m.symmetry == "rotate" and m.starts.size() % 2 == 0
	var taken := {}
	var placed := []   # [kind, cell] for the last even start, for its mirror image
	for p in mini(w.races.size(), m.starts.size()):
		if mirror and p % 2 == 1:
			for e in placed:
				var c: int = m.width * m.height - 1 - e[1]
				if _open(w, c, taken):
					taken[c] = true
					_add(w, e[0], c)
			continue
		placed = []
		var s: Array = m.starts[p]
		for entry in spawn.near_start:
			var k := type_of(w, entry.kind)
			var herd := int(entry.get("size", 1))
			for n in int(entry.count):
				var c: int = _free_cell(w, s[0] / SimMap.TILE, s[1] / SimMap.TILE, int(entry.min), int(entry.max), taken)
				if c < 0:
					continue
				_add(w, k, c)
				placed.append([k, c])
				for h in herd - 1:
					var b: int = _free_cell(w, c % m.width, c / m.width, 0, 1, taken)
					if b >= 0:
						_add(w, k, b)
						placed.append([k, b])
	for entry in spawn.wild:
		var k := type_of(w, entry.kind)
		for h in int(entry.herds):
			var centre := -1
			for tries in 60:
				var x: int = w.rng.range_int(2, m.width - 3)
				var y: int = w.rng.range_int(2, m.height - 3)
				var far := true
				for p in mini(w.races.size(), m.starts.size()):
					var s: Array = m.starts[p]
					if absi(x - s[0] / SimMap.TILE) + absi(y - s[1] / SimMap.TILE) < int(entry.away):
						far = false
				if far and _open(w, y * m.width + x, taken):
					centre = y * m.width + x
					break
			if centre < 0:
				continue
			for n in int(entry.size):
				var c: int = _free_cell(w, centre % m.width, centre / m.width, 0, 2, taken)
				if c >= 0:
					_add(w, k, c)
					var twin: int = m.width * m.height - 1 - c
					if mirror and _open(w, twin, taken):
						taken[twin] = true
						_add(w, k, twin)


static func _open(w, c: int, taken: Dictionary) -> bool:
	return w.map.walk[c] == 1 and w.map.occupied[c] == 0 and w.map.amount[c] == 0 and not taken.has(c)


static func _free_cell(w, cx: int, cy: int, lo: int, hi: int, taken: Dictionary) -> int:
	var m = w.map
	for tries in 40:
		var x: int = cx + w.rng.range_int(-hi, hi)
		var y: int = cy + w.rng.range_int(-hi, hi)
		if maxi(absi(x - cx), absi(y - cy)) < lo or x < 1 or y < 1 or x >= m.width - 1 or y >= m.height - 1:
			continue
		var c: int = y * m.width + x
		if _open(w, c, taken):
			taken[c] = true
			return c
	return -1


static func _add(w, k: int, c: int) -> void:
	var t: Dictionary = w.types[k]
	var slot: int = w.units.add(w.next_id, w.gaia, k, (c % w.map.width) * SimMap.TILE + 500, (c / w.map.width) * SimMap.TILE + 500,
		t.speed, t.radius, t.hp)
	w.units.mclass[slot] = t.mclass
	w.next_id += 1


## Each tick: pens feed and breed (pens.gd); a herd animal goes to the first player (in order)
## with a unit within claim range while none of its owner's units are (unowned sheep: the
## nearest player's). So a rival steals your sheep by walking up while yours aren't near, as in
## the genre; a penned one only by getting into the pen (or tearing it down).
static func tick(w) -> void:
	Pens.tick(w)
	if w.tick % CLAIM_EVERY != 0:
		return
	var u = w.units
	var reach: int = w.claim_tiles * SimMap.TILE
	for i in u.count():
		if w.types[u.kind[i]].get("behaviour", "") != "herd":
			continue
		var owner: int = u.owner[i]
		var best := -1
		var best_d := reach * reach + 1
		var guarded := false
		var pen: int = Pens.pen_at(w, i) if owner != w.gaia else -1
		for j in u.count():
			var o: int = u.owner[j]
			if o == w.gaia or w.types[u.kind[j]].has("animal"):
				continue
			if pen >= 0 and o != owner and not Pens.inside(w, pen, j):
				continue   # penned: a rival must get into the pen
			var dx: int = u.x[j] - u.x[i]
			var dy: int = u.y[j] - u.y[i]
			var d := dx * dx + dy * dy
			if d > reach * reach:
				continue
			if o == owner:
				guarded = true
				break
			if d < best_d or (d == best_d and o < best):
				best_d = d
				best = o
		if best >= 0 and not guarded:
			_claim(w, i, best)


## A herd animal changes hands: whatever it was doing for its old owner (a walk, a queued order)
## is forgotten, and it walks into its new owner's nearest pen with room, else to a spot by their
## Town Center, and stays there. If its new owner is already slaughtering it, it stands still
## for the knife instead.
static func _claim(w, i: int, player: int) -> void:
	var u = w.units
	u.owner[i] = player
	u.foe[i] = 0   # Combat.clear (combat.gd preloads this file)
	u.stance[i] = 0
	u.patient[i] = 0
	Economy.clear_task(w, i)
	u.orders[i] = []
	u.moving[i] = 0
	for j in u.count():
		if u.foe[j] == u.id[i] and u.owner[j] == player:
			return
	var pen := Pens.nearest_with_room(w, player, u.x[i], u.y[i])
	if pen >= 0:
		Pens.send(w, i, pen)
		return
	var b := _nearest_town_center(w, i)
	if b < 0:
		return
	var at := Pens.slot(w, herd_spot(w, b), i)
	w.order_move(i, at[0], at[1], 200, 0)


static func _nearest_town_center(w, i: int) -> int:
	var bs = w.buildings
	var u = w.units
	var best := -1
	var best_d := 1 << 62
	for b in bs.count():
		if bs.owner[b] != u.owner[i] or bs.done[b] == 0 or w.btypes[bs.kind[b]].id != "town_center":
			continue
		var bx: int = bs.cx[b] * SimMap.TILE + bs.sx[b] * SimMap.TILE / 2
		var by: int = bs.cy[b] * SimMap.TILE + bs.sy[b] * SimMap.TILE / 2
		var d: int = absi(bx - u.x[i]) + absi(by - u.y[i])
		if d < best_d:
			best_d = d
			best = b
	return best


const PEN := 3                     # a herd spot is PEN x PEN tiles
const DIRS := [[1, 1], [1, 0], [0, 1], [-1, 1], [1, -1], [-1, 0], [0, -1], [-1, -1]]

## Town Center building b's herd spot: the centre [x, y] (milli-tiles) of a PEN x PEN patch of
## open ground beside it, chosen once when its first sheep comes home with no pen to go to
## (Dominic: claimed sheep gather at one spot and stop). The side away from the map's middle comes
## first (the safe back yard), ties in DIRS order; the patch must be walkable, unbuilt and
## free of resources, or the most open one is taken.
static func herd_spot(w, b: int) -> Array:
	var bs = w.buildings
	var id: int = bs.id[b]
	if w.herd_spots.has(id):
		return w.herd_spots[id]
	var m = w.map
	var tx: int = bs.cx[b] + bs.sx[b] / 2   # the centre tile (Town Centers are square, odd-sized)
	var ty: int = bs.cy[b] + bs.sy[b] / 2
	var off: int = bs.sx[b] / 2 + 2 + PEN / 2   # a tile of path between the walls and the pen
	var mx: int = m.width / 2
	var my: int = m.height / 2
	var best := []
	var best_score := -1
	for k in DIRS.size():
		var px: int = tx + DIRS[k][0] * off
		var py: int = ty + DIRS[k][1] * off
		var open := 0
		for dy in range(-(PEN / 2), PEN / 2 + 1):
			for dx in range(-(PEN / 2), PEN / 2 + 1):
				var x: int = px + dx
				var y: int = py + dy
				if x >= 0 and y >= 0 and x < m.width and y < m.height:
					var c: int = y * m.width + x
					if m.walk[c] == 1 and m.occupied[c] == 0 and m.amount[c] == 0:
						open += 1
		var away: int = absi(px - mx) + absi(py - my)
		var score: int = open * 10000 + away   # open ground first, then the back yard
		if score > best_score:
			best_score = score
			best = [px * SimMap.TILE + SimMap.TILE / 2, py * SimMap.TILE + SimMap.TILE / 2]
	w.herd_spots[id] = best
	return best


## Hurt this tick by `by` (a unit id): a deer bolts away from it; a sheep stands still.
static func hurt(w, i: int, by: int) -> void:
	var t: Dictionary = w.types[w.units.kind[i]]
	if t.get("behaviour", "") == "herd":
		w.units.moving[i] = 0
		w.units.orders[i] = []
		return
	if t.get("behaviour", "") != "flee":
		return
	var a: int = w.units.index_of(by)
	if a < 0:
		return
	var u = w.units
	var dx: int = u.x[i] - u.x[a]
	var dy: int = u.y[i] - u.y[a]
	var len := maxi(1, absi(dx) + absi(dy))
	w.order_move(i, u.x[i] + dx * t.flee / len, u.y[i] + dy * t.flee / len, 300, 0)


## An animal died at slot i: its carcass, food, lies on the nearest open cell, and the
## workers that were fighting it gather it.
static func died(w, i: int) -> void:
	var t: Dictionary = w.types[w.units.kind[i]]
	if int(t.get("food", 0)) <= 0:
		return
	var m = w.map
	var here: int = m.cell_of(w.units.x[i], w.units.y[i])
	var cell := -1
	for r in 3:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var x: int = here % m.width + dx
				var y: int = here / m.width + dy
				if cell < 0 and x >= 0 and y >= 0 and x < m.width and y < m.height:
					var c: int = y * m.width + x
					if m.walk[c] == 1 and m.occupied[c] == 0 and m.amount[c] == 0:
						cell = c
	if cell < 0:
		return
	m.set_terrain(cell, m.terrain_ids.find("carcass"))
	m.amount[cell] = int(t.food)
	var dead: int = w.units.id[i]
	var u = w.units
	for j in u.count():
		if u.foe[j] == dead and w.types[u.kind[j]].worker:
			u.foe[j] = 0
			Economy.start_gather(w, j, cell, Economy.kind_of(w, "food"))
