extends RefCounted
## Detailed 3D models for the high-fidelity pre-render, built from primitives
## with procedural materials. 1 world unit = 1 tile; y is up; sim x = world x,
## sim y = world z. Each builder returns the static body plus the "live" bits
## (animated in 2D after baking) and the points the 2D side needs.

const Materials := preload("res://scenes/style_sampler/hifi/materials.gd")

var mats := Materials.new()
var rng := RandomNumberGenerator.new()


func _mi(mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = rot
	m.scale = scl
	return m


func box(size: Vector3, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mi(b, mat, pos, rot)


func cyl(r_top: float, r_bot: float, h: float, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, seg := 16) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	return _mi(c, mat, pos, rot)


func ball(r: float, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 32
	s.rings = 16
	return _mi(s, mat, pos, rot, scl)


func ring(inner: float, outer: float, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 32
	t.ring_segments = 12
	return _mi(t, mat, pos, rot, scl)


func cloth(team: Color) -> StandardMaterial3D:
	var m := Materials.flat(team, 0.85)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func glow(c: Color, energy := 2.5) -> StandardMaterial3D:
	var m := Materials.flat(c, 0.5)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


# ------------------------------------------------------------------ props

func barrel(at: Vector3, parent: Node3D) -> void:
	var wood := mats.get_mat("wood")
	var band := Materials.flat(Color("#3a3430"), 0.4, 0.7)
	parent.add_child(cyl(0.13, 0.13, 0.34, wood, at + Vector3(0, 0.17, 0)))
	parent.add_child(ball(0.15, wood, at + Vector3(0, 0.17, 0), Vector3(1, 1.15, 1)))
	for y in [0.06, 0.28]:
		parent.add_child(ring(0.14, 0.16, band, at + Vector3(0, y, 0)))
	parent.add_child(cyl(0.12, 0.12, 0.02, wood, at + Vector3(0, 0.35, 0)))


func crate(at: Vector3, parent: Node3D, turn := 0.0) -> void:
	var wood := mats.get_mat("wood")
	var c := Node3D.new()
	c.position = at
	c.rotation_degrees.y = turn
	parent.add_child(c)
	c.add_child(box(Vector3(0.3, 0.26, 0.3), wood, Vector3(0, 0.13, 0)))
	var dark := Materials.flat(Color("#4a2f1c"), 0.9)
	for z in [-0.151, 0.151]:
		c.add_child(box(Vector3(0.31, 0.04, 0.01), dark, Vector3(0, 0.22, z)))
		c.add_child(box(Vector3(0.31, 0.04, 0.01), dark, Vector3(0, 0.04, z)))
		c.add_child(box(Vector3(0.36, 0.035, 0.01), dark, Vector3(0, 0.13, z), Vector3(0, 0, 38)))


func woodpile(at: Vector3, parent: Node3D) -> void:
	var wood := mats.get_mat("wood")
	var ends := Materials.flat(Color("#c8a06a"), 0.9)
	var rows := [[0.06, [-0.15, 0.0, 0.15]], [0.17, [-0.075, 0.075]], [0.28, [0.0]]]
	for r in rows:
		for z in r[1]:
			parent.add_child(cyl(0.065, 0.065, 0.55, wood, at + Vector3(0, r[0], z), Vector3(0, 0, 90), 10))
			parent.add_child(cyl(0.06, 0.06, 0.01, ends, at + Vector3(0.276, r[0], z), Vector3(0, 0, 90), 10))


# ------------------------------------------------------------------ buildings

## A frog-culture Town Center: stone footing, timber frame on mud daub, stepped
## reed thatch, a chimney, barrels, a crate and a woodpile; a team banner and a
## dragonfly weathervane as live parts.
func town_center(team: Color) -> Dictionary:
	rng.seed = 42
	var body := Node3D.new()
	var stone := mats.get_mat("stone")
	var wood := mats.get_mat("wood")
	var mud := mats.get_mat("mud")
	var thatch := mats.get_mat("thatch")
	# Footing: a slab with a rim of uneven stones.
	body.add_child(box(Vector3(2.8, 0.22, 2.8), stone, Vector3(0, 0.11, 0)))
	for side in 4:
		for k in 9:
			var t := -1.3 + k * 0.325
			var p := Vector3(t, 0.13, 1.38) if side == 0 else Vector3(1.38, 0.13, t) if side == 1 else Vector3(t, 0.13, -1.38) if side == 2 else Vector3(-1.38, 0.13, t)
			var s := Vector3(rng.randf_range(0.26, 0.32), rng.randf_range(0.2, 0.28), rng.randf_range(0.18, 0.24))
			if side % 2 == 1:
				s = Vector3(s.z, s.y, s.x)
			body.add_child(box(s, stone, p, Vector3(0, rng.randf_range(-8, 8), 0)))
	# Hall: daub walls inside a timber frame.
	var w := 2.1
	var h := 1.15
	var base := 0.22
	body.add_child(box(Vector3(w, h, w), mud, Vector3(0, base + h / 2, 0)))
	for x in [-1, 0, 1]:
		for z in [-1, 0, 1]:
			if (x == 0 and z == 0) or (absi(x) + absi(z) == 1 and false):
				continue
			if absi(x) == 1 or absi(z) == 1:
				if x == 0 or z == 0 or (absi(x) == 1 and absi(z) == 1):
					body.add_child(box(Vector3(0.12, h + 0.04, 0.12), wood, Vector3(x * w / 2, base + h / 2, z * w / 2)))
	for y in [base + 0.05, base + h * 0.55, base + h - 0.04]:
		for side in [-1, 1]:
			body.add_child(box(Vector3(w + 0.1, 0.09, 0.1), wood, Vector3(0, y, side * w / 2)))
			body.add_child(box(Vector3(0.1, 0.09, w + 0.1), wood, Vector3(side * w / 2, y, 0)))
	# Diagonal braces on the two faces we see.
	for d in [-1, 1]:
		body.add_child(box(Vector3(0.08, 0.62, 0.06), wood, Vector3(d * 0.52, base + h * 0.28, w / 2 + 0.02), Vector3(0, 0, d * 38)))
		body.add_child(box(Vector3(0.06, 0.62, 0.08), wood, Vector3(w / 2 + 0.02, base + h * 0.28, d * 0.52), Vector3(d * 38, 0, 0)))
	# Door with frame and lintel, facing +z.
	var door_wood := Materials.flat(Color("#3e2616"), 0.8)
	body.add_child(box(Vector3(0.46, 0.7, 0.05), door_wood, Vector3(-0.15, base + 0.35, w / 2 + 0.03)))
	body.add_child(cyl(0.23, 0.23, 0.05, door_wood, Vector3(-0.15, base + 0.7, w / 2 + 0.03), Vector3(90, 0, 0)))
	for x in [-0.42, 0.12]:
		body.add_child(box(Vector3(0.07, 0.95, 0.08), wood, Vector3(x, base + 0.47, w / 2 + 0.05)))
	body.add_child(box(Vector3(0.65, 0.09, 0.1), wood, Vector3(-0.15, base + 0.97, w / 2 + 0.05)))
	body.add_child(box(Vector3(0.05, 0.05, 0.02), Materials.flat(Color("#b89a5a"), 0.3, 0.8), Vector3(0.0, base + 0.36, w / 2 + 0.065)))
	# Windows with shutters on the +x face (they glow; the glow pulses in 2D).
	var lights := []
	for z in [-0.5, 0.45]:
		body.add_child(box(Vector3(0.04, 0.3, 0.3), glow(Color("#ffcf6a"), 1.6), Vector3(w / 2 + 0.01, base + 0.78, z)))
		body.add_child(box(Vector3(0.05, 0.34, 0.06), wood, Vector3(w / 2 + 0.04, base + 0.78, z + 0.18)))
		body.add_child(box(Vector3(0.05, 0.34, 0.06), wood, Vector3(w / 2 + 0.04, base + 0.78, z - 0.18)))
		body.add_child(box(Vector3(0.05, 0.05, 0.42), wood, Vector3(w / 2 + 0.04, base + 0.96, z)))
		body.add_child(box(Vector3(0.12, 0.32, 0.03), door_wood, Vector3(w / 2 + 0.1, base + 0.78, z + 0.24), Vector3(0, -55, 0)))
		lights.append(Vector3(w / 2 + 0.05, base + 0.78, z))
	# Stepped reed thatch (two layers for a thick eave) and a ridge cap.
	var roof_y := base + h
	body.add_child(cyl(0.0, 1.95, 1.35, thatch, Vector3(0, roof_y + 0.6, 0), Vector3(0, 45, 0), 4))
	body.add_child(cyl(0.0, 1.62, 1.15, thatch, Vector3(0, roof_y + 0.92, 0), Vector3(0, 45, 0), 4))
	body.add_child(cyl(0.0, 0.32, 0.32, Materials.flat(Color("#5a4220"), 0.9), Vector3(0, roof_y + 1.42, 0), Vector3(0, 45, 0), 4))
	# Chimney through the back of the roof.
	var chim := Vector3(-0.55, roof_y + 1.0, -0.55)
	body.add_child(box(Vector3(0.3, 1.0, 0.3), stone, chim))
	body.add_child(box(Vector3(0.36, 0.08, 0.36), stone, chim + Vector3(0, 0.5, 0)))
	# Props by the door.
	barrel(Vector3(0.75, base, 1.25), body)
	barrel(Vector3(1.05, base, 1.05), body)
	crate(Vector3(-0.85, base, 1.2), body, 20)
	woodpile(Vector3(1.25, base, -0.35), body)
	# Banner pole at the front corner; the banner itself is a live part.
	var pole_at := Vector3(-1.25, 0.22, 1.25)
	body.add_child(cyl(0.035, 0.04, 2.2, wood, pole_at + Vector3(0, 1.1, 0), Vector3.ZERO, 8))
	body.add_child(ball(0.06, Materials.flat(Color("#b89a5a"), 0.3, 0.8), pole_at + Vector3(0, 2.22, 0)))
	var banner := Node3D.new()
	var flag_top := pole_at + Vector3(0.04, 2.1, 0)
	banner.add_child(box(Vector3(0.62, 0.85, 0.02), cloth(team), flag_top + Vector3(0.33, -0.42, 0)))
	banner.add_child(box(Vector3(0.64, 0.06, 0.03), wood, flag_top + Vector3(0.33, 0.0, 0)))
	banner.add_child(ball(0.13, cloth(Color("#e8e4d8")), flag_top + Vector3(0.33, -0.4, 0.015), Vector3(1, 1, 0.1)))
	# Dragonfly weathervane on the ridge; spins in 2D.
	var vane := Node3D.new()
	var apex := Vector3(0, roof_y + 1.58, 0)
	var metal := Materials.flat(Color("#5e6a66"), 0.35, 0.8)
	vane.add_child(cyl(0.012, 0.012, 0.4, metal, apex + Vector3(0, 0.2, 0), Vector3.ZERO, 6))
	vane.add_child(cyl(0.025, 0.025, 0.4, metal, apex + Vector3(0, 0.38, 0), Vector3(0, 0, 90), 6))
	for s in [-1, 1]:
		vane.add_child(ball(0.12, Materials.flat(Color("#7fb6c8"), 0.2, 0.3), apex + Vector3(0.05, 0.4, s * 0.1), Vector3(0.5, 0.06, 1.0)))
	return {"body": body, "anchor": Vector3.ZERO, "banner": banner, "banner_pivot": flag_top,
		"vane": vane, "vane_pivot": apex, "smoke": chim + Vector3(0, 0.55, 0), "lights": lights,
		"lantern": Vector3(0.18, base + 0.75, w / 2 + 0.15)}


## A frog stilt hut: round daub walls on a plank deck over log stilts, a cone of
## thatch, a ladder and a little smoke pipe; a lantern by the door.
func stilt_house(team: Color) -> Dictionary:
	rng.seed = 7
	var body := Node3D.new()
	var wood := mats.get_mat("wood")
	var mud := mats.get_mat("mud")
	var thatch := mats.get_mat("thatch")
	for x in [-0.6, 0.6]:
		for z in [-0.6, 0.6]:
			body.add_child(cyl(0.06, 0.07, 0.45, wood, Vector3(x, 0.22, z), Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)), 10))
	for k in 7:
		body.add_child(box(Vector3(1.55, 0.06, 0.21), wood, Vector3(0, 0.47, -0.66 + k * 0.22), Vector3(0, rng.randf_range(-2, 2), 0)))
	body.add_child(cyl(0.6, 0.62, 0.72, mud, Vector3(0, 0.86, 0), Vector3.ZERO, 24))
	for y in [0.55, 1.18]:
		body.add_child(ring(0.6, 0.66, wood, Vector3(0, y, 0)))
	for k in 6:
		var a := TAU * k / 6.0
		body.add_child(box(Vector3(0.07, 0.72, 0.07), wood, Vector3(cos(a) * 0.62, 0.86, sin(a) * 0.62)))
	body.add_child(box(Vector3(0.32, 0.5, 0.05), Materials.flat(Color("#3e2616"), 0.8), Vector3(0.05, 0.75, 0.6), Vector3(0, 8, 0)))
	body.add_child(cyl(0.0, 0.95, 0.85, thatch, Vector3(0, 1.62, 0), Vector3.ZERO, 24))
	body.add_child(cyl(0.0, 0.8, 0.5, thatch, Vector3(0, 1.95, 0), Vector3(0, 17, 0), 24))
	body.add_child(cyl(0.05, 0.05, 0.25, Materials.flat(Color("#3a3430"), 0.4, 0.7), Vector3(0.35, 1.95, -0.2), Vector3.ZERO, 8))
	# Ladder down the front, from the ground up to the deck edge.
	var foot := Vector3(0, 0.0, 1.12)
	var top := Vector3(0, 0.5, 0.8)
	var along := top - foot
	var tilt := rad_to_deg(atan2(along.z, along.y))
	for x in [-0.12, 0.22]:
		body.add_child(box(Vector3(0.04, along.length(), 0.04), wood, foot.lerp(top, 0.5) + Vector3(x, 0, 0), Vector3(tilt, 0, 0)))
	for k in 4:
		body.add_child(box(Vector3(0.36, 0.03, 0.03), wood, foot.lerp(top, (k + 1) / 5.0) + Vector3(0.05, 0, 0)))
	# A team pennant on the roof tip, so every building shows its owner.
	body.add_child(cyl(0.015, 0.015, 0.5, wood, Vector3(0, 2.4, 0), Vector3.ZERO, 6))
	body.add_child(slab_tri(Vector2(0, 0), Vector2(0, -0.22), Vector2(0.42, -0.11), 0.02, cloth(team)))
	body.get_child(body.get_child_count() - 1).position = Vector3(0.015, 2.62, 0)
	return {"body": body, "anchor": Vector3.ZERO, "smoke": Vector3(0.35, 2.1, -0.2), "lights": [],
		"lantern": Vector3(0.32, 0.95, 0.66), "team": team}


# ------------------------------------------------------------------ ground

func grass_tile(seed_value: int) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	n.add_child(box(Vector3(1.0, 0.1, 1.0), mats.get_mat("grass"), Vector3(0, -0.05, 0)))
	var blade := Materials.flat(Color("#5e8434"), 0.9)
	var blade2 := Materials.flat(Color("#86a64a"), 0.9)
	for k in 22:
		var p := Vector3(rng.randf_range(-0.45, 0.45), 0, rng.randf_range(-0.45, 0.45))
		for b in 3:
			var h := rng.randf_range(0.05, 0.1)
			n.add_child(box(Vector3(0.012, h, 0.012), blade if b % 2 == 0 else blade2, p + Vector3(b * 0.012, h / 2, 0), Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20))))
	return n


