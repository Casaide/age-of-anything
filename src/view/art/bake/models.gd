extends RefCounted
## Detailed 3D models for the high-fidelity pre-render, built from primitives
## with procedural materials. 1 world unit = 1 tile; y is up; sim x = world x,
## sim y = world z. Each builder returns the static body plus the "live" bits
## (animated in 2D after baking) and the points the 2D side needs.

const Materials := preload("res://src/view/art/bake/materials.gd")

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


## The top half of a sphere, sitting on pos.
func dome(r: float, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r
	s.is_hemisphere = true
	s.radial_segments = 32
	s.rings = 10
	return _mi(s, mat, pos, Vector3.ZERO, scl)


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
	return {"body": body, "anchor": Vector3.ZERO, "smoke": Vector3(0.35, 2.1, -0.2), "lights": [],
		"lantern": Vector3(0.32, 0.95, 0.66), "team": team}


# ------------------------------------------------------------------ ground

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

func flowers(seed_value: int) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	var stem := Materials.flat(Color("#4e7a2c"), 1.0)
	var petals: Color = [Color("#f4f0e0"), Color("#f2c94c"), Color("#e07a9a"), Color("#a08ae0")][rng.randi_range(0, 3)]
	for k in rng.randi_range(3, 6):
		var p := Vector3(rng.randf_range(-0.18, 0.18), 0, rng.randf_range(-0.18, 0.18))
		var h := rng.randf_range(0.08, 0.15)
		n.add_child(cyl(0.006, 0.008, h, stem, p + Vector3(0, h / 2, 0), Vector3.ZERO, 5))
		n.add_child(ball(0.045, Materials.flat(petals, 1.0), p + Vector3(0, h, 0), Vector3(1, 0.5, 1)))
		n.add_child(ball(0.035, stem, p + Vector3(0.02, 0.015, 0), Vector3(1.4, 0.4, 0.8)))   # a leaf
		n.add_child(ball(0.012, Materials.flat(Color("#e0a020"), 1.0), p + Vector3(0, h + 0.01, 0)))
	return n


## A rat Town Center built from scrap: brick footing, mismatched plank walls patched
## with tin, a corrugated tin roof, a stove-pipe chimney, a sewer grate, a cheese
## wheel; a team rag flag as the live banner.
## h: wall height; pitch: roof slope; berm: earth and scrap banked against the walls, so the
## hall sits low and grows out of the ground (the scale rule lets a culture sit lower, D-080).
func junk_town_center(team: Color, h := 1.05, pitch := 32.0, berm := false, plinth := true) -> Dictionary:
	rng.seed = 66
	var body := Node3D.new()
	var brick := mats.get_mat("brick")
	var wood := mats.get_mat("wood")
	var tin := mats.get_mat("tin")
	var iron := Materials.flat(Color("#4a4a48"), 0.5, 0.6)
	var base := 0.25
	if berm or not plinth:
		base = 0.02   # no plinth: the hall stands on the ground
	else:
		body.add_child(box(Vector3(2.8, 0.25, 2.8), brick, Vector3(0, 0.12, 0)))
	var w := 2.1
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
	var ridge := tan(deg_to_rad(pitch)) * 1.375   # 0.86 at the original 32 degrees
	for side in [-1, 1]:
		var panel := box(Vector3(2.7, 0.05, 1.6), tin, Vector3(0, roof_y + ridge * 0.5, side * 0.68), Vector3(side * pitch, 0, 0))
		body.add_child(panel)
	body.add_child(box(Vector3(2.75, 0.08, 0.16), iron, Vector3(0, roof_y + ridge, 0)))
	for side in [-1, 1]:   # gable ends
		var gable := slab_tri(Vector2(-1.1, 0), Vector2(1.1, 0), Vector2(0, ridge), 0.06, wood)
		gable.position = Vector3(side * 1.05, roof_y, 0)
		gable.rotation_degrees = Vector3(0, 90, 0)
		body.add_child(gable)
	# Stove-pipe chimney with an elbow.
	var pipe := Vector3(0.6, roof_y + ridge * 0.7, -0.55)
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
	if berm:   # a grassy earth bank up the walls, scrap half-buried in it: the hall sits in the ground
		var earth := mats.get_mat("mud")
		var turf := Materials.flat(Color("#5e7a34"), 0.95)
		# A square-sided cylinder's radius runs to its corners: half-widths x sqrt(2).
		body.add_child(cyl(1.13 * 1.414, 1.55 * 1.414, 0.45, earth, Vector3(0, 0.225, 0), Vector3(0, 45, 0), 4))   # the bank
		body.add_child(cyl(1.12 * 1.414, 1.3 * 1.414, 0.12, turf, Vector3(0, 0.41, 0), Vector3(0, 45, 0), 4))      # turf on top
		for k in 3:   # pipes and a tin sheet poking out of the bank
			body.add_child(cyl(0.11, 0.11, 0.5, iron, Vector3(-1.3 + k * 0.55, 0.18, -1.3), Vector3(70, k * 25, 0)))
		body.add_child(box(Vector3(0.5, 0.03, 0.4), tin, Vector3(1.3, 0.3, 0.4), Vector3(20, 30, 10)))
	var pole_at := Vector3(-1.2, 0.25, -1.1)
	body.add_child(cyl(0.03, 0.035, 1.9, wood, pole_at + Vector3(0, 0.95, 0), Vector3.ZERO, 8))
	var banner := Node3D.new()
	var flag_top := pole_at + Vector3(0.03, 1.8, 0)
	banner.add_child(box(Vector3(0.55, 0.55, 0.02), cloth(team.darkened(0.15)), flag_top + Vector3(0.3, -0.28, 0), Vector3(0, 0, -4)))
	banner.add_child(box(Vector3(0.2, 0.2, 0.025), cloth(Color("#e8dcc0")), flag_top + Vector3(0.18, -0.4, 0.01)))   # a patch
	var vane := Node3D.new()
	vane.add_child(cyl(0.01, 0.01, 0.3, iron, Vector3(0, roof_y + ridge + 0.19, 0), Vector3.ZERO, 6))
	vane.add_child(ball(0.07, Materials.flat(Color("#f2c94c"), 0.6), Vector3(0, roof_y + ridge + 0.36, 0)))
	return {"body": body, "anchor": Vector3.ZERO, "banner": banner, "banner_pivot": flag_top,
		"vane": vane, "vane_pivot": Vector3(0, roof_y + ridge + 0.04, 0), "smoke": pipe + Vector3(0.32, 0.68, 0), "lights": lights,
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


## A farm going in: a tilled plot inside a post-and-rail fence, seed sacks and a hoe by
## the gate, a team pennant on the corner post. The same for every culture (a finished
## farm becomes its field: crops on land, a rice paddy in water).
func farm_plot(team: Color) -> Dictionary:
	var body := Node3D.new()
	var wood := mats.get_mat("wood")
	body.add_child(box(Vector3(1.8, 0.05, 1.8), mats.get_mat("mud"), Vector3(0, 0.025, 0)))
	for k in 6:   # furrows
		body.add_child(box(Vector3(1.6, 0.04, 0.07), Materials.flat(Color("#4e3820"), 1.0), Vector3(0, 0.06, -0.72 + k * 0.29)))
	var half := 0.92
	for side in 4:
		for k in 5:
			var t := -half + k * half * 0.5
			var p := Vector3(t, 0.0, half) if side == 0 else Vector3(half, 0.0, t) if side == 1 else Vector3(t, 0.0, -half) if side == 2 else Vector3(-half, 0.0, t)
			if side == 0 and k == 2:
				continue   # the gate
			body.add_child(cyl(0.03, 0.035, 0.32, wood, p + Vector3(0, 0.16, 0), Vector3.ZERO, 6))
		var a := Vector3(-half, 0.24, half) if side == 0 else Vector3(half, 0.24, half) if side == 1 else Vector3(half, 0.24, -half) if side == 2 else Vector3(-half, 0.24, -half)
		var b := Vector3(half, 0.24, half) if side == 0 else Vector3(half, 0.24, -half) if side == 1 else Vector3(-half, 0.24, -half) if side == 2 else Vector3(-half, 0.24, half)
		body.add_child(box(Vector3(a.distance_to(b), 0.035, 0.035), wood, (a + b) * 0.5, Vector3(0, -rad_to_deg(atan2(b.z - a.z, b.x - a.x)), 0)))
	for k in 2:
		body.add_child(ball(0.09, Materials.flat(Color("#b8a074"), 1.0), Vector3(0.55 + k * 0.17, 0.11, 1.08), Vector3(1, 1.2, 1)))
	return {"body": body, "anchor": Vector3.ZERO, "lights": [], "team": team}


# ------------------------------------------------------------------ military buildings, per culture
# One shape each (a training hall, a stable, a lookout tower), built in each architecture's
# own materials and roof: mud and thatch, scrap tin and brick, limewash and tile, felt and poles.

const KIT := {
	"thatch": {"wall": "mud", "frame": "wood", "roof": "thatch", "base": "stone"},
	"junk": {"wall": "tin", "frame": "wood", "roof": "tin", "base": "brick"},
	"stone": {"wall": "plaster", "frame": "stone", "roof": "tiles", "base": "stone"},
	"tent": {"wall": "felt", "frame": "wood", "roof": "felt", "base": ""},
	"reed": {"wall": "weave", "frame": "wood", "roof": "thatch", "base": "", "dome": true, "stilts": true},
	"mound": {"wall": "mud", "frame": "wood", "roof": "mud", "base": "", "dome": true},
}


## A roof over a w x d box, ridge along x, in the architecture's way: thick thatch,
## corrugated tin, terracotta tiles or a felt ridge tent. Returns the ridge height.
func _roof(body: Node3D, arch: String, at: Vector3, w: float, d: float) -> float:
	var k: Dictionary = KIT[arch]
	if k.get("dome", false):   # a rounded roof: woven reed, or packed earth
		var rise := d * 0.5
		body.add_child(dome(1.0, mats.get_mat(k.roof), at - Vector3(0, 0.05, 0), Vector3(w / 2 + 0.18, rise, d / 2 + 0.18)))
		if arch == "reed":
			_lily_cap(body, at + Vector3(0, rise - 0.06, 0), 0.32)
		return rise
	if k.roof == "tiles":
		var holder := Node3D.new()
		holder.rotation_degrees = Vector3(0, 90, 0)   # tile_roof runs its ridge along z
		holder.position = at
		body.add_child(holder)
		return tile_roof(holder, Vector3.ZERO, d / 2 + 0.12, w + 0.2, 26.0, mats.get_mat("plaster"), mats.get_mat("plaster"))
	var mat: Material = mats.get_mat(k.roof)
	var rise := d * (0.42 if k.roof == "thatch" else 0.3)
	var slope := Vector2(d / 2 + 0.15, rise).length()
	var ang := rad_to_deg(atan2(rise, d / 2 + 0.15))
	var thick := 0.16 if k.roof == "thatch" else 0.05
	for side in [-1, 1]:
		body.add_child(box(Vector3(w + 0.3, thick, slope), mat, at + Vector3(0, rise / 2, side * (d / 4 + 0.07)), Vector3(side * ang, 0, 0)))
	for side in [-1, 1]:   # gable ends
		var g := slab_tri(Vector2(-d / 2, 0), Vector2(d / 2, 0), Vector2(0, rise), 0.06, mats.get_mat(k.wall))
		g.position = at + Vector3(side * w / 2, 0, 0)
		g.rotation_degrees = Vector3(0, 90, 0)
		body.add_child(g)
	body.add_child(box(Vector3(w + 0.34, 0.08, 0.1), mats.get_mat("wood"), at + Vector3(0, rise + 0.02, 0)))
	return rise


## A hall's walls on a plinth, with the culture's frame at the corners.
func _hall(body: Node3D, arch: String, w: float, d: float, h: float) -> float:
	var k: Dictionary = KIT[arch]
	var base := 0.0
	if k.base != "":
		body.add_child(box(Vector3(w + 0.3, 0.16, d + 0.3), mats.get_mat(k.base), Vector3(0, 0.08, 0)))
		base = 0.16
	if k.get("stilts", false):
		base = _stilt_deck(body, Vector3.ZERO, w + 0.3, d + 0.3)
	body.add_child(box(Vector3(w, h, d), mats.get_mat(k.wall), Vector3(0, base + h / 2, 0)))
	for x in [-1, 1]:
		for z in [-1, 1]:
			body.add_child(box(Vector3(0.12, h + 0.04, 0.12), mats.get_mat(k.frame), Vector3(x * w / 2, base + h / 2, z * d / 2)))
	return base


func barracks_thatch(team: Color) -> Dictionary:
	return _barracks("thatch", team)


func barracks_junk(team: Color) -> Dictionary:
	return _barracks("junk", team)


func barracks_stone(team: Color) -> Dictionary:
	return _barracks("stone", team)


func barracks_tent(team: Color) -> Dictionary:
	return _barracks("tent", team)


## A training hall: a long hall with a team-colour door curtain, a fenced yard in front
## with a straw target, a practice dummy and a weapon rack.
func _barracks(arch: String, team: Color) -> Dictionary:
	var body := Node3D.new()
	var wood := mats.get_mat("wood")
	var w := 2.3
	var d := 1.3
	var h := 0.85
	var hall := Node3D.new()
	hall.position = Vector3(0, 0, -0.55)
	body.add_child(hall)
	var base := _hall(hall, arch, w, d, h)
	var rise := _roof(hall, arch, Vector3(0, base + h, 0), w, d)
	hall.add_child(box(Vector3(0.5, 0.62, 0.04), cloth(team), Vector3(-0.3, base + 0.31, d / 2 + 0.02)))
	var lights := []
	body.add_child(box(Vector3(0.04, 0.22, 0.32), glow(Color("#ffcf6a"), 1.3), Vector3(w / 2 + 0.01, base + 0.55, -0.55)))
	lights.append(Vector3(w / 2 + 0.03, base + 0.55, -0.55))
	# The yard: a low fence, a straw target, a dummy, a rack of spears.
	for k in 6:
		var x := -1.25 + k * 0.5
		body.add_child(cyl(0.025, 0.03, 0.26, wood, Vector3(x, 0.13, 1.3), Vector3.ZERO, 6))
	body.add_child(box(Vector3(2.55, 0.03, 0.03), wood, Vector3(0, 0.22, 1.3)))
	body.add_child(cyl(0.2, 0.2, 0.07, mats.get_mat("thatch"), Vector3(0.75, 0.38, 0.75), Vector3(80, 0, 0), 20))   # the target
	body.add_child(ring(0.06, 0.1, cloth(Color("#c03030")), Vector3(0.75, 0.38, 0.79), Vector3(80, 0, 0)))
	body.add_child(cyl(0.025, 0.025, 0.42, wood, Vector3(0.75, 0.21, 0.72), Vector3(-10, 0, 0), 6))
	body.add_child(cyl(0.03, 0.03, 0.5, wood, Vector3(-0.6, 0.25, 0.75), Vector3.ZERO, 6))          # the dummy
	body.add_child(ball(0.12, mats.get_mat("felt"), Vector3(-0.6, 0.48, 0.75), Vector3(1, 1.4, 1)))
	body.add_child(ball(0.07, mats.get_mat("felt"), Vector3(-0.6, 0.66, 0.75)))
	body.add_child(box(Vector3(0.46, 0.03, 0.03), wood, Vector3(-0.6, 0.5, 0.75)))
	for k in 4:   # the rack
		body.add_child(beam(Vector3(-1.1 + k * 0.08, 0.05, 0.25), Vector3(-1.04 + k * 0.08, 0.72, 0.18), 0.012, wood))
	body.add_child(box(Vector3(0.36, 0.03, 0.05), wood, Vector3(-0.98, 0.5, 0.22)))
	return {"body": body, "anchor": Vector3.ZERO, "smoke": Vector3(0.6, base + h + rise, -0.75), "lantern": Vector3(-0.3, base + 0.72, 0.2),
		"lights": lights, "team": team}


func stable_thatch(team: Color) -> Dictionary:
	return _stable("thatch", team)


func stable_junk(team: Color) -> Dictionary:
	return _stable("junk", team)


func stable_stone(team: Color) -> Dictionary:
	return _stable("stone", team)


func stable_tent(team: Color) -> Dictionary:
	return _stable("tent", team)


## A stable: an open-fronted barn with stalls, hay bales, a trough and a team blanket
## over the rail.
func _stable(arch: String, team: Color) -> Dictionary:
	var body := Node3D.new()
	var k: Dictionary = KIT[arch]
	var wood := mats.get_mat("wood")
	var w := 2.4
	var d := 1.6
	var h := 0.8
	var base := 0.0
	if k.base != "":
		body.add_child(box(Vector3(w + 0.3, 0.12, d + 0.3), mats.get_mat(k.base), Vector3(0, 0.06, -0.3)))
		base = 0.12
	body.add_child(box(Vector3(w, h, 0.08), mats.get_mat(k.wall), Vector3(0, base + h / 2, -0.3 - d / 2)))   # back wall
	for side in [-1, 1]:
		body.add_child(box(Vector3(0.08, h, d), mats.get_mat(k.wall), Vector3(side * w / 2, base + h / 2, -0.3)))
	for x in [-1.2, -0.4, 0.4, 1.2]:   # posts and stall boards
		body.add_child(box(Vector3(0.1, h, 0.1), mats.get_mat(k.frame), Vector3(x, base + h / 2, -0.3 + d / 2)))
		if absf(x) < 1.0:
			body.add_child(box(Vector3(0.05, h * 0.6, d * 0.8), wood, Vector3(x, base + h * 0.3, -0.35)))
	body.add_child(box(Vector3(w, 0.06, 0.06), wood, Vector3(0, base + h * 0.55, -0.3 + d / 2)))   # the rail
	body.add_child(box(Vector3(0.5, 0.18, 0.03), cloth(team), Vector3(0.0, base + h * 0.45, -0.3 + d / 2 + 0.04)))   # a blanket over it
	var rise := _roof(body, arch, Vector3(0, base + h, -0.3), w, d)
	var hay := Materials.flat(Color("#d6b45a"), 1.0)
	for p in [Vector3(-0.9, 0.12, 0.85), Vector3(-0.55, 0.12, 0.95), Vector3(-0.75, 0.32, 0.9)]:
		body.add_child(box(Vector3(0.32, 0.2, 0.22), hay, p + Vector3(0, base, 0)))
	body.add_child(box(Vector3(0.6, 0.14, 0.18), wood, Vector3(0.8, base + 0.07, 0.75)))   # trough
	body.add_child(box(Vector3(0.54, 0.02, 0.12), Materials.flat(Color("#4e7a86"), 0.4), Vector3(0.8, base + 0.13, 0.75)))
	return {"body": body, "anchor": Vector3.ZERO, "lantern": Vector3(0.0, base + h * 0.75, 0.55), "lights": [], "team": team}


func watchtower_thatch(team: Color) -> Dictionary:
	return _tower("thatch", team)


func watchtower_junk(team: Color) -> Dictionary:
	return _tower("junk", team)


func watchtower_stone(team: Color) -> Dictionary:
	return _tower("stone", team)


func watchtower_tent(team: Color) -> Dictionary:
	return _tower("tent", team)


## A lookout tower on a one-tile footing: a solid base (or four poles, for tents and junk),
## a railed platform, a little roof, a team flag; a lantern up top.
func _tower(arch: String, team: Color) -> Dictionary:
	var body := Node3D.new()
	var k: Dictionary = KIT[arch]
	var wood := mats.get_mat("wood")
	var top := 1.7
	if arch == "mound":   # a termite spire
		body.add_child(cyl(0.12, 0.42, top, mats.get_mat("mud"), Vector3(0, top / 2, 0), Vector3.ZERO, 12))
	elif arch == "stone" or arch == "thatch":
		body.add_child(box(Vector3(0.62, top, 0.62), mats.get_mat("stone" if arch == "stone" else k.wall), Vector3(0, top / 2, 0)))
		for z in [-0.31, 0.31]:
			body.add_child(box(Vector3(0.08, top, 0.08), mats.get_mat(k.frame), Vector3(0.31, top / 2, z)))
	else:
		for x in [-0.28, 0.28]:
			for z in [-0.28, 0.28]:
				body.add_child(beam(Vector3(x * 1.15, 0, z * 1.15), Vector3(x, top, z), 0.04, wood))
		body.add_child(beam(Vector3(-0.3, 0.5, 0.3), Vector3(0.3, 1.2, 0.3), 0.025, wood))   # cross braces
		body.add_child(beam(Vector3(0.3, 0.5, -0.3), Vector3(0.3, 1.2, 0.3), 0.025, wood))
	body.add_child(box(Vector3(0.86, 0.08, 0.86), wood, Vector3(0, top, 0)))   # the platform
	for side in 4:
		var p := Vector3(0, top + 0.16, 0.42) if side == 0 else Vector3(0.42, top + 0.16, 0) if side == 1 else Vector3(0, top + 0.16, -0.42) if side == 2 else Vector3(-0.42, top + 0.16, 0)
		body.add_child(box(Vector3(0.86 if side % 2 == 0 else 0.04, 0.04, 0.04 if side % 2 == 0 else 0.86), wood, p))
	for x in [-0.4, 0.4]:
		for z in [-0.4, 0.4]:
			body.add_child(cyl(0.025, 0.025, 0.5, wood, Vector3(x, top + 0.25, z), Vector3.ZERO, 6))
	var roof_mat: Material = mats.get_mat("terracotta" if k.roof == "tiles" else k.roof)
	if k.get("dome", false):
		body.add_child(dome(0.5, roof_mat, Vector3(0, top + 0.5, 0), Vector3(1, 0.7, 1)))
		if arch == "reed":
			_lily_cap(body, Vector3(0, top + 0.82, 0), 0.22)
	else:
		body.add_child(cyl(0.0, 0.62, 0.38, roof_mat, Vector3(0, top + 0.68, 0), Vector3(0, 45, 0), 4))
	body.add_child(box(Vector3(0.22, 0.12, 0.02), cloth(team), Vector3(0.1, top + 0.18, 0.47)))   # a team rag on the rail: the owner, quietly
	return {"body": body, "anchor": Vector3.ZERO, "lantern": Vector3(0.3, top + 0.3, 0.3), "lights": [], "team": team}


func barracks_reed(team: Color) -> Dictionary:
	return _barracks("reed", team)


func barracks_mound(team: Color) -> Dictionary:
	return _barracks("mound", team)


func stable_reed(team: Color) -> Dictionary:
	return _stable("reed", team)


func stable_mound(team: Color) -> Dictionary:
	return _stable("mound", team)


func watchtower_reed(team: Color) -> Dictionary:
	return _tower("reed", team)


func watchtower_mound(team: Color) -> Dictionary:
	return _tower("mound", team)


# ------------------------------------------------------------------ amphibians: reed domes on stilts
# Frogs weave reed domes and raise them on stilts over the wet, capped with a lily pad.

## A plank deck on log stilts, w x d, at `at`. Returns the deck's top height.
func _stilt_deck(body: Node3D, at: Vector3, w: float, d: float) -> float:
	var wood := mats.get_mat("wood")
	var h := 0.4
	var nx := maxi(2, int(w / 0.7) + 1)
	var nz := maxi(2, int(d / 0.7) + 1)
	for i in nx:
		for j in nz:
			var p := at + Vector3(-w / 2 + 0.08 + i * (w - 0.16) / (nx - 1), h / 2, -d / 2 + 0.08 + j * (d - 0.16) / (nz - 1))
			body.add_child(cyl(0.05, 0.06, h, wood, p, Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)), 8))
	var planks := int(d / 0.2)
	for k in planks:
		body.add_child(box(Vector3(w, 0.06, d / planks - 0.015), wood, at + Vector3(0, h + 0.03, -d / 2 + (k + 0.5) * d / planks), Vector3(0, rng.randf_range(-1.5, 1.5), 0)))
	return h + 0.06


