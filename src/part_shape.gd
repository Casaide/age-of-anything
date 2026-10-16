extends Node2D
## Draws one part of a unit as its baked pixel sprite (see ArtKit and PartBaker):
## the sprite for this part id and colour set, from the shared atlas, recoloured
## to the team by the team-mask shader. The part's 2D shapes in parts.json are the
## data contract (they identify the bake and give sockets); they are never drawn.
## A part with no bake is a bug: it warns once and draws a magenta marker.

var shapes: Array = []
var colours: Dictionary = {}
var part_id := ""
var facing := 0         # which of the 8 baked facings to draw (0: the classic three-quarter view)
var front := false      # draw the part's front layer (a body's near arm)
var shade := 1.0:       # extra darkening (the far leg sits in shadow)
	set(v):
		shade = v
		self_modulate.a = v

## bake_key -> {tex: Texture2D, origin: Vector2 (texture px of the part's 0,0), scale: texture px per part unit}
static var baked := {}
## The team colour every part is baked in, swapped for the real team at draw time.
const TEAM_KEY := Color(1, 0, 1)
const ATLAS_WIDTH := 4096   # (2048 made one match's atlas over 11000 px tall, near the GPU's limit)
const ATLAS_PAD := 2
const ATLAS_MAX := 16384   # the tallest texture the GPU takes (the Deck's, a Mac's): taller uploads nothing, and every part draws white

static var atlas: Texture2D = null      # all baked parts in one texture (after build_atlas)
static var use_atlas := true            # benchmark switch
static var team_material: ShaderMaterial = _team_mat()   # (made up front: parts draw before any atlas, from their own textures)


static func _team_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://src/team_mask.gdshader")
	return m

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
	if baked.has(key):
		return   # (made again, its old texture was freed under parts drawing it outside the atlas: white boxes)
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
	return take_atlas(pack_atlas(atlas_images(extras)))


## What an atlas packs: every bake's image, and the extras' (as "extra:" + name).
static func atlas_images(extras := {}) -> Dictionary:
	var images := {}
	for k in baked:
		images[k] = baked[k].img
	for k in extras:
		images["extra:" + k] = extras[k]
	return images


## The images shelf-packed into one: {img, at: key -> Rect2}. Images only, so it can run on a
## worker thread (ArtKit.rebuild_atlas_async: a match's atlas held a frame up for 35 ms).
static func pack_atlas(images: Dictionary) -> Dictionary:
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
	assert(y + row_h <= ATLAS_MAX, "atlas %d px tall: more parts than one texture holds (ArtKit._keep_parts keeps a match to its own)" % (y + row_h))
	var img := Image.create(ATLAS_WIDTH, y + row_h, false, Image.FORMAT_RGBA8)
	var at := {}
	for k in keys:
		var src: Image = images[k]
		var p: Vector2i = places[k] + Vector2i.ONE * ATLAS_PAD
		img.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), p)
		at[k] = Rect2(p, src.get_size())
	return {"img": img, "at": at}


## A packed atlas in use: each bake's region, the texture. Returns the extras' regions. (A bake
## made after it was packed has no region yet: it draws from its own texture until the next.)
static func take_atlas(pack: Dictionary) -> Dictionary:
	var regions := {}
	for k in pack.at:
		if k.begins_with("extra:"):
			regions[k.trim_prefix("extra:")] = pack.at[k]
		elif baked.has(k):
			baked[k].region = pack.at[k]
	atlas = ImageTexture.create_from_image(pack.img)
	return regions


static func front_key(key: String) -> String:
	return key + "#front"


## Bakes and rigs of facing k (k = 0 has no suffix: the three-quarter view everything started with).
static func facing_suffix(k: int) -> String:
	return "" if k == 0 else "#f%d" % k


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


## This part's bake in its facing as it would draw (another id's: `id`), or null.
func bake_of(id := "") -> Variant:
	var key := bake_key(part_id if id == "" else id, shapes, team_neutral(colours))
	if facing != 0 and baked.has(key + facing_suffix(facing)):
		key += facing_suffix(facing)
	return baked.get(front_key(key) if front else key)


## The bottom of a bake's opaque pixels, column by column, in part units from its origin (where a
## leg's foot meets the ground: UnitView keeps the lowest on it as the legs swing).
static func soles(b: Dictionary) -> PackedVector2Array:
	if not b.has("soles"):
		var img: Image = b.img
		var out := PackedVector2Array()
		for x in img.get_width():
			for y in range(img.get_height() - 1, -1, -1):
				if img.get_pixel(x, y).a > 0.5:
					out.append((Vector2(x + 0.5, y + 1.0) - b.origin) / b.scale)
					break
		b["soles"] = out
	return b.soles


func _draw() -> void:
	var key := bake_key(part_id, shapes, team_neutral(colours))
	if facing != 0 and baked.has(key + facing_suffix(facing)):
		key += facing_suffix(facing)   # parts without facings (flat shapes) keep their one view
	var b = baked.get(front_key(key) if front else key)
	if b == null:
		_draw_missing(key)
		return
	draw_set_transform(-b.origin / b.scale, 0.0, Vector2.ONE / b.scale)
	if use_atlas and atlas and b.has("region"):
		draw_texture_rect_region(atlas, Rect2(Vector2.ZERO, b.region.size), b.region)
	else:
		draw_texture(b.tex, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)


static var _warned := {}


## Loud on purpose: a part drawn before it was baked shows as a magenta marker.
func _draw_missing(key: String) -> void:
	if not _warned.has(key):
		_warned[key] = true
		push_warning("PartShape: no bake for %s (bake it before drawing; see ArtKit.bake_units)" % key)
	draw_rect(Rect2(-3, -3, 6, 6), Color.MAGENTA)
	draw_line(Vector2(-3, -3), Vector2(3, 3), Color.BLACK, 1.0)
	draw_line(Vector2(-3, 3), Vector2(3, -3), Color.BLACK, 1.0)
