extends SceneTree
## Every architecture's Town Center and house, with their construction stages left
## to right (foundations, scaffold, walls, roof, done), on the game's grass. The tool
## for reviewing building art.
## Run (needs a display): godot --path . --script res://tests/art_buildings.gd -- out.png [zoom]

const DataLib := preload("res://src/data_lib.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const TerrainView := preload("res://src/view/art/terrain_view.gd")
const Iso := preload("res://src/view/iso.gd")

# One race per architecture: thatch, junk, stone, tent, reed (frogs), mound (bugs).
const RACES := [{"creature": "human", "family": "forest"}, {"creature": "rat", "family": "sewer"},
	{"creature": "human", "family": "imperial"}, {"creature": "human", "family": "steppe"},
	{"creature": "frog", "family": "swamp"}, {"creature": "beetle", "family": "forest"}]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://buildings.png"
	var zoom: float = float(args[1]) if args.size() > 1 else 1.0
	var lib = DataLib.new()
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	var t0 := Time.get_ticks_msec()
	await kit.bake_buildings(RACES)
	kit.rebuild_atlas()
	print("buildings baked in %d ms" % (Time.get_ticks_msec() - t0))
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(world)
	var n := 60
	var map := {"id": "buildings", "width": n, "height": n, "terrain_ids": ["grass"], "terrain": PackedByteArray(), "walk": PackedByteArray()}
	map.terrain.resize(n * n)
	map.walk.resize(n * n)
	var ground := TerrainView.new()
	ground.build(map)
	ground.set_art_px(zoom / ArtKit.ART_SCALE)
	ground.position = Vector2(800, 450) / zoom - Iso.to_screen(n * 500, n * 500)
	world.add_child(ground)
	var team := Color(lib.palettes.teams[0])
	var row := 0
	for r in RACES:
		var arch: String = lib.architecture(r)
		for type in ["town_center", "house"]:
			var info: Dictionary = kit.buildings["%s:%s" % [arch, type]]
			var names: Array = info.stages + [info.body]
			for k in names.size():
				var s: Sprite2D = kit.sprite(names[k])
				s.self_modulate = Color(team.r, team.g, team.b, 1.0)
				s.position = Vector2(80 + k * 150 + (0 if type == "town_center" else 800), 80 + row * 135) / zoom
				world.add_child(s)
		row += 1
	for f in 10:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