## A lily pad laid over a roof's crown, notched (no flower: on a green pad it read as a golf ball).
func _lily_cap(body: Node3D, at: Vector3, r: float) -> void:
	# Smaller, darker and slipped to one side, draped on the thatch rather than a flat lid.
	var c := at + Vector3(-r * 0.25, -0.03, r * 0.15)
	var rr := r * 0.75
	body.add_child(cyl(rr, rr, 0.025, Materials.flat(Color("#3d6a2c"), 0.8), c, Vector3(10, 30, -8), 20))
	body.add_child(box(Vector3(rr, 0.035, 0.04), Materials.flat(Color("#2e5222"), 0.85), c + Vector3(rr * 0.5, 0.015, 0), Vector3(10, 30, -8)))   # the notch's vein


## A woven dome on a short wall, with a mud band, a dark door and a lily cap. Returns its top.
func _reed_dome(body: Node3D, at: Vector3, r: float, team: Color, door_turn := 0.0) -> float:
	var weave := mats.get_mat("weave")
	var wall_h := r * 0.35
	body.add_child(cyl(r, r * 1.04, wall_h, weave, at + Vector3(0, wall_h / 2, 0), Vector3.ZERO, 28))
	body.add_child(ring(r - 0.02, r + 0.05, mats.get_mat("mud"), at + Vector3(0, 0.04, 0)))
	body.add_child(dome(r, mats.get_mat("thatch"), at + Vector3(0, wall_h - 0.02, 0), Vector3(1.04, 0.95, 1.04)))
	var a := deg_to_rad(door_turn)
	var door := at + Vector3(sin(a) * r, wall_h * 0.5 + 0.02, cos(a) * r)
	body.add_child(box(Vector3(r * 0.42, wall_h + r * 0.25, 0.05), Materials.flat(Color("#2a1e14"), 0.9), door, Vector3(0, door_turn, 0)))
	body.add_child(box(Vector3(r * 0.5, 0.06, 0.08), cloth(team), door + Vector3(0, wall_h * 0.5 + r * 0.14, 0), Vector3(0, door_turn, 0)))
	var top := at.y + wall_h + r * 0.95
	_lily_cap(body, Vector3(at.x, top - 0.04, at.z), r * 0.45)
	return top


