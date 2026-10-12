extends SceneTree
## Every variant of every building type that has them (data: buildings.json "variants"), for
## every architecture: one row per architecture and type, one column per variant, baked as the
## game bakes them (ArtKit._placed: turn, mirror, nudge in size). For checking that each look
## still shows its door. Run (needs a display):
##   godot --path . --script res://tests/building_variants.gd -- out.png [zoom]

const ArtKit := preload("res://src/view/art/art_kit.gd")
const DataLib := preload("res://src/data_lib.gd")
const PartShape := preload("res://src/part_shape.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var zoom := float(args[1]) if args.size() > 1 else 2.0
	var kit := ArtKit.new()
	root.add_child(kit)
	await process_frame
	var h: Array = [await kit._hifi_baker(), kit._models]
	var d: Dictionary = DataLib.load_json("res://data/buildings.json")
	var archs: Array = ArtKit.HOUSE.keys()
	archs.sort()
	var rows := []   # [label, [bakes]]
	var cols := 1
	var types: Array = d.get("variants", {}).keys()
	types.sort()
	for type in types:
		var n := int(d.variants[type])
		cols = maxi(cols, n)
		for arch in archs:
			var shots := []
			for v in n:
				var spec: Dictionary = kit._placed(h[1], arch, type, "", "#%d" % v if v > 0 else "")
				h[0].set_ground_shadow(true)
				shots.append(await h[0].bake(spec.body, [Vector3.ZERO]))
			rows.append(["%s:%s" % [arch, type], shots])
	var cell := Vector2(150, 120) * zoom
	var size := Vector2i(int(cell.x * cols + 140), int(cell.y * rows.size() + 20))
	root.size = size
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = Vector2(size)
	root.add_child(bg)
	var team_mat := ShaderMaterial.new()
	team_mat.shader = load("res://src/team_mask.gdshader")
	var world := Node2D.new()
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(world)
	for r in rows.size():
		var l := Label.new()
		l.text = rows[r][0]
		l.position = Vector2(8, cell.y * (r + 0.5))
		root.add_child(l)
		for c in rows[r][1].size():
			var b: Dictionary = rows[r][1][c]
			var s := Sprite2D.new()
			s.texture = b.tex
			s.centered = false
			s.offset = -b.points[0]
			s.scale = Vector2.ONE * zoom / ArtKit.ART_SCALE
			s.self_modulate = Color("#3a78d8")
			s.material = team_mat
			s.position = Vector2(140 + cell.x * (c + 0.5), cell.y * (r + 0.8))
			world.add_child(s)
			var vl := Label.new()
			vl.text = "#%d" % c
			vl.position = Vector2(140 + cell.x * c + 4, cell.y * r + 4)
			root.add_child(vl)
	for f in 10:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
