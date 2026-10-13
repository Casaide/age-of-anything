extends Control
## The lobby, the game's front door. A title screen (the two rolled armies facing each other on
## a hill under the title; battle the AI, the Race Lab, quit) leads to the battle setup: two side
## panels (you and the AI), each wearing its race's culture (src/view/ui/theme.gd: the frame,
## crest and banner of data/families.json's `ui` block), with the race's name on its banner, its
## army idling on a lit stage, the dice and the prompt, the roster as cards (portrait, role,
## cost) and the generator's notes; in the middle a cast "vs", the map card, the AI's level and
## Start. The match runs in the game view with the AI on side 2 and comes back here when it ends.
## Each banner's "Tech tree" button opens that race's tech tree page (scenes/tech_tree.tscn).
## Everything has a fixed size, so nothing moves when a race or map changes (Dominic).
## A map with more than two starts is a team game: a panel per player in two teams (you and an
## AI ally against two AIs), each with its own dice, prompt and AI level, all rolled on entry.
## Run: godot --path . res://scenes/match_setup.tscn

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const UnitView := preload("res://src/unit_view.gd")
const Icons := preload("res://src/view/art/icons.gd")
const Audio := preload("res://src/view/audio.gd")
const UiScale := preload("res://src/view/ui_scale.gd")
const UiTheme := preload("res://src/view/ui/theme.gd")
const Mat := preload("res://src/view/ui/ui_materials.gd")
const DiceButton := preload("res://src/view/loaders/dice_button.gd")
const ForgeVeil := preload("res://src/view/loaders/forge_veil.gd")
const LoaderStyle := preload("res://src/view/loaders/loader_style.gd")

const NOT_MAPS := ["choke_test", "river_test", "hill_test"]   # test maps (sim_debug lists them)
var MAPS := _maps()   # every map in data/maps: the real ones first (by name), the test maps last
const LEVELS := ["Easy", "Normal", "Hard"]

const BASE := 20                 # the lobby's body type in UI pixels (Dominic: "text is all too small")
const DESIGN := Vector2(1600, 950)   # the lobby is laid out for this and scaled to fill the window
const CENTRE_W := 420
const BANNER_H := 96
const STAGE_H := 144
const CARD_H := 72
const NOTES_H := 70
const MENU_STAGE_H := 270
const MENU_ZOOM := 3.0           # the title screen's armies, bigger
const STAGE_ZOOM := 2.0          # screen pixels per canvas unit on the preview stage
const BAKE_AFTER := 0.6          # seconds of no typing before a prompt is re-baked
const GRASS := Color("#4e6e2a")

var lib
var gen
var rules: Dictionary
var kit: ArtKit
var baking := false
var menu: Control
var setup: Control
var sides: Array = []           # per side: {field, dice, reroll, race, name, line, roster, units, stage, vp, layer, status, dirty_at, team, panel, banner, family}
var map_index := 0
var map_name: Label
var map_pic: TextureRect
var map_note: Label
var map_data: Dictionary        # the map picked (its starts say how many players)
var level_card: Control         # 1v1: how hard the AI plays (in a team game each AI panel has its own)
var level_buttons: Array = []
var left_col: VBoxContainer     # your team's panels
var right_col: VBoxContainer    # the other team's
var tree_page: Control          # the tech tree page, over everything while open
var menu_layer: Node2D          # the title screen's hill, both armies on it
var menu_stage: SubViewportContainer
var _themes := {}               # family -> Theme (themes are built once per culture)


func _ready() -> void:
	UiScale.fit_window(get_window())   # big enough to read on a Retina screen (src/view/ui_scale.gd)
	get_window().size_changed.connect(_rescale)
	_rescale()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	lib = DataLib.new()
	gen = Generator.new(lib)
	rules = DataLib.load_json("res://data/rules/default.json")
	kit = ArtKit.new()
	kit.lib = lib
	add_child(kit)
	theme = _theme("")
	add_child(_backdrop())
	menu = _menu()
	add_child(menu)
	setup = _setup()
	setup.visible = false
	add_child(setup)
	UiTheme.juice_all(self)
	var audio := Audio.of(get_tree())
	audio.ambience(false)
	audio.music("lobby")


## The lobby is a designed screen: laid out at DESIGN and scaled to fill the window; the UI-size
## setting takes it from 76% of that (at 40%) to all of it (at 100%), so it always reads at a
## glance (Dominic: "text is all too small on the lobby") and the size steps still do something.
func _rescale() -> void:
	var px := Vector2(get_window().size)
	var fill := minf(px.x / DESIGN.x, px.y / DESIGN.y)
	get_window().content_scale_factor = maxf(1.0, fill * (0.6 + 0.4 * UiScale.size_pct() / 100.0))


