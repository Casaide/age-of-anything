extends Control
## The milestone 4 exit check: "blind testers predict counters from silhouettes".
## Shows two units side by side in the game's pixel art, with no names or stats, and
## how many of each cost the same. The tester presses 1 (left wins) or 2 (right wins).
## Each answer is checked against a real fight in the sim (equal cost, same race,
## both attack-moving), played headless before the question appears. The score goes
## on screen and to user://counter_quiz.json. Target: 75% right.
## Run: godot --path . res://scenes/counter_quiz.tscn
## Capture one question: godot --path . res://scenes/counter_quiz.tscn -- shot /tmp/quiz.png

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const Commands := preload("res://src/sim/commands.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")

const ART := 1.5 * 0.85
const ZOOM := 4
const QUESTIONS := 12
const PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans",
	"greek hoplites", "royal knights", "viking beetle riders", "steppe horse archers", "forest spiders"]
const SLOTS := ["spear", "skirmisher", "archer", "large"]
const BUDGET := 600
const LIMIT := 3000
const FROM := [[11000, 20500], [21000, 20500]]

var lib
var gen
var rules: Dictionary
var vp: SubViewport
var label: Label
var questions: Array = []   # {race, left, right, n_left, n_right, left_wins}
var at := 0
var right_answers := 0
var answers: Array = []
var shown: Array = []
var shot := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var args := OS.get_cmdline_user_args()
	if args.size() > 1 and args[0] == "shot":
		shot = args[1]
	lib = DataLib.new()
	gen = Generator.new(lib)
	rules = DataLib.load_json("res://data/rules/default.json")
	var box := SubViewportContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.stretch = true
	box.stretch_shrink = ZOOM
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(box)
	vp = SubViewport.new()
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	box.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = Vector2(2000, 2000)
	vp.add_child(bg)
	label = Label.new()
	label.position = Vector2(24, 18)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	label.text = "Setting up the fights..."
	await get_tree().process_frame
	await _prepare()
	_show()


## Pick the questions (seeded by the clock: every session differs; the fights are deterministic),
## fight each one headless, and bake the units' art.
func _prepare() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var races := {}
	while questions.size() < QUESTIONS:
		var prompt: String = PROMPTS[rng.randi() % PROMPTS.size()]
		if not races.has(prompt):
			races[prompt] = gen.generate(prompt, rules)
		var race: Dictionary = races[prompt]
		var a: String = SLOTS[rng.randi() % SLOTS.size()]
		var b: String = SLOTS[rng.randi() % SLOTS.size()]
		if a == b:
			continue
		var q := _fight(race, a, b)
		if q.is_empty():
			continue
		questions.append(q)
	var baker := PartBaker.new()
	baker.art_scale = ART
	add_child(baker)
	for q in questions:
		for slot in [q.left, q.right]:
			var probe := UnitView.new()
			var u: Dictionary = _unit(q.race, slot)
			probe.build(u.recipe, lib, Color(lib.palettes.teams[0]), u.eval.speed)
			for ps in probe.find_children("*", "Node2D", true, false):
				if ps is PartShape and ps.part_id != "":
					await baker.bake(ps.part_id, ps.shapes, ps.colours)
			probe.free()
	baker.queue_free()
	PartShape.bake_flat("unit_shadow", UnitView.SHADOW_SHAPES, UnitView.SHADOW_COLOURS, ART)
	PartShape.build_atlas()


## An equal-cost fight between two of a race's units. Empty if it's a draw.
func _fight(race: Dictionary, a: String, b: String) -> Dictionary:
	var bare := rules.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	var w := World.new(1, SimMap.load_id("flat_test"), [race, race], bare)
	var counts := []
	var value := []
	for p in 2:
		var e: Dictionary = _unit(race, [a, b][p]).eval
		var cost: int = int(e.cost.food) + int(e.cost.wood)
		var n := maxi(1, (BUDGET + cost / 2) / cost)
		counts.append(n)
		value.append(cost)
		w.issue(p, Commands.SPAWN, {"slot": [a, b][p], "count": n, "x": FROM[p][0], "y": FROM[p][1]})
	while w.units.count() == 0:
		w.step()
	for p in 2:
		var ids := []
		for i in w.units.count():
			if w.units.owner[i] == p:
				ids.append(w.units.id[i])
		w.issue(p, Commands.ATTACK_MOVE, {"ids": ids, "x": FROM[1 - p][0], "y": FROM[1 - p][1]})
	var left := [0, 0]
	while w.tick < LIMIT:
		w.step()
		left = [0, 0]
		for i in w.units.count():
			left[w.units.owner[i]] += 1
		if left[0] == 0 or left[1] == 0:
			break
	var va: int = left[0] * value[0]
	var vb: int = left[1] * value[1]
	if va == vb:
		return {}
	return {"race": race, "left": a, "right": b, "n_left": counts[0], "n_right": counts[1], "left_wins": va > vb}


func _unit(race: Dictionary, slot: String) -> Dictionary:
	for u in race.units:
		if u.recipe.slot == slot:
			return u
	return race.units[0]


func _show() -> void:
	for v in shown:
		v.queue_free()
	shown.clear()
	if at >= questions.size():
		_finish()
		return
	var q: Dictionary = questions[at]
	var size := get_viewport_rect().size / ZOOM
	for side in 2:
		var u: Dictionary = _unit(q.race, [q.left, q.right][side])
		var v := UnitView.new()
		v.style = "baked"
		v.build(u.recipe, lib, Color(lib.palettes.teams[side]), u.eval.speed)
		v.scale = Vector2(ART, ART)
		v.position = Vector2(size.x * (0.3 + side * 0.4), size.y * 0.62)
		v.face(1.0 if side == 0 else -1.0)
		vp.add_child(v)
		shown.append(v)
		var n := Label.new()
		n.text = "x %d" % [q.n_left, q.n_right][side]
		n.add_theme_font_size_override("font_size", 8)
		n.position = v.position + Vector2(-8, 10)
		vp.add_child(n)
		shown.append(n)
	label.text = "Question %d of %d.  Same cost on each side.  Which side wins?\n1 = left (blue)    2 = right (red)\nScore so far: %d / %d" % [at + 1, questions.size(), right_answers, at]
	if shot != "":
		for f in 10:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(shot)
		print("saved ", shot)
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or at >= questions.size():
		return
	if event.keycode != KEY_1 and event.keycode != KEY_2:
		return
	var q: Dictionary = questions[at]
	var said_left: bool = event.keycode == KEY_1
	var ok: bool = said_left == q.left_wins
	if ok:
		right_answers += 1
	answers.append({"race": q.race.name, "left": q.left, "right": q.right, "n_left": q.n_left, "n_right": q.n_right,
		"left_wins": q.left_wins, "answer": "left" if said_left else "right", "right_answer": ok})
	at += 1
	_show()


func _finish() -> void:
	var pct := right_answers * 100 / maxi(1, questions.size())
	label.text = "Done: %d of %d right (%d%%). Target: 75%%.\nSaved to user://counter_quiz.json" % [right_answers, questions.size(), pct]
	var f := FileAccess.open("user://counter_quiz.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"score": right_answers, "of": questions.size(), "answers": answers}, " "))
	print("Counter quiz: %d / %d (%d%%) -> %s" % [right_answers, questions.size(), pct, ProjectSettings.globalize_path("user://counter_quiz.json")])
