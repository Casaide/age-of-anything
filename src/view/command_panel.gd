extends PanelContainer
## The bottom command panel, in three parts split by carved grooves:
## - who's selected: a portrait of the unit (its own baked art), its name, a slim health bar
##   with "hp / max" and what it's doing; for a group, a tray of small portraits with counts;
## - what it can do: big square buttons with the unit's or building's picture, a hotkey and
##   the cost, in captioned groups (Train, Research, Age up, Orders, Build...);
## - for a building, its training queue, sunk in a well: the unit being trained in the first
##   slot with a progress bar, the rest in small slots after it; click a slot to cancel it.
##   Shift-click a train button to queue five.
## Buttons explain themselves on hover: a tooltip card (title, cost, what it does, what it
## needs in red, what it unlocks), from the button's `tip` (BBCode) or else its text.
## Rebuilt only when its content changes, so buttons don't flicker or lose clicks;
## health, progress and the info line update every frame.
## Its look is your race's (the HUD's theme, src/view/ui/theme.gd): the frame and crest, the
## buttons' material, wells for the portrait, queue and slots.

const PartShape := preload("res://src/part_shape.gd")
const Audio := preload("res://src/view/audio.gd")
const UiTheme := preload("res://src/view/ui/theme.gd")

const GOLD := Color("#f2c94c")
const HP_GOOD := Color("#5cb84a")
const HP_HURT := Color("#e0a83a")
const HP_LOW := Color("#d8503c")
const PORTRAIT := 96
const BUTTON := 80        # bigger than anything in the queue: what you can order reads first (Dominic)
const QUEUE_FIRST := 60
const QUEUE_SLOT := 28
const QUEUE_COLUMNS := 7
const GROUP_COLUMNS := 4

var res_icons := {}   # a resource's short letter -> its icon, so costs under buttons read "10 [food icon]"
var _portrait: TextureRect
var _title: Label
var _info: Label
var _hp: ProgressBar
var _hp_text: Label
var _tray: HFlowContainer
var _actions: HBoxContainer      # the button groups side by side, a faint groove between each
var _split_who: Control          # the carved grooves: who | actions | queue
var _split_queue: Control
var _queue_box: PanelContainer
var _queue_rest: GridContainer   # the queue after the first: small slots, only the filled ones
var _queue: HBoxContainer
var _queue_label: Label   # "Training", or what the building is doing instead (ageing up, research)
var _queue_bar: ProgressBar
var _hp_fills := {}
var _signature := ""
var _team := Color.WHITE


func _ready() -> void:
	theme_type_variation = "Hud"
	for c in [HP_GOOD, HP_HURT, HP_LOW]:
		_hp_fills[c] = UiTheme.bar_fill(c)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var frame := _framed(_portrait, Vector2(PORTRAIT, PORTRAIT))
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN   # stays square when the buttons make the row tall
	row.add_child(frame)

	var who := VBoxContainer.new()
	who.custom_minimum_size = Vector2(300, 0)
	who.add_theme_constant_override("separation", 5)
	row.add_child(who)
	_title = UiTheme.label("", "Heading")
	_title.add_theme_font_size_override("font_size", 23)
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.add_child(_title)
	var hp_row := HBoxContainer.new()   # a slim bar and the number: health is a fact, not a banner (Dominic)
	hp_row.add_theme_constant_override("separation", 8)
	who.add_child(hp_row)
	_hp = _bar(HP_GOOD, 7)
	_hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row.add_child(_hp)
	_hp_text = UiTheme.label("", "Dim")
	_hp_text.add_theme_font_size_override("font_size", 14)
	_hp_text.custom_minimum_size.x = 76
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_row.add_child(_hp_text)
	_info = UiTheme.label("", "Dim")
	_info.add_theme_font_size_override("font_size", 15)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(300, 0)   # room for the unit card
	who.add_child(_info)
	_tray = HFlowContainer.new()
	_tray.add_theme_constant_override("h_separation", 3)
	_tray.add_theme_constant_override("v_separation", 3)
	who.add_child(_tray)

	_split_who = _groove(true)
	row.add_child(_split_who)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 10)
	row.add_child(_actions)
	_split_queue = _groove(true)
	row.add_child(_split_queue)

	_queue_box = PanelContainer.new()   # a recessed well: what's coming, apart from what you can order
	_queue_box.theme_type_variation = "Well"
	_queue_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_queue_box)
	var qcol := VBoxContainer.new()
	qcol.add_theme_constant_override("separation", 5)
	_queue_box.add_child(qcol)
	_queue_label = _caption("Training")
	qcol.add_child(_queue_label)
	_queue = HBoxContainer.new()
	_queue.alignment = BoxContainer.ALIGNMENT_BEGIN
	_queue.add_theme_constant_override("separation", 6)
	qcol.add_child(_queue)
	_queue_rest = GridContainer.new()
	_queue_rest.columns = QUEUE_COLUMNS
	_queue_rest.add_theme_constant_override("h_separation", 3)
	_queue_rest.add_theme_constant_override("v_separation", 3)
	_queue.add_child(_queue_rest)
	_queue_bar = _bar(GOLD, 4)
	_queue_bar.custom_minimum_size.x = QUEUE_FIRST
	_queue_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	qcol.add_child(_queue_bar)


