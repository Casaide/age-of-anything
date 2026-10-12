extends SceneTree
## Living towns concepts (milestone 17, D-080: options first), rendered through the real rig,
## bakes and baker for Dominic to look at and pick from. Two sheets:
##   loads   the reed bundle over the shoulder in all 8 facings, meat, stone, gold, bugs, per race
##   chores  per race: sweep (two frames), sit, chat (two frames), till the rows (two frames),
##           meat and gold carried home; and a sheep grazing (head down, head up)
##   props   the drop-off piles in both styles (A and B) at their fullest, the picked style
##           through its three stages, a house's yard and garden as they grow, the tether post
## Run (needs a display): godot --path . --script res://tests/town_concept_sheet.gd -- out_dir

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const PartShape := preload("res://src/part_shape.gd")
const TownProps := preload("res://scenes/art_pixel/town_props.gd")

const BG := Color("#56782e")

var lib
var kit
var out_dir: String


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://concepts"
	DirAccess.make_dir_recursive_absolute(out_dir)
	lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var prompts := ["tiny vikings", "angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans", "spooky beetle knights"]
	var races := prompts.map(func(p): return gen.generate(p, rules))
	var team := Color(lib.palettes.teams[0])
	kit = ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	var pb := PartBaker.new()
	pb.art_scale = ArtKit.ART_SCALE * ArtKit.UNIT_SCALE
	pb.bands = ArtKit.UNIT_BANDS
	root.add_child(pb)
	var units := []
	for r in races:
		units.append(r.units[0])
	units.append({"recipe": ArtKit.animal_race().units.filter(func(u): return u.recipe.slot == "sheep")[0].recipe, "eval": {"speed": 7}})
	for w in units:
		var probe := UnitView.new()
		probe.build(w.recipe, lib, team, w.eval.speed)
		for ps in probe.find_children("*", "Node2D", true, false):
			if ps is PartShape and ps.part_id != "":
				await pb.bake(ps.part_id, ps.shapes, ps.colours)
		probe.free()
		if w.recipe.slot != "worker":
			continue
		var colours := UnitView.colours_for(lib, w.recipe.skin, w.recipe.family, team)
		for id in ArtKit.JOB_PARTS:
			await pb.bake(id, lib.part(id).shapes, colours)
		if not w.recipe.has("mount") or w.recipe.mount.get("fused", false):
			for h in UnitView.WORK_HOLDS:
				await pb.bake(w.recipe.body + "@" + h, lib.part(w.recipe.body).shapes, colours)
	pb.queue_free()
	PartShape.bake_flat("unit_shadow", UnitView.SHADOW_SHAPES, UnitView.SHADOW_COLOURS, ArtKit.ART_SCALE * ArtKit.UNIT_SCALE)
	await kit.bake_props()   # the town props come with them
	kit.rebuild_atlas()
	await _loads(units)
	await _chores(units)
	await _props()
	quit()


func _clear() -> Node2D:
	for n in root.get_children():
		if n != kit:
			n.queue_free()
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(1600, 900)
	root.add_child(bg)
	var world := Node2D.new()
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(world)
	return world


func _label(text: String, at: Vector2, size := 15) -> void:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", size)
	root.add_child(l)


func _save(name: String) -> void:
	for f in 12:
		await process_frame
	var path := out_dir.path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


## Per race a row: sweep x2, sit, chat x2, till x2, meat home, gold home; the sheep below.
func _chores(units: Array) -> void:
	var world := _clear()
	var zoom := 3.0
	world.scale = Vector2.ONE * zoom
	var cols := [["sweep", 0.0, "tool.broom"], ["sweep", 0.6, "tool.broom"], ["sit", 1.0, ""], ["chat", 0.5, ""], ["chat", 1.9, ""],
		["till", 0.2, "tool.hoe"], ["till", 0.95, "tool.hoe"], ["walk", 0.0, "load.meat"], ["walk", 0.0, "load.gold"]]
	var heads := ["sweep", "", "sit", "chat", "", "till the rows", "", "meat home", "gold home"]
	for k in cols.size():
		_label(heads[k], Vector2(150 + k * 150, 12), 16)
	for row in units.size():
		var u: Dictionary = units[row]
		var y := 150.0 + row * 135.0
		_label(u.recipe.name, Vector2(10, y - 40), 13)
		var list: Array = cols if u.recipe.slot == "worker" else [["graze", 0.5, ""], ["graze", 3.5, ""], ["", 0.0, ""]]
		for k in list.size():
			var v := UnitView.new()
			v.build(u.recipe, lib, Color(lib.palettes.teams[0]), u.eval.speed)
			v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
			v.position = Vector2(180 + k * 150, y) / zoom
			v.idle_wait = 1000.0
			world.add_child(v)
			if list[k][2] != "":
				v.set_tool(lib, list[k][2])
			if list[k][0] == "walk":
				v.walking = true
				v.phase = 1.0
			else:
				v.job = list[k][0]
			v.time = float(list[k][1]) - float(v.noise.seed % 5) * 0.21 * {"sweep": 1.2, "sit": 5.0, "chat": 2.6, "graze": 4.0, "till": 1.3}.get(list[k][0], 1.0)
			v._process(0.0)
			v.set_process(false)
	await _save("town_chores")


