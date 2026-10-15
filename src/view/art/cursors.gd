extends RefCounted
## Mouse cursors per action, from authored SVG art (assets/art/cursors/): the plain
## pointer, move, forage (bug bushes), chop (reeds), build (your foundations), rally
## (a selected building) and attack (enemies). `use` swaps the hardware cursor only when
## the action changes.

const DIR := "res://assets/art/cursors/"
## name -> hotspot, in the 32 x 32 art
const HOTSPOT := {"pointer": Vector2(3, 2), "move": Vector2(3, 2), "forage": Vector2(16, 18),
	"chop": Vector2(6, 13), "mine": Vector2(7, 19), "build": Vector2(7, 8), "rally": Vector2(7, 29), "attack": Vector2(3, 3)}

var images := {}
var current := ""
var scale := 1.0


const SIZE := 0.65   # the art is 32 px; drawn at about 21 px a screen point (Dominic: "massive")


## Tool cursors get a small pointer at their top left, its tip the hotspot, so you can
## aim them (an axe or basket alone has no point; Fable).
const TIPPED := ["forage", "chop", "mine", "build"]
const TIP_SIZE := 0.5   # the pointer, at half size
const TOOL_AT := Vector2(7, 7)   # where the tool sits after the pointer

var hotspots := {}


func _init(p_scale := 1.0) -> void:
	scale = p_scale * SIZE
	for name in HOTSPOT:
		var img := _svg(name, scale)
		hotspots[name] = HOTSPOT[name] * scale
		if name in TIPPED:
			var tip := _svg("pointer", scale * TIP_SIZE)
			var at := Vector2i((TOOL_AT * scale).round())
			var both := Image.create(img.get_width() + at.x, img.get_height() + at.y, false, Image.FORMAT_RGBA8)
			both.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
			both.blend_rect(tip, Rect2i(Vector2i.ZERO, tip.get_size()), Vector2i.ZERO)
			img = both
			hotspots[name] = HOTSPOT.pointer * scale * TIP_SIZE
		images[name] = img


func _svg(name: String, s: float) -> Image:
	var img := Image.new()
	img.load_svg_from_string(FileAccess.get_file_as_string(DIR + name + ".svg"), s)
	img.convert(Image.FORMAT_RGBA8)
	return img


## The cursor's art as a texture (the pad's reticle shows it beside itself).
func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = ImageTexture.create_from_image(images[name])
	return _textures[name]


var _textures := {}


func use(name: String) -> void:
	if name == current:
		return
	current = name
	Input.set_custom_mouse_cursor(images[name], Input.CURSOR_ARROW, hotspots[name])