func swamp_tile(seed_value: int) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	n.add_child(box(Vector3(1.0, 0.08, 1.0), mats.get_mat("swamp"), Vector3(0, -0.06, 0)))
	var pad := Materials.flat(Color("#4e7a34"), 0.5)
	for k in 2:
		var p := Vector3(rng.randf_range(-0.3, 0.3), -0.015, rng.randf_range(-0.3, 0.3))
		n.add_child(cyl(0.11, 0.11, 0.01, pad, p, Vector3.ZERO, 16))
	return n


func reeds(seed_value: int) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	var stalk := Materials.flat(Color("#9aa846"), 0.8)
	var stalk2 := Materials.flat(Color("#7e8e3a"), 0.8)
	var tip := Materials.flat(Color("#6b4a2a"), 0.9)
	for k in 18:
		var h := rng.randf_range(0.55, 0.95)
		var p := Vector3(rng.randf_range(-0.42, 0.42), h / 2, rng.randf_range(-0.42, 0.42))
		var r := Vector3(rng.randf_range(-9, 9), 0, rng.randf_range(-9, 9))
		var s := cyl(0.012, 0.018, h, stalk if k % 3 else stalk2, p, r, 6)
		n.add_child(s)
		if k % 2 == 0:
			var t := cyl(0.03, 0.03, 0.13, tip, Vector3(0, h / 2 - 0.05, 0), Vector3.ZERO, 8)
			s.add_child(t)
		var leaf := box(Vector3(0.05, h * 0.55, 0.01), stalk2, p + Vector3(0.03, -h * 0.15, 0), r + Vector3(0, rng.randf_range(0, 180), rng.randf_range(10, 25)))
		n.add_child(leaf)
	return n


