extends RefCounted
## Mouse cursors per action, from authored SVG art (assets/art/cursors/): the plain
## pointer, move, forage (bug bushes), chop (reeds), build (your foundations), rally
## (a selected building) and attack (enemies). `use` swaps the hardware cursor only when
## the action changes.

const DIR := "res://assets/art/cursors/"
## name -> hotspot, in the 32 x 32 art
const HOTSPOT := {"pointer": Vector2(3, 2), "move": Vector2(3, 2), "forage": Vector2(16, 16),
	"chop": Vector2(3, 4), "build": Vector2(3, 7), "rally": Vector2(6, 29), "attack": Vector2(3, 3)}

var images := {}
var current := ""
var scale := 1.0


func _init(p_scale := 1.0) -> void:
	scale = p_scale
	for name in HOTSPOT:
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string(DIR + name + ".svg"), scale)
		images[name] = img


func use(name: String) -> void:
	if name == current:
		return
	current = name
	Input.set_custom_mouse_cursor(images[name], Input.CURSOR_ARROW, HOTSPOT[name] * scale)
