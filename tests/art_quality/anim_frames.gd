extends SceneTree
## Animation study (docs/concepts/animation/): frame sequences modelled in Blender (concept_creatures.py anim:
## rat_b_walk_<k>, rat_b_thrust_<k>), each baked by the game's unit baker in the given facings, laid out as strips
## (one row per sequence and facing) and written frame by frame (out_dir/<seq>_f<facing>_<k>.png, for animated GIFs).
## Run (needs a display):
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/art_quality/anim_frames.gd -- out_dir zoom facings dir seq[:n] [seq[:n] ...]
## e.g. ... -- /tmp/anim 4 1,0 /tmp/frames rat_b_walk:8 rat_b_thrust:6

const ArtKit := preload("res://src/view/art/art_kit.gd")
const PartShape := preload("res://src/part_shape.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const UnitView := preload("res://src/unit_view.gd")
const DataLib := preload("res://src/data_lib.gd")
const StudyModels := preload("res://tests/art_quality/study_models.gd")

const CELL := Vector2(58, 52)   # canvas units a frame, at the game's scale
const BG := Color("#56782e")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var zoom := float(args[1])
	var facings: Array = Array(args[2].split(",")).map(func(x): return int(x))
	var dir: String = args[3]
	var seqs: Array = Array(args.slice(4)).map(func(a): return [a.get_slice(":", 0), int(a.get_slice(":", 1))])
	DirAccess.make_dir_recursive_absolute(out)
	var lib = DataLib.new()
	var team := Color(lib.palettes.teams[0])
	var baker := PartBaker.new()
	baker.models = StudyModels.new()
	baker.art_scale = ArtKit.ART_SCALE * ArtKit.UNIT_SCALE
	baker.bands = ArtKit.UNIT_BANDS
	baker.outlined = true
	root.add_child(baker)
	await process_frame
	var colours := UnitView.colours_for(lib, "human_light", "imperial", team)
	var keys := {}
	var longest := 0
	for s in seqs:
		longest = maxi(longest, s[1])
		for k in s[1]:
			var id := "concept.%s_%d" % [s[0], k]
			baker.models.files[id] = dir.path_join("%s_%d.glb" % [s[0], k])
			await baker.bake(id, [], colours)
			keys[id] = PartShape.bake_key(id, [], PartShape.team_neutral(colours))
	# The strips: a row per sequence and facing.
	var rows := []
	for s in seqs:
		for f in facings:
			rows.append([s, f])
	var vp := _viewport(Vector2i(int(170 + CELL.x * zoom * longest), int(30 + CELL.y * zoom * rows.size())))
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom
	world.position = Vector2(170, 30)
	vp.add_child(world)
	for r in rows.size():
		var s: Array = rows[r][0]
		vp.add_child(_label("%s, f%d" % [s[0], rows[r][1]], Vector2(8, 30 + (r + 0.4) * CELL.y * zoom)))
		for k in s[1]:
			world.add_child(_figure(keys["concept.%s_%d" % [s[0], k]], rows[r][1], Vector2((k + 0.5) * CELL.x, (r + 0.85) * CELL.y), team))
	for i in 12:
		await process_frame
	vp.get_texture().get_image().save_png(out.path_join("strips.png"))
	vp.queue_free()
	# Each frame alone, for the GIFs.
	for s in seqs:
		for f in facings:
			for k in s[1]:
				var one := _viewport(Vector2i(int(CELL.x * zoom), int(CELL.y * zoom)))
				var w := Node2D.new()
				w.scale = Vector2.ONE * zoom
				one.add_child(w)
				w.add_child(_figure(keys["concept.%s_%d" % [s[0], k]], f, Vector2(0.5 * CELL.x, 0.85 * CELL.y), team))
				for i in 4:
					await process_frame
				one.get_texture().get_image().save_png(out.path_join("%s_f%d_%d.png" % [s[0], f, k]))
				one.queue_free()
	print("saved ", out)
	quit()


func _viewport(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(size)
	vp.add_child(bg)
	return vp


func _figure(key: String, facing: int, at: Vector2, team: Color) -> Node2D:
	var e: Dictionary = PartShape.baked[key + PartShape.facing_suffix(facing)]
	var unit := Node2D.new()
	unit.position = at
	unit.scale = Vector2.ONE * ArtKit.UNIT_SCALE
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
	return unit


func _label(t: String, at: Vector2) -> Label:
	var l := Label.new()
	l.text = t
	l.position = at
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l
