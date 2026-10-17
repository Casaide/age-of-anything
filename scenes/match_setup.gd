extends Control
## The lobby, the game's front door. A title screen (the two rolled armies facing each other on
## a hill under the title; battle the AI, the Race Lab, quit) leads to the battle setup: two side
## panels (you and the AI), each wearing its race's culture (src/view/ui/theme.gd: the frame,
## crest and banner of data/families.json's `ui` block), with the race's name on its banner, its
## army idling on a lit stage, the dice and the prompt, the roster as a line of its lines' names
## (every line age by age on hover; the portraits and unit cards are on the tech tree page), one line of bonuses,
## lacks and notes (src/view/ui/trait_strip.gd: the lists on hover); in the middle a cast "vs", the map card, the AI's level and
## Start. The match runs in the game view with the AI on side 2 and comes back here when it ends.
## Each banner's "Tech tree" button opens that race's tech tree page (scenes/tech_tree.tscn).
## Everything has a fixed size, so nothing moves when a race or map changes (Dominic).
## A map with more than two starts is a team game: a panel per player in two teams (you and an
## AI ally against two AIs), each with its own dice, prompt and AI level, all rolled on entry.
## Run: godot --path . res://scenes/match_setup.tscn

const DataLib := preload("res://src/data_lib.gd")
const PadMode := preload("res://src/view/pad_mode.gd")
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
const TraitStrip := preload("res://src/view/ui/trait_strip.gd")
const TreeModel := preload("res://src/view/tech_tree_model.gd")
const Identity := preload("res://src/identity.gd")
const SavesPage := preload("res://src/view/ui/saves_page.gd")
const NetPage := preload("res://src/view/ui/net_page.gd")

const NOT_MAPS := ["choke_test", "river_test", "hill_test"]   # test maps (sim_debug lists them)
var MAPS := _maps()   # every map in data/maps: the real ones first (by name), the test maps last
const LEVELS := ["Easy", "Normal", "Hard"]

const BASE := 20                 # the lobby's body type in UI pixels (Dominic: "text is all too small")
const DESIGN := Vector2(1600, 950)   # the lobby is laid out for this and scaled to fill the window
const CENTRE_W := 420
const BANNER_H := 96
const STAGE_H := 144
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
var map_name_fs := 0            # the map name's heading size; a long name is fitted below it
var map_note: Label
var MODES := _modes()         # the game modes (data/modes.json), Standard first
var mode_index := 0
var mode_name: Label
var map_data: Dictionary        # the map picked (its starts say how many players)
var level_card: Control         # 1v1: how hard the AI plays (in a team game each AI panel has its own)
var level_buttons: Array = []
var left_col: VBoxContainer     # your team's panels
var right_col: VBoxContainer    # the other team's
var start_button: Button        # where a pad's focus starts on the battle setup
var tree_page: Control          # the tech tree page, over everything while open
var saves_page: Control         # Load game: the saved matches (src/view/ui/saves_page.gd)
var net_page: Control           # Play on the network (src/view/ui/net_page.gd)
var net_hosting := false        # the battle setup is for hosting a network game (Start: wait for a player)
var net_hosting_save := false   # the saves page is picking a saved match to host on the network
var menu_layer: Node2D          # the title screen's hill, both armies on it
var menu_stage: SubViewportContainer
var _themes := {}               # family -> Theme (themes are built once per culture)
var _tech: Dictionary           # data/tech.json (the bonuses, own research and lacks in words)


func _ready() -> void:
	UiScale.fit_window(get_window())   # big enough to read on a Retina screen (src/view/ui_scale.gd)
	get_window().size_changed.connect(_rescale)
	_rescale()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	lib = DataLib.new()
	gen = Generator.new(lib)
	rules = DataLib.load_rules("default")
	kit = ArtKit.new()
	kit.lib = lib
	add_child(kit)
	theme = _theme("")
	add_child(_backdrop())
	menu = _menu()
	add_child(menu)
	setup = _setup()
	setup.set_meta("pad_first", start_button)   # a pad starts on Start Battle
	setup.visible = false
	add_child(setup)
	UiTheme.juice_all(self)
	PadMode.of(get_tree()).menus.append_array([menu, setup])   # a pad walks them by focus (milestone 20)
	var audio := Audio.of(get_tree())
	audio.ambience(false)
	audio.music("lobby")