## Reed bundles standing round a deck's edge, tied in the middle: the frogs' fence.
func _reed_fence(body: Node3D, at: Vector3, half: float, gap_side := 0) -> void:
	var reed := mats.get_mat("thatch")
	var tie := mats.get_mat("wood")
	for side in 4:
		if side == gap_side:
			continue
		for k in 6:
			var t := -half + (k + 0.5) * half * 2.0 / 6.0
			var p := Vector3(t, 0, half) if side == 0 else Vector3(half, 0, t) if side == 1 else Vector3(t, 0, -half) if side == 2 else Vector3(-half, 0, t)
			body.add_child(cyl(0.035, 0.05, 0.36, reed, at + p + Vector3(0, 0.18, 0), Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)), 8))
			body.add_child(ring(0.04, 0.06, tie, at + p + Vector3(0, 0.2, 0)))


func reed_house(team: Color) -> Dictionary:
	rng.seed = 11
	var body := Node3D.new()
	var deck := _stilt_deck(body, Vector3.ZERO, 1.5, 1.5)
	var top := _reed_dome(body, Vector3(0, deck, 0), 0.58, team)
	# A reed ladder down to the water, and a fishing pole leaning on the dome.
	var wood := mats.get_mat("wood")
	for x in [-0.12, 0.12]:
		body.add_child(beam(Vector3(x, 0.0, 1.05), Vector3(x, deck, 0.72), 0.02, wood, 6))
	for k in 3:
		body.add_child(box(Vector3(0.28, 0.025, 0.025), wood, Vector3(0, 0.0, 1.05).lerp(Vector3(0, deck, 0.72), (k + 1) / 4.0)))
	body.add_child(beam(Vector3(0.6, deck, 0.4), Vector3(0.95, deck + 0.9, -0.1), 0.012, wood, 4))
	return {"body": body, "anchor": Vector3.ZERO, "lights": [], "lantern": Vector3(0.3, deck + 0.2, 0.65), "team": team}


