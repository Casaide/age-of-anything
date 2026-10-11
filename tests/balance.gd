extends SceneTree
## The milestone 10 cost-sanity check: every soldier of several races fights every other at
## equal cost (same budget each side, both attack-moving, in the sim), in a given age. A unit's
## value is its win rate; the metric is that none is more than 20% off the mean. Prints a table,
## outliers first, so pricing can be tuned in data. Deterministic.
## Run: godot --headless --path . --script res://tests/balance.gd [-- age]   (a few minutes)

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Commands := preload("res://src/sim/commands.gd")
const Tech := preload("res://src/sim/tech.gd")

const PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans",
	"greek hoplites", "spooky beetle knights"]
const SLOTS := ["spear", "skirmisher", "archer", "large"]
const BUDGET := 600
const LIMIT := 3000
const FROM := [[11000, 20500], [21000, 20500]]
const TOLERANCE := 20   # percent off the mean


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var age := int(args[0]) if args.size() > 0 else 2
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var units := []   # [race, slot, name]
	var races := []
	for p in PROMPTS:
		var r: Dictionary = gen.generate(p, rules)
		races.append(r)
		for slot in SLOTS:
			units.append([r, slot, "%s (%s)" % [_name(r, slot), r.name]])
	var wins := []
	var played := []
	wins.resize(units.size())
	wins.fill(0)
	played.resize(units.size())
	played.fill(0)
	var t0 := Time.get_ticks_msec()
	for a in units.size():
		for b in range(a + 1, units.size()):
			var r := _fight(rules, age, units[a], units[b])
			if r == 0:
				continue
			played[a] += 2
			played[b] += 2
			wins[a] += 2 if r > 0 else 0
			wins[b] += 2 if r < 0 else 0
	var rates := []
	var total := 0
	for k in units.size():
		var rate: int = wins[k] * 100 / maxi(1, played[k])
		rates.append(rate)
		total += rate
	var mean := total / units.size()
	var order := range(units.size())
	order.sort_custom(func(x, y): return absi(rates[x] - mean) > absi(rates[y] - mean))
	var off := 0
	print("\nAge %d, %d units, %d fights each, mean win rate %d%% (%d s)" % [age, units.size(), units.size() - 1, mean, (Time.get_ticks_msec() - t0) / 1000])
	for k in order:
		var dev: int = (rates[k] - mean) * 100 / maxi(1, mean)
		var flag := "  OUT" if absi(dev) > TOLERANCE else ""
		if flag != "":
			off += 1
		var e: Dictionary = _eval(units[k][0], units[k][1], age)
		print("%4d%%  %+4d%%  %-48s cost %3d  hp %3d  atk %2d %s%s" % [rates[k], dev, units[k][2], int(e.cost.food) + int(e.cost.wood) + int(e.cost.get("stone", 0)), int(e.hp), int(e.attack), e.damage, flag])
	print("\n%d of %d units more than %d%% off the mean" % [off, units.size(), TOLERANCE])
	quit()


## +1 if a wins, -1 if b wins, 0 for a draw (by value left standing).
func _fight(rules: Dictionary, age: int, a: Array, b: Array) -> int:
	var bare: Dictionary = rules.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	var w := World.new(1, SimMap.load_id("flat_test"), [a[0], b[0]], bare)
	for p in 2:
		w.ages[p] = age
		Tech.retype(w, p)
	var value := []
	for p in 2:
		var slot: String = [a, b][p][1]
		var t: Dictionary = w.types[w.type_of(p, slot)]
		var cost: int = 0
		for c in t.cost:
			cost += c
		var n := maxi(1, (BUDGET + cost / 2) / cost)
		value.append(cost)
		w.issue(p, Commands.SPAWN, {"slot": slot, "count": n, "x": FROM[p][0], "y": FROM[p][1]})
	while w.units.count() == 0:
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
		left = [0, 0]
		for i in w.units.count():
			left[w.units.owner[i]] += 1
		if left[0] == 0 or left[1] == 0:
			break
	var va: int = left[0] * value[0]
	var vb: int = left[1] * value[1]
	return 1 if va > vb else -1 if vb > va else 0


func _name(race: Dictionary, slot: String) -> String:
	for u in race.units:
		if u.recipe.slot == slot:
			return u.recipe.name
	return slot


func _eval(race: Dictionary, slot: String, age: int) -> Dictionary:
	for u in race.units:
		if u.recipe.slot == slot:
			var e: Dictionary = u.line[0].eval
			for l in u.line:
				if int(l.age) <= age:
					e = l.eval
			return e
	return {}
