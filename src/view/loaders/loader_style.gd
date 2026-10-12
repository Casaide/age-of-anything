extends RefCounted
## The loaders' look in one place (the match loader, the lobby's forging veil and dice), so a
## shared UI theme can take it over later: colours, type sizes and the few boxes they draw.
## The palette is the lobby's: warm dark wood, bronze, gold.

const BG := Color("#14100c")
const PANEL := Color("#2a231b")
const EDGE := Color("#6a5a40")
const BRONZE := Color("#a08858")
const GOLD := Color("#f2c94c")
const TEXT := Color("#efe4c8")
const DIM := Color("#b8ad94")
const GRASS := Color("#4e6e2a")
const TROUGH := Color("#120e0a")

const TITLE := 52      # race names
const VS := 40
const HEAD := 15       # small caps headings
const BODY := 17
const TIP := 16

const STAGE_H := 300           # the match loader's stage at its smallest, in UI pixels
const MAX_W := 1500            # the match loader's content at its widest
const STAGE_ZOOM := 2.5        # screen pixels per canvas unit on it
const FADE := 0.6              # seconds the match loader takes to fade into the match
const ARMY_FADE := 0.45        # seconds a lobby army takes to fade in when it's ready
const DIM_ARMY := 0.32         # how bright an army stays while its new one is forged


static func label(text: String, size: int, colour: Color, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", outline)
	return l


static func box(fill: Color, edge: Color, width: int, radius := 4) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = edge
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	b.content_margin_left = 14
	b.content_margin_right = 14
	b.content_margin_top = 10
	b.content_margin_bottom = 10
	return b


## The grass the armies stand on darkens towards the back, so they stand forward.
static func ground_shade() -> Texture2D:
	var g := GradientTexture2D.new()
	g.fill_from = Vector2(0.5, 0.0)
	g.fill_to = Vector2(0.5, 1.0)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.08, 0.02, 0.6))
	grad.set_color(1, Color(0, 0, 0, 0))
	g.gradient = grad
	return g
