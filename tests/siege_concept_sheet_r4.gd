extends SceneTree
## Siege concepts, round 4 (milestone 13, 2026-10-13): other catapults for the frogs' swamp beasts
## (D-121: the newt may go to the cavalry; Dominic: "catapult on snail maybe?"). The humans' picked
## catapult and round 3's newt head the sheet; then the snail, the toad (the swap), a bigger snapping
## turtle, and round 3's reed catapult hauled by the turtle. The bolt sheet shows the other half of the
## swap (the turtle carrying the bolt thrower); the sets sheet the whole frog siege per proposal in one
## facing. Models in scenes/art_pixel/siege_concepts.gd (round 4 section). Zoom 1.5 is the game's
## scale. Run (needs a display):
##   godot --path . --script res://tests/siege_concept_sheet_r4.gd -- out_dir [zoom] [sheet,...]
## sheets: catapult, bolt (a "for size" column, then three facings), sets. Writes
## <out_dir>/siege_r4_<sheet>_<zoom>x.png

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const Siege := preload("res://scenes/art_pixel/siege_concepts.gd")

## The crews' races: prompt, family (for the cloth).
const RACES := [["romans", "imperial"], ["swamp frogs", "swamp"]]
## Each sheet's rows: [model id, race index, label].
const ROWS := {
	"catapult": [["siege.catapult.c.timber", 0, "humans (picked)\ncatapult, crewed"],
		["siege.catapult.beast.frog", 1, "round 3: newt\n(for comparison)"],
		["siege.catapult.snail.frog", 1, "1. snail\n(Dominic's idea)"],
		["siege.catapult.toad.frog", 1, "2. toad\n(swap with the bolt)"],
		["siege.catapult.turtle.frog", 1, "3. big snapping\nturtle"],
		["siege.catapult.haul.frog", 1, "4. reed catapult\nhauled by the turtle"]],
	"bolt": [["siege.bolt.c.timber", 0, "humans (picked)\nbolt thrower, crewed"],
		["siege.bolt.beast.frog", 1, "round 3: toad\n(picked)"],
		["siege.bolt.turtle.frog", 1, "turtle\n(the swap's other half)"]],
}
## The sets sheet: a frog siege train per proposal, one facing: [label, [ram, catapult, bolt]].
const SETS := [
	["humans (picked)", 0, ["siege.ram.c.timber", "siege.catapult.c.timber", "siege.bolt.c.timber"]],
	["frogs: snail catapult\n(recommended)", 1, ["siege.ram.beast.frog", "siege.catapult.snail.frog", "siege.bolt.beast.frog"]],
	["frogs: the swap", 1, ["siege.ram.beast.frog", "siege.catapult.toad.frog", "siege.bolt.turtle.frog"]],
]
const FACINGS := [0, 2, 6]
const SIZE_COL := 0.45   # the "for size" column, in cells
## World units per cell, per sheet.
const CELLS := {"catapult": Vector2(170, 118), "bolt": Vector2(120, 100), "sets": Vector2(135, 118)}
## Shadow radii per engine (world units, before the unit scale); the haul is two things in a row.
const SHADOWS := {"ram": Vector2(42, 15), "catapult": Vector2(36, 14), "bolt": Vector2(32, 13), "haul": Vector2(70, 16)}

var lib
var team: Color


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	var zoom := float(args[1]) if args.size() > 1 else 4.5
	var sheets: Array = Array(args[2].split(",")) if args.size() > 2 else ["catapult", "bolt", "sets"]
	DirAccess.make_dir_recursive_absolute(out_dir)
	lib = DataLib.new()
	team = Color(lib.palettes.teams[0])
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races := []
	for r in RACES:
		races.append(gen.generate(r[0], rules))
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	await kit.prepare_units(races, races.map(func(_r): return team))
	var pb := PartBaker.new()
	pb.models = Siege.new()
	pb.art_scale = ArtKit.ART_SCALE * ArtKit.UNIT_SCALE
	pb.bands = ArtKit.UNIT_BANDS
	pb.facings = 1
	root.add_child(pb)
	var bakes := {}   # model id -> race index, each once
	for sheet in ROWS:
		for row in ROWS[sheet]:
			bakes[row[0]] = row[1]
	for set in SETS:
		for id in set[2]:
			bakes[id] = set[1]
	for id in bakes:
		var colours := _colours(races[bakes[id]], RACES[bakes[id]][1])
		for k in [2, 6, 0]:   # only the facings shown: each baked as facing 0, then filed under k (0 last)
			pb.azimuth = PartBaker.AZIMUTH + PartBaker.FACING_STEP * k
			var key := PartShape.bake_key(id, [], PartShape.team_neutral(colours))
			await pb.bake(id, [], colours)
			if k != 0:
				PartShape.baked[key + PartShape.facing_suffix(k)] = PartShape.baked[key]
				PartShape.rigs[id + PartShape.facing_suffix(k)] = PartShape.rigs.get(id, {})
				PartShape.baked.erase(key)
	kit.rebuild_atlas()
	var tag := str(zoom / ArtKit.ART_SCALE).trim_suffix(".0")
	for sheet in sheets:
		await _sheet(sheet, races, zoom, out_dir.path_join("siege_r4_%s_%sx.png" % [sheet, tag]))
	quit()


