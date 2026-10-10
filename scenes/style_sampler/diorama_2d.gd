extends Node2D
## One little isometric scene drawn in a given 2D style: terrain, reeds, bug
## bushes, a Town Center and a house, and four units milling about. Used by the
## art-direction sampler. Styles: "storybook", "paper", "soft" (painterly base),
## "pixel" (storybook drawing, pixelated by the panel).

const Iso := preload("res://src/view/iso.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")

const W := 8
const H := 8
## g grass, s swamp, r reeds, b bug bush; T/h mark building footprints (on grass).
const ROWS := [
	"rrrgTTTg",
	"rrggTTTg",
	"rgggTTTg",
	"gggggghh",
	"gggggghh",
	"ssgggggg",
	"sssgggbb",
	"ssssggbb",
]
const GROUND := {"g": ["#6f8f4a", "#688846"], "s": ["#4f6e5a", "#4a6855"], "r": ["#7d8c47", "#76853f"],
	"b": ["#5e7a40", "#587438"], "T": ["#6f8f4a", "#688846"], "h": ["#6f8f4a", "#688846"]}
const INK := Color("#2b1d14")
const PAPER := Color("#f4ecd8")
const WALL := Color("#b98a5c")
const REED := Color("#a6b44c")
const REED_TIP := Color("#6b4a2a")
const BUSH := Color("#4e7a34")
const BUG := Color("#e0607f")

var style := "storybook"
var team := [Color.BLUE, Color.RED]
var ground: Node2D
var layer: Node2D


func build(lib, races: Array, p_style: String) -> void:
	style = p_style
	team = [Color(lib.palettes.teams[0]), Color(lib.palettes.teams[1])]
	ground = Node2D.new()
	ground.draw.connect(_draw_ground)
	add_child(ground)
	layer = Node2D.new()
	layer.y_sort_enabled = true
	add_child(layer)
	for y in H:
		for x in W:
			var ch := _at(x, y)
			if ch == "r" or ch == "b":
				var prop := Node2D.new()
				prop.position = Iso.to_screen(x * 1000 + 500, y * 1000 + 500)
				var kind := ch
				var seed_value := x * 31 + y * 17
				prop.draw.connect(func(): _draw_prop(prop, kind, seed_value))
				layer.add_child(prop)
	_add_building(4, 0, 3, 0, true)
	_add_building(6, 3, 2, 0, false)
	var picks := [[0, 0], [0, 1], [1, 1], [1, 4]]   # [side, roster index]: frog worker, frog spear, rat spear, rat large
	var area := Rect2(Iso.to_screen(3000, 4000) + Vector2(-70, -25), Vector2(120, 55))
	for k in picks.size():
		var u: Dictionary = races[picks[k][0]].units[picks[k][1]]
		var view := UnitView.new()
		view.style = "storybook" if style == "pixel" else style
		view.build(u.recipe, lib, team[picks[k][0]], u.eval.speed)
		view.position = area.position + Vector2(30 + 35 * k, 20 + 12 * (k % 2))
		view.face(1.0 if picks[k][0] == 0 else -1.0)
		view.wander_in(area)
		layer.add_child(view)


func centre() -> Vector2:
	return Iso.to_screen(W * 500, H * 500)


func _at(x: int, y: int) -> String:
	var row: String = ROWS[y]
	return row[x] if x < row.length() and row[x] != " " else "g"


# ------------------------------------------------------------------ ground

