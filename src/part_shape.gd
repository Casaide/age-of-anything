extends Node2D
## Draws one part from its vector shape list. Placeholder art: the real art
## pass swaps this for atlas sprites + a palette/team-mask shader, but the
## socket layout, recipes and animation stay the same.
##
## `style` picks how the same shapes are drawn (the art-direction sampler uses
## it): "" is the plain placeholder, "storybook" adds cel shading and ink,
## "paper" makes rough-cut paper pieces, "soft" drops the outlines (painterly base),
## "baked" draws a pre-baked sprite for this part and colour set from `baked`
## (falling back to plain shapes if none was baked).

const INK := Color("#2b1d14")
const PAPER := Color("#f4ecd8")
const PIN := Color("#b89a5a")

var shapes: Array = []
var colours: Dictionary = {}
var outline := true
var style := ""
var pin := false        # paper style: a brass fastener at the joint (legs, heads)
var part_id := ""
var front := false      # baked style: draw the part's front layer (a body's near arm)
var shade := 1.0:       # baked style: extra darkening (the far leg sits in shadow)
	set(v):
		shade = v
		self_modulate.a = v

## bake_key -> {tex: Texture2D, origin: Vector2 (texture px of the part's 0,0), scale: texture px per part unit}
static var baked := {}
## The team colour every part is baked in, swapped for the real team at draw time.
const TEAM_KEY := Color(1, 0, 1)
const ATLAS_WIDTH := 2048
const ATLAS_PAD := 2

static var atlas: Texture2D = null      # all baked parts in one texture (after build_atlas)
static var use_atlas := true            # benchmark switch
static var team_material: ShaderMaterial = null

## part id -> {sockets: {name: Vector2}, anchors: [[x, y, phase, z]], torso_scale: Vector2}
## for parts baked from hand-built models: their sockets as seen by the bake camera.
static var rigs := {}


## Colours with the team channel replaced by the bake key: one bake serves every team.
static func team_neutral(colour_map: Dictionary) -> Dictionary:
	var c := colour_map.duplicate()
	c.team = TEAM_KEY
	return c


## Pack every baked part into one atlas texture (shelf packing, padded), so units
## share a texture and a material and can batch.
## A flat pixel ellipse for a shape list's first ellipse, baked straight into `baked`
## (no 3D needed): unit shadows, so they live in the atlas with everything else.
static func bake_flat(id: String, shape_list: Array, colour_map: Dictionary, art_scale: float) -> void:
	var key := bake_key(id, shape_list, team_neutral(colour_map))
	var e: Dictionary = shape_list[0]
	var c := v2(e.c)
	var r := v2(e.r) * art_scale
	var col: Color = colour_map[e.ch]
	var img := Image.create(ceili(r.x * 2) + 2, ceili(r.y * 2) + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in img.get_height():
		for x in img.get_width():
			var q := (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(1, 1) - r) / r
			if q.length_squared() <= 1.0:
				img.set_pixel(x, y, col)
	baked[key] = {"img": img, "tex": ImageTexture.create_from_image(img), "origin": Vector2(1, 1) + r - c * art_scale, "scale": art_scale}


## extras: name -> Image, packed alongside the parts; returns name -> region.
static func build_atlas(extras := {}) -> Dictionary:
	var images := {}
	for k in baked:
		images[k] = baked[k].img
	for k in extras:
		images["extra:" + k] = extras[k]
	var keys := images.keys()
	keys.sort_custom(func(a, b): return images[a].get_height() > images[b].get_height() or (images[a].get_height() == images[b].get_height() and a < b))
	var x := 0
	var y := 0
	var row_h := 0
	var places := {}
	for k in keys:
		var sz: Vector2i = images[k].get_size() + Vector2i.ONE * ATLAS_PAD * 2
		if x + sz.x > ATLAS_WIDTH:
			x = 0
			y += row_h
			row_h = 0
		places[k] = Vector2i(x, y)
		x += sz.x
		row_h = maxi(row_h, sz.y)
	var img := Image.create(ATLAS_WIDTH, y + row_h, false, Image.FORMAT_RGBA8)
	var regions := {}
	for k in keys:
		var src: Image = images[k]
		var at: Vector2i = places[k] + Vector2i.ONE * ATLAS_PAD
		img.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)
		if baked.has(k):
			baked[k].region = Rect2(at, src.get_size())
		else:
			regions[k.trim_prefix("extra:")] = Rect2(at, src.get_size())
	atlas = ImageTexture.create_from_image(img)
	if team_material == null:
		team_material = ShaderMaterial.new()
		team_material.shader = load("res://src/team_mask.gdshader")
	return regions


static func front_key(key: String) -> String:
	return key + "#front"


## Identifies a part as drawn in particular colours (team, skin and cloth are baked in).
static func bake_key(id: String, shape_list: Array, colour_map: Dictionary) -> String:
	var chans := {}
	for s in shape_list:
		chans[s.ch] = true
	var names := chans.keys()
	names.sort()
	return id + ":" + ",".join(names.map(func(c): return "%s=%s" % [c, colour_map.get(c, Color.MAGENTA).to_html(false)]))


func setup(shape_list: Array, colour_map: Dictionary) -> void:
	shapes = shape_list
	colours = colour_map
	if style == "baked":
		var team: Color = colours.get("team", Color.WHITE)
		self_modulate = Color(team.r, team.g, team.b, shade)
		if team_material:
			material = team_material
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
		"baked":
			var key := bake_key(part_id, shapes, team_neutral(colours))
			var b = baked.get(front_key(key) if front else key)
			if b == null:
				_draw_plain(outline)
				return
			draw_set_transform(-b.origin / b.scale, 0.0, Vector2.ONE / b.scale)
			if use_atlas and atlas and b.has("region"):
				draw_texture_rect_region(atlas, Rect2(Vector2.ZERO, b.region.size), b.region)
			else:
				draw_texture(b.tex, Vector2.ZERO)
			draw_set_transform(Vector2.ZERO)
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
