extends StyleBox
## A race's banner: cloth in the culture's colour hanging from a metal rod, cut to the
## culture's shape (swallowtail, pointed, ragged, fringed, tongues, notched, scalloped, square),
## with soft folds, a hem in the side's team colour (the one quiet team mark) and a shadow.
## Used as a PanelContainer's panel, so the race's name sits on the cloth.

const TEXEL := 0.5
const ROD := 7.0     # the rod's thickness

var cloth: Texture2D
var tint := Color.WHITE
var shape := "square"
var trim := Color("#c8a050")    # the hem: the side's team colour
var rod := Color("#b08a48")     # the rod and its finials: the culture's metal
var tail := 26.0                # how far the shape's cuts reach up from the bottom


## The cloth's outline inside r (the rod above it).
func outline(r: Rect2) -> PackedVector2Array:
	var top := r.position.y + ROD * 0.5
	var x0 := r.position.x
	var x1 := r.end.x
	var yb := r.end.y
	var w := x1 - x0
	var pts := PackedVector2Array([Vector2(x0, top), Vector2(x1, top)])
	match shape:
		"swallowtail":
			pts.append_array([Vector2(x1, yb), Vector2(x0 + w * 0.5, yb - tail), Vector2(x0, yb)])
		"pointed":
			pts.append_array([Vector2(x1, yb - tail), Vector2(x0 + w * 0.5, yb), Vector2(x0, yb - tail)])
		"notched":
			pts.append(Vector2(x1, yb))
			for k in [0.72, 0.28]:
				var cx: float = x0 + w * k
				pts.append_array([Vector2(cx + tail * 0.6, yb), Vector2(cx, yb - tail * 0.8), Vector2(cx - tail * 0.6, yb)])
			pts.append(Vector2(x0, yb))
		"tongues":
			var n := 3
			pts.append(Vector2(x1, yb))
			for k in range(n, 0, -1):
				var a := x0 + w * k / n
				var b := x0 + w * (k - 1) / n
				pts.append_array([Vector2(a - w / n * 0.12, yb - tail), Vector2(b + w / n * 0.5, yb), Vector2(b + w / n * 0.12, yb - tail)] if k > 1 else [Vector2(a - w / n * 0.12, yb - tail), Vector2(b + w / n * 0.5, yb)])
			pts.append(Vector2(x0, yb))
		"ragged":
			var steps := int(w / 18.0)
			for k in range(steps, -1, -1):
				var x := x0 + w * k / steps
				var h := fmod(absf(sin(k * 12.9898 + 4.1) * 43758.5453), 1.0)
				pts.append(Vector2(x, yb - tail * 0.15 - tail * 0.7 * h * (0.0 if k == 0 or k == steps else 1.0)))
		"scalloped":
			var bumps := maxi(4, int(w / 60.0))
			pts.append(Vector2(x1, yb - tail * 0.5))
			for k in range(bumps, 0, -1):
				var a := x0 + w * k / bumps
				var b := x0 + w * (k - 1) / bumps
				for s in range(1, 9):
					var t := s / 8.0
					pts.append(Vector2(lerpf(a, b, t), yb - tail * 0.5 + sin(t * PI) * tail * 0.5))
		_:   # square and fringed
			pts.append_array([Vector2(x1, yb - (tail * 0.4 if shape == "fringe" else 0.0)), Vector2(x0, yb - (tail * 0.4 if shape == "fringe" else 0.0))])
	return pts


