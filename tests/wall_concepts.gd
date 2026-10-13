extends SceneTree
## Walls for sieges, concept round W2 (milestone 16; Dominic: the siege towers are too small, the walls
## "a bit buggy and overlappy, and not really big enough", learn from castle-building games, "less like
## the classic first-generation look"). Options first (D-080): nothing here is in play.
##
## Each option is one walled corner, built as a whole in 3D and baked once with the building baker (so
## joins are the model's own, no sprite overlaps): a wall run along sim x with a gatehouse in it, a run
## along sim y, a tower on the corner and at the ends, defenders up on the walkway between the merlons
## (the game's own unit art, stood in the scene on upright cards so merlons in front hide their legs),
## and the attack: a siege tower docked with its gangway down on the walkway, a ladder against the other
## run with a climber on it, and attackers at the foot. The town is inside (up the screen); the outside
## faces the camera.
##
## Options (OPTIONS below): "now" (the walls in play after today's fixes, the siege tower at its size in
## play, for scale), "a" thick (a 2-tile-deep stone curtain, walkway with parapets both sides, round towers
## rising well above, a twin-towered gatehouse), "b" tall (a 1-tile curtain as tall again, square towers
## with timber hoardings and roofs, a square twin gatehouse), "c" per culture (option a's shape in the
## rats' brick and scrap, and the frogs' earth rampart with a stake breastwork and mud drum towers).
## Writes <out_dir>/walls_w2_<option>_1x.png (the game's scale) and _3x.png, and walls_w2_sheet_1x.png.
## Run (needs a display):
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/wall_concepts.gd -- out_dir [option,...]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const UnitView := preload("res://src/unit_view.gd")
const Baker := preload("res://src/view/art/bake/baker.gd")
const Models := preload("res://src/view/art/bake/models.gd")
const Materials := preload("res://src/view/art/bake/materials.gd")
const BuildingArt := preload("res://src/view/art/building_art.gd")

const BG := Color("#56782e")
const RENDER := 6144      # the bake's frame (supersampled 4x): a corner is about 20 tiles across the screen

## The styles. depth: wall thickness (tiles); walk: walkway height; merlon: [height, width, beat];
## inner: the town side's parapet ("low", "merlons", "none"); tower: [shape, size, height, roof]; gate:
## [tower shape, tower size, passage width, height]; hoard: timber hoardings on towers and gatehouse;
## rampart: an earth bank with a stake breastwork instead of a stone curtain.
const OPTIONS := {
	"now": {"title": "now: the walls in play (after today's fixes), the siege tower in play",
		"real": true, "walk": 0.72, "siege_tower": 0.83},
	"a": {"title": "A  thick: 2-tile curtain, parapets both sides, round towers, twin-tower gate",
		"stone": "stone", "depth": 2.0, "walk": 1.5, "merlon": [0.32, 0.26, 0.5], "inner": "low",
		"tower": ["round", 2.4, 2.6, ""], "gate": ["round", 2.2, 2.0, 2.4], "corner": true},
	"b": {"title": "B  tall: 1-tile curtain twice as high, square towers with hoardings and roofs",
		"stone": "stone", "depth": 1.0, "walk": 1.7, "merlon": [0.3, 0.22, 0.45], "inner": "none",
		"tower": ["square", 2.0, 2.9, "terracotta"], "gate": ["square", 2.0, 2.0, 2.6], "hoard": true, "corner": true},
	"c_rats": {"title": "C  per culture: the rats' brick and scrap (A's shape, tin roofs)",
		"def": "sewer rats", "att": "romans", "stone": "brick", "depth": 2.0, "walk": 1.5, "merlon": [0.3, 0.26, 0.5], "inner": "low",
		"tower": ["square", 2.2, 2.6, "tin"], "gate": ["square", 2.0, 2.0, 2.4], "scrap": true, "corner": true},
	"c_frogs": {"title": "C  per culture: the frogs' earth rampart, a stake breastwork, mud drum towers",
		"def": "bog frogs", "att": "romans", "stone": "mud", "depth": 2.4, "walk": 1.2, "merlon": [0.0, 0.0, 0.0], "inner": "none",
		"tower": ["round", 2.2, 2.2, "thatch"], "gate": ["round", 2.0, 2.0, 2.0], "rampart": true, "corner": true},
}
## The layout (tiles; the corner at the origin, the town at negative x and z): run A along x at the
## back of z = 0, run B along z at the back of x = 0, the gatehouse's passage centred on GATE_X.
const RUN_A := 12.0
const RUN_B := 8.0
const GATE_X := -6.5
const TOWER_SIEGE_X := -10.6   # the siege tower docks against run A here
const LADDER_Z := -4.5         # the ladder leans on run B here
const DIAG := 3.5              # a diagonal stretch on from run B's far tower, this far each way

