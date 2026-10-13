extends SceneTree
## Concept C2 (2026-10-13): the alley cat again, as a cat and not a horse (Dominic on RM1's C:
## "tail is good, just legs and body a bit unclear ... Needs to be more naturally a cat, including
## sitting when idle"). Rows: a human on a pony for size, RM1's cat (C, before), then the new cat in
## its coats, each ridden by the rats' crossbow rider (the cheese-hammer rider in the last columns).
## The new cat is the real pipeline: its data is data/later/cat_mount.json, put into the loaded data
## here only (data/ is untouched), composed by UnitView, every part and pose baked in 8 facings.
## Zoom 1.5 is the game's scale. Run (needs a display):
##   godot --path . --script res://tests/cat_mount_sheet.gd -- out_dir [zoom] [sheet,...] [coat,...]
## sheets: facings (standing, 8 facings), walk (the hammer rider walking, 3 facings x 4 steps),
##   sit (the idle sit, 8 facings), sit1 (the step on the way down), cycle (every step of the walk, side on).
## coats: cat_ginger, cat_tuxedo, cat_grey (default: ginger and tuxedo).
## Writes <out_dir>/cat_mount_<sheet>_<zoom>x.png

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const Concepts := preload("res://scenes/art_pixel/rat_mount_concepts.gd")
const BakeCache := preload("res://src/view/art/bake_cache.gd")

const PROMPTS := ["romans", "sewer rats riding capybaras"]
const COATS := {"cat_ginger": "C2  alley cat,\nginger tabby", "cat_tuxedo": "C2  alley cat,\nblack and white",
	"cat_grey": "C2  alley cat,\ngrey tabby"}
const CELL := Vector2(66, 64)   # world units per cell
const SIZE_COL := 0.8

var lib
var team: Color


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	var zoom := float(args[1]) if args.size() > 1 else 4.5
	var sheets: Array = Array(args[2].split(",")) if args.size() > 2 else ["facings", "walk", "sit"]
	var coats: Array = Array(args[3].split(",")) if args.size() > 3 else ["cat_ginger", "cat_tuxedo"]
	DirAccess.make_dir_recursive_absolute(out_dir)
	lib = DataLib.new()
	var later: Dictionary = DataLib.load_json("res://data/later/cat_mount.json")
	for p in later.parts:
		lib.parts[p.id] = p
	lib.creatures.merge(later.creatures)
	lib.palettes.skins.merge(later.skins)
	team = Color(lib.palettes.teams[0])
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races := []
	for p in PROMPTS:
		races.append(gen.generate(p, rules))
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	var steps := []
	for r in races:
		for u in r.units:
			steps += u.get("line", [u])
	BakeCache.enabled = false
	await kit.prepare_units([{"units": steps}], [team])
	var bow := _find(steps, "weapon.crossbow")
	var hammer := _find(steps, "weapon.cheese_hammer")
	var pb := PartBaker.new()
	pb.models = Concepts.new()
	pb.art_scale = ArtKit.ART_SCALE * ArtKit.UNIT_SCALE
	pb.bands = ArtKit.UNIT_BANDS
	root.add_child(pb)
	var worker := _slot(races[1], "worker")
	# Rows: [label, rider, other rider, size unit]
	var rows := [["human on a pony", _slot(races[0], "large"), null, _slot(races[0], "worker")]]
	var mounted := [["C  alley cat\n(RM1, before)", _borrowed(bow, "rm_cat"), _borrowed(hammer, "rm_cat")]]
	for coat in coats:
		mounted.append([COATS[coat], _cat(bow, coat), _cat(hammer, coat)])
	for m in mounted:
		for u in [m[1], m[2]]:
			var probe := UnitView.new()
			probe.build(u.recipe, lib, team, u.eval.speed)
			for ps in probe.find_children("*", "Node2D", true, false):
				if ps is PartShape and (".rm_" in ps.part_id or ".cat" in ps.part_id):
					await pb.bake(ps.part_id, ps.shapes, ps.colours)
			probe.free()
			var colours := UnitView.colours_for(lib, u.recipe.mount.skin, u.recipe.family, team)
			colours.team = team
			for pp in UnitView.pose_parts(lib, u.recipe):
				await pb.bake(pp[0], pp[1], colours)
		rows.append([m[0], m[1], m[2], worker])
	kit.rebuild_atlas()
	var tag := str(zoom / ArtKit.ART_SCALE).trim_suffix(".0")
	for sheet in sheets:
		await _sheet(sheet, rows, zoom, out_dir.path_join("cat_mount_%s_%sx.png" % [sheet, tag]))
	quit()


func _slot(race: Dictionary, slot: String) -> Dictionary:
	for u in race.units:
		if u.recipe.slot == slot:
			return u
	assert(false, "no %s unit" % slot)
	return {}


func _find(steps: Array, weapon: String) -> Dictionary:
	for u in steps:
		if u.recipe.has("mount") and weapon in JSON.stringify(u.recipe):
			return u
	assert(false, "no mounted %s" % weapon)
	return {}


