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

var cam: Camera3D
var holder: Node3D


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
	key.rotation_degrees = Vector3(-48, 160, 0)   # from the viewer's upper left
	key.light_energy = 1.05
	key.shadow_enabled = true
	key.shadow_bias = 0.05
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	key.directional_shadow_max_distance = 30.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -60, 0)
	fill.light_energy = 0.25
	fill.light_color = Color("#b8c8ff")
	add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, -135, 0)
	rim.light_energy = 0.3
	rim.light_color = Color("#fff0d0")
	add_child(rim)
	var env := Environment.new()
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
	holder.remove_child(model)
	model.queue_free()
	var used := img.get_used_rect().grow(4).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(used)
	crop.fix_alpha_edges()
	crop.generate_mipmaps()
	return {"tex": ImageTexture.create_from_image(crop),
		"points": projected.map(func(p): return p - Vector2(used.position))}
