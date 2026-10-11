extends PanelContainer
## The bottom command panel, in three parts:
## - who's selected: a portrait of the unit (its own baked art), its name, a health
##   bar and what it's doing; for a group, a tray of small portraits with counts;
## - what it can do: square buttons with the unit's or building's picture, a hotkey
##   and the cost;
## - for a building, its training queue: big slots with the units' pictures, the first
##   with a progress bar; click a slot to cancel it.
## Rebuilt only when its content changes, so buttons don't flicker or lose clicks;
## health, progress and the info line update every frame.

const BG := Color("#2e2820")
const SLOT := Color("#1e1a14")
const EDGE := Color("#6a5a40")
const TEXT_DIM := Color("#b8ad94")
const GOLD := Color("#f2c94c")
const PORTRAIT := 96
const BUTTON := 64
const QUEUE_FIRST := 72
const QUEUE_SLOT := 52

var _portrait: TextureRect
var _title: Label
var _info: Label
var _hp: ProgressBar
var _tray: HFlowContainer
var _buttons: GridContainer
var _queue_box: VBoxContainer
var _queue: HBoxContainer
var _queue_bar: ProgressBar
var _signature := ""


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
	row.add_child(_framed(_portrait, Vector2(PORTRAIT, PORTRAIT)))

	var who := VBoxContainer.new()
	who.custom_minimum_size = Vector2(250, 0)
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
	_info.custom_minimum_size = Vector2(250, 0)
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
	ql.text = "Training"
	ql.add_theme_font_size_override("font_size", 13)
	ql.add_theme_color_override("font_color", TEXT_DIM)
	_queue_box.add_child(ql)
	_queue = HBoxContainer.new()
	_queue.alignment = BoxContainer.ALIGNMENT_BEGIN
	_queue.add_theme_constant_override("separation", 5)
	_queue_box.add_child(_queue)
	_queue_bar = _bar(GOLD, 8)
	_queue_bar.custom_minimum_size.x = QUEUE_FIRST
	_queue_box.add_child(_queue_bar)


## c: {title, info, team, portrait (Texture2D or null), hp: [now, max] or [],
##     tray: [{icon, count}], buttons: [{icon, text, key, cost, enabled, action}],
##     queue: [{icon, name, action}] or null (no queue), queue_max, progress (0..1)}
func show_content(c: Dictionary) -> void:
	_title.text = c.title
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
	_queue_bar.modulate.a = 1.0 if queue != null and not queue.is_empty() else 0.25
	var sig := "%s|%s|%s|%s|%s|%s" % [c.title, c.team, c.portrait, c.get("tray", []).map(func(t): return "%s%d" % [t.icon, t.count]),
		c.buttons.map(func(b): return "%s:%s" % [b.text, b.enabled]), queue.map(func(q): return str(q.icon)) if queue != null else "-"]
	if sig == _signature:
		return
	_signature = sig
	_portrait.texture = c.portrait
	_portrait.get_parent().visible = c.portrait != null
	for n in [_tray, _buttons, _queue]:
		for k in n.get_children():
			k.queue_free()
	for t in c.get("tray", []):
		_tray.add_child(_tray_icon(t.icon, t.count))
	for b in c.buttons:
		_buttons.add_child(_button(b))
	if queue != null:
		for k in int(c.queue_max):
			_queue.add_child(_queue_slot(queue[k] if k < queue.size() else {}, k == 0))


func _button(b: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(BUTTON, BUTTON)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not b.enabled
	button.tooltip_text = b.text
	button.pressed.connect(b.action)
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
		button.add_child(pic)
	else:
		button.text = b.text
	if b.get("key", "") != "":
		button.add_child(_corner(b.key, Vector2(4, 1), GOLD))
	if b.get("cost", "") != "":
		var cost := _corner(b.cost, Vector2(0, BUTTON - 16), Color.WHITE if b.enabled else Color("#e07060"))
		cost.size = Vector2(BUTTON, 14)
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_child(cost)
	return button


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


static func _slot_style(bg: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	return s
