extends SceneTree
## Prints races for a few prompts. Handy for eyeballing generator output.
## Run: godot --headless --path . --script res://tests/print_races.gd -- "your prompt" "another"

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")


func _init() -> void:
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var prompts := OS.get_cmdline_user_args()
	if prompts.is_empty():
		prompts = ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans", "flying greeks with wings"]
	for p in prompts:
		var race: Dictionary = gen.generate(p, rules)
		print("\n== %s  (\"%s\")  %s/%s  key %s" % [race.name, p, race.creature, race.family, race.key.substr(0, 12)])
		for n in race.notes:
			print("   note: ", n)
		for u in race.units:
			var e: Dictionary = u.eval
			print("   %-38s %3dF %3dW  hp %3d atk %2d arm %d/%d rng %d spd %2d  %s" % [u.recipe.name, e.cost.food, e.cost.wood, e.hp, e.attack, e.armour.melee, e.armour.pierce, e["range"], e.speed, u.recipe.parts.values()])
	quit()