## Cmd/Ctrl + minus / plus: the UI a step smaller or larger (saved).
func _unhandled_key_input(event: InputEvent) -> void:
	var d := UiScale.key_step(event)
	if d != 0:
		UiScale.step(d)
		_rescale()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for i in sides.size():
		if sides[i].dirty_at > 0.0 and now - sides[i].dirty_at > BAKE_AFTER and not baking:
			sides[i].dirty_at = 0.0
			_bake(i)


func _theme(family: String) -> Theme:
	if not _themes.has(family):
		_themes[family] = UiTheme.theme(UiTheme.look(family), BASE)
	return _themes[family]


## A dark table under everything: wood, darkening to the corners.
func _backdrop() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wood := TextureRect.new()
	wood.texture = Mat.texture("wood", Color("#2a1c12"))
	wood.stretch_mode = TextureRect.STRETCH_TILE
	wood.set_anchors_preset(Control.PRESET_FULL_RECT)
	wood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wood)
	var vignette := TextureRect.new()
	vignette.texture = _vignette()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vignette)
	return root


# ------------------------------------------------------------------ the title screen

func _menu() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The hill along the bottom: your army and the AI's, facing each other.
	menu_stage = SubViewportContainer.new()
	menu_stage.stretch = true
	menu_stage.anchor_left = 0.0
	menu_stage.anchor_right = 1.0
	menu_stage.anchor_top = 1.0
	menu_stage.anchor_bottom = 1.0
	menu_stage.offset_top = -MENU_STAGE_H
	menu_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	menu_stage.add_child(vp)
	var hill := TextureRect.new()   # turf, rising out of the dark
	hill.texture = Mat.texture("felt", GRASS.darkened(0.25))
	hill.stretch_mode = TextureRect.STRETCH_TILE
	hill.size = Vector2(4000, MENU_STAGE_H)
	vp.add_child(hill)
	var fade := TextureRect.new()
	fade.texture = _hill()
	fade.size = Vector2(4000, MENU_STAGE_H)
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	vp.add_child(fade)
	menu_layer = Node2D.new()
	menu_layer.y_sort_enabled = true
	menu_layer.scale = Vector2.ONE * MENU_ZOOM
	vp.add_child(menu_layer)
	var melt := ShaderMaterial.new()   # the hill melts into the table at its top and its ends: a pool of light, no edges
	melt.shader = Shader.new()
	melt.shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV) * COLOR;\n\tc.a *= smoothstep(0.0, 0.3, UV.y) * smoothstep(0.0, 0.24, UV.x) * smoothstep(1.0, 0.76, UV.x);\n\tCOLOR = c;\n}\n"
	menu_stage.material = melt
	menu_stage.resized.connect(func(): hill.size.x = menu_stage.size.x; fade.size.x = menu_stage.size.x; _muster_menu())
	root.add_child(menu_stage)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.offset_bottom = -MENU_STAGE_H * 0.55
	root.add_child(centre)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(col)
	var crest := TextureRect.new()
	crest.texture = UiTheme.crest_texture(UiTheme.look(""))
	crest.custom_minimum_size = Vector2(300, 90)
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(crest)
	var title := UiTheme.label("Age of Anything", "Title")
	title.add_theme_font_size_override("font_size", 104)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_constant_override("shadow_offset_y", 7)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var tag := UiTheme.label("Your civilisation is whatever you can describe.", "Dim")
	tag.add_theme_font_size_override("font_size", 26)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size.y = 26
	col.add_child(gap)
	var plaque := PanelContainer.new()
	plaque.theme_type_variation = "Frame"
	plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(plaque)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	plaque.add_child(buttons)
	for item in [["Battle the AI", func(): _open_setup()], ["Race Lab", func(): get_tree().change_scene_to_file("res://scenes/race_lab.tscn")],
			["Quit", func(): get_tree().quit()]]:
		var primary: bool = item[0] == "Battle the AI"
		var b := UiTheme.button(item[0], primary)
		b.custom_minimum_size = Vector2(400, 88 if primary else 62)
		if not primary:
			b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(item[1])
		buttons.add_child(b)
	var foot := UiTheme.label("Type \"centaur romans\" or \"sewer rats with cheese hammers\": the game builds the race and prices every unit fairly.", "Dim", true)
	foot.custom_minimum_size.x = 640
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 10
	col.add_child(gap2)
	col.add_child(foot)
	return root


func _open_setup() -> void:
	menu.visible = false
	setup.visible = true
	UiTheme.arrive(setup.get_child(0))
	Audio.of(get_tree()).play("ui_tip")


