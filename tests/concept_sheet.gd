extends SceneTree
## A concept sheet: candidate designs (scenes/art_pixel/concepts.gd) worn by the same unit,
## in a row with their names, so variations can be compared and picked before one is built.
## Run it twice: close up to judge the design, at game scale to judge what survives.
## Run (needs a display):
##   godot --path . --script res://tests/concept_sheet.gd -- out.png <art px per unit> <zoom> "prompt" id id ...
## e.g. ... -- /tmp/c.png 4.0 2 "romans" concept.current_cap concept.roman_bare ...

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const Concepts := preload("res://scenes/art_pixel/concepts.gd")

const W := 1600
const H := 900


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var art := float(args[1])
	var zoom := int(args[2])
	var prompt: String = args[3]
	var ids: Array = args.slice(4)
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var race: Dictionary = gen.generate(prompt, DataLib.load_json("res://data/rules/default.json"))
	var base: Dictionary = race.units[1]   # the spear unit at its first age
	for u in race.units:
		if u.recipe.slot == "spear":
			base = u
	for id in ids:   # concepts borrow a real head-gear part's entry; only the model differs
		var p: Dictionary = lib.part("helm.cap").duplicate(true)
		p.id = id
		lib.parts[id] = p
	var baker := PartBaker.new()
	baker.art_scale = art
	baker.models = Concepts.new()
	root.add_child(baker)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.stretch_shrink = zoom
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.size = Vector2(W, H)
	root.add_child(box)
	var vp := SubViewport.new()
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	box.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = Vector2(W, H) / zoom
	vp.add_child(bg)
	await process_frame
	var team := Color(lib.palettes.teams[0])
	var recipes := []
	for id in ids:
		var r: Dictionary = base.recipe.duplicate(true)
		r.parts.head_gear = id
		recipes.append(r)
		var probe := UnitView.new()
		probe.build(r, lib, team, base.eval.speed)
		for ps in probe.find_children("*", "Node2D", true, false):
			if ps is PartShape and ps.part_id != "":
				await baker.bake(ps.part_id, ps.shapes, ps.colours)
		probe.free()
	PartShape.bake_flat("unit_shadow", UnitView.SHADOW_SHAPES, UnitView.SHADOW_COLOURS, art)
	PartShape.build_atlas()
	var cols := ids.size()
	for k in cols:
		var v := UnitView.new()
		v.build(recipes[k], lib, team, base.eval.speed)
		v.scale = Vector2(art, art)
		v.position = Vector2((k + 0.5) * W / cols, H * 0.6) / zoom
		vp.add_child(v)
		var name := Label.new()
		name.text = String(ids[k]).trim_prefix("concept.")
		name.add_theme_font_size_override("font_size", 18)
		name.position = Vector2((k + 0.5) * W / cols - 80, H * 0.82)
		name.size = Vector2(160, 30)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(name)
	for f in 20:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
