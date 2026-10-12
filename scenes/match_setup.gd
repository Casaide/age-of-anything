extends Control
## The lobby, the game's front door. A title menu (battle the AI, the Race Lab, quit) leads to
## the battle setup: two side banners (you and the AI), each with a live preview of the army the
## prompt makes (baked as in a match, idling on a strip of grass), the prompt with a reroll and
## presets, the roster with costs and the generator's notes; a map card in the middle drawn from
## the map's data; and Start. The match runs in the game view with the AI on side 2, and comes
## back here when it ends. Styled like the in-game command panel (warm dark wood, bronze, gold).
## Each banner's "Tech tree" button opens that race's tech tree page (scenes/tech_tree.tscn).
## Run: godot --path . res://scenes/match_setup.tscn

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const UnitView := preload("res://src/unit_view.gd")
const Audio := preload("res://src/view/audio.gd")
const UiScale := preload("res://src/view/ui_scale.gd")
const DiceButton := preload("res://src/view/loaders/dice_button.gd")
const ForgeVeil := preload("res://src/view/loaders/forge_veil.gd")
const LoaderStyle := preload("res://src/view/loaders/loader_style.gd")

const MAPS := ["reed_meadow", "reed_meadow_large", "flat_test"]   # real maps; choke_test is a movement test (sim_debug lists it)

const BG := Color("#1c1712")
const PANEL := Color("#2a231b")
const EDGE := Color("#6a5a40")
const BRONZE := Color("#a08858")
const GOLD := Color("#f2c94c")
const TEXT := Color("#efe4c8")
const DIM := Color("#b8ad94")
const GRASS := Color("#4e6e2a")
const STAGE_H := 190
const STAGE_ZOOM := 2.0          # screen pixels per canvas unit on the preview stage
const BAKE_AFTER := 0.6          # seconds of no typing before a prompt is re-baked

var lib
var gen
var rules: Dictionary
var kit: ArtKit
var baking := false
var menu: Control
var setup: Control
var sides: Array = []           # per side: {field, reroll, race, name, line, roster, stage, layer, dirty_at}
var map_index := 0
var map_name: Label
var map_pic: TextureRect
var map_note: Label
var level_pick: OptionButton
var tree_page: Control          # the tech tree page, over everything while open


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
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vignette := TextureRect.new()   # a soft darkening at the corners, like an old map
	vignette.texture = _vignette()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	menu = _menu()
	add_child(menu)
	setup = _setup()
	setup.visible = false
	add_child(setup)
	var audio := Audio.of(get_tree())
	audio.ambience(false)
	audio.music("lobby")


## Cmd/Ctrl + minus / plus: the UI a step smaller or larger (saved).
func _unhandled_key_input(event: InputEvent) -> void:
	var d := UiScale.key_step(event)
	if d != 0:
		UiScale.step(d)
		_rescale()
		get_viewport().set_input_as_handled()


## The lobby is all UI: the whole window scales to the screen's density and the player's UI size.
func _rescale() -> void:
	get_window().content_scale_factor = UiScale.factor(get_window(), UiScale.MENU_NEEDS)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for i in sides.size():
		if sides[i].dirty_at > 0.0 and now - sides[i].dirty_at > BAKE_AFTER and not baking:
			sides[i].dirty_at = 0.0
			_bake(i)


# ------------------------------------------------------------------ the title menu

func _menu() -> Control:
	var root := CenterContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(col)
	var title := Label.new()
	title.text = "Age of Whatever"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_outline_color", Color("#3a2a10"))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 5)
	col.add_child(title)
	var tag := _label("Your civilisation is whatever you can describe.", 20, DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size.y = 36
	col.add_child(gap)
	for item in [["Battle the AI", func(): _open_setup()], ["Race Lab", func(): get_tree().change_scene_to_file("res://scenes/race_lab.tscn")],
			["Quit", func(): get_tree().quit()]]:
		var b := _button(item[0], 26, item[0] == "Battle the AI")
		b.custom_minimum_size = Vector2(360, 64)
		b.pressed.connect(item[1])
		col.add_child(b)
	var foot := _label("Type \"centaur romans\" or \"sewer rats with cheese hammers\": the game builds the race and prices every unit fairly.", 15, DIM.darkened(0.25), true)
	foot.custom_minimum_size.x = 560
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 28
	col.add_child(gap2)
	col.add_child(foot)
	return root


func _open_setup() -> void:
	menu.visible = false
	setup.visible = true
	for i in sides.size():   # every side starts rolled (Dominic): flick the dice again, or type
		if sides[i].race.is_empty():
			_roll(i)


# ------------------------------------------------------------------ the battle setup

func _setup() -> Control:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)
	var head := HBoxContainer.new()
	var back := _button("< Menu", 16, false)
	back.pressed.connect(func(): setup.visible = false; menu.visible = true)
	head.add_child(back)
	var title := _label("  Prepare for battle", 30, GOLD)
	head.add_child(title)
	col.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	row.add_child(_side_panel(0, "You"))
	row.add_child(_centre())
	row.add_child(_side_panel(1, "The AI"))
	return margin


