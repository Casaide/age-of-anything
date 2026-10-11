extends SceneTree
## The milestone 10 cost-sanity check: every soldier of several races fights every other at
## equal cost (same budget each side, both attack-moving, in the sim), in a given age. A unit's
## value is its win rate; the metric is that none is more than 20% off the mean. Prints a table,
## outliers first, so pricing can be tuned in data. Deterministic.
## Run: godot --headless --path . --script res://tests/balance.gd [-- age]   (a few minutes)

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const RoundRobin := preload("res://tests/round_robin.gd")

const PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans",
	"greek hoplites", "spooky beetle knights"]
const TOLERANCE := 20   # percent off the mean


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var age := int(args[0]) if args.size() > 0 else 2
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races := PROMPTS.map(func(p): return gen.generate(p, rules))
	var t0 := Time.get_ticks_msec()
	var rr: Dictionary = RoundRobin.run(races, rules, age)
	var units: Array = rr.units
	var rates: Array = rr.rates
	var mean: int = rr.mean
	var order := range(units.size())
	order.sort_custom(func(x, y): return absi(rates[x] - mean) > absi(rates[y] - mean))
	var off := 0
	print("\nAge %d, %d units, %d fights each, mean win rate %d%% (%d s)" % [age, units.size(), units.size() - 1, mean, (Time.get_ticks_msec() - t0) / 1000])
	for k in order:
		var dev: int = (rates[k] - mean) * 100 / maxi(1, mean)
		var flag := "  OUT" if absi(dev) > TOLERANCE else ""
		if flag != "":
			off += 1
		var e: Dictionary = RoundRobin.recipe_at(units[k][0], units[k][1], age).eval
		print("%4d%%  %+4d%%  %-48s cost %3d  hp %3d  atk %2d %s%s" % [rates[k], dev, units[k][2], int(e.cost.food) + int(e.cost.wood) + int(e.cost.get("stone", 0)), int(e.hp), int(e.attack), e.damage, flag])
	print("\n%d of %d units more than %d%% off the mean" % [off, units.size(), TOLERANCE])
	quit()