var lib
var gen
var kit
var baker
var models: Models
var team_def: Color
var team_att: Color
var units := {}        # key -> {img, foot}: the game's unit art, rendered once per facing
var races := {}


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	var only: Array = Array(args[1].split(",")) if args.size() > 1 else OPTIONS.keys()
	DirAccess.make_dir_recursive_absolute(out_dir)
	lib = DataLib.new()
	gen = Generator.new(lib)
	team_def = Color(lib.palettes.teams[0])
	team_att = Color(lib.palettes.teams[1])
	var rules = DataLib.load_json("res://data/rules/default.json")
	var pairs := {}
	for id in only:
		pairs[OPTIONS[id].get("def", "romans")] = true
		pairs[OPTIONS[id].get("att", "sewer rats")] = true
	for p in pairs:
		races[p] = gen.generate(p, rules)
	kit = ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	await kit.prepare_units(pairs.keys().map(func(p): return races[p]), pairs.keys().map(func(_p): return team_def))
	for id in only:
		races.def = races[OPTIONS[id].get("def", "romans")]
		races.att = races[OPTIONS[id].get("att", "sewer rats")]
		await _render_units()
	baker = await kit._hifi_baker()
	models = kit._models
	baker.size = Vector2i(RENDER, RENDER)
	baker.cam.size = float(RENDER) / (Baker.PX_PER_UNIT * ArtKit.ART_SCALE * ArtKit.SS)
	var shots := []
	for id in only:
		var o: Dictionary = OPTIONS[id]
		races.def = races[o.get("def", "romans")]
		races.att = races[o.get("att", "sewer rats")]
		var scene := Node3D.new()
		var walk: float = o.walk
		if o.get("real", false):
			_real_walls(scene)
		else:
			_walls(scene, o)
		_people(scene, o, walk)
		_siege(scene, o, walk)
		scene.position = Vector3(3.5, 0, 5.0)   # the corner's middle on the bake's origin
		baker.set_ground_shadow(true)
		baker.shadow_reach = 0.25
		var b: Dictionary = await baker.bake(scene, [Vector3.ZERO])
		baker.set_ground_shadow(false)
		var art: Image = (b.tex as Texture2D).get_image()
		var one := _on_grass(art, 1.0 / ArtKit.ART_SCALE)
		one.save_png(out_dir.path_join("walls_w2_%s_1x.png" % id))
		var three := _on_grass(art, 2.0)
		three.save_png(out_dir.path_join("walls_w2_%s_3x.png" % id))
		shots.append([o.title, one])
		print("saved walls_w2_%s" % id)
	if shots.size() > 1:
		await _sheet(shots, out_dir.path_join("walls_w2_sheet_1x.png"))
	quit()


# ------------------------------------------------------------------ the walls in play (option "now")

## The pieces in play, tile by tile, as the game lays them (post plus linked arms, wall towers, the
## stone gate), in the same corner.
func _real_walls(scene: Node3D) -> void:
	var at := {}
	for x in range(-12, 0):
		at[Vector2i(x, -1)] = "wall"
	for z in range(-8, 0):
		at[Vector2i(-1, z)] = "wall"
	for c in [Vector2i(-1, -1), Vector2i(-12, -1), Vector2i(-1, -8), Vector2i(-4, -1)]:
		at[c] = "wall_tower"
	for x in range(-8, -5):
		at[Vector2i(x, -1)] = "gate"
	for c in at:
		var t: String = at[c]
		if t == "gate":
			if c.x != -7:
				continue
			var g: Dictionary = kit._placed(models, "stone", "stone_gate", "", "")
			g.body.position = Vector3(c.x + 0.5, 0, c.y + 0.5)
			_team_cloth(g.body)
			scene.add_child(g.body)
			continue
		var spec: Dictionary = kit._placed(models, "stone", t, "", "")
		var holder := Node3D.new()
		holder.position = Vector3(c.x + 0.5, 0, c.y + 0.5)
		holder.add_child(spec.body)
		if spec.has("arms"):
			var links := BuildingArt.links_of(func(d: Vector2i) -> bool: return at.has(c + d))
			for k in spec.arms.size():
				if links & (1 << k):
					holder.add_child(spec.arms[k])
		_team_cloth(holder)
		scene.add_child(holder)


## The game's bakes carry the team key (recoloured by a shader in play): the defenders' colour here.
func _team_cloth(node: Node) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mat := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if mat != null and mat.albedo_color.is_equal_approx(Color(1, 0, 1)):
			(mi as MeshInstance3D).material_override = models.cloth(team_def)


# ------------------------------------------------------------------ concept walls

func _walls(scene: Node3D, o: Dictionary) -> void:
	var D: float = o.depth
	var H: float = o.walk
	var m := models.mats.get_mat(o.stone)
	var tw: float = o.tower[1]
	var gw: float = o.gate[2] / 2.0
	var gt: float = o.gate[1]
	# Run A: from the far end tower to the corner tower, cut by the gatehouse.
	var a_lo := -RUN_A + tw * 0.5
	var a_hi := -tw * 0.5 - D * 0.5 + D * 0.5
	_run(scene, o, Vector3(a_lo, 0, -D * 0.5), Vector3(GATE_X - gw - gt, 0, -D * 0.5), m)
	_run(scene, o, Vector3(GATE_X + gw + gt, 0, -D * 0.5), Vector3(-tw * 0.5, 0, -D * 0.5), m)
	_run(scene, o, Vector3(-D * 0.5, 0, -tw * 0.5), Vector3(-D * 0.5, 0, -RUN_B + tw * 0.5), m)
	_tower(scene, o, Vector3(-D * 0.5, 0, -D * 0.5), true)
	_tower(scene, o, Vector3(-RUN_A, 0, -D * 0.5), false)
	_tower(scene, o, Vector3(-D * 0.5, 0, -RUN_B), false)
	_gatehouse(scene, o, Vector3(GATE_X, 0, -D * 0.5))
	if not o.get("rampart", false):   # a diagonal stretch on from run B's end, to one more tower: how a 45 degree run joins
		var d0 := Vector3(-D * 0.5, 0, -RUN_B)
		var d1 := d0 + Vector3(DIAG, 0, -DIAG)
		var off := Vector3(0.5, 0, -0.5).normalized() * (tw * 0.45)
		_run(scene, o, d0 + off, d1 - off, m)
		_tower(scene, o, d1, false)