## The lobby is a designed screen: laid out at DESIGN and scaled to fill the window; the UI-size
## setting takes it from 76% of that (at 40%) to all of it (at 100%), so it always reads at a
## glance (Dominic: "text is all too small on the lobby") and the size steps still do something.
func _rescale() -> void:
	var px := Vector2(get_window().size)
	var fill := minf(px.x / DESIGN.x, px.y / DESIGN.y)
	# Never below 1 where it fits at 1; on a smaller window (the Steam Deck's 1280 x 800) the whole
	# design fits on screen (Dominic: the Start button was off the bottom).
	get_window().content_scale_factor = maxf(minf(1.0, fill), fill * (0.6 + 0.4 * UiScale.size_pct() / 100.0))


## Cmd/Ctrl + minus / plus: the UI a step smaller or larger (saved).
func _unhandled_key_input(event: InputEvent) -> void:
	var d := UiScale.key_step(event)
	if d != 0:
		UiScale.step(d)
		_rescale()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_pad()
	var now := Time.get_ticks_msec() / 1000.0
	for i in sides.size():
		if sides[i].dirty_at > 0.0 and now - sides[i].dirty_at > BAKE_AFTER and not baking:
			sides[i].dirty_at = 0.0
			_bake(i)


## The pad's shortcuts on the battle setup (focus does the rest): X rolls the dice of the panel
## the focus is in (yours when it's elsewhere), Menu starts the battle, B goes back to the title.
func _pad() -> void:
	var pad := PadMode.of(get_tree())
	if not pad.on or not setup.visible or (tree_page != null and (tree_page.visible or tree_page.closed_frame == Engine.get_process_frames())):
		return
	if net_page != null and (net_page.visible or net_page.closed_frame == Engine.get_process_frames()):
		return   # (the network page reads the pad by focus)
	if pad.pressed(JOY_BUTTON_X):
		var focus := get_viewport().gui_get_focus_owner()
		var k := 0
		for i in sides.size():
			if focus != null and sides[i].panel.is_ancestor_of(focus):
				k = i
		sides[k].dice.tumble()
		_roll(k)
	elif pad.pressed(JOY_BUTTON_START):
		_play()
	elif pad.pressed(JOY_BUTTON_B) and not get_viewport().gui_get_focus_owner() is LineEdit:
		setup.visible = false
		menu.visible = true
		UiTheme.arrive(menu)


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
	for item in [["Battle the AI", func(): net_hosting = false; _open_setup()], ["Play on the network", func(): _open_net()], ["Load game", func(): net_hosting_save = false; _open_saves()], ["Race Lab", func(): get_tree().change_scene_to_file("res://scenes/race_lab.tscn")],
			["Quit", func(): get_tree().quit()]]:
		var primary: bool = item[0] == "Battle the AI"
		var b := UiTheme.button(item[0], primary)
		b.custom_minimum_size = Vector2(400, 88 if primary else 62)
		if not primary:
			b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(item[1])
		b.focus_neighbor_left = NodePath(".")   # a pad's left and right stay put: the list runs up and down
		b.focus_neighbor_right = NodePath(".")
		buttons.add_child(b)
	var foot := UiTheme.label("Type \"centaur romans\" or \"sewer rats with cheese hammers\": the game builds the race and prices every unit fairly.", "Dim", true)
	foot.custom_minimum_size.x = 640
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 10
	col.add_child(gap2)
	col.add_child(foot)
	return root


## Play on the network: host (the battle setup, then wait for a player) or join a game on the home
## network (src/view/ui/net_page.gd).
func _open_net() -> void:
	if net_page == null:
		net_page = NetPage.new()
		add_child(net_page)
		PadMode.of(get_tree()).menus.append(net_page)
		net_page.host_chosen.connect(func(): net_hosting = true; _open_setup())
		net_page.host_save_chosen.connect(func(): net_hosting_save = true; _open_saves())
		net_page.start.connect(_play_network)
		net_page.closed.connect(func():
			if not setup.visible:
				menu.visible = true
				UiTheme.arrive(menu))
	menu.visible = false
	net_page.open()