func bug_bush(seed_value: int) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	var leaf := mats.get_mat("grass")
	for k in 7:
		var r := rng.randf_range(0.17, 0.26)
		n.add_child(ball(r, leaf, Vector3(rng.randf_range(-0.22, 0.22), r * 0.9 + rng.randf_range(0, 0.15), rng.randf_range(-0.22, 0.22))))
	var bug := Materials.flat(Color("#e0607f"), 0.2)
	var spot := Materials.flat(Color("#1e1414"), 0.3)
	for k in 9:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a) * 0.3, rng.randf_range(0.18, 0.5), sin(a) * 0.3)
		n.add_child(ball(0.035, bug, p, Vector3(1, 0.7, 1)))
		n.add_child(ball(0.012, spot, p + Vector3(0.02, 0.02, 0.02)))
	return n


# ------------------------------------------------------------------ the frog

## A frog worker, facing +x, in parts that rotate about pivots in 2D:
## far leg, far arm, body, head, near leg, near arm with its basket.
func frog_worker(team: Color) -> Dictionary:
	var skin := mats.get_mat("frog")
	var cream := Materials.flat(Color("#e6e2b0"), 0.45)
	var dark := Materials.flat(Color("#1a1612"), 0.08)
	var white := Materials.flat(Color("#f4f0e0"), 0.2)
	var pink := Materials.flat(Color("#e89a8a"), 0.6)
	var leaf := Materials.flat(Color("#4e8a3a"), 0.55)
	var parts := {}
	var pivots := {}

	var body := Node3D.new()
	body.add_child(ball(0.3, skin, Vector3(0, 0.36, 0), Vector3(1.0, 0.95, 0.88)))
	body.add_child(ball(0.24, cream, Vector3(0.12, 0.32, 0), Vector3(0.62, 0.95, 0.85)))
	body.add_child(ring(0.17, 0.25, cloth(team), Vector3(0.04, 0.58, 0), Vector3(0, 0, -12), Vector3(1.05, 0.8, 1.05)))
	body.add_child(box(Vector3(0.09, 0.26, 0.03), cloth(team), Vector3(-0.2, 0.46, 0.08), Vector3(10, 0, -20)))
	parts.body = body
	pivots.body = Vector3(0, 0.1, 0)

	var head := Node3D.new()
	head.add_child(ball(0.26, skin, Vector3(0.1, 0.72, 0), Vector3(1.18, 0.74, 1.12)))
	head.add_child(ring(0.27, 0.285, dark, Vector3(0.12, 0.68, 0), Vector3(0, 0, -6), Vector3(1.12, 1, 1.07)))
	for s in [-1, 1]:
		var e := Vector3(0.2, 0.88, s * 0.14)
		head.add_child(ball(0.095, skin, e))
		head.add_child(ball(0.075, white, e + Vector3(0.04, 0.01, s * 0.01)))
		head.add_child(ball(0.042, dark, e + Vector3(0.09, 0.015, s * 0.02)))
		head.add_child(ball(0.1, skin, e + Vector3(-0.01, 0.045, 0), Vector3(1.0, 0.45, 1.0)))   # sleepy lid
		head.add_child(ball(0.05, pink, Vector3(0.28, 0.66, s * 0.2), Vector3(1, 0.6, 1)))      # cheek
	head.add_child(ball(0.24, leaf, Vector3(-0.06, 0.95, 0), Vector3(1.35, 0.1, 1.0), Vector3(0, 20, 14)))
	head.add_child(box(Vector3(0.36, 0.01, 0.015), Materials.flat(Color("#7ab84a"), 0.5), Vector3(-0.06, 0.975, 0), Vector3(0, 20, 14)))
	head.add_child(cyl(0.01, 0.012, 0.12, Materials.flat(Color("#6b4a2a"), 0.8), Vector3(-0.3, 1.0, -0.08), Vector3(0, 0, 60), 6))
	parts.head = head
	pivots.head = Vector3(0.05, 0.58, 0)

	for side in ["far", "near"]:
		var z := -0.2 if side == "far" else 0.2
		var leg := Node3D.new()
		leg.add_child(ball(0.17, skin, Vector3(-0.04, 0.2, z * 1.1), Vector3(1.3, 0.85, 0.75)))
		leg.add_child(ball(0.1, skin, Vector3(0.12, 0.08, z * 1.2), Vector3(1.4, 0.5, 0.7)))
		var foot := Vector3(0.24, 0.03, z * 1.25)
		leg.add_child(ball(0.1, skin, foot, Vector3(1.6, 0.35, 1.1)))
		for t in 3:
			leg.add_child(ball(0.035, skin, foot + Vector3(0.14, 0.0, (t - 1) * 0.06)))
		parts["leg_" + side] = leg
		pivots["leg_" + side] = Vector3(-0.04, 0.28, z)

	for side in ["far", "near"]:
		var z := -0.24 if side == "far" else 0.24
		var arm := Node3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.055
		cap.height = 0.3
		arm.add_child(_mi(cap, skin, Vector3(0.18, 0.4, z), Vector3(0, 0, 40)))
		var hand := Vector3(0.28, 0.28, z)
		arm.add_child(ball(0.06, skin, hand))
		for t in 3:
			arm.add_child(ball(0.025, skin, hand + Vector3(0.05, -0.02, (t - 1) * 0.035)))
		if side == "near":
			var basket := hand + Vector3(0.05, -0.16, 0.06)
			arm.add_child(cyl(0.15, 0.12, 0.18, mats.get_mat("weave"), basket, Vector3.ZERO, 20))
			arm.add_child(ring(0.14, 0.17, Materials.flat(Color("#6e5226"), 0.8), basket + Vector3(0, 0.09, 0)))
			arm.add_child(ring(0.13, 0.15, Materials.flat(Color("#6e5226"), 0.8), basket + Vector3(0, 0.02, 0), Vector3(90, 0, 0), Vector3(1, 1, 1.2)))
			for b in 5:
				arm.add_child(ball(0.035, Materials.flat(Color("#e0607f"), 0.2), basket + Vector3(-0.06 + b * 0.03, 0.1, (b % 2) * 0.05 - 0.02), Vector3(1, 0.7, 1)))
		parts["arm_" + side] = arm
		pivots["arm_" + side] = Vector3(0.1, 0.48, z)
	return {"parts": parts, "pivots": pivots,
		"order": ["leg_far", "arm_far", "body", "head", "leg_near", "arm_near"]}