## A straight stretch of curtain from a to b (on the ground, any way round: a diagonal too), D deep, H
## high, merlons on its outer face (the side towards the camera), the town side's parapet as asked.
func _run(scene: Node3D, o: Dictionary, a: Vector3, b: Vector3, m: Material) -> void:
	var D: float = o.depth
	var H: float = o.walk
	var along := (b - a).normalized()
	var L := a.distance_to(b)
	var mid := (a + b) * 0.5
	var out := Vector3(-along.z, 0, along.x)
	if out.x + out.z < 0.0:
		out = -out   # (the outside faces the camera: +x and +z)
	var rot := Vector3(0, -rad_to_deg(atan2(along.z, along.x)), 0)   # a box's length along the run
	if o.get("rampart", false):
		_rampart(scene, o, mid, L, rot, out)
		return
	var lay := func(size: Vector3, mat: Material, at: Vector3, tilt := 0.0) -> void:
		scene.add_child(models.box(size, mat, at, rot + Vector3(0, 0, tilt)))
	lay.call(Vector3(L, H, D), m, mid + Vector3(0, H / 2, 0))
	# A plinth (batter) along the outer foot: the wall reads as sitting on the ground, not dropped on it.
	lay.call(Vector3(L, 0.22, 0.16), m, mid + out * (D / 2 + 0.06) + Vector3(0, 0.11, 0))
	# The walkway's floor, a shade apart (flags), so it reads as a way along.
	lay.call(Vector3(L, 0.02, D - 0.34), models.mats.get_mat("stone"), mid + Vector3(0, H + 0.01, 0))
	var mh: float = o.merlon[0]
	var mw: float = o.merlon[1]
	var beat: float = o.merlon[2]
	var n := int(L / beat)
	for k in n:
		var t := -L / 2 + (k + 0.5) * L / n
		lay.call(Vector3(mw, mh, 0.16), m, mid + along * t + out * (D / 2 - 0.08) + Vector3(0, H + mh / 2, 0))
	# The parapet's low wall between the merlons on the outside, and the town side's.
	lay.call(Vector3(L, 0.12, 0.16), m, mid + out * (D / 2 - 0.08) + Vector3(0, H + 0.06, 0))
	if o.inner == "low":
		lay.call(Vector3(L, 0.14, 0.12), m, mid - out * (D / 2 - 0.06) + Vector3(0, H + 0.07, 0))
	# Arrow loops down the outer face: scale cues so the height reads.
	var dark := Materials.flat(Color("#1e1a16"), 1.0)
	for k in range(1, n, 3):
		var t := -L / 2 + (k + 0.5) * L / n
		lay.call(Vector3(0.05, 0.3, 0.02), dark, mid + along * t + out * (D / 2 + 0.005) + Vector3(0, H * 0.55, 0))
	if o.get("scrap", false):   # tin patches nailed over the brick here and there
		for k in range(2, n, 5):
			var t := -L / 2 + (k + 0.5) * L / n
			lay.call(Vector3(0.4, 0.3, 0.02), models.mats.get_mat("tin"), mid + along * t + out * (D / 2 + 0.01) + Vector3(0, H * 0.3, 0), 6.0)