## Host: the battle as set up, one human each side (1v1 on a two-player map); wait for a player.
func _host_network() -> void:
	if sides.size() != 2:
		net_page.visible = false
		start_button.text = "Host Battle: 1v1 maps only"
		return
	var setup_now := {"prompts": [_prompt(0), _prompt(1)], "rerolls": [sides[0].reroll, 0], "map": MAPS[map_index],
		"mode": MODES[mode_index][0] if MODES[mode_index][0] != "standard" else "", "teams": sides.map(func(s): return s.side_team)}
	net_page.wait_for_player(setup_now, "%s on %s" % [sides[0].race.get("name", "?"), str(map_data.get("name", MAPS[map_index]))])


## Both ready: the match, this machine playing side `me` (the host 0, the joiner 1).
func _play_network(link, me: int, net_setup: Dictionary) -> void:
	Audio.of(get_tree()).play("ui_start")
	while baking:
		await get_tree().process_frame
	var view = load("res://scenes/sim_debug.tscn").instantiate()
	view.use_network(link, me, net_setup)
	remove_child(kit)
	view.kit = kit
	get_tree().root.add_child(view)
	get_tree().current_scene = view
	queue_free()


## Load game: the saved matches over the title menu; picking one plays on from it.
func _open_saves() -> void:
	if saves_page == null:
		saves_page = SavesPage.new(lib, UiTheme.look("").metal)
		add_child(saves_page)
		PadMode.of(get_tree()).menus.append(saves_page)
		saves_page.chosen.connect(func(rep):
			if net_hosting_save:   # hosting it on the network: which AI the other player takes over
				net_hosting_save = false
				saves_page.visible = false
				net_page.choose_seat(rep)
			else:
				_play_saved(rep))
		saves_page.closed.connect(func():
			net_hosting_save = false
			menu.visible = true
			UiTheme.arrive(menu))
	menu.visible = false
	saves_page.open()


func _play_saved(rep: Dictionary) -> void:
	Audio.of(get_tree()).play("ui_start")
	while baking:
		await get_tree().process_frame
	var view = load("res://scenes/sim_debug.tscn").instantiate()
	view.use_save(rep)
	remove_child(kit)   # the match takes the kit, as a new battle does
	view.kit = kit
	get_tree().root.add_child(view)
	get_tree().current_scene = view
	queue_free()


func _open_setup() -> void:
	menu.visible = false
	setup.visible = true
	start_button.text = "Host Battle" if net_hosting else "Start Battle"
	UiTheme.arrive(setup.get_child(0))
	Audio.of(get_tree()).play("ui_tip")


