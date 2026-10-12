extends SceneTree
## A building concept sheet: model functions from src/view/art/bake/models.gd (real ones and
## concept_* options), baked with the game's building baker and set side by side on the grass at
## game scale with their names, so options can be compared before one is built.
## Run (needs a display):
##   godot --path . --script res://tests/building_sheet.gd -- out.png <zoom> model [model ...]
## e.g. ... -- /tmp/b.png 2 stone_town_center junk_town_center concept_junk_tc_low
## A gate's open look: palisade_gate:stone:open
## Props too: prop.<function>.<seed>[.<stage>], e.g. prop.quarry.1300.0 prop.boulders.1000
## Trees: tree.<seed>.<species>.<style>[.<stage>], e.g. tree.3.pine.0 (scenes/art_pixel/tree_models.gd)

const ArtKit := preload("res://src/view/art/art_kit.gd")
const PartShape := preload("res://src/part_shape.gd")
const PropModels := preload("res://scenes/art_pixel/prop_models.gd")
const TreeModels := preload("res://scenes/art_pixel/tree_models.gd")
const BridgeModels := preload("res://scenes/art_pixel/bridge_models.gd")

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
		var spec: Dictionary
		if n.begins_with("tree.") or n.begins_with("bridge."):   # tree.<seed>.<species>.<style>[.<stage>], bridge.<seed>.<length>.<style>[.<broken>]
			var bits: PackedStringArray = String(n).split(".")
			var targs: Array = Array(bits.slice(1)).map(func(x): return int(x) if x.is_valid_int() else x)
			var lib = TreeModels.new() if bits[0] == "tree" else BridgeModels.new()
			spec = {"body": lib.callv(bits[0], targs)}
		elif n.begins_with("prop."):   # a prop: prop.<function>.<seed>[.<stage>]
			var bits: PackedStringArray = String(n).split(".")
			var pargs: Array = Array(bits.slice(2)).map(func(x): return int(x) if x.is_valid_int() else x)
			spec = {"body": PropModels.new().callv(bits[1], pargs)}
		elif n.contains(":"):   # type:arch, e.g. market:stone; type:arch:open for a gate's open look
			spec = models.building(n.get_slice(":", 0), n.get_slice(":", 1), team)
			if n.get_slice_count(":") > 2 and n.get_slice(":", 2) == "open":
				spec.body = spec.open
		else:
			spec = models.call(n, team)
		if n.contains("house"):
			spec.body.scale = Vector3.ONE * ArtKit.HOUSE_SCALE
		baker.set_ground_shadow(true)
		baker.shadow_reach = 2.0 if n.begins_with("tree.") else 1.0
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