## The frogs' rampart: a bank of earth (a wedge, steep outside, a slope inside), a breastwork of stakes
## along its top's outer edge, a walkway behind.
func _rampart(scene: Node3D, o: Dictionary, mid: Vector3, L: float, rot: Vector3, out: Vector3) -> void:
	var D: float = o.depth
	var H: float = o.walk
	var mud := models.mats.get_mat("mud")
	var top_w := D * 0.5
	scene.add_child(models.box(Vector3(L, H, top_w), mud, mid + out * (D / 2 - top_w / 2) + Vector3(0, H / 2, 0), rot))   # the bank's core
	var slope := Node3D.new()   # the town side: a long slope of earth up to the walkway
	slope.position = mid - out * (top_w / 2 - 0.0) + Vector3(0, H / 2 - 0.15, 0)
	slope.rotation_degrees = rot
	var s := models.box(Vector3(L, H * 1.05, (D - top_w) * 1.05), mud, Vector3(0, 0, 0))
	s.rotation_degrees = Vector3(-35 if out.z > 0 else 35, 0, 0) if absf(out.z) > 0.5 else Vector3(0, 0, 0)
	slope.add_child(s)
	if absf(out.z) < 0.5:
		s.rotation_degrees = Vector3(-35, 0, 0)
	scene.add_child(slope)
	var wood := models.mats.get_mat("wood")
	var along := Vector3(1, 0, 0) if absf(out.z) > 0.5 else Vector3(0, 0, 1)
	var n := int(L / 0.17)
	models.rng.seed = 7
	for k in n:
		var t := -L / 2 + (k + 0.5) * L / n
		var hh := models.rng.randf_range(0.5, 0.62)
		var p := mid + along * t + out * (D / 2 - 0.1) + Vector3(0, H, 0)
		scene.add_child(models.cyl(0.07, 0.075, hh, wood, p + Vector3(0, hh / 2, 0), Vector3(models.rng.randf_range(-4, 4), 0, models.rng.randf_range(-4, 4)), 7))
		scene.add_child(models.cyl(0.0, 0.07, 0.1, wood, p + Vector3(0, hh + 0.05, 0), Vector3.ZERO, 7))
	for y in [0.22, 0.42]:
		scene.add_child(models.box(Vector3(L, 0.04, 0.04) if absf(out.z) > 0.5 else Vector3(0.04, 0.04, L), wood, mid + out * (D / 2 - 0.18) + Vector3(0, H + y, 0)))
	scene.add_child(models.box(Vector3(L, 0.03, 0.5) if absf(out.z) > 0.5 else Vector3(0.5, 0.03, L), wood, mid + out * (D / 2 - 0.5) + Vector3(0, H + 0.015, 0)))   # a plank walk behind the stakes


## A tower: round or square, `size` across, rising well over the walkway; merlons round its top; a roof
## (cone or pyramid) if asked, standing on a hoarding when the style has them.
func _tower(scene: Node3D, o: Dictionary, at: Vector3, corner: bool) -> void:
	var shape: String = o.tower[0]
	var size: float = o.tower[1] * (1.0 if corner else 0.9)
	var h: float = o.tower[2] * (1.0 if corner else 0.92)
	var roof: String = o.tower[3]
	var m := models.mats.get_mat(o.stone)
	var dark := Materials.flat(Color("#1e1a16"), 1.0)
	var r := size / 2.0
	if shape == "round":
		scene.add_child(models.cyl(r, r * 1.06, h, m, at + Vector3(0, h / 2, 0), Vector3.ZERO, 28))
		scene.add_child(models.cyl(r * 1.1, r * 1.12, 0.26, m, at + Vector3(0, 0.13, 0), Vector3.ZERO, 28))   # its battered foot
	else:
		scene.add_child(models.box(Vector3(size, h, size), m, at + Vector3(0, h / 2, 0)))
		scene.add_child(models.box(Vector3(size + 0.14, 0.26, size + 0.14), m, at + Vector3(0, 0.13, 0)))
	# A ring of corbels and a slightly wider crown: the top reads as a fighting platform.
	if shape == "round":
		scene.add_child(models.cyl(r + 0.08, r, 0.14, m, at + Vector3(0, h - 0.05, 0), Vector3.ZERO, 28))
	else:
		scene.add_child(models.box(Vector3(size + 0.16, 0.14, size + 0.16), m, at + Vector3(0, h - 0.05, 0)))
	for k in 3:   # arrow loops up its face, towards the camera
		var y := h * (0.3 + k * 0.22)
		var face := Vector3(r * 0.71, 0, r * 0.71) if shape == "round" else Vector3(r + 0.005, 0, 0)
		scene.add_child(models.box(Vector3(0.03, 0.32, 0.07), dark, at + face + Vector3(0, y, 0), Vector3(0, 45 if shape == "round" else 0, 0)))
		if shape != "round":
			scene.add_child(models.box(Vector3(0.07, 0.32, 0.03), dark, at + Vector3(0, y, r + 0.005)))
	if o.get("hoard", false) or roof != "":
		_crown_roof(scene, o, at, size + 0.16, h, shape, roof)
	else:
		_merlon_ring(scene, o, at, size + 0.16, h, shape, m)
	# The team's banner on the corner tower.
	if corner:
		var pole := at + Vector3(-r * 0.3, h, -r * 0.3)
		var top_y: float = h + (1.2 if roof == "" else 1.5)
		scene.add_child(models.beam(pole, pole + Vector3(0, top_y - h, 0), 0.025, models.mats.get_mat("wood")))
		scene.add_child(models.box(Vector3(0.5, 0.32, 0.02), models.cloth(team_def), pole + Vector3(0.27, top_y - h - 0.2, 0)))


func _merlon_ring(scene: Node3D, o: Dictionary, at: Vector3, size: float, h: float, shape: String, m: Material) -> void:
	var r := size / 2.0
	var mh := 0.32
	if shape == "round":
		var n := int(TAU * r / 0.5)
		for k in n:
			var a := TAU * (k + 0.5) / n
			scene.add_child(models.box(Vector3(0.26, mh, 0.16), m, at + Vector3(cos(a) * (r - 0.08), h + 0.02 + mh / 2, sin(a) * (r - 0.08)), Vector3(0, -rad_to_deg(a) + 90, 0)))
		scene.add_child(models.cyl(r, r, 0.12, m, at + Vector3(0, h + 0.06, 0), Vector3.ZERO, 28).duplicate())
	else:
		var n := int(size / 0.5)
		for side in 4:
			for k in n:
				var t := -r + (k + 0.5) * size / n
				var p: Vector3 = [Vector3(t, 0, r - 0.08), Vector3(t, 0, -r + 0.08), Vector3(r - 0.08, 0, t), Vector3(-r + 0.08, 0, t)][side]
				var s := Vector3(0.26, mh, 0.16) if side < 2 else Vector3(0.16, mh, 0.26)
				scene.add_child(models.box(s, m, at + p + Vector3(0, h + 0.02 + mh / 2, 0)))