func _draw_ground() -> void:
	ground.draw_rect(Rect2(-3000, -3000, 6000, 6000), Color("#2b2620"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in H:
		for x in W:
			var cols: Array = GROUND[_at(x, y)]
			var col := Color(cols[(x + y) & 1])
			var d := _diamond(x, y)
			match style:
				"paper":
					var flat: Color = Color(cols[0])
					ground.draw_colored_polygon(_grow(d, 0.6), flat.lerp(Color(flat.get_luminance(), flat.get_luminance(), flat.get_luminance()), 0.15))
				"soft":
					ground.draw_colored_polygon(d, col)
					for k in 4:
						var p: Vector2 = d[0].lerp(d[2], rng.randf()).lerp(d[1].lerp(d[3], rng.randf()), 0.5)
						ground.draw_circle(p, rng.randf_range(4, 10), Color(col.lightened(rng.randf_range(-0.2, 0.25)), 0.5))
				_:
					ground.draw_colored_polygon(d, col)
					ground.draw_polyline(PackedVector2Array([d[3], d[0], d[1]]), Color(col.lightened(0.18), 0.6), 1.0)
					if _at(x, y) == "g" and rng.randf() < 0.5:
						var p: Vector2 = (d[0] + d[2]) * 0.5 + Vector2(rng.randf_range(-12, 12), rng.randf_range(-4, 4))
						for t in 3:
							ground.draw_line(p + Vector2(t * 2 - 2, 0), p + Vector2(t * 2 - 3 + t, -4), col.darkened(0.25), 1.0)
	if style == "paper":
		# Sheets of one colour; a torn white edge (with a shadow) where the terrain changes.
		var edges := [[0, -1, 0, 1], [1, 0, 1, 2], [0, 1, 2, 3], [-1, 0, 3, 0]]
		for y in H:
			for x in W:
				var here := _ground_kind(x, y)
				var d := _diamond(x, y)
				for e in edges:
					var nx: int = x + e[0]
					var ny: int = y + e[1]
					if nx < 0 or ny < 0 or nx >= W or ny >= H or _ground_kind(nx, ny) == here:
						continue
					var a: Vector2 = d[e[2]]
					var b: Vector2 = d[e[3]]
					var torn := PackedVector2Array()
					for k in 7:
						torn.append(a.lerp(b, k / 6.0) + Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8)))
					ground.draw_polyline(_shift(torn, Vector2(1.2, 1.8)), Color(0, 0, 0, 0.2), 2.5)
					ground.draw_polyline(torn, PAPER, 2.0)
		# Fold the edge of the board under, like a cut sheet.
		var e := PackedVector2Array([Iso.to_screen(0, H * 1000), Iso.to_screen(W * 1000, H * 1000), Iso.to_screen(W * 1000, 0)])
		ground.draw_polyline(e, PAPER, 3.0)


func _ground_kind(x: int, y: int) -> String:
	var ch := _at(x, y)
	return "g" if ch == "T" or ch == "h" else ch


func _diamond(x: int, y: int) -> PackedVector2Array:
	return PackedVector2Array([Iso.to_screen(x * 1000, y * 1000), Iso.to_screen(x * 1000 + 1000, y * 1000),
		Iso.to_screen(x * 1000 + 1000, y * 1000 + 1000), Iso.to_screen(x * 1000, y * 1000 + 1000)])


