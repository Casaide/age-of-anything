extends SceneTree
## Bakes the full roster of two races as pixel-art units and shows them large
## (4x nearest) on a plain ground: the tool for reviewing unit art.
## Run (needs a display):
##   godot --path . --script res://tests/unit_lineup.gd -- out.png ["prompt A" "prompt B"]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")

const ART := 1.5 * 0.85   # art pixels per part unit, as in the pixel-art scene
const ZOOM := 4


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://lineup.png"
	var prompts: Array = [args[1], args[2]] if args.size() > 2 else ["angry swamp frogs with reed spears", "sewer rats with cheese hammers"]
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var baker := PartBaker.new()
	baker.art_scale = ART
	root.add_child(baker)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.stretch_shrink = ZOOM
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.size = Vector2(1600, 900)
	root.add_child(box)
	var vp := SubViewport.new()
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	box.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = Vector2(1600, 900) / ZOOM
	vp.add_child(bg)
	await process_frame
	for side in 2:
		var race: Dictionary = gen.generate(prompts[side], rules)
		var team := Color(lib.palettes.teams[side])
		for k in race.units.size():
			var u: Dictionary = race.units[k]
			var probe := UnitView.new()
			probe.build(u.recipe, lib, team, u.eval.speed)
			for ps in probe.find_children("*", "Node2D", true, false):
				if ps is PartShape and ps.part_id != "":
					await baker.bake(ps.part_id, ps.shapes, ps.colours)
			probe.free()
			var v := UnitView.new()
			v.style = "baked"
			v.build(u.recipe, lib, team, u.eval.speed)
			v.scale = Vector2(ART, ART)
			v.position = Vector2(40 + k * 75, 95 + side * 105)
			vp.add_child(v)
	for f in 20:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
