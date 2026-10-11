extends SubViewport
## Bakes 3D models into 2D sprites, the classic pre-render pipeline in-engine:
## an orthographic camera at our 2:1 isometric angle, a key/fill/rim light rig
## and ambient occlusion, rendered at SCALE x game size onto a transparent
## background, cropped, alpha-bled and mipmapped (mipmaps are the level of
## detail: small at game zoom, full detail close up).

const SCALE := 4.0
## Screen pixels per world unit at game zoom: a tile edge projects to (32, 16) px,
## which is 0.7071 world units across the screen plane.
const PX_PER_UNIT := 32.0 / 0.70710678
const SIZE := 1024
const PIXEL_SIZE := 2048

const Pixelize := preload("res://scenes/art_pixel/pixelize.gd")

var cam: Camera3D
var holder: Node3D
var pixel_factor := 0      # > 0: pixel mode, shrink the render by this much and pixelize it
var shadow_plane: MeshInstance3D
var shadow_on := false
var outline := true      # pixel mode: darker inner outline (off for realistic props)
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var rim: DirectionalLight3D
var env: Environment


## Pixel mode: bake at `art_scale` art pixels per canvas unit, supersampled by `factor`,
## with ground shadows baked in (a shadow-catcher plane).
func set_pixel_mode(art_scale: float, factor: int) -> void:
	pixel_factor = factor
	size = Vector2i(PIXEL_SIZE, PIXEL_SIZE)   # supersampled pixel bakes need more room
	cam.size = PIXEL_SIZE / (PX_PER_UNIT * art_scale * factor)
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	shadow_plane = MeshInstance3D.new()
	shadow_plane.mesh = plane
	shadow_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.roughness = 1.0
	shadow_plane.material_override = m
	shadow_plane.position.y = 0.003
	shadow_plane.visible = false
	add_child(shadow_plane)


## Bake a ground shadow with the next model (pixel mode): a second, shadow-only pass.
func set_ground_shadow(on: bool) -> void:
	shadow_on = on


func _init() -> void:
	size = Vector2i(SIZE, SIZE)
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_8X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = SIZE / (PX_PER_UNIT * SCALE)
	cam.rotation_degrees = Vector3(-30, 45, 0)
	add_child(cam)
	var key := DirectionalLight3D.new()
	sun = key
	key.rotation_degrees = Vector3(-48, -58, 0)   # from the screen's upper left: left faces lit, right faces in shade, shadows fall lower right
	key.light_energy = 1.05
	key.shadow_enabled = true
	key.shadow_bias = 0.05
	key.shadow_blur = 0.4
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	key.directional_shadow_max_distance = 120.0   # the bake camera sits 30 units out; shadows must reach past it
	add_child(key)
	fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -60, 0)
	fill.light_energy = 0.25
	fill.light_color = Color("#b8c8ff")
	add_child(fill)
	rim = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, -135, 0)
	rim.light_energy = 0.3
	rim.light_color = Color("#fff0d0")
	add_child(rim)
	env = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c8d0e0")
	env.ambient_light_energy = 0.28
	env.ssao_enabled = true
	env.ssao_radius = 0.35
	env.ssao_intensity = 2.2
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	holder = Node3D.new()
	add_child(holder)


## Second and third passes: the model only casts shadows onto a white ground lit by
## the sun alone (the sun shadow mask), then flat light with strong ambient occlusion
## (where things meet the ground). Returns [sun mask, occlusion], at the render's size.
func _shadow_passes(model: Node3D) -> Array:
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	shadow_plane.visible = true
	fill.visible = false
	rim.visible = false
	var ambient := env.ambient_light_energy
	env.ambient_light_energy = 0.0
	var ssao := env.ssao_enabled
	env.ssao_enabled = false
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var mask := get_texture().get_image()
	sun.visible = false
	env.ambient_light_energy = 1.0
	env.ambient_light_color = Color.WHITE
	env.ssao_enabled = true
	var ssao_r := env.ssao_radius
	var ssao_i := env.ssao_intensity
	env.ssao_radius = 0.45
	env.ssao_intensity = 6.0
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var occl := get_texture().get_image()
	sun.visible = true
	env.ssao_radius = ssao_r
	env.ssao_intensity = ssao_i
	env.ambient_light_color = Color("#c8d0e0")
	for mi in meshes:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	shadow_plane.visible = false
	fill.visible = true
	rim.visible = true
	env.ambient_light_energy = ambient
	env.ssao_enabled = ssao
	return [mask, occl]


