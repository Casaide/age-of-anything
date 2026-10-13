extends SceneTree
## Concept S3 (2026-10-13, Dominic: "Swords looking great, need age 3"): the swordsman's age-3
## kit for every culture without one (swamp, forest, hellenic, steppe, spooky, han). Each culture's
## age-2 swordsman as the game makes it, then two options for its age-3 step (a weapon, and for
## some a helmet) in the 8 baked facings plus a wind-up and a blow. The concept parts are modelled
## in scenes/art_pixel/sword3_concepts.gd and baked through the real part pipeline (PartBaker,
## 8 facings, the swordsman's hold); they are put into the loaded data here only (data/ is
## untouched). Zoom 1.5 is the game's scale, 4.5 is 3x. Run (needs a display):
##   godot --path . --script res://tests/sword3_concept_sheet.gd -- out_dir [zoom] [family,...]
## Writes <out_dir>/sword3_<family>_<n>x.png per family, or with several families at zoom 1.5 one
## sheet of them all: <out_dir>/sword3_all_1x.png

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const Concepts := preload("res://scenes/art_pixel/sword3_concepts.gd")

const PROMPTS := {"swamp": "swamp frogs", "forest": "forest beetles", "hellenic": "greeks", "steppe": "mongols",
	"spooky": "spooky spiders", "han": "han"}
const FAMILIES := ["hellenic", "steppe", "han", "swamp", "forest", "spooky"]
## Per family: [label, {slot: concept part}] for options A and B.
const OPTIONS := {
	"hellenic": [["A  iron kopis", {"hand_r": "weapon.s3_kopis"}],
		["B  long xiphos\n+ Attic helmet, high crest", {"hand_r": "weapon.s3_xiphos", "head_gear": "helm.s3_attic"}]],
	"steppe": [["A  long sabre\n(team tassel)", {"hand_r": "weapon.s3_sabre"}],
		["B  flared heavy sabre\n+ spiked helm, mail", {"hand_r": "weapon.s3_flared", "head_gear": "helm.s3_spike"}]],
	"han": [["A  jian\n(straight, team tassel)", {"hand_r": "weapon.s3_jian"}],
		["B  dao\n(broad, ring pommel)", {"hand_r": "weapon.s3_dao"}]],
	"swamp": [["A  reed saw\n(obsidian teeth)", {"hand_r": "weapon.s3_reed_saw"}],
		["B  river-stone mace", {"hand_r": "weapon.s3_stone_mace"}]],
	"forest": [["A  chitin-edged blade", {"hand_r": "weapon.s3_chitin_blade"}],
		["B  thorn sword", {"hand_r": "weapon.s3_thorn"}]],
	"spooky": [["A  bone scythe-sword", {"hand_r": "weapon.s3_bone_scythe"}],
		["B  hooked sickle blade\n(silk grip)", {"hand_r": "weapon.s3_hook"}]],
}
const CELL := Vector2(46, 62)   # world units per cell
const EXTRA := [[6, 0.22, "wind-up"], [6, 0.62, "blow"]]   # [facing, attack phase, label]

var lib
var team: Color


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	var zoom := float(args[1]) if args.size() > 1 else 4.5
	var fams: Array = Array(args[2].split(",")) if args.size() > 2 else FAMILIES
	DirAccess.make_dir_recursive_absolute(out_dir)
	lib = DataLib.new()
	team = Color(lib.palettes.teams[0])
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	var sets := []   # per family: [family, [[label, unit], ...]]
	var races := []
	for fam in fams:
		var race: Dictionary = gen.generate(PROMPTS[fam], rules)
		races.append(race)
		var u: Dictionary = race.units.filter(func(x): return x.recipe.slot == "infantry")[0]
		var age2: Dictionary = u.line[0]
		var age3: Dictionary = u.line[0]
		for l in u.line:
			if int(l.age) <= 2:
				age2 = l
			if int(l.age) <= 3:
				age3 = l
		print("%-9s age 2 %s\n          age 3 %s" % [fam, age2.recipe.parts, age3.recipe.parts])
		var rows := [["age 2 (age 3 today%s)\n%s" % ["" if JSON.stringify(age2.recipe.parts) == JSON.stringify(age3.recipe.parts) else ": a helmet", age2.recipe.name], age2]]
		for o in OPTIONS[fam]:
			var v: Dictionary = age3.duplicate(true)   # the options build on age 3's step (han's lamellar helmet)
			for slot in o[1]:
				v.recipe.parts[slot] = o[1][slot]
			rows.append([o[0], v])
		sets.append([fam, rows])
	_register()   # after generating: the generator would pick them (tier 3 blades)
	await kit.prepare_units(races, [team])
	var pb := PartBaker.new()
	pb.models = Concepts.new()
	pb.art_scale = ArtKit.ART_SCALE * ArtKit.UNIT_SCALE
	pb.bands = ArtKit.UNIT_BANDS
	root.add_child(pb)
	for s in sets:
		for row in s[1]:
			var probe := UnitView.new()
			probe.build(row[1].recipe, lib, team, row[1].eval.speed)
			for ps in probe.find_children("*", "Node2D", true, false):
				if ps is PartShape and ".s3_" in ps.part_id:
					await pb.bake(ps.part_id, ps.shapes, ps.colours)
			probe.free()
	kit.rebuild_atlas()
	var tag := str(zoom / ArtKit.ART_SCALE).trim_suffix(".0")
	if fams.size() > 1 and zoom <= 1.5:
		await _sheet(sets, zoom, out_dir.path_join("sword3_all_%sx.png" % tag))
	else:
		for s in sets:
			await _sheet([s], zoom, out_dir.path_join("sword3_%s_%sx.png" % [s[0], tag]))
	quit()