func _colours(race: Dictionary, family: String) -> Dictionary:
	return UnitView.colours_for(lib, race.units[0].recipe.skin, family, team)


## One of the race's units drawn at `at` (world), facing k, in a hold; z layer `z`.
func _unit(world: Node2D, unit: Dictionary, at: Vector2, k: int, hold: String, z: int, walking: bool, phase: float) -> void:
	var v := UnitView.new()
	v.facing_k = k
	v.build(unit.recipe, lib, team, unit.eval.speed)
	v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
	v.position = at
	v.z_index = z
	v.idle_wait = 1000.0
	world.add_child(v)
	if hold != "":
		v.set_hold(hold)
	v.walking = walking
	v.phase = phase
	v._process(0.0)
	v.set_process(false)


## An engine at `at`, facing k, with its shadow and its crew on the engine's sockets.
func _engine(world: Node2D, id: String, race: Dictionary, colours: Dictionary, at: Vector2, k: int) -> void:
	var engine: String = id.split(".")[1]
	var shadow_r: Vector2 = SHADOWS["haul" if id.split(".")[2] == "haul" else engine]
	var ps := PartShape.new()
	ps.part_id = id
	ps.facing = k
	ps.scale = Vector2.ONE * ArtKit.UNIT_SCALE
	ps.position = at
	world.add_child(ps)
	ps.setup([], colours)
	var shadow := _shadow(shadow_r)
	shadow.position = at
	shadow.z_index = -2
	world.add_child(shadow)
	var rig: Dictionary = PartShape.rigs.get(id + PartShape.facing_suffix(k), {})
	var crew := []
	for s in rig.get("sockets", {}):
		crew.append([s, rig.sockets[s], rig.depth[s]])
	crew.sort_custom(func(a, b): return a[2] < b[2])
	for i in crew.size():
		var tags: PackedStringArray = crew[i][0].split("_")
		var face := k
		var hold := ""
		var z := 1 if crew[i][2] > 0.0 else -1
		for t in tags:
			if t.begins_with("f") and t.length() == 2:
				face = (k + int(t.substr(1))) % 8
			elif t in ["reach", "raise"]:
				hold = t
			elif t == "in":
				z = -1
			elif t == "top":
				z = 1
		var walking := engine == "ram" and not "top" in tags
		_unit(world, race.units[0], at + crew[i][1] * ArtKit.UNIT_SCALE, face, hold, z, walking, 0.7 * i)


func _sheet(sheet: String, races: Array, zoom: float, path: String) -> void:
	var label_w := 190.0 if zoom > 2 else 120.0
	var head_h := 30.0
	var cell: Vector2 = CELLS[sheet]
	var overview := sheet == "sets"
	# Rows of [label, race index, cells of [id, facing]].
	var rows := []
	if overview:
		for set in SETS:
			rows.append([set[0], set[1], set[2].map(func(id): return [id, 0])])
	else:
		for r in ROWS[sheet]:
			rows.append([r[2], r[1], FACINGS.map(func(k): return [r[0], k])])
	var cols := 3 + SIZE_COL
	var vp := SubViewport.new()
	vp.size = Vector2i(int(label_w + cell.x * zoom * cols), int(head_h + cell.y * zoom * rows.size()))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var band := ColorRect.new()   # a slightly darker band behind the size column
	band.color = Color(0, 0, 0, 0.07)
	band.position = Vector2(label_w, 0)
	band.size = Vector2(cell.x * SIZE_COL * zoom, vp.size.y)
	vp.add_child(band)
	var fs := 14 if zoom > 2 else 10
	vp.add_child(_label("for size", Vector2(label_w + 8, 6), fs))
	var title: String = "frog siege, round 4: ram, catapult, bolt thrower per proposal (one facing)" if overview \
		else {"catapult": "catapult, round 4: the frogs' swamp-beast catapults, three facings, crewed",
			"bolt": "bolt thrower, round 4: the toad, or the turtle (if the toad takes the catapult)"}[sheet]
	vp.add_child(_label(title, Vector2(label_w + cell.x * SIZE_COL * zoom + 8, 6), fs))
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom
	world.position = Vector2(label_w, head_h)
	world.z_index = 10
	vp.add_child(world)
	for r in rows.size():
		var race: Dictionary = races[rows[r][1]]
		var colours := _colours(race, RACES[rows[r][1]][1])
		vp.add_child(_label(rows[r][0], Vector2(8, head_h + (r + 0.4) * cell.y * zoom), fs))
		var base_y := (r + 0.78) * cell.y
		_unit(world, race.units[0], Vector2(cell.x * SIZE_COL * 0.5, base_y), 0, "", 0, false, 0.0)
		for f in rows[r][2].size():
			var c: Array = rows[r][2][f]
			_engine(world, c[0], race, colours, Vector2((f + SIZE_COL + 0.5) * cell.x, base_y), c[1])
	for f in 20:
		await process_frame
	vp.get_texture().get_image().save_png(path)
	print("saved ", path)
	vp.queue_free()


## A soft flat shadow under the engine (the real thing would bake its own, as buildings do).
func _shadow(r: Vector2) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 28:
		pts.append(Vector2(cos(TAU * k / 28.0) * r.x, sin(TAU * k / 28.0) * r.y))
	p.polygon = pts
	p.color = Color(0, 0, 0, 0.22)
	return p


func _label(text: String, at: Vector2, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#f4f1e8"))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 3)
	return l
