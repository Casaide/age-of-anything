extends Control
## A pad button's badge, drawn (our own, plain and neutral like the Deck's own buttons): a disc
## with a letter for the face buttons, a rounded bar for bumpers and triggers, a ring for a
## stick, a cross with one arm lit for the d-pad, small pills for View and Menu.
## `hint(button, text)` gives a badge and its words in a row, for the pad HUD's hint strip.

const UiTheme := preload("res://src/view/ui/theme.gd")

const FACE := ["A", "B", "X", "Y"]
const BAR := ["LB", "RB", "LT", "RT"]
const STICK := ["LS", "RS", "L3", "R3"]
const DPAD := ["up", "down", "left", "right", "dpad"]
const INK := Color("#2a2219")
const FILL := Color("#ece2c8")
const RIM := Color(0, 0, 0, 0.55)

var button := "A"
var side := 26.0


static func make(b: String, px := 26.0) -> Control:
	var g = load("res://src/view/pad_glyph.gd").new()
	g.button = b
	g.side = px
	g.custom_minimum_size = Vector2(px * (1.5 if b in BAR or b in ["view", "menu"] else 1.0), px)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


static func hint(b: String, text: String, px := 26.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := make(b, px)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(g)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.text_font(true))
	l.add_theme_font_size_override("font_size", roundi(px * 0.7))
	l.add_theme_color_override("font_color", Color("#f2e9d4"))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


func _draw() -> void:
	var s := size
	var c := s * 0.5
	var r := minf(s.x, s.y) * 0.5
	if button in FACE:
		draw_circle(c, r, RIM)
		draw_circle(c, r - 1.5, FILL)
		_letter(button, c, r * 1.15)
	elif button in BAR:
		var trig := button.ends_with("T")
		var box := StyleBoxFlat.new()
		box.bg_color = FILL
		box.border_color = RIM
		box.set_border_width_all(2)
		box.set_corner_radius_all(roundi(r * (0.9 if trig else 0.45)))
		if trig:   # a trigger: rounded on top, flat below
			box.corner_radius_bottom_left = 3
			box.corner_radius_bottom_right = 3
		draw_style_box(box, Rect2(Vector2(0, s.y * 0.12), Vector2(s.x, s.y * 0.76)))
		_letter(button, c, r * 0.95)
	elif button in STICK:
		draw_circle(c, r, RIM)
		draw_circle(c, r - 1.5, FILL)
		draw_arc(c, r * 0.62, 0.0, TAU, 24, INK, 1.5, true)
		_letter(button.left(1) if button.ends_with("S") else button, c, r * (0.95 if button.ends_with("S") else 0.8))
	elif button in DPAD:
		var w := r * 0.62
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var arm := Rect2(c + d * (r - w * 0.5) - Vector2(w, w) * 0.5 + (Vector2.ZERO), Vector2(w, w)).merge(Rect2(c - Vector2(w, w) * 0.5, Vector2(w, w)))
			draw_rect(arm.grow(1.5), RIM)
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var arm := Rect2(c + d * (r - w * 0.5) - Vector2(w, w) * 0.5, Vector2(w, w)).merge(Rect2(c - Vector2(w, w) * 0.5, Vector2(w, w)))
			var lit: bool = {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}.get(button, Vector2.INF) == d
			draw_rect(arm, FILL if lit or button == "dpad" else FILL.darkened(0.55))
	else:   # view / menu: a small pill with two squares or three lines
		var box := StyleBoxFlat.new()
		box.bg_color = FILL
		box.border_color = RIM
		box.set_border_width_all(2)
		box.set_corner_radius_all(roundi(r * 0.8))
		draw_style_box(box, Rect2(Vector2(0, s.y * 0.15), Vector2(s.x, s.y * 0.7)))
		if button == "view":
			var q := r * 0.42
			draw_rect(Rect2(c - Vector2(q * 1.1, q * 0.9), Vector2(q * 1.3, q * 1.1)), INK, false, 1.5)
			draw_rect(Rect2(c - Vector2(q * 0.2, q * 0.2), Vector2(q * 1.3, q * 1.1)), INK)
		else:
			for k in 3:
				var y := c.y + (k - 1) * r * 0.3
				draw_line(Vector2(c.x - r * 0.45, y), Vector2(c.x + r * 0.45, y), INK, 1.6)


func _letter(text: String, c: Vector2, px: float) -> void:
	var font := UiTheme.text_font(true)
	var fs := roundi(px * (0.62 if text.length() > 1 else 0.9))
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(c.x - w * 0.5, c.y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