## A timber hoarding (a covered gallery hung out over the wall head on beams) and its roof; or for the
## rats, tin sheets; for the frogs a thatched cone over a reed screen.
func _crown_roof(scene: Node3D, o: Dictionary, at: Vector3, size: float, h: float, shape: String, roof: String) -> void:
	var wood := models.mats.get_mat("wood")
	var dark := Materials.flat(Color("#1e1a16"), 1.0)
	var r := size / 2.0 + 0.12
	var gal_h := 0.5
	var walls := models.mats.get_mat("tin" if o.get("scrap", false) else "weave" if o.get("rampart", false) else "wood")
	if shape == "round":
		scene.add_child(models.cyl(r, r, gal_h, walls, at + Vector3(0, h + gal_h / 2, 0), Vector3.ZERO, 28))
		for k in 10:   # beams under it
			var a := TAU * k / 10.0
			scene.add_child(models.box(Vector3(0.24, 0.06, 0.06), wood, at + Vector3(cos(a) * (r - 0.1), h - 0.04, sin(a) * (r - 0.1)), Vector3(0, -rad_to_deg(a), 0)))
		for k in 6:   # shooting windows
			var a := TAU * (k + 0.25) / 6.0
			scene.add_child(models.box(Vector3(0.02, 0.14, 0.18), dark, at + Vector3(cos(a) * (r + 0.005), h + gal_h * 0.55, sin(a) * (r + 0.005)), Vector3(0, -rad_to_deg(a), 0)))
		var rm := models.mats.get_mat(roof if roof != "" else "wood")
		scene.add_child(models.cyl(0.0, r + 0.12, r * 1.3, rm, at + Vector3(0, h + gal_h + r * 0.65, 0), Vector3.ZERO, 28))
	else:
		scene.add_child(models.box(Vector3(r * 2, gal_h, r * 2), walls, at + Vector3(0, h + gal_h / 2, 0)))
		for k in 5:
			var t := -r + (k + 0.5) * r * 2 / 5
			scene.add_child(models.box(Vector3(0.06, 0.06, r * 2 + 0.1), wood, at + Vector3(t, h - 0.04, 0)))
			scene.add_child(models.box(Vector3(0.16, 0.13, 0.02), dark, at + Vector3(t, h + gal_h * 0.55, r + 0.005)))
			scene.add_child(models.box(Vector3(0.02, 0.13, 0.16), dark, at + Vector3(r + 0.005, h + gal_h * 0.55, t)))
		var rm := models.mats.get_mat(roof if roof != "" else "wood")
		scene.add_child(models.cyl(0.0, (r + 0.15) * 1.414, r * 1.15, rm, at + Vector3(0, h + gal_h + r * 0.575, 0), Vector3(0, 45, 0), 4))


