extends SceneTree
## One unit line of every culture (families.json) in its 8 baked facings, one row per culture, at
## one age's step: the tool for checking that a line's weapons and holds read at game scale
## (tests/healer_lineup.gd is the healer's). Run (needs a display):
##   godot --path . --script res://tests/line_lineup.gd -- out.png [slot] [age] [zoom] [family,family...]
## e.g. -- /tmp/swords2.png infantry 2 3   (a race that lacks the line gets no row)

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const UnitView := preload("res://src/unit_view.gd")

const W := 1400
const H := 1500
## One prompt per culture, in families.json order (the healer lineup's).
const PROMPTS := {"swamp": "swamp frogs", "sewer": "sewer rats", "forest": "forest beetles", "imperial": "romans",
	"hellenic": "greeks", "royal": "royal humans", "steppe": "mongols", "spooky": "spooky spiders",
	"nile": "egyptians", "han": "han", "aztec": "aztecs"}


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var slot: String = args[1] if args.size() > 1 else "infantry"
	var age := int(args[2]) if args.size() > 2 else 1
	var zoom := float(args[3]) if args.size() > 3 else 3.0
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races := []
	var only: Array = Array(args[4].split(",")) if args.size() > 4 else lib.families.keys()
	for fam in lib.families:
		if not fam in only:
			continue
		var race: Dictionary = gen.generate(PROMPTS[fam], rules)
		var found: Array = race.units.filter(func(x): return x.recipe.slot == slot)
		if found.is_empty():   # the race lacks the line (Aztecs have no mounted archers)
			print("%-9s %-16s (no %s line)" % [fam, PROMPTS[fam], slot])
			continue
		var u: Dictionary = found[0]
		var step: Dictionary = u.line[0]
		for l in u.line:
			if int(l.age) <= age:
				step = l
		print("%-9s %-16s %-34s %s" % [fam, PROMPTS[fam], step.recipe.name, step.recipe.parts])
		races.append({"race": race, "step": step, "family": fam})
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
		l.text = "%s: %s" % [races[row].family, races[row].step.recipe.name]
		l.position = Vector2(8, (row + 0.1) * (vp.size.y - 40) / races.size() + 40)
		vp.add_child(l)
		for k in 8:
			var v := UnitView.new()
			v.facing_k = k
			var step: Dictionary = races[row].step
			v.build(step.recipe, lib, team, step.eval.speed)
			v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
			v.pose_steps = 8
			v.position = Vector2((k + 1.0) * W / 8.6, (row + 0.8) * (vp.size.y - 40) / races.size() + 40) / zoom
			world.add_child(v)
	for f in 20:
		await process_frame
	vp.get_texture().get_image().save_png(args[0])
	print("saved ", args[0])
	quit()