func reed_town_center(team: Color) -> Dictionary:
	rng.seed = 12
	var body := Node3D.new()
	var deck := _stilt_deck(body, Vector3.ZERO, 2.5, 2.5)
	var top := _reed_dome(body, Vector3(-0.25, deck, -0.25), 0.92, team)
	_reed_dome(body, Vector3(0.8, deck, 0.75), 0.36, team, 40.0)
	_reed_fence(body, Vector3(0, deck, 0), 1.2)
	# Steps down at the front, and a stack of caught fish on a rack.
	var wood := mats.get_mat("wood")
	for k in 3:
		body.add_child(box(Vector3(0.5, 0.05, 0.16), wood, Vector3(-0.2, deck * (k + 0.5) / 3.0, 1.55 - k * 0.14)))
	body.add_child(beam(Vector3(-1.0, deck, 0.8), Vector3(-1.0, deck + 0.45, 0.8), 0.02, wood, 6))
	body.add_child(beam(Vector3(-0.6, deck, 0.8), Vector3(-0.6, deck + 0.45, 0.8), 0.02, wood, 6))
	body.add_child(beam(Vector3(-1.0, deck + 0.42, 0.8), Vector3(-0.6, deck + 0.42, 0.8), 0.015, wood, 4))
	for k in 3:
		body.add_child(ball(0.05, Materials.flat(Color("#8aa0a8"), 0.4, 0.3), Vector3(-0.92 + k * 0.12, deck + 0.32, 0.8), Vector3(0.6, 1.8, 0.6)))
	# The standard: a tall reed pole with a team banner.
	var pole_at := Vector3(1.0, deck, -0.95)
	body.add_child(cyl(0.03, 0.035, 1.6, wood, pole_at + Vector3(0, 0.8, 0), Vector3.ZERO, 8))
	var banner := Node3D.new()
	var flag_top := pole_at + Vector3(0.03, 1.5, 0)
	banner.add_child(box(Vector3(0.5, 0.05, 0.03), wood, flag_top + Vector3(0.25, 0, 0)))
	banner.add_child(slab_tri(Vector2(0, 0), Vector2(0.62, -0.22), Vector2(0, -0.5), 0.02, cloth(team)))
	banner.get_child(banner.get_child_count() - 1).position = flag_top
	return {"body": body, "anchor": Vector3.ZERO, "banner": banner, "banner_pivot": flag_top,
		"smoke": Vector3(-0.25, top, -0.25), "lights": [], "lantern": Vector3(-0.25, deck + 0.4, 0.75)}