# ------------------------------------------------------------------ doodads

func stones(seed_value: int) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	var stone := mats.get_mat("stone")
	for k in rng.randi_range(2, 4):
		var r := rng.randf_range(0.06, 0.13)
		var s := ball(r, stone, Vector3(rng.randf_range(-0.15, 0.15), r * 0.55, rng.randf_range(-0.15, 0.15)), Vector3(1.3, 0.7, 1.0), Vector3(0, rng.randf_range(0, 180), 0))
		n.add_child(s)
	return n


func flowers(seed_value: int) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	var stem := Materials.flat(Color("#4e7a2c"), 1.0)
	var petals: Color = [Color("#f4f0e0"), Color("#f2c94c"), Color("#e07a9a"), Color("#a08ae0")][rng.randi_range(0, 3)]
	for k in rng.randi_range(3, 6):
		var p := Vector3(rng.randf_range(-0.18, 0.18), 0, rng.randf_range(-0.18, 0.18))
		var h := rng.randf_range(0.08, 0.15)
		n.add_child(cyl(0.006, 0.008, h, stem, p + Vector3(0, h / 2, 0), Vector3.ZERO, 5))
		n.add_child(ball(0.03, Materials.flat(petals, 1.0), p + Vector3(0, h, 0), Vector3(1, 0.5, 1)))
		n.add_child(ball(0.012, Materials.flat(Color("#e0a020"), 1.0), p + Vector3(0, h + 0.01, 0)))
	return n


func tuft(seed_value: int) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	for k in 9:
		var h := rng.randf_range(0.1, 0.2)
		var col := Materials.flat([Color("#4e6e28"), Color("#628634"), Color("#7a9840")][k % 3], 1.0)
		n.add_child(box(Vector3(0.018, h, 0.018), col, Vector3(rng.randf_range(-0.06, 0.06), h / 2, rng.randf_range(-0.06, 0.06)),
			Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25))))
	return n


## A few reeds at the water's edge (smaller than a reed bed tile).
func shore_reeds(seed_value: int) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	var stalk := Materials.flat(Color("#8a9a40"), 1.0)
	var tip := Materials.flat(Color("#6b4a2a"), 1.0)
	for k in rng.randi_range(4, 7):
		var h := rng.randf_range(0.35, 0.6)
		var s := cyl(0.012, 0.016, h, stalk, Vector3(rng.randf_range(-0.15, 0.15), h / 2, rng.randf_range(-0.15, 0.15)),
			Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12)), 6)
		n.add_child(s)
		if k % 2 == 0:
			s.add_child(cyl(0.028, 0.028, 0.1, tip, Vector3(0, h / 2 - 0.04, 0), Vector3.ZERO, 8))
	return n


