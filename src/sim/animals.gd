extends RefCounted
## Animals (data/animals.json): deer to hunt (they bolt when hurt), boar (they turn on whoever
## hurts them) and sheep to herd (they belong to the first player whose unit comes close, and
## follow orders like units). Nobody owns them at first: their owner is the world's `gaia`,
## one past the last player, on a team of its own. A dead animal leaves a carcass where it
## fell, food to gather, and the hunters who brought it down start gathering it. Integers only.

const SimMap := preload("res://src/sim/sim_map.gd")
const Economy := preload("res://src/sim/economy.gd")
const Flow := preload("res://src/sim/flow.gd")

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
		w.types.append(t)


static func type_of(w, id: String) -> int:
	for k in w.types.size():
		if w.types[k].get("animal", "") == id:
			return k
	return -1


## Sheep and boar round each start, deer herds out on the open map (seeded: the same map
## and seed always give the same animals).
static func place(w, spawn: Dictionary) -> void:
	var m = w.map
	var taken := {}
	for p in mini(w.races.size(), m.starts.size()):
		var s: Array = m.starts[p]
		for entry in spawn.near_start:
			var k := type_of(w, entry.kind)
			for n in int(entry.count):
				var c: int = _free_cell(w, s[0] / SimMap.TILE, s[1] / SimMap.TILE, int(entry.min), int(entry.max), taken)
				if c >= 0:
					_add(w, k, c)
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


## Each tick: an unowned herd animal goes to the first player (in order) with a unit within
## claim range. (Owned sheep stay owned; the genre lets a rival steal them by getting closer
## while yours aren't near; not yet.)
static func tick(w) -> void:
	if w.tick % CLAIM_EVERY != 0:
		return
	var u = w.units
	var reach: int = w.claim_tiles * SimMap.TILE
	for i in u.count():
		if u.owner[i] != w.gaia or w.types[u.kind[i]].get("behaviour", "") != "herd":
			continue
		var best := -1
		var best_d := reach * reach + 1
		for j in u.count():
			var o: int = u.owner[j]
			if o == w.gaia or w.types[u.kind[j]].has("animal"):
				continue
			var dx: int = u.x[j] - u.x[i]
			var dy: int = u.y[j] - u.y[i]
			var d := dx * dx + dy * dy
			if d < best_d or (d == best_d and o < best):
				best_d = d
				best = o
		if best >= 0:
			u.owner[i] = best


## Hurt this tick by `by` (a unit id): a deer bolts away from it.
static func hurt(w, i: int, by: int) -> void:
	var t: Dictionary = w.types[w.units.kind[i]]
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