# ------------------------------------------------------------------ bugs: earth mounds, logs, husks
# Bugs dig in: packed-earth mounds with round doors, a hollowed log, seed husks for sheds.

## A round dark doorway in a mound, facing out along `turn` degrees.
func _burrow_door(body: Node3D, at: Vector3, r: float, turn := 0.0, team := Color.BLACK) -> void:
	var a := deg_to_rad(turn)
	body.add_child(cyl(r, r, 0.06, Materials.flat(Color("#1e140c"), 1.0), at, Vector3(90, turn, 0), 16))
	body.add_child(ring(r, r + 0.05, mats.get_mat("wood"), at + Vector3(sin(a), 0, cos(a)) * 0.01, Vector3(90, turn, 0)))
	if team != Color.BLACK:   # a team cloth hung over the doorway
		body.add_child(box(Vector3(r * 2.4, r * 0.7, 0.04), cloth(team), at + Vector3(sin(a), 0, cos(a)) * 0.04 + Vector3(0, r * 1.05, 0), Vector3(-12, turn, 0)))


## A seed husk propped up as a shed: a big ribbed shell, open side out.
func _husk(body: Node3D, at: Vector3, r: float, turn := 0.0) -> void:
	var shell := Materials.flat(Color("#b08a52"), 0.8)
	body.add_child(ball(r, shell, at + Vector3(0, r * 0.9, 0), Vector3(1.0, 1.5, 0.8), Vector3(0, turn, 18)))
	for k in 3:
		body.add_child(ring(r * (0.55 + 0.15 * k), r * (0.6 + 0.15 * k), Materials.flat(Color("#8a6a3a"), 0.9), at + Vector3(0, r * 0.9, 0), Vector3(0, turn, 18 + 90), Vector3(1.0, 1.0, 1.5)))


