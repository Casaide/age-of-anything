extends SceneTree
## Every culture's healer (families.json) in its 8 baked facings, one row per culture: the
## tool for checking that each culture's staff and bag read at game scale. Run (needs a display):
##   godot --path . --script res://tests/healer_lineup.gd -- out.png [zoom] [family,family...]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const UnitView := preload("res://src/unit_view.gd")

const W := 1400
const H := 1500
## One prompt per culture, in families.json order.
const PROMPTS := {"swamp": "swamp frogs", "sewer": "sewer rats", "forest": "forest beetles", "imperial": "romans",
	"hellenic": "greeks", "royal": "royal humans", "steppe": "mongols", "spooky": "spooky spiders",
	"nile": "egyptians", "han": "han", "aztec": "aztecs"}


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var zoom := float(args[1]) if args.size() > 1 else 3.0
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races := []
	var only: Array = Array(args[2].split(",")) if args.size() > 2 else lib.families.keys()
	for fam in lib.families:
		if not fam in only:
			continue
		var race: Dictionary = gen.generate(PROMPTS[fam], rules)
		var h: Dictionary = race.units.filter(func(u): return u.recipe.role == "healer")[0]
		print("%-9s %-16s %-22s %s" % [fam, PROMPTS[fam], h.recipe.name, h.recipe.parts])
		races.append({"race": race, "healer": h, "family": fam})
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	var team := Color(lib.palettes.teams[0])
	await kit.prepare_units(races.map(func(e): return e.race), races.map(func(_e): return team))
	var vp := SubViewport.new()   # taller than the screen: the window can't hold eleven rows
	vp.size = Vector2i(W, int(H * zoom / 3.0 * races.size() / 11.0) + 100)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vp.add_child(world)
	for row in races.size():
		var l := Label.new()
		l.text = races[row].family
		l.position = Vector2(8, (row + 0.35) * (vp.size.y - 40) / races.size() + 40)
		vp.add_child(l)
		for k in 8:
			var v := UnitView.new()
			v.facing_k = k
			var u: Dictionary = races[row].healer
			v.build(u.recipe, lib, team, u.eval.speed)
			v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
			v.pose_steps = 8
			v.position = Vector2((k + 1.0) * W / 8.6, (row + 0.8) * (vp.size.y - 40) / races.size() + 40) / zoom
			world.add_child(v)
	for f in 20:
		await process_frame
	vp.get_texture().get_image().save_png(args[0])
	print("saved ", args[0])
	quit()
