extends SceneTree
## The milestone 10 cost-sanity check: every soldier of several races fights every other at
## equal cost (same budget each side, both attack-moving, in the sim), in a given age. A unit's
## value is its win rate; the metric is that none is more than 20% off the mean. Prints a table,
## outliers first, so pricing can be tuned in data. Deterministic.
## Run: godot --headless --path . --script res://tests/balance.gd [-- age [combat_rule=value ...] ["+another prompt" ...] [serial] [jobs=N]]
## (the fights are shared between processes side by side unless "serial")

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const RoundRobin := preload("res://tests/round_robin.gd")
const Par := preload("res://tests/par.gd")

const PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans",
	"greek hoplites", "spooky beetle knights"]
const TOLERANCE := 20   # percent off the mean


func _init() -> void:
	var all_args := Par.plain(OS.get_cmdline_user_args())
	var part := all_args.filter(func(a): return a.begins_with("part:"))   # part:<k>/<n>: one share of the fights (a child)
	var serial := all_args.has("serial")
	var args := all_args.filter(func(a): return not a.begins_with("part:") and a != "serial")
	var age := int(args[0]) if args.size() > 0 else 2
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var prompts := PROMPTS.duplicate()
	for arg in args.slice(1):   # rule overrides to try, e.g. kite_gap=1500; "+prompt" adds a race
		if arg.begins_with("+"):
			prompts.append(arg.trim_prefix("+"))
			continue
		rules.combat[arg.get_slice("=", 0)] = int(arg.get_slice("=", 1))
		if part.is_empty():
			print("trying combat.%s = %s" % [arg.get_slice("=", 0), arg.get_slice("=", 1)])
	var races := prompts.map(func(p): return gen.generate(p, rules))
	if not part.is_empty():
		var kn: String = part[0].trim_prefix("part:")
		print("@@ fights ", JSON.stringify(RoundRobin.fights(races, rules, age, int(kn.get_slice("/", 0)), int(kn.get_slice("/", 1)))))
		quit()
		return
	var t0 := Time.get_ticks_msec()
	var results := {}
	if serial:
		results = RoundRobin.fights(races, rules, age)
	else:   # the fights shared between processes side by side
		var n := Par.jobs_wanted(OS.get_cmdline_user_args())
		var jobs := range(n).map(func(k): return Par.job("balance/%d" % k, "res://tests/balance.gd", args + ["part:%d/%d" % [k, n]]))
		for r in Par.run(jobs, n, true):
			assert(r.code == 0 and r.stats.has("fights"), "balance: %s failed, see %s" % [r.name, r.log])
			results.merge(r.stats.fights)
	var rr: Dictionary = RoundRobin.tally(races, age, results)
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
	print("\n%d of %d units more than %d%% off the mean; counters won %d%% of same-race counter fights" % [off, units.size(), TOLERANCE, rr.counters])
	quit()
