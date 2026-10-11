extends PanelContainer
## The bottom command panel, in three parts:
## - who's selected: a portrait of the unit (its own baked art), its name, a health
##   bar and what it's doing; for a group, a tray of small portraits with counts;
## - what it can do: square buttons with the unit's or building's picture, a hotkey
##   and the cost;
## - for a building, its training queue: the unit being trained in a big slot with a progress
##   bar, the rest in small slots after it; click a slot to cancel it. Shift-click a train
##   button to queue five.
## Buttons explain themselves on hover: a tooltip card (title, cost, what it does, what it
## needs in red, what it unlocks), from the button's `tip` (BBCode) or else its text.
## Rebuilt only when its content changes, so buttons don't flicker or lose clicks;
## health, progress and the info line update every frame.

const PartShape := preload("res://src/part_shape.gd")
const Audio := preload("res://src/view/audio.gd")

const BG := Color("#2e2820")
const SLOT := Color("#1e1a14")
const EDGE := Color("#6a5a40")
const TEXT_DIM := Color("#b8ad94")
const GOLD := Color("#f2c94c")
const PORTRAIT := 96
const BUTTON := 64
const QUEUE_FIRST := 72
const QUEUE_SLOT := 36
const QUEUE_COLUMNS := 7

var res_icons := {}   # a resource's short letter -> its icon, so costs under buttons read "10 [food icon]"
var _portrait: TextureRect
var _title: Label
var _info: Label
var _hp: ProgressBar
var _tray: HFlowContainer
var _buttons: GridContainer
var _queue_box: VBoxContainer
var _queue_rest: GridContainer   # the queue after the first: small slots, only the filled ones
var _queue: HBoxContainer
var _queue_label: Label   # "Training", or what the building is doing instead (ageing up, research)
var _queue_bar: ProgressBar
var _signature := ""
var _team := Color.WHITE


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(BG, 0.95)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(4)
	style.border_width_top = 4
	style.border_color = EDGE
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
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
	who.custom_minimum_size = Vector2(330, 0)
	who.add_theme_constant_override("separation", 4)
	row.add_child(who)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 17)
	who.add_child(_title)
	_hp = _bar(Color("#5cb84a"), 10)
	who.add_child(_hp)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 13)
	_info.add_theme_color_override("font_color", TEXT_DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(330, 0)   # room for the unit card
	who.add_child(_info)
	_tray = HFlowContainer.new()
	_tray.add_theme_constant_override("h_separation", 3)
	_tray.add_theme_constant_override("v_separation", 3)
	who.add_child(_tray)

	_buttons = GridContainer.new()
	_buttons.columns = 4
	_buttons.add_theme_constant_override("h_separation", 6)
	_buttons.add_theme_constant_override("v_separation", 6)
	row.add_child(_buttons)

	_queue_box = VBoxContainer.new()
	_queue_box.add_theme_constant_override("separation", 4)
	row.add_child(_queue_box)
	var ql := Label.new()
	_queue_label = ql
	ql.text = "Training"
	ql.add_theme_font_size_override("font_size", 13)
	ql.add_theme_color_override("font_color", TEXT_DIM)
	_queue_box.add_child(ql)
	_queue = HBoxContainer.new()
	_queue.alignment = BoxContainer.ALIGNMENT_BEGIN
	_queue.add_theme_constant_override("separation", 5)
	_queue_box.add_child(_queue)
	_queue_rest = GridContainer.new()
	_queue_rest.columns = QUEUE_COLUMNS
	_queue_rest.add_theme_constant_override("h_separation", 3)
	_queue_rest.add_theme_constant_override("v_separation", 3)
	_queue.add_child(_queue_rest)
	_queue_bar = _bar(GOLD, 8)
	_queue_bar.custom_minimum_size.x = QUEUE_FIRST
	_queue_box.add_child(_queue_bar)


## c: {title, info, team, portrait (Texture2D or null), hp: [now, max] or [],
##     tray: [{icon, count}], buttons: [{icon, text, key, cost, enabled, action}],
##     queue: [{icon, name, action}] or null (no queue), queue_max, progress (0..1)}
func show_content(c: Dictionary) -> void:
	_title.text = c.title
	_team = c.team
	_info.text = c.info
	(get_theme_stylebox("panel") as StyleBoxFlat).border_color = c.team
	var hp: Array = c.get("hp", [])
	_hp.visible = not hp.is_empty()
	if not hp.is_empty():
		_hp.max_value = hp[1]
		_hp.value = hp[0]
	var queue = c.get("queue")
	_queue_box.visible = queue != null
	_queue_bar.value = c.get("progress", 0.0)
	_queue_label.text = c.get("queue_title", "Training")
	_queue_bar.modulate.a = 1.0 if queue != null and not queue.is_empty() else 0.25
	var sig := "%s|%s|%s|%s|%s|%s" % [c.title, c.team, c.portrait, c.get("tray", []).map(func(t): return "%s%d" % [t.icon, t.count]),
		c.buttons.map(func(b): return "%s:%s" % [b.text, b.enabled]), queue.map(func(q): return str(q.icon)) if queue != null else "-"]
	if sig == _signature:
		return
	_signature = sig
	_portrait.texture = c.portrait
	_tint(_portrait)
	_portrait.get_parent().visible = c.portrait != null
	for n in [_tray, _buttons, _queue, _queue_rest]:
		for k in n.get_children():
			if k != _queue_rest:
				k.queue_free()
	for t in c.get("tray", []):
		_tray.add_child(_tray_icon(t.icon, t.count))
	for b in c.buttons:
		_buttons.add_child(_button(b))
	if queue != null:
		var first := _queue_slot(queue[0] if not queue.is_empty() else {}, true)
		_queue.add_child(first)
		_queue.move_child(first, 0)
		for k in range(1, queue.size()):
			_queue_rest.add_child(_queue_slot(queue[k], false))
		_queue_rest.tooltip_text = "%d of %d" % [queue.size(), int(c.queue_max)]


## A button whose tooltip is a styled card instead of the plain grey box.
class TipButton extends Button:
	func _make_custom_tooltip(for_text: String) -> Object:
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#1e1a14", 0.97)
		style.border_color = Color("#a08858")
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", style)
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.custom_minimum_size.x = 300
		text.add_theme_font_size_override("normal_font_size", 14)
		text.add_theme_font_size_override("bold_font_size", 17)
		text.add_theme_color_override("default_color", Color("#e8dcc0"))
		text.text = for_text
		card.add_child(text)
		return card


func _button(b: Dictionary) -> Button:
	var button := TipButton.new()
	button.custom_minimum_size = Vector2(BUTTON, BUTTON)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not b.enabled
	button.tooltip_text = b.get("tip", b.text)
	button.pressed.connect(b.action)
	button.pressed.connect(func(): Audio.of(get_tree()).play("ui_click"))
	button.add_theme_stylebox_override("normal", _slot_style(SLOT, EDGE))
	button.add_theme_stylebox_override("hover", _slot_style(SLOT.lightened(0.12), GOLD))
	button.add_theme_stylebox_override("pressed", _slot_style(SLOT.darkened(0.2), GOLD))
	button.add_theme_stylebox_override("disabled", _slot_style(SLOT, EDGE.darkened(0.4)))
	if b.get("icon"):
		var pic := TextureRect.new()
		pic.texture = b.icon
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.offset_left = 4
		pic.offset_top = 4
		pic.offset_right = -4
		pic.offset_bottom = -12
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
		g.size = Vector2(24, 24)
		g.position = Vector2(BUTTON - 26, 2)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.modulate.a = 1.0 if b.enabled else 0.5
		button.add_child(g)
	if b.get("key", "") != "":
		button.add_child(_corner(b.key, Vector2(4, 1), GOLD))
	if b.get("cost", "") != "":
		button.add_child(_cost_row(b.cost, Color.WHITE if b.enabled else Color("#e07060")))
	return button


## "10F 20W" as numbers with resource icons, centred along the button's foot.
func _cost_row(text: String, colour: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.position = Vector2(0, BUTTON - 17)
	row.size = Vector2(BUTTON, 14)
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
		ic.custom_minimum_size = Vector2(14, 14)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
	return row


func _queue_slot(q: Dictionary, first: bool) -> Control:
	var side := QUEUE_FIRST if first else QUEUE_SLOT
	if q.is_empty():
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(side, side)
		empty.add_theme_stylebox_override("panel", _slot_style(Color(SLOT, 0.5), EDGE.darkened(0.5)))
		return empty
	var b := Button.new()
	b.custom_minimum_size = Vector2(side, side)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "%s (click to cancel)" % q.name
	b.pressed.connect(q.action)
	b.pressed.connect(func(): Audio.of(get_tree()).play("ui_click", -4.0))
	b.add_theme_stylebox_override("normal", _slot_style(SLOT, GOLD if first else EDGE))
	b.add_theme_stylebox_override("hover", _slot_style(Color("#3a1a14"), Color("#e07060")))
	b.add_theme_stylebox_override("pressed", _slot_style(Color("#3a1a14"), Color("#e07060")))
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
	p.custom_minimum_size = Vector2(36, 36)
	p.add_theme_stylebox_override("panel", _slot_style(SLOT, EDGE))
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
		var n := _corner(str(count), Vector2(0, 20), Color.WHITE)
		n.size = Vector2(33, 14)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		p.add_child(n)
	return p


func _framed(inner: Control, size: Vector2) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = size
	p.add_theme_stylebox_override("panel", _slot_style(SLOT, EDGE))
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(inner)
	return p


func _corner(text: String, at: Vector2, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", 11)
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
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(2)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return bar


## Building pictures come straight from the atlas in the team key colour: recolour
## them like the map does (unit portraits are rendered in their team already).
func _tint(pic: TextureRect) -> void:
	var baked := pic.texture is AtlasTexture
	pic.material = PartShape.team_material if baked else null
	pic.self_modulate = Color(_team.r, _team.g, _team.b, 1.0) if baked else Color.WHITE


static func _slot_style(bg: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	return s