## Both armies on the title screen's hill: yours from the left, the AI's from the right.
func _muster_menu() -> void:
	if menu_layer == null:
		return
	for n in menu_layer.get_children():
		n.queue_free()
	var w: float = menu_stage.size.x / MENU_ZOOM
	if w <= 0.0:
		return
	for i in sides.size():
		var s: Dictionary = sides[i]
		if not _stood(s):
			continue
		var units: Array = _stage_pick(s.race.units, STAGE_MAX)   # the few the stage bakes (not the whole roster)
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
		var who := "You" if i == 0 else ("Ally (AI)" if t == _team_of(0, n) else "The AI")
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
	var above := Control.new()   # the map card, as tall as its map, sits in the middle of what a tall window spares (not an empty well under the map: Dominic)
	above.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(above)
	var card := PanelContainer.new()
	card.theme_type_variation = "CrestFrame"
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
	map_name.resized.connect(_fit_map_name)
	pick.add_child(map_name)
	var next := UiTheme.button(">")
	next.custom_minimum_size = Vector2(46, 46)
	next.pressed.connect(func(): _set_map(map_index + 1))
	pick.add_child(next)
	inner.add_child(pick)
	var well := PanelContainer.new()
	well.theme_type_variation = "Well"
	inner.add_child(well)
	map_pic = TextureRect.new()   # the map fills the well's width, the well as tall as the map's diamond
	map_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_pic.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	map_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	well.add_child(map_pic)
	map_note = UiTheme.label("", "Dim")
	map_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(map_note)
	var mode_pick := HBoxContainer.new()   # the game mode (milestone 16): Standard, Fortress, Siege
	mode_pick.add_theme_constant_override("separation", 8)
	var mprev := UiTheme.button("<")
	mprev.custom_minimum_size = Vector2(36, 36)
	mprev.pressed.connect(func(): _set_mode(mode_index - 1))
	mode_pick.add_child(mprev)
	mode_name = UiTheme.label("")
	mode_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_pick.add_child(mode_name)
	var mnext := UiTheme.button(">")
	mnext.custom_minimum_size = Vector2(36, 36)
	mnext.pressed.connect(func(): _set_mode(mode_index + 1))
	mode_pick.add_child(mnext)
	inner.add_child(mode_pick)
	_set_mode(0)
	var spare := Control.new()   # and the AI's level and Start stay at the foot, level with the side panels
	spare.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spare)
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
	start_button = start
	col.add_child(start)
	var breathe := start.create_tween().set_loops()   # Start breathes: the screen's call to arms
	breathe.set_trans(Tween.TRANS_SINE)
	breathe.tween_property(start, "self_modulate", Color(1.12, 1.08, 1.0), 1.4)
	breathe.tween_property(start, "self_modulate", Color.WHITE, 1.4)
	var hint := UiTheme.label("Esc in battle: pause and menu", "Dim")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	var pad := PadMode.of(get_tree())
	var say := func(on: bool): hint.text = "X: roll the dice  ·  Menu: start  ·  B: back" if on else "Esc in battle: pause and menu"
	pad.changed.connect(say)
	hint.tree_exiting.connect(func(): pad.changed.disconnect(say), CONNECT_ONE_SHOT)   # the pad node outlives the lobby
	say.call(pad.on)
	return col


## One side's panel, in its race's culture: who it is and the tech tree, the race's banner,
## its army on a lit stage, the dice and the prompt, the roster as portrait tiles grouped by
## building, a line of bonuses, lacks and notes. Compact (a team game, two panels a column): a
## smaller banner (the traits line on it), stage and tiles (no captions), an AI's level in its top row. The
## roster and the line are kept small so the stage gets the height (Dominic: "taking up too much space").
func _side_panel(i: int, who: String, compact := false) -> Control:
	var team := Color(lib.palettes.teams[i])
	var card := PanelContainer.new()
	card.theme_type_variation = "CrestFrame"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL   # two to a column share it; the stages take the slack
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6 if compact else 9)
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
	whol.clip_text = true   # (a team panel's top row is full: it mustn't widen its column past the other)
	whol.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	whol.custom_minimum_size.x = 40
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
	banner.custom_minimum_size.y = 62 if compact else BANNER_H
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
	var line_row := HBoxContainer.new()   # compact: the traits line rides here, beside the creature and culture
	line_row.add_theme_constant_override("separation", 14)
	line_row.add_child(line)
	bcol.add_child(line_row)
	col.add_child(banner)
	# The stage: the army idling on grass, lit from above, sunk in the panel.
	var well := PanelContainer.new()
	well.theme_type_variation = "Well"
	well.add_theme_stylebox_override("panel", _stage_well())
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL   # the stage takes what the window spares
	col.add_child(well)
	var stage := SubViewportContainer.new()
	stage.custom_minimum_size = Vector2(0, 60 if compact else STAGE_H)
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
		if i < sides.size():
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
	dice.custom_minimum_size = Vector2.ONE * (48 if compact else 68)
	dice.tooltip_text = "Roll the dice: a new race (with words in the box, another roll of those words)"
	dice.pressed.connect(func(): dice.tumble(); _roll(i))
	UiTheme.juice(dice)
	prompt.add_child(dice)
	var field := LineEdit.new()
	field.placeholder_text = "...or describe your race"
	field.custom_minimum_size = Vector2(0, 48 if compact else 68)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.add_theme_font_size_override("font_size", 22 if compact else 28)
	field.text_changed.connect(func(_t): sides[i].reroll = 0; _regenerate(i))
	field.text_submitted.connect(func(_t): _regenerate(i))   # Enter shows the race; only Start starts (Fable)
	prompt.add_child(field)
	var units := RichTextLabel.new()   # the roster in words: its lines' names (the portraits and cards are on the tech tree page); lacked lines struck through
	units.bbcode_enabled = true
	units.scroll_active = false
	units.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	units.add_theme_font_override("normal_font", UiTheme.text_font())
	units.add_theme_font_size_override("normal_font_size", 15 if compact else 17)
	units.custom_minimum_size.y = 22 if compact else 48
	units.clip_contents = true   # (one or two lines; the whole list on hover)
	units.mouse_filter = Control.MOUSE_FILTER_STOP
	col.add_child(units)
	var roster := TraitStrip.new(compact)   # bonuses, own research, lacks, notes: one line, the lists on hover
	if compact:   # on the banner (two panels a column: the stage needs the height)
		var hold := Control.new()   # it takes the room the line leaves, never widening the panel
		hold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hold.custom_minimum_size.y = roster.custom_minimum_size.y
		hold.clip_contents = true
		roster.set_anchors_preset(Control.PRESET_FULL_RECT)
		hold.add_child(roster)
		line_row.add_child(hold)
	else:
		col.add_child(roster)
	sides.append({"field": field, "dice": dice, "reroll": 0, "rolled": "", "race": {}, "name": name, "line": line, "roster": roster, "units": units,
		"stage": stage, "vp": vp, "layer": layer, "status": status, "dirty_at": 0.0, "team": team, "panel": card, "banner": banner, "family": "?",
		"level": 0, "side_team": i, "compact": compact, "veil": veil, "forging": false, "gen": 0, "baked_gen": -1})
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
	s.units.add_theme_color_override("default_color", s.units.get_theme_color("font_color", "Dim"))
	s.units.text = _lines_text(race, rules)
	s.units.tooltip_text = _lines_card(race, rules)
	s.gen += 1   # a new race: its stage waits for its bake
	kit.cancel_warm()   # the old race's background bake stops (warmed again once every stage stands)
	show_traits(i, _traits(race))
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