## c: {title, info, team, portrait (Texture2D or null), hp: [now, max] or [],
##     tray: [{icon, count}], buttons: [{icon, text, key, cost, enabled, action, group, accent}],
##     queue: [{icon, name, action}] or null (no queue), queue_max, progress (0..1)}
## Buttons sharing a `group` (its caption: "Train", "Research", "Build"...) sit together, groups
## in the order they first appear; `accent` gives a button a gold edge (the age-up).
func show_content(c: Dictionary) -> void:
	_title.text = c.title
	_team = c.team
	_info.text = c.info
	# How-to lines show on hover, so the text stays short and the panel one row tall.
	_info.tooltip_text = c.get("hint", "")
	_info.mouse_filter = Control.MOUSE_FILTER_PASS if _info.tooltip_text != "" else Control.MOUSE_FILTER_IGNORE
	var hp: Array = c.get("hp", [])
	_hp.get_parent().visible = not hp.is_empty()
	if not hp.is_empty():
		_hp.max_value = hp[1]
		_hp.value = hp[0]
		_hp_text.text = "%d / %d" % [hp[0], hp[1]]
		var f := float(hp[0]) / maxf(1.0, float(hp[1]))
		_hp.add_theme_stylebox_override("fill", _hp_fills[HP_GOOD if f > 0.5 else (HP_HURT if f > 0.25 else HP_LOW)])
	var queue = c.get("queue")
	_queue_box.visible = queue != null
	_queue_bar.value = c.get("progress", 0.0)
	_queue_label.text = str(c.get("queue_title", "Training")).to_upper()
	_queue_bar.modulate.a = 1.0 if queue != null and not queue.is_empty() else 0.25
	var sig := "%s|%s|%s|%s|%s|%s" % [c.title, c.team, c.portrait, c.get("tray", []).map(func(t): return "%s%d" % [t.icon, t.count]),
		c.buttons.map(func(b): return "%s:%s:%s:%s:%s" % [b.get("group", ""), b.text, b.enabled, b.get("accent", false), b.get("cost", "")]), queue.map(func(q): return str(q.icon)) if queue != null else "-"]
	if sig == _signature:
		return
	_signature = sig
	_portrait.texture = c.portrait
	_tint(_portrait)
	_portrait.get_parent().visible = c.portrait != null
	for n in [_tray, _actions, _queue, _queue_rest]:
		for k in n.get_children():
			if k != _queue_rest:
				n.remove_child(k)   # out now, so action_buttons() and the layout see only the new ones
				k.queue_free()
	for t in c.get("tray", []):
		_tray.add_child(_tray_icon(t.icon, t.count))
	var groups := {}   # caption -> its buttons
	var order := []    # captions, first seen first
	for b in c.buttons:
		var g: String = b.get("group", "")
		if not groups.has(g):
			groups[g] = []
			order.append(g)
		groups[g].append(b)
	for i in order.size():
		if i > 0:
			_actions.add_child(_groove(false))
		_actions.add_child(_group(order[i], groups[order[i]]))
	_actions.visible = not order.is_empty()
	_split_who.visible = not order.is_empty() or queue != null
	_split_queue.visible = not order.is_empty() and queue != null
	if queue != null:
		var first := _queue_slot(queue[0] if not queue.is_empty() else {}, true)
		_queue.add_child(first)
		_queue.move_child(first, 0)
		for k in range(1, queue.size()):
			_queue_rest.add_child(_queue_slot(queue[k], false))
		_queue_rest.tooltip_text = "%d of %d" % [queue.size(), int(c.queue_max)]


