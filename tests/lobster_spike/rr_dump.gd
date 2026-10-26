extends SceneTree
## Every round-robin fight's result (tests/round_robin.gd), one line a pair, for the Lobster balancer's check.
## Run: godot --headless --path . --script res://tests/lobster_spike/rr_dump.gd -- <out> <age> [part/parts]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const RoundRobin := preload("res://tests/round_robin.gd")
const PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans", "greek hoplites", "spooky beetle knights"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races := PROMPTS.map(func(p): return gen.generate(p, rules))
	var res: Dictionary = RoundRobin.fights(races, rules, int(args[1]))
	var keys: Array = res.keys()
	keys.sort_custom(func(a, b): return int(a.get_slice(",", 0)) * 1000 + int(a.get_slice(",", 1)) < int(b.get_slice(",", 0)) * 1000 + int(b.get_slice(",", 1)))
	var f := FileAccess.open(args[0], FileAccess.WRITE)
	for k in keys:
		f.store_line("%s %d" % [k, res[k]])
	quit()
