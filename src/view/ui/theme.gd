extends RefCounted
## The game's UI look, in one place: every screen (title menu, lobby, loaders, HUD, pause and end
## screens, tech tree page) takes its Theme, boxes and type from here, so one change reaches all.
##
## A look is a direction (data/ui.json: the neutral look of the menus) with a culture's `ui`
## block from data/families.json laid over it, so your race's HUD and lobby banner wear its
## culture: frame material and colour, accent, crest, the cut of its banner, and (in the timber
## direction) its own panel material. look("") is the neutral look.
##
## Materials are painted in code (ui_materials.gd), boxes are vector-lit frames and faces
## (ui_box.gd), banners are cloth (ui_banner.gd), crests are SVGs (assets/art/ui/, written by
## tools/ui/crests.py). Type: a display face for titles and a text face for everything else.
## Fonts dropped into assets/fonts/ (display.ttf, text.ttf, text_bold.ttf, with their licence)
## win; until then the display face comes from the system's serifs and the text face is Godot's.
##
## Buttons get weight: a hover tick and lift, a press sound and sink (juice()).

const UiBox := preload("res://src/view/ui/ui_box.gd")
const UiBanner := preload("res://src/view/ui/ui_banner.gd")
const Mat := preload("res://src/view/ui/ui_materials.gd")
const DataLib := preload("res://src/data_lib.gd")
const Audio := preload("res://src/view/audio.gd")

const FONT_DIR := "res://assets/fonts/"
const DISPLAY_SYSTEM := ["Cinzel", "Trajan Pro", "Palatino", "Palatino Linotype", "Book Antiqua", "Baskerville", "Georgia", "serif"]
const CORNERS := {"bronze": "stud", "gold": "stud", "lacquer": "stud", "iron": "rivet", "reed": "bind", "leather": "stitch",
	"felt": "stitch", "wood": "peg", "bone": "peg", "marble": "", "stone": "", "sandstone": "", "parchment": ""}
const IDENTITY := ["frame", "frame_colour", "accent", "metal", "thread", "ornament", "banner", "primary", "primary_colour"]
const FACES := ["panel", "colour", "button", "button_colour"]

