extends SceneTree
## Animation concepts (2026-10-12): options for how units move at work, rendered through the
## real rig and bakes at 3x, for Dominic to pick from (D-080: concepts first). Three sheets:
##   workers  W1 three arm poses (raise / low / reach, baked), W2 two (raise / low), W3 as now
##   centaur  C1 kneel (front legs fold, chest dips), C2 bow (whole body pitches), C3 as now
##   armless  A1 head-dig (head and body into the work), A2 pounce (the body rocks and hops), A3 as now
## Each row: five frames of the chop cycle, then one of foraging and one of building.
## Run (needs a display): godot --path . --script res://tests/anim_concept_sheet.gd -- out_dir

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const PartShape := preload("res://src/part_shape.gd")

const ZOOM := 4.0
const BG := Color("#56782e")
const HOLDS := ["reach", "raise"]

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
	var prompts := ["tiny vikings", "angry swamp frogs with reed spears", "centaur romans", "spooky beetle knights", "giant spiders"]
	var races := prompts.map(func(p): return gen.generate(p, rules))
	var team := Color(lib.palettes.teams[0])
	var teams := races.map(func(_r): return team)
	kit = ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	# Only the workers (every line of every unit would take minutes), their job tools, and the
	# extra holds for the two-armed ones (bakes the game doesn't have yet).
	var pb := PartBaker.new()
	pb.art_scale = ArtKit.ART_SCALE * ArtKit.UNIT_SCALE
	pb.bands = ArtKit.UNIT_BANDS
	root.add_child(pb)
	for r in races:
		var w: Dictionary = r.units[0]
		var probe := UnitView.new()
		probe.build(w.recipe, lib, team, w.eval.speed)
		for ps in probe.find_children("*", "Node2D", true, false):
			if ps is PartShape and ps.part_id != "":
				await pb.bake(ps.part_id, ps.shapes, ps.colours)
		probe.free()
		var colours := UnitView.colours_for(lib, w.recipe.skin, w.recipe.family, team)
		for id in ArtKit.JOB_PARTS:
			await pb.bake(id, lib.part(id).shapes, colours)
		if not w.recipe.has("mount"):
			for h in HOLDS:
				await pb.bake(w.recipe.body + "@" + h, lib.part(w.recipe.body).shapes, colours)
		print("baked ", r.name)
	pb.queue_free()
	PartShape.bake_flat("unit_shadow", UnitView.SHADOW_SHAPES, UnitView.SHADOW_COLOURS, ArtKit.ART_SCALE * ArtKit.UNIT_SCALE)
	kit.rebuild_atlas()
	await _sheet("workers", [races[0], races[1]], [
		["W1  three poses: raise, low, reach (baked arm)", _w1],
		["W2  two poses: raise, low", _w2],
		["W3  as now: the tool turns in a still hand", _now]])
	await _sheet("centaur", [races[2]], [
		["C1  kneel: front legs fold, chest dips, rider leans in", _c1],
		["C2  bow: the whole body pitches down to the work", _c2],
		["C3  as now", _now]])
	await _sheet("armless", [races[3], races[4]], [
		["A1  head-dig: head and body drive into the work", _a1],
		["A2  pounce: the body rocks back and lunges", _a2],
		["A3  as now", _now]])
	quit()


## One sheet: per race, per option a row of frames.
func _sheet(name: String, races: Array, options: Array) -> void:
	for k in races.size():
		await _sheet_one(name + ("" if races.size() == 1 else "_%d" % (k + 1)), races[k], options)


func _sheet_one(name: String, r: Dictionary, options: Array) -> void:
	for n in root.get_children():
		if n != kit:
			n.queue_free()
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(1600, 900)
	root.add_child(bg)
	var world := Node2D.new()
	world.scale = Vector2.ONE * ZOOM
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(world)
	var labels := Node2D.new()
	root.add_child(labels)
	var y := 70.0
	if true:
		var u: Dictionary = r.units[0]
		for opt in options:
			print("  row ", r.name, " ", opt[0])
			var l := Label.new()
			l.text = "%s   %s" % [r.name, opt[0]]
			l.position = Vector2(20, y - 60)
			l.add_theme_font_size_override("font_size", 16)
			labels.add_child(l)
			var frames := [["chop", 0], ["chop", 1], ["chop", 2], ["chop", 3], ["chop", 4], ["forage", 0], ["forage", 1], ["build", 0], ["build", 1]]
			for k in frames.size():
				var v := UnitView.new()
				v.build(u.recipe, lib, Color(lib.palettes.teams[0]), u.eval.speed)
				v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
				v.pose_steps = 0
				v.position = Vector2(70 + k * 120 + (30 if k >= 5 else 0) + (30 if k >= 7 else 0), y + 110) / ZOOM
				v.idle_wait = 1000.0
				v.time = 0.3
				v.set_tool(lib, {"chop": "tool.axe", "forage": "tool.basket", "build": "tool.hammer"}[frames[k][0]])
				world.add_child(v)
				v._process(0.0)
				opt[1].call(v, frames[k][0], frames[k][1])
				v._process(0.0)
				v.set_process(false)
			y += 175
	for f in 12:
		await process_frame
	var path := out_dir.path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