## Keep clear of something to the right (the minimap) by `right_edge` (HUD x): while the panel
## reaches past it, its button groups wrap into fewer columns, one step per frame, down to 2.
func keep_left_of(right_edge: float) -> void:
	if get_rect().end.x <= right_edge:
		return
	for g in _actions.get_children():
		if g is VBoxContainer:
			var grid: GridContainer = g.get_child(1)
			if grid.columns > 2:
				grid.columns -= 1
				return


## Every action button, in panel order (for tests and captures).
func action_buttons() -> Array:
	var out := []
	for g in _actions.get_children():
		if g is VBoxContainer:
			out.append_array(g.get_child(1).get_children())
	return out


## One group: its caption over a grid of its buttons.
func _group(caption: String, buttons: Array) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	col.add_child(_caption(caption.to_upper()))
	var grid := GridContainer.new()
	grid.columns = mini(buttons.size(), GROUP_COLUMNS)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	for b in buttons:
		grid.add_child(_button(b))
	return col


func _caption(text: String) -> Label:
	var l := UiTheme.label(text, "Caption")
	l.add_theme_font_size_override("font_size", 12)
	l.custom_minimum_size.y = 16
	return l


## A line carved down the panel: a dark cut with a light lip. A major one (between who, the
## actions and the queue) runs the panel's height with a small bronze diamond at its middle;
## between groups it's short and faint, starting under the captions.
class Groove extends Control:
	var major := false

	func _draw() -> void:
		var top := 2.0 if major else 22.0
		var bottom := size.y - 2.0
		var x := floorf(size.x * 0.5)
		var a := 1.0 if major else 0.55
		draw_line(Vector2(x, top), Vector2(x, bottom), Color(0, 0, 0, 0.6 * a), 1.0)
		draw_line(Vector2(x + 1, top), Vector2(x + 1, bottom), Color("#8a7450", 0.5 * a), 1.0)
		if major:
			var m := Vector2(x + 0.5, floorf(size.y * 0.5))
			var d := 4.0
			var pts := PackedVector2Array([m + Vector2(0, -d), m + Vector2(d, 0), m + Vector2(0, d), m + Vector2(-d, 0)])
			draw_colored_polygon(pts, Color("#a08858"))
			pts.append(pts[0])
			draw_polyline(pts, Color(0, 0, 0, 0.6), 1.0)


func _groove(major: bool) -> Control:
	var g := Groove.new()
	g.major = major
	g.custom_minimum_size = Vector2(10, 0)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.resized.connect(g.queue_redraw)
	return g


## A button whose tooltip is a styled card instead of the plain grey box. Tooltips are popups
## outside the scaled HUD, so the card sizes its own type by `ui_scale` (set by the HUD).
class TipButton extends Button:
	static var ui_scale := 1.0
	static var look := {}   # the HUD's look (your race's), set by the HUD

	func _make_custom_tooltip(for_text: String) -> Object:
		return UiTheme.tip_card(for_text, look if not look.is_empty() else UiTheme.look(""), ui_scale)