## Bake only what a side's stage shows (the few _stage_pick stands up, at their first age; the kit
## skips parts it has) and stand them up; the other sides are left alone (Dominic: "it shouldn't
## generate more than needed straight away"). Once no side is waiting, the rest warms up behind
## (kit.warm, lowest priority): every age of every line, the portraits, the buildings and props,
## so the tech tree page and a match start find them done.
func _bake(i: int) -> void:
	baking = true
	var s: Dictionary = sides[i]
	var gen: int = s.gen
	var t0 := Time.get_ticks_msec()
	var picks := _stage_pick(s.race.units, STAGE_MAX)
	await kit.bake_steps(picks.map(func(u): return {"recipe": u.recipe, "eval": u.eval}))
	print("Lobby bake: %d ms (%s: %d units for the stage)" % [Time.get_ticks_msec() - t0, s.race.name, picks.size()])
	baking = false
	if i >= sides.size() or not is_same(sides[i], s):   # (the sides were rebuilt meanwhile, 2v2 to 1v1: theirs bake anew)
		return
	if s.gen == gen:   # (typed or rolled again meanwhile: it's dirty, and baked next)
		s.baked_gen = gen
	_muster(i)
	_muster_menu()
	if sides.all(func(x): return _stood(x)):
		kit.warm(sides.map(func(x): return x.race), sides.map(func(x): return x.team))


## A side's army is baked and standing (not waiting on a new race's bake).
func _stood(s: Dictionary) -> bool:
	return not s.race.is_empty() and s.baked_gen == s.gen and s.dirty_at == 0.0


## The few that show off a race on the stage, a line each, in this order while there's room (the
## whole roster, siege and all, crowded into a heap: Dominic, "we squeeze too much, be selective").
const STAGE_ROLES := ["spear", "infantry", "archer", "large", "skirmisher", "worker", "catapult", "healer"]
const STAGE_MAX := 6   # the most a stage shows (a wide one): what the lobby bakes for it up front


