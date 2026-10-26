extends SceneTree
## One round-robin fight's state hash every tick (export.gd state_hash), and its dump at a tick, for the
## Lobster balancer's check. Run: godot --headless --path . --script res://tests/lobster_spike/rr_hash.gd -- <age> <a> <b> [dump tick]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const RoundRobin := preload("res://tests/round_robin.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Commands := preload("res://src/sim/commands.gd")
const Export := preload("res://tests/lobster_spike/export.gd")
const PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans", "greek hoplites", "spooky beetle knights"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var age := int(args[0])
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races := PROMPTS.map(func(p): return gen.generate(p, rules))
	var units: Array = RoundRobin.units_of(races, age)
	var a: Array = units[int(args[1])]
	var b: Array = units[int(args[2])]
	var dump_at := int(args[3]) if args.size() > 3 else -1
	var bare: Dictionary = rules.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	var w := World.new(1, SimMap.load_id("flat_test"), [a[0], b[0]], bare)
	for p in 2:
		RoundRobin.in_age(w, p, age)
	for p in 2:
		var slot: String = [a, b][p][1]
		var t: Dictionary = w.types[w.type_of(p, slot)]
		var cost := 0
		for c in t.cost:
			cost += c
		w.issue(p, Commands.SPAWN, {"slot": slot, "count": maxi(1, (RoundRobin.BUDGET + cost / 2) / cost), "x": RoundRobin.FROM[p][0], "y": RoundRobin.FROM[p][1]})
	while RoundRobin._left(w).has(0):
		w.step()
		print("h %d %d" % [w.tick, Export.state_hash(w)])
	for p in 2:
		var ids := []
		for i in w.units.count():
			if w.units.owner[i] == p:
				ids.append(w.units.id[i])
		w.issue(p, Commands.ATTACK_MOVE, {"ids": ids, "x": RoundRobin.FROM[1 - p][0], "y": RoundRobin.FROM[1 - p][1]})
	while w.tick < RoundRobin.LIMIT:
		w.step()
		print("h %d %d" % [w.tick, Export.state_hash(w)])
		if w.tick == dump_at:
			var out := PackedStringArray()
			Export._dump(w, out)
			print("\n".join(out))
		var left := RoundRobin._left(w)
		if left[0] == 0 or left[1] == 0:
			break
	quit()
