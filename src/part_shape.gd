extends Node2D
## Draws one part from its vector shape list. Placeholder art: the real art
## pass swaps this for atlas sprites + a palette/team-mask shader, but the
## socket layout, recipes and animation stay the same.

var shapes: Array = []
var colours: Dictionary = {}
var outline := true


func setup(shape_list: Array, colour_map: Dictionary) -> void:
	shapes = shape_list
	colours = colour_map
	queue_redraw()


static func v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func points(list: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in list:
		out.append(v2(p))
	return out


static func ellipse(c: Vector2, r: Vector2, steps := 18) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps:
		var a := TAU * i / steps
		out.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return out


static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


func _draw() -> void:
	for s in shapes:
		var col: Color = colours.get(s.ch, Color.MAGENTA)
		var edge := col.darkened(0.6)
		match s.t:
			"ellipse":
				var pts := ellipse(v2(s.c), v2(s.r))
				draw_colored_polygon(pts, col)
				if outline:
					draw_polyline(closed(pts), edge, 1.0, true)
			"circle":
				draw_circle(v2(s.c), float(s.r), col)
				if outline:
					draw_arc(v2(s.c), float(s.r), 0.0, TAU, 20, edge, 1.0, true)
			"poly":
				var pts := points(s.p)
				draw_colored_polygon(pts, col)
				if outline:
					draw_polyline(closed(pts), edge, 1.0, true)
			"line":
				var pts := points(s.p)
				draw_polyline(pts, edge, float(s.w) + 1.4, true)
				draw_polyline(pts, col, float(s.w), true)