static var direction := ""      # "" = data/ui.json's choice; the mocks and Dominic can switch it
static var _data := {}
static var _families := {}
static var _fonts := {}
static var _crests := {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = DataLib.load_json("res://data/ui.json")
		_families = DataLib.load_json("res://data/families.json")
	return _data


## The look for a culture ("" for the neutral look of the menus). Colours come back as Colors.
static func look(family := "") -> Dictionary:
	var d := data()
	var dir: String = direction if direction != "" else d.direction
	var raw: Dictionary = d.directions[dir].duplicate()
	var fam: Dictionary = _families.get(family, {})
	var ui: Dictionary = fam.get("ui", {})
	for k in IDENTITY:
		if ui.has(k):
			raw[k] = ui[k]
	if raw.culture_faces:
		for k in FACES:
			if ui.has(k):
				raw[k] = ui[k]
	var lk := {"direction": dir, "family": family}
	for k in raw:
		var v = raw[k]
		lk[k] = Color(v) if v is String and v.begins_with("#") else v
	lk.thread = lk.get("thread", lk.metal.lightened(0.4))
	lk.cloth = Color(fam.cloth[0]) if fam.has("cloth") else lk.colour.lightened(0.15)
	lk.corners = CORNERS[lk.frame]
	lk.light_face = lk.colour.get_luminance() > 0.5
	return lk


# ------------------------------------------------------------------ type

## The display face (titles, race names, big buttons).
static func display_font() -> Font:
	if not _fonts.has("display"):
		var f: Font
		if FileAccess.file_exists(FONT_DIR + "display.ttf"):
			var ff := FontFile.new()   # loaded raw, so headless --script runs need no editor import
			ff.load_dynamic_font(FONT_DIR + "display.ttf")
			var v := FontVariation.new()   # Cinzel is a variable font: a semi-bold weight for titles
			v.base_font = ff
			v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
			v.fallbacks = [ThemeDB.fallback_font]
			f = v
		else:
			var s := SystemFont.new()
			s.font_names = PackedStringArray(DISPLAY_SYSTEM)
			s.font_weight = 600
			s.fallbacks = [ThemeDB.fallback_font]
			f = s
		_fonts.display = f
	return _fonts.display


## The text face; bold for names and buttons.
static func text_font(bold := false) -> Font:
	var key := "text_bold" if bold else "text"
	if not _fonts.has(key):
		var f: Font
		if FileAccess.file_exists(FONT_DIR + key + ".ttf"):
			var ff := FontFile.new()
			ff.load_dynamic_font(FONT_DIR + key + ".ttf")
			f = ff
		elif bold:
			var v := FontVariation.new()
			v.base_font = ThemeDB.fallback_font
			v.variation_embolden = 0.6
			f = v
		else:
			f = ThemeDB.fallback_font
		_fonts[key] = f
	return _fonts[key]


## Captions: the text face in small spaced capitals.
static func caps_font() -> Font:
	if not _fonts.has("caps"):
		var v := FontVariation.new()
		v.base_font = text_font(true)
		v.spacing_glyph = 2
		_fonts.caps = v
	return _fonts.caps


# ------------------------------------------------------------------ boxes

static func _box(lk: Dictionary) -> UiBox:
	var b := UiBox.new()
	b.metal = lk.metal
	b.thread = lk.thread
	return b


static func _margins(b: StyleBox, h: float, v: float) -> StyleBox:
	b.content_margin_left = h
	b.content_margin_right = h
	b.content_margin_top = v
	b.content_margin_bottom = v
	return b


## The heavy frame of a main panel: the culture's frame material round its face, studs at the
## corners, a soft shadow; with crest, the culture's crest sits on the top edge.
static func frame_box(lk: Dictionary, crest := false, weight := 10.0) -> StyleBox:
	var b := _box(lk)
	b.frame = Mat.texture(lk.frame, lk.frame_colour)
	b.frame_w = weight
	b.face = Mat.texture(lk.panel, lk.colour)
	b.corners = lk.corners
	b.shadow = 12.0
	if crest:
		b.crest = crest_texture(lk)
	return _margins(b, weight + 14, weight + 12)


## A card inside a panel: a thin frame, the face a shade lighter.
static func card_box(lk: Dictionary) -> StyleBox:
	var b := _box(lk)
	b.frame = Mat.texture(lk.frame, lk.frame_colour)
	b.frame_tint = Color(0.85, 0.85, 0.85)
	b.frame_w = 3.0
	b.face = Mat.texture(lk.panel, lk.colour)
	b.face_tint = Color(1.08, 1.08, 1.08)
	b.shadow = 4.0
	return _margins(b, 12, 9)


## A well sunk into the panel (the army's stage, the map, the queue).
static func well_box(lk: Dictionary) -> StyleBox:
	var b := _box(lk)
	b.fill = lk.well
	b.face = Mat.texture(lk.panel, lk.colour)
	b.face_tint = Color(0.38, 0.38, 0.38)
	b.depth = -1
	b.frame = Mat.texture(lk.frame, lk.frame_colour)
	b.frame_tint = Color(0.7, 0.7, 0.7)
	b.frame_w = 2.0
	return _margins(b, 10, 8)


## A button. state: normal, hover, pressed, disabled. primary: the centrepiece (Start).
static func button_box(lk: Dictionary, state: String, primary := false) -> StyleBox:
	var b := _box(lk)
	var face_mat: String = lk.primary if primary else lk.button
	var face_col: Color = lk.primary_colour if primary else lk.button_colour
	b.frame = Mat.texture(lk.frame, lk.frame_colour)
	b.frame_w = 6.0 if primary else 3.0
	b.face = Mat.texture(face_mat, face_col)
	b.shadow = 8.0 if primary else 4.0
	b.corners = lk.corners if primary else ""
	match state:
		"hover":
			b.face_tint = Color(1.22, 1.18, 1.1)
			b.accent = Color(lk.accent, 0.85)
		"pressed":
			b.face_tint = Color(0.8, 0.78, 0.74)
			b.depth = -1
			b.shadow = 0.0
			b.accent = Color(lk.accent, 0.6)
		"disabled":
			b.face_tint = Color(0.5, 0.5, 0.52)
			b.depth = 0
			b.shadow = 0.0
			b.frame_tint = Color(0.6, 0.6, 0.6)
	if primary and state == "normal":
		b.accent = Color(lk.accent, 0.45)
	var pad := 8.0 if primary else 4.0
	_margins(b, b.frame_w + 12, b.frame_w + pad)
	if state == "pressed":
		b.content_margin_top += 1.5
		b.content_margin_bottom -= 1.5
	return b


## A text field: a well with a lit rim when focused.
static func field_box(lk: Dictionary, focus: bool) -> StyleBox:
	var b := well_box(lk)
	b.face_tint = Color(0.3, 0.3, 0.3)
	if focus:
		b.accent = Color(lk.accent, 0.8)
	return _margins(b, 14, 8)


## A tooltip card: dark, a metal rim.
static func tip_box(lk: Dictionary, k := 1.0) -> StyleBox:
	var b := _box(lk)
	b.frame = Mat.texture(lk.frame, lk.frame_colour)
	b.frame_w = 3.0 * k
	b.face = Mat.texture(lk.panel, lk.colour)
	b.face_tint = Color(0.65, 0.65, 0.65)
	b.shadow = 10.0 * k
	return _margins(b, 14 * k, 10 * k)


## A tooltip card: the title (bold) in the display face, the text a size up from the old cards.
## k: the HUD's scale (tooltips are popups outside the scaled HUD, so they size themselves).
static func tip_card(bbcode: String, lk: Dictionary, k := 1.0) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", tip_box(lk, k))
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size.x = 330 * k
	text.add_theme_font_override("normal_font", text_font())
	text.add_theme_font_override("bold_font", display_font())
	text.add_theme_font_size_override("normal_font_size", roundi(15 * k))
	text.add_theme_font_size_override("bold_font_size", roundi(20 * k))
	text.add_theme_color_override("default_color", Color("#efe4c8"))
	text.add_theme_constant_override("line_separation", roundi(1 * k))
	text.text = bbcode
	card.add_child(text)
	return card


## A bar's fill: the accent, lit like a rod of metal.
static func bar_fill(c: Color) -> StyleBox:
	var b := UiBox.new()
	b.fill = c
	b.depth = 1
	b.edge = Color(0, 0, 0, 0.6)
	return b


static func bar_back(lk: Dictionary) -> StyleBox:
	var b := UiBox.new()
	b.fill = Color(0, 0, 0, 0.6)
	b.depth = -1
	b.edge = Color(0, 0, 0, 0.7)
	return b


## A race's banner: its culture's cloth and cut, the hem in its side's colour.
static func banner_box(lk: Dictionary, team: Color) -> StyleBox:
	var b := UiBanner.new()
	b.cloth = Mat.texture("felt", lk.cloth)
	var lum: float = lk.cloth.get_luminance()
	if lum > 0.4:   # pale cloth darkened, so the race's name in gold still stands off it
		b.tint = Color.WHITE * (0.4 / lum + 0.1)
		b.tint.a = 1.0
	b.shape = lk.banner
	b.trim = team
	b.rod = lk.metal
	b.content_margin_left = 22
	b.content_margin_right = 22
	b.content_margin_top = 16
	b.content_margin_bottom = b.tail + 12
	return b


## The culture's crest, cast in its metal.
static func crest_texture(lk: Dictionary) -> Texture2D:
	var key := "%s:%s" % [lk.ornament, lk.metal.to_html()]
	if not _crests.has(key):
		var svg := FileAccess.get_file_as_string("res://assets/art/ui/crest_%s.svg" % lk.ornament)
		var m: Color = lk.metal
		svg = svg.replace("{L}", "#" + m.lightened(0.55).to_html(false)).replace("{M}", "#" + m.to_html(false)).replace("{D}", "#" + m.darkened(0.6).to_html(false))
		var img := Image.new()
		img.load_svg_from_string(svg, 2.0)
		_crests[key] = ImageTexture.create_from_image(img)
	return _crests[key]


# ------------------------------------------------------------------ the Theme

## The whole Theme for a look at a base type size (UI pixels).
static func theme(lk: Dictionary, base := 20) -> Theme:
	var t := Theme.new()
	t.default_font = text_font()
	t.default_font_size = base
	var text: Color = lk.text
	var shadow := Color(0, 0, 0, 0.0 if lk.light_face else 0.55)
	# Labels: plain text, and the variations screens use by name.
	t.set_color("font_color", "Label", text)
	t.set_color("font_shadow_color", "Label", shadow)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_constant("shadow_offset_x", "Label", 0)
	_label_kind(t, "Title", display_font(), roundi(base * 2.3), lk.title, 3)
	_label_kind(t, "Heading", display_font(), roundi(base * 1.35), lk.title, 2)
	_label_kind(t, "Caption", caps_font(), roundi(base * 0.72), lk.metal.lightened(0.25), 1)
	_label_kind(t, "Dim", text_font(), roundi(base * 0.85), lk.dim, 1)
	_label_kind(t, "Name", text_font(true), base, text, 1)
	t.set_color("font_outline_color", "Title", Color(0, 0, 0, 0.75))
	t.set_constant("outline_size", "Title", maxi(4, base / 4))
	# Buttons.
	for kind in ["Button", "PrimaryButton", "OptionButton"]:
		var primary: bool = kind == "PrimaryButton"
		if primary:
			t.set_type_variation(kind, "Button")
		for state in ["normal", "hover", "pressed", "disabled"]:
			t.set_stylebox(state, kind, button_box(lk, state, primary))
		t.set_stylebox("hover_pressed", kind, button_box(lk, "pressed", primary))
		t.set_stylebox("focus", kind, StyleBoxEmpty.new())
		t.set_font("font", kind, display_font() if primary else text_font(true))
		t.set_font_size("font_size", kind, roundi(base * (1.55 if primary else 1.0)))
		var fc: Color = lk.title if primary else text
		t.set_color("font_color", kind, fc)
		t.set_color("font_hover_color", kind, fc.lightened(0.3))
		t.set_color("font_pressed_color", kind, lk.accent)
		t.set_color("font_hover_pressed_color", kind, lk.accent)
		t.set_color("font_disabled_color", kind, Color(lk.dim, 0.5))
		t.set_color("font_outline_color", kind, Color(0, 0, 0, 0.6))
		t.set_constant("outline_size", kind, 4 if primary else 2)
		t.set_color("icon_normal_color", kind, Color.WHITE)
		t.set_color("icon_hover_color", kind, Color(1.15, 1.12, 1.05))
	# The option picker and its list.
	t.set_stylebox("panel", "PopupMenu", card_box(lk))
	t.set_stylebox("hover", "PopupMenu", button_box(lk, "hover"))
	t.set_color("font_color", "PopupMenu", text)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_font_size("font_size", "PopupMenu", base)
	# Text fields.
	t.set_stylebox("normal", "LineEdit", field_box(lk, false))
	t.set_stylebox("focus", "LineEdit", field_box(lk, true))
	t.set_color("font_color", "LineEdit", Color("#f6ecd2"))
	t.set_color("font_placeholder_color", "LineEdit", Color(lk.dim if not lk.light_face else Color("#c4b493"), 0.75))
	t.set_color("caret_color", "LineEdit", lk.accent)
	t.set_color("selection_color", "LineEdit", Color(lk.accent, 0.35))
	# Panels.
	t.set_stylebox("panel", "PanelContainer", frame_box(lk))
	for kind in ["Frame", "CrestFrame", "Card", "Well"]:
		t.set_type_variation(kind, "PanelContainer")
	t.set_stylebox("panel", "Frame", frame_box(lk))
	t.set_stylebox("panel", "CrestFrame", frame_box(lk, true))
	t.set_stylebox("panel", "Card", card_box(lk))
	t.set_stylebox("panel", "Well", well_box(lk))
	# The HUD's pieces: the top bar's beam, plaques for numbers, square icon buttons, slots.
	for kind in ["Bar", "Plaque", "Slot"]:
		t.set_type_variation(kind, "PanelContainer")
	var beam: UiBox = frame_box(lk, false, 6.0)
	_margins(beam, 16, 9)
	beam.shadow = 8.0
	t.set_stylebox("panel", "Bar", beam)
	var plaque: StyleBox = well_box(lk)
	_margins(plaque, 8, 2)
	t.set_stylebox("panel", "Plaque", plaque)
	var slot: StyleBox = well_box(lk)
	_margins(slot, 2, 2)
	t.set_stylebox("panel", "Slot", slot)
	t.set_type_variation("Hud", "PanelContainer")   # the command panel: a lighter frame, the crest on top
	var hud: UiBox = frame_box(lk, true, 8.0)
	hud.crest_h = 36.0
	_margins(hud, 16, 12)
	hud.content_margin_top = 16
	t.set_stylebox("panel", "Hud", hud)
	t.set_type_variation("IconButton", "Button")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var ib: StyleBox = button_box(lk, state)
		_margins(ib, 4, 4)
		t.set_stylebox(state, "IconButton", ib)
	var ip: StyleBox = button_box(lk, "pressed")
	_margins(ip, 4, 4)
	t.set_stylebox("hover_pressed", "IconButton", ip)
	t.set_stylebox("focus", "IconButton", StyleBoxEmpty.new())
	t.set_type_variation("Accent", "Button")   # a button with the accent's rim (the age-up)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var ab: UiBox = button_box(lk, state)
		_margins(ab, 4, 4)
		if state == "normal":
			ab.accent = Color(lk.accent, 0.7)
		t.set_stylebox(state, "Accent", ab)
	t.set_stylebox("focus", "Accent", StyleBoxEmpty.new())
	# Tooltips.
	t.set_stylebox("panel", "TooltipPanel", tip_box(lk))
	t.set_color("font_color", "TooltipLabel", Color("#efe4c8"))
	t.set_font_size("font_size", "TooltipLabel", roundi(base * 0.85))
	# Bars.
	t.set_stylebox("background", "ProgressBar", bar_back(lk))
	t.set_stylebox("fill", "ProgressBar", bar_fill(lk.accent))
	# Rich text.
	t.set_color("default_color", "RichTextLabel", text)
	t.set_font("normal_font", "RichTextLabel", text_font())
	t.set_font("bold_font", "RichTextLabel", text_font(true))
	t.set_font_size("normal_font_size", "RichTextLabel", base)
	t.set_font_size("bold_font_size", "RichTextLabel", base)
	t.set_font_size("italics_font_size", "RichTextLabel", base)
	# Scroll bars: a metal grabber in a groove.
	for kind in ["HScrollBar", "VScrollBar"]:
		var grab := _box(lk)
		grab.frame = Mat.texture(lk.frame, lk.frame_colour)
		grab.frame_w = 2.0
		grab.face = Mat.texture(lk.frame, lk.frame_colour)
		grab.face_tint = Color(0.9, 0.9, 0.9)
		_margins(grab, 5, 5)
		t.set_stylebox("grabber", kind, grab)
		var hl: UiBox = grab.duplicate()
		hl.accent = Color(lk.accent, 0.7)
		t.set_stylebox("grabber_highlight", kind, hl)
		t.set_stylebox("grabber_pressed", kind, hl)
		t.set_stylebox("scroll", kind, _margins(bar_back(lk), 5, 5))
	return t


static func _label_kind(t: Theme, kind: String, font: Font, size: int, colour: Color, shadow_y: int) -> void:
	t.set_type_variation(kind, "Label")
	t.set_font("font", kind, font)
	t.set_font_size("font_size", kind, size)
	t.set_color("font_color", kind, colour)
	t.set_color("font_shadow_color", kind, Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_y", kind, shadow_y)


## A label of a kind ("Title", "Heading", "Caption", "Dim", "Name" or "" for plain text).
static func label(text: String, kind := "", wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = kind
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A button with weight; primary is the screen's centrepiece.
static func button(text: String, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.theme_type_variation = "PrimaryButton"
	juice(b)
	return b


## Weight for a button: a soft tick and a small lift on hover, a click and a sink on press.
static func juice(b: BaseButton, click := true) -> void:
	if b.has_meta("juiced"):
		return
	b.set_meta("juiced", true)
	b.mouse_entered.connect(func():
		if b.disabled or not b.is_inside_tree():
			return
		Audio.of(b.get_tree()).play("ui_hover")
		_pop(b, 1.035))
	b.mouse_exited.connect(func(): _pop(b, 1.0))
	b.button_down.connect(func(): _pop(b, 0.97))
	b.button_up.connect(func(): _pop(b, 1.035 if b.is_hovered() else 1.0))
	if click:
		b.pressed.connect(func(): Audio.of(b.get_tree()).play("ui_click"))


## Weight for every button under root, now and as they're made (panels rebuild their buttons).
static func juice_all(root: Node) -> void:
	for n in root.find_children("*", "BaseButton", true, false):
		juice(n)
	root.get_tree().node_added.connect(func(n: Node):
		if n is BaseButton and is_instance_valid(root) and root.is_ancestor_of(n):
			juice(n))


static func _pop(c: Control, to: float) -> void:
	if not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.set_trans(Tween.TRANS_BACK if to > 1.0 else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE * to, 0.12)


## A screen or page arriving: a quick fade and a short rise (~0.2 s).
static func arrive(c: Control, rise := 14.0) -> void:
	c.modulate.a = 0.0
	var to := c.position
	c.position.y += rise
	var tw := c.create_tween().set_parallel()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.2)
	tw.tween_property(c, "position:y", to.y, 0.24)


## A separator: an engraved line with a small lozenge at its middle.
class Rule extends Control:
	var colour := Color("#c09048")

	func _init(c := Color("#c09048")) -> void:
		colour = c
		custom_minimum_size.y = 12
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := floorf(size.y * 0.5)
		var m := size.x * 0.5
		draw_line(Vector2(6, y + 1), Vector2(size.x - 6, y + 1), Color(0, 0, 0, 0.55), 1.0)
		draw_line(Vector2(6, y), Vector2(size.x - 6, y), Color(colour, 0.7), 1.0)
		var d := 4.5
		var pts := PackedVector2Array([Vector2(m, y - d), Vector2(m + d, y), Vector2(m, y + d), Vector2(m - d, y)])
		draw_colored_polygon(pts, colour)
		pts.append(pts[0])
		draw_polyline(pts, Color(0, 0, 0, 0.6), 1.0)


## A round cast medallion with a word on it (the lobby's "vs").
class Medallion extends Control:
	var lk: Dictionary
	var word := "VS"

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 4.0
		var m: Color = lk.metal
		draw_circle(c + Vector2(2, 4), r + 3, Color(0, 0, 0, 0.45))
		draw_circle(c, r, m.darkened(0.45))
		draw_circle(c - Vector2(0.8, 1.2), r - 2.5, m)
		draw_circle(c + Vector2(0.8, 1.6), r - 7, m.darkened(0.35))
		draw_circle(c, r - 8, lk.primary_colour.darkened(0.2))
		draw_arc(c, r - 8, 0, TAU, 64, Color(0, 0, 0, 0.6), 2.0, true)
		draw_arc(c, r - 1.5, PI * 1.05, PI * 1.6, 24, Color(1, 1, 0.9, 0.55), 2.0, true)
		for k in 12:
			var a := TAU * k / 12.0
			var p := c + Vector2(cos(a), sin(a)) * (r - 4.0)
			draw_circle(p + Vector2(0.4, 0.8), 2.2, Color(0, 0, 0, 0.5))
			draw_circle(p, 1.8, m.lightened(0.3))
		var font: Font = load("res://src/view/ui/theme.gd").display_font()
		var fs := int(r * 0.9)
		var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := c + Vector2(-w * 0.5, fs * 0.34)
		draw_string(font, base + Vector2(0, 3), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6))
		draw_string(font, base, word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lk.title)
