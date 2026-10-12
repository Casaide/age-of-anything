extends SceneTree
## The siege engines in play (milestone 13), as the game draws them: per race, its ram, catapult and
## bolt thrower in four facings, crewed by its own workers, with a worker beside for size. One row
## per engine. Zoom 1.5 is the game's scale. Run (needs a display):
##   godot --audio-driver Dummy --always-on-top --path . --script res://tests/siege_lineup.gd -- out.png [zoom] ["prompt" ...]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const UnitView := preload("res://src/unit_view.gd")

const PROMPTS := ["romans", "sewer rats", "forest beetles", "spooky spiders", "swamp frogs"]
const FACINGS := [0, 2, 5, 6]
const CELL := Vector2(78, 62)   # world units per cell (at zoom 1)
const LABEL_W := 150.0


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var zoom := float(args[1]) if args.size() > 1 else 3.0
	var prompts: Array = args.slice(2) if args.size() > 2 else PROMPTS
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races := prompts.map(func(p): return gen.generate(p, rules))
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	var team := Color(lib.palettes.teams[0])
	await kit.prepare_units(races, races.map(func(_r): return team))
	var rows := []   # [race, unit]
	for race in races:
		for u in race.units:
			if u.recipe.has("crew"):
				rows.append([race, u])
	var vp := SubViewport.new()
	vp.size = Vector2i(int(LABEL_W + CELL.x * zoom * (FACINGS.size() + 0.6)), int(CELL.y * zoom * rows.size()))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom
	world.position = Vector2(LABEL_W, 0)
	vp.add_child(world)
	for r in rows.size():
		var race: Dictionary = rows[r][0]
		var u: Dictionary = rows[r][1]
		var y := (r + 0.78) * CELL.y
		var label := Label.new()
		label.text = "%s\n%s (%s)\n%s" % [race.prompt, u.recipe.name, u.recipe.body.trim_prefix("siege."), _cost(u.eval.cost)]
		label.position = Vector2(8, (r + 0.25) * CELL.y * zoom)
		label.add_theme_font_size_override("font_size", 12 if zoom > 2 else 9)
		label.add_theme_color_override("font_color", Color("#f4f1e8"))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		label.add_theme_constant_override("outline_size", 3)
		vp.add_child(label)
		var worker: Dictionary = race.units[0]
		_view(world, worker, Vector2(CELL.x * 0.3, y), 0, lib, team)
		for f in FACINGS.size():
			_view(world, u, Vector2((f + 1.1) * CELL.x, y), FACINGS[f], lib, team)
	for f in 20:
		await process_frame
	vp.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()


func _view(world: Node2D, u: Dictionary, at: Vector2, k: int, lib, team: Color) -> void:
	var v := UnitView.new()
	v.facing_k = k
	v.build(u.recipe, lib, team, u.eval.speed)
	v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
	v.pose_steps = 8
	v.idle_wait = 1000.0
	v.position = at
	world.add_child(v)


func _cost(c: Dictionary) -> String:
	var parts := []
	for k in c:
		if int(c[k]) > 0:
			parts.append("%d %s" % [c[k], k])
	return ", ".join(parts)
