extends VBoxContainer
## The Wonder countdowns, centred under the top bar, the same for every player: one line per
## standing finished Wonder ("Sewer Rats' Wonder: 7:32") in its owner's team colour, from the
## sim's list (src/sim/match.gd). Hidden while there's none. View only.

const Match := preload("res://src/sim/match.gd")


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 0)


func show_for(w, team_colours: Array) -> void:
	var n: int = w.wonder_ids.size() if Match.hold_ticks(w) > 0 and w.winner < 0 else 0
	visible = n > 0
	position.x = (get_parent().size.x - size.x) / 2   # centred under the top bar
	while get_child_count() < n:
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 6)
		add_child(l)
	for k in get_child_count():
		var l: Label = get_child(k)
		l.visible = k < n
		if k >= n:
			continue
		var secs: int = (Match.ticks_left(w, k) + 19) / 20
		var owner: int = w.wonder_owners[k]
		l.text = "%s Wonder: %d:%02d" % [possessive(w.races[owner].name), secs / 60, secs % 60]
		l.add_theme_color_override("font_color", Color(team_colours[owner]).lightened(0.25))


## "Sewer Rats'", "Frogkin's".
static func possessive(name: String) -> String:
	return name + ("'" if name.ends_with("s") else "'s")
