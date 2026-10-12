extends PanelContainer
## The top bar: a beam in your race's frame material (src/view/ui/theme.gd, the HUD's theme)
## with your stock of each resource sunk in a plaque with its icon, your population against the
## cap (red when it's full), your race's name, the age badge, idle workers, the tech tree (F2)
## and the match clock. Resources come from data, so a new one shows up here by itself.

const Icons := preload("res://src/view/art/icons.gd")
const UiTheme := preload("res://src/view/ui/theme.gd")

const FULL := Color("#ff8a70")

signal idle_pressed
signal tree_pressed

var _values := {}    # key -> Label
var _idle: Button
var _title: Label
var _clock: Label
var _age_num: Label     # the age badge: a big number and the age's name, and the age-up's progress
var _age_name: Label
var _age_bar: ProgressBar


func setup(resource_ids: Array) -> void:
	theme_type_variation = "Bar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	for id in resource_ids + ["pop"]:
		var plaque := PanelContainer.new()
		plaque.theme_type_variation = "Plaque"
		plaque.tooltip_text = String(id).capitalize() if id != "pop" else "Population / room (build houses for more)"
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		plaque.add_child(cell)
		var icon := TextureRect.new()
		icon.texture = Icons.texture("res_" + id)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(28, 28)
		cell.add_child(icon)
		var value := UiTheme.label("", "Name")
		value.add_theme_font_size_override("font_size", 20)
		value.custom_minimum_size.x = 66 if id == "pop" else 50
		cell.add_child(value)
		_values[id] = value
		row.add_child(plaque)
	_title = UiTheme.label("", "Heading")
	_title.add_theme_font_size_override("font_size", 22)
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lead := Control.new()
	lead.custom_minimum_size.x = 8
	row.add_child(lead)
	row.add_child(_title)
	row.add_child(_make_age_badge())
	_idle = Button.new()   # idle workers: how many, and a click cycles through them (".")
	_idle.theme_type_variation = "IconButton"
	_idle.icon = Icons.texture("idle")
	_idle.expand_icon = true
	_idle.custom_minimum_size = Vector2(74, 40)
	_idle.focus_mode = Control.FOCUS_NONE
	_idle.tooltip_text = "Idle workers: click (or press .) to go to the next one"
	_idle.add_theme_font_size_override("font_size", 18)
	_idle.pressed.connect(func(): idle_pressed.emit())
	row.add_child(_idle)
	var tree := Button.new()   # the tech tree page (F2)
	tree.text = "Tech tree"
	tree.icon = Icons.texture("research")
	tree.add_theme_constant_override("icon_max_width", 22)
	tree.custom_minimum_size = Vector2(0, 40)
	tree.focus_mode = Control.FOCUS_NONE
	tree.tooltip_text = "Your race's tech tree and bonuses (F2)"
	tree.add_theme_font_size_override("font_size", 17)
	tree.pressed.connect(func(): tree_pressed.emit())
	row.add_child(tree)
	var clock := PanelContainer.new()
	clock.theme_type_variation = "Plaque"
	_clock = UiTheme.label("", "Name")
	_clock.add_theme_font_size_override("font_size", 18)
	_clock.custom_minimum_size.x = 52
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock.add_child(_clock)
	row.add_child(clock)


## The age on its own (Dominic: it was lost after the race name): the age-up icon, a big
## number, the name; while ageing up, the next age's name and a progress bar.
func _make_age_badge() -> Control:
	var badge := PanelContainer.new()
	badge.theme_type_variation = "Plaque"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	badge.add_child(col)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	col.add_child(line)
	var icon := TextureRect.new()
	icon.texture = Icons.texture("age_up")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(26, 26)
	line.add_child(icon)
	_age_num = UiTheme.label("", "Heading")
	_age_num.add_theme_font_size_override("font_size", 24)
	line.add_child(_age_num)
	_age_name = UiTheme.label("", "Name")
	_age_name.add_theme_font_size_override("font_size", 17)
	_age_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(_age_name)
	_age_bar = ProgressBar.new()
	_age_bar.show_percentage = false
	_age_bar.custom_minimum_size = Vector2(0, 5)
	col.add_child(_age_bar)
	return badge


## age: the number; name: its name; next: the next age's name while ageing up ("" when not);
## frac: how far the age-up has got (0..1).
func show_age(age: int, name: String, next: String, frac: float) -> void:
	_age_num.text = str(age)
	_age_bar.visible = next != ""
	if next == "":
		_age_name.text = name
		_age_name.remove_theme_color_override("font_color")
	else:
		_age_name.text = "%s  ->  %s  %d%%" % [name, next, int(frac * 100.0)]
		_age_name.add_theme_color_override("font_color", Color("#f6d77a"))
		_age_bar.value = frac * 100.0


func show_idle(n: int) -> void:
	_idle.text = str(n)
	_idle.modulate = Color(1, 1, 1, 1.0 if n > 0 else 0.5)
	_idle.add_theme_color_override("font_color", Color("#ffb070") if n > 0 else Color("#efe4c8"))


## stock: {resource id: amount}; pop, cap; title e.g. "Bog Frogs"; secs of match time.
func show_state(stock: Dictionary, pop: int, cap: int, title: String, secs: int) -> void:
	for id in stock:
		_values[id].text = str(stock[id])
	_values.pop.text = "%d/%d" % [pop, cap]
	if pop >= cap:
		_values.pop.add_theme_color_override("font_color", FULL)
	else:
		_values.pop.remove_theme_color_override("font_color")
	_title.text = title
	_clock.text = "%d:%02d" % [secs / 60, secs % 60]