## A gatehouse: two towers either side of the passage, a block over the passage with the walkway across
## it (merlons front and back, or a hoarding), a deep arch, the gate leaves and a portcullis showing.
func _gatehouse(scene: Node3D, o: Dictionary, at: Vector3) -> void:
	var shape: String = o.gate[0]
	var ts: float = o.gate[1]
	var pw: float = o.gate[2]
	var gh: float = o.gate[3]
	var D: float = o.depth
	var H: float = o.walk
	var m := models.mats.get_mat(o.stone)
	var wood := models.mats.get_mat("wood")
	var dark := Materials.flat(Color("#141210"), 1.0)
	var iron := Materials.flat(Color("#3a3c40"), 0.5, 0.7)
	var deep := maxf(D, ts) + 0.2   # the passage block, a little proud of the wall front and back
	for side in [-1, 1]:
		var c := at + Vector3(side * (pw / 2 + ts / 2), 0, 0.3)   # the towers stand forward of the wall
		var tower_o: Dictionary = o.duplicate()
		tower_o.tower = [shape, ts, gh + 0.9, o.tower[3]]
		_tower(scene, tower_o, c, false)
	var top := H + 0.55
	scene.add_child(models.box(Vector3(pw + 0.1, top - 1.05, deep), m, at + Vector3(0, 1.05 + (top - 1.05) / 2, 0.15)))   # over the arch
	scene.add_child(models.box(Vector3(pw - 0.1, 1.05, 0.06), dark, at + Vector3(0, 0.52, 0.15 + deep / 2 - 0.2)))   # the dark passage behind the arch
	for x in range(-int(pw / 0.18) / 2, int(pw / 0.18) / 2 + 1):   # the portcullis, half raised
		scene.add_child(models.box(Vector3(0.035, 0.7, 0.035), iron, at + Vector3(x * 0.18, 0.75, 0.15 + deep / 2 - 0.12)))
	for y in [0.55, 0.85]:
		scene.add_child(models.box(Vector3(pw - 0.1, 0.035, 0.035), iron, at + Vector3(0, y, 0.15 + deep / 2 - 0.12)))
	for side in [-1, 1]:   # the leaves, swung back inside
		scene.add_child(models.box(Vector3(0.07, 1.0, pw / 2 - 0.05), wood, at + Vector3(side * (pw / 2 - 0.1), 0.5, 0.15 + deep / 2 - pw / 4 - 0.25)))
	if o.get("hoard", false):
		_crown_roof(scene, o, at + Vector3(0, 0, 0.15), maxf(pw, deep - 0.4), top, "square", o.tower[3])
	else:
		var n := int(pw / 0.5)
		for k in n:
			var x := -pw / 2 + (k + 0.5) * pw / n
			for z in [deep / 2 - 0.08, -deep / 2 + 0.08]:
				scene.add_child(models.box(Vector3(0.26, 0.32, 0.16), m, at + Vector3(x, top + 0.16, 0.15 + z)))
		# Machicolations: a corbelled gallery over the arch with drop holes (the pour comes from here).
		scene.add_child(models.box(Vector3(pw + 0.1, 0.12, 0.22), m, at + Vector3(0, top - 0.2, 0.15 + deep / 2 + 0.05)))
		for k in n * 2:
			var x := -pw / 2 + (k + 0.5) * pw / (n * 2)
			scene.add_child(models.box(Vector3(0.08, 0.2, 0.12), m, at + Vector3(x, top - 0.36, 0.15 + deep / 2 + 0.02)))
	var banner := at + Vector3(0, top - 0.25, 0.15 + deep / 2 + 0.17)
	scene.add_child(models.box(Vector3(0.5, 0.6, 0.02), models.cloth(team_def), banner + Vector3(0, -0.3, 0)))


# ------------------------------------------------------------------ the people

## Defenders up on the walkway (and a tower top), attackers at the foot. Positions on the walkway: near
## the outer parapet, so the merlons in front cover their legs.
func _people(scene: Node3D, o: Dictionary, walk: float) -> void:
	var D: float = o.get("depth", 0.54) if not o.get("real", false) else 0.54
	var zf := -0.42 - (0.25 if o.get("rampart", false) else 0.0)   # run A: by the outer parapet (the rampart: behind its stakes)
	var xf := zf
	if o.get("real", false):
		zf = -0.5 - 0.12
		xf = -0.5 - 0.12
	var A := [-11.0, -9.4, -4.6, -3.4, -2.6]
	for x in A:
		_put(scene, races.def, "archer", 3, Vector3(x, walk, zf + (0.0 if o.get("real", false) else 0.0)), team_def)
	for z in [-6.8, -5.6, -3.2, -2.2]:
		_put(scene, races.def, "archer" if int(z) % 2 == 0 else "skirmisher", 1, Vector3(xf, walk, z), team_def)
	if not o.get("real", false):   # the gatehouse's walk and a tower top
		_put(scene, races.def, "spear", 2, Vector3(GATE_X - 0.4, walk + 0.55, 0.3), team_def)
		_put(scene, races.def, "archer", 2, Vector3(GATE_X + 0.5, walk + 0.55, 0.3), team_def)
		var th: float = o.tower[2]
		_put(scene, races.def, "archer", 2, Vector3(-D * 0.5 + 0.3, th + 0.02, -D * 0.5 + 0.3), team_def)
	else:
		_put(scene, races.def, "archer", 2, Vector3(-0.5, Models.WALK_H.wall_tower, -0.5), team_def)
	# Attackers: at the gate, along the foot of run A and at the ladder.
	var out_a := 0.0 if o.get("real", false) else 0.0
	for p in [Vector2(GATE_X - 0.6, 1.4), Vector2(GATE_X + 0.4, 1.7), Vector2(GATE_X - 0.1, 2.3), Vector2(-8.6, 1.2), Vector2(-3.9, 1.5)]:
		_put(scene, races.att, "spear" if int(p.x) % 2 == 0 else "infantry", 7, Vector3(p.x, 0, p.y + out_a), team_att)
	for p in [Vector2(1.4, LADDER_Z + 0.7), Vector2(1.8, LADDER_Z - 0.6)]:
		_put(scene, races.att, "infantry", 5, Vector3(p.x, 0, p.y), team_att)


## Stand one unit of `race`'s line `slot` in the scene, facing `k` (0 right .. 2 towards .. 6 away),
## its feet at `at`: the game's own art on an upright card (it turns to face the camera about the
## vertical only, stretched by 1/cos 30 so it shows at its true size) with a soft shadow under it.
func _put(scene: Node3D, race: Dictionary, slot: String, k: int, at: Vector3, team: Color) -> void:
	var u := _unit_art(race, slot, k, team)
	var s := Sprite3D.new()
	s.texture = ImageTexture.create_from_image(u.img)
	s.pixel_size = 1.0 / (Baker.PX_PER_UNIT * UNIT_ZOOM)
	s.centered = true
	s.offset = Vector2(0, u.foot.y - u.img.get_height() / 2.0)   # (y up: the feet onto the node)
	s.offset.x = u.img.get_width() / 2.0 - u.foot.x
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.scale = Vector3(1, 1.0 / 0.8660254, 1)
	s.position = at
	scene.add_child(s)
	var sh := MeshInstance3D.new()   # a soft shadow on whatever it stands on
	var disc := CylinderMesh.new()
	disc.top_radius = 0.13
	disc.bottom_radius = 0.13
	disc.height = 0.005
	sh.mesh = disc
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.05, 0.04, 0.03, 0.4)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sh.material_override = sm
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sh.position = at + Vector3(0, 0.01, 0)
	sh.scale = Vector3(1.0, 1.0, 0.7)
	scene.add_child(sh)