## The hem: the outline's lower run, pulled in a little (left to right, under the top).
func _hem(pts: PackedVector2Array, inset: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(2, pts.size()):
		out.append(pts[k] + Vector2(0, -inset))
	out.append(pts[pts.size() - 1] + Vector2(0, -inset))
	out.reverse()
	return out


func _draw(ci: RID, r: Rect2) -> void:
	var rs := RenderingServer
	rs.canvas_item_set_default_texture_repeat(ci, RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
	var pts := outline(r)
	var shade := PackedVector2Array()
	for p in pts:
		shade.append(p + Vector2(5, 7))
	rs.canvas_item_add_polygon(ci, shade, PackedColorArray([Color(0, 0, 0, 0.35)]))
	var span := Vector2(cloth.get_size()) * TEXEL
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	for p in pts:
		uvs.append(p / span)
		cols.append(tint)
	rs.canvas_item_add_polygon(ci, pts, cols, uvs, cloth.get_rid())
	# Folds: soft upright bands of light and shade, clipped to the cloth.
	var folds := maxi(3, int(r.size.x / 70.0))
	for k in folds * 2:
		var a := r.position.x + r.size.x * k / (folds * 2)
		var b := r.position.x + r.size.x * (k + 1) / (folds * 2)
		var strip := PackedVector2Array([Vector2(a, r.position.y), Vector2(b, r.position.y), Vector2(b, r.end.y), Vector2(a, r.end.y)])
		var c := Color(1, 0.95, 0.85, 0.07) if k % 2 == 0 else Color(0, 0, 0, 0.13)
		for piece in Geometry2D.intersect_polygons(strip, pts):
			var pc := PackedColorArray()
			for p in piece:
				var t := (p.x - a) / maxf(b - a, 1.0)
				pc.append(Color(c, c.a * sin(t * PI)))
			rs.canvas_item_add_polygon(ci, piece, pc)
	# Light from above, shade at the foot, the hem in the team colour.
	var y0 := r.position.y
	for piece in Geometry2D.intersect_polygons(PackedVector2Array([Vector2(r.position.x, y0), Vector2(r.end.x, y0), Vector2(r.end.x, y0 + 16), Vector2(r.position.x, y0 + 16)]), pts):
		var pc := PackedColorArray()
		for p in piece:
			pc.append(Color(0, 0, 0, 0.45 * (1.0 - (p.y - y0) / 16.0)))
		rs.canvas_item_add_polygon(ci, piece, pc)
	var hem := _hem(pts, 7.0)
	rs.canvas_item_add_polyline(ci, hem, PackedColorArray([Color(0, 0, 0, 0.35)]), 5.0, true)
	rs.canvas_item_add_polyline(ci, hem, PackedColorArray([trim]), 3.0, true)
	var edge := pts.duplicate()
	edge.append(pts[0])
	rs.canvas_item_add_polyline(ci, edge, PackedColorArray([Color(0, 0, 0, 0.6)]), 1.2, true)
	if shape == "fringe":
		var yb := pts[2].y
		var x := r.position.x + 3.0
		while x < r.end.x - 2.0:
			rs.canvas_item_add_line(ci, Vector2(x, yb), Vector2(x + 0.5, yb + tail * 0.4), Color(0, 0, 0, 0.4), 2.2, true)
			rs.canvas_item_add_line(ci, Vector2(x, yb), Vector2(x + 0.5, yb + tail * 0.38), rod.lightened(0.15), 1.6, true)
			x += 4.0
	# The rod across the top, with a finial at each end.
	var ry := r.position.y + ROD * 0.5
	var ra := Vector2(r.position.x - 12, ry)
	var rb := Vector2(r.end.x + 12, ry)
	rs.canvas_item_add_line(ci, ra + Vector2(0, 2), rb + Vector2(0, 2), Color(0, 0, 0, 0.5), ROD, true)
	rs.canvas_item_add_line(ci, ra, rb, rod.darkened(0.25), ROD, true)
	rs.canvas_item_add_line(ci, ra - Vector2(0, ROD * 0.22), rb - Vector2(0, ROD * 0.22), rod.lightened(0.25), ROD * 0.3, true)
	for p in [ra, rb]:
		rs.canvas_item_add_circle(ci, p + Vector2(0.8, 1.5), ROD * 0.95, Color(0, 0, 0, 0.5), true)
		rs.canvas_item_add_circle(ci, p, ROD * 0.9, rod.darkened(0.2), true)
		rs.canvas_item_add_circle(ci, p - Vector2(1.5, 1.5), ROD * 0.45, rod.lightened(0.4), true)
