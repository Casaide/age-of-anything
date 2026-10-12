extends SceneTree
## The giant newt, the frogs' cavalry mount (D-122; concept SW1 round 4, now real parts in
## unit_models.gd: body.newt, head.newt, leg.newt). The frogs' large unit on a newt in each of its
## three skins (fire, red eft, crested), a human and a rat riding newts, and a human on a pony
## for size, as the game composes and bakes them. Zoom 1.5 is the game's scale. Run (needs a display):
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/newt_cavalry_sheet.gd -- out_dir [zoom] [sheet,...]
## sheets: facings (each rider in all 8 facings, a worker for size), walk (a walk cycle in two
## facings). Writes <out_dir>/newt_cavalry_<sheet>_<zoom>x.png

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")

## [label, prompt, newt skin to wear ("" keeps the race's own)]
const ROWS := [["human on a pony", "romans", ""],
	["frog on a newt:\nfire", "swamp frogs", "newt_fire"],
	["frog on a newt:\nred eft", "swamp frogs", "newt_eft"],
	["frog on a newt:\ncrested", "swamp frogs", "newt_crested"],
	["human on a newt", "swamp folk", "newt_fire"],
	["rat on a newt", "rats on newts", "newt_eft"]]
const CELL := Vector2(92, 64)   # world units per cell
const SIZE_COL := 0.75

var lib
var team: Color


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	var zoom := float(args[1]) if args.size() > 1 else 4.5
	var sheets: Array = Array(args[2].split(",")) if args.size() > 2 else ["facings", "walk"]
	DirAccess.make_dir_recursive_absolute(out_dir)
	lib = DataLib.new()
	team = Color(lib.palettes.teams[0])
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races := []
	var rows := []   # [label, large unit, worker]
	for spec in ROWS:
		var race: Dictionary = _riding(gen, spec[1], rules, spec[2] != "")
		var cav := _slot(race, "large")
		if spec[2] != "":
			cav.recipe.mount.skin = spec[2]
		races.append(race)
		rows.append([spec[0], cav, _slot(race, "worker")])
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	await kit.prepare_units(races, races.map(func(_r): return team))
	var tag := str(zoom / ArtKit.ART_SCALE).trim_suffix(".0")
	for sheet in sheets:
		await _sheet(sheet, rows, zoom, out_dir.path_join("newt_cavalry_%s_%sx.png" % [sheet, tag]))
	quit()


## The first reroll of the prompt whose large unit rides (a newt, when asked).
func _riding(gen, prompt: String, rules: Dictionary, newt: bool) -> Dictionary:
	for reroll in 40:
		var race: Dictionary = gen.generate(prompt, rules, reroll)
		var cav := _slot(race, "large")
		if cav.recipe.has("mount") and not cav.recipe.mount.fused and (cav.recipe.mount.creature == "newt") == newt:
			return race
	assert(false, "no mounted large unit for '%s'" % prompt)
	return {}


func _slot(race: Dictionary, slot: String) -> Dictionary:
	for u in race.units:
		if u.recipe.slot == slot:
			return u
	assert(false, "no %s unit" % slot)
	return {}


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
	# Columns: [facing, walking, phase]
	var cols := []
	if walk:
		for k in [0, 2]:
			for f in 4:
				cols.append([k, true, f * PI * 0.5])
	else:
		for k in 8:
			cols.append([k, false, 0.0])
	var label_w := 200.0 if zoom > 2 else 120.0
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
	var fs := 14 if zoom > 2 else 10
	vp.add_child(_label("for size", Vector2(label_w + 8, 6), fs))
	var title := "cavalry on a giant newt: a walk in two facings (four steps each)" if walk \
		else "cavalry on a giant newt: the eight facings, beside a pony"
	vp.add_child(_label(title, Vector2(label_w + CELL.x * SIZE_COL * zoom + 8, 6), fs))
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom
	world.position = Vector2(label_w, head_h)
	vp.add_child(world)
	for r in rows.size():
		vp.add_child(_label(rows[r][0], Vector2(8, head_h + (r + 0.35) * CELL.y * zoom), fs))
		var base_y := (r + 0.8) * CELL.y
		_unit(world, rows[r][2], Vector2(CELL.x * SIZE_COL * 0.5, base_y), 0, false, 0.0)
		for c in cols.size():
			_unit(world, rows[r][1], Vector2((c + SIZE_COL + 0.5) * CELL.x, base_y), cols[c][0], cols[c][1], cols[c][2])
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
