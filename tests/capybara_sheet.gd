extends SceneTree
## The capybara looks (CP1, 2026-10-13: "very cubey face", Dominic): the rats' capybara cavalry,
## a rat riding, in its 8 baked facings standing and a walk strip (two facings through the
## stride), for one look of the capybara (unit_models.gd CAPYBARA_LOOKS). Run once per look and
## stack the strips into a sheet. Run (needs a display):
##   godot --path . --script res://tests/capybara_sheet.gd -- out.png <zoom> <look> ["prompt"]
## zoom 1.5 is the game's scale (ArtKit.ART_SCALE); 4.5 is a 3x close-up.

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const UnitModels := preload("res://scenes/art_pixel/unit_models.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")

const CELL := Vector2(64, 62)   # world units per unit shown


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var zoom := float(args[1])
	UnitModels.capybara_look = args[2]
	var prompt: String = args[3] if args.size() > 3 else "sewer rats riding capybaras"
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var race: Dictionary = gen.generate(prompt, DataLib.load_json("res://data/rules/default.json"))
	var steps := []   # every age of every line: the capybara rides from age 2
	for x in race.units:
		steps += x.get("line", [x])
	var u: Dictionary = steps.filter(func(x): return x.recipe.has("mount") and x.recipe.mount.creature == "capybara")[0]
	var team := Color(lib.palettes.teams[0])
	var baker := PartBaker.new()
	baker.art_scale = ArtKit.ART_SCALE * ArtKit.UNIT_SCALE
	baker.bands = ArtKit.UNIT_BANDS
	root.add_child(baker)
	var probe := UnitView.new()
	probe.build(u.recipe, lib, team, u.eval.speed)
	for ps in probe.find_children("*", "Node2D", true, false):
		if ps is PartShape and ps.part_id != "":
			await baker.bake(ps.part_id, ps.shapes, ps.colours)
	probe.free()
	PartShape.bake_flat("unit_shadow", UnitView.SHADOW_SHAPES, UnitView.SHADOW_COLOURS, ArtKit.ART_SCALE * ArtKit.UNIT_SCALE)
	PartShape.build_atlas()
	# Row 1: the 8 facings standing. Row 2: facings 0 and 2 (and 6) through a stride.
	var cols := 8
	var size := Vector2i(int(CELL.x * cols * zoom) + 40, int(CELL.y * 2 * zoom) + 30)
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = Vector2(size)
	vp.add_child(bg)
	var label := Label.new()
	label.text = "%s  (%s)" % [args[2], u.recipe.name]
	label.position = Vector2(6, 2)
	vp.add_child(label)
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom
	world.position = Vector2(20, 24)
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vp.add_child(world)
	var cells := []
	for k in 8:
		cells.append([k, 0, -1.0])
	for k in [0, 2, 6]:
		for p in [0.0, 1.6]:   # one stride apart
			cells.append([k, 1, p])
	cells.append([4, 1, 0.8])
	cells.append([1, 1, 0.8])
	var col_in_row := [0, 0]
	for c in cells:
		var v := UnitView.new()
		v.facing_k = c[0]
		v.build(u.recipe, lib, team, u.eval.speed)
		v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
		v.pose_steps = 8
		v.art_px = ArtKit.ART_SCALE * zoom
		if c[2] >= 0.0:
			v.walking = true
			v.phase = c[2]
			v.speed_px = 0.0
		var row: int = c[1]
		v.position = Vector2((col_in_row[row] + 0.5) * CELL.x, (row + 0.82) * CELL.y)
		col_in_row[row] += 1
		world.add_child(v)
	for f in 20:
		await process_frame
	vp.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