# ------------------------------------------------------------------ the options
# A frame: (view, job, index). Chop index 0..4 is wind-up, top, coming down, the blow, recover;
# forage 0 reach in / 1 lift; build 0 up / 1 knock.

func _now(v, job: String, f: int) -> void:
	v.job = job
	v.time = {"chop": [0.1, 0.45, 0.58, 0.66, 0.85], "forage": [0.55, 0.0], "build": [0.15, 0.38]}[job][f] * {"chop": 0.9, "forage": 1.1, "build": 0.5}[job]


func _w1(v, job: String, f: int) -> void:
	match job:
		"chop":
			v.set_hold(["raise", "raise", "low", "reach", "low"][f])
			v.concept = {"pitch": [-0.06, -0.08, 0.04, 0.14, 0.02][f], "tool": [-0.9, -1.2, 0.2, 0.9, 0.1][f], "drop": [0, 0, 0.5, 1.5, 0][f]}
		"forage":
			v.set_hold(["reach", "low"][f])
			v.concept = {"pitch": [0.16, 0.0][f], "drop": [2.0, 0.0][f], "tool": [0.3, -0.25][f], "tool_dy": [0.0, -1.0][f]}
		"build":
			v.set_hold(["raise", "reach"][f])
			v.concept = {"pitch": [-0.03, 0.08][f], "tool": [-0.9, 0.5][f], "drop": [0, 1][f]}


func _w2(v, job: String, f: int) -> void:
	match job:
		"chop":
			v.set_hold(["raise", "raise", "low", "low", "low"][f])
			v.concept = {"pitch": [-0.06, -0.08, 0.06, 0.14, 0.02][f], "tool": [-0.9, -1.2, 0.3, 0.6, 0.1][f], "drop": [0, 0, 0.5, 1.5, 0][f]}
		"forage":
			v.set_hold("low")
			v.concept = {"pitch": [0.18, 0.0][f], "drop": [2.5, 0.0][f], "tool": [0.4, -0.25][f], "tool_dx": [3.0, 0.0][f], "tool_dy": [4.0, -1.0][f]}
		"build":
			v.set_hold(["raise", "low"][f])
			v.concept = {"pitch": [-0.03, 0.08][f], "tool": [-0.8, 0.4][f], "drop": [0, 1][f]}


func _c1(v, job: String, f: int) -> void:
	v.job = ""
	match job:
		"chop":
			v.concept = {"kneel": [0.0, 0.0, 0.0, 0.0, 0.0][f] + 0.0, "pitch": [-0.05, -0.08, 0.05, 0.12, 0.0][f], "tool": [-0.9, -1.2, 0.2, 0.9, 0.1][f], "drop": [0, 0, 0.5, 1.5, 0][f]}
		"forage":
			v.concept = {"kneel": [1.0, 0.6][f], "tool": [0.5, -0.2][f], "tool_dy": [2.0, -1.0][f], "head": [0.2, 0.0][f]}
		"build":
			v.concept = {"kneel": [0.0, 0.0][f], "pitch": [-0.03, 0.1][f], "tool": [-0.9, 0.5][f]}
	if job == "chop":
		v.concept.kneel = 0.0


func _c2(v, job: String, f: int) -> void:
	v.job = ""
	match job:
		"chop":
			v.concept = {"pitch": [-0.06, -0.1, 0.1, 0.24, 0.02][f], "tool": [-0.9, -1.2, 0.2, 0.9, 0.1][f], "drop": [0, 0, 1.0, 2.5, 0][f]}
		"forage":
			v.concept = {"pitch": [0.3, 0.1][f], "drop": [3.0, 1.0][f], "tool": [0.5, -0.2][f], "tool_dy": [2.0, -1.0][f], "head": [0.25, 0.0][f]}
		"build":
			v.concept = {"pitch": [-0.03, 0.14][f], "tool": [-0.9, 0.5][f], "drop": [0, 1.5][f]}


func _a1(v, job: String, f: int) -> void:
	v.job = ""
	match job:
		"chop":
			v.concept = {"pitch": [-0.12, -0.18, 0.1, 0.26, 0.02][f], "head": [-0.5, -0.7, 0.3, 0.8, 0.0][f], "drop": [-1.0, -1.5, 1.0, 2.5, 0][f]}
		"forage":
			v.concept = {"pitch": [0.2, 0.0][f], "head": [0.7, -0.2][f], "drop": [2.0, 0.0][f]}
		"build":
			v.concept = {"pitch": [-0.08, 0.16][f], "head": [-0.4, 0.6][f], "drop": [-0.5, 1.5][f]}


func _a2(v, job: String, f: int) -> void:
	v.job = ""
	match job:
		"chop":
			v.concept = {"pitch": [-0.2, -0.3, 0.05, 0.2, 0.0][f], "drop": [-3.0, -5.0, 0.0, 2.0, 0][f], "head": [0.0, 0.0, 0.2, 0.5, 0.0][f]}
		"forage":
			v.concept = {"pitch": [0.12, -0.05][f], "drop": [1.5, -1.0][f], "head": [0.5, 0.0][f]}
		"build":
			v.concept = {"pitch": [-0.15, 0.1][f], "drop": [-3.0, 1.0][f], "head": [0.0, 0.3][f]}