## The rider on the cat from data/later (the real pipeline: only the recipe's mount changes).
func _cat(rider: Dictionary, coat: String) -> Dictionary:
	var u := rider.duplicate(true)
	u.recipe.mount.creature = "cat"
	u.recipe.mount.skin = coat
	return u


## The rider on an RM1 concept mount (the capybara's data borrowed under its ids, as
## tests/rat_mount_sheet.gd does).
func _borrowed(rider: Dictionary, id: String) -> Dictionary:
	if not lib.creatures.has(id):
		var body: Dictionary = lib.part("body.capybara").duplicate(true)
		body.id = "body." + id
		body.legs.part = "leg." + id
		lib.parts[body.id] = body
		for slot in [["head", "head.capybara"], ["leg", "leg.capybara"]]:
			var p: Dictionary = lib.part(slot[1]).duplicate(true)
			p.id = "%s.%s" % [slot[0], id]
			lib.parts[p.id] = p
		var mc: Dictionary = lib.creatures["capybara"].duplicate(true)
		mc.body = body.id
		mc.mount_body = body.id
		mc.head = "head." + id
		lib.creatures[id] = mc
	var u := rider.duplicate(true)
	u.recipe.mount.creature = id
	return u


func _unit(world: Node2D, unit: Dictionary, at: Vector2, k: int, walking: bool, phase: float, pose: String) -> void:
	var v := UnitView.new()
	v.facing_k = k
	if unit.recipe.has("mount") and unit.recipe.mount.creature == "cat":
		v.body_pose = pose
	v.build(unit.recipe, lib, team, unit.eval.speed)
	v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
	v.position = at
	v.idle_wait = 1000.0
	world.add_child(v)
	v.walking = walking
	v.phase = phase
	v._process(0.0)
	v.set_process(false)


func _sheet(sheet: String, rows: Array, zoom: float, path: String) -> void:
	var walk := sheet == "walk" or sheet == "cycle"
	# Columns: [facing, walking, phase, other rider, pose]
	var cols := []
	if sheet == "walk":
		for k in [0, 2, 5]:
			for f in 4:
				cols.append([k, true, f * PI * 0.5, true, ""])
	elif sheet == "cycle":
		for f in 8:
			cols.append([7, true, f * PI * 0.25, true, ""])
	else:
		var pose := sheet if sheet in ["sit", "sit1"] else ""
		for k in 8:
			cols.append([k, false, 0.0, false, pose])
		for k in [1, 7]:
			cols.append([k, false, 0.0, true, pose])
	var label_w := 220.0 if zoom > 2 else 130.0
	var head_h := 30.0
	var vp := SubViewport.new()
	vp.size = Vector2i(int(label_w + CELL.x * zoom * (cols.size() + SIZE_COL)), int(head_h + CELL.y * zoom * rows.size()))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var band := ColorRect.new()
	band.color = Color(0, 0, 0, 0.07)
	band.position = Vector2(label_w, 0)
	band.size = Vector2(CELL.x * SIZE_COL * zoom, vp.size.y)
	vp.add_child(band)
	if not walk:
		var band2 := ColorRect.new()
		band2.color = Color(0, 0, 0, 0.07)
		band2.position = Vector2(label_w + CELL.x * (SIZE_COL + 8) * zoom, 0)
		band2.size = Vector2(CELL.x * 2 * zoom, vp.size.y)
		vp.add_child(band2)
	var fs := 14 if zoom > 2 else 10
	vp.add_child(_label("for size", Vector2(label_w + 8, 6), fs))
	var title: String = {"walk": "walking: the cheese-hammer rider in three facings, four steps each (a cat's four-beat walk)",
		"cycle": "walking: the eight baked steps of the walk, one facing",
		"sit": "idle: the cat sits (the pony and RM1's cat stand); the crossbow rider in 8 facings, the cheese-hammer rider on the right",
		"sit1": "sitting down (the step between standing and sitting, a fifth of a second); the crossbow rider in 8 facings",
		"facings": "standing: the crossbow rider in the eight facings; the cheese-hammer rider on the right"}[sheet]
	vp.add_child(_label(title, Vector2(label_w + CELL.x * SIZE_COL * zoom + 8, 6), fs))
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom
	world.position = Vector2(label_w, head_h)
	vp.add_child(world)
	for r in rows.size():
		vp.add_child(_label(rows[r][0], Vector2(8, head_h + (r + 0.35) * CELL.y * zoom), fs))
		var base_y := (r + 0.8) * CELL.y
		_unit(world, rows[r][3], Vector2(CELL.x * SIZE_COL * 0.5, base_y), 0, false, 0.0, "")
		for c in cols.size():
			var u: Variant = rows[r][2] if cols[c][3] and rows[r][2] != null else rows[r][1]
			_unit(world, u, Vector2((c + SIZE_COL + 0.5) * CELL.x, base_y), cols[c][0], cols[c][1], cols[c][2], cols[c][4])
	for f in 20:
		await process_frame
	vp.get_texture().get_image().save_png(path)
	print("saved ", path)
	vp.queue_free()


func _label(text: String, at: Vector2, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#f4f1e8"))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 3)
	return l
