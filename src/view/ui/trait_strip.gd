extends HBoxContainer
## A race's bonuses, own research, lacks and notes as one compact line: a small plaque per
## kind with its count ("3 bonuses", "2 lacks"), the full list on hover as a tooltip card, and
## the generator's first note in the room that's left (the notes are half the fun). Fill it
## with show_traits([{title, one, lines, kind}]) (one: the title for a single entry); kinds: "bonus", "own", "lack", "hero", "note"
## (any other kind shows plain). A group with no lines is left out. Used by the lobby
## (scenes/match_setup.gd: _traits builds the groups; another group, a hero, is one more entry).

const UiTheme := preload("res://src/view/ui/theme.gd")
const COLOURS := {"bonus": Color("#a8d878"), "own": Color("#f2c94c"), "hero": Color("#f2c94c"), "lack": Color("#e88a70"), "note": Color("#d8c8a0")}

var look := {}        # the side's culture look (the tooltip cards wear it)
var compact := false
var _note: Label


func _init(is_compact := false) -> void:
	compact = is_compact
	add_theme_constant_override("separation", 6)
	custom_minimum_size.y = 26 if compact else 30


func show_traits(groups: Array) -> void:
	for n in get_children():
		remove_child(n)
		n.queue_free()
	var first_note := ""
	for g in groups:
		if g.lines.is_empty():
			continue
		if g.kind == "note" and first_note == "":
			first_note = g.lines[0]
		add_child(_chip(g))
	_note = UiTheme.label(first_note, "Dim")
	_note.add_theme_font_size_override("font_size", 13 if compact else 15)
	_note.add_theme_color_override("font_color", Color("#e8d8a8"))
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_note.clip_text = true
	_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_note.custom_minimum_size.x = 10
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_note)


func _chip(g: Dictionary) -> Control:
	var chip := Chip.new()
	chip.look = look
	chip.theme_type_variation = "Plaque"
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var n: int = g.lines.size()
	var word: String = g.title.to_lower()
	var l := UiTheme.label(("%d %s" % [n, word]) if n > 1 else _single(g), "Caption")
	l.add_theme_font_size_override("font_size", 12 if compact else 13)
	l.add_theme_color_override("font_color", COLOURS.get(g.kind, Color("#e8d8a8")))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(l)
	var lines := ["[b]%s[/b]" % g.title]
	for line in g.lines:
		lines.append("·  " + String(line))
	chip.tooltip_text = "\n".join(lines)
	return chip


## One entry fits on its plaque as itself when it's short ("Lacks: Mounted Archer line").
static func _single(g: Dictionary) -> String:
	var line := String(g.lines[0])
	return ("%s: %s" % [g.title, line]) if line.length() <= 26 and g.kind != "note" else "1 " + String(g.get("one", g.title)).to_lower()


class Chip extends PanelContainer:
	var look := {}

	func _make_custom_tooltip(for_text: String) -> Object:
		var k: float = get_global_transform_with_canvas().get_scale().x
		return UiTheme.tip_card(for_text, look, k)
