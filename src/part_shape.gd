extends Node2D
## Draws one part from its vector shape list. Placeholder art: the real art
## pass swaps this for atlas sprites + a palette/team-mask shader, but the
## socket layout, recipes and animation stay the same.
##
## `style` picks how the same shapes are drawn (the art-direction sampler uses
## it): "" is the plain placeholder, "storybook" adds cel shading and ink,
## "paper" makes rough-cut paper pieces, "soft" drops the outlines (painterly base).

const INK := Color("#2b1d14")
const PAPER := Color("#f4ecd8")
const PIN := Color("#b89a5a")

var shapes: Array = []
var colours: Dictionary = {}
var outline := true
var style := ""
var pin := false        # paper style: a brass fastener at the joint (legs, heads)


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
	match style:
		"storybook":
			_draw_storybook()
		"paper":
			_draw_paper()
		_:
			_draw_plain(outline and style != "soft")


func _draw_plain(with_outline: bool) -> void:
	for s in shapes:
		var col: Color = colours.get(s.ch, Color.MAGENTA)
		var edge := col.darkened(0.6)
		match s.t:
			"ellipse":
				var pts := ellipse(v2(s.c), v2(s.r))
				draw_colored_polygon(pts, col)
				if with_outline:
					draw_polyline(closed(pts), edge, 1.0, true)
			"circle":
				draw_circle(v2(s.c), float(s.r), col)
				if with_outline:
					draw_arc(v2(s.c), float(s.r), 0.0, TAU, 20, edge, 1.0, true)
			"poly":
				var pts := points(s.p)
				draw_colored_polygon(pts, col)
				if with_outline:
					draw_polyline(closed(pts), edge, 1.0, true)
			"line":
				var pts := points(s.p)
				if with_outline:
					draw_polyline(pts, edge, float(s.w) + 1.4, true)
				draw_polyline(pts, col, float(s.w), true)


## The outline of a shape as a polygon (lines excluded).
func _outline_of(s: Dictionary, steps := 22) -> PackedVector2Array:
	match s.t:
		"ellipse":
			return ellipse(v2(s.c), v2(s.r), steps)
		"circle":
			return ellipse(v2(s.c), Vector2(float(s.r), float(s.r)), steps)
		"poly":
			return points(s.p)
	return PackedVector2Array()


static func _centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / maxf(1.0, pts.size())


static func _scaled(pts: PackedVector2Array, k: float, shift: Vector2) -> PackedVector2Array:
	var c := _centroid(pts)
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + (p - c) * k + shift)
	return out


## Storybook: a shade base, the colour lit from the top-left, a soft highlight, ink lines.
func _draw_storybook() -> void:
	for s in shapes:
		var col: Color = colours.get(s.ch, Color.MAGENTA)
		if s.t == "line":
			var pts := points(s.p)
			draw_polyline(pts, INK, float(s.w) + 1.8, true)
			draw_polyline(pts, col, float(s.w), true)
			if float(s.w) >= 1.2:
				draw_polyline(_scaled(pts, 1.0, Vector2(-0.3, -0.35)), col.lightened(0.35), maxf(0.5, float(s.w) * 0.3), true)
			continue
		var pts := _outline_of(s)
		if s.ch == "eye":
			draw_colored_polygon(pts, col)
			var r := _centroid(pts).distance_to(pts[0])
			draw_circle(_centroid(pts) + Vector2(-r * 0.35, -r * 0.35), maxf(0.45, r * 0.38), Color(1, 1, 1, 0.9))
			continue
		var size := _centroid(pts).distance_to(pts[0])
		draw_colored_polygon(pts, col.darkened(0.28))
		draw_colored_polygon(_scaled(pts, 0.84, Vector2(-size * 0.1, -size * 0.12)), col)
		if size > 2.5:
			draw_colored_polygon(_scaled(pts, 0.3, Vector2(-size * 0.32, -size * 0.38)), Color(col.lightened(0.45), 0.75))
		draw_polyline(closed(pts), INK, 1.3, true)


## Paper: each piece is cut from coloured paper with a white edge, a little
## rough, casting a shadow; joints are pinned with brass fasteners.
func _draw_paper() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(shapes))
	for s in shapes:
		var col: Color = colours.get(s.ch, Color.MAGENTA)
		col = col.lerp(Color(col.get_luminance(), col.get_luminance(), col.get_luminance()), 0.12)
		if s.t == "line":
			var pts := points(s.p)
			draw_polyline(_scaled(pts, 1.0, Vector2(1.2, 1.8)), Color(0, 0, 0, 0.22), float(s.w) + 2.2)
			draw_polyline(pts, PAPER, float(s.w) + 2.0)
			draw_polyline(pts, col, float(s.w))
			continue
		var pts := _outline_of(s, 26)
		var rough := PackedVector2Array()
		var c := _centroid(pts)
		for p in pts:
			var d := p - c
			rough.append(c + d + d.normalized() * rng.randf_range(-0.45, 0.45))
		var border := _scaled(rough, 1.0, Vector2.ZERO)
		for k in border.size():
			border[k] = c + (border[k] - c) + (border[k] - c).normalized() * 1.1
		draw_colored_polygon(_scaled(border, 1.0, Vector2(1.2, 1.8)), Color(0, 0, 0, 0.22))
		draw_colored_polygon(border, PAPER)
		draw_colored_polygon(rough, col)
	if pin:
		draw_circle(Vector2.ZERO, 1.6, PIN.darkened(0.3))
		draw_circle(Vector2(-0.3, -0.3), 1.1, PIN)