## Paint the ground shadows into a pixelized sprite, at art resolution (cheap: the
## passes are shrunk first). Sun shadow where the mask went dark; contact shadow where
## the occlusion pass darkened, plus the classic hand-drawn band: a short dark strip of
## ground right below the lowest pixels in every column, so things sit on the ground.
static func _paint_shadows(art: Image, mask: Image, occl: Image) -> void:
	var w := art.get_width()
	var h := art.get_height()
	mask.convert(Image.FORMAT_RGBA8)
	occl.convert(Image.FORMAT_RGBA8)
	mask.resize(w, h, Image.INTERPOLATE_BILINEAR)
	occl.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var a := art.get_data()
	var m := mask.get_data()
	var o := occl.get_data()
	var bottom := PackedInt32Array()
	bottom.resize(w)
	bottom.fill(-1)
	for x in w:
		for y in range(h - 1, -1, -1):
			if a[(y * w + x) * 4 + 3] == 255:
				bottom[x] = y
				break
	var sun := Pixelize.SHADOW
	var contact := Pixelize.CONTACT
	for y in h:
		for x in w:
			var i := (y * w + x) * 4
			if a[i + 3] != 0:
				continue
			var ml := (m[i] * 0.3 + m[i + 1] * 0.59 + m[i + 2] * 0.11) / 255.0
			var ol := (o[i] * 0.3 + o[i + 1] * 0.59 + o[i + 2] * 0.11) / 255.0
			var c := Color(0, 0, 0, 0)
			if m[i + 3] > 128 and ml < 0.35:
				c = sun
			elif (o[i + 3] > 128 and ol < 0.8) or (bottom[x] >= 0 and y > bottom[x] and y <= bottom[x] + 3):
				c = contact
			else:
				continue
			a[i] = int(c.r8)
			a[i + 1] = int(c.g8)
			a[i + 2] = int(c.b8)
			a[i + 3] = int(c.a8)
	art.set_data(w, h, false, Image.FORMAT_RGBA8, a)


## Render `model` (centred on its anchor at the world origin) and return
## {"tex": ImageTexture, "points": [Vector2]} where points are the given 3D
## points projected into the cropped image (in baked pixels).
func bake(model: Node3D, points: Array) -> Dictionary:
	holder.add_child(model)
	cam.position = Vector3(0, 0.6, 0) + cam.transform.basis.z * 30.0
	var shots: Array = await _shoot()
	var projected := points.map(func(p): return cam.unproject_position(p))
	holder.remove_child(model)
	model.queue_free()
	var img: Image = shots[0]
	return _cut(shots, Rect2i(Vector2i.ZERO, img.get_size()), projected)


## Pixel mode: bake several small models (props) in one render, each in its own cell
## of the frame, anchored on its origin. Returns one {tex, points: [origin]} per model.
## Much cheaper than one render each: a render (and its shadow passes) is most of a bake.
func bake_many(models: Array, cols := 3) -> Array:
	assert(pixel_factor > 0)
	cam.position = Vector3(0, 0.6, 0) + cam.transform.basis.z * 30.0
	var out := []
	var cell := PIXEL_SIZE / cols
	var per := cols * cols
	for first in range(0, models.size(), per):
		var batch: Array = models.slice(first, first + per)
		var anchors := []
		for k in batch.size():
			# The ground point seen at this cell's anchor (low in the cell: things grow up).
			var px := Vector2((k % cols + 0.5) * cell, (k / cols + 0.68) * cell)
			var o := cam.project_ray_origin(px)
			var d := cam.project_ray_normal(px)
			var g := o + d * (-o.y / d.y)
			var m: Node3D = batch[k]
			m.position = g
			holder.add_child(m)
			anchors.append(g)
		var shots: Array = await _shoot()
		for k in batch.size():
			var r := Rect2i((k % cols) * cell, (k / cols) * cell, cell, cell)
			out.append(_cut(shots, r, [cam.unproject_position(anchors[k])]))
		for m in batch:
			holder.remove_child(m)
			m.queue_free()
	return out


## Render what's in the holder: [image, then the shadow passes if they're on].
func _shoot() -> Array:
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var shots := [get_texture().get_image()]
	if pixel_factor > 0 and shadow_on:
		shots.append_array(await _shadow_passes(holder))
	return shots


## Crop one model out of a render (within `area`), pixelize it in pixel mode and
## paint its shadows. Points come in render pixels and go out in the sprite's pixels.
func _cut(shots: Array, area: Rect2i, projected: Array) -> Dictionary:
	var img: Image = shots[0]
	var used := img.get_region(area).get_used_rect()
	used.position += area.position
	used = used.grow(4).intersection(area)
	if pixel_factor > 0:
		if shots.size() > 1:   # room for the shadows around the model
			used = used.grow(maxi(used.size.x, used.size.y) / 2).intersection(area)
		used.position = used.position / pixel_factor * pixel_factor   # keep the pixel grid aligned
		var f := float(pixel_factor)
		var art := Pixelize.run(img.get_region(used), pixel_factor, outline)
		if shots.size() > 1:
			_paint_shadows(art, shots[1].get_region(used), shots[2].get_region(used))
		var keep := art.get_used_rect().grow(1).intersection(Rect2i(Vector2i.ZERO, art.get_size()))
		var shift := Vector2(used.position) / f + Vector2(keep.position)
		return {"tex": ImageTexture.create_from_image(art.get_region(keep)),
			"points": projected.map(func(p): return p / f - shift)}
	var crop := img.get_region(used)
	crop.fix_alpha_edges()
	crop.generate_mipmaps()
	return {"tex": ImageTexture.create_from_image(crop),
		"points": projected.map(func(p): return p - Vector2(used.position))}
