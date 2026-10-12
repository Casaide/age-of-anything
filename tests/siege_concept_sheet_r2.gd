extends SceneTree
## Siege concepts, round 2 (milestone 13, 2026-10-13): every engine crewed (D-118), the rats'
## engines at human scale from sewer junk (D-116), the forest ram a giant beetle (D-117), the
## frogs' engines grown for their crouched crew, and round 1's human picks crewed alongside so
## the scale is the same. Models in scenes/art_pixel/siege_concepts.gd (round 2 section); the
## crew are the race's own workers, composed on the engine's sockets (names say facing, hold and
## layer). One sheet per engine: a "for size" column (the worker; for the beetles also their
## cavalry), then three facings. Zoom 1.5 is the game's scale. Run (needs a display):
##   godot --path . --script res://tests/siege_concept_sheet_r2.gd -- out_dir [zoom] [engine,...]
## writes <out_dir>/siege_r2_<engine>_<zoom>x.png

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const Siege := preload("res://scenes/art_pixel/siege_concepts.gd")

## The crews' races: prompt, family (for the cloth).
const RACES := [["romans", "imperial"], ["swamp frogs", "swamp"], ["sewer rats", "sewer"], ["forest beetles", "forest"]]
## engine -> rows of [model id, race index, label]
const ROWS := {
	"ram": [["siege.ram.c.timber", 0, "humans: open ram\n(round 1 B, crewed)"],
		["siege.ram.c.swamp", 1, "frogs: open ram\n(grown for the frogs)"],
		["siege.ram.shed.junk", 2, "rats: covered ram\n(junk shed, crew shove)"],
		["siege.ram.c.junk", 2, "rats: open ram\n(pipes and chains)"],
		["siege.ram.ridden.forest", 3, "beetles: giant beetle\nridden (howdah)"],
		["siege.ram.led.forest", 3, "beetles: giant beetle\nled (rope and goad)"]],
	"catapult": [["siege.catapult.c.timber", 0, "humans: catapult\n(round 1 A, crewed)"],
		["siege.catapult.c.swamp", 1, "frogs: catapult\n(grown for the frogs)"],
		["siege.catapult.c.junk", 2, "rats: catapult\n(junk, cheese)"]],
	"bolt": [["siege.bolt.c.timber", 0, "humans: bolt thrower\n(round 1 A, crewed)"],
		["siege.bolt.c.swamp", 1, "frogs: bolt thrower\n(grown for the frogs)"],
		["siege.bolt.c.junk", 2, "rats: bolt thrower\n(junk, grate shield)"]],
}
const FACINGS := [0, 2, 6]
const MOUNT := "siege.ram.mount.forest"   # a cavalry beetle, for size beside the giant one
const SIZE_COL := 0.8   # the "for size" column, in cells
## World units per cell, per engine.
const CELLS := {"ram": Vector2(130, 100), "catapult": Vector2(105, 92), "bolt": Vector2(100, 80)}
const SHADOWS := {"c.ram": Vector2(30, 10), "shed.ram": Vector2(30, 11), "ridden.ram": Vector2(40, 14), "led.ram": Vector2(40, 14),
	"c.catapult": Vector2(25, 10), "c.bolt": Vector2(22, 9)}

var lib
var team: Color


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	var zoom := float(args[1]) if args.size() > 1 else 4.5
	var engines: Array = Array(args[2].split(",")) if args.size() > 2 else ["ram", "catapult", "bolt"]
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
	for engine in engines:
		for row in ROWS[engine] + ([[MOUNT, 3]] if engine == "ram" else []):
			var id: String = row[0]
			var colours := _colours(races[row[1]], RACES[row[1]][1])
			for k in ([2, 6, 0] if id != MOUNT else [0]):   # only the facings shown: each baked as facing 0, then filed under k (0 last)
				pb.azimuth = PartBaker.AZIMUTH + PartBaker.FACING_STEP * k
				var key := PartShape.bake_key(id, [], PartShape.team_neutral(colours))
				await pb.bake(id, [], colours)
				if k != 0:
					PartShape.baked[key + PartShape.facing_suffix(k)] = PartShape.baked[key]
					PartShape.rigs[id + PartShape.facing_suffix(k)] = PartShape.rigs.get(id, {})
					PartShape.baked.erase(key)
	kit.rebuild_atlas()
	for engine in engines:
		await _sheet(engine, races, zoom, out_dir.path_join("siege_r2_%s_%sx.png" % [engine, str(zoom / ArtKit.ART_SCALE).trim_suffix(".0")]))
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


func _sheet(engine: String, races: Array, zoom: float, path: String) -> void:
	var label_w := 180.0 if zoom > 2 else 120.0
	var head_h := 30.0
	var cell: Vector2 = CELLS[engine]
	var rows: Array = ROWS[engine]
	var cols := FACINGS.size() + SIZE_COL
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
	vp.add_child(_label("%s, round 2: three facings, crew on the engine" % engine, Vector2(label_w + cell.x * SIZE_COL * zoom + 8, 6), fs))
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom
	world.position = Vector2(label_w, head_h)
	world.z_index = 10   # its children sort -2..1 among themselves, all above the background
	vp.add_child(world)
	for r in rows.size():
		var id: String = rows[r][0]
		var race: Dictionary = races[rows[r][1]]
		var worker: Dictionary = race.units[0]
		var colours := _colours(race, RACES[rows[r][1]][1])
		vp.add_child(_label(rows[r][2], Vector2(8, head_h + (r + 0.4) * cell.y * zoom), fs))
		# For size: the worker, and for the beetles their cavalry.
		var base_y := (r + 0.75) * cell.y
		if id.contains("forest"):   # the worker and a cavalry beetle
			_unit(world, worker, Vector2(cell.x * 0.18, base_y), 0, "", 0, false, 0.0)
			var m := PartShape.new()
			m.part_id = MOUNT
			m.scale = Vector2.ONE * ArtKit.UNIT_SCALE
			m.position = Vector2(cell.x * 0.52, base_y)
			world.add_child(m)
			m.setup([], colours)
		else:
			_unit(world, worker, Vector2(cell.x * SIZE_COL * 0.5, base_y), 0, "", 0, false, 0.0)
		var p := id.split(".")
		for f in FACINGS.size():
			var k: int = FACINGS[f]
			var at := Vector2((f + SIZE_COL + 0.5) * cell.x, base_y)
			var ps := PartShape.new()
			ps.part_id = id
			ps.facing = k
			ps.scale = Vector2.ONE * ArtKit.UNIT_SCALE
			ps.position = at
			world.add_child(ps)
			ps.setup([], colours)
			var shadow := _shadow(SHADOWS["%s.%s" % [p[2], p[1]]] * (1.3 if p[3] == "swamp" else 1.0))
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
				var walking := p[1] == "ram" and not "top" in tags
				_unit(world, worker, at + crew[i][1] * ArtKit.UNIT_SCALE, face, hold, z, walking, 0.7 * i)
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