func _grass_tufts(body: Node3D, at: Vector3, spread: float, n: int) -> void:
	var grass := Materials.flat(Color("#5e8a34"), 0.9)
	for k in n:
		var p := at + Vector3(rng.randf_range(-spread, spread), 0, rng.randf_range(-spread, spread))
		body.add_child(cyl(0.0, 0.05, 0.22, grass, p + Vector3(0, 0.1, 0), Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12)), 5))


func mound_house(team: Color) -> Dictionary:
	rng.seed = 21
	var body := Node3D.new()
	var mud := mats.get_mat("mud")
	body.add_child(dome(0.72, mud, Vector3.ZERO, Vector3(1.0, 0.95, 1.0)))
	body.add_child(dome(0.3, mud, Vector3(0.0, 0.62, 0.0), Vector3(1.0, 0.9, 1.0)))   # the crown, a second lump
	_burrow_door(body, Vector3(0.05, 0.2, 0.66), 0.17, 0.0, team)
	_husk(body, Vector3(0.75, 0, -0.35), 0.24, -30.0)
	_grass_tufts(body, Vector3(0, 0.62, 0), 0.25, 5)
	return {"body": body, "anchor": Vector3.ZERO, "lights": [], "lantern": Vector3(0.25, 0.35, 0.62), "team": team}


