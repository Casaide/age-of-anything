extends Button
## The lobby's dice: a button whose die tumbles when thrown. tumble() hops it across a few
## bounces, spinning and turning over, with the clatter of dice on a table; while `busy` (the
## race it rolled is still being made) it keeps rocking on its edge, and settles when done.

const Icons := preload("res://src/view/art/icons.gd")
const Audio := preload("res://src/view/audio.gd")

const HOPS := [[0.0, 26.0, 0.16], [0.16, 12.0, 0.12], [0.28, 5.0, 0.09]]   # [start s, height px, length s]
const TUMBLE := 0.42     # seconds of the throw (the clatter runs a little longer)
const TURNS := 1.75      # spins in a throw

var busy := false:
	set(v):
		busy = v
		set_process(true)
var face: TextureRect
var _throw := -1.0       # seconds into a throw, or < 0
var _rock := 0.0


func _init() -> void:
	focus_mode = Control.FOCUS_ALL   # the pad reaches it by focus (milestone 20)
	face = TextureRect.new()
	face.texture = Icons.texture("dice")
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(face)
	resized.connect(_place)
	set_process(false)


func _place() -> void:
	var s := size * 0.72
	face.size = s
	face.pivot_offset = s * 0.5
	face.position = (size - s) * 0.5


## Throw the die: a few hops, spinning and turning over, and the clatter.
func tumble() -> void:
	_throw = 0.0
	set_process(true)
	Audio.of(get_tree()).play("dice_roll")


func _process(delta: float) -> void:
	_place()
	if _throw >= 0.0:
		_throw += delta
		var t := minf(_throw / TUMBLE, 1.0)
		var e := 1.0 - pow(1.0 - t, 3.0)   # fast out of the hand, slowing as it lands
		face.rotation = e * TURNS * TAU
		var turn := cos(e * TAU * 1.5)   # turning over: its face narrows and flips, but stays a die
		face.scale = Vector2(signf(turn + 0.0001) * lerpf(0.55, 1.0, absf(turn)), 1.0)
		var lift := 0.0
		for h in HOPS:
			var u: float = (_throw - h[0]) / h[2]
			if u >= 0.0 and u <= 1.0:
				lift = h[1] * 4.0 * u * (1.0 - u)
		face.position.y -= lift
		if t >= 1.0:
			_throw = -1.0
			face.rotation = 0.0
			face.scale = Vector2.ONE
		return
	if busy:   # rocking on an edge until the race is made
		_rock += delta
		face.rotation = sin(_rock * 9.0) * 0.12
		face.position.y -= absf(sin(_rock * 9.0)) * 2.0
		return
	face.rotation = 0.0
	face.scale = Vector2.ONE
	set_process(false)
