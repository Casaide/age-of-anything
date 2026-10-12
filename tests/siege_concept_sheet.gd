extends SceneTree
## Siege engine concepts (milestone 13, D-080): the ram, catapult and bolt thrower from
## scenes/art_pixel/siege_concepts.gd, each family's take in two directions (A: the engine
## alone; B: the crew shows), baked like unit parts and drawn at the game's size with the
## race's worker beside it (B: the crew on the engine's sockets). One row per family; three
## facings per direction. Zoom 1.5 is the game's scale (one art pixel per screen pixel).
## Run (needs a display):
##   godot --path . --script res://tests/siege_concept_sheet.gd -- out_dir [zoom] [engine,...]
## writes <out_dir>/siege_<engine>_<zoom>x.png

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const Siege := preload("res://scenes/art_pixel/siege_concepts.gd")

## family -> [prompt for the crew's race, the race's family for its cloth, label]
const ROWS := [["timber", "romans", "imperial", "humans: timber\n(imperial trim)"],
	["swamp", "swamp frogs", "swamp", "frogs: swamp"], ["sewer", "sewer rats", "sewer", "rats: sewer"],
	["forest", "forest beetles", "forest", "beetles: forest"], ["spooky", "spooky spiders", "spooky", "spiders: spooky"]]
const FACINGS := [0, 2, 6]
const NAMES := {"ram": ["A: covered shed, crew hidden", "B: open ram, crew alongside (forest: a beetle pushes)"],
	"catapult": ["A: arm-and-cup engine", "B: pole flinger, the crew pulls"],
	"bolt": ["A: on a wheeled carriage", "B: on a tripod, a crew member aims"]}
const CELL := Vector2(76, 56)   # world units per cell (a unit part unit is 0.85 of these)

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
	for row in ROWS:
		races.append(gen.generate(row[1], rules))
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
		for r in ROWS.size():
			var colours := _colours(races[r], ROWS[r][2])
			for dir in ["a", "b"]:
				var id := "siege.%s.%s.%s" % [engine, dir, ROWS[r][0]]
				for k in [2, 6, 0]:   # only the facings shown: each baked as facing 0, then filed under k (0 last)
					pb.azimuth = PartBaker.AZIMUTH + PartBaker.FACING_STEP * k
					var key := PartShape.bake_key(id, [], PartShape.team_neutral(colours))
					await pb.bake(id, [], colours)
					if k != 0:
						PartShape.baked[key + PartShape.facing_suffix(k)] = PartShape.baked[key]
						PartShape.rigs[id + PartShape.facing_suffix(k)] = PartShape.rigs.get(id, {})
						PartShape.baked.erase(key)
	kit.rebuild_atlas()
	for engine in engines:
		await _sheet(engine, races, zoom, out_dir.path_join("siege_%s_%sx.png" % [engine, str(zoom / ArtKit.ART_SCALE).trim_suffix(".0")]))
	quit()


func _colours(race: Dictionary, family: String) -> Dictionary:
	return UnitView.colours_for(lib, race.units[0].recipe.skin, family, team)


func _sheet(engine: String, races: Array, zoom: float, path: String) -> void:
	var label_w := 120.0
	var head_h := 40.0
	var cols := FACINGS.size() * 2
	var vp := SubViewport.new()
	vp.size = Vector2i(int(label_w + CELL.x * zoom * cols), int(head_h + CELL.y * zoom * ROWS.size()))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	for d in 2:   # a slightly darker band behind direction B
		var band := ColorRect.new()
		band.color = Color(0, 0, 0, 0.06 * d)
		band.position = Vector2(label_w + d * FACINGS.size() * CELL.x * zoom, 0)
		band.size = Vector2(FACINGS.size() * CELL.x * zoom, vp.size.y)
		vp.add_child(band)
		var l := _label(NAMES[engine][d], Vector2(label_w + (d + 0.0) * FACINGS.size() * CELL.x * zoom + 8, 6), 14 if zoom > 2 else 11)
		vp.add_child(l)
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom
	world.position = Vector2(label_w, head_h)
	world.z_index = 10   # its children sort -2..1 among themselves, all above the background
	vp.add_child(world)
	for r in ROWS.size():
		vp.add_child(_label(ROWS[r][3], Vector2(8, head_h + (r + 0.4) * CELL.y * zoom), 14 if zoom > 2 else 10))
		var worker: Dictionary = races[r].units[0]
		var colours := _colours(races[r], ROWS[r][2])
		for d in 2:
			var id := "siege.%s.%s.%s" % [engine, ["a", "b"][d], ROWS[r][0]]
			for f in FACINGS.size():
				var k: int = FACINGS[f]
				var at := Vector2((d * FACINGS.size() + f + 0.55) * CELL.x, (r + 0.72) * CELL.y)
				var ps := PartShape.new()
				ps.part_id = id
				ps.facing = k
				ps.scale = Vector2.ONE * ArtKit.UNIT_SCALE
				ps.position = at
				world.add_child(ps)
				ps.setup([], colours)
				var shadow := _shadow(engine)
				shadow.position = at
				shadow.z_index = -2
				world.add_child(shadow)
				var rig: Dictionary = PartShape.rigs.get(id + PartShape.facing_suffix(k), {})
				var crew := []
				if d == 0 and f == 0:   # a worker standing by, for size
					crew.append([Vector2(-CELL.x * 0.4, 6) / ArtKit.UNIT_SCALE, 1.0, k])
				for s in rig.get("sockets", {}):
					var face := k if engine != "catapult" else (k + 4) % 8   # the flinger's crew face it, pulling
					crew.append([rig.sockets[s], rig.depth[s], face])
				crew.sort_custom(func(a, b): return a[1] < b[1])
				for c in crew:
					var v := UnitView.new()
					v.facing_k = c[2]
					v.build(worker.recipe, lib, team, worker.eval.speed)
					v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
					v.position = at + c[0] * ArtKit.UNIT_SCALE
					v.z_index = 1 if c[1] > 0.0 else -1
					v.idle_wait = 1000.0
					world.add_child(v)
					if engine == "ram" and d == 1:
						v.walking = true
						v.phase = 0.6 * crew.find(c)
					v._process(0.0)
					v.set_process(false)
	for f in 20:
		await process_frame
	vp.get_texture().get_image().save_png(path)
	print("saved ", path)
	vp.queue_free()


## A soft flat shadow under the engine (the real thing would bake its own, as buildings do).
func _shadow(engine: String) -> Polygon2D:
	var r: Vector2 = {"ram": Vector2(20, 7), "catapult": Vector2(20, 8), "bolt": Vector2(17, 7)}[engine]
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
