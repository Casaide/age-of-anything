extends PanelContainer
## The bottom-left command panel: what's selected, a line of info, and buttons
## (with hotkeys) for what it can do. Rebuilt only when its content changes, so
## buttons don't flicker or lose clicks; the info line updates every frame.

const BG := Color("#3a332b")
const TEXT_DIM := Color("#b8ad94")

var _title: Label
var _info: Label
var _buttons: HFlowContainer
var _signature := ""


func _ready() -> void:
	custom_minimum_size = Vector2(460, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(BG, 0.92)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(4)
	style.border_width_top = 4
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	box.add_child(_title)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 12)
	_info.add_theme_color_override("font_color", TEXT_DIM)
	box.add_child(_info)
	_buttons = HFlowContainer.new()
	_buttons.add_theme_constant_override("h_separation", 6)
	_buttons.add_theme_constant_override("v_separation", 6)
	box.add_child(_buttons)


## buttons: [{text, enabled, action: Callable}]
func show_content(title: String, info: String, team: Color, buttons: Array) -> void:
	_title.text = title
	_info.text = info
	(get_theme_stylebox("panel") as StyleBoxFlat).border_color = team
	var sig := title + "|" + str(team) + "|" + "|".join(buttons.map(func(b): return "%s:%s" % [b.text, b.enabled]))
	if sig == _signature:
		return
	_signature = sig
	for c in _buttons.get_children():
		c.queue_free()
	for b in buttons:
		var button := Button.new()
		button.text = b.text
		button.disabled = not b.enabled
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(b.action)
		_buttons.add_child(button)
