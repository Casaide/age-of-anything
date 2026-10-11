extends SceneTree
## Every unit of a race in its 8 baked facings, one row per unit, at a zoom (the tool for
## checking facings). Run (needs a display):
##   godot --path . --script res://tests/facing_sheet.gd -- out.png "prompt" [zoom]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const UnitView := preload("res://src/unit_view.gd")

const W := 1600
const H := 900


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var race: Dictionary = gen.generate(args[1], DataLib.load_json("res://data/rules/default.json"))
	var zoom := float(args[2]) if args.size() > 2 else 3.0
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	var team := Color(lib.palettes.teams[0])
	await kit.prepare_units([race], [team])
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = Vector2(W, H)
	root.add_child(bg)
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(world)
	var units: Array = race.units
	for row in units.size():
		for k in 8:
			var v := UnitView.new()
			v.facing_k = k
			v.build(units[row].recipe, lib, team, units[row].eval.speed)
			v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
			v.pose_steps = 8
			v.position = Vector2((k + 0.6) * W / 8.0, (row + 0.8) * H / units.size()) / zoom
			world.add_child(v)
	for f in 20:
		await process_frame
	root.get_texture().get_image().save_png(args[0])
	print("saved ", args[0])
	quit()
