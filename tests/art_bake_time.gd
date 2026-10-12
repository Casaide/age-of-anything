extends SceneTree
## Bakes the art kit for two races, as a match start does, and prints how long each
## part took. The bake runs every match start, so its time is a budget we watch.
## cold: empties the bake cache first (every bake renders); warm: uses what's on disk;
## off: no disk cache at all (renders everything, writes nothing).
## Run (needs a display): godot --path . --script res://tests/art_bake_time.gd -- [cold|warm|off] ["prompt A" "prompt B"]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const BakeCache := preload("res://src/view/art/bake_cache.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "warm"
	var prompts: Array = [args[1], args[2]] if args.size() > 2 else ["angry swamp frogs with reed spears", "sewer rats with cheese hammers"]
	if mode == "cold":
		for f in DirAccess.get_files_at(BakeCache.folder()):
			if f.ends_with(".bin"):
				DirAccess.remove_absolute(BakeCache.folder() + "/" + f)
	BakeCache.enabled = mode != "off"
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
	print("%s: total %d ms, %d bakes, %d buildings, %d unit sprites" % [mode, Time.get_ticks_msec() - t0, kit.bakes.size(), kit.buildings.size(), kit.PartShape.baked.size()])
	quit()