## Both armies on the title screen's hill: yours from the left, the AI's from the right.
func _muster_menu() -> void:
	if menu_layer == null:
		return
	for n in menu_layer.get_children():
		n.queue_free()
	var w: float = menu_stage.size.x / MENU_ZOOM
	if w <= 0.0 or kit.icons.is_empty():
		return
	for i in sides.size():
		var s: Dictionary = sides[i]
		if s.race.is_empty():
			continue
		var units: Array = s.race.units
		for k in units.size():
			var u: Dictionary = units[units.size() - 1 - k]   # the big ones at the front
			var view := UnitView.new()
			view.build(u.recipe, lib, s.team, u.eval.speed)
			view.scale = Vector2.ONE * ArtKit.UNIT_SCALE
			view.pose_steps = 8
			view.art_px = ArtKit.ART_SCALE / MENU_ZOOM
			var x := w * (0.42 - 0.055 * k) if i == 0 else w * (0.58 + 0.055 * k)
			view.position = Vector2(x, MENU_STAGE_H / MENU_ZOOM * (0.7 if k % 2 == 0 else 0.86))
			view.face(1.0 if i == 0 else -1.0)
			menu_layer.add_child(view)


# ------------------------------------------------------------------ the battle setup

func _setup() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 22)
	root.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)   # room for the crests on the panels' top edges
	margin.add_child(col)
	var head := HBoxContainer.new()
	head.custom_minimum_size.y = 56
	var back := UiTheme.button("Menu")
	back.icon = Icons.texture("back")
	back.add_theme_constant_override("icon_max_width", 22)
	back.custom_minimum_size = Vector2(150, 48)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): setup.visible = false; menu.visible = true; UiTheme.arrive(menu))
	head.add_child(back)
	var title := UiTheme.label("Prepare for Battle", "Title")
	title.add_theme_font_size_override("font_size", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var balance := Control.new()   # the back button's twin, so the title sits in the middle
	balance.custom_minimum_size.x = 150
	head.add_child(balance)
	col.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	left_col = VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 30)   # room for the lower panel's crest
	row.add_child(left_col)
	row.add_child(_centre())
	right_col = VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 30)
	row.add_child(right_col)
	_set_map(0)   # the map says how many sides: their panels are made (and rolled) there
	return root


## Which team player i of n is on: the map's "teams" (a team per start, as the sim reads it:
## SimMap.start_teams), else the first half against the second; 1v1 is each for themselves.
func _team_of(i: int, n: int) -> int:
	var teams: Array = map_data.get("teams", [])
	if i < teams.size():
		return int(teams[i])
	return i if n <= 2 else (0 if i < n / 2 else 1)


## A panel per player: your team on the left, the other on the right; compact when there are
## more than two. What was typed, rolled and picked for a player carries over when the map
## changes; new players are rolled.
func _build_sides(n: int) -> void:
	var keep := []
	for s in sides:
		keep.append({"text": s.field.text, "rolled": s.rolled, "reroll": s.reroll, "level": s.level})
	for c in left_col.get_children() + right_col.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	sides.clear()
	var compact := n > 2
	for i in n:
		var t := _team_of(i, n)
		var who := "You" if i == 0 else ("Your ally (AI)" if t == _team_of(0, n) else "The AI")
		var panel := _side_panel(i, who, compact)
		sides[i].side_team = t
		(left_col if t == _team_of(0, n) else right_col).add_child(panel)
	for i in n:
		if i < keep.size():
			sides[i].field.text = keep[i].text
			sides[i].rolled = keep[i].rolled
			sides[i].reroll = keep[i].reroll
			sides[i].level = keep[i].level
			_regenerate(i)
		else:
			_roll(i)
	level_card.visible = not compact
	for k in level_buttons.size():
		level_buttons[k].set_pressed_no_signal(n > 1 and k == sides[1].level)


## The middle: the cast "vs", the map card, the AI's level, and Start.
func _centre() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = CENTRE_W   # fixed: a longer map name mustn't push the banners about (Dominic)
	col.add_theme_constant_override("separation", 18)
	var vs := UiTheme.Medallion.new()
	vs.lk = UiTheme.look("")
	vs.custom_minimum_size = Vector2(0, 104)
	col.add_child(vs)
	var card := PanelContainer.new()
	card.theme_type_variation = "CrestFrame"
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	card.add_child(inner)
	var cap := UiTheme.label("BATTLEFIELD", "Caption")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(cap)
	var pick := HBoxContainer.new()
	pick.add_theme_constant_override("separation", 8)
	var prev := UiTheme.button("<")
	prev.custom_minimum_size = Vector2(46, 46)
	prev.pressed.connect(func(): _set_map(map_index - 1))
	pick.add_child(prev)
	map_name = UiTheme.label("", "Heading")
	map_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_name.clip_text = true
	map_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pick.add_child(map_name)
	var next := UiTheme.button(">")
	next.custom_minimum_size = Vector2(46, 46)
	next.pressed.connect(func(): _set_map(map_index + 1))
	pick.add_child(next)
	inner.add_child(pick)
	var well := PanelContainer.new()
	well.theme_type_variation = "Well"
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL   # the map takes the room a tall window spares
	inner.add_child(well)
	map_pic = TextureRect.new()
	map_pic.custom_minimum_size = Vector2(0, 196)   # Dominic: the map needs more room
	map_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	well.add_child(map_pic)
	map_note = UiTheme.label("", "Dim")
	map_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(map_note)
	var level := PanelContainer.new()   # how hard the AI plays: three buttons, one lit
	level.theme_type_variation = "Card"
	level_card = level
	col.add_child(level)
	var lcol := VBoxContainer.new()
	lcol.add_theme_constant_override("separation", 6)
	level.add_child(lcol)
	var lcap := UiTheme.label("THE AI PLAYS", "Caption")
	lcap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lcol.add_child(lcap)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 8)
	lcol.add_child(lrow)
	var group := ButtonGroup.new()
	for k in LEVELS.size():
		var b := UiTheme.button(LEVELS[k])
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = k == 0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 46
		b.toggled.connect(func(on): if on and sides.size() > 1: sides[1].level = k)
		lrow.add_child(b)
		level_buttons.append(b)
	var start := UiTheme.button("Start Battle", true)
	start.custom_minimum_size = Vector2(0, 100)
	start.add_theme_font_size_override("font_size", 40)
	start.pressed.connect(_play)
	col.add_child(start)
	var breathe := start.create_tween().set_loops()   # Start breathes: the screen's call to arms
	breathe.set_trans(Tween.TRANS_SINE)
	breathe.tween_property(start, "self_modulate", Color(1.12, 1.08, 1.0), 1.4)
	breathe.tween_property(start, "self_modulate", Color.WHITE, 1.4)
	var hint := UiTheme.label("Esc in battle: pause and menu", "Dim")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	return col