func mound_town_center(team: Color) -> Dictionary:
	rng.seed = 22
	var body := Node3D.new()
	var mud := mats.get_mat("mud")
	var wood := mats.get_mat("wood")
	body.add_child(dome(1.15, mud, Vector3(-0.2, 0, -0.2), Vector3(1.0, 0.85, 1.0)))
	body.add_child(dome(0.55, mud, Vector3(-0.2, 0.85, -0.2), Vector3(1.0, 0.9, 1.0)))
	body.add_child(dome(0.6, mud, Vector3(0.95, 0, 0.55), Vector3(1.0, 0.8, 1.0)))
	_burrow_door(body, Vector3(-0.1, 0.26, 0.86), 0.24, 0.0, team)
	_burrow_door(body, Vector3(0.75, 0.2, 0.56), 0.14, 60.0, team)
	_burrow_door(body, Vector3(-0.85, 0.55, 0.45), 0.1, -40.0)
	# A hollowed log along the side, its dark ends showing, and a husk shed.
	var log_at := Vector3(-1.0, 0.24, 1.05)
	body.add_child(cyl(0.24, 0.24, 1.2, wood, log_at, Vector3(0, -20, 90), 16))
	for end in [-1, 1]:
		var e: Vector3 = log_at + Vector3(cos(deg_to_rad(20)), 0, sin(deg_to_rad(20))) * 0.6 * end
		body.add_child(cyl(0.18, 0.18, 0.02, Materials.flat(Color("#2a1c10"), 1.0), e + Vector3(cos(deg_to_rad(20)), 0, sin(deg_to_rad(20))) * 0.01 * end, Vector3(0, -20, 90), 14))
	_husk(body, Vector3(1.2, 0, -0.75), 0.32, -50.0)
	_grass_tufts(body, Vector3(-0.2, 1.2, -0.2), 0.3, 7)
	var pole_at := Vector3(0.6, 0.0, -1.2)
	body.add_child(cyl(0.03, 0.035, 2.0, wood, pole_at + Vector3(0, 1.0, 0), Vector3.ZERO, 8))
	var banner := Node3D.new()
	var flag_top := pole_at + Vector3(0.03, 1.9, 0)
	banner.add_child(box(Vector3(0.5, 0.05, 0.03), wood, flag_top + Vector3(0.25, 0, 0)))
	banner.add_child(slab_tri(Vector2(0, 0), Vector2(0.62, -0.22), Vector2(0, -0.5), 0.02, cloth(team)))
	banner.get_child(banner.get_child_count() - 1).position = flag_top
	return {"body": body, "anchor": Vector3.ZERO, "banner": banner, "banner_pivot": flag_top,
		"smoke": Vector3(-0.2, 1.35, -0.2), "lights": [], "lantern": Vector3(0.2, 0.4, 0.95)}


