extends SceneTree
## A sheet of every baked prop variant on the game's grass, close up: resource props
## (reeds, bug bushes) in rows by variant with their used-up stages across, then the
## doodads. The tool for reviewing prop art and variety.
## Run (needs a display): godot --path . --script res://tests/art_props.gd -- out.png [zoom]

const DataLib := preload("res://src/data_lib.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const TerrainView := preload("res://src/view/art/terrain_view.gd")
const Iso := preload("res://src/view/iso.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://props.png"
	var zoom: float = float(args[1]) if args.size() > 1 else 2.0
	var lib = DataLib.new()
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	var t0 := Time.get_ticks_msec()
	await kit.bake_props()
	kit.rebuild_atlas()
	print("props baked in %d ms" % (Time.get_ticks_msec() - t0))
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(world)
	var n := 40
	var map := {"id": "props", "width": n, "height": n, "terrain_ids": ["grass"], "terrain": PackedByteArray(), "walk": PackedByteArray()}
	map.terrain.resize(n * n)
	map.walk.resize(n * n)
	var ground := TerrainView.new()
	ground.build(map)
	ground.set_art_px(zoom / ArtKit.ART_SCALE)
	ground.position = Vector2(800, 450) / zoom - Iso.to_screen(n * 500, n * 500)
	world.add_child(ground)
	var layer := Node2D.new()
	layer.y_sort_enabled = true
	world.add_child(layer)
	var step := Vector2(62, 52)
	var y := 40.0
	for kind in ["reeds", "bush"]:
		for v in ArtKit.DOODADS[kind]:
			for st in ArtKit.STAGES:
				var col := st + (0 if kind == "reeds" else ArtKit.STAGES + 1)
				_put(kit.doodad(kind, v, st), Vector2(36 + col * step.x, y + v * step.y * 0.7), layer)
	y += ArtKit.DOODADS.reeds * step.y * 0.7 + 30
	var x := 0
	for kind in ["rock", "stones", "tuft", "flowers", "shore", "lily"]:
		for v in ArtKit.DOODADS[kind]:
			_put(kit.doodad(kind, v), Vector2(36 + v * 52, y + x * 34), layer)
		x += 1
	for f in 10:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()


func _put(s: Sprite2D, at: Vector2, layer: Node2D) -> void:
	var h := Node2D.new()
	h.position = at
	h.add_child(s)
	layer.add_child(h)