## The concept parts in the loaded data only: weapons as the bronze sword's entry under a new id
## at tier 3, helmets as the culture's age-2 helmet's.
func _register() -> void:
	for fam in OPTIONS:
		for o in OPTIONS[fam]:
			for slot in o[1]:
				var id: String = o[1][slot]
				var base := "weapon.sword.bronze" if slot == "hand_r" else "helm.bronze"
				var p: Dictionary = lib.part(base).duplicate(true)
				p.id = id
				p.tier = 3
				lib.parts[id] = p


func _unit(world: Node2D, unit: Dictionary, at: Vector2, k: int, phase := -1.0) -> void:
	var v := UnitView.new()
	v.facing_k = k
	v.build(unit.recipe, lib, team, unit.eval.speed)
	v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
	v.position = at
	v.idle_wait = 1000.0
	v.pose_steps = 8
	world.add_child(v)
	if phase >= 0.0:
		v.attack_t = 0.35 * (1.0 - phase) + 0.0001
	v._process(0.0)
	v.set_process(false)


func _sheet(sets: Array, zoom: float, path: String) -> void:
	var cols := 8 + EXTRA.size()
	var label_w := 230.0 if zoom > 2 else 150.0
	var head_h := 34.0
	var rows := 0
	for s in sets:
		rows += s[1].size()
	var vp := SubViewport.new()
	vp.size = Vector2i(int(label_w + CELL.x * zoom * (cols + 0.3)), int(head_h + CELL.y * zoom * rows + 8 * sets.size()))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var band := ColorRect.new()
	band.color = Color(0, 0, 0, 0.07)
	band.position = Vector2(label_w + CELL.x * (8.15) * zoom, 0)
	band.size = Vector2(CELL.x * EXTRA.size() * zoom, vp.size.y)
	vp.add_child(band)
	var fs := 14 if zoom > 2 else 10
	var title := "swordsman age 3, concept S3: the eight facings"
	if sets.size() == 1:
		title = "%s swordsman, age 3 (concept S3): age 2 today, then options A and B in the eight facings" % sets[0][0]
	vp.add_child(_label(title, Vector2(label_w, 8), fs))
	for e in EXTRA.size():
		vp.add_child(_label(EXTRA[e][2], Vector2(label_w + CELL.x * (8.3 + e) * zoom, 8), fs))
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom
	world.position = Vector2(label_w, head_h)
	vp.add_child(world)
	var r := 0
	var gap := 0.0
	for s in sets:
		for row in s[1]:
			var y0: float = head_h + r * CELL.y * zoom + gap
			var text: String = row[0] if sets.size() == 1 else "%s: %s" % [s[0], row[0]]
			vp.add_child(_label(text, Vector2(8, y0 + 0.3 * CELL.y * zoom), fs))
			var base_y := (r + 0.85) * CELL.y + gap / zoom
			for k in 8:
				_unit(world, row[1], Vector2((k + 0.5) * CELL.x, base_y), k)
			for e in EXTRA.size():
				_unit(world, row[1], Vector2((8.65 + e) * CELL.x, base_y), EXTRA[e][0], EXTRA[e][1])
			r += 1
		gap += 8.0
		if sets.size() > 1:
			var line := ColorRect.new()
			line.color = Color(0, 0, 0, 0.25)
			line.position = Vector2(0, head_h + r * CELL.y * zoom + gap - 5)
			line.size = Vector2(vp.size.x, 2)
			vp.add_child(line)
	for f in 20:
		await process_frame
	vp.get_texture().get_image().save_png(path)
	print("saved ", path)
	vp.queue_free()


func _label(text: String, at: Vector2, fs: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	return l