# ------------------------------------------------------------------ sewer-rat ("junk") buildings

## A rat Town Center built from scrap: brick footing, mismatched plank walls patched
## with tin, a corrugated tin roof, a stove-pipe chimney, a sewer grate, a cheese
## wheel; a team rag flag as the live banner.
func junk_town_center(team: Color) -> Dictionary:
	rng.seed = 66
	var body := Node3D.new()
	var brick := mats.get_mat("brick")
	var wood := mats.get_mat("wood")
	var tin := mats.get_mat("tin")
	var iron := Materials.flat(Color("#4a4a48"), 0.5, 0.6)
	body.add_child(box(Vector3(2.8, 0.25, 2.8), brick, Vector3(0, 0.12, 0)))
	var base := 0.25
	var w := 2.1
	var h := 1.05
	# Walls: planks of different shades and lengths, then tin patches over the gaps.
	for side in [-1, 1]:
		for k in 7:
			var t := -w / 2 + 0.15 + k * 0.3
			var hh := h + rng.randf_range(-0.12, 0.08)
			var tint := Materials.flat(Color("#6e4a2c").lerp(Color("#8a7050"), rng.randf()), 0.9)
			body.add_child(box(Vector3(0.28, hh, 0.08), tint, Vector3(t, base + hh / 2, side * w / 2), Vector3(0, 0, rng.randf_range(-3, 3))))
			body.add_child(box(Vector3(0.08, hh, 0.28), tint, Vector3(side * w / 2, base + hh / 2, t), Vector3(rng.randf_range(-3, 3), 0, 0)))
	body.add_child(box(Vector3(w - 0.1, h, w - 0.1), wood, Vector3(0, base + h / 2, 0)))
	for p in [[Vector3(0.5, base + 0.4, w / 2 + 0.06), Vector3(0.6, 0.5, 0.02), Vector3(0, 0, 8)], [Vector3(w / 2 + 0.06, base + 0.65, -0.4), Vector3(0.02, 0.55, 0.7), Vector3(-6, 0, 0)]]:
		body.add_child(box(p[1], tin, p[0], p[2]))
	# Door and windows.
	body.add_child(box(Vector3(0.45, 0.7, 0.05), Materials.flat(Color("#2a1e16"), 0.9), Vector3(-0.35, base + 0.35, w / 2 + 0.08)))
	var lights := []
	for z in [-0.55, 0.35]:
		body.add_child(box(Vector3(0.04, 0.26, 0.3), glow(Color("#ffcf6a"), 1.4), Vector3(w / 2 + 0.07, base + 0.7, z)))
		lights.append(Vector3(w / 2 + 0.1, base + 0.7, z))
	# Corrugated tin gable roof with an overhang, and a ridge cap.
	var roof_y := base + h
	for side in [-1, 1]:
		var panel := box(Vector3(2.7, 0.05, 1.6), tin, Vector3(0, roof_y + 0.42, side * 0.68), Vector3(side * 32, 0, 0))
		panel.rotation_degrees = Vector3(side * 32, 0, 0)
		body.add_child(panel)
	body.add_child(box(Vector3(2.75, 0.08, 0.16), iron, Vector3(0, roof_y + 0.86, 0)))
	for side in [-1, 1]:   # gable ends
		var gable := slab_tri(Vector2(-1.1, 0), Vector2(1.1, 0), Vector2(0, 0.85), 0.06, wood)
		gable.position = Vector3(side * 1.05, roof_y, 0)
		gable.rotation_degrees = Vector3(0, 90, 0)
		body.add_child(gable)
	# Stove-pipe chimney with an elbow.
	var pipe := Vector3(0.6, roof_y + 0.6, -0.55)
	body.add_child(cyl(0.11, 0.11, 0.9, iron, pipe))
	body.add_child(cyl(0.11, 0.11, 0.35, iron, pipe + Vector3(0.12, 0.5, 0), Vector3(0, 0, -50)))
	body.add_child(cyl(0.15, 0.13, 0.1, iron, pipe + Vector3(0.28, 0.62, 0), Vector3(0, 0, -50)))
	# A sewer grate in the forecourt, a cheese wheel with a wedge out, barrels.
	body.add_child(box(Vector3(0.6, 0.03, 0.4), Materials.flat(Color("#1e1c1a"), 0.6), Vector3(0.6, 0.27, 1.15)))
	for k in 5:
		body.add_child(box(Vector3(0.04, 0.05, 0.4), iron, Vector3(0.38 + k * 0.11, 0.29, 1.15)))
	var cheese := Materials.flat(Color("#f2c94c"), 0.7)
	body.add_child(cyl(0.3, 0.3, 0.2, cheese, Vector3(-1.0, 0.36, 1.05), Vector3.ZERO, 20))
	body.add_child(cyl(0.3, 0.3, 0.02, Materials.flat(Color("#c99a1e"), 0.8), Vector3(-1.0, 0.47, 1.05), Vector3.ZERO, 20))
	barrel(Vector3(1.15, base, 0.95), body)
	crate(Vector3(1.2, base, -1.0), body, 35)
	var pole_at := Vector3(-1.2, 0.25, -1.1)
	body.add_child(cyl(0.03, 0.035, 1.9, wood, pole_at + Vector3(0, 0.95, 0), Vector3.ZERO, 8))
	var banner := Node3D.new()
	var flag_top := pole_at + Vector3(0.03, 1.8, 0)
	banner.add_child(box(Vector3(0.55, 0.55, 0.02), cloth(team.darkened(0.15)), flag_top + Vector3(0.3, -0.28, 0), Vector3(0, 0, -4)))
	banner.add_child(box(Vector3(0.2, 0.2, 0.025), cloth(Color("#e8dcc0")), flag_top + Vector3(0.18, -0.4, 0.01)))   # a patch
	var vane := Node3D.new()
	vane.add_child(cyl(0.01, 0.01, 0.3, iron, Vector3(0, roof_y + 1.05, 0), Vector3.ZERO, 6))
	vane.add_child(ball(0.07, Materials.flat(Color("#f2c94c"), 0.6), Vector3(0, roof_y + 1.22, 0)))
	return {"body": body, "anchor": Vector3.ZERO, "banner": banner, "banner_pivot": flag_top,
		"vane": vane, "vane_pivot": Vector3(0, roof_y + 0.9, 0), "smoke": pipe + Vector3(0.32, 0.68, 0), "lights": lights,
		"lantern": Vector3(0.05, base + 0.8, w / 2 + 0.15)}


