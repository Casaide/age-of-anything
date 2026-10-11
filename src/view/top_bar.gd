extends PanelContainer
## The top bar: your stock of each resource with its icon, your population against the cap
## (red when it's full), your race and age, and the match clock. Styled like the command
## panel. Resources come from data, so a new one shows up here by itself.

const Icons := preload("res://src/view/art/icons.gd")

const BG := Color("#2e2820")
const EDGE := Color("#6a5a40")
const TEXT := Color("#f0e6cc")
const FULL := Color("#e88a70")

signal idle_pressed

var _values := {}    # key -> Label
var _idle: Button
var _title: Label
var _clock: Label
var _age_num: Label     # the age badge: a big number and the age's name, and the age-up's progress
var _age_name: Label
var _age_bar: ProgressBar


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
	row.add_child(_make_age_badge())
	_idle = Button.new()   # idle workers: how many, and a click cycles through them (".")
	_idle.icon = Icons.texture("idle")
	_idle.expand_icon = true
	_idle.custom_minimum_size = Vector2(70, 30)
	_idle.focus_mode = Control.FOCUS_NONE
	_idle.tooltip_text = "Idle workers: click (or press .) to go to the next one"
	_idle.add_theme_font_size_override("font_size", 16)
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#3a2e20")
	st.border_color = EDGE
	st.set_border_width_all(1)
	st.set_corner_radius_all(3)
	_idle.add_theme_stylebox_override("normal", st)
	_idle.pressed.connect(func(): idle_pressed.emit())
	row.add_child(_idle)
	_clock = Label.new()
	_clock.add_theme_font_size_override("font_size", 16)
	_clock.add_theme_color_override("font_color", Color("#b8ad94"))
	row.add_child(_clock)


## The age on its own (Dominic: it was lost after the race name): framed, the age-up icon, a
## big gold number, the name; while ageing up, the next age's name and a progress bar.
func _make_age_badge() -> Control:
	var badge := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#3a2e20")
	st.border_color = Color("#f2c94c")
	st.set_border_width_all(1)
	st.set_corner_radius_all(4)
	st.content_margin_left = 8
	st.content_margin_right = 10
	badge.add_theme_stylebox_override("panel", st)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	badge.add_child(col)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	col.add_child(line)
	var icon := TextureRect.new()
	icon.texture = Icons.texture("age_up")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(22, 22)
	line.add_child(icon)
	_age_num = Label.new()
	_age_num.add_theme_font_size_override("font_size", 20)
	_age_num.add_theme_color_override("font_color", Color("#f2c94c"))
	line.add_child(_age_num)
	_age_name = Label.new()
	_age_name.add_theme_font_size_override("font_size", 16)
	_age_name.add_theme_color_override("font_color", TEXT)
	_age_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(_age_name)
	_age_bar = ProgressBar.new()
	_age_bar.show_percentage = false
	_age_bar.custom_minimum_size = Vector2(0, 4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#f2c94c")
	var back := StyleBoxFlat.new()
	back.bg_color = Color("#1e1a14")
	_age_bar.add_theme_stylebox_override("fill", fill)
	_age_bar.add_theme_stylebox_override("background", back)
	col.add_child(_age_bar)
	return badge


## age: the number; name: its name; next: the next age's name while ageing up ("" when not);
## frac: how far the age-up has got (0..1).
func show_age(age: int, name: String, next: String, frac: float) -> void:
	_age_num.text = str(age)
	_age_bar.visible = next != ""
	if next == "":
		_age_name.text = name
		_age_name.add_theme_color_override("font_color", TEXT)
	else:
		_age_name.text = "%s  ->  %s  %d%%" % [name, next, int(frac * 100.0)]
		_age_name.add_theme_color_override("font_color", Color("#f2c94c"))
		_age_bar.value = frac * 100.0


func show_idle(n: int) -> void:
	_idle.text = str(n)
	_idle.modulate = Color(1, 1, 1, 1.0 if n > 0 else 0.45)
	_idle.add_theme_color_override("font_color", Color("#ffb070") if n > 0 else TEXT)


## stock: {resource id: amount}; pop, cap; title e.g. "Bog Frogs, Stick Age"; secs of match time.
func show_state(stock: Dictionary, pop: int, cap: int, title: String, secs: int) -> void:
	for id in stock:
		_values[id].text = str(stock[id])
	_values.pop.text = "%d/%d" % [pop, cap]
	_values.pop.add_theme_color_override("font_color", FULL if pop >= cap else TEXT)
	_title.text = title
	_clock.text = "%d:%02d" % [secs / 60, secs % 60]