const UNIT_ZOOM := 6.0   # the unit art rendered at 4x the bakes' 1.5 (pixel-sharp after the 4x supersample shrinks it)

## The game's unit art for one line in one facing: {img, foot} (foot: its ground point in the image).
func _unit_art(race: Dictionary, slot: String, k: int, team: Color) -> Dictionary:
	var key := "%s|%s|%d|%s" % [race.key, _slot(race, slot), k, team.to_html()]
	assert(units.has(key), "unit art not rendered first: %s (add it to ART)" % key)
	return units[key]


## Every unit art the scenes use: [side, slot, facing].
const ART := [["def", "archer", 3], ["def", "archer", 1], ["def", "archer", 2], ["def", "skirmisher", 1], ["def", "spear", 2],
	["att", "spear", 7], ["att", "infantry", 7], ["att", "infantry", 5]]

func _render_units() -> void:
	for a in ART:
		await _render_unit(races[a[0]], a[1], a[2], team_def if a[0] == "def" else team_att)


## The race's line for a slot, or the nearest it has (a race without bows sends its skirmishers).
func _slot(race: Dictionary, slot: String) -> String:
	for s in [slot, "skirmisher", "spear", "infantry"]:
		if race.units.any(func(x): return x.recipe.slot == s):
			return s
	return slot


func _render_unit(race: Dictionary, slot: String, k: int, team: Color) -> void:
	slot = _slot(race, slot)
	var key := "%s|%s|%d|%s" % [race.key, slot, k, team.to_html()]
	if units.has(key):
		return
	var found: Array = race.units.filter(func(x): return x.recipe.slot == slot)
	var step: Dictionary = found[0].line[mini(1, found[0].line.size() - 1)]
	var vp := SubViewport.new()
	vp.size = Vector2i(480, 480)
	vp.transparent_bg = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var v := UnitView.new()
	v.facing_k = k
	v.build(step.recipe, lib, team, step.eval.get("speed", 10))
	v.scale = Vector2.ONE * ArtKit.UNIT_SCALE * UNIT_ZOOM
	var foot := Vector2(240, 400)
	v.position = foot
	v.idle_wait = 1000.0
	vp.add_child(v)
	v._process(0.0)
	v.set_process(false)
	for f in 4:
		await process_frame
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	vp.queue_free()
	units[key] = {"img": img, "foot": foot}   # (its own ground shadow is in the art)
	if OS.has_environment("WALLS_W2_DEBUG"):
		img.save_png("/tmp/w2_unit_%s_%d.png" % [slot, k])


# ------------------------------------------------------------------ the attack