## One side's panel, in its race's culture: who it is and the tech tree, the race's banner,
## its army on a lit stage, the dice and the prompt, the roster as cards, the notes. Compact (a
## team game, two panels a column): a smaller banner and stage, the roster as portraits (their
## names and costs on hover), the notes on the banner's hover, an AI's level in its top row.
func _side_panel(i: int, who: String, compact := false) -> Control:
	var team := Color(lib.palettes.teams[i])
	var card := PanelContainer.new()
	card.theme_type_variation = "CrestFrame"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL   # two to a column share it; the stages take the slack
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 9)
	card.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var gem := TeamGem.new()   # the side's colour: one quiet mark
	gem.colour = team
	gem.custom_minimum_size = Vector2(18, 18)
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(gem)
	var whol := UiTheme.label(who.to_upper(), "Caption")
	whol.add_theme_font_size_override("font_size", 17)
	whol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	whol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(whol)
	if compact and i > 0:   # this AI's level, in its own panel
		var group := ButtonGroup.new()
		for k in LEVELS.size():
			var lb := UiTheme.button(LEVELS[k])
			lb.toggle_mode = true
			lb.button_group = group
			lb.button_pressed = k == 0
			lb.add_theme_font_size_override("font_size", 15)
			lb.custom_minimum_size = Vector2(0, 38)
			lb.toggled.connect(func(on): if on: sides[i].level = k)
			top.add_child(lb)
	var tree_b := UiTheme.button("Tech tree")
	tree_b.icon = Icons.texture("research")
	tree_b.add_theme_constant_override("icon_max_width", 22)
	tree_b.add_theme_font_size_override("font_size", 16 if compact else 18)
	tree_b.tooltip_text = "Everything this race can build, train and research, and its bonuses"
	tree_b.pressed.connect(func(): _open_tree(i))
	top.add_child(tree_b)
	col.add_child(top)
	var banner := PanelContainer.new()
	banner.custom_minimum_size.y = 72 if compact else BANNER_H
	var bcol := VBoxContainer.new()
	bcol.add_theme_constant_override("separation", -2)
	banner.add_child(bcol)
	var name := UiTheme.label("", "Title")
	name.add_theme_font_size_override("font_size", 30 if compact else 42)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bcol.add_child(name)
	var line := UiTheme.label("", "Name")
	line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	line.add_theme_constant_override("outline_size", 5)
	bcol.add_child(line)
	col.add_child(banner)
	# The stage: the army idling on grass, lit from above, sunk in the panel.
	var well := PanelContainer.new()
	well.theme_type_variation = "Well"
	well.add_theme_stylebox_override("panel", _stage_well())
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL   # the stage takes what the window spares
	col.add_child(well)
	var stage := SubViewportContainer.new()
	stage.custom_minimum_size = Vector2(0, 84 if compact else STAGE_H)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.stretch = true
	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	stage.add_child(vp)
	var ground := TextureRect.new()
	ground.texture = Mat.texture("felt", GRASS)   # close-cropped turf
	ground.stretch_mode = TextureRect.STRETCH_TILE
	ground.size = Vector2(2000, 1000)
	vp.add_child(ground)
	var shade := TextureRect.new()   # the grass darkens towards the back and the sides; a pool of light in the middle
	shade.texture = _stage_light()
	shade.size = Vector2(2000, STAGE_H)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	vp.add_child(shade)
	stage.resized.connect(func():
		shade.size = stage.size
		if not baking and not kit.icons.is_empty():
			_muster(i))
	var layer := Node2D.new()
	layer.y_sort_enabled = true
	layer.scale = Vector2.ONE * STAGE_ZOOM
	vp.add_child(layer)
	var stage_box := Control.new()   # the stage, and over it the veil shown while a new army is forged
	stage_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_box.add_child(stage)
	var veil := ForgeVeil.new()
	stage_box.add_child(veil)
	well.add_child(stage_box)
	var status := UiTheme.label("", "Dim")   # over the stage's foot
	status.add_theme_font_size_override("font_size", 15)
	status.add_theme_color_override("font_color", Color("#f4ecd4", 0.85))
	status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	status.add_theme_constant_override("outline_size", 4)
	status.size_flags_vertical = Control.SIZE_SHRINK_END
	status.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.visible = not compact
	well.add_child(status)
	# The dice, then the prompt (Dominic: the dice is the main thing; every side starts rolled,
	# the box starts empty, no menu of presets).
	var prompt := HBoxContainer.new()
	prompt.add_theme_constant_override("separation", 10)
	col.add_child(prompt)
	var dice := DiceButton.new()   # tumbles when thrown, rocks until the race is made
	dice.custom_minimum_size = Vector2.ONE * (54 if compact else 68)
	dice.focus_mode = Control.FOCUS_NONE
	dice.tooltip_text = "Roll the dice: a new race (with words in the box, another roll of those words)"
	dice.pressed.connect(func(): dice.tumble(); _roll(i))
	UiTheme.juice(dice)
	prompt.add_child(dice)
	var field := LineEdit.new()
	field.placeholder_text = "...or describe your race"
	field.custom_minimum_size = Vector2(0, 54 if compact else 68)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.add_theme_font_size_override("font_size", 22 if compact else 28)
	field.text_changed.connect(func(_t): sides[i].reroll = 0; _regenerate(i))
	field.text_submitted.connect(func(_t): _regenerate(i))   # Enter shows the race; only Start starts (Fable)
	prompt.add_child(field)
	var units := GridContainer.new()   # the roster as cards: portrait, name, role and cost
	units.columns = 6 if compact else 2
	units.add_theme_constant_override("h_separation", 8 if compact else 10)
	units.add_theme_constant_override("v_separation", 8)
	units.custom_minimum_size.y = 54 if compact else CARD_H * 3 + 16
	col.add_child(units)
	var roster := RichTextLabel.new()   # the generator's notes
	roster.bbcode_enabled = true
	roster.scroll_active = false
	roster.clip_contents = true
	roster.custom_minimum_size.y = NOTES_H
	roster.add_theme_font_size_override("normal_font_size", 16)
	roster.add_theme_font_size_override("italics_font_size", 16)
	roster.add_theme_constant_override("line_separation", -2)
	roster.add_theme_color_override("default_color", Color("#e8d8a8"))
	col.add_child(roster)
	roster.visible = not compact
	sides.append({"field": field, "dice": dice, "reroll": 0, "rolled": "", "race": {}, "name": name, "line": line, "roster": roster, "units": units,
		"stage": stage, "vp": vp, "layer": layer, "status": status, "dirty_at": 0.0, "team": team, "panel": card, "banner": banner, "family": "?",
		"level": 0, "side_team": i, "compact": compact, "veil": veil, "forging": false})
	return card


