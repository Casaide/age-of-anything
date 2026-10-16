extends SceneTree
## Hero names (milestone 14 step 9; HR2's naming contract, in play since 2026-10-14): data/heroes.json
## (hero_names, hero_signatures) run on real races through src/heroes.gd. For each prompt: the race key
## and every hero the race gets (D-136: its creature's and culture's, topped up from its culture's kin),
## each with its name, temper and aura. Deterministic: src/rng.gd seeded from the race key. Run:
##   godot --headless --path . --script res://tests/hero_names.gd -- "sewer rats" "romans" ...

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const Heroes := preload("res://src/heroes.gd")
const CreatureKit := preload("res://scenes/art_pixel/creature_kit.gd")


func _init() -> void:
	var lib = DataLib.new()
	CreatureKit.stage(lib, "res://data/later/bears.json")
	var gen = Generator.new(lib)
	var rules = DataLib.load_rules("default")
	for p in OS.get_cmdline_user_args():
		var race: Dictionary = gen.generate(p, rules)
		var sigs := Heroes.roster_for(lib.heroes, race.creature, race.family)
		print("\n== \"%s\"  %s/%s  key %s" % [p, race.creature, race.family, race.key.substr(0, 12)])
		for sid in sigs:
			var s: Dictionary = lib.heroes.hero_signatures[sid]
			print("   %-12s %s  %s  (%s)" % [sid, Heroes.pick(lib.heroes, race.key, race.creature, race.family, sid).name, s.temper, s.aura.text])
	quit()
