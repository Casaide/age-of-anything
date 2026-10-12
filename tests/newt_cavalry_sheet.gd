extends SceneTree
## Concept SW1 round 4 (2026-10-13, D-121): the giant newt as the frogs' cavalry mount, in three
## colourings, ridden by the frogs' lancer, beside today's frog on a beetle and a human on a pony.
## The newt is composed by UnitView like any mount (body, head, legs baked apart in 8 facings: the
## real pipeline); its parts live in scenes/art_pixel/newt_concepts.gd and are put into the loaded
## data here only (data/ is untouched). Zoom 1.5 is the game's scale. Run (needs a display):
##   godot --path . --script res://tests/newt_cavalry_sheet.gd -- out_dir [zoom] [sheet,...]
## sheets: facings (each mount in all 8 facings, a worker for size), walk (a walk cycle in two
## facings). Writes <out_dir>/newt_cavalry_<sheet>_<zoom>x.png

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const Newts := preload("res://scenes/art_pixel/newt_concepts.gd")

const PROMPTS := ["romans", "swamp frogs riding beetles"]
const KINDS := ["fire", "eft", "crested"]
const LABELS := {"fire": "frog on a newt:\nfire (black, yellow)", "eft": "frog on a newt:\nred eft", "crested": "frog on a newt:\ncrested (olive)"}
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
	for p in PROMPTS:
		races.append(gen.generate(p, rules))
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	await kit.prepare_units(races, races.map(func(_r): return team))
	# Rows: [label, unit dict, worker unit]
	var human_cav := _slot(races[0], "large")
	var frog_cav := _slot(races[1], "large")
	var rows := [["human on a pony", human_cav, _slot(races[0], "worker")],
		["frog on a beetle\n(today)", frog_cav, _slot(races[1], "worker")]]
	var pb := PartBaker.new()
	pb.models = Newts.new()
	pb.art_scale = ArtKit.ART_SCALE * ArtKit.UNIT_SCALE
	pb.bands = ArtKit.UNIT_BANDS
	root.add_child(pb)
	for kind in KINDS:
		var u := _newt_unit(frog_cav, kind)
		var probe := UnitView.new()
		probe.build(u.recipe, lib, team, u.eval.speed)
		for ps in probe.find_children("*", "Node2D", true, false):
			if ps is PartShape and ".newt_" in ps.part_id:
				await pb.bake(ps.part_id, ps.shapes, ps.colours)
		probe.free()
		rows.append([LABELS[kind], u, rows[1][2]])
	kit.rebuild_atlas()
	var tag := str(zoom / ArtKit.ART_SCALE).trim_suffix(".0")
	for sheet in sheets:
		await _sheet(sheet, rows, zoom, out_dir.path_join("newt_cavalry_%s_%sx.png" % [sheet, tag]))
	quit()


func _slot(race: Dictionary, slot: String) -> Dictionary:
	for u in race.units:
		if u.recipe.slot == slot:
			return u
	assert(false, "no %s unit" % slot)
	return {}


## The frog lancer on a newt: the beetle's data entries borrowed under the newt's ids (only the
## models differ), a creature for it, the rider's recipe with the mount swapped.
func _newt_unit(cav: Dictionary, kind: String) -> Dictionary:
	var body: Dictionary = lib.part("body.beetle").duplicate(true)
	body.id = "body.newt_" + kind
	body.legs.part = "leg.newt_" + kind
	lib.parts[body.id] = body
	for slot in [["head", "head.beetle"], ["leg", "leg.insect"]]:
		var p: Dictionary = lib.part(slot[1]).duplicate(true)
		p.id = "%s.newt_%s" % [slot[0], kind]
		lib.parts[p.id] = p
	var mc: Dictionary = lib.creatures["beetle"].duplicate(true)
	mc.body = body.id
	mc.mount_body = body.id
	mc.head = "head.newt_" + kind
	lib.creatures["newt_" + kind] = mc
	var u := cav.duplicate(true)
	u.recipe.mount.creature = "newt_" + kind
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
	var title := "frog cavalry on a giant newt: a walk in two facings (four steps each)" if walk \
		else "frog cavalry on a giant newt: the eight facings, beside the beetle and the pony"
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