func _button(b: Dictionary) -> Button:
	var button := TipButton.new()
	button.custom_minimum_size = Vector2(BUTTON, BUTTON)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not b.enabled
	button.tooltip_text = b.get("tip", b.text)
	button.pressed.connect(b.action)
	button.theme_type_variation = "Accent" if b.get("accent", false) else "IconButton"
	UiTheme.juice(button)
	if b.get("icon"):
		var pic := TextureRect.new()
		pic.texture = b.icon
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.offset_left = 6
		pic.offset_top = 5
		pic.offset_right = -6
		pic.offset_bottom = -17
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.modulate.a = 1.0 if b.enabled else 0.35
		_tint(pic)
		button.add_child(pic)
	else:
		button.text = b.text
	if b.get("glyph") != null:   # a small function badge (bow, anvil, logs...): tells look-alike buildings apart
		var g := TextureRect.new()
		g.texture = b.glyph
		g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		g.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		g.size = Vector2(26, 26)
		g.position = Vector2(BUTTON - 29, 3)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.modulate.a = 1.0 if b.enabled else 0.5
		button.add_child(g)
	if b.get("key", "") != "":
		var key := _corner(b.key, Vector2(7, 3), GOLD)
		key.add_theme_font_size_override("font_size", 14)
		button.add_child(key)
	if b.get("cost", "") != "":
		button.add_child(_cost_row(b.cost, Color.WHITE if b.enabled else Color("#e07060")))
	return button


## "10F 20W" as numbers with resource icons, centred along the button's foot.
func _cost_row(text: String, colour: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.position = Vector2(0, BUTTON - 19)
	row.size = Vector2(BUTTON, 15)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for word in text.split(" "):
		var short := word.right(1)
		if not res_icons.has(short) or not word.left(-1).is_valid_int():
			row.add_child(_corner(word, Vector2.ZERO, colour))
			continue
		row.add_child(_corner(word.left(-1), Vector2.ZERO, colour))
		var ic := TextureRect.new()
		ic.texture = res_icons[short]
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(15, 15)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
	# Three or four costs (an age-up, a Wonder) spill past the button's edges: shrink the row to
	# fit, once its labels know their font (before it's in the tree they measure nothing).
	row.minimum_size_changed.connect(_fit_cost.bind(row))
	_fit_cost(row)
	return row


func _fit_cost(row: HBoxContainer) -> void:
	var w := row.get_combined_minimum_size().x
	var k := minf(1.0, (BUTTON - 6) / maxf(1.0, w))
	if is_equal_approx(k, row.scale.x):
		return
	row.scale = Vector2(k, k)
	row.size.x = BUTTON / k
	row.position = Vector2(0, BUTTON - 4 - 15 * k)


func _queue_slot(q: Dictionary, first: bool) -> Control:
	var side := QUEUE_FIRST if first else QUEUE_SLOT
	if q.is_empty():
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(side, side)
		empty.theme_type_variation = "Slot"
		return empty
	var b := TipButton.new()
	b.custom_minimum_size = Vector2(side, side)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "[b]%s[/b]\nClick to cancel." % q.name
	b.pressed.connect(q.action)
	b.theme_type_variation = "Accent" if first else "IconButton"
	UiTheme.juice(b)
	var pic := TextureRect.new()
	pic.texture = q.icon
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 3
	pic.offset_top = 3
	pic.offset_right = -3
	pic.offset_bottom = -3
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pic)
	return b


func _tray_icon(icon: Texture2D, count: int) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(40, 40)
	p.theme_type_variation = "Slot"
	var pic := TextureRect.new()
	pic.texture = icon
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 2
	pic.offset_top = 2
	pic.offset_right = -2
	pic.offset_bottom = -2
	p.add_child(pic)
	if count > 1:
		var n := _corner(str(count), Vector2(0, 22), Color.WHITE)
		n.size = Vector2(37, 14)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		p.add_child(n)
	return p


func _framed(inner: Control, size: Vector2) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = size
	p.theme_type_variation = "Slot"
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(inner)
	return p


func _corner(text: String, at: Vector2, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_font_override("font", UiTheme.text_font(true))
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar(fill: Color, height: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.max_value = 1.0
	bar.add_theme_stylebox_override("fill", UiTheme.bar_fill(fill))
	return bar


## Building pictures come straight from the atlas in the team key colour: recolour
## them like the map does (unit portraits are rendered in their team already).
func _tint(pic: TextureRect) -> void:
	var baked := pic.texture is AtlasTexture
	pic.material = PartShape.team_material if baked else null
	pic.self_modulate = Color(_team.r, _team.g, _team.b, 1.0) if baked else Color.WHITE
