extends SceneTree
## A building concept sheet: model functions from src/view/art/bake/models.gd (real ones and
## concept_* options), baked with the game's building baker and set side by side on the grass at
## game scale with their names, so options can be compared before one is built.
## Run (needs a display):
##   godot --path . --script res://tests/building_sheet.gd -- out.png <zoom> model [model ...]
## e.g. ... -- /tmp/b.png 2 stone_town_center junk_town_center concept_junk_tc_low

const ArtKit := preload("res://src/view/art/art_kit.gd")
const PartShape := preload("res://src/part_shape.gd")

const W := 1600
const H := 900


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var zoom := float(args[1])
	var names: Array = args.slice(2)
	var kit := ArtKit.new()
	root.add_child(kit)
	await process_frame
	var h: Array = await kit._hifi()
	var baker = h[0]
	var models = h[1]
	var team := Color(PartShape.TEAM_KEY)
	var shots := []
	for n in names:
		var spec: Dictionary = models.call(n, team)
		if n.contains("house"):
			spec.body.scale = Vector3.ONE * ArtKit.HOUSE_SCALE
		baker.set_ground_shadow(true)
		var b: Dictionary = await baker.bake(spec.body, [Vector3.ZERO])
		shots.append(b)
	var team_mat := ShaderMaterial.new()
	team_mat.shader = load("res://src/team_mask.gdshader")
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = Vector2(W, H)
	root.add_child(bg)
	root.add_child(world)
	for k in shots.size():
		var s := Sprite2D.new()
		s.texture = shots[k].tex
		s.centered = false
		s.offset = -shots[k].points[0]
		s.scale = Vector2.ONE / ArtKit.ART_SCALE
		s.self_modulate = Color("#3a78d8")
		s.material = team_mat
		s.position = Vector2((k + 0.5) * W / shots.size(), H * 0.62) / zoom
		world.add_child(s)
		var l := Label.new()
		l.text = String(names[k]).replace("concept_", "")
		l.add_theme_font_size_override("font_size", 18)
		l.position = Vector2((k + 0.5) * W / shots.size() - 150, H * 0.84)
		l.size = Vector2(300, 30)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(l)
	for f in 10:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
