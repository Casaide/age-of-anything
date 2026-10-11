extends SceneTree
## A contact sheet of unit animation: for each unit, frames of its walk cycle and of
## each work job (forage, chop, build), left to right, at 3x. The tool for reviewing
## animation without watching a match.
## Run (needs a display): godot --path . --script res://tests/art_anim.gd -- out.png ["prompt A" "prompt B"]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")

const ZOOM := 3.0
const FRAMES := 5
const ROWS := [["walk", ""], ["work", "forage"], ["work", "chop"], ["work", "build"]]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://anim.png"
	var prompts: Array = [args[1], args[2]] if args.size() > 2 else ["angry swamp frogs with reed spears", "spooky beetle knights"]
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races := [gen.generate(prompts[0], rules), gen.generate(prompts[1], rules)]
	var teams := [Color(lib.palettes.teams[0]), Color(lib.palettes.teams[1])]
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	await kit.prepare_units(races, teams)
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = Vector2(1600, 900)
	root.add_child(bg)
	var world := Node2D.new()
	world.scale = Vector2.ONE * ZOOM
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(world)
	# Per race (a column each): its worker walking and at every job, then a soldier
	# and its large unit walking.
	for side in 2:
		var units: Array = races[side].units
		var rows := []
		for r in ROWS:
			rows.append([units[0], r])
		rows.append([units[1], ROWS[0]])
		rows.append([units[units.size() - 1], ROWS[0]])
		for k in rows.size():
			var u: Dictionary = rows[k][0]
			var row: Array = rows[k][1]
			for f in FRAMES:
				var v := UnitView.new()
				v.build(u.recipe, lib, teams[side], u.eval.speed)
				v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
				v.pose_steps = 8
				v.position = Vector2(24 + side * 268 + f * 48, 36 + k * 46)
				v.walking = row[0] == "walk"
				v.job = row[1]
				v.time = f * 0.16
				v.phase = f * TAU / FRAMES
				v.idle_wait = 1000.0
				world.add_child(v)
				v._process(0.0)
				v.set_process(false)
	for f in 10:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