## The side's colour as a small cut gem (the one team mark on its panel).
class TeamGem extends Control:
	var colour := Color.WHITE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.0
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		draw_colored_polygon(pts, colour.darkened(0.25))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c, c + Vector2(-r, 0)]), colour.lightened(0.15))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.6), c + Vector2(r * 0.35, -r * 0.15), c + Vector2(-r * 0.2, -r * 0.1)]), Color(1, 1, 1, 0.5))
		pts.append(pts[0])
		draw_polyline(pts, Color(0, 0, 0, 0.7), 1.2, true)


## A side's panel takes its race's culture: its theme (frame, crest, buttons, cards) and banner.
func _dress(i: int) -> void:
	var s: Dictionary = sides[i]
	var fam: String = s.race.family
	if s.family == fam:
		return
	s.family = fam
	s.panel.theme = _theme(fam)
	s.banner.add_theme_stylebox_override("panel", UiTheme.banner_box(UiTheme.look(fam), s.team))


func _stage_well() -> StyleBox:
	var b: StyleBox = UiTheme.well_box(UiTheme.look(""))
	b.content_margin_left = 3
	b.content_margin_right = 3
	b.content_margin_top = 3
	b.content_margin_bottom = 3
	return b


## The words a side's race comes from: what's typed, else what the dice rolled.
func _prompt(i: int) -> String:
	var typed: String = sides[i].field.text.strip_edges()
	return typed if typed != "" else sides[i].rolled


