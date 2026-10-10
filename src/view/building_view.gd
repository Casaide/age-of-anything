extends Node2D
## Placeholder isometric building: a block on its footprint with a team-coloured
## roof. A foundation is an outline whose walls rise with build progress.
## The node sits at the footprint's front (lowest) corner so it y-sorts with units.

const Iso := preload("res://src/view/iso.gd")

const WALL_LEFT := Color("#6e5238")
const WALL_RIGHT := Color("#8a6a48")
const OUTLINE := Color("#2a2018")

var size_tiles := 1
var height := 24.0
var team := Color.WHITE
var built := 1.0         # 0..1 of construction
var done := true
var corners: Array = []  # top, right, bottom, left of the footprint, relative to position


func setup(cx: int, cy: int, size: int, team_colour: Color, tall: bool) -> void:
	size_tiles = size
	team = team_colour
	height = 14.0 + size * 8.0 + (12.0 if tall else 0.0)
	position = Iso.to_screen((cx + size) * 1000, (cy + size) * 1000)
	corners = [
		Iso.to_screen(cx * 1000, cy * 1000) - position,
		Iso.to_screen((cx + size) * 1000, cy * 1000) - position,
		Vector2.ZERO,
		Iso.to_screen(cx * 1000, (cy + size) * 1000) - position,
	]


func set_state(is_done: bool, fraction: float) -> void:
	if is_done == done and absf(fraction - built) < 0.01:
		return
	done = is_done
	built = fraction
	queue_redraw()


func _draw() -> void:
	var t: Vector2 = corners[0]
	var r: Vector2 = corners[1]
	var b: Vector2 = corners[2]
	var l: Vector2 = corners[3]
	var h := Vector2(0, -height * (built if not done else 1.0))
	if not done:
		draw_colored_polygon(PackedVector2Array([t, r, b, l]), Color(0, 0, 0, 0.18))
	draw_colored_polygon(PackedVector2Array([l, b, b + h, l + h]), WALL_LEFT)
	draw_colored_polygon(PackedVector2Array([b, r, r + h, b + h]), WALL_RIGHT)
	var roof := PackedVector2Array([t + h, r + h, b + h, l + h])
	draw_colored_polygon(roof, team.darkened(0.15) if done else Color(WALL_RIGHT, 0.6))
	var line := PackedVector2Array([l, b, r, r + h, t + h, l + h, l])
	draw_polyline(line, OUTLINE, 1.5)
	draw_line(b, b + h, OUTLINE, 1.5)
	draw_line(b + h, r + h, OUTLINE, 1.0)
	draw_line(b + h, l + h, OUTLINE, 1.0)
	if not done:
		draw_polyline(PackedVector2Array([t, r, b, l, t]), Color(1, 1, 1, 0.5), 1.0)