static func _stage_pick(units: Array, room: int) -> Array:
	var out := []
	for role in STAGE_ROLES:
		if out.size() >= clampi(room, 3, STAGE_MAX):
			break
		for u in units:
			if u.recipe.get("role", "") == role:
				out.append(u)
				break
	return out


func _muster(i: int) -> void:
	var s: Dictionary = sides[i]
	if not _stood(s):   # its new race isn't baked yet: the old army stays under the veil
		return
	for n in s.layer.get_children():
		n.queue_free()
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
		var h: float = s.stage.size.y / zoom
		var feet := (0.62 if k % 2 == 0 else 0.8) if h >= 40.0 else 0.92   # a low stage (a team game at a big UI size): one line, feet at its foot
		view.position = Vector2(x, h * feet)
		view.face(1.0 if i == 0 else -1.0)   # both armies face the middle
		s.layer.add_child(view)
	s.status.text = "  %d units, every one priced by its parts" % all.size()
	if s.forging:   # the new army is ready: the veil lifts and it fades in
		s.forging = false
		s.dice.busy = false
		s.veil.hide_veil()
		s.layer.modulate.a = 0.0
		_fade_army(s, 1.0, LoaderStyle.ARMY_FADE)


## The roster in a line of words (BBCode): each line's name at its first age, the creature's noun
## left off when most share it ("Spearbearer, Archer, Heavy Lancer..." for "Spearbearer Centaur"...);
## a line the race lacks (spiders: no Stable, so no Heavy or Scout) struck through, as the tech
## tree page crosses it out, and not counted.
static func _lines_text(race: Dictionary, rules: Dictionary) -> String:
	var last := {}
	var units: Array = race.units.filter(func(u): return u.recipe.slot != "hero")   # (the heroes: their own group in the traits)
	for u in units:
		for w in Array(String(u.recipe.name).split(" ")).filter(func(x): return x.length() > 2):   # (each word once a name; not "on", "a")
			last[w] = last.get(w, 0) + 1
	var common := ""
	for w in last:
		if last[w] * 2 >= units.size() and (common == "" or last[w] > last[common]):
			common = w
	var names := []
	var have := 0
	var ident := Identity.of(race.creature, race.family)
	for u in units:
		var words := Array(String(u.recipe.name).split(" ")).filter(func(w): return w != common)
		var n: String = " ".join(words) if not words.is_empty() else u.recipe.name
		if Identity.lacks(ident, u.recipe.slot, rules):
			names.append("[color=#e88a70][s]%s[/s][/color]" % n)
		else:
			names.append(n)
			have += 1
	var heroes: int = race.units.size() - units.size()
	return "%d lines: %s" % [have, ", ".join(names)] + ("; %d heroes" % heroes if heroes > 1 else "; a hero" if heroes == 1 else "")


## Why a race has no such line, from whichever of its creature and culture lacks it (the line
## itself, or the building that trains it): "Spiders have no Stable"; "" if it has it.
static func _lack_reason(race: Dictionary, slot: String, rules: Dictionary) -> String:
	if not Identity.lacks(Identity.of(race.creature, race.family), slot, rules):
		return ""
	var d := Identity.files()
	for src in [[d.creatures[race.creature], String(d.creatures[race.creature].plural)], [d.families[race.family], String(race.family).capitalize() + " folk"]]:
		for id in src[0].get("lacks", []):
			if id == slot:
				return "%s have no such line" % src[1]
			if d.buildings.has(id) and slot in d.buildings[id].get("trains", []):
				return "%s have no %s" % [src[1], d.buildings[id].name]
	return "not in this race's tree"


## The roster on hover: every line, age by age (the portraits and cards are on the tech tree page).
static func _lines_card(race: Dictionary, rules: Dictionary) -> String:
	var rows := []
	for u in race.units:
		var why := _lack_reason(race, u.recipe.slot, rules)
		if why != "":
			rows.append("%s: not in this race's tree (%s)" % [u.recipe.name, why])
			continue
		if u.recipe.slot == "hero":
			rows.append("Hero: %s (age %d, Town Center)" % [u.recipe.name, int(u.recipe.tier)])
			continue
		rows.append(" > ".join(u.get("line", [u]).map(func(l): return "%s (age %d)" % [l.recipe.name, int(l.get("age", u.recipe.get("tier", 1)))])))
	return "\n".join(rows) + "\n\nTech tree: every line's portraits and cards"


