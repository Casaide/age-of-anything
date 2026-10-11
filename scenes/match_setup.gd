extends Control
## The match setup screen: pick your race and the AI's (type a prompt or press a preset),
## see what each prompt makes (the race's name and roster), pick a map, and play. The match
## runs in the game view with the AI on side 2. Also the way into the Race Lab.
## Run: godot --path . res://scenes/match_setup.tscn

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")

const PRESETS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans",
	"greek hoplites", "spooky beetle knights", "steppe horse archers", "forest spiders"]
const MAPS := ["flat_test", "choke_test"]
const BG := Color("#2e2820")
const GOLD := Color("#f2c94c")
const DIM := Color("#b8ad94")

var lib
var gen
var rules: Dictionary
var fields: Array = []      # LineEdit per side
var previews: Array = []    # Label per side
var map_pick: OptionButton


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	lib = DataLib.new()
	gen = Generator.new(lib)
	rules = DataLib.load_json("res://data/rules/default.json")
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)
	var title := Label.new()
	title.text = "Age of Whatever"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", GOLD)
	col.add_child(title)
	col.add_child(_dim("Describe a race. Anything goes; the game builds it and prices every unit fairly."))
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 40)
	sides.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(sides)
	for side in 2:
		sides.add_child(_side(side, ["You", "The AI"][side], PRESETS[side]))
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	col.add_child(bottom)
	bottom.add_child(_dim("Map"))
	map_pick = OptionButton.new()
	for m in MAPS:
		map_pick.add_item(m)
	bottom.add_child(map_pick)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	var lab := Button.new()
	lab.text = "Race Lab"
	lab.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/race_lab.tscn"))
	bottom.add_child(lab)
	var play := Button.new()
	play.text = "  Play  "
	play.add_theme_font_size_override("font_size", 24)
	play.pressed.connect(_play)
	bottom.add_child(play)


func _side(side: int, who: String, prompt: String) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	var head := Label.new()
	head.text = who
	head.add_theme_font_size_override("font_size", 26)
	head.add_theme_color_override("font_color", Color(lib.palettes.teams[side]))
	box.add_child(head)
	var field := LineEdit.new()
	field.text = prompt
	field.placeholder_text = "e.g. sewer rats with cheese hammers"
	field.add_theme_font_size_override("font_size", 20)
	field.text_changed.connect(func(_t): _preview(side))
	field.text_submitted.connect(func(_t): _play())
	box.add_child(field)
	fields.append(field)
	var presets := HFlowContainer.new()
	presets.add_theme_constant_override("h_separation", 6)
	presets.add_theme_constant_override("v_separation", 6)
	for p in PRESETS:
		var b := Button.new()
		b.text = p
		b.pressed.connect(func(): field.text = p; _preview(side))
		presets.add_child(b)
	box.add_child(presets)
	var preview := Label.new()
	preview.add_theme_font_size_override("font_size", 17)
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(preview)
	previews.append(preview)
	_preview(side)
	return box


func _dim(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", DIM)
	return l


## What the prompt makes: the race's name, its units through the ages, and the generator's notes.
func _preview(side: int) -> void:
	var race: Dictionary = gen.generate(fields[side].text, rules)
	var lines := ["%s  (%s)" % [race.name, lib.creatures[race.creature].plural]]
	for u in race.units:
		lines.append("  %s%s" % [u.recipe.name, "" if int(u.recipe.tier) <= 1 else "  (from age %d)" % int(u.recipe.tier)])
	for n in race.notes:
		lines.append("Note: " + n)
	previews[side].text = "\n".join(lines)


func _play() -> void:
	var view = load("res://scenes/sim_debug.tscn").instantiate()
	view.prompts = [fields[0].text, fields[1].text]
	view.map_id = MAPS[map_pick.selected]
	view.vs_ai = true
	get_tree().root.add_child(view)
	get_tree().current_scene = view
	queue_free()
