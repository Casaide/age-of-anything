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
	plane.size = Vector2(16, 16)
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
	key.rotation_degrees = Vector3(-48, -72, 0)   # from the screen's upper left: left faces lit, shadows fall lower right
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


## Second pass: the model only casts shadows onto a white ground lit by the sun alone.
## Where the ground went dark and the model isn't drawn, mark a shadow pixel
## (dark and half transparent; Pixelize turns it into the flat shadow colour).
func _add_ground_shadow(img: Image, model: Node3D) -> void:
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
	for mi in meshes:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	shadow_plane.visible = false
	fill.visible = true
	rim.visible = true
	env.ambient_light_energy = ambient
	env.ssao_enabled = ssao
	var body := img.get_used_rect()
	var area := body.grow(maxi(body.size.x, body.size.y) / 2).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var m := mask.get_pixel(x, y)
			if img.get_pixel(x, y).a < 0.5 and m.a > 0.5 and m.get_luminance() < 0.35:
				img.set_pixel(x, y, Color(0, 0, 0, 0.5))


## Render `model` (centred on its anchor at the world origin) and return
## {"tex": ImageTexture, "points": [Vector2]} where points are the given 3D
## points projected into the cropped image (in baked pixels).
func bake(model: Node3D, points: Array) -> Dictionary:
	holder.add_child(model)
	cam.position = Vector3(0, 0.6, 0) + cam.transform.basis.z * 30.0
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := get_texture().get_image()
	var projected := points.map(func(p): return cam.unproject_position(p))
	if pixel_factor > 0 and shadow_on:
		await _add_ground_shadow(img, model)
	holder.remove_child(model)
	model.queue_free()
	var used := img.get_used_rect().grow(4).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if pixel_factor > 0:
		used.position = used.position / pixel_factor * pixel_factor   # keep the pixel grid aligned
		var crop_p := img.get_region(used)
		var f := float(pixel_factor)
		return {"tex": ImageTexture.create_from_image(Pixelize.run(crop_p, pixel_factor)),
			"points": projected.map(func(p): return (p - Vector2(used.position)) / f)}
	var crop := img.get_region(used)
	crop.fix_alpha_edges()
	crop.generate_mipmaps()
	return {"tex": ImageTexture.create_from_image(crop),
		"points": projected.map(func(p): return p - Vector2(used.position))}
