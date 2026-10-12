extends PanelContainer
## The top bar: a beam in your race's frame material (src/view/ui/theme.gd, the HUD's theme)
## with your stock of each resource sunk in a plaque with its icon, your population against the
## cap (red when it's full), your race's name, the age badge, idle workers, the tech tree (F2)
## and the match clock. Resources come from data, so a new one shows up here by itself.
## Under each stock, how many of your workers are on it (a small worker and a count; the
## breakdown, farming / foraging / hunting..., on hover).

const Icons := preload("res://src/view/art/icons.gd")
const UiTheme := preload("res://src/view/ui/theme.gd")

const FULL := Color("#ff8a70")

signal idle_pressed
signal tree_pressed

var _values := {}    # key -> Label
var _workers := {}   # resource id -> Label: how many work it
var _plaques := {}   # resource id -> its plaque (the breakdown is its tooltip)
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
		var nums := VBoxContainer.new()
		nums.add_theme_constant_override("separation", -4)
		nums.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(nums)
		var value := UiTheme.label("", "Name")
		value.add_theme_font_size_override("font_size", 20)
		value.custom_minimum_size.x = 66 if id == "pop" else 50
		nums.add_child(value)
		_values[id] = value
		if id != "pop":   # who's on it: a small worker and a count
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 3)
			var who := TextureRect.new()
			who.texture = Icons.texture("res_pop")
			who.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			who.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			who.custom_minimum_size = Vector2(14, 14)
			who.modulate = Color(1, 1, 1, 0.85)
			line.add_child(who)
			var n := UiTheme.label("0", "Name")
			n.add_theme_font_size_override("font_size", 15)
			n.add_theme_color_override("font_color", Color("#d8c8a0"))
			line.add_child(n)
			nums.add_child(line)
			_workers[id] = n
			_plaques[id] = plaque
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


## work: {resource id: {verb: count}} (e.g. food: {farming: 6, foraging: 2, hunting: 1}).
func show_workers(work: Dictionary) -> void:
	for id in _workers:
		var jobs: Dictionary = work.get(id, {})
		var total := 0
		var parts := []
		for verb in jobs:
			total += int(jobs[verb])
			parts.append("%d %s" % [jobs[verb], verb])
		_workers[id].text = str(total)
		_workers[id].modulate.a = 1.0 if total > 0 else 0.55
		_plaques[id].tooltip_text = "%s: %s" % [String(id).capitalize(), ", ".join(parts) if total > 0 else "nobody on it"]


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
