extends Node3D
## The same little scene as diorama_2d.gd, but actually rendered in 3D from
## primitives: a "toy diorama" look (lit, shadowed, glossy plastic) through an
## orthographic camera at our 2:1 isometric angle. In production such renders
## would be baked into the 2D parts atlas; here they're live, to judge the look.

const Diorama2D := preload("res://scenes/style_sampler/diorama_2d.gd")

const W := 8
const H := 8

var team := [Color.BLUE, Color.RED]
var units: Array = []    # [{root, legs: [Node3D], kind, t, path}]
var time := 0.0


func build(lib) -> void:
	team = [Color(lib.palettes.teams[0]), Color(lib.palettes.teams[1])]
	_environment()
	for y in H:
		for x in W:
			var ch := _at(x, y)
			var cols: Array = Diorama2D.GROUND.get(ch, Diorama2D.GROUND.g)
			var tile := _box(Vector3(0.98, 0.16, 0.98), Color(cols[(x + y) & 1]), 0.9)
			tile.position = Vector3(x + 0.5, -0.08 - (0.04 if ch == "s" else 0.0), y + 0.5)
			add_child(tile)
			if ch == "r":
				_reeds(Vector3(x + 0.5, 0, y + 0.5), x * 31 + y)
			elif ch == "b":
				_bush(Vector3(x + 0.5, 0, y + 0.5), x * 17 + y)
	_building(Vector3(5.5, 0, 1.5), 2.6, 1.0, team[0], true)
	_building(Vector3(7.0, 0, 4.0), 1.7, 0.75, team[0], false)
	_frog(Vector3(1.8, 0, 3.6), Vector3(3.2, 0, 4.2), true)
	_frog(Vector3(2.6, 0, 3.0), Vector3(3.6, 0, 3.6), false)
	_rat(Vector3(4.3, 0, 4.9), Vector3(2.9, 0, 5.4))
	_rat(Vector3(4.6, 0, 3.6), Vector3(4.2, 0, 4.4))


func _at(x: int, y: int) -> String:
	var row: String = Diorama2D.ROWS[y]
	return row[x] if x < row.length() and row[x] != " " else "g"


## One 2D canvas pixel at zoom 1 is this many world units vertically at our 30 degree pitch:
## a tile diagonal (sqrt 2) spans 32 px and projects to sqrt(2) * sin(30) units.
const UNITS_PER_PX := 1.41421356 * 0.5 / 32.0

var cam: Camera3D


## Frame like a Camera2D at `zoom` centred over the tile point (tx, ty), for a viewport `height_px` tall.
func frame(tx: float, ty: float, zoom: float, height_px: float) -> void:
	cam.size = height_px * UNITS_PER_PX / zoom
	cam.position = Vector3(tx, 0.3, ty) + cam.transform.basis.z * 20.0


func _environment() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(-30, 45, 0)
	add_child(cam)
	frame(W * 0.5, H * 0.5, 1.0, 300.0)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 150, 0)   # from behind the viewer's left, so shadows fall where we can see them
	sun.light_energy = 1.5
	sun.shadow_opacity = 0.85
	sun.shadow_enabled = true
	sun.shadow_bias = 0.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2b2620")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b8c4d8")
	env.ambient_light_energy = 0.35
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 2.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _mat(c: Color, rough := 0.4) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic_specular = 0.6
	return m


func _mesh(mesh: Mesh, c: Color, rough := 0.4) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c, rough)
	return mi


func _box(size: Vector3, c: Color, rough := 0.5) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(b, c, rough)


func _sphere(r: float, c: Color, rough := 0.35) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return _mesh(s, c, rough)


func _cyl(r_top: float, r_bottom: float, h: float, c: Color, segments := 12) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = segments
	return _mesh(cm, c)


func _reeds(at: Vector3, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for k in 9:
		var h := rng.randf_range(0.45, 0.7)
		var stalk := _cyl(0.015, 0.02, h, Diorama2D.REED, 6)
		stalk.position = at + Vector3(rng.randf_range(-0.35, 0.35), h * 0.5, rng.randf_range(-0.35, 0.35))
		stalk.rotation = Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))
		add_child(stalk)
		var tip := _cyl(0.035, 0.035, 0.12, Diorama2D.REED_TIP, 8)
		tip.position = Vector3(0, h * 0.5, 0)
		stalk.add_child(tip)


