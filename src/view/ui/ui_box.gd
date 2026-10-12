extends StyleBox
## A panel, button or well made of real materials: a frame of one material (bronze, wood, reed,
## marble...) round a face of another, lit from the top left. A raised box has a lit top lip and
## a shadowed foot and casts a soft shadow; a sunk one (a well, a pressed button) has an inner
## shadow under its top edge. Corners can carry studs, rivets, reed bindings or a stitched seam.
## Drawn as vector shading over tiled material textures (src/view/ui/ui_materials.gd), so it
## stays crisp at any UI size. Built by src/view/ui/theme.gd; nothing else needs to know.

const TEXEL := 0.5          # UI pixels per texture pixel: the tiles are painted at twice the size

var face: Texture2D         # the face's material (null: a flat fill)
var face_tint := Color.WHITE
var fill := Color(0, 0, 0, 0)   # a flat fill under the face (or instead of it)
var frame: Texture2D        # the frame's material (null: no frame)
var frame_tint := Color.WHITE
var frame_w := 0.0
var depth := 1              # 1 raised, 0 flat, -1 sunk
var shadow := 0.0           # the soft drop shadow's reach (0: none)
var accent := Color(0, 0, 0, 0)   # a glowing line round the face (hover, focus, the primary button)
var corners := ""           # "stud", "rivet", "bind", "peg", "stitch" or ""
var metal := Color("#b08a48")     # the studs' and bindings' colour
var thread := Color("#e8d8a8")    # the stitching's colour
var edge := Color(0, 0, 0, 0.8)   # the outermost line
var shift := Vector2.ZERO   # where the material tiles start (so neighbours don't match)
var crest: Texture2D        # an ornament cast on the middle of the top edge
var crest_h := 44.0         # its height in UI pixels


func _draw(ci: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	rs.canvas_item_set_default_texture_repeat(ci, RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
	if shadow > 0.0:
		for k in 4:
			var g := shadow * (k + 1) / 4.0
			_rect(ci, rect.grow(g * 0.6).grow_individual(0, -g * 0.2, 0, g * 0.5), Color(0, 0, 0, 0.11))
	var inner := rect.grow(-frame_w)
	if frame != null and frame_w > 0.0:
		_tex(ci, rect, frame, frame_tint)
		_bevel(ci, rect, inner, 0.32, 0.5)
	if fill.a > 0.0:
		_rect(ci, inner, fill)
	if face != null:
		_tex(ci, inner, face, face_tint)
	if depth > 0:
		_quad(ci, inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y),
			Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.07), Color(0, 0, 0, 0.2), Color(0, 0, 0, 0.2))
		var lip := clampf(minf(inner.size.x, inner.size.y) * 0.08, 1.5, 4.0)
		_bevel(ci, inner, inner.grow(-lip), 0.22, 0.42)
	elif depth < 0:
		var d := clampf(inner.size.y * 0.25, 3.0, 12.0)
		_strip(ci, inner, 0, d, Color(0, 0, 0, 0.6))
		_strip(ci, inner, 1, d * 0.6, Color(0, 0, 0, 0.35))
		_strip(ci, inner, 3, d * 0.6, Color(0, 0, 0, 0.25))
		_line(ci, Vector2(inner.position.x, inner.end.y - 0.5), inner.end - Vector2(0, 0.5), Color(1, 1, 1, 0.14), 1.0)
	if frame != null and frame_w > 0.0:
		_outline(ci, inner, Color(0, 0, 0, 0.65), 1.0)
	if accent.a > 0.0:
		_outline(ci, inner.grow(-1.5), accent, 2.0)
		_outline(ci, inner.grow(-3.5), Color(accent, accent.a * 0.3), 2.0)
	_outline(ci, rect.grow(-0.5), edge, 1.0)
	match corners:
		"stud", "rivet", "peg":
			var r := frame_w * (0.55 if corners == "rivet" else 0.8)
			var m := frame_w * 0.5
			for p in [rect.position + Vector2(m, m), Vector2(rect.end.x - m, rect.position.y + m), rect.end - Vector2(m, m), Vector2(rect.position.x + m, rect.end.y - m)]:
				_stud(ci, p, maxf(r, 2.5), metal if corners != "peg" else metal.darkened(0.2))
		"bind":
			_bindings(ci, rect, frame_w)
		"stitch":
			_stitches(ci, rect.grow(-frame_w * 0.5), thread)
	if crest != null:
		var cs := Vector2(crest.get_size()) * (crest_h / crest.get_size().y)
		RenderingServer.canvas_item_add_texture_rect(ci, Rect2(Vector2(rect.get_center().x - cs.x * 0.5, rect.position.y - cs.y * 0.5), cs), crest.get_rid())


## A rectangle filled with a material tile, tinted.
func _tex(ci: RID, r: Rect2, tex: Texture2D, tint: Color) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var span := Vector2(tex.get_size()) * TEXEL
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append((p + shift) / span)
	RenderingServer.canvas_item_add_polygon(ci, pts, PackedColorArray([tint, tint, tint, tint]), uvs, tex.get_rid())