## The dice: with the box empty, a new race from random words; with words typed, another roll
## of those words. Lobby-only randomness: the match gets the words and the roll, as ever.
func _roll(i: int) -> void:
	if sides[i].field.text.strip_edges() != "":
		sides[i].reroll += 1
	else:
		sides[i].rolled = _random_words()
		sides[i].reroll = randi() % 4
	_regenerate(i)


## A race's worth of words from the lexicon: maybe a culture, a creature, maybe "with" some kit.
func _random_words() -> String:
	var creatures := []
	var cultures := []
	var kit_words := []
	for w in lib.lexicon:
		var e: Dictionary = lib.lexicon[w]
		if e.has("creature") and w.ends_with("s") and lib.creatures.get(e.creature, {}).get("playable", false):
			creatures.append(w)
		elif e.has("family") and not e.has("creature"):
			cultures.append(w)
		elif e.keys().size() == 1 and e.has("tags"):
			kit_words.append(w)
	creatures.sort()
	cultures.sort()
	kit_words.sort()
	var words := []
	if randi() % 3 != 0:
		words.append(cultures[randi() % cultures.size()])
	words.append(creatures[randi() % creatures.size()])
	if randi() % 2 == 0:
		words.append("with " + kit_words[randi() % kit_words.size()])
	return " ".join(words)


## A prompt changed: the name and roster at once (generation is instant), the army after a pause.
func _regenerate(i: int) -> void:
	var s: Dictionary = sides[i]
	var race: Dictionary = gen.generate(_prompt(i), rules, s.reroll)
	s.race = race
	_dress(i)
	s.name.text = race.name
	s.line.text = "%s  ·  %s culture" % [lib.creatures[race.creature].plural, String(race.family).capitalize()]
	for n in s.units.get_children():
		s.units.remove_child(n)
		n.queue_free()
	for u in race.units:
		s.units.add_child(_unit_chip(u) if s.compact else _unit_card(u))
	var lines := []
	for n in race.notes:
		lines.append("[i]%s[/i]" % n)
	s.roster.text = "\n".join(lines)
	s.roster.tooltip_text = "\n".join(race.notes)
	s.banner.tooltip_text = "\n".join(race.notes)
	s.status.text = "  Forging the army..."
	s.dirty_at = Time.get_ticks_msec() / 1000.0
	_forging(i)


## A side's army is being made (typed, rolled, baking): the old one dims under the forge veil
## and the dice rocks, until _muster stands the new one up.
func _forging(i: int) -> void:
	var s: Dictionary = sides[i]
	s.dice.busy = true
	if s.forging:
		return
	s.forging = true
	s.veil.show_veil()
	_fade_army(s, LoaderStyle.DIM_ARMY, 0.2)


func _fade_army(s: Dictionary, to: float, secs: float) -> void:
	if s.has("tween"):
		s.tween.kill()
	s.tween = s.layer.create_tween()
	s.tween.tween_property(s.layer, "modulate:a", to, secs)


## Bake a side's army (the kit skips parts it has) and stand it on the stage.
func _bake(_i: int) -> void:
	baking = true
	var t0 := Time.get_ticks_msec()
	var races := []
	var teams := []
	for s in sides:
		if not s.race.is_empty():
			races.append(s.race)
			teams.append(s.team)
	await kit.prepare_units(races, teams)
	await kit.bake_icons(races, teams)
	print("Lobby bake: %d ms" % (Time.get_ticks_msec() - t0))
	baking = false
	for k in sides.size():   # the atlas was rebuilt: every stage redraws from it
		_muster(k)
	_muster_menu()
	if races.size() == sides.size() and sides.all(func(s): return s.dirty_at == 0.0):
		kit.warm(races)   # while the players choose, bake the match's buildings and props


## The few that show off a race on the stage, a line each, in this order while there's room (the
## whole roster, siege and all, crowded into a heap: Dominic, "we squeeze too much, be selective").
const STAGE_ROLES := ["spear", "infantry", "archer", "large", "skirmisher", "worker", "catapult", "healer"]


static func _stage_pick(units: Array, room: int) -> Array:
	var out := []
	for role in STAGE_ROLES:
		if out.size() >= clampi(room, 3, 6):
			break
		for u in units:
			if u.recipe.get("role", "") == role:
				out.append(u)
				break
	return out