func _bush(at: Vector3, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for b in [[Vector3(0, 0.22, 0), 0.3], [Vector3(-0.2, 0.16, 0.1), 0.22], [Vector3(0.2, 0.15, -0.1), 0.22], [Vector3(0, 0.4, 0), 0.18]]:
		var s := _sphere(b[1], Diorama2D.BUSH, 0.7)
		s.position = at + b[0]
		add_child(s)
	for k in 6:
		var bug := _sphere(0.045, Diorama2D.BUG, 0.25)
		var a := rng.randf() * TAU
		bug.position = at + Vector3(cos(a) * 0.28, rng.randf_range(0.15, 0.45), sin(a) * 0.28)
		add_child(bug)


func _building(at: Vector3, size: float, height: float, roof: Color, tall: bool) -> void:
	var walls := _box(Vector3(size, height, size), Diorama2D.WALL, 0.75)
	walls.position = at + Vector3(0, height * 0.5, 0)
	add_child(walls)
	var cap := CylinderMesh.new()      # four segments and no top: a hip roof
	cap.top_radius = 0.0
	cap.bottom_radius = size * 0.78
	cap.height = size * (0.55 if tall else 0.5)
	cap.radial_segments = 4
	var r := _mesh(cap, roof, 0.65)
	r.position = at + Vector3(0, height + cap.height * 0.5, 0)
	r.rotation_degrees = Vector3(0, 45, 0)
	add_child(r)
	var door := _box(Vector3(0.28, 0.45, 0.04), Color("#4a3020"))
	door.position = at + Vector3(-size * 0.15, 0.22, size * 0.5 + 0.01)
	add_child(door)
	var window := _box(Vector3(0.04, 0.22, 0.26), Color("#f2d78a"))
	window.position = at + Vector3(size * 0.5 + 0.01, height * 0.6, 0.1)
	add_child(window)
	if tall:
		var pole := _cyl(0.025, 0.025, 0.8, Color("#4a3020"), 6)
		pole.position = at + Vector3(0, height + cap.height + 0.3, 0)
		add_child(pole)
		var flag := _box(Vector3(0.36, 0.22, 0.02), roof.lightened(0.15))
		flag.position = Vector3(0.18, 0.26, 0)
		pole.add_child(flag)


func _frog(from: Vector3, to: Vector3, worker: bool) -> void:
	var root := Node3D.new()
	add_child(root)
	var skin := Color("#6bbf59")
	var body := _sphere(0.2, skin)
	body.scale = Vector3(1.0, 0.8, 1.15)
	body.position = Vector3(0, 0.2, 0)
	root.add_child(body)
	var belly := _sphere(0.14, Color("#c8e6a0"))
	belly.position = Vector3(0, 0.17, 0.1)
	root.add_child(belly)
	var head := _sphere(0.16, skin)
	head.scale = Vector3(1.25, 0.8, 1.0)
	head.position = Vector3(0, 0.38, 0.1)
	root.add_child(head)
	for side in [-1, 1]:
		var eye := _sphere(0.06, skin)
		eye.position = Vector3(0.08 * side, 0.47, 0.13)
		root.add_child(eye)
		var pupil := _sphere(0.032, Color("#141414"), 0.15)
		pupil.position = Vector3(0.09 * side, 0.48, 0.18)
		root.add_child(pupil)
	var legs := []
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.position = Vector3(0.14 * side, 0.12, -0.05)
		root.add_child(leg)
		var thigh := _sphere(0.09, skin)
		thigh.scale = Vector3(0.8, 0.7, 1.4)
		thigh.position = Vector3(0, -0.04, 0.04)
		leg.add_child(thigh)
		legs.append(leg)
	var hat := _sphere(0.13, Color("#4e8a3a"), 0.6)
	hat.scale = Vector3(1.2, 0.35, 1.2)
	hat.position = Vector3(0, 0.5, 0.08)
	root.add_child(hat)
	if worker:
		var basket := _cyl(0.09, 0.07, 0.12, Color("#a6844a"), 10)
		basket.position = Vector3(0.18, 0.2, 0.12)
		root.add_child(basket)
	else:
		var spear := _cyl(0.012, 0.012, 0.9, Color("#a6b44c"), 6)
		spear.position = Vector3(0.18, 0.32, 0.1)
		spear.rotation_degrees = Vector3(55, 0, 0)
		root.add_child(spear)
		var tip := _cyl(0.0, 0.035, 0.1, Color("#e8e0c8"), 6)
		tip.position = Vector3(0, 0.48, 0)
		spear.add_child(tip)
		var shield := _cyl(0.13, 0.13, 0.03, Color("#3f8a4a"), 16)
		shield.position = Vector3(-0.2, 0.22, 0.05)
		shield.rotation_degrees = Vector3(0, 0, 90)
		root.add_child(shield)
	units.append({"root": root, "legs": legs, "from": from, "to": to, "t": randf(), "hop": true})


func _rat(from: Vector3, to: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	var fur := Color("#8a8a8a")
	var body := _sphere(0.17, fur)
	body.scale = Vector3(0.9, 1.25, 0.85)
	body.position = Vector3(0, 0.3, 0)
	root.add_child(body)
	var head := _sphere(0.12, fur)
	head.scale = Vector3(0.9, 0.85, 1.4)
	head.position = Vector3(0, 0.55, 0.08)
	root.add_child(head)
	var nose := _sphere(0.035, Color("#e89aa8"), 0.2)
	nose.position = Vector3(0, 0.54, 0.25)
	root.add_child(nose)
	for side in [-1, 1]:
		var ear := _sphere(0.07, Color("#d8b4b4"))
		ear.scale = Vector3(1.0, 1.0, 0.3)
		ear.position = Vector3(0.09 * side, 0.67, 0.02)
		root.add_child(ear)
		var eye := _sphere(0.022, Color("#141414"), 0.1)
		eye.position = Vector3(0.06 * side, 0.6, 0.17)
		root.add_child(eye)
	var helm := _sphere(0.11, Color("#8a5a2a"), 0.5)
	helm.scale = Vector3(1.0, 0.6, 1.1)
	helm.position = Vector3(0, 0.66, 0.06)
	root.add_child(helm)
	var at := Vector3(0, 0.12, -0.12)   # a tail that curls along the ground, segment by segment
	var heading := 0.0
	for k in 4:
		var dir := Vector3(sin(heading), -0.25 if k == 0 else 0.0, -cos(heading)).normalized()
		var seg := _cyl(0.014 - k * 0.002, 0.02 - k * 0.002, 0.15, Color("#c89a9a"), 6)
		seg.position = at + dir * 0.075
		seg.look_at_from_position(seg.position, seg.position + dir, Vector3.UP)
		seg.rotate_object_local(Vector3.RIGHT, PI / 2)
		root.add_child(seg)
		at += dir * 0.14
		heading += 0.45
	var legs := []
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.position = Vector3(0.08 * side, 0.14, 0)
		root.add_child(leg)
		var shin := _cyl(0.035, 0.03, 0.18, fur, 8)
		shin.position = Vector3(0, -0.07, 0)
		leg.add_child(shin)
		legs.append(leg)
	var spear := _cyl(0.012, 0.012, 1.0, Color("#a6844a"), 6)
	spear.position = Vector3(0.17, 0.42, 0.05)
	spear.rotation_degrees = Vector3(20, 0, 0)
	root.add_child(spear)
	var tip := _cyl(0.0, 0.04, 0.12, Color("#c8a050"), 6)
	tip.position = Vector3(0, 0.55, 0)
	spear.add_child(tip)
	var shield := _cyl(0.15, 0.15, 0.03, team[1], 16)
	shield.position = Vector3(-0.17, 0.32, 0.06)
	shield.rotation_degrees = Vector3(0, 0, 90)
	root.add_child(shield)
	units.append({"root": root, "legs": legs, "from": from, "to": to, "t": randf(), "hop": false})


func _process(delta: float) -> void:
	time += delta
	for u in units:
		u.t += delta * 0.12
		var k := pingpong(u.t, 1.0)
		var p: Vector3 = u.from.lerp(u.to, smoothstep(0.0, 1.0, k))
		var dir: Vector3 = (u.to - u.from) * (1.0 if fmod(u.t, 2.0) < 1.0 else -1.0)
		var walk := sin(time * 9.0 + u.t * 3.0)
		u.root.position = p + Vector3(0, absf(walk) * (0.06 if u.hop else 0.03), 0)
		u.root.rotation.y = atan2(dir.x, dir.z)
		for i in u.legs.size():
			u.legs[i].rotation.x = walk * 0.6 * (1.0 if i == 0 else -1.0)