## A rat house: an upturned tin can with a door cut into it, its lid propped on top
## with a stone, and a little pipe chimney.
func tin_can_house(team: Color) -> Dictionary:
	var body := Node3D.new()
	var tin := mats.get_mat("tin")
	body.add_child(cyl(0.7, 0.7, 1.05, tin, Vector3(0, 0.53, 0), Vector3.ZERO, 28))
	for y in [0.12, 0.5, 0.92]:
		body.add_child(ring(0.69, 0.75, Materials.flat(Color("#9a9c96"), 0.5, 0.5), Vector3(0, y, 0)))
	body.add_child(box(Vector3(0.36, 0.55, 0.05), Materials.flat(Color("#1e1612"), 0.9), Vector3(0.1, 0.3, 0.69), Vector3(0, 8, 0)))
	body.add_child(box(Vector3(0.36, 0.55, 0.03), tin, Vector3(0.38, 0.3, 0.78), Vector3(0, -40, 0)))   # the cut flap
	body.add_child(cyl(0.78, 0.78, 0.06, tin, Vector3(0.08, 1.12, 0.02), Vector3(6, 0, -5), 28))      # the lid
	body.add_child(ball(0.16, mats.get_mat("stone"), Vector3(-0.15, 1.24, -0.1), Vector3(1.2, 0.8, 1)))
	body.add_child(cyl(0.06, 0.06, 0.35, Materials.flat(Color("#4a4a48"), 0.5, 0.6), Vector3(0.35, 1.3, -0.3), Vector3.ZERO, 8))
	body.add_child(box(Vector3(0.25, 0.04, 0.12), cloth(team), Vector3(-0.5, 0.75, 0.48), Vector3(0, 40, 10)))   # a team rag
	return {"body": body, "anchor": Vector3.ZERO, "smoke": Vector3(0.35, 1.5, -0.3), "lights": [],
		"lantern": Vector3(0.4, 0.75, 0.75), "team": team}