## A race's traits in words, as the strip's groups: what it's better at, its own research,
## what it lacks, the generator's notes (src/identity.gd via the tech tree's race panel).
func _traits(race: Dictionary) -> Array:
	if _tech.is_empty():
		_tech = DataLib.load_json("res://data/tech.json")
	var p: Dictionary = TreeModel._race_panel(race, rules, lib, _tech)
	return [{"title": "Bonuses", "one": "bonus", "lines": p.bonuses, "kind": "bonus"},
		{"title": "Own research", "one": "own research", "lines": p.own, "kind": "own"},
		{"title": "Lacks", "one": "lack", "lines": p.lacks, "kind": "lack"},
		{"title": "Heroes", "one": "hero", "lines": race.get("heroes", []).map(func(h): return "%s: %s (%s)" % [h.name, h.temper, h.aura]), "kind": "hero"},
		{"title": "Notes", "one": "note", "lines": race.notes, "kind": "note"}]


## A side's traits line: groups of {title, one, lines, kind} (see src/view/ui/trait_strip.gd).
## Kept as one call so more can join it (the heroes joined as a group, milestone 14).
func show_traits(i: int, groups: Array) -> void:
	sides[i].roster.look = UiTheme.look(sides[i].race.family)
	sides[i].roster.show_traits(groups)


## The tech tree page for a side's race. It opens at once; what it shows that isn't baked yet
## (every age of every line and their portraits, the culture's buildings) it bakes under its
## own loader, whether the lobby's background warm-up got there first or not.
func _open_tree(i: int) -> void:
	var s: Dictionary = sides[i]
	if s.race.is_empty():
		return
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


## The game modes in data/modes.json: [id, name, desc], Standard first, the rest as listed.
static func _modes() -> Array:
	var d: Dictionary = DataLib.load_json("res://data/modes.json").modes
	var out := []
	for id in d:
		out.append([id, d[id].name, d[id].get("desc", "")])
	return out


func _set_mode(k: int) -> void:
	mode_index = posmod(k, MODES.size())
	mode_name.text = "Mode: %s" % MODES[mode_index][1]
	mode_name.tooltip_text = MODES[mode_index][2]


func _set_map(k: int) -> void:
	map_index = posmod(k, MAPS.size())
	var m: Dictionary = DataLib.load_json("res://data/maps/%s.json" % MAPS[map_index])
	map_data = m
	if m.starts.size() != sides.size():
		_build_sides(m.starts.size())
	map_name.text = m.name
	_fit_map_name()
	var n: int = m.starts.size()
	map_note.text = "%d x %d tiles  ·  %s" % [int(m.width), int(m.height), "1 v 1" if n == 2 else "%d v %d" % [n / 2, n - n / 2]]
	map_pic.texture = ImageTexture.create_from_image(_map_image(m))


## A long name ("Reed Meadow (2v2)") gets a smaller size, not an ellipsis (Dominic). Fitted again
## when the label is laid out: the first map is named before the setup screen has its size, which
## left "Old Forest" in the smallest type.
func _fit_map_name() -> void:
	if not map_name.is_inside_tree():
		return   # no theme yet (the setup screen is still being built); it fits when it's laid out
	if map_name_fs == 0:
		map_name_fs = map_name.get_theme_font_size("font_size")   # the heading's own size, before any fitting
	var room: float = map_name.size.x
	var f: Font = map_name.get_theme_font("font")
	var fs := map_name_fs
	while room > 0.0 and fs > 16 and f.get_string_size(map_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 2
	if fs != map_name.get_theme_font_size("font_size"):   # (setting it resizes the label, which calls this again)
		map_name.add_theme_font_size_override("font_size", fs)


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
	if net_hosting:
		_host_network()
		return
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
	view.mode = MODES[mode_index][0] if MODES[mode_index][0] != "standard" else ""
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