func _rough(pts: PackedVector2Array, rng: RandomNumberGenerator, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		for k in 4:
			out.append(a.lerp(b, k / 4.0) + Vector2(rng.randf_range(-amount, amount), rng.randf_range(-amount, amount)))
	return out


func _grow(pts: PackedVector2Array, by: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + (p - c).normalized() * by)
	return out


# ------------------------------------------------------------------ props

func _draw_prop(n: Node2D, kind: String, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if kind == "r":
		for k in 9:
			var base := Vector2(rng.randf_range(-20, 20), rng.randf_range(-7, 7))
			base.x *= 1.0 - absf(base.y) / 14.0
			var top := base + Vector2(rng.randf_range(-3, 3), -rng.randf_range(16, 26))
			match style:
				"paper":
					n.draw_line(base + Vector2(1, 1.5), top + Vector2(1, 1.5), Color(0, 0, 0, 0.2), 3.5)
					n.draw_line(base, top, PAPER, 3.5)
					n.draw_line(base, top, REED, 1.8)
					n.draw_line(top, top + Vector2(0, 5), REED_TIP, 3.0)
				"soft":
					n.draw_line(base, top, REED, 2.2)
					n.draw_line(top, top + Vector2(0, 5), REED_TIP, 3.2)
				_:
					n.draw_line(base, top, INK, 3.6)
					n.draw_line(base, top, REED, 2.0)
					n.draw_line(top + Vector2(0, -0.5), top + Vector2(0, 5.5), INK, 4.6)
					n.draw_line(top, top + Vector2(0, 5), REED_TIP, 3.0)
	else:
		var blobs := [[Vector2(0, -8), 11.0], [Vector2(-8, -6), 8.0], [Vector2(8, -7), 8.0], [Vector2(0, -15), 7.0]]
		for b in blobs:
			match style:
				"paper":
					n.draw_circle(b[0] + Vector2(1.2, 1.8), b[1] + 1.0, Color(0, 0, 0, 0.2))
					n.draw_circle(b[0], b[1] + 1.0, PAPER)
					n.draw_circle(b[0], b[1], BUSH)
				"soft":
					n.draw_circle(b[0], b[1], BUSH)
				_:
					n.draw_circle(b[0], b[1] + 1.2, INK)
		if style == "storybook" or style == "pixel":
			for b in blobs:
				n.draw_circle(b[0], b[1], BUSH)
				n.draw_circle(b[0] + Vector2(-b[1] * 0.3, -b[1] * 0.3), b[1] * 0.45, Color(BUSH.lightened(0.3), 0.8))
		for k in 7:
			var p := Vector2(rng.randf_range(-12, 12), rng.randf_range(-20, -2))
			n.draw_circle(p, 1.8, BUG)
			if style == "storybook":
				n.draw_circle(p + Vector2(-0.5, -0.5), 0.6, Color.WHITE)


# ------------------------------------------------------------------ buildings

func _add_building(cx: int, cy: int, size: int, owner: int, tall: bool) -> void:
	var n := Node2D.new()
	n.position = Iso.to_screen((cx + size) * 1000, (cy + size) * 1000)
	var origin := n.position
	n.draw.connect(func(): _draw_building(n, origin, cx, cy, size, team[owner], tall))
	layer.add_child(n)


func _draw_building(n: Node2D, origin: Vector2, cx: int, cy: int, size: int, roof_col: Color, tall: bool) -> void:
	var t := Iso.to_screen(cx * 1000 + 150, cy * 1000 + 150) - origin
	var r := Iso.to_screen((cx + size) * 1000 - 150, cy * 1000 + 150) - origin
	var b := Iso.to_screen((cx + size) * 1000 - 150, (cy + size) * 1000 - 150) - origin
	var l := Iso.to_screen(cx * 1000 + 150, (cy + size) * 1000 - 150) - origin
	var h := Vector2(0, -(14.0 + size * 7.0))
	var apex := (t + r + b + l) / 4.0 + h + Vector2(0, -(22.0 + size * 9.0 + (8.0 if tall else 0.0)))
	var faces := [
		[[l, b, b + h, l + h], WALL.darkened(0.25)],                       # left wall
		[[b, r, r + h, b + h], WALL],                                      # right wall
		[[r + h, t + h, apex], roof_col.darkened(0.35)],                   # back roof (peeks out)
		[[l + h, b + h, apex], roof_col.darkened(0.15)],                   # front-left roof
		[[b + h, r + h, apex], roof_col.lightened(0.1)],                   # front-right roof
	]
	var door := [l.lerp(b, 0.4), l.lerp(b, 0.62), l.lerp(b, 0.62) + h * 0.6, l.lerp(b, 0.4) + h * 0.6]
	var window := [b.lerp(r, 0.4) + h * 0.35, b.lerp(r, 0.6) + h * 0.35, b.lerp(r, 0.6) + h * 0.7, b.lerp(r, 0.4) + h * 0.7]
	match style:
		"paper":
			for f in faces:
				var pts := PackedVector2Array(f[0])
				n.draw_colored_polygon(_shift(_grow(pts, 1.5), Vector2(2, 3)), Color(0, 0, 0, 0.2))
			for f in faces:
				var pts := PackedVector2Array(f[0])
				n.draw_colored_polygon(_grow(pts, 1.5), PAPER)
				n.draw_colored_polygon(pts, f[1])
			n.draw_colored_polygon(PackedVector2Array(door), Color("#4a3020"))
			n.draw_colored_polygon(PackedVector2Array(window), Color("#f2d78a"))
		_:
			for f in faces:
				n.draw_colored_polygon(PackedVector2Array(f[0]), f[1])
			n.draw_colored_polygon(PackedVector2Array(door), Color("#4a3020"))
			n.draw_colored_polygon(PackedVector2Array(window), Color("#f2d78a"))
			if style != "soft":
				for f in faces:
					var pts := PackedVector2Array(f[0])
					pts.append(f[0][0])
					n.draw_polyline(pts, INK, 1.4, true)
				# A few plank lines for the storybook look.
				for k in range(1, 4):
					n.draw_line(l + h * (k / 4.0), b + h * (k / 4.0), WALL.darkened(0.45), 1.0)
	if tall:
		var pole := apex + Vector2(0, 2)
		n.draw_line(pole, pole + Vector2(0, -22), INK if style != "soft" else WALL.darkened(0.5), 1.6)
		n.draw_colored_polygon(PackedVector2Array([pole + Vector2(0, -22), pole + Vector2(13, -18), pole + Vector2(0, -14)]), roof_col.lightened(0.15))


static func _shift(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + by)
	return out