func slab_tri(a: Vector2, b: Vector2, c: Vector2, thick: float, m: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [1.0, -1.0]:
		for p in ([a, b, c] if face > 0 else [a, c, b]):
			st.set_normal(Vector3(0, 0, face))
			st.add_vertex(Vector3(p.x, p.y, thick * 0.5 * face))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	return mi


# ------------------------------------------------------------------ stone culture (imperial, hellenic, royal)

## A cylinder from a to b.
func beam(a: Vector3, b: Vector3, r: float, mat: Material, seg := 8) -> MeshInstance3D:
	var mi := cyl(r, r, a.distance_to(b), mat, (a + b) * 0.5, Vector3.ZERO, seg)
	mi.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	return mi


## A terracotta gable roof, ridge along z: two tiled slopes with rows of rounded cover
## tiles running down them, a ridge line, and the gable triangles at both ends.
func tile_roof(parent: Node3D, centre: Vector3, half_span: float, length: float, pitch_deg: float, front_gable: Material, back_gable: Material) -> float:
	var tile := mats.get_mat("terracotta")
	var pitch := deg_to_rad(pitch_deg)
	var rise := half_span * tan(pitch)
	var slope := half_span / cos(pitch)
	for side in [-1, 1]:
		parent.add_child(box(Vector3(slope + 0.06, 0.05, length), mats.get_mat("terracotta_dark"), centre + Vector3(side * half_span / 2, rise / 2, 0), Vector3(0, 0, -side * pitch_deg)))
		var z := -length / 2 + 0.07
		while z < length / 2 - 0.04:
			var top := centre + Vector3(0, rise + 0.03, z)
			var eave := centre + Vector3(side * (half_span + 0.03), 0.0, z)
			parent.add_child(beam(top, eave, 0.05, tile))
			z += 0.17
	parent.add_child(beam(centre + Vector3(0, rise + 0.05, -length / 2 - 0.02), centre + Vector3(0, rise + 0.05, length / 2 + 0.02), 0.06, tile))
	for end in [[1, front_gable], [-1, back_gable]]:
		var g := slab_tri(Vector2(-half_span, 0), Vector2(half_span, 0), Vector2(0, rise), 0.08, end[1])
		g.position = centre + Vector3(0, 0, end[0] * (length / 2 - 0.05))
		parent.add_child(g)
	return rise


## A stone-culture Town Center: a stepped podium, a limewashed hall with a team-colour
## frieze, a columned porch under a pediment, a terracotta roof and a fire bowl.
func stone_town_center(team: Color) -> Dictionary:
	var body := Node3D.new()
	var stone := mats.get_mat("stone")
	var plaster := mats.get_mat("plaster")
	var marble := Materials.flat(Color("#e6e0d2"), 0.75)
	var bronze := Materials.flat(Color("#b07a36"), 0.4, 0.7)
	body.add_child(box(Vector3(2.9, 0.14, 2.9), stone, Vector3(0, 0.07, 0)))
	body.add_child(box(Vector3(2.6, 0.14, 2.6), stone, Vector3(0, 0.21, 0)))
	var base := 0.28
	var w := 1.9
	var d := 1.55
	var h := 1.0
	var hall_z := -0.35
	body.add_child(box(Vector3(w + 0.06, 0.14, d + 0.06), stone, Vector3(0, base + 0.07, hall_z)))
	body.add_child(box(Vector3(w, h, d), plaster, Vector3(0, base + h / 2, hall_z)))
	body.add_child(box(Vector3(w + 0.03, 0.12, d + 0.03), cloth(team), Vector3(0, base + h - 0.16, hall_z)))   # frieze
	body.add_child(box(Vector3(w + 0.08, 0.07, d + 0.08), marble, Vector3(0, base + h - 0.035, hall_z)))
	# Windows high on the +x wall, with marble sills; they glow at night.
	var lights := []
	for z in [-0.75, 0.05]:
		body.add_child(box(Vector3(0.04, 0.32, 0.22), glow(Color("#ffcf6a"), 1.4), Vector3(w / 2 + 0.01, base + 0.55, hall_z + z + 0.35)))
		body.add_child(box(Vector3(0.08, 0.05, 0.3), marble, Vector3(w / 2 + 0.03, base + 0.37, hall_z + z + 0.35)))
		lights.append(Vector3(w / 2 + 0.04, base + 0.55, hall_z + z + 0.35))
	# Bronze-studded double door in the front wall.
	var front_wall := hall_z + d / 2
	body.add_child(box(Vector3(0.5, 0.74, 0.04), Materials.flat(Color("#4a2a18"), 0.8), Vector3(0, base + 0.37, front_wall + 0.02)))
	body.add_child(box(Vector3(0.6, 0.08, 0.06), marble, Vector3(0, base + 0.78, front_wall + 0.03)))
	for k in 6:
		body.add_child(ball(0.022, bronze, Vector3(-0.15 + (k % 3) * 0.15, base + 0.25 + (k / 3) * 0.3, front_wall + 0.045)))
	# The porch: four columns with bases and capitals, under an entablature.
	var porch_z := front_wall + 0.5
	for k in 4:
		var x := -0.78 + k * 0.52
		body.add_child(cyl(0.075, 0.09, h - 0.12, marble, Vector3(x, base + h / 2, porch_z), Vector3.ZERO, 14))
		body.add_child(box(Vector3(0.22, 0.06, 0.22), marble, Vector3(x, base + 0.03, porch_z)))
		body.add_child(box(Vector3(0.24, 0.07, 0.24), marble, Vector3(x, base + h - 0.035, porch_z)))
	body.add_child(box(Vector3(w + 0.12, 0.14, porch_z - front_wall + 0.2), marble, Vector3(0, base + h + 0.07, (porch_z + front_wall) / 2)))
	# The roof over hall and porch; a team shield in the pediment.
	var roof_c := Vector3(0, base + h + 0.14, (hall_z - d / 2 - 0.12 + porch_z + 0.16) / 2)
	var length := (porch_z + 0.16) - (hall_z - d / 2 - 0.12)
	var rise := tile_roof(body, roof_c, w / 2 + 0.14, length, 24.0, marble, plaster)
	body.add_child(ball(0.13, cloth(team), roof_c + Vector3(0, rise * 0.4, length / 2 - 0.0), Vector3(1, 1, 0.3)))
	body.add_child(ring(0.12, 0.16, bronze, roof_c + Vector3(0, rise * 0.4, length / 2 + 0.01), Vector3(90, 0, 0)))
	for x in [-w / 2 - 0.1, 0.0, w / 2 + 0.1]:   # little finials on the pediment
		body.add_child(ball(0.06, marble, roof_c + Vector3(x, (rise + 0.08) if x == 0.0 else 0.06, length / 2)))
	# A fire bowl on a tripod by the steps (it smokes and glows).
	var bowl := Vector3(1.05, base, 1.05)
	for k in 3:
		var a := TAU * k / 3.0
		body.add_child(beam(bowl + Vector3(cos(a) * 0.12, 0, sin(a) * 0.12), bowl + Vector3(0, 0.42, 0), 0.015, bronze))
	body.add_child(cyl(0.16, 0.08, 0.1, bronze, bowl + Vector3(0, 0.46, 0), Vector3.ZERO, 16))
	body.add_child(cyl(0.13, 0.13, 0.02, glow(Color("#ff9a3a"), 2.0), bowl + Vector3(0, 0.51, 0), Vector3.ZERO, 16))
	# Amphorae on the podium.
	for p in [Vector3(-1.05, base, 0.95), Vector3(-0.9, base, 1.12)]:
		var clay := mats.get_mat("terracotta")
		body.add_child(ball(0.1, clay, p + Vector3(0, 0.14, 0), Vector3(1, 1.4, 1)))
		body.add_child(cyl(0.035, 0.045, 0.1, clay, p + Vector3(0, 0.31, 0), Vector3.ZERO, 10))
	# A banner on a tall pole at the corner, and a bronze vane on the ridge (live parts).
	var wood := mats.get_mat("wood")
	var pole_at := Vector3(-1.25, base, 1.25)
	body.add_child(cyl(0.035, 0.04, 2.1, wood, pole_at + Vector3(0, 1.05, 0), Vector3.ZERO, 8))
	body.add_child(ball(0.07, bronze, pole_at + Vector3(0, 2.13, 0)))
	var banner := Node3D.new()
	var flag_top := pole_at + Vector3(0.04, 2.0, 0)
	banner.add_child(box(Vector3(0.66, 0.06, 0.03), wood, flag_top + Vector3(0.33, 0, 0)))
	banner.add_child(box(Vector3(0.6, 0.8, 0.02), cloth(team), flag_top + Vector3(0.33, -0.42, 0)))
	banner.add_child(ring(0.1, 0.15, cloth(Color("#f2c94c")), flag_top + Vector3(0.33, -0.38, 0.015), Vector3(90, 0, 0)))
	var vane := Node3D.new()
	var apex := roof_c + Vector3(0, rise + 0.08, -length / 2 + 0.25)
	vane.add_child(cyl(0.012, 0.012, 0.35, bronze, apex + Vector3(0, 0.17, 0), Vector3.ZERO, 6))
	vane.add_child(box(Vector3(0.36, 0.02, 0.02), bronze, apex + Vector3(0, 0.33, 0)))
	vane.add_child(slab_tri(Vector2(0.1, 0), Vector2(0.24, 0.06), Vector2(0.24, -0.06), 0.02, bronze))
	vane.get_child(vane.get_child_count() - 1).position = apex + Vector3(0, 0.33, 0)
	return {"body": body, "anchor": Vector3.ZERO, "banner": banner, "banner_pivot": flag_top,
		"vane": vane, "vane_pivot": apex, "smoke": bowl + Vector3(0, 0.6, 0), "lights": lights,
		"lantern": bowl + Vector3(0, 0.52, 0)}


## A stone-culture house: limewashed walls on a stone plinth, a tile roof, team-colour
## shutters, an amphora by the door and a cypress.
func villa_house(team: Color) -> Dictionary:
	var body := Node3D.new()
	var stone := mats.get_mat("stone")
	var plaster := mats.get_mat("plaster")
	var w := 1.15
	var d := 1.0
	var h := 0.72
	body.add_child(box(Vector3(w + 0.14, 0.12, d + 0.14), stone, Vector3(0, 0.06, 0)))
	body.add_child(box(Vector3(w, h, d), plaster, Vector3(0, 0.12 + h / 2, 0)))
	body.add_child(box(Vector3(w + 0.02, 0.1, d + 0.02), stone, Vector3(0, 0.17, 0)))
	var front := d / 2
	body.add_child(box(Vector3(0.28, 0.48, 0.04), Materials.flat(Color("#4a2a18"), 0.8), Vector3(-0.22, 0.12 + 0.24, front + 0.02)))
	body.add_child(box(Vector3(0.36, 0.06, 0.06), stone, Vector3(-0.22, 0.12 + 0.5, front + 0.03)))
	# A window on the +x wall with team-colour shutters thrown open.
	body.add_child(box(Vector3(0.04, 0.2, 0.18), glow(Color("#ffcf6a"), 1.2), Vector3(w / 2 + 0.01, 0.12 + 0.42, 0.05)))
	for s in [-1, 1]:
		body.add_child(box(Vector3(0.1, 0.22, 0.02), cloth(team), Vector3(w / 2 + 0.06, 0.12 + 0.42, 0.05 + s * 0.15), Vector3(0, s * 60, 0)))
	var rise := tile_roof(body, Vector3(0, 0.12 + h, 0), w / 2 + 0.1, d + 0.16, 26.0, plaster, plaster)
	var clay := mats.get_mat("terracotta")
	body.add_child(ball(0.08, clay, Vector3(0.2, 0.12 + 0.1, front + 0.14), Vector3(1, 1.4, 1)))
	body.add_child(cyl(0.03, 0.035, 0.08, clay, Vector3(0.2, 0.12 + 0.24, front + 0.14), Vector3.ZERO, 10))
	var cypress := Materials.flat(Color("#2e4a26"), 0.95)
	body.add_child(cyl(0.03, 0.04, 0.3, mats.get_mat("wood"), Vector3(-0.72, 0.15, 0.4), Vector3.ZERO, 6))
	body.add_child(ball(0.17, cypress, Vector3(-0.72, 0.75, 0.4), Vector3(1, 3.4, 1)))
	body.add_child(cyl(0.05, 0.05, 0.3, stone, Vector3(0.3, 0.12 + h + rise + 0.05, -0.2), Vector3.ZERO, 8))   # chimney
	return {"body": body, "anchor": Vector3.ZERO, "smoke": Vector3(0.3, 0.12 + h + rise + 0.25, -0.2), "lights": [],
		"lantern": Vector3(-0.22, 0.12 + 0.62, front + 0.1), "team": team}


# ------------------------------------------------------------------ tent culture (steppe)

## A felt tent: a round lattice wall, a conical roof with a smoke crown, rope bands
## and a team-colour door flap.
func _yurt(parent: Node3D, at: Vector3, r: float, wall_h: float, team: Color) -> float:
	var felt := mats.get_mat("felt")
	var rope := Materials.flat(Color("#8a6a3c"), 0.9)
	parent.add_child(cyl(r, r, wall_h, felt, at + Vector3(0, wall_h / 2, 0), Vector3.ZERO, 28))
	for y in [0.3, 0.7]:
		parent.add_child(ring(r - 0.01, r + 0.03, rope, at + Vector3(0, wall_h * y, 0)))
	var roof_h := r * 0.55
	parent.add_child(cyl(r * 0.18, r + 0.06, roof_h, felt, at + Vector3(0, wall_h + roof_h / 2, 0), Vector3.ZERO, 28))
	parent.add_child(cyl(r * 0.2, r * 0.2, 0.06, mats.get_mat("wood"), at + Vector3(0, wall_h + roof_h + 0.02, 0), Vector3.ZERO, 16))
	for k in 8:   # roof ropes
		var a := TAU * k / 8.0
		parent.add_child(beam(at + Vector3(cos(a) * r * 0.2, wall_h + roof_h, sin(a) * r * 0.2), at + Vector3(cos(a) * (r + 0.05), wall_h, sin(a) * (r + 0.05)), 0.012, rope, 4))
	var door := at + Vector3(0, 0, r)
	parent.add_child(box(Vector3(0.3, wall_h * 0.8, 0.03), cloth(team), door + Vector3(0, wall_h * 0.4, 0.01)))
	parent.add_child(box(Vector3(0.36, 0.05, 0.05), mats.get_mat("wood"), door + Vector3(0, wall_h * 0.82, 0.02)))
	return wall_h + roof_h


## A tent-culture Town Center: a great felt tent with a smaller one beside it, a cart,
## a hitching rail and a pennant standard.
func tent_town_center(team: Color) -> Dictionary:
	var body := Node3D.new()
	var wood := mats.get_mat("wood")
	var top := _yurt(body, Vector3(-0.15, 0.0, -0.15), 1.05, 0.75, team)
	_yurt(body, Vector3(0.95, 0.0, 0.75), 0.42, 0.42, team)
	# A cart with two big wheels.
	var cart := Vector3(-0.95, 0.06, 0.95)
	body.add_child(box(Vector3(0.55, 0.06, 0.35), wood, cart + Vector3(0, 0.26, 0)))
	for z in [-0.2, 0.2]:
		body.add_child(ring(0.13, 0.17, wood, cart + Vector3(0, 0.17, z), Vector3(90, 0, 0)))
	body.add_child(beam(cart + Vector3(0.27, 0.26, 0), cart + Vector3(0.7, 0.06, 0.05), 0.02, wood))
	for k in 3:
		body.add_child(ball(0.08, mats.get_mat("weave"), cart + Vector3(-0.15 + k * 0.15, 0.36, 0)))
	# A hitching rail.
	for x in [0.2, 0.9]:
		body.add_child(cyl(0.025, 0.025, 0.3, wood, Vector3(x, 0.21, 1.3), Vector3.ZERO, 6))
	body.add_child(beam(Vector3(0.2, 0.33, 1.3), Vector3(0.9, 0.33, 1.3), 0.02, wood))
	# The standard: a pole with a team pennant (a live banner), and a vane on the crown.
	var pole_at := Vector3(-1.2, 0.06, -0.9)
	body.add_child(cyl(0.03, 0.035, 2.0, wood, pole_at + Vector3(0, 1.0, 0), Vector3.ZERO, 8))
	var banner := Node3D.new()
	var flag_top := pole_at + Vector3(0.03, 1.9, 0)
	banner.add_child(box(Vector3(0.5, 0.05, 0.03), wood, flag_top + Vector3(0.25, 0, 0)))
	banner.add_child(slab_tri(Vector2(0, 0), Vector2(0.62, -0.22), Vector2(0, -0.5), 0.02, cloth(team)))
	banner.get_child(banner.get_child_count() - 1).position = flag_top
	var vane := Node3D.new()
	var apex := Vector3(-0.15, top + 0.04, -0.15)
	vane.add_child(cyl(0.012, 0.012, 0.3, wood, apex + Vector3(0, 0.15, 0), Vector3.ZERO, 6))
	vane.add_child(box(Vector3(0.3, 0.02, 0.02), Materials.flat(Color("#b07a36"), 0.4, 0.7), apex + Vector3(0, 0.28, 0)))
	return {"body": body, "anchor": Vector3.ZERO, "banner": banner, "banner_pivot": flag_top,
		"vane": vane, "vane_pivot": apex, "smoke": apex + Vector3(0, 0.1, 0), "lights": [],
		"lantern": Vector3(-0.15, 0.5, 0.95)}


## A tent-culture house: one felt tent and a woodpile.
func tent_house(team: Color) -> Dictionary:
	var body := Node3D.new()
	var top := _yurt(body, Vector3.ZERO, 0.62, 0.48, team)
	woodpile(Vector3(0.7, 0, -0.3), body)
	return {"body": body, "anchor": Vector3.ZERO, "smoke": Vector3(0, top + 0.1, 0), "lights": [],
		"lantern": Vector3(0, 0.35, 0.7), "team": team}
