extends SceneTree
## Concept RM1 (2026-10-13): the rats' mount. CP1's capybara (full), the capybara pushed two ways, an
## alley cat and a tiger, each ridden by the rats' crossbow rider in 8 facings with the
## cheese-hammer rider beside, and a human on a pony for size. The concept mounts are composed by
## UnitView like any mount (body, head, legs baked apart in 8 facings: the real pipeline); their
## parts live in scenes/art_pixel/rat_mount_concepts.gd and are put into the loaded data here only
## (data/ is untouched). Zoom 1.5 is the game's scale. Run (needs a display):
##   godot --path . --script res://tests/rat_mount_sheet.gd -- out_dir [zoom] [sheet,...] [mount,...]
## sheets: facings (8 facings + the hammer rider), walk (a walk cycle in two facings).
## mounts: today, capy_long, capy_long_tan, cat, tiger (default: all).
## Writes <out_dir>/rat_mount_<sheet>_<zoom>x.png

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const Concepts := preload("res://scenes/art_pixel/rat_mount_concepts.gd")
const UnitModels := preload("res://scenes/art_pixel/unit_models.gd")
const BakeCache := preload("res://src/view/art/bake_cache.gd")

const PROMPTS := ["romans", "sewer rats riding capybaras"]
const MOUNTS := ["today", "capy_long", "capy_long_tan", "cat", "tiger"]
const LABELS := {"today": "capybara\n(CP1 full, before)", "capy_long": "A  capybara, long head\n(in play; redder here)",
	"capy_long_tan": "B  capybara,\nlonger, tan face", "cat": "C  alley cat", "tiger": "D  tiger"}
const CELL := Vector2(66, 70)   # world units per cell
const SIZE_COL := 0.8

var lib
var team: Color


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	var zoom := float(args[1]) if args.size() > 1 else 4.5
	var sheets: Array = Array(args[2].split(",")) if args.size() > 2 else ["facings", "walk"]
	var mounts: Array = Array(args[3].split(",")) if args.size() > 3 else MOUNTS
	DirAccess.make_dir_recursive_absolute(out_dir)
	lib = DataLib.new()
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
	UnitModels.capybara_look = "full"   # the before row (the cache is off: same ids, another look)
	BakeCache.enabled = false
	await kit.prepare_units([{"units": steps}], [team])
	var bow := _find(steps, "weapon.crossbow")
	var hammer := _find(steps, "weapon.cheese_hammer")
	# Rows: [label, rider, other rider, size unit]
	var rows := [["human on a pony", _slot(races[0], "large"), null, _slot(races[0], "worker")]]
	var pb := PartBaker.new()
	pb.models = Concepts.new()
	pb.art_scale = ArtKit.ART_SCALE * ArtKit.UNIT_SCALE
	pb.bands = ArtKit.UNIT_BANDS
	root.add_child(pb)
	var worker := _slot(races[1], "worker")
	for m in mounts:
		if m == "today":
			rows.append([LABELS[m], bow, hammer, worker])
			continue
		var pair := [_mounted(bow, m), _mounted(hammer, m)]
		for u in pair:
			var probe := UnitView.new()
			probe.build(u.recipe, lib, team, u.eval.speed)
			for ps in probe.find_children("*", "Node2D", true, false):
				if ps is PartShape and ".rm_" in ps.part_id:
					await pb.bake(ps.part_id, ps.shapes, ps.colours)
			probe.free()
		rows.append([LABELS[m], pair[0], pair[1], worker])
	kit.rebuild_atlas()
	var tag := str(zoom / ArtKit.ART_SCALE).trim_suffix(".0")
	for sheet in sheets:
		await _sheet(sheet, rows, zoom, out_dir.path_join("rat_mount_%s_%sx.png" % [sheet, tag]))
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


## A rider moved onto a concept mount: the capybara's data entries borrowed under the concept's
## ids (only the models differ), a creature for it, the recipe's mount swapped.
func _mounted(rider: Dictionary, m: String) -> Dictionary:
	var id := "rm_" + m
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


func _unit(world: Node2D, unit: Dictionary, at: Vector2, k: int, walking: bool, phase: float) -> void:
	var v := UnitView.new()
	v.facing_k = k
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
	var walk := sheet == "walk"
	# Columns: [facing, walking, phase, other rider]
	var cols := []
	if walk:
		for k in [0, 2]:
			for f in 4:
				cols.append([k, true, f * PI * 0.5, true])
	else:
		for k in 8:
			cols.append([k, false, 0.0, false])
		for k in [1, 7]:
			cols.append([k, false, 0.0, true])
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
	var title := "the rats' mount: the cheese-hammer rider walking in two facings (four steps each)" if walk \
		else "the rats' mount: the crossbow rider in the eight facings; the cheese-hammer rider on the right"
	vp.add_child(_label(title, Vector2(label_w + CELL.x * SIZE_COL * zoom + 8, 6), fs))
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom
	world.position = Vector2(label_w, head_h)
	vp.add_child(world)
	for r in rows.size():
		vp.add_child(_label(rows[r][0], Vector2(8, head_h + (r + 0.35) * CELL.y * zoom), fs))
		var base_y := (r + 0.82) * CELL.y
		_unit(world, rows[r][3], Vector2(CELL.x * SIZE_COL * 0.5, base_y), 0, false, 0.0)
		for c in cols.size():
			var u: Variant = rows[r][2] if cols[c][3] and rows[r][2] != null else rows[r][1]
			_unit(world, u, Vector2((c + SIZE_COL + 0.5) * CELL.x, base_y), cols[c][0], cols[c][1], cols[c][2])
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