# ------------------------------------------------------------------ concept options (building sheets)
# Variations shown by tests/building_sheet.gd for Dominic to pick from; not used in play until picked.

func concept_junk_tc_small(team: Color) -> Dictionary:
	return junk_town_center_small(team)


func concept_junk_tc_low(team: Color) -> Dictionary:
	return junk_town_center(team, 0.72, 24.0, false)


func concept_junk_tc_berm(team: Color) -> Dictionary:
	return junk_town_center(team, 0.72, 24.0, true)


## The rat Town Centre in play (Dominic's pick, 2026-10-11): the no-plinth hall, smaller than
## the human halls in width, depth and height, with scrap and weeds low round its base so it
## sinks into the ground (D-081).
func junk_town_center_small(team: Color) -> Dictionary:
	var spec := junk_town_center(team, 0.7, 26.0, false, false)
	var k := 0.78
	var hall: Node3D = spec.body
	hall.scale = Vector3(k, 1.0, k)
	var root := Node3D.new()
	root.add_child(hall)
	rng.seed = 67
	var earth := mats.get_mat("mud")
	var weeds := Materials.flat(Color("#5e7a34"), 0.95)
	var tin := mats.get_mat("tin")
	for i in 22:   # rubble, weeds and scrap round the base, low: the ground creeping up
		var ang := TAU * i / 22.0 + rng.randf_range(-0.12, 0.12)
		var r := rng.randf_range(0.95, 1.25)
		var at := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		match i % 3:
			0:
				root.add_child(ball(rng.randf_range(0.14, 0.24), earth, at, Vector3(1.4, 0.5, 1.2)))
			1:
				root.add_child(cyl(0.0, 0.07, rng.randf_range(0.18, 0.3), weeds, at + Vector3(0, 0.1, 0), Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-15, 15)), 5))
			2:
				root.add_child(box(Vector3(rng.randf_range(0.15, 0.3), 0.02, rng.randf_range(0.1, 0.2)), tin, at + Vector3(0, 0.03, 0), Vector3(rng.randf_range(-12, 12), rng.randf_range(0, 90), 0)))
	spec.body = root
	for key in ["banner_pivot", "vane_pivot", "smoke", "lantern"]:
		spec[key] = Vector3(spec[key].x * k, spec[key].y, spec[key].z * k)
	spec.lights = spec.lights.map(func(p): return Vector3(p.x * k, p.y, p.z * k))
	for part in [spec.banner, spec.vane]:
		part.scale = Vector3(k, 1.0, k)
	return spec


## The rally point's flag: a staff planted in a little cairn of stones, a cloth in the team colour
## in a gentle wave, a brass finial. About a unit and a half tall, so it's found at a glance.
func rally_flag(team: Color) -> Node3D:
	rng.seed = 77
	var n := Node3D.new()
	var wood := mats.get_mat("wood")
	var stone := mats.get_mat("stone")
	for k in 5:   # the cairn
		var a := k * TAU / 5.0
		n.add_child(ball(0.06 + rng.randf() * 0.02, stone, Vector3(cos(a) * 0.07, 0.03, sin(a) * 0.07), Vector3(1.2, 0.8, 1.0)))
	n.add_child(ball(0.05, stone, Vector3(0.0, 0.08, 0.0), Vector3(1.2, 0.8, 1.0)))
	n.add_child(cyl(0.016, 0.02, 0.8, wood, Vector3(0, 0.4, 0), Vector3.ZERO, 8))
	n.add_child(ball(0.03, Materials.flat(Color("#c89a40"), 0.3, 0.8), Vector3(0, 0.82, 0)))
	n.add_child(cyl(0.008, 0.008, 0.36, wood, Vector3(0.18, 0.76, 0), Vector3(0, 0, 90), 6))   # the cross-bar the cloth hangs from
	var strips := 12
	for k in strips:   # the cloth as one gentle wave, growing towards the free end and sagging a touch
		var f := float(k) / strips
		var x := 0.02 + f * 0.34
		var z := sin(f * 7.0) * 0.025 * (0.3 + f)
		var slope := cos(f * 7.0) * 7.0 * 0.025 * (0.3 + f) / 0.34
		n.add_child(box(Vector3(0.034, 0.27 - f * 0.03, 0.01), cloth(team), Vector3(x, 0.625 - f * 0.012, z), Vector3(0, -rad_to_deg(atan(slope)), 0)))
	return n