func _rect(ci: RID, r: Rect2, c: Color) -> void:
	RenderingServer.canvas_item_add_rect(ci, r, c)


func _quad(ci: RID, a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([a, b, c, d]), PackedColorArray([ca, cb, cc, cd]))


func _line(ci: RID, a: Vector2, b: Vector2, c: Color, w: float) -> void:
	RenderingServer.canvas_item_add_line(ci, a, b, c, w, true)


func _outline(ci: RID, r: Rect2, c: Color, w: float) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	RenderingServer.canvas_item_add_polyline(ci, pts, PackedColorArray([c]), w, true)


## The light on a band between two rectangles: the top and left lit, the bottom and right in
## shade (light and dark are the strongest alphas, at the outer edge).
func _bevel(ci: RID, o: Rect2, i: Rect2, light: float, dark: float) -> void:
	var o2 := Vector2(o.end.x, o.position.y)
	var o4 := Vector2(o.position.x, o.end.y)
	var i2 := Vector2(i.end.x, i.position.y)
	var i4 := Vector2(i.position.x, i.end.y)
	var hi := Color(1, 0.96, 0.85, light)
	var hi0 := Color(1, 0.96, 0.85, light * 0.25)
	var lo := Color(0, 0, 0, dark)
	var lo0 := Color(0, 0, 0, dark * 0.3)
	_quad(ci, o.position, o2, i2, i.position, hi, hi, hi0, hi0)                 # top
	_quad(ci, o.position, i.position, i4, o4, hi * Color(1, 1, 1, 0.7), hi0, hi0, hi * Color(1, 1, 1, 0.7))   # left
	_quad(ci, o4, i4, i.end, o.end, lo, lo0, lo0, lo)                           # bottom
	_quad(ci, o2, o.end, i.end, i2, lo * Color(1, 1, 1, 0.8), lo * Color(1, 1, 1, 0.8), lo0, lo0)   # right


## An inner shadow along one edge (0 top, 1 left, 2 right, 3 bottom), fading over `d`.
func _strip(ci: RID, r: Rect2, side: int, d: float, c: Color) -> void:
	var c0 := Color(c, 0.0)
	match side:
		0:
			_quad(ci, r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y + d), r.position + Vector2(0, d), c, c, c0, c0)
		1:
			_quad(ci, r.position, r.position + Vector2(d, 0), Vector2(r.position.x + d, r.end.y), Vector2(r.position.x, r.end.y), c, c0, c0, c)
		3:
			_quad(ci, Vector2(r.position.x, r.end.y - d), Vector2(r.end.x, r.end.y - d), r.end, Vector2(r.position.x, r.end.y), c0, c0, c, c)


## A domed stud: a dark seat, the metal, a soft light on its upper left, a glint.
func _stud(ci: RID, p: Vector2, r: float, c: Color) -> void:
	var rs := RenderingServer
	rs.canvas_item_add_circle(ci, p + Vector2(0.6, 1.0), r + 1.2, Color(0, 0, 0, 0.55), true)
	rs.canvas_item_add_circle(ci, p, r, c.darkened(0.35), true)
	rs.canvas_item_add_circle(ci, p - Vector2(r, r) * 0.12, r * 0.8, c, true)
	rs.canvas_item_add_circle(ci, p - Vector2(r, r) * 0.3, r * 0.42, c.lightened(0.35), true)
	rs.canvas_item_add_circle(ci, p - Vector2(r, r) * 0.38, maxf(r * 0.16, 0.8), Color(1, 1, 0.92, 0.85), true)


## Reed frames are lashed at the corners: three turns of cord across each.
func _bindings(ci: RID, r: Rect2, w: float) -> void:
	var cord := metal
	for corner in [r.position, Vector2(r.end.x - w * 2.0, r.position.y), Vector2(r.position.x, r.end.y - w * 2.0), r.end - Vector2(w * 2.0, w * 2.0)]:
		for k in 3:
			var o: Vector2 = corner + Vector2(0, w * (0.35 + k * 0.6))
			_line(ci, o + Vector2(0, 1.2), o + Vector2(w * 2.0, w * 0.6 + 1.2), Color(0, 0, 0, 0.5), maxf(w * 0.32, 1.5))
			_line(ci, o, o + Vector2(w * 2.0, w * 0.6), cord, maxf(w * 0.3, 1.4))
			_line(ci, o - Vector2(0, 0.6), o + Vector2(w * 2.0, w * 0.6 - 0.6), cord.lightened(0.3), maxf(w * 0.1, 0.8))


## A running stitch round the frame: short dashes of thread, each with a little shadow.
func _stitches(ci: RID, r: Rect2, c: Color) -> void:
	var dash := 6.0
	var gap := 5.0
	var sides := [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
		[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]
	for s in sides:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var length := a.distance_to(b)
		var dir := (b - a) / maxf(length, 1.0)
		var t := gap * 0.5
		while t + dash < length:
			var p := a + dir * t
			_line(ci, p + Vector2(0.6, 0.9), p + dir * dash + Vector2(0.6, 0.9), Color(0, 0, 0, 0.5), 1.6)
			_line(ci, p, p + dir * dash, c, 1.4)
			t += dash + gap
