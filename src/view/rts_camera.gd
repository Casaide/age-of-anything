extends Camera2D
## RTS camera: WASD/arrows and screen-edge pan, middle-drag pan, wheel zoom
## towards the cursor, kept over the map.

const PAN_SPEED := 900.0     # screen pixels a second
const EDGE_PX := 8.0
const ZOOM_MIN := 0.4
const ZOOM_MAX := 4.0
const ZOOM_STEP := 1.1

var bounds := Rect2()        # canvas rect the camera centre stays inside
var edge_scroll := true
var _dragging := false


func _process(delta: float) -> void:
	var pan := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	if edge_scroll and DisplayServer.window_is_focused():
		var vp := get_viewport().get_visible_rect()
		var m := get_viewport().get_mouse_position()
		if vp.has_point(m):
			pan.x += float(m.x > vp.end.x - EDGE_PX) - float(m.x < EDGE_PX)
			pan.y += float(m.y > vp.end.y - EDGE_PX) - float(m.y < EDGE_PX)
	if pan != Vector2.ZERO:
		position += pan.normalized() * PAN_SPEED * delta / zoom.x
		_clamp()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					zoom_at(ZOOM_STEP, get_global_mouse_position())
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					zoom_at(1.0 / ZOOM_STEP, get_global_mouse_position())
			MOUSE_BUTTON_MIDDLE:
				_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		position -= event.relative / zoom.x
		_clamp()


## Zoom by a factor, keeping the canvas point under the cursor where it is.
func zoom_at(factor: float, point: Vector2) -> void:
	var old := zoom.x
	var z := clampf(old * factor, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(z, z)
	position = point - (point - position) * old / z
	_clamp()


func look_at_point(p: Vector2) -> void:
	position = p
	_clamp()


func _clamp() -> void:
	if bounds.has_area():
		position = position.clamp(bounds.position, bounds.end)
