extends Control
## The lobby, the game's front door. A title menu (battle the AI, the Race Lab, quit) leads to
## the battle setup: two side banners (you and the AI), each with a live preview of the army the
## prompt makes (baked as in a match, idling on a strip of grass), the prompt with a reroll and
## presets, the roster with costs and the generator's notes; a map card in the middle drawn from
## the map's data; and Start. The match runs in the game view with the AI on side 2, and comes
## back here when it ends. Styled like the in-game command panel (warm dark wood, bronze, gold).
## Run: godot --path . res://scenes/match_setup.tscn

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const UnitView := preload("res://src/unit_view.gd")
const Icons := preload("res://src/view/art/icons.gd")

const PRESETS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans",
	"greek hoplites", "spooky beetle knights", "steppe horse archers", "forest spiders"]
const MAPS := ["flat_test", "choke_test"]

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


func _ready() -> void:
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
	for i in sides.size():
		if sides[i].race.is_empty():
			_regenerate(i)


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
	row.add_child(_side_panel(0, "You", PRESETS[0]))
	row.add_child(_centre())
	row.add_child(_side_panel(1, "The AI", PRESETS[1]))
	return margin


## The middle: the "versus" seal, the map card, and Start.
func _centre() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 300
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
	pick.add_child(map_name)
	var next := _button(">", 18, false)
	next.pressed.connect(func(): _set_map(map_index + 1))
	pick.add_child(next)
	inner.add_child(pick)
	map_pic = TextureRect.new()
	map_pic.custom_minimum_size = Vector2(256, 140)
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


## One side's banner: the race's name, its army on a strip of grass, the prompt, presets,
## the roster with costs, and the generator's notes.
func _side_panel(i: int, who: String, prompt: String) -> Control:
	var team := Color(lib.palettes.teams[i])
	var card := _panel(team)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	var top := HBoxContainer.new()
	var whol := _label(who.to_upper(), 14, team.lightened(0.3))
	top.add_child(whol)
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
	col.add_child(stage)
	var status := _label("", 13, DIM)
	col.add_child(status)
	if i == 1:   # the AI's banner: how hard it plays
		var lrow := HBoxContainer.new()
		lrow.add_theme_constant_override("separation", 8)
		lrow.add_child(_label("Plays", 15, DIM))
		level_pick = OptionButton.new()
		level_pick.add_item("Easy: attacks late and small")
		level_pick.add_item("Normal")
		level_pick.selected = 0
		level_pick.focus_mode = Control.FOCUS_NONE
		lrow.add_child(level_pick)
		col.add_child(lrow)
	# The prompt, a reroll, presets.
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 8)
	var field := LineEdit.new()
	field.text = prompt
	field.placeholder_text = "Describe a race: \"sewer rats with cheese hammers\""
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_font_size_override("font_size", 19)
	field.add_theme_stylebox_override("normal", _box(Color("#16120d"), EDGE, 1))
	field.add_theme_stylebox_override("focus", _box(Color("#16120d"), GOLD, 1))
	field.text_changed.connect(func(_t): sides[i].reroll = 0; _regenerate(i))
	field.text_submitted.connect(func(_t): _regenerate(i))   # Enter shows the race; only Start starts (Fable)
	prow.add_child(field)
	var dice := _button("Reroll", 16, false)
	dice.tooltip_text = "Same words, another roll of the dice"
	dice.pressed.connect(func(): sides[i].reroll += 1; _regenerate(i))
	prow.add_child(dice)
	col.add_child(prow)
	var pick := OptionButton.new()   # presets in one menu, not a wall of chips (Fable)
	pick.add_item("Try one of these...")
	for p in PRESETS:
		pick.add_item(p)
	pick.focus_mode = Control.FOCUS_NONE
	pick.add_theme_font_size_override("font_size", 15)
	pick.item_selected.connect(func(k): if k > 0: field.text = PRESETS[k - 1]; sides[i].reroll = 0; _regenerate(i); pick.select(0))
	col.add_child(pick)
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
	sides.append({"field": field, "reroll": 0, "race": {}, "name": name, "line": line, "roster": roster, "units": units,
		"stage": stage, "vp": vp, "layer": layer, "status": status, "dirty_at": 0.0, "team": team})
	return card


## A prompt changed: the name and roster at once (generation is instant), the army after a pause.
func _regenerate(i: int) -> void:
	var s: Dictionary = sides[i]
	var prompt: String = s.field.text.strip_edges()
	var race: Dictionary = gen.generate(prompt if prompt != "" else "?", rules, s.reroll)
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
	s.status.text = "Mustering..."
	s.dirty_at = Time.get_ticks_msec() / 1000.0


## Bake a side's army (the kit skips parts it has) and stand it on the stage.
func _bake(i: int) -> void:
	baking = true
	var races := []
	var teams := []
	for s in sides:
		if not s.race.is_empty():
			races.append(s.race)
			teams.append(s.team)
	await kit.prepare_units(races, teams)
	await kit.bake_icons(races, teams)
	baking = false
	for k in sides.size():   # the atlas was rebuilt: every stage redraws from it
		_muster(k)


func _muster(i: int) -> void:
	var s: Dictionary = sides[i]
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
	var view = load("res://scenes/sim_debug.tscn").instantiate()
	view.prompts = [sides[0].field.text, sides[1].field.text]
	view.rerolls = [sides[0].reroll, sides[1].reroll]
	view.map_id = MAPS[map_index]
	view.vs_ai = true
	view.ai_level = ["easy", "normal"][level_pick.selected]
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