## Loads carried home, walking: the reed bundle over the shoulder in all 8 facings, then the
## meat, stone, gold and the food basket, per race, close up.
func _loads(units: Array) -> void:
	var world := _clear()
	var zoom := 3.0
	world.scale = Vector2.ONE * zoom
	var heads := ["reeds: the 8 facings", "", "", "", "", "", "", "", "meat", "stone", "gold", "bugs"]
	for k in heads.size():
		_label(heads[k], Vector2(100 + k * 120, 12), 15)
	var row := 0
	for u in units:
		if u.recipe.slot != "worker" or (u.recipe.has("mount") and not u.recipe.mount.get("fused", false)):
			continue
		var y := 150.0 + row * 140.0
		_label(u.recipe.name, Vector2(10, y - 45), 13)
		for k in 12:
			var v := UnitView.new()
			v.build(u.recipe, lib, Color(lib.palettes.teams[0]), u.eval.speed)
			v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
			v.position = Vector2(120 + k * 120, y) / zoom
			v.idle_wait = 1000.0
			world.add_child(v)
			if k < 8:
				var a := TAU * k / 8.0
				v.face_vec(Vector2(cos(a), sin(a) * 0.5))
			v.set_tool(lib, ["load.reeds", "load.meat", "load.stone", "load.gold", "tool.basket"][maxi(0, k - 7)])
			v.walking = true
			v.phase = 1.0
			v._process(0.0)
			v.set_process(false)
		row += 1
	await _save("town_loads")


## The piles in both styles, the picked style's stages, the yard and garden, the tether post.
func _props() -> void:
	var world := _clear()
	var zoom := 3.0
	world.scale = Vector2.ONE * zoom
	var h: Array = await kit._hifi()
	var baker = h[0]
	var tp := TownProps.new()
	tp.models = h[1]
	var rows := [
		["Drop-off piles, style A (full)", TownProps.PILE_KINDS.map(func(k): return ["%s A" % k, tp.pile(k, 3, "a"), true])],
		["Drop-off piles, style B (full)", TownProps.PILE_KINDS.map(func(k): return ["%s B" % k, tp.pile(k, 3, "b"), true])],
		["As built (food A, wood A, stone B, gold A): stages 1, 2, 3", []],
		["A house's yard (1-3) and garden (1-3) as it ages; the stable's tether post", []],
	]
	for st in [1, 2, 3]:
		for k in ["food", "wood", "stone", "gold"]:
			rows[2][1].append(["%s %d" % [k, st], tp.pile(k, st, ArtKit.PILE_STYLE[k]), true])
	for st in [1, 2, 3]:
		rows[3][1].append(["yard %d" % st, tp.yard(st), true])
	for st in [1, 2, 3]:
		rows[3][1].append(["garden %d" % st, tp.garden(st), false])
	rows[3][1].append(["tether post", tp.tether_post(), true])
	var team_mat := ShaderMaterial.new()
	team_mat.shader = load("res://src/team_mask.gdshader")
	for r in rows.size():
		var y := 60.0 + r * 215.0
		_label(rows[r][0], Vector2(12, y - 50), 16)
		var items: Array = rows[r][1]
		for k in items.size():
			baker.set_ground_shadow(items[k][2])
			var b: Dictionary = await baker.bake(items[k][1], [Vector3.ZERO])
			var s := Sprite2D.new()
			s.texture = b.tex
			s.centered = false
			s.offset = -b.points[0]
			s.scale = Vector2.ONE / ArtKit.ART_SCALE
			s.material = team_mat
			s.self_modulate = Color("#3a78d8")
			var x := 70.0 + k * (1500.0 / maxf(items.size(), 4))
			s.position = Vector2(x, y + 110) / zoom
			world.add_child(s)
			_label(items[k][0], Vector2(x - 40, y + 135), 12)
	baker.queue_free()
	await _save("town_props")