func _muster(i: int) -> void:
	var s: Dictionary = sides[i]
	if s.dirty_at > 0.0:   # its new race isn't baked yet: the old army stays under the veil, redrawn from the new atlas
		for ps in s.layer.find_children("*", "Node2D", true, false):
			ps.queue_redraw()
		return
	for n in s.layer.get_children():
		n.queue_free()
	if s.race.is_empty():
		return
	var zoom := 3.0 if s.stage.size.y >= STAGE_H * 1.45 else STAGE_ZOOM   # a tall stage (a big window) shows the army bigger, in whole pixels
	s.layer.scale = Vector2.ONE * zoom
	var w: float = maxf(s.stage.size.x, 300.0) / zoom
	var all: Array = s.race.units
	var units := _stage_pick(all, int(w / 46.0))
	var n := units.size()
	for k in n:
		var u: Dictionary = units[k]
		var view := UnitView.new()
		view.build(u.recipe, lib, s.team, u.eval.speed)
		view.scale = Vector2.ONE * ArtKit.UNIT_SCALE
		view.pose_steps = 8
		view.art_px = ArtKit.ART_SCALE / zoom
		var x := w * (k + 0.75) / (n + 0.5)
		view.position = Vector2(x, maxf(s.stage.size.y, STAGE_H) / zoom * (0.62 if k % 2 == 0 else 0.8))
		view.face(1.0 if i == 0 else -1.0)   # both armies face the middle
		s.layer.add_child(view)
	s.status.text = "  %d units, every one priced by its parts" % all.size()
	if s.forging and s.dirty_at == 0.0:   # the new army is ready: the veil lifts and it fades in
		s.forging = false
		s.dice.busy = false
		s.veil.hide_veil()
		s.layer.modulate.a = 0.0
		_fade_army(s, 1.0, LoaderStyle.ARMY_FADE)
	var side := 0   # the portraits: kit.icons is keyed by the side's place among the races baked
	for k in i:
		if not sides[k].race.is_empty():
			side += 1
	for k in mini(n, s.units.get_child_count()):
		var pic: TextureRect = s.units.get_child(k).find_child("portrait", true, false)
		pic.texture = kit.icons.get("%d:%s" % [side, units[k].recipe.slot])


## A team game's roster entry: the portrait alone in a well; name, role and cost on hover.
func _unit_chip(u: Dictionary) -> Control:
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", _stage_well())
	well.custom_minimum_size = Vector2(54, 54)
	var role: Dictionary = {}
	for r in rules.roster:
		if r.slot == u.recipe.slot:
			role = r
	var cost := []
	for r in ["food", "wood", "stone", "gold"]:
		if int(u.eval.cost.get(r, 0)) > 0:
			cost.append("%d %s" % [int(u.eval.cost[r]), r])
	well.tooltip_text = "%s (%s)\n%s\n%s" % [u.recipe.name, role.get("name", u.recipe.slot), ", ".join(cost), role.get("desc", "")]
	var pic := TextureRect.new()
	pic.name = "portrait"
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	well.add_child(pic)
	return well


