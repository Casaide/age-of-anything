extends RefCounted
## Equal-cost round robin (used by tests/balance.gd and tests/tune_points.gd): every soldier of
## the given races fights every other at the same budget in one age, in the sim. Returns
## {units: [[race, slot, label]], rates: [win %], mean, counters: % of same-race counter fights
## the counter won}. Deterministic.

const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Commands := preload("res://src/sim/commands.gd")
const Tech := preload("res://src/sim/tech.gd")

const SLOTS := ["spear", "infantry", "skirmisher", "archer", "large"]
const BUDGET := 1200
const LIMIT := 3000
const FROM := [[11000, 20500], [21000, 20500]]
## Within one race, who should beat whom at equal cost (the genre's counters).
const COUNTERS := [["spear", "large"], ["large", "archer"], ["skirmisher", "archer"], ["archer", "spear"],
	["infantry", "spear"], ["infantry", "skirmisher"], ["archer", "infantry"]]


static func run(races: Array, rules: Dictionary, age: int) -> Dictionary:
	var units := []
	for r in races:
		for slot in SLOTS:
			units.append([r, slot, "%s (%s)" % [recipe_at(r, slot, age).recipe.name, r.name]])
	var wins := []
	var played := []
	wins.resize(units.size())
	wins.fill(0)
	played.resize(units.size())
	played.fill(0)
	var counter_won := 0
	var counter_fights := 0
	for a in units.size():
		for b in range(a + 1, units.size()):
			var r := fight(rules, age, units[a], units[b])
			if units[a][0] == units[b][0]:
				for pair in COUNTERS:
					if [units[a][1], units[b][1]] == pair or [units[b][1], units[a][1]] == pair:
						counter_fights += 1
						var a_is_counter: bool = units[a][1] == pair[0]
						if (r > 0 and a_is_counter) or (r < 0 and not a_is_counter):
							counter_won += 1
			if r == 0:
				continue
			played[a] += 1
			played[b] += 1
			wins[a] += 1 if r > 0 else 0
			wins[b] += 1 if r < 0 else 0
	var rates := []
	var total := 0
	for k in units.size():
		rates.append(wins[k] * 100 / maxi(1, played[k]))
		total += rates[k]
	return {"units": units, "rates": rates, "mean": total / maxi(1, units.size()),
		"counters": counter_won * 100 / maxi(1, counter_fights)}


## +1 if a wins, -1 if b wins, 0 for a draw (by value left standing).
static func fight(rules: Dictionary, age: int, a: Array, b: Array) -> int:
	var bare: Dictionary = rules.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	var w := World.new(1, SimMap.load_id("flat_test"), [a[0], b[0]], bare)
	for p in 2:
		in_age(w, p, age)
	var value := []
	for p in 2:
		var slot: String = [a, b][p][1]
		var t: Dictionary = w.types[w.type_of(p, slot)]
		var cost := 0
		for c in t.cost:
			cost += c
		var n := maxi(1, (BUDGET + cost / 2) / cost)
		value.append(cost)
		w.issue(p, Commands.SPAWN, {"slot": slot, "count": n, "x": FROM[p][0], "y": FROM[p][1]})
	while _left(w).has(0):   # animals are units too: wait for both armies
		w.step()
	for p in 2:
		var ids := []
		for i in w.units.count():
			if w.units.owner[i] == p:
				ids.append(w.units.id[i])
		w.issue(p, Commands.ATTACK_MOVE, {"ids": ids, "x": FROM[1 - p][0], "y": FROM[1 - p][1]})
	var left := [0, 0]
	while w.tick < LIMIT:
		w.step()
		left = _left(w)
		if left[0] == 0 or left[1] == 0:
			break
	var va: int = left[0] * value[0]
	var vb: int = left[1] * value[1]
	return 1 if va > vb else -1 if vb > va else 0


## Put a player in an age with every unit line upgraded up to it (the step recipe_at shows).
static func in_age(w, p: int, age: int) -> void:
	w.ages[p] = age
	for k in w.tech.research.size():
		var r: Dictionary = w.tech.research[k]
		if r.has("line") and int(r.line_age) <= age:
			w.researched[p][k] = 1
	Tech.retype(w, p)


static func name_of(race: Dictionary, slot: String) -> String:
	return unit_of(race, slot).recipe.name


static func unit_of(race: Dictionary, slot: String) -> Dictionary:
	for u in race.units:
		if u.recipe.slot == slot:
			return u
	return race.units[0]


## The recipe a unit fields in this age (the last step of its line at or before it).
static func recipe_at(race: Dictionary, slot: String, age: int) -> Dictionary:
	var u := unit_of(race, slot)
	var step: Dictionary = u.line[0]
	for l in u.line:
		if int(l.age) <= age:
			step = l
	return step


## Soldiers left per player (animals don't count, even a sheep a side has claimed).
static func _left(w) -> Array:
	var left := [0, 0]
	for i in w.units.count():
		if w.units.owner[i] < 2 and not w.types[w.units.kind[i]].has("animal"):
			left[w.units.owner[i]] += 1
	return left
