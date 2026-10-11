extends SceneTree
## Bakes the art kit for two races, as a match start does, and prints how long each
## part took. The bake runs every match start, so its time is a budget we watch.
## Run (needs a display): godot --path . --script res://tests/art_bake_time.gd -- ["prompt A" "prompt B"]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prompts: Array = [args[0], args[1]] if args.size() > 1 else ["angry swamp frogs with reed spears", "sewer rats with cheese hammers"]
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races := [gen.generate(prompts[0], rules), gen.generate(prompts[1], rules)]
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	var t0 := Time.get_ticks_msec()
	await kit.prepare(races, [Color(lib.palettes.teams[0]), Color(lib.palettes.teams[1])])
	print("total %d ms, %d bakes, atlas %s" % [Time.get_ticks_msec() - t0, kit.bakes.size(), kit.regions.size()])
	quit()