## A roster card: the unit's portrait in a well (filled in once the army is baked), its name,
## its role and cost (numbers with resource icons), what it's for on hover.
func _unit_card(u: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.custom_minimum_size = Vector2(0, CARD_H)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var role: Dictionary = {}
	for r in rules.roster:
		if r.slot == u.recipe.slot:
			role = r
	card.tooltip_text = "%s: %s" % [u.recipe.name, role.get("desc", "")]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", _stage_well())
	well.custom_minimum_size = Vector2(52, 52)
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(well)
	var pic := TextureRect.new()
	pic.name = "portrait"
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	well.add_child(pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	var tier := int(u.recipe.tier)
	var what := String(role.get("name", u.recipe.slot.capitalize()))
	var role_l := UiTheme.label((what + ("  ·  age %d" % tier if tier > 1 else "")).to_upper(), "Caption")
	role_l.add_theme_font_size_override("font_size", 12)
	col.add_child(role_l)
	var name := UiTheme.label(u.recipe.name, "Name")
	name.add_theme_font_size_override("font_size", 18)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name)
	var facts := HBoxContainer.new()
	facts.add_theme_constant_override("separation", 3)
	col.add_child(facts)
	for r in ["food", "wood", "stone", "gold"]:
		if int(u.eval.cost.get(r, 0)) <= 0:
			continue
		var n := UiTheme.label(str(int(u.eval.cost[r])), "Dim")
		n.add_theme_font_size_override("font_size", 15)
		n.add_theme_color_override("font_color", Color("#efe4c8"))
		facts.add_child(n)
		var ic := TextureRect.new()
		ic.texture = Icons.texture("res_" + r)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(17, 17)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		facts.add_child(ic)
		var sp := Control.new()
		sp.custom_minimum_size.x = 4
		facts.add_child(sp)
	return card


## The tech tree page for a side's race: its army and every age of its lines baked first (the
## portraits), and its culture's buildings (the lobby doesn't bake them otherwise).
func _open_tree(i: int) -> void:
	var s: Dictionary = sides[i]
	if s.race.is_empty():
		return
	while baking:
		await get_tree().process_frame
	if s.dirty_at > 0.0:
		s.dirty_at = 0.0
		await _bake(i)
	var arch: String = lib.architecture(s.race)
	if not kit.buildings.has(arch + ":house"):
		baking = true
		s.status.text = "  Raising the buildings..."
		await kit.bake_buildings([s.race])
		kit.rebuild_atlas()
		baking = false
		for k in sides.size():   # the atlas was rebuilt: every stage redraws from it
			_muster(k)
	if tree_page == null:
		tree_page = load("res://scenes/tech_tree.tscn").instantiate()
		add_child(tree_page)
	var side := 0   # the race's place among the races baked (kit.icons keys), as in _muster
	for k in i:
		if not sides[k].race.is_empty():
			side += 1
	tree_page.open(s.race, rules, lib, kit, side, s.team)


static func _maps() -> Array:
	var ids := []
	for f in DirAccess.get_files_at("res://data/maps"):
		if f.ends_with(".json") and not f.get_basename() in NOT_MAPS:
			ids.append(f.get_basename())
	ids.sort_custom(func(a, b): return a < b if a.contains("test") == b.contains("test") else b.contains("test"))
	return ids


func _set_map(k: int) -> void:
	map_index = posmod(k, MAPS.size())
	var m: Dictionary = DataLib.load_json("res://data/maps/%s.json" % MAPS[map_index])
	map_data = m
	if m.starts.size() != sides.size():
		_build_sides(m.starts.size())
	map_name.text = m.name
	map_name.remove_theme_font_size_override("font_size")
	var room: float = map_name.size.x
	var f: Font = map_name.get_theme_font("font")
	var fs: int = map_name.get_theme_font_size("font_size")
	while room > 0.0 and fs > 16 and f.get_string_size(m.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 2   # a long name ("Reed Meadow (2v2)") gets a smaller size, not an ellipsis (Dominic)
	map_name.add_theme_font_size_override("font_size", fs)
	var n: int = m.starts.size()
	map_note.text = "%d x %d tiles  ·  %s" % [int(m.width), int(m.height), "1 v 1" if n == 2 else "%d v %d" % [n / 2, n - n / 2]]
	map_pic.texture = ImageTexture.create_from_image(_map_image(m))


## The map as a small isometric diamond, coloured from data/terrain.json, start spots marked.
func _map_image(m: Dictionary) -> Image:
	var terr: Dictionary = DataLib.load_json("res://data/terrain.json").terrain
	var w := int(m.width)
	var h := int(m.height)
	var px := 2
	var img := Image.create((w + h) * px, (w + h) * px / 2 + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row: String = m.rows[y]
		for x in w:
			var t: String = m.legend.get(row[x], "grass")
			var c := Color(terr[t].colour)
			var sx := (x - y + h) * px
			var sy := (x + y) * px / 2
			img.fill_rect(Rect2i(sx, sy, px * 2, px), c)
	for s in m.starts:
		var sx := (int(s[0]) - int(s[1]) + h) * px
		var sy := (int(s[0]) + int(s[1])) * px / 2
		img.fill_rect(Rect2i(sx - 3, sy - 3, 8, 6), Color("#f2c94c"))
	return img


func _play() -> void:
	Audio.of(get_tree()).play("ui_start")
	while baking:   # the lobby's own bake finishes first (it's awaited here, so it must not outlive the lobby)
		await get_tree().process_frame
	var view = load("res://scenes/sim_debug.tscn").instantiate()
	view.prompts = range(sides.size()).map(func(i): return _prompt(i))
	view.rerolls = sides.map(func(s): return s.reroll)
	view.player_teams = sides.map(func(s): return s.side_team)
	view.ai_levels = sides.map(func(s): return LEVELS[s.level].to_lower())
	view.ai_levels[0] = ""   # you
	view.map_id = MAPS[map_index]
	view.vs_ai = true
	view.ai_level = view.ai_levels[1]
	remove_child(kit)   # the match takes the kit with everything baked here (and the warm-up still going)
	view.kit = kit
	get_tree().root.add_child(view)
	get_tree().current_scene = view
	queue_free()


# ------------------------------------------------------------------ backdrops

func _vignette() -> Texture2D:
	var g := GradientTexture2D.new()
	g.width = 256
	g.height = 256
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.42)
	g.fill_to = Vector2(1.05, 1.05)
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.15))
	grad.set_color(1, Color(0, 0, 0, 0.8))
	g.gradient = grad
	return g


## The stage's light: dark at the back and the sides, a warm pool where the army stands.
func _stage_light() -> Texture2D:
	var g := GradientTexture2D.new()
	g.width = 256
	g.height = 128
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.75)
	g.fill_to = Vector2(1.1, 0.0)
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.92, 0.7, 0.12))
	grad.set_color(1, Color(0.02, 0.03, 0.0, 0.75))
	g.gradient = grad
	return g


## The title screen's hill: dark above, the turf coming into the light, darker at the front.
func _hill() -> Texture2D:
	var g := GradientTexture2D.new()
	g.width = 8
	g.height = 256
	g.fill_from = Vector2(0.5, 0.0)
	g.fill_to = Vector2(0.5, 1.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.5)])
	g.gradient = grad
	return g
