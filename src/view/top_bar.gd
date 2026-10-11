extends PanelContainer
## The top bar: your stock of each resource with its icon, your population against the cap
## (red when it's full), your race and age, and the match clock. Styled like the command
## panel. Resources come from data, so a new one shows up here by itself.

const Icons := preload("res://src/view/art/icons.gd")

const BG := Color("#2e2820")
const EDGE := Color("#6a5a40")
const TEXT := Color("#f0e6cc")
const FULL := Color("#e88a70")

var _values := {}    # key -> Label
var _title: Label
var _clock: Label


func setup(resource_ids: Array) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(BG, 0.94)
	style.border_color = EDGE
	style.border_width_bottom = 2
	style.border_width_right = 2
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 14
	style.content_margin_right = 18
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	add_child(row)
	for id in resource_ids + ["pop"]:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		var icon := TextureRect.new()
		icon.texture = Icons.texture("res_" + id)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(26, 26)
		cell.add_child(icon)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 18)
		value.add_theme_color_override("font_color", TEXT)
		value.custom_minimum_size.x = 64 if id == "pop" else 48
		cell.add_child(value)
		_values[id] = value
		row.add_child(cell)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_color", Color("#d8c89a"))
	row.add_child(_title)
	_clock = Label.new()
	_clock.add_theme_font_size_override("font_size", 16)
	_clock.add_theme_color_override("font_color", Color("#b8ad94"))
	row.add_child(_clock)


## stock: {resource id: amount}; pop, cap; title e.g. "Bog Frogs, Stick Age"; secs of match time.
func show_state(stock: Dictionary, pop: int, cap: int, title: String, secs: int) -> void:
	for id in stock:
		_values[id].text = str(stock[id])
	_values.pop.text = "%d/%d" % [pop, cap]
	_values.pop.add_theme_color_override("font_color", FULL if pop >= cap else TEXT)
	_title.text = title
	_clock.text = "%d:%02d" % [secs / 60, secs % 60]