## The middle: the "versus" seal, the map card, and Start.
func _centre() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 400   # fixed: a longer map name mustn't push the banners about (Dominic)
	col.add_theme_constant_override("separation", 16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var vs := _label("vs", 54, BRONZE)
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs.add_theme_color_override("font_outline_color", Color("#120e0a"))
	vs.add_theme_constant_override("outline_size", 8)
	col.add_child(vs)
	var card := _panel()
	col.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	card.add_child(inner)
	inner.add_child(_label("Battlefield", 14, DIM))
	var pick := HBoxContainer.new()
	var prev := _button("<", 18, false)
	prev.pressed.connect(func(): _set_map(map_index - 1))
	pick.add_child(prev)
	map_name = _label("", 21, TEXT)
	map_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_name.clip_text = true
	pick.add_child(map_name)
	var next := _button(">", 18, false)
	next.pressed.connect(func(): _set_map(map_index + 1))
	pick.add_child(next)
	inner.add_child(pick)
	map_pic = TextureRect.new()
	map_pic.custom_minimum_size = Vector2(360, 200)   # Dominic: the map needs more room
	map_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inner.add_child(map_pic)
	map_note = _label("", 14, DIM)
	map_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(map_note)
	_set_map(0)
	var start := _button("Start battle", 28, true)
	start.custom_minimum_size = Vector2(0, 72)
	start.pressed.connect(_play)
	col.add_child(start)
	var hint := _label("Esc in battle: pause and menu", 13, DIM.darkened(0.2))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	return col


## One side's banner: the race's name, its army on a strip of grass, the dice and the prompt,
## the roster with costs, and the generator's notes.
func _side_panel(i: int, who: String) -> Control:
	var team := Color(lib.palettes.teams[i])
	var card := _panel(team)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	var top := HBoxContainer.new()
	var whol := _label(who.to_upper(), 14, team.lightened(0.3))
	whol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	whol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(whol)
	var tree_b := _button("Tech tree", 15, false)
	tree_b.tooltip_text = "Everything this race can build, train and research, and its bonuses"
	tree_b.pressed.connect(func(): _open_tree(i))
	top.add_child(tree_b)
	col.add_child(top)
	var name := _label("", 32, TEXT)
	col.add_child(name)
	var line := _label("", 16, DIM)
	col.add_child(line)
	# The stage: the army idling on grass.
	var stage := SubViewportContainer.new()
	stage.custom_minimum_size = Vector2(0, STAGE_H)
	stage.stretch = true
	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	stage.add_child(vp)
	var ground := ColorRect.new()
	ground.color = GRASS
	ground.size = Vector2(2000, 1000)
	vp.add_child(ground)
	var shade := TextureRect.new()   # the grass darkens towards the back, so the army stands forward
	shade.texture = _ground_shade()
	shade.size = Vector2(2000, STAGE_H)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	vp.add_child(shade)
	var layer := Node2D.new()
	layer.y_sort_enabled = true
	layer.scale = Vector2.ONE * STAGE_ZOOM
	vp.add_child(layer)
	var stage_box := Control.new()   # the stage, and over it the veil shown while a new army is forged
	stage_box.custom_minimum_size = Vector2(0, STAGE_H)
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_box.add_child(stage)
	var veil := ForgeVeil.new()
	stage_box.add_child(veil)
	col.add_child(stage_box)
	var status := _label("", 13, DIM)
	col.add_child(status)
	# The dice, then the prompt (Dominic: the dice is the main thing; every side starts rolled,
	# the box starts empty, no menu of presets).
	var dice := DiceButton.new()   # tumbles when thrown, rocks until the race is made
	dice.custom_minimum_size = Vector2(84, 84)
	dice.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dice.tooltip_text = "Roll the dice: a new race (with words in the box, another roll of those words)"
	dice.add_theme_stylebox_override("normal", _box(Color("#2e2820"), EDGE, 2))
	dice.add_theme_stylebox_override("hover", _box(Color("#3a3226"), GOLD, 2))
	dice.add_theme_stylebox_override("pressed", _box(Color("#1e1a14"), GOLD, 2))
	dice.pressed.connect(func(): dice.tumble(); _roll(i))
	col.add_child(dice)
	var field := LineEdit.new()
	field.placeholder_text = "...or describe your race"
	field.custom_minimum_size = Vector2(0, 60)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.add_theme_font_size_override("font_size", 26)
	field.add_theme_color_override("font_placeholder_color", Color(DIM, 0.7))
	field.add_theme_stylebox_override("normal", _box(Color("#16120d"), BRONZE, 2))
	field.add_theme_stylebox_override("focus", _box(Color("#1c1710"), GOLD, 3))
	field.text_changed.connect(func(_t): sides[i].reroll = 0; _regenerate(i))
	field.text_submitted.connect(func(_t): _regenerate(i))   # Enter shows the race; only Start starts (Fable)
	col.add_child(field)
	if i == 1:   # the AI's banner: how hard it plays
		var lrow := HBoxContainer.new()
		lrow.add_theme_constant_override("separation", 8)
		lrow.add_child(_label("Plays", 15, DIM))
		level_pick = OptionButton.new()
		level_pick.add_item("Easy")
		level_pick.add_item("Normal")
		level_pick.add_item("Hard")
		level_pick.selected = 0
		level_pick.focus_mode = Control.FOCUS_NONE
		lrow.add_child(level_pick)
		col.add_child(lrow)
	var units := VBoxContainer.new()   # one row per unit: its portrait, name and cost (the banner's lower half was empty: Fable)
	units.add_theme_constant_override("separation", 4)
	col.add_child(units)
	var roster := RichTextLabel.new()   # the generator's notes
	roster.bbcode_enabled = true
	roster.fit_content = true
	roster.scroll_active = false
	roster.add_theme_font_size_override("normal_font_size", 15)
	roster.add_theme_color_override("default_color", TEXT)
	col.add_child(roster)
	sides.append({"field": field, "reroll": 0, "rolled": "", "race": {}, "name": name, "line": line, "roster": roster, "units": units,
		"stage": stage, "vp": vp, "layer": layer, "status": status, "dirty_at": 0.0, "team": team,
		"veil": veil, "dice": dice, "forging": false})
	return card


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
	var kit := []
	for w in lib.lexicon:
		var e: Dictionary = lib.lexicon[w]
		if e.has("creature") and w.ends_with("s") and lib.creatures.get(e.creature, {}).get("playable", false):
			creatures.append(w)
		elif e.has("family") and not e.has("creature"):
			cultures.append(w)
		elif e.keys().size() == 1 and e.has("tags"):
			kit.append(w)
	creatures.sort()
	cultures.sort()
	kit.sort()
	var words := []
	if randi() % 3 != 0:
		words.append(cultures[randi() % cultures.size()])
	words.append(creatures[randi() % creatures.size()])
	if randi() % 2 == 0:
		words.append("with " + kit[randi() % kit.size()])
	return " ".join(words)


## A prompt changed: the name and roster at once (generation is instant), the army after a pause.
func _regenerate(i: int) -> void:
	var s: Dictionary = sides[i]
	var race: Dictionary = gen.generate(_prompt(i), rules, s.reroll)
	s.race = race
	s.name.text = race.name
	s.line.text = "%s, %s" % [lib.creatures[race.creature].plural, String(race.family).capitalize()]
	var lines := []
	for n in s.units.get_children():
		n.queue_free()
	for u in race.units:
		var cost := []
		for r in u.eval.cost:
			if int(u.eval.cost[r]) > 0:
				cost.append("%d%s" % [int(u.eval.cost[r]), String(r).substr(0, 1).to_upper()])
		var age := "" if int(u.recipe.tier) <= 1 else "  [color=#%s]from age %d[/color]" % [DIM.to_html(false), int(u.recipe.tier)]
		s.units.add_child(_unit_row("[b]%s[/b]   [color=#%s]%s[/color]%s" % [u.recipe.name, DIM.to_html(false), " ".join(cost), age]))
	for n in race.notes:
		lines.append("[i][color=#%s]%s[/color][/i]" % [BRONZE.lightened(0.2).to_html(false), n])
	s.roster.text = "\n".join(lines)
	s.status.text = "Forging the army..."
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
	if races.size() == sides.size() and sides.all(func(s): return s.dirty_at == 0.0):
		kit.warm(races)   # while the players choose, bake the match's buildings and props


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
	var w: float = s.stage.size.x / STAGE_ZOOM
	var units: Array = s.race.units
	var n := units.size()
	for k in n:
		var u: Dictionary = units[k]
		var view := UnitView.new()
		view.build(u.recipe, lib, s.team, u.eval.speed)
		view.scale = Vector2.ONE * ArtKit.UNIT_SCALE
		view.pose_steps = 8
		view.art_px = ArtKit.ART_SCALE / STAGE_ZOOM
		var x := w * (k + 0.75) / (n + 0.5)
		view.position = Vector2(x, STAGE_H / STAGE_ZOOM * (0.72 if k % 2 == 0 else 0.86))
		view.face(1.0 if i == 0 else -1.0)   # both armies face the middle
		s.layer.add_child(view)
	s.status.text = "%d units, every one priced by its parts" % n
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
		var pic: TextureRect = s.units.get_child(k).get_child(0)
		pic.texture = kit.icons.get("%d:%s" % [side, units[k].recipe.slot])


## A roster row: a framed portrait (filled in once the army is baked) and the unit's line.
func _unit_row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(54, 54)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(pic)
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.scroll_active = false
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.add_theme_font_size_override("normal_font_size", 15)
	t.add_theme_color_override("default_color", TEXT)
	t.text = text
	row.add_child(t)
	return row


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
		s.status.text = "Raising the buildings..."
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


func _set_map(k: int) -> void:
	map_index = posmod(k, MAPS.size())
	var m: Dictionary = DataLib.load_json("res://data/maps/%s.json" % MAPS[map_index])
	map_name.text = m.name
	map_note.text = "%d x %d tiles, %d players" % [int(m.width), int(m.height), m.starts.size()]
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
		img.fill_rect(Rect2i(sx - 3, sy - 3, 8, 6), GOLD)
	return img


func _play() -> void:
	while baking:   # the lobby's own bake finishes first (it's awaited here, so it must not outlive the lobby)
		await get_tree().process_frame
	var view = load("res://scenes/sim_debug.tscn").instantiate()
	view.prompts = [_prompt(0), _prompt(1)]
	view.rerolls = [sides[0].reroll, sides[1].reroll]
	view.map_id = MAPS[map_index]
	view.vs_ai = true
	view.ai_level = ["easy", "normal", "hard"][level_pick.selected]
	remove_child(kit)   # the match takes the kit with everything baked here (and the warm-up still going)
	view.kit = kit
	get_tree().root.add_child(view)
	get_tree().current_scene = view
	queue_free()


# ------------------------------------------------------------------ the look

func _label(text: String, size: int, colour: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	if wrap:   # only in a column: in a row a wrapping label squeezes to one letter wide
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _box(fill: Color, edge: Color, width: int, radius := 4) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = edge
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	b.content_margin_left = 12
	b.content_margin_right = 12
	b.content_margin_top = 6
	b.content_margin_bottom = 6
	return b


## A framed panel; with a team colour, its top edge carries it (the side's banner).
func _panel(team := Color.TRANSPARENT) -> PanelContainer:
	var p := PanelContainer.new()
	var b := _box(Color(PANEL, 0.96), EDGE, 2, 6)
	b.content_margin_left = 18
	b.content_margin_right = 18
	b.content_margin_top = 14
	b.content_margin_bottom = 16
	if team.a > 0.0:   # the side's colour runs along the top edge of its banner
		b.border_width_top = 6
		b.border_color = team.darkened(0.15)
		b.border_width_left = 1
		b.border_width_right = 1
		b.border_width_bottom = 1
	p.add_theme_stylebox_override("panel", b)
	return p


func _button(text: String, size: int, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	var fill := Color("#5a3e14") if primary else Color("#2e2820")
	var edge := GOLD if primary else EDGE
	b.add_theme_stylebox_override("normal", _box(fill, edge, 2))
	b.add_theme_stylebox_override("hover", _box(fill.lightened(0.12), GOLD, 2))
	b.add_theme_stylebox_override("pressed", _box(fill.darkened(0.2), GOLD, 2))
	b.add_theme_color_override("font_color", GOLD.lightened(0.3) if primary else TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.pressed.connect(func(): Audio.of(get_tree()).play("ui_click"))
	return b


func _vignette() -> Texture2D:
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.45)
	g.fill_to = Vector2(1.05, 1.05)
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.55))
	g.gradient = grad
	return g


func _ground_shade() -> Texture2D:
	var g := GradientTexture2D.new()
	g.fill_from = Vector2(0.5, 0.0)
	g.fill_to = Vector2(0.5, 1.0)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.08, 0.02, 0.55))
	grad.set_color(1, Color(0, 0, 0, 0))
	g.gradient = grad
	return g
