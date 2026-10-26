extends SceneTree
## Fidelity study (docs/concepts/fidelity/): whole figures modelled for realism in Blender
## (tools/blender/concept_soldier.py), baked by the game's unit baker (its camera, light, value bands,
## outline and pixelizer, whatever the run's AOW_* flags set) and drawn beside today's legionary at the
## same scale, in four facings. Not game units: a concept figure is one piece, with no sockets, gear
## swaps or walk.
## Run (needs a display):
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/art_quality/fidelity_sheet.gd -- out.png zoom label=file.glb [label=file.glb ...]
## A row may instead be today's unit: "today:<prompt>|<slot>|<age>" (the legionary is the first row unless one is given).

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const PartShape := preload("res://src/part_shape.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const StudyModels := preload("res://tests/art_quality/study_models.gd")

const FACINGS := [1, 2, 0, 6]
const NAMES := ["f1", "f2 towards", "f0 right", "f6 away"]
const CELL := Vector2(70, 64)   # canvas units a cell, at the game's scale
const BG := Color("#56782e")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var zoom := float(args[1])
	var rows: Array = Array(args.slice(2))
	if not rows.any(func(a): return a.begins_with("today:")):
		rows.push_front("today:romans|infantry|2")
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var team := Color(lib.palettes.teams[0])
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	# Today's units: each "today:<prompt>|<slot>|<age>" row, its line's step at that age.
	var units := {}
	var races := []
	for a in rows:
		if a.begins_with("today:"):
			var spec: PackedStringArray = a.trim_prefix("today:").split("|")
			var race: Dictionary = gen.generate(spec[0], rules)
			races.append(race)
			for u in race.units:
				if u.recipe.slot == spec[1]:
					for step in u.line:
						if int(step.age) <= int(spec[2]):
							units[a] = step
			assert(units.has(a), "no %s" % a)
	await kit.prepare_units(races, races.map(func(_r): return team))
	# The concept figures, baked like a unit part (one piece; no sockets).
	var baker := PartBaker.new()
	baker.models = StudyModels.new()
	baker.art_scale = ArtKit.ART_SCALE * ArtKit.UNIT_SCALE
	baker.bands = ArtKit.UNIT_BANDS
	baker.outlined = OS.get_environment("AOW_UNIT_OUTLINE") != "0"
	root.add_child(baker)
	var first: Dictionary = units.values()[0]
	var colours := UnitView.colours_for(lib, first.recipe.skin, first.recipe.family, team)
	var keys := {}
	for k in rows.size():
		if rows[k].begins_with("today:"):
			continue
		var id := "concept.figure%d" % k
		baker.models.files[id] = rows[k].get_slice("=", 1)
		await baker.bake(id, [], colours)
		keys[k] = PartShape.bake_key(id, [], PartShape.team_neutral(colours))
	var label_w := 190.0
	var head := 40.0
	var vp := SubViewport.new()
	vp.size = Vector2i(int(label_w + CELL.x * zoom * FACINGS.size()) + 8, int(head + CELL.y * zoom * rows.size()) + 4)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var flags := []
	for e in ["AOW_ART_SCALE", "AOW_UNIT_BANDS", "AOW_UNIT_OUTLINE", "AOW_UNIT_RIM"]:
		if OS.has_environment(e):
			flags.append("%s=%s" % [e.trim_prefix("AOW_").to_lower(), OS.get_environment(e)])
	vp.add_child(_label("Fidelity: today's units and figures modelled for realism, same baker  |  %s  |  zoom %s" % [", ".join(flags) if not flags.is_empty() else "today's bake settings", zoom], Vector2(8, 6), 15))
	for c in FACINGS.size():
		vp.add_child(_label(NAMES[c], Vector2(label_w + c * CELL.x * zoom + 6, head - 18), 13))
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom
	world.position = Vector2(label_w, head)
	vp.add_child(world)
	for r in rows.size():
		var today: bool = rows[r].begins_with("today:")
		var name: String = ("today: " + rows[r].trim_prefix("today:").replace("|", " ")) if today else rows[r].get_slice("=", 0)
		vp.add_child(_label(name, Vector2(8, head + (r + 0.35) * CELL.y * zoom), 14))
		for c in FACINGS.size():
			var at := Vector2((c + 0.5) * CELL.x, (r + 0.85) * CELL.y)
			if today:
				var u: Dictionary = units[rows[r]]
				var v := UnitView.new()
				v.build(u.recipe, lib, team, u.eval.speed)
				v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
				v.pose_steps = 0
				v.idle_wait = 1000.0
				v.position = at
				world.add_child(v)
				v.face_vec(Vector2.from_angle(_screen_angle(FACINGS[c])))
				v._process(0.0)
				v.set_process(false)
				continue
			var e: Dictionary = PartShape.baked[keys[r] + PartShape.facing_suffix(FACINGS[c])]
			var unit := Node2D.new()
			unit.position = at
			unit.scale = Vector2.ONE * ArtKit.UNIT_SCALE
			world.add_child(unit)
			var shadow := Node2D.new()
			shadow.draw.connect(func(): shadow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.45)); shadow.draw_circle(Vector2.ZERO, 7.5, Color(0.06, 0.05, 0.03, 0.42)))
			unit.add_child(shadow)
			var s := Sprite2D.new()
			s.texture = e.tex
			s.centered = false
			s.offset = -e.origin
			s.scale = Vector2.ONE / float(e.scale)
			s.material = PartShape.team_material
			s.self_modulate = Color(team.r, team.g, team.b, 1.0)
			unit.add_child(s)
	for f in 20:
		await process_frame
	vp.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()


## The screen direction a facing walks (UnitView picks the facing from it).
static func _screen_angle(k: int) -> float:
	return deg_to_rad([0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0][k] - 10.0)


func _label(t: String, at: Vector2, fs: int) -> Label:
	var l := Label.new()
	l.text = t
	l.position = at
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l