## The siege tower, docked against run A with its gangway down on the walkway (taller than the wall by a
## storey; hides on its sides, a fighting top), attackers on its top and gangway; a ladder against run B
## with a climber on it.
func _siege(scene: Node3D, o: Dictionary, walk: float) -> void:
	var real: bool = o.get("real", false)
	var D: float = 0.54 if real else o.depth
	var face := 0.0 if real else 0.0   # run A's outer face: z = 0 (real walls: the tile's edge, the wall's face at -0.23)
	var wood := models.mats.get_mat("wood")
	var dark := Materials.flat(Color("#3a2a1c"), 0.9)
	var hide := Materials.flat(Color("#8a6a48"), 0.95)
	var top: float = o.siege_tower if real else walk + 1.1   # its fighting top: two storeys over the walkway
	var bw := 0.75 if real else 1.5
	var front_z := (-0.23 if real else 0.0) + 0.12
	var c := Vector3(TOWER_SIEGE_X, 0, front_z + bw / 2 + 0.05)
	for x in [-1, 1]:   # wheels
		for z in [-1, 1]:
			scene.add_child(models.cyl(bw * 0.16, bw * 0.16, 0.08, wood, c + Vector3(x * bw * 0.38, bw * 0.16, z * (bw / 2 + 0.03)), Vector3(90, 0, 0), 14))
	var base := bw * 0.2
	for x in [-1, 1]:   # corner posts, leaning in a little
		for z in [-1, 1]:
			scene.add_child(models.beam(c + Vector3(x * bw * 0.48, base, z * bw * 0.48), c + Vector3(x * bw * 0.42, top + 0.3, z * bw * 0.42), 0.035, wood))
	var mid := (base + top) / 2
	for x in [-1, 1]:   # hides down both sides
		scene.add_child(models.box(Vector3(0.03, top - base, bw * 0.88), hide, c + Vector3(x * bw * 0.45, mid, 0)))
	scene.add_child(models.box(Vector3(bw * 0.88, top - base, 0.03), hide, c + Vector3(0, mid, bw * 0.45)))   # and the front (towards the camera)
	var floors := int((top - base) / 0.42)
	for k in floors:   # a cross brace over the hides on the front of every storey: it reads as a timber frame
		var y0 := base + k * (top - base) / floors
		var y1 := base + (k + 1) * (top - base) / floors
		for sx in [-1, 1]:
			scene.add_child(models.beam(c + Vector3(sx * bw * 0.42, y0, bw * 0.47), c + Vector3(-sx * bw * 0.42, y1, bw * 0.47), 0.022, wood))
	for k in range(1, floors + 1):   # storey frames
		var y := base + k * (top - base) / floors
		scene.add_child(models.box(Vector3(bw * 0.92, 0.04, 0.04), dark, c + Vector3(0, y, bw * 0.46)))
		for x in [-1, 1]:
			scene.add_child(models.box(Vector3(0.04, 0.04, bw * 0.92), dark, c + Vector3(x * bw * 0.46, y, 0)))
	scene.add_child(models.box(Vector3(bw * 0.9, 0.05, bw * 0.9), dark, c + Vector3(0, top, 0)))   # the fighting top
	for x in [-1, 1]:   # a wicker breastwork round it, open at the back (the wall side)
		scene.add_child(models.box(Vector3(0.04, 0.28, bw * 0.9), models.mats.get_mat("weave"), c + Vector3(x * bw * 0.45, top + 0.14, 0)))
	scene.add_child(models.box(Vector3(bw * 0.9, 0.28, 0.04), models.mats.get_mat("weave"), c + Vector3(0, top + 0.14, bw * 0.45)))
	# The gangway: down from the deck at the walkway's height onto the wall's walk.
	var g0 := c + Vector3(0, walk + 0.05, -bw / 2)
	var g1 := Vector3(c.x, walk + 0.03, -D * 0.35 if not real else -0.5)
	var gw := models.box(Vector3(bw * 0.6, 0.04, g0.distance_to(g1)), wood, (g0 + g1) / 2)
	scene.add_child(gw)
	scene.add_child(models.box(Vector3(0.04, 0.6, 0.04), wood, c + Vector3(-bw * 0.25, top + 0.3, bw * 0.25)))
	scene.add_child(models.box(Vector3(0.36, 0.22, 0.02), models.cloth(team_att), c + Vector3(-bw * 0.25 + 0.18, top + 0.48, bw * 0.25)))
	if not real:
		_put(scene, races.att, "infantry", 7, Vector3(c.x - 0.2, top + 0.03, c.z + 0.1), team_att)
		_put(scene, races.att, "spear", 7, Vector3(c.x + 0.15, walk + 0.06, (g0.z + g1.z) / 2), team_att)
	# The ladder against run B: from the ground out from the wall to just over the parapet.
	var bx := 0.0 if not real else -0.23
	var lh: float = walk + (0.3 if not real else 0.16)
	var foot := Vector3(bx + lh * 0.38, 0, LADDER_Z)
	var head := Vector3(bx + 0.02, lh, LADDER_Z)
	for z in [-0.16, 0.16]:
		scene.add_child(models.beam(foot + Vector3(0, 0, z), head + Vector3(0, 0, z), 0.025, wood))
	var rungs := int(lh / 0.16)
	for k in range(1, rungs):
		var p := foot.lerp(head, float(k) / rungs)
		scene.add_child(models.box(Vector3(0.025, 0.025, 0.34), wood, p))
	var on := foot.lerp(head, 0.55)
	_put(scene, races.att, "infantry", 5, on + Vector3(0.12, 0, 0), team_att)


# ------------------------------------------------------------------ output

## The bake on a grass ground, resized by `k` (1/1.5: the game's scale; 2: three times it).
func _on_grass(art: Image, k: float) -> Image:
	var img := art.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_LANCZOS if k < 1.0 else Image.INTERPOLATE_NEAREST)
	var out := Image.create(img.get_width() + 40, img.get_height() + 40, false, Image.FORMAT_RGBA8)
	out.fill(BG)
	out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(20, 20))
	return out


## Every option side by side at the game's scale, titled.
func _sheet(shots: Array, path: String) -> void:
	var cols := 2
	var cw := 0
	var ch := 0
	for s in shots:
		cw = maxi(cw, s[1].get_width())
		ch = maxi(ch, s[1].get_height())
	var rows := (shots.size() + cols - 1) / cols
	var vp := SubViewport.new()
	vp.size = Vector2i(cw * cols, (ch + 34) * rows)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = BG.darkened(0.25)
	bg.size = vp.size
	vp.add_child(bg)
	for i in shots.size():
		var at := Vector2((i % cols) * cw, (i / cols) * (ch + 34))
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(shots[i][1])
		tr.position = at + Vector2(0, 34)
		vp.add_child(tr)
		var l := Label.new()
		l.text = shots[i][0]
		l.position = at + Vector2(10, 6)
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", Color("#f4f1e8"))
		vp.add_child(l)
	for f in 8:
		await process_frame
	vp.get_texture().get_image().save_png(path)
	vp.queue_free()
