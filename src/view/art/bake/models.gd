extends RefCounted
## Detailed 3D models for the high-fidelity pre-render, built from primitives
## with procedural materials. 1 world unit = 1 tile; y is up; sim x = world x,
## sim y = world z. Each builder returns the static body plus the "live" bits
## (animated in 2D after baking) and the points the 2D side needs. A building that bakes
## variants (buildings.json "variants") says which way its door faces ("door", outward, and an
## optional "window"), so a variant is only turned or mirrored where they stay in view.

const Materials := preload("res://src/view/art/bake/materials.gd")

var mats := Materials.new()
var rng := RandomNumberGenerator.new()
var gate_span := 3.0   # a gate's length end to end in tiles: 3 along x, 3 x sqrt 2 corner to corner on a diagonal (ArtKit sets it)


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

## A doorway in a wall facing +z, for the view to light when someone goes in or comes out
## (milestone 17): its bottom-left, bottom-right and top-left corners, from the middle of its
## foot, and whether it's round (a burrow, a domed hut's door) rather than square.
func _doorway(foot: Vector3, w: float, h: float, round := false) -> Array:
	var out := [foot + Vector3(-w / 2, 0, 0), foot + Vector3(w / 2, 0, 0), foot + Vector3(-w / 2, h, 0)]
	if round:
		out.append(Vector3.ZERO)   # a fourth point marks it round
	return out

## A frog-culture Town Center: timber sills on earth, timber frame on mud daub, stepped
## reed thatch, a chimney, barrels, a crate and a woodpile; a team banner and a
## dragonfly weathervane as live parts.
func town_center(team: Color) -> Dictionary:
	rng.seed = 42
	var body := Node3D.new()
	var stone := mats.get_mat("stone")
	var wood := mats.get_mat("wood")
	var mud := mats.get_mat("mud")
	var thatch := mats.get_mat("thatch")
	# Footing: timber sills on packed earth (a wooden town builds no stone plinths; Dominic).
	_footing(body, "thatch", 2.8, 2.8, 0.22)
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
		"lantern": Vector3(0.18, base + 0.75, w / 2 + 0.15),
		"doorway": _doorway(Vector3(-0.15, base, w / 2 + 0.06), 0.46, 0.82)}


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
		"lantern": Vector3(0.32, 0.95, 0.66), "team": team, "door": Vector3(0, 0, 1)}


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
		"lantern": Vector3(0.05, base + 0.8, w / 2 + 0.15),
		"doorway": _doorway(Vector3(-0.35, base, w / 2 + 0.11), 0.45, 0.7)}


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
		"lantern": Vector3(0.4, 0.75, 0.75), "team": team, "door": Vector3(0, 0, 1)}


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
		"lantern": Vector3(-0.22, 0.12 + 0.62, front + 0.1), "team": team, "door": Vector3(0, 0, 1), "window": Vector3(1, 0, 0)}


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
		"lantern": Vector3(-0.15, 0.5, 0.95), "doorway": _doorway(Vector3(-0.15, 0.0, 0.94), 0.3, 0.6)}


## A tent-culture house: one felt tent and a woodpile.
func tent_house(team: Color) -> Dictionary:
	var body := Node3D.new()
	var top := _yurt(body, Vector3.ZERO, 0.62, 0.48, team)
	woodpile(Vector3(0.7, 0, -0.3), body)
	return {"body": body, "anchor": Vector3.ZERO, "smoke": Vector3(0, top + 0.1, 0), "lights": [],
		"lantern": Vector3(0, 0.35, 0.7), "team": team, "door": Vector3(0, 0, 1)}


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
	"thatch": {"wall": "mud", "frame": "wood", "roof": "thatch", "base": "timber"},   # timber sills on earth, no stone (Dominic)
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
		return rise   # (no lily pad: only the frog Town Center keeps one, as its landmark; Fable)
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
		_footing(body, arch, w + 0.3, d + 0.3, 0.16)
		base = 0.16
	if k.get("stilts", false):
		base = _stilt_deck(body, Vector3.ZERO, w + 0.3, d + 0.3)
	body.add_child(box(Vector3(w, h, d), mats.get_mat(k.wall), Vector3(0, base + h / 2, 0)))
	for x in [-1, 1]:
		for z in [-1, 1]:
			body.add_child(box(Vector3(0.12, h + 0.04, 0.12), mats.get_mat(k.frame), Vector3(x * w / 2, base + h / 2, z * d / 2)))
	return base


## A footing `h` high under a w x d building (centred on `at`, on the ground), in the culture's
## base: a stone or brick plinth; for the timber towns (KIT base "timber": no stone under a
## wooden house) a timber sill on packed earth: squared beams round the edge, their ends
## crossing past each other at the corners, and a plank floor between them.
func _footing(body: Node3D, arch: String, w: float, d: float, h: float, at := Vector3.ZERO) -> void:
	var k: Dictionary = KIT[arch]
	if k.base != "timber":
		body.add_child(box(Vector3(w, h, d), mats.get_mat(k.base), at + Vector3(0, h / 2, 0)))
		return
	var wood := mats.get_mat("wood")
	var s := minf(h, 0.16)   # the beams' section
	body.add_child(box(Vector3(w - 0.02, h - 0.02, d - 0.02), mats.get_mat("mud"), at + Vector3(0, (h - 0.02) / 2, 0)))   # packed earth
	for side in [-1, 1]:
		body.add_child(box(Vector3(w + 0.08, s, s), wood, at + Vector3(0, h - s / 2, side * (d - s) / 2)))
		body.add_child(box(Vector3(s * 0.9, s * 0.9, d + 0.08), wood, at + Vector3(side * (w - s) / 2, h - s * 0.55, 0)))
	var n := maxi(int((w - 2.0 * s) / 0.22), 1)   # planks across, between the sills
	for i in n:
		var x := -w / 2 + s + (i + 0.5) * (w - 2.0 * s) / n
		body.add_child(box(Vector3((w - 2.0 * s) / n - 0.02, 0.03, d - 2.0 * s), wood, at + Vector3(x, h - 0.012, 0)))


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
		"lights": lights, "team": team, "doorway": _doorway(Vector3(-0.3, base, -0.55 + d / 2 + 0.05), 0.5, 0.62)}


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
		_footing(body, arch, w + 0.3, d + 0.3, 0.12, Vector3(0, 0, -0.3))
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
		pass
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


# ------------------------------------------------------------------ outposts and bastions (milestone 12 phase 3)
# The Outpost: a cheap lookout that only sees. Three concept looks, each in every architecture
# (tests/building_sheet.gd outpost_pole:thatch ...); OUTPOST_LOOK picks one per culture until
# Dominic chooses. Lower and lighter than a Watchtower, so the two never read alike.

const OUTPOST_LOOK := {"thatch": "deck", "junk": "pole", "stone": "beacon", "tent": "pole", "reed": "deck", "mound": "deck"}


func _outpost(arch: String, team: Color) -> Dictionary:
	return call("_outpost_" + OUTPOST_LOOK[arch], arch, team)


## A spotter's mast: one tall post on three raking legs, peg rungs up it, a crow's-nest basket
## at the top and the team's pennant over it. Reed towns bind it from reed bundles, the mound
## folk raise it from a clay spire, the junk-rats from a pipe on an oil drum.
func _outpost_pole(arch: String, team: Color) -> Dictionary:
	rng.seed = 41
	var body := Node3D.new()
	var wood := mats.get_mat("wood")
	var top := 1.45
	var post_mat: Material = wood
	if arch == "reed":
		post_mat = mats.get_mat("thatch")
	elif arch == "junk":
		post_mat = Materials.flat(Color("#5a5c5e"), 0.5, 0.6)   # a pipe
	if arch == "mound":
		body.add_child(cyl(0.05, 0.3, top, mats.get_mat("mud"), Vector3(0, top / 2, 0), Vector3.ZERO, 10))
	else:
		body.add_child(cyl(0.045, 0.06, top, post_mat, Vector3(0, top / 2, 0), Vector3.ZERO, 8))
		for k in 3:   # the raking legs
			var a := TAU * k / 3.0 + 0.4
			body.add_child(beam(Vector3(cos(a) * 0.42, 0, sin(a) * 0.42), Vector3(0, top * 0.55, 0), 0.025, post_mat, 6))
		for k in 6:   # peg rungs
			body.add_child(box(Vector3(0.2, 0.025, 0.025), wood, Vector3(0, 0.2 + k * 0.18, 0.05), Vector3(0, 30 * (k % 2), 0)))
	if arch == "junk":
		body.add_child(cyl(0.2, 0.2, 0.36, Materials.flat(Color("#7a3a2a"), 0.6, 0.4), Vector3(0, 0.18, 0), Vector3.ZERO, 14))   # an oil drum foot
		body.add_child(ring(0.19, 0.21, Materials.flat(Color("#4a2a20"), 0.6), Vector3(0, 0.3, 0)))
	# The crow's nest: a basket (woven, a tin can for the rats, felt-lined for tents)
	var nest: Material = {"junk": mats.get_mat("tin"), "tent": mats.get_mat("felt"), "mound": mats.get_mat("mud")}.get(arch, mats.get_mat("weave"))
	body.add_child(cyl(0.2, 0.15, 0.22, nest, Vector3(0, top, 0), Vector3.ZERO, 14))
	body.add_child(ring(0.18, 0.22, wood if arch != "junk" else mats.get_mat("tin"), Vector3(0, top + 0.11, 0)))
	body.add_child(cyl(0.16, 0.16, 0.012, Materials.flat(Color("#2a1e14"), 0.95), Vector3(0, top + 0.12, 0), Vector3.ZERO, 14))   # open: you look into it
	body.add_child(cyl(0.012, 0.012, 0.45, wood, Vector3(0.12, top + 0.32, -0.08), Vector3.ZERO, 5))   # the pennant's staff
	body.add_child(box(Vector3(0.22, 0.1, 0.01), cloth(team), Vector3(0.24, top + 0.48, -0.08)))
	return {"body": body, "anchor": Vector3.ZERO, "lantern": Vector3(0, top + 0.1, 0.18), "lights": [], "team": team}


## A low look-out deck: four short legs, a ladder, a railing and a sunshade in the culture's
## roof, a horn hung on the rail. Wide and low where the Watchtower is tall.
func _outpost_deck(arch: String, team: Color) -> Dictionary:
	rng.seed = 42
	var body := Node3D.new()
	var k: Dictionary = KIT[arch]
	var wood := mats.get_mat("wood")
	var h := 0.75
	var legs: Material = mats.get_mat("thatch") if arch == "reed" else wood
	for x in [-0.32, 0.32]:
		for z in [-0.32, 0.32]:
			body.add_child(cyl(0.035, 0.045, h, legs, Vector3(x, h / 2, z), Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)), 8))
	if arch == "mound":
		body.add_child(cyl(0.3, 0.46, h, mats.get_mat("mud"), Vector3(0, h / 2, 0), Vector3.ZERO, 14))   # a packed-earth plinth
	body.add_child(box(Vector3(0.82, 0.06, 0.82), wood, Vector3(0, h, 0)))
	for side in 4:   # the rail, open at the ladder (front)
		if side == 0:
			continue
		var p := Vector3(0, h + 0.2, 0.39) if side == 0 else Vector3(0.39, h + 0.2, 0) if side == 1 else Vector3(0, h + 0.2, -0.39) if side == 2 else Vector3(-0.39, h + 0.2, 0)
		body.add_child(box(Vector3(0.8 if side % 2 == 0 else 0.03, 0.03, 0.03 if side % 2 == 0 else 0.8), wood, p))
	for x in [-0.12, 0.12]:   # the ladder
		body.add_child(beam(Vector3(x, 0, 0.72), Vector3(x, h, 0.4), 0.018, wood, 5))
	for n in 3:
		body.add_child(box(Vector3(0.26, 0.02, 0.02), wood, Vector3(0, 0, 0.72).lerp(Vector3(0, h, 0.4), (n + 1) / 4.0)))
	# The sunshade on two poles at the back: a slanted sheet of the culture's roof stuff.
	for x in [-0.36, 0.36]:
		body.add_child(cyl(0.02, 0.02, 0.62, wood, Vector3(x, h + 0.31, -0.36), Vector3.ZERO, 6))
	var shade: Material = mats.get_mat("terracotta" if k.roof == "tiles" else k.roof)
	if k.get("dome", false):
		body.add_child(dome(0.42, shade, Vector3(0, h + 0.56, -0.12), Vector3(1.05, 0.35, 0.8)))
	else:
		body.add_child(box(Vector3(0.88, 0.04, 0.6), shade, Vector3(0, h + 0.6, -0.14), Vector3(-14, 0, 0)))
	body.add_child(box(Vector3(0.24, 0.1, 0.015), cloth(team), Vector3(0.18, h + 0.13, -0.4)))   # a team rag on the rail
	var horn := Materials.flat(Color("#d8c8a0"), 0.6)   # a horn to call with
	body.add_child(cyl(0.012, 0.045, 0.22, horn, Vector3(-0.39, h + 0.12, 0.05), Vector3(0, 0, 70), 8))
	return {"body": body, "anchor": Vector3.ZERO, "lantern": Vector3(0.2, h + 0.3, 0.1), "lights": [], "team": team}


## A beacon cairn: a heap of the culture's stuff (dressed stones, clay, crates and drums, reed
## sheaves) with a post and a fire basket on top, lit: you see the watch from far off.
func _outpost_beacon(arch: String, team: Color) -> Dictionary:
	rng.seed = 43
	var body := Node3D.new()
	var wood := mats.get_mat("wood")
	var h := 0.55
	match arch:
		"junk":
			body.add_child(box(Vector3(0.5, 0.3, 0.5), wood, Vector3(-0.05, 0.15, 0.02), Vector3(0, 8, 0)))
			body.add_child(box(Vector3(0.36, 0.26, 0.36), wood, Vector3(0.02, 0.43, -0.02), Vector3(0, -12, 0)))
			body.add_child(cyl(0.13, 0.13, 0.3, Materials.flat(Color("#7a3a2a"), 0.6, 0.4), Vector3(0.3, 0.15, 0.25), Vector3.ZERO, 12))
		"reed", "thatch", "tent":
			var sheaf: Material = mats.get_mat("thatch") if arch != "tent" else mats.get_mat("felt")
			body.add_child(cyl(0.18, 0.42, h, sheaf, Vector3(0, h / 2, 0), Vector3.ZERO, 16))
			body.add_child(ring(0.3, 0.34, wood, Vector3(0, 0.22, 0)))
		"mound":
			body.add_child(cyl(0.16, 0.45, h + 0.1, mats.get_mat("mud"), Vector3(0, (h + 0.1) / 2, 0), Vector3.ZERO, 14))
			h += 0.1
		_:   # dressed stones, stacked in rings
			var stone := mats.get_mat("stone")
			for row in 4:
				var r := 0.42 - row * 0.09
				var n := 8 - row
				for s in n:
					var a := TAU * s / n + row * 0.4
					body.add_child(box(Vector3(0.2, 0.14, 0.16), stone, Vector3(cos(a) * r * 0.7, 0.07 + row * 0.13, sin(a) * r * 0.7), Vector3(rng.randf_range(-6, 6), -rad_to_deg(a), rng.randf_range(-4, 4))))
			body.add_child(cyl(0.12, 0.3, h, stone, Vector3(0, h / 2, 0), Vector3.ZERO, 10))
	body.add_child(cyl(0.035, 0.04, 0.7, wood, Vector3(0, h + 0.35, 0), Vector3.ZERO, 8))
	var iron := Materials.flat(Color("#3a3634"), 0.5, 0.7)
	body.add_child(cyl(0.16, 0.08, 0.14, iron, Vector3(0, h + 0.76, 0), Vector3.ZERO, 12))   # the fire basket
	body.add_child(cyl(0.13, 0.13, 0.03, glow(Color("#c04018"), 1.5), Vector3(0, h + 0.83, 0), Vector3.ZERO, 12))   # the embers
	body.add_child(cyl(0.0, 0.11, 0.26, glow(Color("#ff8a20"), 2.2), Vector3(0, h + 0.97, 0), Vector3(0, 0, 6), 8))   # the flame
	body.add_child(cyl(0.0, 0.06, 0.18, glow(Color("#ffd860"), 2.6), Vector3(0.02, h + 0.94, 0.03), Vector3(0, 0, -8), 8))
	body.add_child(box(Vector3(0.2, 0.12, 0.015), cloth(team), Vector3(0.12, h + 0.45, 0.04)))   # a team rag tied to the post
	return {"body": body, "anchor": Vector3.ZERO, "lantern": Vector3(0, h + 0.86, 0), "lights": [Vector3(0, h + 0.86, 0)], "team": team}


## The Bastion (the University's tower upgrade): a Watchtower rebuilt heavy and tall, one look
## per culture. Stone towns raise a battlemented keep; the timber towns a daub-and-frame tower
## under a fighting gallery; the junk-rats brick topped with riveted tin; tents a timber frame
## hung with felt; frogs a tall woven drum on stilts; the mound folk a buttressed clay spire.
func _bastion(arch: String, team: Color) -> Dictionary:
	rng.seed = 44
	var body := Node3D.new()
	var k: Dictionary = KIT[arch]
	var wood := mats.get_mat("wood")
	var slit := Materials.flat(Color("#1c140e"), 0.95)
	var top := 2.2
	var lantern := Vector3(0.3, top, 0.4)
	match arch:
		"stone":
			var stone := mats.get_mat("stone")
			body.add_child(box(Vector3(0.96, 0.24, 0.96), stone, Vector3(0, 0.12, 0)))   # a battered foot
			body.add_child(box(Vector3(0.82, top - 0.2, 0.82), stone, Vector3(0, 0.24 + (top - 0.24 - 0.2) / 2, 0)))
			body.add_child(box(Vector3(0.94, 0.12, 0.94), stone, Vector3(0, top - 0.14, 0)))   # the corbel course
			for s in 4:   # merlons round the top
				for m in 3:
					var t := -0.33 + m * 0.33
					var p := Vector3(t, top + 0.04, 0.42) if s == 0 else Vector3(0.42, top + 0.04, t) if s == 1 else Vector3(t, top + 0.04, -0.42) if s == 2 else Vector3(-0.42, top + 0.04, t)
					body.add_child(box(Vector3(0.18, 0.2, 0.12) if s % 2 == 0 else Vector3(0.12, 0.2, 0.18), stone, p))
			body.add_child(cyl(0.015, 0.015, 0.7, wood, Vector3(-0.2, top + 0.3, -0.2), Vector3.ZERO, 5))
			body.add_child(box(Vector3(0.3, 0.18, 0.01), cloth(team), Vector3(-0.04, top + 0.55, -0.2)))
			for y in [0.8, 1.45]:
				body.add_child(box(Vector3(0.05, 0.22, 0.02), slit, Vector3(0.1, y, 0.415)))
				body.add_child(box(Vector3(0.02, 0.22, 0.05), slit, Vector3(0.415, y, -0.1)))
			body.add_child(box(Vector3(0.24, 0.36, 0.03), Materials.flat(Color("#3a2416"), 0.9), Vector3(-0.15, 0.42, 0.42)))   # the door
		"thatch":
			body.add_child(box(Vector3(0.84, 0.14, 0.84), mats.get_mat("mud"), Vector3(0, 0.07, 0)))
			var h := top - 0.55
			body.add_child(box(Vector3(0.74, h, 0.74), mats.get_mat("mud"), Vector3(0, 0.14 + h / 2, 0)))
			for x in [-0.37, 0.37]:
				for z in [-0.37, 0.37]:
					body.add_child(box(Vector3(0.09, h + 0.1, 0.09), wood, Vector3(x, 0.14 + h / 2, z)))
			for y in [0.7, 1.25]:   # timber bands and braces
				body.add_child(box(Vector3(0.78, 0.06, 0.78), wood, Vector3(0, y, 0)))
			body.add_child(beam(Vector3(-0.37, 0.18, 0.375), Vector3(0.37, 0.68, 0.375), 0.025, wood, 5))
			body.add_child(beam(Vector3(0.375, 0.18, 0.37), Vector3(0.375, 0.68, -0.37), 0.025, wood, 5))
			var g := 0.14 + h   # the fighting gallery, jutting out over the walls
			body.add_child(box(Vector3(1.04, 0.07, 1.04), wood, Vector3(0, g, 0)))
			for s in 4:
				var p := Vector3(0, g + 0.17, 0.5) if s == 0 else Vector3(0.5, g + 0.17, 0) if s == 1 else Vector3(0, g + 0.17, -0.5) if s == 2 else Vector3(-0.5, g + 0.17, 0)
				body.add_child(box(Vector3(1.02 if s % 2 == 0 else 0.05, 0.28, 0.05 if s % 2 == 0 else 1.02), wood, p))
			body.add_child(cyl(0.0, 0.78, 0.6, mats.get_mat("thatch"), Vector3(0, g + 0.62, 0), Vector3(0, 45, 0), 4))
			body.add_child(box(Vector3(0.26, 0.14, 0.02), cloth(team), Vector3(0.12, g + 0.12, 0.53)))
			body.add_child(box(Vector3(0.05, 0.2, 0.02), slit, Vector3(-0.1, 0.95, 0.375)))
			top = g + 0.9
			lantern = Vector3(0.35, g + 0.25, 0.45)
		"junk":
			var brick := mats.get_mat("brick")
			body.add_child(box(Vector3(0.84, 1.0, 0.84), brick, Vector3(0, 0.5, 0)))
			body.add_child(box(Vector3(0.9, 0.9, 0.9), mats.get_mat("tin"), Vector3(0, 1.45, 0), Vector3(0, 3, 0)))   # riveted tin upper
			var band := Materials.flat(Color("#4a4440"), 0.5, 0.6)
			for y in [1.05, 1.85]:
				body.add_child(box(Vector3(0.93, 0.05, 0.93), band, Vector3(0, y, 0), Vector3(0, 3, 0)))
			for s in 4:   # crate merlons
				var a := s * 90.0
				var p := Vector3(sin(deg_to_rad(a)) * 0.34, 2.0, cos(deg_to_rad(a)) * 0.34)
				body.add_child(box(Vector3(0.22, 0.2, 0.22), wood, p, Vector3(0, rng.randf_range(-15, 15), 0)))
			body.add_child(box(Vector3(0.95, 0.04, 0.6), mats.get_mat("tin"), Vector3(0, 2.32, -0.15), Vector3(-12, 3, 0)))   # a sheet of tin for a roof
			for x in [-0.4, 0.4]:
				body.add_child(cyl(0.015, 0.015, 0.4, wood, Vector3(x, 2.15, -0.38), Vector3.ZERO, 5))
			body.add_child(box(Vector3(0.05, 0.2, 0.02), slit, Vector3(0.12, 1.45, 0.455)))
			body.add_child(box(Vector3(0.28, 0.18, 0.02), cloth(team), Vector3(-0.15, 1.6, 0.46)))
			top = 2.35
		"tent":
			for x in [-0.36, 0.36]:
				for z in [-0.36, 0.36]:
					body.add_child(cyl(0.06, 0.07, top, wood, Vector3(x, top / 2, z), Vector3.ZERO, 8))
			for y in [0.45, 1.1]:
				body.add_child(beam(Vector3(-0.36, y, 0.36), Vector3(0.36, y + 0.55, 0.36), 0.025, wood, 5))
				body.add_child(beam(Vector3(0.36, y, 0.36), Vector3(0.36, y + 0.55, -0.36), 0.025, wood, 5))
			body.add_child(box(Vector3(0.9, 0.08, 0.9), wood, Vector3(0, top - 0.5, 0)))
			body.add_child(box(Vector3(0.86, 0.46, 0.86), mats.get_mat("felt"), Vector3(0, top - 0.23, 0)))   # felt hung round the fighting floor
			for s in 4:
				var p := Vector3(0, top - 0.25, 0.44) if s == 0 else Vector3(0.44, top - 0.25, 0) if s == 1 else Vector3(0, top - 0.25, -0.44) if s == 2 else Vector3(-0.44, top - 0.25, 0)
				body.add_child(box(Vector3(0.1 if s % 2 == 0 else 0.02, 0.16, 0.02 if s % 2 == 0 else 0.1), slit, p))
			body.add_child(cyl(0.0, 0.66, 0.62, mats.get_mat("felt"), Vector3(0, top + 0.31, 0), Vector3.ZERO, 16))
			body.add_child(cyl(0.015, 0.015, 0.35, wood, Vector3(0, top + 0.75, 0), Vector3.ZERO, 5))
			body.add_child(box(Vector3(0.24, 0.12, 0.01), cloth(team), Vector3(0.13, top + 0.85, 0)))
			top += 0.6
		"reed":
			var deck := _stilt_deck(body, Vector3.ZERO, 0.96, 0.96)
			var h := 1.45
			body.add_child(cyl(0.36, 0.42, h, mats.get_mat("weave"), Vector3(0, deck + h / 2, 0), Vector3.ZERO, 24))
			body.add_child(cyl(0.43, 0.45, 0.3, mats.get_mat("mud"), Vector3(0, deck + 0.15, 0), Vector3.ZERO, 24))   # mud-plastered skirt
			for y in [0.65, 1.2]:
				body.add_child(ring(0.37, 0.41, mats.get_mat("wood"), Vector3(0, deck + y, 0)))
			_reed_fence(body, Vector3(0, deck + h, 0), 0.4)
			body.add_child(dome(0.46, mats.get_mat("thatch"), Vector3(0, deck + h + 0.28, 0), Vector3(1, 0.7, 1)))
			for x in [-0.4, 0.4]:
				body.add_child(cyl(0.02, 0.02, 0.3, wood, Vector3(x, deck + h + 0.15, 0.1), Vector3.ZERO, 5))
			body.add_child(box(Vector3(0.05, 0.18, 0.02), slit, Vector3(0.12, deck + 0.95, 0.4), Vector3(0, 15, 0)))
			body.add_child(box(Vector3(0.26, 0.12, 0.02), cloth(team), Vector3(-0.1, deck + h - 0.1, 0.42)))
			top = deck + h + 0.6
		"mound":
			var mud := mats.get_mat("mud")
			body.add_child(cyl(0.14, 0.52, top, mud, Vector3(0, top / 2, 0), Vector3.ZERO, 14))
			for s in 5:   # buttress spires leaning on the main one
				var a := TAU * s / 5.0 + 0.3
				var hh := rng.randf_range(0.9, 1.4)
				body.add_child(cyl(0.04, 0.2, hh, mud, Vector3(cos(a) * 0.36, hh / 2, sin(a) * 0.36), Vector3(sin(a) * 8, 0, -cos(a) * 8), 10))
			for s in 6:   # vent holes to shoot from
				var a := TAU * s / 6.0
				var y := 1.0 + (s % 2) * 0.45
				var r := 0.52 - y / top * 0.38
				body.add_child(ball(0.05, slit, Vector3(cos(a) * r, y, sin(a) * r), Vector3(1, 1.4, 1)))
			body.add_child(box(Vector3(0.26, 0.12, 0.02), cloth(team), Vector3(0.0, 1.2, 0.36), Vector3(0, 0, 4)))
			top += 0.1
	return {"body": body, "anchor": Vector3.ZERO, "lantern": lantern, "lights": [], "team": team}


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
func _reed_dome(body: Node3D, at: Vector3, r: float, team: Color, door_turn := 0.0, cap := false) -> float:
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
	if cap:
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
	return {"body": body, "anchor": Vector3.ZERO, "lights": [], "lantern": Vector3(0.3, deck + 0.2, 0.65), "team": team, "door": Vector3(0, 0, 1)}


func reed_town_center(team: Color) -> Dictionary:
	rng.seed = 12
	var body := Node3D.new()
	var deck := _stilt_deck(body, Vector3.ZERO, 2.5, 2.5)
	var top := _reed_dome(body, Vector3(-0.25, deck, -0.25), 0.92, team)
	# A second, smaller woven dome stacked on the first: the village's tallest roof, its landmark.
	body.add_child(cyl(0.34, 0.4, 0.22, mats.get_mat("weave"), Vector3(-0.25, top - 0.05, -0.25), Vector3.ZERO, 20))
	body.add_child(dome(0.4, mats.get_mat("thatch"), Vector3(-0.25, top + 0.05, -0.25), Vector3(1.0, 1.1, 1.0)))
	_lily_cap(body, Vector3(-0.25, top + 0.45, -0.25), 0.2)
	top += 0.5
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
		"smoke": Vector3(-0.25, top, -0.25), "lights": [], "lantern": Vector3(-0.25, deck + 0.4, 0.75),
		"doorway": _doorway(Vector3(-0.25, deck + 0.04, -0.25 + 0.92 + 0.06), 0.92 * 0.42, 0.92 * 0.35 + 0.92 * 0.25 - 0.04, true)}


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
	return {"body": body, "anchor": Vector3.ZERO, "lights": [], "lantern": Vector3(0.25, 0.35, 0.62), "team": team, "door": Vector3(0, 0, 1)}


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
		"smoke": Vector3(-0.2, 1.35, -0.2), "lights": [], "lantern": Vector3(0.2, 0.4, 0.95),
		"doorway": _doorway(Vector3(-0.1, 0.26 - 0.2, 0.92), 0.4, 0.4, true)}


# ------------------------------------------------------------------ concept options (building sheets)
# Variations shown by tests/building_sheet.gd for Dominic to pick from; not used in play until picked.

func concept_junk_tc_small(team: Color) -> Dictionary:
	return junk_town_center_small(team)


func concept_junk_tc_low(team: Color) -> Dictionary:
	return junk_town_center(team, 0.72, 24.0, false)


func concept_junk_tc_berm(team: Color) -> Dictionary:
	return junk_town_center(team, 0.72, 24.0, true)


# ---- RB3: the rats' buildings by age (concepts for Dominic to pick; not in play)

func _drum(body: Node3D, at: Vector3, r: float, h: float, paint: Color) -> void:
	var m := Materials.flat(paint, 0.7, 0.3)
	body.add_child(cyl(r, r, h, m, at + Vector3(0, h / 2, 0), Vector3.ZERO, 18))
	for y in [0.15, 0.5, 0.85]:
		body.add_child(ring(r - 0.01, r + 0.025, Materials.flat(paint.darkened(0.35), 0.6, 0.4), at + Vector3(0, h * y, 0)))
	body.add_child(cyl(r * 0.98, r * 0.98, 0.02, Materials.flat(paint.darkened(0.2), 0.6, 0.3), at + Vector3(0, h + 0.01, 0), Vector3.ZERO, 18))


## House A: a can on its side, half sunk, the door in its open end.
func concept_rat_house_can_side(team: Color) -> Dictionary:
	var body := Node3D.new()
	var tin := mats.get_mat("tin")
	body.add_child(cyl(0.5, 0.5, 1.1, tin, Vector3(0, 0.3, 0), Vector3(90, 30, 0), 24))
	for k in 3:
		body.add_child(ring(0.49, 0.54, Materials.flat(Color("#9a9c96"), 0.5, 0.5), Vector3(0, 0.3, 0) + Vector3(sin(deg_to_rad(30)), 0, cos(deg_to_rad(30))) * (-0.35 + k * 0.35), Vector3(90, 30, 0)))
	var end := Vector3(sin(deg_to_rad(30)), 0, cos(deg_to_rad(30))) * 0.56 + Vector3(0, 0.3, 0)
	body.add_child(cyl(0.32, 0.32, 0.04, Materials.flat(Color("#1e1612"), 0.9), end, Vector3(90, 30, 0), 18))   # the doorway
	body.add_child(box(Vector3(0.5, 0.04, 0.3), cloth(team), end + Vector3(0.1, -0.2, 0.15), Vector3(0, 30, 0)))   # a team mat
	body.add_child(cyl(0.05, 0.05, 0.35, Materials.flat(Color("#4a4a48"), 0.5, 0.6), Vector3(-0.2, 0.85, -0.2), Vector3.ZERO, 8))
	_grass_tufts(body, Vector3(0, 0, 0), 0.6, 8)
	return {"body": body, "anchor": Vector3.ZERO, "smoke": Vector3(-0.2, 1.05, -0.2), "lights": [], "lantern": Vector3(0.3, 0.4, 0.5), "team": team}


## House B: two small cans stacked, a ladder up to the top one.
func concept_rat_house_stack(team: Color) -> Dictionary:
	var body := Node3D.new()
	var tin := mats.get_mat("tin")
	body.add_child(cyl(0.48, 0.48, 0.62, tin, Vector3(0, 0.31, 0), Vector3.ZERO, 24))
	body.add_child(cyl(0.38, 0.38, 0.5, Materials.flat(Color("#b8a080"), 0.6, 0.5), Vector3(0.05, 0.87, -0.03), Vector3(0, 0, 3), 24))   # a smaller, rustier can on top
	body.add_child(box(Vector3(0.3, 0.42, 0.05), Materials.flat(Color("#1e1612"), 0.9), Vector3(0.1, 0.22, 0.47), Vector3(0, 10, 0)))
	var wood := mats.get_mat("wood")
	for x in [-0.08, 0.08]:
		body.add_child(beam(Vector3(0.45 + x, 0, 0.3), Vector3(0.3 + x, 0.9, 0.28), 0.015, wood, 4))
	for k in 4:
		body.add_child(box(Vector3(0.2, 0.02, 0.02), wood, Vector3(0.43 - k * 0.04, 0.2 + k * 0.2, 0.3)))
	body.add_child(box(Vector3(0.22, 0.08, 0.02), cloth(team), Vector3(-0.2, 0.95, 0.35)))
	return {"body": body, "anchor": Vector3.ZERO, "smoke": Vector3(0, 1.2, 0), "lights": [], "lantern": Vector3(0.3, 0.5, 0.5), "team": team}


## House C: a cotton reel turned into a round house, thread still wound round it.
func concept_rat_house_reel(team: Color) -> Dictionary:
	var body := Node3D.new()
	var wood := Materials.flat(Color("#c89a60"), 0.8)
	body.add_child(cyl(0.62, 0.62, 0.1, wood, Vector3(0, 0.05, 0), Vector3.ZERO, 24))
	body.add_child(cyl(0.62, 0.62, 0.1, wood, Vector3(0, 0.95, 0), Vector3.ZERO, 24))
	body.add_child(cyl(0.48, 0.48, 0.8, Materials.flat(Color("#d8d0c0"), 0.9), Vector3(0, 0.5, 0), Vector3.ZERO, 24))   # the wound thread
	for y in range(6):
		body.add_child(ring(0.47, 0.5, Materials.flat(Color("#c0b8a8"), 0.9), Vector3(0, 0.17 + y * 0.13, 0)))
	body.add_child(box(Vector3(0.28, 0.45, 0.05), Materials.flat(Color("#1e1612"), 0.9), Vector3(0, 0.33, 0.48)))
	body.add_child(box(Vector3(0.34, 0.06, 0.04), cloth(team), Vector3(0, 0.6, 0.5)))
	body.add_child(cyl(0.12, 0.12, 0.06, Materials.flat(Color("#2a1e14"), 0.9), Vector3(0, 1.02, 0), Vector3.ZERO, 12))   # the spindle hole
	return {"body": body, "anchor": Vector3.ZERO, "smoke": Vector3(0, 1.1, 0), "lights": [], "lantern": Vector3(0.3, 0.45, 0.5), "team": team}


## Age 3, the pride step: the town hall gets a porch on oil-drum columns and a pediment cut
## from a cracked dinner plate, copying the Romans' temples; broken crockery paves the front.
func junk_town_center_pride(team: Color) -> Dictionary:
	var spec := junk_town_center_small(team)
	var root: Node3D = spec.body
	var paint := [Color("#8a3a2a"), Color("#3a5a7a"), Color("#8a3a2a"), Color("#6a6a5a")]
	for k in 4:   # four columns, each two drums stacked
		var at := Vector3(-0.75 + k * 0.5, 0, 1.05)
		_drum(root, at, 0.13, 0.38, paint[k])
		_drum(root, at + Vector3(0, 0.38, 0), 0.13, 0.38, paint[(k + 1) % 4])
	root.add_child(box(Vector3(1.85, 0.07, 0.4), mats.get_mat("wood"), Vector3(0, 0.8, 1.05)))   # the beam across them
	var plate := slab_tri(Vector2(-0.95, 0), Vector2(0.95, 0), Vector2(0, 0.42), 0.04, Materials.flat(Color("#f0ece0"), 0.4))
	plate.position = Vector3(0, 0.84, 1.15)
	root.add_child(plate)
	root.add_child(box(Vector3(0.02, 0.36, 0.05), Materials.flat(Color("#5a5048"), 0.8), Vector3(0.18, 0.98, 1.18), Vector3(0, 0, 25)))   # the crack
	root.add_child(ring(0.12, 0.15, Materials.flat(Color("#4a6aa0"), 0.5), Vector3(0, 1.0, 1.19), Vector3(90, 0, 0)))   # the plate's blue rim pattern
	rng.seed = 71
	for k in 14:   # the crockery forecourt
		var p := Vector3(rng.randf_range(-0.9, 0.9), 0.015, rng.randf_range(1.3, 1.6))
		root.add_child(box(Vector3(rng.randf_range(0.12, 0.22), 0.02, rng.randf_range(0.1, 0.18)), Materials.flat(Color("#e8e4d8") if k % 3 else Color("#7a9ac0"), 0.4), p, Vector3(0, rng.randf_range(0, 90), 0)))
	return spec


## Barracks A: a sardine tin as the hall, its lid rolled back on the key as the roof's curl.
func concept_rat_barracks_sardine(team: Color) -> Dictionary:
	var body := Node3D.new()
	var tin := Materials.flat(Color("#c8ccd0"), 0.35, 0.8)
	var gold := Materials.flat(Color("#c8a040"), 0.5, 0.5)
	body.add_child(box(Vector3(2.2, 0.62, 1.3), tin, Vector3(0, 0.31, -0.4)))
	body.add_child(box(Vector3(2.24, 0.12, 1.34), gold, Vector3(0, 0.3, -0.4)))   # the printed label band
	body.add_child(cyl(0.2, 0.2, 1.3, tin, Vector3(-1.1, 0.82, -0.4), Vector3(90, 0, 0), 18))   # the lid rolled up at one end
	body.add_child(box(Vector3(1.5, 0.04, 1.3), tin, Vector3(-0.35, 0.95, -0.4), Vector3(0, 0, -14)))   # the lid peeled back over it
	body.add_child(box(Vector3(0.12, 0.3, 0.3), Materials.flat(Color("#6a6c66"), 0.4, 0.7), Vector3(-1.3, 0.82, -0.4)))   # the key
	body.add_child(box(Vector3(0.5, 0.48, 0.05), cloth(team), Vector3(0.4, 0.26, 0.27)))   # the door curtain
	for k in 5:
		body.add_child(cyl(0.025, 0.03, 0.26, mats.get_mat("wood"), Vector3(-1.0 + k * 0.5, 0.13, 1.1), Vector3.ZERO, 6))
	body.add_child(box(Vector3(2.1, 0.03, 0.03), mats.get_mat("wood"), Vector3(0, 0.22, 1.1)))
	body.add_child(cyl(0.18, 0.18, 0.06, mats.get_mat("thatch"), Vector3(0.7, 0.32, 0.7), Vector3(80, 0, 0), 18))   # a cork target
	return {"body": body, "anchor": Vector3.ZERO, "lights": [], "lantern": Vector3(0.4, 0.55, 0.3), "team": team}


## Barracks B: a fort of stacked crates round a yard, a mousetrap as the drill frame.
func concept_rat_barracks_crates(team: Color) -> Dictionary:
	var root := Node3D.new()
	var body := Node3D.new()
	body.scale = Vector3.ONE * 1.6   # crates big enough to read as a fort's walls
	root.add_child(body)
	rng.seed = 72
	for k in 4:   # the back wall, two crates high, and the side walls
		crate(Vector3(-0.6 + k * 0.4, 0, -0.55), body, rng.randf_range(-6, 6))
		crate(Vector3(-0.6 + k * 0.4, 0.3, -0.55), body, rng.randf_range(-8, 8))
	for k in 2:
		crate(Vector3(-0.68, 0, -0.15 + k * 0.4), body, rng.randf_range(-6, 6))
		crate(Vector3(0.68, 0, -0.15 + k * 0.4), body, rng.randf_range(-6, 6))
	var wood := mats.get_mat("wood")
	body.add_child(box(Vector3(0.7, 0.04, 0.4), wood, Vector3(0, 0.03, 0.3)))   # the mousetrap's base
	body.add_child(beam(Vector3(-0.3, 0.06, 0.3), Vector3(0.3, 0.06, 0.3), 0.02, Materials.flat(Color("#8a8c88"), 0.4, 0.7), 6))
	body.add_child(beam(Vector3(-0.3, 0.06, 0.3), Vector3(-0.25, 0.4, 0.2), 0.015, Materials.flat(Color("#8a8c88"), 0.4, 0.7), 6))   # its bar, sprung up
	body.add_child(box(Vector3(0.36, 0.2, 0.03), cloth(team), Vector3(-0.2, 0.5, -0.38)))   # a team rag hung on the wall
	return {"body": root, "anchor": Vector3.ZERO, "lights": [], "lantern": Vector3(0, 0.9, -0.6), "team": team}


## Barracks C: a drainpipe half sunk in the ground as a tunnel hall, a plank front with a door.
func concept_rat_barracks_drain(team: Color) -> Dictionary:
	var body := Node3D.new()
	var clay := Materials.flat(Color("#9a5a3a"), 0.85)
	body.add_child(cyl(0.7, 0.7, 2.2, clay, Vector3(0, 0.2, -0.3), Vector3(0, 0, 90), 24))
	for x in [-0.9, 0.0, 0.9]:
		body.add_child(ring(0.69, 0.76, Materials.flat(Color("#7a4228"), 0.9), Vector3(x, 0.2, -0.3), Vector3(0, 0, 90)))
	body.add_child(cyl(0.6, 0.6, 0.04, Materials.flat(Color("#1e1612"), 0.9), Vector3(1.11, 0.25, -0.3), Vector3(0, 0, 90), 20))   # its dark mouth
	var wood := mats.get_mat("wood")
	for k in 5:
		body.add_child(box(Vector3(0.05, 0.6, 0.24), wood, Vector3(1.13, 0.3, -0.75 + k * 0.22)))   # planks across the mouth
	body.add_child(box(Vector3(0.06, 0.4, 0.3), Materials.flat(Color("#2a1e14"), 0.9), Vector3(1.16, 0.2, -0.3)))
	body.add_child(box(Vector3(0.04, 0.12, 0.34), cloth(team), Vector3(1.18, 0.47, -0.3)))
	var earth := mats.get_mat("mud")
	for side in [-1, 1]:   # earth banked up along both sides: the pipe sits sunk in the ground
		body.add_child(ball(1.0, earth, Vector3(0, 0.0, -0.3 + side * 0.62), Vector3(1.15, 0.32, 0.38)))
	_grass_tufts(body, Vector3(0, 0.25, -0.3), 1.0, 10)
	return {"body": body, "anchor": Vector3.ZERO, "lights": [], "lantern": Vector3(1.2, 0.5, 0.1), "team": team}


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
	spec.doorway = spec.doorway.map(func(p): return Vector3(p.x * k, p.y, p.z * k))
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


## A unit's waypoint (its queued orders): the rally flag's little sibling. A short stake knocked
## into a tuft of earth, a swallow-tailed pennant in the team colour, a brass cap. About half a
## unit tall, so a line of them reads as a route without crowding the units walking it.
func waypoint_flag(team: Color) -> Node3D:
	rng.seed = 78
	var n := Node3D.new()
	var wood := mats.get_mat("wood")
	var stone := mats.get_mat("stone")
	n.add_child(ball(0.06, Materials.flat(Color("#5a4630"), 0.95), Vector3(0, 0.0, 0), Vector3(1.3, 0.35, 1.1)))   # the kicked-up earth
	for k in 3:   # a few stones wedging it
		var a := k * TAU / 3.0 + 0.4
		n.add_child(ball(0.028 + rng.randf() * 0.01, stone, Vector3(cos(a) * 0.05, 0.02, sin(a) * 0.05), Vector3(1.2, 0.8, 1.0)))
	n.add_child(cyl(0.012, 0.016, 0.44, wood, Vector3(0, 0.22, 0), Vector3.ZERO, 8))
	n.add_child(ball(0.022, Materials.flat(Color("#c89a40"), 0.3, 0.8), Vector3(0, 0.455, 0)))
	var strips := 8
	for k in strips:   # the pennant: tapering to a swallow tail, with a little wave
		var f := float(k) / strips
		var x := 0.016 + f * 0.2
		var z := sin(f * 6.0) * 0.015 * (0.3 + f)
		var h := 0.13 * (1.0 - f * 0.55)
		var y := 0.375 - f * 0.01
		if k >= strips - 2:   # the notch of the tail: two points, not a block
			n.add_child(box(Vector3(0.026, h * 0.38, 0.008), cloth(team), Vector3(x, y + h * 0.31, z)))
			n.add_child(box(Vector3(0.026, h * 0.38, 0.008), cloth(team), Vector3(x, y - h * 0.31, z)))
		else:
			n.add_child(box(Vector3(0.026, h, 0.008), cloth(team), Vector3(x, y, z)))
	return n


# ------------------------------------------------------------------ milestone 11 buildings
# One builder per type, dressed in each architecture's kit (KIT: walls, frame, roof, base).

## A building's model: its own function if it has one (barracks_reed...), else the type's
## generic builder in this architecture.
func building(type: String, arch: String, team: Color) -> Dictionary:
	var own := "%s_%s" % [type, arch]
	if has_method(own):
		return call(own, team)
	return call("_" + type, arch, team)


## Posts at the corners of a w x d footprint under the culture's roof: an open shed.
func _lean_to(body: Node3D, arch: String, at: Vector3, w: float, d: float, h: float) -> float:
	var k: Dictionary = KIT[arch]
	for x in [-1, 1]:
		for z in [-1, 1]:
			body.add_child(box(Vector3(0.09, h, 0.09), mats.get_mat(k.frame), at + Vector3(x * (w / 2 - 0.05), h / 2, z * (d / 2 - 0.05))))
	body.add_child(box(Vector3(w, h * 0.5, 0.06), mats.get_mat(k.wall), at + Vector3(0, h * 0.25, -d / 2 + 0.03)))   # a back wall, waist high
	return _roof(body, arch, at + Vector3(0, h, 0), w, d)


func _log_stack(body: Node3D, at: Vector3, rows: int) -> void:
	var wood := mats.get_mat("wood")
	var cut := Materials.flat(Color("#d8b47a"), 0.9)
	for row in rows:
		for k in rows - row + 1:
			var p := at + Vector3(0, 0.07 + row * 0.12, -0.2 + (k + row * 0.5) * 0.13)
			body.add_child(cyl(0.065, 0.065, 0.62, wood, p, Vector3(0, 0, 90), 10))
			body.add_child(cyl(0.06, 0.06, 0.01, cut, p + Vector3(0.315, 0, 0), Vector3(0, 0, 90), 10))


## Archery Range: an open long shed (posts and a roof, no walls) behind a lane of targets.
func _archery_range(arch: String, team: Color) -> Dictionary:
	var body := Node3D.new()
	var wood := mats.get_mat("wood")
	var rise := _lean_to(body, arch, Vector3(0, 0, -0.85), 2.5, 0.8, 0.62)
	body.add_child(box(Vector3(0.36, 0.22, 0.03), cloth(team), Vector3(-0.9, 0.5, -0.45)))   # a team rag on a post
	for k in 3:   # bows racked under the shed
		body.add_child(beam(Vector3(0.6 + k * 0.14, 0.02, -1.05), Vector3(0.65 + k * 0.14, 0.55, -1.12), 0.012, wood, 4))
	for k in 3:   # the targets, down a lane of trodden earth
		var at := Vector3(-0.85 + k * 0.85, 0, 0.85)
		body.add_child(beam(at + Vector3(-0.12, 0, -0.08), at + Vector3(0, 0.42, 0), 0.02, wood, 6))
		body.add_child(beam(at + Vector3(0.12, 0, -0.08), at + Vector3(0, 0.42, 0), 0.02, wood, 6))
		body.add_child(cyl(0.2, 0.2, 0.08, mats.get_mat("thatch"), at + Vector3(0, 0.42, 0.04), Vector3(80, 0, 0), 20))
		body.add_child(ring(0.05, 0.09, cloth(Color("#c03030")), at + Vector3(0, 0.42, 0.09), Vector3(80, 0, 0)))
	body.add_child(box(Vector3(2.6, 0.015, 0.5), mats.get_mat("mud"), Vector3(0, 0.008, 0.2)))   # the shooting lane
	return {"body": body, "anchor": Vector3.ZERO, "lantern": Vector3(0, 0.5, -0.5), "lights": [], "team": team}


## Armoury: a squat smithy under a tall chimney stack, the forge glowing in an open side.
func _armoury(arch: String, team: Color) -> Dictionary:
	var body := Node3D.new()
	var wood := mats.get_mat("wood")
	var iron := Materials.flat(Color("#4a4c50"), 0.5, 0.7)
	var hall := Node3D.new()
	hall.position = Vector3(-0.25, 0, -0.2)
	body.add_child(hall)
	var base := _hall(hall, arch, 1.2, 1.1, 0.55)   # low and squat
	_roof(hall, arch, Vector3(0, base + 0.55, 0), 1.2, 1.1)
	hall.add_child(box(Vector3(0.34, 0.42, 0.04), cloth(team), Vector3(-0.3, base + 0.21, 0.57)))
	var stone := mats.get_mat("stone")
	# The chimney stack is the silhouette, in the culture's own stuff: stone and brick for the
	# builders, a clay pipe for reed and mound, a stove pipe for the junk-rats, felt-wrapped poles
	# for tents.
	var stack_mat: Material = {"reed": mats.get_mat("mud"), "mound": mats.get_mat("mud"), "junk": Materials.flat(Color("#4a4a48"), 0.5, 0.6),
		"tent": mats.get_mat("felt"), "thatch": mats.get_mat("brick")}.get(arch, stone)
	if arch == "junk":
		body.add_child(cyl(0.14, 0.14, 1.5, stack_mat, Vector3(0.55, 0.75, -0.55), Vector3.ZERO, 12))
		body.add_child(cyl(0.18, 0.16, 0.12, stack_mat, Vector3(0.55, 1.5, -0.55), Vector3.ZERO, 12))
	elif arch in ["reed", "mound"]:
		body.add_child(cyl(0.16, 0.24, 1.5, stack_mat, Vector3(0.55, 0.75, -0.55), Vector3.ZERO, 12))   # a tapering clay flue
	else:
		body.add_child(box(Vector3(0.36, 1.5, 0.36), stack_mat, Vector3(0.55, 0.75, -0.55)))
		body.add_child(box(Vector3(0.42, 0.08, 0.42), stack_mat, Vector3(0.55, 1.5, -0.55)))
	body.add_child(box(Vector3(0.44, 0.34, 0.4), stack_mat if arch == "thatch" else stone, Vector3(0.6, 0.17, 0.25)))   # the forge (brick, like its stack, in a timber town)
	body.add_child(box(Vector3(0.3, 0.04, 0.26), glow(Color("#ff8a30"), 2.2), Vector3(0.6, 0.35, 0.25)))
	body.add_child(box(Vector3(0.22, 0.1, 0.1), iron, Vector3(0.1, 0.26, 0.62)))   # the anvil on its stump
	body.add_child(cyl(0.08, 0.09, 0.2, wood, Vector3(0.1, 0.1, 0.62), Vector3.ZERO, 10))
	return {"body": body, "anchor": Vector3.ZERO, "lantern": Vector3(-0.3, base + 0.45, 0.45), "lights": [Vector3(0.6, 0.38, 0.25)],
		"team": team, "smoke": Vector3(0.55, 1.6, -0.55)}


## Pen: a fold for herd animals round a 3 x 3 patch of open ground (the sheep stand inside, so
## nothing stands in the middle and the fence stays low). Drawn under the units (sim_debug puts
## it in the flat layer), so a sheep by the back fence stands in front of it. A gap for the gate
## on the front (+z) face, a team rag on the gate post, a feed trough and a hay heap outside.
## Three looks were tried (concept_pen_*, archive/images/2026-10-13); each culture takes the one
## that suits its stuff: woven hurdles for the reed and thatch towns, tin sheets nailed up by the
## junk-rats, a dry-stone wall for the builders, a packed-earth wall for the mound, and an open
## corral of rails for the tent people (PEN_LOOK: style, fence material).
const PEN_LOOK := {"thatch": ["hurdles", "weave"], "reed": ["hurdles", "weave"], "junk": ["hurdles", "tin"],
	"stone": ["wall", "stone"], "mound": ["wall", "mud"], "tent": ["rails", "wood"]}


func _pen(arch: String, team: Color) -> Dictionary:
	return _pen_look(PEN_LOOK[arch][0], arch, team)


func concept_pen_hurdles(team: Color) -> Dictionary:
	return _pen_look("hurdles", "thatch", team)


func concept_pen_rails(team: Color) -> Dictionary:
	return _pen_look("rails", "thatch", team)


func concept_pen_wall(team: Color) -> Dictionary:
	return _pen_look("wall", "stone", team)


func _pen_look(style: String, arch: String, team: Color) -> Dictionary:
	var body := Node3D.new()
	var wood := mats.get_mat("wood")
	var panel: Material = mats.get_mat(PEN_LOOK[arch][1])
	var half := 1.42
	var h := 0.24
	for side in 4:   # front (+z), right (+x), back (-z), left (-x)
		var along := Vector3(1, 0, 0) if side % 2 == 0 else Vector3(0, 0, 1)
		var out := Vector3(0, 0, half) if side == 0 else Vector3(half, 0, 0) if side == 1 else Vector3(0, 0, -half) if side == 2 else Vector3(-half, 0, 0)
		var rot := Vector3(0, 0 if side % 2 == 0 else 90, 0)
		for k in 3:   # a tile of fence at a time; the front's middle one is the gate
			var mid := out + along * (k - 1) * (half * 2.0 / 3.0)
			if side == 0 and k == 1:
				continue
			match style:
				"hurdles":   # a woven panel between two stakes
					body.add_child(box(Vector3(0.9, h, 0.05), panel, mid + Vector3(0, h * 0.5 + 0.02, 0), rot))
					for e in [-0.47, 0.47]:
						body.add_child(cyl(0.025, 0.03, h + 0.1, wood, mid + along * e + Vector3(0, (h + 0.1) * 0.5, 0), Vector3.ZERO, 6))
				"rails":   # post and two rails
					for e in [-0.47, 0.47]:
						body.add_child(cyl(0.03, 0.035, h + 0.06, wood, mid + along * e + Vector3(0, (h + 0.06) * 0.5, 0), Vector3.ZERO, 6))
					for y in [0.1, 0.21]:
						body.add_child(box(Vector3(0.96, 0.035, 0.035), wood, mid + Vector3(0, y, 0), rot))
				"wall":   # a low dry-stone wall, capped
					body.add_child(box(Vector3(0.98, h * 0.8, 0.16), panel, mid + Vector3(0, h * 0.4, 0), rot))
					body.add_child(box(Vector3(0.98, 0.04, 0.2), panel, mid + Vector3(0, h * 0.8 + 0.02, 0), rot))
	var gate_post := Vector3(half / 3.0, 0, half)
	body.add_child(cyl(0.035, 0.04, h + 0.2, wood, gate_post + Vector3(0, (h + 0.2) * 0.5, 0), Vector3.ZERO, 6))
	body.add_child(box(Vector3(0.03, 0.16, 0.14), cloth(team), gate_post + Vector3(0.04, h + 0.08, 0.08)))   # a team rag on the gate post
	if style == "hurdles":   # the gate hurdle, swung open against the fence
		body.add_child(box(Vector3(0.85, h, 0.05), panel, Vector3(half / 3.0 + 0.1, h * 0.5 + 0.02, half + 0.42), Vector3(0, 80, 0)))
	# A feed trough against the right fence, outside, and a heap of hay by the gate.
	body.add_child(box(Vector3(0.16, 0.1, 0.62), wood, Vector3(half + 0.16, 0.06, -0.3)))
	body.add_child(box(Vector3(0.11, 0.03, 0.56), Materials.flat(Color("#c8b060"), 1.0), Vector3(half + 0.16, 0.115, -0.3)))
	body.add_child(ball(0.2, mats.get_mat("thatch"), Vector3(-half / 3.0 - 0.1, 0.06, half + 0.32), Vector3(1.3, 0.6, 1.0)))
	return {"body": body, "anchor": Vector3.ZERO, "lights": [], "team": team}


## Lumber Camp: an open shed over a stack of logs, a chopping block with an axe in it.
func _lumber_camp(arch: String, team: Color) -> Dictionary:
	var body := Node3D.new()
	var wood := mats.get_mat("wood")
	_lean_to(body, arch, Vector3(0, 0, -0.2), 1.3, 0.9, 0.62)
	_log_stack(body, Vector3(-0.2, 0, 0.35), 3)
	body.add_child(cyl(0.13, 0.14, 0.22, wood, Vector3(0.55, 0.11, 0.55), Vector3.ZERO, 12))   # the block
	body.add_child(box(Vector3(0.03, 0.3, 0.03), wood, Vector3(0.58, 0.34, 0.55), Vector3(0, 0, -25)))   # the axe
	body.add_child(box(Vector3(0.1, 0.07, 0.02), Materials.flat(Color("#9aa0a6"), 0.4, 0.6), Vector3(0.53, 0.25, 0.55), Vector3(0, 0, -25)))
	body.add_child(box(Vector3(0.36, 0.04, 0.26), cloth(team), Vector3(-0.5, 0.02, 0.5), Vector3(0, 20, 0)))   # a team tarp on the ground
	return {"body": body, "anchor": Vector3.ZERO, "lights": [], "team": team}


## Mill: a raised platform of drying racks hung with produce, sacks and a basket of berries.
func _mill(arch: String, team: Color) -> Dictionary:
	var body := Node3D.new()
	var wood := mats.get_mat("wood")
	var k: Dictionary = KIT[arch]
	for x in [-0.6, 0.6]:   # the platform on short posts
		for z in [-0.6, 0.3]:
			body.add_child(box(Vector3(0.08, 0.3, 0.08), mats.get_mat(k.frame), Vector3(x, 0.15, z)))
	body.add_child(box(Vector3(1.4, 0.06, 1.1), wood, Vector3(0, 0.33, -0.15)))
	for z in [-0.5, -0.1, 0.3]:   # the racks: rails with bundles hanging to dry
		for x in [-0.55, 0.55]:
			body.add_child(box(Vector3(0.05, 0.6, 0.05), wood, Vector3(x, 0.66, z)))
		body.add_child(box(Vector3(1.2, 0.04, 0.04), wood, Vector3(0, 0.95, z)))
		for n in 5:
			body.add_child(ball(0.05, Materials.flat([Color("#c8302a"), Color("#d8b44a"), Color("#7a9a3a")][(n + int(z * 10)) % 3], 0.8),
				Vector3(-0.45 + n * 0.22, 0.85, z), Vector3(0.8, 1.6, 0.8)))
	body.add_child(box(Vector3(0.36, 0.12, 0.03), cloth(team), Vector3(0, 0.98, 0.32)))   # a team cloth over a rail
	if arch in ["stone", "thatch"]:   # builders' towns: on their own footing under their own roof, so it belongs (Fable)
		_footing(body, arch, 1.5, 1.2, 0.3, Vector3(0, 0, -0.15))
		_roof(body, arch, Vector3(0, 1.0, -0.15), 1.4, 1.1)
	var sack := Materials.flat(Color("#c8b48a"), 1.0)
	for p in [Vector3(-0.55, 0.12, 0.6), Vector3(-0.3, 0.12, 0.68), Vector3(-0.42, 0.3, 0.64)]:
		body.add_child(ball(0.13, sack, p, Vector3(1.0, 1.15, 0.9)))
	body.add_child(cyl(0.13, 0.1, 0.16, mats.get_mat("weave"), Vector3(0.45, 0.08, 0.6), Vector3.ZERO, 14))
	return {"body": body, "anchor": Vector3.ZERO, "lights": [], "team": team, "lantern": Vector3(0, 0.5, 0.4)}


## Mining Camp: a lean-to over a dug pit (a ladder down into it), a cart of stone and gold.
func _mining_camp(arch: String, team: Color) -> Dictionary:
	var body := Node3D.new()
	var wood := mats.get_mat("wood")
	_lean_to(body, arch, Vector3(-0.4, 0, -0.4), 1.0, 0.8, 0.58)
	body.add_child(cyl(0.38, 0.32, 0.04, Materials.flat(Color("#1a1410"), 1.0), Vector3(0.35, 0.02, 0.15), Vector3.ZERO, 16))   # the pit, dark
	body.add_child(ring(0.38, 0.5, mats.get_mat("mud"), Vector3(0.35, 0.03, 0.15)))   # its spoil heap rim
	for x in [-0.06, 0.06]:
		body.add_child(beam(Vector3(0.35 + x, -0.1, 0.15), Vector3(0.35 + x, 0.42, -0.05), 0.012, wood, 4))   # the ladder out
	body.add_child(box(Vector3(0.5, 0.15, 0.3), wood, Vector3(-0.35, 0.2, 0.6)))   # the cart
	for x in [-0.55, -0.15]:
		body.add_child(cyl(0.1, 0.1, 0.04, wood, Vector3(x, 0.1, 0.77), Vector3(90, 0, 0), 12))
	var stone := Materials.flat(Color("#e6d4b0"), 0.9)
	var gold := Materials.flat(Color("#f2c440"), 0.3, 0.8)
	for n in 5:
		body.add_child(ball(0.06, stone if n % 3 != 0 else gold, Vector3(-0.5 + (n % 3) * 0.13, 0.32 + (n / 3) * 0.05, 0.56 + (n % 2) * 0.07), Vector3(1.2, 0.8, 1.0)))
	body.add_child(box(Vector3(0.3, 0.12, 0.02), cloth(team), Vector3(-0.4, 0.38, -0.01)))
	return {"body": body, "anchor": Vector3.ZERO, "lights": [], "team": team}


## Market: three stalls under striped awnings round a square, crates, barrels and sacks.
func _market(arch: String, team: Color) -> Dictionary:
	var body := Node3D.new()
	var k: Dictionary = KIT[arch]
	var wood := mats.get_mat("wood")
	if k.base != "":
		_footing(body, arch, 2.7, 2.7, 0.06)
	var awnings := [Color("#c8a040"), Color("#7a9a5a"), Color("#e8dcc0")]   # cream, ochre, olive: not the team (Fable)
	var spots := [[Vector3(-0.8, 0, -0.8), 0.0], [Vector3(0.85, 0, -0.75), -90.0], [Vector3(-0.8, 0, 0.75), 90.0]]
	for i in 3:
		var st := Node3D.new()
		st.position = spots[i][0]
		st.rotation_degrees = Vector3(0, spots[i][1], 0)
		body.add_child(st)
		for x in [-1, 1]:
			for z in [-1, 1]:
				st.add_child(box(Vector3(0.06, 0.62, 0.06), mats.get_mat(k.frame), Vector3(x * 0.38, 0.31, z * 0.26)))
		st.add_child(box(Vector3(0.8, 0.22, 0.4), wood, Vector3(0, 0.11, 0.05)))   # the counter
		st.add_child(box(Vector3(0.9, 0.04, 0.66), cloth(awnings[i]), Vector3(0, 0.66, 0), Vector3(-12, 0, 0)))
		for g in 3:
			st.add_child(ball(0.06, Materials.flat([Color("#d8402a"), Color("#e8c050"), Color("#7aa040")][g], 0.7), Vector3(-0.22 + g * 0.22, 0.27, 0.05)))
	barrel(Vector3(0.75, 0, 0.7), body)
	crate(Vector3(0.45, 0, 0.9), body, 15.0)
	crate(Vector3(0.95, 0, 0.35), body, -10.0)
	return {"body": body, "anchor": Vector3.ZERO, "lights": [], "team": team, "lantern": Vector3(0, 0.6, 0)}


# ------------------------------------------------------------------ siege workshop and wonder (milestone 12)

## Siege Workshop: a yard of timber frames. An open shed at the back under the culture's roof, a
## workbench in it; in the yard two engines going up in fresh-sawn timber: a catapult half built
## (its chassis on three wheels, the fourth leaning by, the A-frames up, the throwing arm propped
## against its crossbar, not yet fitted) and the bare rafters of a ram's shed. Wheels in the
## culture's stuff (_engine_wheel).
func _siege_workshop(arch: String, team: Color) -> Dictionary:
	var body := Node3D.new()
	var wood := mats.get_mat("wood")
	var raw := Materials.flat(Color("#c8a06a"), 0.85)   # fresh-sawn timber, paler than the weathered shed
	var iron := Materials.flat(Color("#4a4c50"), 0.5, 0.7)
	body.add_child(box(Vector3(2.8, 0.015, 2.6), mats.get_mat("mud"), Vector3(0, 0.008, 0.05)))   # the trodden yard
	var rise := _lean_to(body, arch, Vector3(-0.2, 0, -1.0), 2.3, 0.75, 0.72)
	body.add_child(box(Vector3(0.4, 0.26, 0.03), cloth(team), Vector3(-1.1, 0.5, -0.6)))   # a team cloth on the shed post
	body.add_child(box(Vector3(1.0, 0.06, 0.3), wood, Vector3(-0.2, 0.36, -1.1)))   # the bench, a tool on it
	for x in [-0.62, 0.22]:
		body.add_child(box(Vector3(0.06, 0.33, 0.25), wood, Vector3(x, 0.17, -1.1)))
	body.add_child(box(Vector3(0.22, 0.06, 0.06), iron, Vector3(-0.35, 0.42, -1.05)))
	for k in 3:   # sawn beams stacked under the shed's end
		body.add_child(box(Vector3(0.9, 0.08, 0.08), raw, Vector3(0.75, 0.04 + (k / 2) * 0.08, -1.1 + (k % 2) * 0.1 + (k / 2) * 0.05)))
	# The catapult: a chassis along x on its wheels.
	var e := Vector3(-0.45, 0.24, 0.45)
	for z in [-0.26, 0.26]:
		body.add_child(box(Vector3(1.2, 0.1, 0.1), raw, e + Vector3(0, 0, z)))
	for x in [-0.55, 0.55]:
		body.add_child(box(Vector3(0.1, 0.09, 0.62), raw, e + Vector3(x, 0.02, 0)))
	_engine_wheel(body, arch, e + Vector3(-0.4, -0.03, -0.36), Vector3(90, 0, 0))
	_engine_wheel(body, arch, e + Vector3(0.4, -0.03, -0.36), Vector3(90, 0, 0))
	_engine_wheel(body, arch, e + Vector3(-0.4, -0.03, 0.36), Vector3(90, 0, 0))
	_engine_wheel(body, arch, e + Vector3(0.35, -0.04, 0.62), Vector3(70, 0, -10))   # the fourth, leaning by its axle
	# Its A-frames, one each side, and the crossbar over them.
	var apex := e + Vector3(0.1, 0.62, 0)
	for z in [-0.26, 0.26]:
		body.add_child(beam(e + Vector3(-0.35, 0.05, z), apex + Vector3(0, 0, z), 0.035, raw, 6))
		body.add_child(beam(e + Vector3(0.5, 0.05, z), apex + Vector3(0, 0, z), 0.035, raw, 6))
	body.add_child(box(Vector3(0.08, 0.08, 0.66), raw, apex + Vector3(0, 0.02, 0)))
	# The arm, propped on the crossbar, its cup on the ground.
	body.add_child(beam(e + Vector3(-0.85, -0.18, 0.02), apex + Vector3(0.18, 0.12, 0.02), 0.04, raw, 6))
	body.add_child(cyl(0.11, 0.07, 0.07, wood, e + Vector3(-0.9, -0.17, 0.02), Vector3(0, 0, 20), 12))
	body.add_child(box(Vector3(0.03, 0.14, 0.12), cloth(team), apex + Vector3(0.05, 0.12, 0.34)))   # a team rag tied on
	# The ram's shed: bare rafters on two sills, along z, a ridge pole over them.
	var r := Vector3(0.85, 0, 0.35)
	for x in [-0.3, 0.3]:
		body.add_child(box(Vector3(0.09, 0.09, 1.3), raw, r + Vector3(x, 0.045, 0)))
	var ridge_h := 0.75
	for k in 4:
		var z := -0.55 + k * 0.37
		for x in [-0.3, 0.3]:
			body.add_child(beam(r + Vector3(x, 0.08, z), r + Vector3(0, ridge_h, z), 0.03, raw, 6))
	body.add_child(box(Vector3(0.07, 0.07, 1.36), raw, r + Vector3(0, ridge_h, 0)))
	body.add_child(cyl(0.09, 0.09, 1.1, wood, r + Vector3(0, 0.22, 0.05), Vector3(90, 0, 0), 12))   # the ram's log, slung under
	body.add_child(cyl(0.11, 0.1, 0.12, iron, r + Vector3(0, 0.22, 0.62), Vector3(90, 0, 0), 12))     # its iron head
	return {"body": body, "anchor": Vector3.ZERO, "lantern": Vector3(-0.2, rise * 0.3 + 0.6, -0.65), "lights": [], "team": team}


## An engine's wheel in the culture's stuff: a tin lid crimped red for the junk-rats, a round sawn
## off a log for reed and mound, a spoked timber wheel for the rest.
func _engine_wheel(body: Node3D, arch: String, at: Vector3, rot: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation_degrees = rot
	body.add_child(holder)
	var wood := mats.get_mat("wood")
	if arch == "junk":
		holder.add_child(cyl(0.2, 0.2, 0.04, Materials.flat(Color("#b8bcc0"), 0.35, 0.8), Vector3.ZERO, Vector3.ZERO, 18))
		holder.add_child(ring(0.18, 0.22, Materials.flat(Color("#c84030"), 0.5, 0.4)))
	elif arch in ["reed", "mound"]:
		holder.add_child(cyl(0.2, 0.2, 0.07, wood, Vector3.ZERO, Vector3.ZERO, 16))
		holder.add_child(cyl(0.17, 0.17, 0.075, Materials.flat(Color("#d8b47a"), 0.9), Vector3.ZERO, Vector3.ZERO, 16))
	else:
		holder.add_child(ring(0.17, 0.21, wood))
		for s in 3:
			holder.add_child(box(Vector3(0.36, 0.03, 0.03), wood, Vector3.ZERO, Vector3(0, s * 60.0, 0)))
		holder.add_child(cyl(0.04, 0.04, 0.06, wood, Vector3.ZERO, Vector3.ZERO, 8))


## A pole with a team pennant, the live banner a Wonder flies. Returns [banner node, its pivot].
func _pennant(body: Node3D, foot: Vector3, h: float, team: Color, finial: Material = null) -> Array:
	var wood := mats.get_mat("wood")
	body.add_child(cyl(0.03, 0.04, h, wood, foot + Vector3(0, h / 2, 0), Vector3.ZERO, 8))
	if finial != null:
		body.add_child(ball(0.06, finial, foot + Vector3(0, h + 0.03, 0)))
	var banner := Node3D.new()
	var flag_top := foot + Vector3(0.03, h - 0.1, 0)
	banner.add_child(box(Vector3(0.5, 0.05, 0.03), wood, flag_top + Vector3(0.25, 0, 0)))
	banner.add_child(slab_tri(Vector2(0, 0), Vector2(0.62, -0.22), Vector2(0, -0.5), 0.02, cloth(team)))
	banner.get_child(banner.get_child_count() - 1).position = flag_top
	return [banner, flag_top]


## The builders' Wonder (stone): a great temple on a three-stepped podium, a colonnade all round
## its limewashed hall, a gilded ridge, a team frieze, and a bronze figure on a plinth by the stair.
func wonder_stone(team: Color) -> Dictionary:
	var body := Node3D.new()
	var stone := mats.get_mat("stone")
	var plaster := mats.get_mat("plaster")
	var marble := Materials.flat(Color("#e6e0d2"), 0.75)
	var gold := Materials.flat(Color("#e0b040"), 0.3, 0.85)
	var bronze := Materials.flat(Color("#b07a36"), 0.4, 0.7)
	var y := 0.0
	for s in 3:   # the podium, three steps
		var wd := 4.7 - s * 0.35
		body.add_child(box(Vector3(wd, 0.18, wd), stone, Vector3(0, y + 0.09, -s * 0.12)))
		y += 0.18
	var cz := -0.25   # the temple's middle, a little back: the front steps stay clear
	var w := 3.3
	var d := 3.6
	body.add_child(box(Vector3(w - 0.7, 1.5, d - 0.8), plaster, Vector3(0, y + 0.75, cz)))   # the hall
	body.add_child(box(Vector3(w - 0.68, 0.14, d - 0.78), cloth(team), Vector3(0, y + 1.32, cz)))   # a frieze in the team colour
	body.add_child(box(Vector3(0.6, 0.9, 0.04), Materials.flat(Color("#3a2414"), 0.8), Vector3(0, y + 0.45, cz + (d - 0.8) / 2 + 0.02)))   # the doors
	for k in 6:
		body.add_child(ball(0.03, gold, Vector3(-0.15 + (k % 3) * 0.15, y + 0.3 + (k / 3) * 0.35, cz + (d - 0.8) / 2 + 0.05)))
	var colh := 1.55
	for i in 6:   # the colonnade: six across the ends, seven down the sides
		for side in [-1, 1]:
			var x := -w / 2 + 0.15 + i * (w - 0.3) / 5.0
			body.add_child(cyl(0.085, 0.1, colh, marble, Vector3(x, y + colh / 2, cz + side * (d / 2 - 0.15)), Vector3.ZERO, 14))
	for i in range(1, 6):
		for side in [-1, 1]:
			var z := cz - d / 2 + 0.15 + i * (d - 0.3) / 6.0
			body.add_child(cyl(0.085, 0.1, colh, marble, Vector3(side * (w / 2 - 0.15), y + colh / 2, z), Vector3.ZERO, 14))
	body.add_child(box(Vector3(w + 0.1, 0.2, d + 0.1), marble, Vector3(0, y + colh + 0.1, cz)))   # the entablature
	body.add_child(box(Vector3(w + 0.12, 0.07, d + 0.12), cloth(team), Vector3(0, y + colh + 0.06, cz)))
	var holder := Node3D.new()   # tile_roof runs its ridge along z: front to back here
	holder.position = Vector3(0, y + colh + 0.2, cz)
	body.add_child(holder)
	var rise := tile_roof(holder, Vector3.ZERO, w / 2 + 0.12, d + 0.2, 22.0, marble, plaster)
	var ry := y + colh + 0.2
	body.add_child(box(Vector3(0.1, 0.08, d + 0.25), gold, Vector3(0, ry + rise + 0.03, cz)))   # the gilded ridge
	for z in [-1, 1]:   # gold finials on the gables, a team disc in the front one
		body.add_child(ball(0.09, gold, Vector3(0, ry + rise + 0.1, cz + z * (d / 2 + 0.1))))
	body.add_child(ball(0.17, cloth(team), Vector3(0, ry + rise * 0.4, cz + d / 2 + 0.12), Vector3(1, 1, 0.3)))
	body.add_child(ring(0.16, 0.21, gold, Vector3(0, ry + rise * 0.4, cz + d / 2 + 0.13), Vector3(90, 0, 0)))
	# Two fire bowls before the doors, and the figure on its plinth at the corner.
	for x in [-0.7, 0.7]:
		body.add_child(cyl(0.16, 0.08, 0.12, bronze, Vector3(x, y + 0.06, 1.62), Vector3.ZERO, 14))
		body.add_child(cyl(0.13, 0.13, 0.02, glow(Color("#ff9a3a"), 2.0), Vector3(x, y + 0.12, 1.62), Vector3.ZERO, 14))
	var fig := Vector3(-1.85, y, 1.5)
	body.add_child(box(Vector3(0.4, 0.5, 0.4), marble, fig + Vector3(0, 0.25, 0)))
	body.add_child(cyl(0.1, 0.14, 0.55, bronze, fig + Vector3(0, 0.78, 0), Vector3.ZERO, 12))
	body.add_child(ball(0.08, bronze, fig + Vector3(0, 1.12, 0)))
	body.add_child(beam(fig + Vector3(0.1, 0.95, 0), fig + Vector3(0.2, 1.45, 0.05), 0.02, bronze, 6))   # a raised spear
	var p := _pennant(body, Vector3(1.9, y, 1.55), 2.6, team, gold)
	return {"body": body, "anchor": Vector3.ZERO, "banner": p[0], "banner_pivot": p[1], "lights": [Vector3(-0.7, y + 0.14, 1.62), Vector3(0.7, y + 0.14, 1.62)],
		"smoke": Vector3(0.7, y + 0.3, 1.62), "lantern": Vector3(0, y + 0.6, cz + d / 2 + 0.1)}


## The timber towns' Wonder (thatch): the elders' great hall, mud and timber under deep thatch,
## a stave tower of three stacked roofs rising out of its middle, carved posts at the corners
## with heads in the team colour, and a fire pit before the door.
func wonder_thatch(team: Color) -> Dictionary:
	var body := Node3D.new()
	var wood := mats.get_mat("wood")
	var thatch := mats.get_mat("thatch")
	var dark := Materials.flat(Color("#3a2414"), 0.8)
	var hall := Node3D.new()
	hall.position = Vector3(0, 0, -0.3)
	body.add_child(hall)
	var base := _hall(hall, "thatch", 3.6, 2.4, 0.85)
	var rise := _roof(hall, "thatch", Vector3(0, base + 0.85, 0), 3.6, 2.4)
	hall.add_child(box(Vector3(0.6, 0.7, 0.04), cloth(team), Vector3(0, base + 0.35, 1.22)))
	# The stave tower: three storeys, each a timber box under its own steep thatch hat.
	var y := base + 0.85 + rise * 0.55
	var sizes := [1.3, 1.0, 0.7]
	var hs := [0.6, 0.45, 0.4]
	for s in 3:
		var sz: float = sizes[s]
		var hh: float = hs[s]
		hall.add_child(box(Vector3(sz, hh, sz), wood, Vector3(0, y + hh / 2, 0)))
		for x in [-1, 1]:
			for z in [-1, 1]:
				hall.add_child(box(Vector3(0.07, hh + 0.04, 0.07), dark, Vector3(x * sz / 2, y + hh / 2, z * sz / 2)))
		hall.add_child(cyl(0.0, sz * 0.95, sz * 0.55, thatch, Vector3(0, y + hh + sz * 0.22, 0), Vector3(0, 45, 0), 4))
		y += hh + sz * 0.3
	hall.add_child(beam(Vector3(0, y + 0.05, 0), Vector3(0, y + 0.5, 0), 0.02, wood, 6))
	hall.add_child(box(Vector3(0.24, 0.16, 0.02), cloth(team), Vector3(0.12, y + 0.42, 0)))
	# Carved posts: a tall trunk with rings cut into it and a painted head on top.
	for p in [Vector3(-2.15, 0, 1.55), Vector3(2.15, 0, 1.55), Vector3(-2.15, 0, -1.8), Vector3(2.15, 0, -1.8)]:
		var h := 1.5
		body.add_child(cyl(0.11, 0.14, h, wood, p + Vector3(0, h / 2, 0), Vector3.ZERO, 10))
		for r in 3:
			body.add_child(ring(0.1, 0.15, dark, p + Vector3(0, 0.4 + r * 0.35, 0)))
		body.add_child(box(Vector3(0.26, 0.3, 0.26), wood, p + Vector3(0, h + 0.15, 0)))   # the carved head
		body.add_child(box(Vector3(0.28, 0.07, 0.28), cloth(team), p + Vector3(0, h + 0.05, 0)))   # painted in the team colour
		body.add_child(box(Vector3(0.1, 0.08, 0.16), dark, p + Vector3(0, h + 0.12, 0.18), Vector3(-15, 0, 0)))   # its beak
		body.add_child(box(Vector3(0.34, 0.05, 0.08), dark, p + Vector3(0, h + 0.32, 0)))   # a crest
		for x in [-0.07, 0.07]:   # its eyes
			body.add_child(ball(0.035, Materials.flat(Color("#f0e6c8"), 0.6), p + Vector3(x, h + 0.22, 0.13)))
	# A fire pit in a ring of stones before the door, benches by it.
	var pit := Vector3(0, 0, 1.6)
	body.add_child(ring(0.24, 0.36, mats.get_mat("stone"), pit + Vector3(0, 0.04, 0)))
	body.add_child(cyl(0.22, 0.22, 0.03, glow(Color("#ff8a30"), 2.2), pit + Vector3(0, 0.04, 0), Vector3.ZERO, 14))
	for x in [-0.8, 0.8]:
		body.add_child(box(Vector3(0.7, 0.08, 0.16), wood, Vector3(x, 0.18, 1.7)))
		for e in [-0.25, 0.25]:
			body.add_child(box(Vector3(0.08, 0.16, 0.12), wood, Vector3(x + e, 0.08, 1.7)))
	return {"body": body, "anchor": Vector3.ZERO, "lights": [pit + Vector3(0, 0.06, 0)], "smoke": pit + Vector3(0, 0.2, 0),
		"lantern": Vector3(0.5, base + 0.5, 0.95), "team": team}


## The junk-rats' Wonder: the Great Cheese. A brick plinth ringed with painted oil drums, a giant
## tin can on it, and on the can a whole cheese wheel stood on its edge, holes and all, crowned
## with a gold bottle cap; team banners fly from poles by the drums.
func wonder_junk(team: Color) -> Dictionary:
	rng.seed = 91
	var body := Node3D.new()
	var brick := mats.get_mat("brick")
	var tin := mats.get_mat("tin")
	var wood := mats.get_mat("wood")
	var gold := Materials.flat(Color("#e0b040"), 0.3, 0.85)
	body.add_child(box(Vector3(4.5, 0.3, 4.5), brick, Vector3(0, 0.15, 0)))
	body.add_child(box(Vector3(3.6, 0.2, 3.6), brick, Vector3(0, 0.4, 0)))
	var paint := [Color("#8a3a2a"), Color("#3a5a7a"), Color("#6a6a5a"), Color("#7a6a2a")]
	var n := 0
	for side in 4:   # oil drums round the plinth's top
		for k in 3:
			var t := -1.2 + k * 1.2
			var at := Vector3(t, 0.5, 1.6) if side == 0 else Vector3(1.6, 0.5, -t) if side == 1 else Vector3(-t, 0.5, -1.6) if side == 2 else Vector3(-1.6, 0.5, t)
			if side == 0 and k == 1:
				continue   # the way in
			_drum(body, at, 0.22, 0.5, paint[n % 4])
			n += 1
	var can_h := 1.0
	body.add_child(cyl(1.15, 1.15, can_h, tin, Vector3(0, 0.5 + can_h / 2, -0.1), Vector3.ZERO, 32))   # the great can
	for y in [0.2, 0.5, 0.8]:
		body.add_child(ring(1.13, 1.2, Materials.flat(Color("#9a9c96"), 0.5, 0.5), Vector3(0, 0.5 + can_h * y, -0.1)))
	body.add_child(cyl(1.0, 1.0, 0.04, Materials.flat(Color("#c8ccd0"), 0.35, 0.8), Vector3(0, 0.5 + can_h + 0.02, -0.1), Vector3.ZERO, 32))
	body.add_child(box(Vector3(0.5, 0.7, 0.04), Materials.flat(Color("#2a1e16"), 0.9), Vector3(0, 0.85, 1.07)))   # a door cut in the can
	body.add_child(box(Vector3(1.0, 0.18, 0.03), cloth(team), Vector3(0, 1.3, 1.06)))   # a label in the team colour
	# The cheese, on edge in a timber cradle.
	var cheese := Materials.flat(Color("#f2c94c"), 0.7)
	var rind := Materials.flat(Color("#c99a1e"), 0.8)
	var c := Vector3(0, 0.5 + can_h + 0.92, -0.1)
	for x in [-0.4, 0.4]:
		body.add_child(box(Vector3(0.12, 0.3, 0.9), wood, Vector3(x, 0.5 + can_h + 0.15, -0.1)))
	body.add_child(cyl(0.9, 0.9, 0.62, cheese, c, Vector3(90, 0, 0), 32))
	for z in [0.3, -0.3]:
		body.add_child(ring(0.86, 0.94, rind, c + Vector3(0, 0, z), Vector3(90, 0, 0)))
	for k in 7:   # holes on the face
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.15, 0.7)
		body.add_child(cyl(0.06 + rng.randf() * 0.06, 0.06, 0.02, Materials.flat(Color("#c8961e"), 0.9), c + Vector3(cos(a) * r, sin(a) * r, 0.315), Vector3(90, 0, 0), 12))
	# The bottle cap crown: a crimped gold disc on the cheese's top.
	var cap := c + Vector3(0, 0.95, 0)
	body.add_child(cyl(0.3, 0.3, 0.08, gold, cap, Vector3.ZERO, 20))
	for k in 12:
		var a := TAU * k / 12.0
		body.add_child(box(Vector3(0.06, 0.12, 0.05), gold, cap + Vector3(cos(a) * 0.3, -0.03, sin(a) * 0.3), Vector3(0, -rad_to_deg(a), 0)))
	_pennant(body, Vector3(1.6, 0.5, -1.6), 2.0, team).front().free()   # a still pole at the back (one banner waves)
	body.add_child(slab_tri(Vector2(0, 0), Vector2(0.5, -0.18), Vector2(0, -0.4), 0.02, cloth(team)))
	body.get_child(body.get_child_count() - 1).position = Vector3(1.63, 2.35, -1.6)
	var p := _pennant(body, Vector3(-1.6, 0.5, 1.6), 2.2, team)
	return {"body": body, "anchor": Vector3.ZERO, "banner": p[0], "banner_pivot": p[1], "lights": [],
		"lantern": Vector3(0.4, 1.0, 1.15), "team": team}


## The tent people's Wonder: the great pavilion. A two-storey felt palace on a timber floor, a
## gilded crown on its smoke ring, four tents round it and a ring of tall horse-tail standards.
func wonder_tent(team: Color) -> Dictionary:
	var body := Node3D.new()
	var wood := mats.get_mat("wood")
	var felt := mats.get_mat("felt")
	var gold := Materials.flat(Color("#e0b040"), 0.3, 0.85)
	body.add_child(cyl(1.85, 1.95, 0.14, wood, Vector3(0, 0.07, -0.1), Vector3.ZERO, 32))   # the floor
	var top := _yurt(body, Vector3(0, 0.14, -0.1), 1.6, 1.0, team)
	body.add_child(cyl(0.62, 0.62, 0.45, felt, Vector3(0, 0.14 + top + 0.2, -0.1), Vector3.ZERO, 24))   # the upper storey
	body.add_child(ring(0.6, 0.66, cloth(team), Vector3(0, 0.14 + top + 0.35, -0.1)))
	body.add_child(cyl(0.12, 0.7, 0.42, felt, Vector3(0, 0.14 + top + 0.62, -0.1), Vector3.ZERO, 24))
	var crown := Vector3(0, 0.14 + top + 0.86, -0.1)
	body.add_child(cyl(0.14, 0.14, 0.08, gold, crown, Vector3.ZERO, 16))
	body.add_child(cyl(0.0, 0.06, 0.4, gold, crown + Vector3(0, 0.24, 0), Vector3.ZERO, 8))
	body.add_child(ball(0.07, gold, crown + Vector3(0, 0.12, 0)))
	for at in [Vector3(-1.75, 0, 1.55), Vector3(1.75, 0, 1.55), Vector3(-1.85, 0, -1.65), Vector3(1.85, 0, -1.65)]:
		_yurt(body, at, 0.42, 0.42, team)
	# Horse-tail standards: tall poles, a dark tuft under a gold point.
	var hair := Materials.flat(Color("#2a2018"), 0.95)
	for k in 6:
		var a := TAU * (k + 0.5) / 6.0
		var foot := Vector3(cos(a) * 2.15, 0, sin(a) * 2.0 - 0.1)
		if foot.z > 1.2 and absf(foot.x) < 0.8:
			continue   # the way in stays open
		body.add_child(cyl(0.025, 0.03, 2.1, wood, foot + Vector3(0, 1.05, 0), Vector3.ZERO, 6))
		body.add_child(cyl(0.0, 0.04, 0.16, gold, foot + Vector3(0, 2.18, 0), Vector3.ZERO, 6))
		body.add_child(ball(0.1, hair, foot + Vector3(0, 1.9, 0), Vector3(1.0, 1.8, 1.0)))
	var p := _pennant(body, Vector3(-0.75, 0.14, 1.75), 2.5, team, gold)
	return {"body": body, "anchor": Vector3.ZERO, "banner": p[0], "banner_pivot": p[1], "lights": [],
		"smoke": crown + Vector3(0, 0.1, 0), "lantern": Vector3(0, 0.6, 1.6), "team": team}


## The frogs' Wonder: the Lily Spire. A great deck on stilts, a big woven dome and a spire of
## woven drums stacked on it, each under its own reed cap, opening at the top into a pink water
## lily the size of a hut; small domes at the deck's corners and a reed fence round it.
func wonder_reed(team: Color) -> Dictionary:
	rng.seed = 92
	var body := Node3D.new()
	var weave := mats.get_mat("weave")
	var thatch := mats.get_mat("thatch")
	var deck := _stilt_deck(body, Vector3.ZERO, 4.5, 4.5)
	var top := _reed_dome(body, Vector3(0, deck, -0.2), 1.35, team)
	var y := top - 0.15
	var radii := [0.7, 0.52, 0.38]
	for s in 3:   # the spire: drum, cap, drum, cap ...
		var r: float = radii[s]
		body.add_child(cyl(r * 0.92, r, 0.4, weave, Vector3(0, y + 0.2, -0.2), Vector3.ZERO, 24))
		body.add_child(ring(r - 0.02, r + 0.04, cloth(team) if s == 0 else mats.get_mat("mud"), Vector3(0, y + 0.08, -0.2)))
		body.add_child(dome(r + 0.08, thatch, Vector3(0, y + 0.38, -0.2), Vector3(1.0, 0.45, 1.0)))
		y += 0.52
	# The lily: two rings of petals round a gold heart, on a wide pad.
	var heart := Vector3(0, y + 0.1, -0.2)
	body.add_child(cyl(0.75, 0.75, 0.03, Materials.flat(Color("#3d6a2c"), 0.8), heart - Vector3(0, 0.12, 0), Vector3.ZERO, 24))
	for rk in 2:
		var count := 8 if rk == 0 else 6
		for k in count:
			var a := TAU * (k + rk * 0.5) / count
			var lean := 55.0 if rk == 0 else 25.0
			var petal := Node3D.new()   # turned to face out, then tipped outwards
			petal.position = heart + Vector3(cos(a), 0, sin(a)) * (0.3 - rk * 0.13) + Vector3(0, 0.12 + rk * 0.08, 0)
			petal.rotation_degrees = Vector3(0, -rad_to_deg(a) + 90.0, 0)
			body.add_child(petal)
			petal.add_child(ball(0.32 - rk * 0.06, Materials.flat(Color("#e890b0") if rk == 0 else Color("#f4c0d0"), 0.6),
				Vector3.ZERO, Vector3(0.45, 1.0, 0.22), Vector3(lean, 0, 0)))
	body.add_child(ball(0.13, Materials.flat(Color("#f2c94c"), 0.5), heart + Vector3(0, 0.2, 0)))
	for at in [Vector3(-1.7, deck, -1.7), Vector3(1.65, deck, 1.6), Vector3(1.75, deck, -1.7)]:
		_reed_dome(body, at, 0.42, team, 20.0 * signf(at.x))
	_reed_fence(body, Vector3(0, deck, 0), 2.15)
	var wood := mats.get_mat("wood")
	for k in 3:   # steps down at the front
		body.add_child(box(Vector3(0.6, 0.05, 0.16), wood, Vector3(0, deck * (k + 0.5) / 3.0, 2.55 - k * 0.14)))
	var p := _pennant(body, Vector3(-1.9, deck, 1.9), 2.2, team)   # on the left corner, clear of the spire
	return {"body": body, "anchor": Vector3.ZERO, "banner": p[0], "banner_pivot": p[1], "lights": [],
		"lantern": Vector3(0, deck + 0.4, 1.3), "team": team}


## The bugs' Wonder: the great termite spires. A broad earthen mound with five tall fluted spires
## grown out of it, round doors at their feet, amber set glowing into the walls, and a polished
## shell hung up as a trophy over the main door.
func wonder_mound(team: Color) -> Dictionary:
	rng.seed = 93
	var body := Node3D.new()
	var mud := mats.get_mat("mud")
	body.add_child(dome(2.0, mud, Vector3(0, 0, -0.1), Vector3(1.05, 0.55, 1.0)))
	var spires := [[Vector3(-0.1, 0, -0.35), 0.75, 3.4], [Vector3(-0.95, 0, 0.35), 0.5, 2.3], [Vector3(0.85, 0, -0.85), 0.55, 2.6],
		[Vector3(0.9, 0, 0.6), 0.45, 1.8], [Vector3(-1.0, 0, -1.1), 0.42, 1.7]]
	for s in spires:
		var at: Vector3 = s[0]
		var r: float = s[1]
		var h: float = s[2]
		body.add_child(cyl(r * 0.12, r, h, mud, at + Vector3(0, h / 2, 0), Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)), 14))
		for k in 3:   # flutes: lumps up its sides
			var a := TAU * k / 3.0 + rng.randf()
			body.add_child(cyl(r * 0.05, r * 0.4, h * 0.6, mud, at + Vector3(cos(a) * r * 0.55, h * 0.3, sin(a) * r * 0.55), Vector3.ZERO, 8))
	_burrow_door(body, Vector3(0.0, 0.32, 1.8), 0.3, 0.0, team)
	_burrow_door(body, Vector3(-1.6, 0.25, 1.0), 0.16, -50.0, team)
	_burrow_door(body, Vector3(1.75, 0.25, 0.6), 0.16, 60.0)
	var amber := glow(Color("#ffb040"), 1.6)
	var lights := []
	for p in [Vector3(-0.55, 0.65, 1.55), Vector3(0.6, 0.7, 1.45), Vector3(-0.1, 1.6, 0.25), Vector3(0.95, 1.2, -0.45)]:
		body.add_child(ball(0.08, amber, p, Vector3(1.0, 1.3, 0.7)))
		lights.append(p)
	# The trophy: a polished beetle shell over the main door.
	var shell := Materials.flat(Color("#2e5a4a"), 0.25, 0.6)
	body.add_child(ball(0.32, shell, Vector3(0.0, 0.95, 1.62), Vector3(1.0, 0.55, 0.5), Vector3(-25, 0, 0)))
	body.add_child(box(Vector3(0.03, 0.17, 0.2), Materials.flat(Color("#1a3028"), 0.3), Vector3(0.0, 0.96, 1.75), Vector3(-25, 0, 0)))
	_grass_tufts(body, Vector3(0, 0.6, 0), 1.4, 12)
	var p := _pennant(body, Vector3(1.85, 0.0, -1.8), 2.4, team)
	return {"body": body, "anchor": Vector3.ZERO, "banner": p[0], "banner_pivot": p[1], "lights": lights,
		"lantern": Vector3(0.3, 0.5, 1.9), "team": team}

# ------------------------------------------------------------------ University and Castle (milestone 12)
# Built from one vocabulary per culture: its tower (_fort_tower), its wall (_fort_wall) and its
# great hall (_keep), so a castle reads as its culture's whatever the layout: dressed stone and
# merlons for the builders, timber and thatch on an earth bank for the timber towns, stacked tin
# cans and brick for the junk-rats, felt on poles for the tent people, woven reed on stilts for
# the frogs, termite spires for the mound-diggers. The concept round (D-080) tried three layouts
# of each (building sheet: castle:stone:curtain); CASTLE_LOOK and UNIVERSITY_LOOK say which one
# each culture builds in play until Dominic picks.

const UNIVERSITY_LOOK := {"stone": "cloister", "thatch": "cloister", "junk": "builders", "tent": "builders",
	"reed": "observatory", "mound": "observatory"}
const CASTLE_LOOK := {"stone": "curtain", "thatch": "motte", "junk": "great_tower", "tent": "curtain", "reed": "great_tower",
	"mound": "great_tower"}
const UNIVERSITY_LOOKS := ["observatory", "cloister", "builders"]
const CASTLE_LOOKS := ["curtain", "motte", "great_tower"]


## A building type's model in one of its concept looks (the building sheet: type:arch:look).
func look(type: String, arch: String, name: String, team: Color) -> Dictionary:
	return call("_%s_look" % type, name, arch, team)


func _university(arch: String, team: Color) -> Dictionary:
	return _university_look(UNIVERSITY_LOOK[arch], arch, team)


func _castle(arch: String, team: Color) -> Dictionary:
	return _castle_look(CASTLE_LOOK[arch], arch, team)


## A dark arrow slit on a wall facing `turn` degrees (0: +z), centred on `at`.
func _slit(body: Node3D, at: Vector3, turn: float, h := 0.18) -> void:
	body.add_child(box(Vector3(0.035, h, 0.02), Materials.flat(Color("#1a140e"), 1.0), at, Vector3(0, turn, 0)))


## Merlons round a circle of radius r at height y.
func _merlon_ring(body: Node3D, at: Vector3, r: float, y: float, mat: Material, n := 8) -> void:
	for k in n:
		var a := TAU * (k + 0.5) / n
		body.add_child(box(Vector3(0.11, 0.12, 0.09), mat, at + Vector3(sin(a) * r, y + 0.06, cos(a) * r), Vector3(0, rad_to_deg(a), 0)))


## A tower in the culture's own way, standing on `at`, radius r (half its width) and h tall to
## its fighting top. Returns the height of its very top.
func _fort_tower(body: Node3D, arch: String, at: Vector3, r: float, h: float) -> float:
	var wood := mats.get_mat("wood")
	match arch:
		"stone":   # a round drum tower of dressed stone, a string course, slits, merlons
			var stone := mats.get_mat("stone")
			body.add_child(cyl(r, r * 1.08, h, stone, at + Vector3(0, h / 2, 0), Vector3.ZERO, 20))
			body.add_child(ring(r * 1.0, r * 1.07, stone, at + Vector3(0, h * 0.62, 0)))
			body.add_child(cyl(r + 0.05, r + 0.03, 0.1, stone, at + Vector3(0, h + 0.05, 0), Vector3.ZERO, 20))
			_merlon_ring(body, at, r + 0.0, h + 0.1, stone, 8)
			for turn in [0.0, 90.0]:
				var a := deg_to_rad(turn)
				_slit(body, at + Vector3(sin(a), 0, cos(a)) * (r * 1.02) + Vector3(0, h * 0.45, 0), turn)
			return h + 0.22
		"thatch":   # a square mud-and-timber tower, a jettied plank top, a thatched pyramid roof
			var mud := mats.get_mat("mud")
			_footing(body, arch, r * 2 + 0.1, r * 2 + 0.1, 0.1, at)
			body.add_child(box(Vector3(r * 2, h, r * 2), mud, at + Vector3(0, h / 2 + 0.1, 0)))
			for x in [-1, 1]:
				for z in [-1, 1]:
					body.add_child(box(Vector3(0.08, h, 0.08), wood, at + Vector3(x * r, h / 2 + 0.1, z * r)))
			body.add_child(beam(at + Vector3(-r, 0.15, r + 0.01), at + Vector3(r, h * 0.8, r + 0.01), 0.03, wood, 4))   # a brace across the front
			body.add_child(box(Vector3(r * 2 + 0.16, 0.3, r * 2 + 0.16), wood, at + Vector3(0, h + 0.25, 0)))   # the jetty
			_slit(body, at + Vector3(0, h + 0.25, r + 0.09), 0.0, 0.14)
			var rr := (r + 0.18) * 1.414
			body.add_child(cyl(0.0, rr, r * 1.5, mats.get_mat("thatch"), at + Vector3(0, h + 0.4 + r * 0.75, 0), Vector3(0, 45, 0), 4))
			return h + 0.4 + r * 1.5
		"junk":   # tin cans stacked on a brick drum, a funnel for a roof and a stove pipe
			var tin := mats.get_mat("tin")
			var band := Materials.flat(Color("#9a9c96"), 0.5, 0.5)
			body.add_child(cyl(r * 1.08, r * 1.12, 0.3, mats.get_mat("brick"), at + Vector3(0, 0.15, 0), Vector3.ZERO, 16))
			var y := 0.3
			var k := 0
			while y < h - 0.05:
				var ch := minf(0.55, h - y)
				var cr := r * (1.0 - 0.06 * k)
				body.add_child(cyl(cr, cr, ch, tin, at + Vector3(0.02 * (k % 2), y + ch / 2, 0), Vector3(0, 30 * k, 0), 18))
				body.add_child(ring(cr - 0.01, cr + 0.03, band, at + Vector3(0.02 * (k % 2), y + ch - 0.04, 0)))
				y += ch
				k += 1
			_slit(body, at + Vector3(0, h * 0.55, r * 0.95), 0.0)
			body.add_child(cyl(0.0, r + 0.12, r * 0.9, tin, at + Vector3(0, y + r * 0.45, 0), Vector3.ZERO, 18))   # the funnel roof
			body.add_child(cyl(0.05, 0.05, r * 1.4, Materials.flat(Color("#4a4a48"), 0.5, 0.6), at + Vector3(r * 0.35, y + r * 0.7, 0), Vector3.ZERO, 8))
			return y + r * 0.9
		"tent":   # four poles to a railed platform, felt wrapped round the lower half, a felt cap
			var felt := mats.get_mat("felt")
			for x in [-1, 1]:
				for z in [-1, 1]:
					body.add_child(beam(at + Vector3(x * r * 1.15, 0, z * r * 1.15), at + Vector3(x * r * 0.85, h, z * r * 0.85), 0.04, wood))
			body.add_child(cyl(r * 1.02, r * 1.12, h * 0.55, felt, at + Vector3(0, h * 0.275, 0), Vector3(0, 45, 0), 4))
			body.add_child(box(Vector3(r * 2 + 0.1, 0.07, r * 2 + 0.1), wood, at + Vector3(0, h, 0)))
			body.add_child(cyl(r * 0.85, r * 0.85, 0.28, felt, at + Vector3(0, h + 0.17, 0), Vector3.ZERO, 20))
			body.add_child(cyl(r * 0.15, r + 0.05, r * 0.6, felt, at + Vector3(0, h + 0.31 + r * 0.3, 0), Vector3.ZERO, 20))
			return h + 0.31 + r * 0.6
		"reed":   # a woven tower on stilts, banded with mud, under a reed dome
			var deck := _stilt_deck(body, at, r * 2 + 0.2, r * 2 + 0.2)
			var weave := mats.get_mat("weave")
			body.add_child(cyl(r * 0.88, r, h - deck, weave, at + Vector3(0, deck + (h - deck) / 2, 0), Vector3.ZERO, 22))
			for t in [0.25, 0.7]:
				body.add_child(ring(r * (1.0 - 0.12 * t) - 0.02, r * (1.0 - 0.12 * t) + 0.04, mats.get_mat("mud"), at + Vector3(0, deck + (h - deck) * t, 0)))
			_slit(body, at + Vector3(0, deck + (h - deck) * 0.5, r * 0.95), 0.0)
			body.add_child(dome(r * 0.98, mats.get_mat("thatch"), at + Vector3(0, h - 0.02, 0), Vector3(1.0, 1.0, 1.0)))
			return h + r * 0.98
		"mound":   # a termite spire: a tapering cone of packed earth, lumps on its flanks
			var mud := mats.get_mat("mud")
			body.add_child(cyl(r * 0.28, r * 1.05, h, mud, at + Vector3(0, h / 2, 0), Vector3.ZERO, 14))
			for k in 4:
				var a := TAU * k / 4.0 + 0.6
				var y := h * (0.25 + 0.15 * k)
				var rad := r * 1.05 - (r * 0.77) * y / h
				body.add_child(ball(r * 0.32, mud, at + Vector3(sin(a) * rad * 0.8, y, cos(a) * rad * 0.8), Vector3(1.0, 1.3, 1.0)))
			body.add_child(ball(r * 0.3, mud, at + Vector3(0, h, 0), Vector3(1.0, 1.4, 1.0)))
			_burrow_door(body, at + Vector3(0, h * 0.5, r * 0.62), r * 0.18, 0.0)
			return h + r * 0.4
	assert(false, "no tower for %s" % arch)
	return h


## A stretch of curtain wall h high from a to b (on the ground), in the culture's stuff.
func _fort_wall(body: Node3D, arch: String, a: Vector3, b: Vector3, h: float, thick := 0.22) -> void:
	var holder := Node3D.new()
	holder.position = (a + b) / 2
	holder.transform.basis = Basis(Vector3.UP, atan2(-(b.z - a.z), b.x - a.x))
	body.add_child(holder)
	var l := a.distance_to(b)
	var wood := mats.get_mat("wood")
	match arch:
		"stone":   # dressed stone, a walkway cap, merlons
			var stone := mats.get_mat("stone")
			holder.add_child(box(Vector3(l, h, thick), stone, Vector3(0, h / 2, 0)))
			holder.add_child(box(Vector3(l, 0.05, thick + 0.06), stone, Vector3(0, h + 0.025, 0)))
			var n := maxi(1, int(l / 0.24))
			for k in n:
				holder.add_child(box(Vector3(0.12, 0.11, thick * 0.6), stone, Vector3(-l / 2 + (k + 0.5) * l / n, h + 0.1, 0)))
		"thatch", "tent":   # sharpened stakes (on an earth bank in the timber towns; felt hung on them for the tents)
			if arch == "thatch":
				holder.add_child(box(Vector3(l + 0.1, 0.16, thick + 0.3), mats.get_mat("mud"), Vector3(0, 0.08, 0)))
			var base := 0.14 if arch == "thatch" else 0.0
			var n := maxi(2, int(l / 0.11))
			for k in n:
				var x := -l / 2 + (k + 0.5) * l / n
				var sh := h - base + (0.04 if k % 2 == 0 else -0.02)
				holder.add_child(cyl(0.05, 0.055, sh, wood, Vector3(x, base + sh / 2, 0), Vector3(rng.randf_range(-3, 3), 0, 0), 7))
				holder.add_child(cyl(0.0, 0.05, 0.1, wood, Vector3(x, base + sh + 0.05, 0), Vector3.ZERO, 7))
			holder.add_child(box(Vector3(l, 0.04, 0.03), wood, Vector3(0, base + (h - base) * 0.7, thick * 0.3)))   # a rail binding them
			if arch == "tent":
				holder.add_child(box(Vector3(l, h * 0.42, 0.03), mats.get_mat("felt"), Vector3(0, h * 0.3, 0.07)))
		"junk":   # a brick footing with tin sheets and planks nailed up above it
			holder.add_child(box(Vector3(l, h * 0.45, thick), mats.get_mat("brick"), Vector3(0, h * 0.225, 0)))
			var n := maxi(1, int(l / 0.42))
			for k in n:
				var x := -l / 2 + (k + 0.5) * l / n
				var sh := h * 0.6 + rng.randf_range(-0.05, 0.08)
				var mat: Material = mats.get_mat("tin") if k % 3 != 1 else Materials.flat(Color("#6e4a2c").lerp(Color("#8a7050"), rng.randf()), 0.9)
				holder.add_child(box(Vector3(l / n + 0.03, sh, 0.05), mat, Vector3(x, h * 0.4 + sh / 2, rng.randf_range(-0.02, 0.02)), Vector3(0, 0, rng.randf_range(-4, 4))))
		"reed":   # reed bundles tied upright on a mud bank
			holder.add_child(box(Vector3(l + 0.1, 0.12, thick + 0.2), mats.get_mat("mud"), Vector3(0, 0.06, 0)))
			var reed := mats.get_mat("thatch")
			var n := maxi(2, int(l / 0.1))
			for k in n:
				var x := -l / 2 + (k + 0.5) * l / n
				holder.add_child(cyl(0.04, 0.055, h - 0.1, reed, Vector3(x, 0.1 + (h - 0.1) / 2, 0), Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-4, 4)), 7))
			for y in [0.35, 0.75]:
				holder.add_child(box(Vector3(l, 0.035, thick * 0.5), wood, Vector3(0, h * y, 0)))
		"mound":   # rammed earth with a rounded top
			var mud := mats.get_mat("mud")
			holder.add_child(box(Vector3(l, h - thick / 2, thick + 0.1), mud, Vector3(0, (h - thick / 2) / 2, 0)))
			holder.add_child(cyl(thick / 2 + 0.05, thick / 2 + 0.05, l, mud, Vector3(0, h - thick / 2, 0), Vector3(0, 0, 90), 10))


## The culture's great hall or keep, centred on `at`: w wide (x), d deep (z), h to its eaves or
## battlements, its door on the front (+z). Returns its top.
func _keep(body: Node3D, arch: String, at: Vector3, w: float, d: float, h: float, team: Color) -> float:
	var holder := Node3D.new()
	holder.position = at
	body.add_child(holder)
	match arch:
		"stone":   # a square keep: plinth, battlements, corner turrets, slits, a hung team banner
			var stone := mats.get_mat("stone")
			holder.add_child(box(Vector3(w + 0.12, 0.14, d + 0.12), stone, Vector3(0, 0.07, 0)))
			holder.add_child(box(Vector3(w, h, d), stone, Vector3(0, h / 2, 0)))
			holder.add_child(box(Vector3(w + 0.08, 0.08, d + 0.08), stone, Vector3(0, h + 0.04, 0)))
			for side in 4:
				var along := w if side % 2 == 0 else d
				var n := maxi(2, int(along / 0.24))
				for k in n:
					var t := -along / 2 + (k + 0.5) * along / n
					var p := Vector3(t, h + 0.14, d / 2) if side == 0 else Vector3(w / 2, h + 0.14, t) if side == 1 else Vector3(t, h + 0.14, -d / 2) if side == 2 else Vector3(-w / 2, h + 0.14, t)
					holder.add_child(box(Vector3(0.11 if side % 2 == 0 else 0.09, 0.12, 0.09 if side % 2 == 0 else 0.11), stone, p))
			for x in [-1, 1]:
				for z in [-1, 1]:
					holder.add_child(cyl(0.13, 0.13, h + 0.35, stone, Vector3(x * w / 2, (h + 0.35) / 2, z * d / 2), Vector3.ZERO, 12))
					holder.add_child(cyl(0.0, 0.17, 0.3, mats.get_mat("terracotta"), Vector3(x * w / 2, h + 0.5, z * d / 2), Vector3.ZERO, 12))
			for x in [-w * 0.25, w * 0.25]:
				_slit(holder, Vector3(x, h * 0.7, d / 2 + 0.01), 0.0)
			_slit(holder, Vector3(w / 2 + 0.01, h * 0.6, 0), 90.0)
			holder.add_child(box(Vector3(0.36, 0.5, 0.04), Materials.flat(Color("#3a2416"), 0.9), Vector3(0, 0.39, d / 2 + 0.02)))   # the door
			holder.add_child(box(Vector3(0.2, 0.42, 0.02), cloth(team), Vector3(w * 0.3, h * 0.55, d / 2 + 0.02)))   # a banner hung on the face
			return at.y + h + 0.65
		"tent":   # a great felt tent
			return at.y + _yurt(holder, Vector3.ZERO, minf(w, d) / 2 + 0.15, h * 0.55, team)
		"reed":   # a big reed dome on its deck, a second dome stacked on it
			var deck := _stilt_deck(holder, Vector3.ZERO, w + 0.2, d + 0.2)
			var r := minf(w, d) / 2
			var top := _reed_dome(holder, Vector3(0, deck, 0), r, team)
			holder.add_child(cyl(r * 0.36, r * 0.44, 0.22, mats.get_mat("weave"), Vector3(0, top - 0.06, 0), Vector3.ZERO, 20))
			holder.add_child(dome(r * 0.44, mats.get_mat("thatch"), Vector3(0, top + 0.05, 0), Vector3(1.0, 1.1, 1.0)))
			return at.y + top + r * 0.5
		"mound":   # a great earth mound, a crown on it, a round door hung with the team's cloth
			var mud := mats.get_mat("mud")
			var r := minf(w, d) / 2
			holder.add_child(dome(r, mud, Vector3.ZERO, Vector3(w / (2 * r), h / r, d / (2 * r))))
			holder.add_child(dome(r * 0.45, mud, Vector3(0, h * 0.85, 0), Vector3(1.0, 1.0, 1.0)))
			_burrow_door(holder, Vector3(0, h * 0.25, d / 2 - 0.05), r * 0.22, 0.0, team)
			return at.y + h * 0.85 + r * 0.45
	# The hall kinds: mud and thatch, tin and brick (their walls, frame and roof from KIT).
	var base := _hall(holder, arch, w, d, h)
	var rise := _roof(holder, arch, Vector3(0, base + h, 0), w, d)
	holder.add_child(box(Vector3(0.36, 0.5, 0.04), Materials.flat(Color("#2a1e14"), 0.9), Vector3(0, base + 0.25, d / 2 + 0.02)))
	holder.add_child(box(Vector3(0.42, 0.07, 0.06), cloth(team), Vector3(0, base + 0.53, d / 2 + 0.03)))   # a team cloth over the door
	return at.y + base + h + rise


## A standard on a pole at `at`, `tall` high: the team pennant, waved in 2D (a live banner).
func _standard(body: Node3D, at: Vector3, tall: float, team: Color) -> Array:
	var wood := mats.get_mat("wood")
	body.add_child(cyl(0.025, 0.03, tall, wood, at + Vector3(0, tall / 2, 0), Vector3.ZERO, 8))
	var banner := Node3D.new()
	var flag_top := at + Vector3(0.03, tall - 0.08, 0)
	banner.add_child(box(Vector3(0.46, 0.04, 0.03), wood, flag_top + Vector3(0.23, 0, 0)))
	banner.add_child(slab_tri(Vector2(0, 0), Vector2(0.56, -0.2), Vector2(0, -0.44), 0.02, cloth(team)))
	banner.get_child(banner.get_child_count() - 1).position = flag_top
	return [banner, flag_top]


## A castle (4 x 4 tiles) in one of three layouts:
##   curtain: a square of curtain wall, a tower at each corner, a gate in the front, the keep inside;
##   motte: the keep up on an earth mound at the back, a lower wall round a yard at its foot;
##   great_tower: one huge tower beside a hall, a short wall round a small yard.
func _castle_look(name: String, arch: String, team: Color) -> Dictionary:
	rng.seed = 400 + CASTLE_LOOKS.find(name)
	var body := Node3D.new()
	var wood := mats.get_mat("wood")
	var top := 0.0
	var flag := []
	var c := 1.55   # the corner towers' centres
	match name:
		"curtain":
			var tr := 0.34
			var th := 1.25
			for x in [-1, 1]:
				for z in [-1, 1]:
					_fort_tower(body, arch, Vector3(x * c, 0, z * c), tr, th + (0.15 if z < 0 else 0.0))
			var wh := 0.82
			_fort_wall(body, arch, Vector3(-c, 0, -c), Vector3(c, 0, -c), wh)
			_fort_wall(body, arch, Vector3(-c, 0, -c), Vector3(-c, 0, c), wh)
			_fort_wall(body, arch, Vector3(c, 0, -c), Vector3(c, 0, c), wh)
			_fort_wall(body, arch, Vector3(-c, 0, c), Vector3(-0.42, 0, c), wh)   # the front, either side of the gate
			_fort_wall(body, arch, Vector3(0.42, 0, c), Vector3(c, 0, c), wh)
			_gate(body, arch, Vector3(0, 0, c), wh, team)
			top = _keep(body, arch, Vector3(0, 0, -0.35), 1.45, 1.15, 1.45, team)
			flag = _standard(body, Vector3(0.3, 1.53, -0.35), 0.9, team) if arch == "stone" else _standard(body, Vector3(-0.95, 0, -0.95), top + 0.4, team)
		"motte":
			var mx := Vector3(-0.35, 0, -0.45)
			var mr := 1.25
			var mh := 0.55
			body.add_child(dome(mr, mats.get_mat("mud"), mx, Vector3(1.0, mh / mr, 1.0)))
			_grass_tufts(body, mx + Vector3(0, mh * 0.6, 0.5), 0.45, 8)
			top = _keep(body, arch, mx + Vector3(0, mh - 0.1, 0), 1.2, 1.05, 1.4, team)
			for k in 5:   # steps up the mound's front
				body.add_child(box(Vector3(0.36, 0.06, 0.16), wood, mx + Vector3(0.45, mh * (k + 0.5) / 5.0, mr * 0.95 - k * 0.14), Vector3(0, 25, 0)))
			var wh := 0.62
			var fz := 1.6
			_fort_tower(body, arch, Vector3(-c, 0, fz), 0.3, 1.0)
			_fort_tower(body, arch, Vector3(c, 0, fz), 0.3, 1.0)
			_fort_tower(body, arch, Vector3(c, 0, -c), 0.28, 0.9)
			_fort_wall(body, arch, Vector3(-c, 0, fz), Vector3(-0.42, 0, fz), wh)
			_fort_wall(body, arch, Vector3(0.42, 0, fz), Vector3(c, 0, fz), wh)
			_fort_wall(body, arch, Vector3(c, 0, -c), Vector3(c, 0, fz), wh)
			_fort_wall(body, arch, Vector3(-c, 0, fz), Vector3(-c, 0, 0.35), wh)
			_fort_wall(body, arch, Vector3(-0.9, 0, -c), Vector3(c, 0, -c), wh)
			_gate(body, arch, Vector3(0, 0, fz), wh, team)
			crate(Vector3(0.95, 0, 0.75), body, 20.0)
			barrel(Vector3(0.75, 0, 1.05), body)
			flag = _standard(body, mx + Vector3(0.4, mh, -0.4), top - mh + 0.5, team)
		"great_tower":
			var tx := Vector3(-0.55, 0, -0.55)
			top = _fort_tower(body, arch, tx, 0.78, 2.5)
			_keep(body, arch, Vector3(0.75, 0, -0.65), 1.2, 1.0, 0.8, team)
			var wh := 0.6
			_fort_tower(body, arch, Vector3(c, 0, c), 0.26, 0.95)
			_fort_tower(body, arch, Vector3(-c, 0, c), 0.26, 0.95)
			_fort_wall(body, arch, Vector3(-c, 0, c), Vector3(-0.4, 0, c), wh)
			_fort_wall(body, arch, Vector3(0.4, 0, c), Vector3(c, 0, c), wh)
			_fort_wall(body, arch, Vector3(c, 0, c), Vector3(c, 0, 0.0), wh)
			_fort_wall(body, arch, Vector3(-c, 0, c), Vector3(-c, 0, 0.3), wh)
			_gate(body, arch, Vector3(0, 0, c), wh, team)
			woodpile(Vector3(0.6, 0, 0.55), body)
			flag = _standard(body, tx + Vector3(0.0, top - 0.05, 0.0), 0.8, team)
	return {"body": body, "anchor": Vector3.ZERO, "banner": flag[0], "banner_pivot": flag[1], "lights": [], "team": team,
		"lantern": Vector3(0.0, 0.9, 1.7), "smoke": Vector3(0.0, top, -0.35)}


## A gateway in a front wall (+z face) at `at`: two posts or piers, a lintel or arch, the doors.
func _gate(body: Node3D, arch: String, at: Vector3, h: float, team: Color) -> void:
	var post: Material = mats.get_mat({"stone": "stone", "junk": "brick", "mound": "mud", "reed": "wood", "tent": "wood", "thatch": "wood"}[arch])
	var gh := h + 0.3
	for x in [-0.42, 0.42]:
		body.add_child(box(Vector3(0.2, gh, 0.32), post, at + Vector3(x, gh / 2, 0)))
	body.add_child(box(Vector3(1.04, 0.2, 0.34), post, at + Vector3(0, gh - 0.1, 0)))
	if arch == "stone":
		for x in [-0.42, 0.0, 0.42]:
			body.add_child(box(Vector3(0.12, 0.12, 0.1), post, at + Vector3(x, gh + 0.06, 0.12)))
	body.add_child(box(Vector3(0.62, gh - 0.22, 0.05), Materials.flat(Color("#3a2416"), 0.9), at + Vector3(0, (gh - 0.22) / 2, 0.02)))   # the doors, shut
	body.add_child(box(Vector3(0.6, 0.04, 0.06), mats.get_mat("wood"), at + Vector3(0, (gh - 0.22) * 0.3, 0.05)))
	body.add_child(box(Vector3(0.6, 0.04, 0.06), mats.get_mat("wood"), at + Vector3(0, (gh - 0.22) * 0.75, 0.05)))
	body.add_child(box(Vector3(0.16, 0.24, 0.02), cloth(team), at + Vector3(-0.42, gh * 0.6, 0.17)))   # a small team cloth on a pier


## A University (3 x 3 tiles) in one of three looks:
##   observatory: a hall and a round tower crowned with a dome, a sundial in the yard;
##   cloister: a hall behind a yard ringed by a covered walk, a tree in it, a bell tower;
##   builders: a hall, a lifting frame hoisting a cut block, stacked stone and a model arch.
func _university_look(name: String, arch: String, team: Color) -> Dictionary:
	rng.seed = 300 + UNIVERSITY_LOOKS.find(name)
	var body := Node3D.new()
	var wood := mats.get_mat("wood")
	var k: Dictionary = KIT[arch]
	var stone_like: Material = mats.get_mat({"stone": "stone", "junk": "brick", "mound": "mud", "reed": "mud", "tent": "wood", "thatch": "stone"}[arch])
	var top := 0.0
	var lights := []
	match name:
		"observatory":
			top = _uni_hall(body, arch, Vector3(-0.35, 0, 0.05), 1.8, 1.1, 0.8, team)
			var at := Vector3(0.8, 0, -0.85)
			var r := 0.42
			var th := 2.0
			var scope_from := at + Vector3(0, th + r * 0.45, r * 0.45)
			if arch == "mound":   # a spire with a glass poking out near its top
				top = maxf(top, _fort_tower(body, arch, at, r, th))
				scope_from = at + Vector3(0, th * 0.8, r * 0.35)
			elif arch == "reed":   # the woven tower, under its own reed dome
				top = maxf(top, _fort_tower(body, arch, at, r, th))
			else:
				_plain_tower(body, arch, at, r, th)
				var dome_mat: Material = {"stone": Materials.flat(Color("#6a9a86"), 0.5, 0.4), "junk": mats.get_mat("tin"),
					"tent": mats.get_mat("felt"), "thatch": mats.get_mat("thatch")}[arch]
				body.add_child(dome(r + 0.06, dome_mat, at + Vector3(0, th, 0)))
				body.add_child(box(Vector3(0.1, r * 0.8, 0.03), Materials.flat(Color("#1a140e"), 1.0), at + Vector3(0, th + r * 0.35, r * 0.62), Vector3(-35, 0, 0)))   # the slot in the dome
				top = maxf(top, th + r + 0.06)
			body.add_child(beam(scope_from, scope_from + Vector3(0.12, 0.32, 0.3), 0.04, Materials.flat(Color("#b07a36"), 0.4, 0.7), 10))   # the brass glass, out at the sky
			# A sundial on a plinth, and a bench of books.
			body.add_child(cyl(0.13, 0.15, 0.3, stone_like, Vector3(0.95, 0.15, 0.85), Vector3.ZERO, 12))
			body.add_child(cyl(0.18, 0.18, 0.03, Materials.flat(Color("#c8b48a"), 0.6), Vector3(0.95, 0.315, 0.85), Vector3.ZERO, 16))
			body.add_child(slab_tri(Vector2(0, 0), Vector2(0.14, 0), Vector2(0, 0.12), 0.012, Materials.flat(Color("#b07a36"), 0.4, 0.7)))
			body.get_child(body.get_child_count() - 1).position = Vector3(0.93, 0.33, 0.85)
			_books(body, Vector3(-0.4, 0, 1.05))
			lights.append(at + Vector3(r * 0.9, th * 0.6, r * 0.4))
		"cloister":
			top = _uni_hall(body, arch, Vector3(0, 0, -0.85), 2.4, 0.8, 0.8, team)
			for side in [-1, 1]:   # the covered walks down the sides, open to the yard
				_walk(body, arch, Vector3(side * 1.1, 0, 0.25), 0.5, 1.5, true)
			_walk(body, arch, Vector3(0, 0, 1.15), 1.7, 0.42, false)
			body.add_child(cyl(0.05, 0.06, 0.4, wood, Vector3(0.15, 0.2, 0.25), Vector3.ZERO, 8))   # a tree in the yard
			body.add_child(ball(0.32, Materials.flat(Color("#4e7a30"), 0.9), Vector3(0.15, 0.62, 0.25), Vector3(1.0, 0.9, 1.0)))
			body.add_child(ball(0.2, Materials.flat(Color("#5e8a38"), 0.9), Vector3(0.0, 0.75, 0.35)))
			body.add_child(cyl(0.12, 0.14, 0.12, stone_like, Vector3(-0.35, 0.06, 0.3), Vector3.ZERO, 12))   # a well
			# The bell tower, at the back corner: square, an open belfry, the bell hung in it.
			var bt := Vector3(-1.05, 0, -1.05)
			var bh := 1.55
			body.add_child(box(Vector3(0.5, bh, 0.5), mats.get_mat(k.wall), bt + Vector3(0, bh / 2, 0)))
			for x in [-1, 1]:
				for z in [-1, 1]:
					body.add_child(box(Vector3(0.07, 0.42, 0.07), mats.get_mat(k.frame), bt + Vector3(x * 0.22, bh + 0.21, z * 0.22)))
			body.add_child(cyl(0.05, 0.1, 0.14, Materials.flat(Color("#b07a36"), 0.4, 0.7), bt + Vector3(0, bh + 0.22, 0), Vector3.ZERO, 12))
			var roof_mat: Material = mats.get_mat("terracotta" if k.roof == "tiles" else k.roof)
			body.add_child(cyl(0.0, 0.45, 0.4, roof_mat, bt + Vector3(0, bh + 0.62, 0), Vector3(0, 45, 0), 4))
			top = maxf(top, bh + 0.82)
		"builders":
			top = _uni_hall(body, arch, Vector3(-0.5, 0, -0.6), 1.6, 1.1, 0.85, team)
			# The lifting frame: two legs, a beam, a rope, a cut block hanging; a drum to wind it.
			var f := Vector3(0.8, 0, 0.15)
			for z in [-0.35, 0.35]:
				body.add_child(beam(f + Vector3(-0.45, 0, z), f + Vector3(0, 1.75, z * 0.3), 0.055, wood))
				body.add_child(beam(f + Vector3(0.45, 0, z), f + Vector3(0, 1.75, z * 0.3), 0.055, wood))
			body.add_child(beam(f + Vector3(0, 1.72, -0.15), f + Vector3(0.0, 1.72, 0.15), 0.04, wood))
			body.add_child(beam(f + Vector3(0, 1.72, 0.0), f + Vector3(0.0, 0.84, 0.0), 0.015, Materials.flat(Color("#8a6a3c"), 0.9), 4))
			body.add_child(box(Vector3(0.42, 0.28, 0.3), stone_like, f + Vector3(0, 0.7, 0)))
			body.add_child(cyl(0.1, 0.1, 0.5, wood, f + Vector3(-0.3, 0.3, 0), Vector3(90, 0, 0), 10))   # the winding drum
			# Cut blocks stacked, and a half-built arch to learn on.
			for p in [Vector3(-0.2, 0.11, 0.85), Vector3(0.15, 0.11, 0.9), Vector3(-0.03, 0.33, 0.87)]:
				body.add_child(box(Vector3(0.32, 0.22, 0.24), stone_like, p, Vector3(0, rng.randf_range(-8, 8), 0)))
			for x in [-1.05, -0.55]:
				body.add_child(box(Vector3(0.16, 0.5, 0.18), stone_like, Vector3(x, 0.25, 0.7)))
			body.add_child(box(Vector3(0.66, 0.14, 0.18), stone_like, Vector3(-0.8, 0.57, 0.7)))
			body.add_child(box(Vector3(0.3, 0.03, 0.22), Materials.flat(Color("#e8dcc0"), 0.9), Vector3(0.45, 0.42, 1.05), Vector3(0, 10, 0)))   # a plan on a trestle
			for x in [0.33, 0.57]:
				body.add_child(beam(Vector3(x, 0, 0.98), Vector3(x, 0.4, 1.06), 0.015, wood, 4))
				body.add_child(beam(Vector3(x, 0, 1.14), Vector3(x, 0.4, 1.06), 0.015, wood, 4))
			top = maxf(top, 1.75)
	return {"body": body, "anchor": Vector3.ZERO, "lights": lights, "team": team, "lantern": Vector3(0.0, 0.5, 0.9),
		"smoke": Vector3(-0.3, top, -0.45)}


## A University's hall: the culture's hall and roof, or its dome on stilts or mound (reed, mound),
## centred on `at`, with a team cloth over the door. Returns its top.
func _uni_hall(body: Node3D, arch: String, at: Vector3, w: float, d: float, h: float, team: Color) -> float:
	if arch in ["reed", "mound", "tent"]:
		return _keep(body, arch, at, w, d, h, team)
	var holder := Node3D.new()
	holder.position = at
	body.add_child(holder)
	var base := _hall(holder, arch, w, d, h)
	var rise := _roof(holder, arch, Vector3(0, base + h, 0), w, d)
	holder.add_child(box(Vector3(0.36, 0.5, 0.04), Materials.flat(Color("#2a1e14"), 0.9), Vector3(-w * 0.2, base + 0.25, d / 2 + 0.02)))
	holder.add_child(box(Vector3(0.42, 0.07, 0.06), cloth(team), Vector3(-w * 0.2, base + 0.53, d / 2 + 0.03)))
	for x in [w * 0.1, w * 0.32]:   # tall windows: a place of reading
		holder.add_child(box(Vector3(0.14, 0.32, 0.03), glow(Color("#ffcf6a"), 1.2), Vector3(x, base + h * 0.55, d / 2 + 0.01)))
	return at.y + base + h + rise


## A plain round or square tower of the culture's walls (not a fortification), h to its top.
func _plain_tower(body: Node3D, arch: String, at: Vector3, r: float, h: float) -> float:
	var k: Dictionary = KIT[arch]
	if arch == "stone":
		body.add_child(cyl(r, r * 1.05, h, mats.get_mat("plaster"), at + Vector3(0, h / 2, 0), Vector3.ZERO, 20))
		body.add_child(ring(r, r * 1.06, mats.get_mat("stone"), at + Vector3(0, h - 0.05, 0)))
		body.add_child(ring(r * 1.02, r * 1.08, mats.get_mat("stone"), at + Vector3(0, 0.06, 0)))
	elif arch == "junk":
		body.add_child(cyl(r, r, h, mats.get_mat("tin"), at + Vector3(0, h / 2, 0), Vector3.ZERO, 20))
		for y in [0.3, 0.75]:
			body.add_child(ring(r - 0.01, r + 0.03, Materials.flat(Color("#9a9c96"), 0.5, 0.5), at + Vector3(0, h * y, 0)))
	elif arch == "tent":
		body.add_child(cyl(r, r * 1.1, h, mats.get_mat("felt"), at + Vector3(0, h / 2, 0), Vector3.ZERO, 20))
		for y in [0.3, 0.7]:
			body.add_child(ring(r * 1.02, r * 1.08, Materials.flat(Color("#8a6a3c"), 0.9), at + Vector3(0, h * y, 0)))
	else:
		body.add_child(cyl(r, r * 1.05, h, mats.get_mat(k.wall), at + Vector3(0, h / 2, 0), Vector3.ZERO, 20))
		for a in [0.0, 120.0, 240.0]:
			var t := deg_to_rad(a)
			body.add_child(box(Vector3(0.07, h, 0.07), mats.get_mat(k.frame), at + Vector3(sin(t) * r, h / 2, cos(t) * r)))
	body.add_child(box(Vector3(0.1, 0.24, 0.03), glow(Color("#ffcf6a"), 1.2), at + Vector3(0, h * 0.6, r + 0.005)))
	return at.y + h


## A covered walk: a row of posts under a lean-to roof of the culture's roofing, w x d.
func _walk(body: Node3D, arch: String, at: Vector3, w: float, d: float, along_z: bool) -> void:
	var k: Dictionary = KIT[arch]
	var post: Material = mats.get_mat("stone" if arch == "stone" else k.frame)
	var h := 0.5
	var n := maxi(2, int((d if along_z else w) / 0.38) + 1)
	for i in n:
		var t := -0.5 + float(i) / (n - 1)
		var p := at + (Vector3(0, 0, t * d) if along_z else Vector3(t * w, 0, 0))
		if arch == "stone":
			body.add_child(cyl(0.04, 0.05, h, post, p + Vector3(0, h / 2, 0), Vector3.ZERO, 10))
		else:
			body.add_child(box(Vector3(0.06, h, 0.06), post, p + Vector3(0, h / 2, 0)))
	var roof_mat: Material = mats.get_mat("terracotta" if k.roof == "tiles" else k.roof)
	body.add_child(box(Vector3(w + 0.1, 0.05, d + 0.1), roof_mat, at + Vector3(0, h + 0.06, 0), Vector3(0, 0, 0)))


## A stack of books and a scroll on a little bench.
func _books(body: Node3D, at: Vector3) -> void:
	var wood := mats.get_mat("wood")
	body.add_child(box(Vector3(0.5, 0.04, 0.18), wood, at + Vector3(0, 0.2, 0)))
	for x in [-0.2, 0.2]:
		body.add_child(box(Vector3(0.04, 0.2, 0.14), wood, at + Vector3(x, 0.1, 0)))
	var covers := [Color("#7a2a22"), Color("#2a4a6a"), Color("#5a6a2a")]
	for i in 3:
		body.add_child(box(Vector3(0.16, 0.04, 0.12), Materials.flat(covers[i], 0.8), at + Vector3(-0.08, 0.24 + i * 0.04, 0), Vector3(0, i * 12, 0)))
	body.add_child(cyl(0.03, 0.03, 0.18, Materials.flat(Color("#e8dcc0"), 0.9), at + Vector3(0.14, 0.25, 0), Vector3(0, 30, 90), 8))


# ------------------------------------------------------------------ walls and gates
# A wall tile is a post in the tile's middle plus an arm out to each wall neighbour, the eight
# ways round (LINKS: sim dx, dy). Each piece bakes on its own, anchored on the tile's centre, and
# the view lays the arms a tile needs under and over its post (ArtKit.wall_look), so a line
# reads as one wall whichever way it runs, diagonals included. Arms end on the tile's edge (or
# corner) where the neighbour's arm takes over; the stake or merlon on that edge belongs to the
# arm pointing down the screen (OWNS), so it isn't stood there twice.
# Gates are `length` tiles long along x (sim x) and baked a quarter turn for lines along z; on a
# diagonal (ArtKit: an eighth turn) they run corner to corner across their square, `gate_span` long,
# so their ends meet the diagonal wall arms on the cells' corners.

const LINKS := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]

## What a culture builds its stone wall of: dressed stone, brick and scrap for the junk-rats,
## rammed earth and stones for reed and mound.
const WALL_STONE := {"stone": "stone", "thatch": "stone", "tent": "stone", "junk": "brick", "reed": "mud", "mound": "mud"}


## Does the arm in direction k own the stake or merlon on its far edge? (Down the screen, or
## to the right along it.)
static func owns(k: int) -> bool:
	var d: Vector2i = LINKS[k]
	return d.x + d.y > 0 or (d.x + d.y == 0 and d.x > 0)


## An arm's holder, turned so its +x runs from the tile's centre towards neighbour k; and its length.
func _arm(k: int) -> Array:
	var d: Vector2i = LINKS[k]
	var holder := Node3D.new()
	holder.transform.basis = Basis(Vector3.UP, atan2(-float(d.y), float(d.x)))
	return [holder, 0.5 if d.x == 0 or d.y == 0 else 0.70710678]


## A wall spec: the post as the body, the eight arms, and a short straight run for its picture.
func _wall_spec(post: Callable, arm: Callable, team: Color) -> Dictionary:
	var arms := []
	for k in LINKS.size():
		arms.append(arm.call(k))
	var icon := Node3D.new()
	icon.add_child(post.call())
	icon.add_child(arm.call(0))
	icon.add_child(arm.call(4))
	return {"body": post.call(), "arms": arms, "icon": icon, "anchor": Vector3.ZERO, "lights": [], "team": team}


## Stone Wall: a squat pier with a merlon on each corner, and arms of crenellated block wall
## in the culture's stone.
func _wall(arch: String, team: Color) -> Dictionary:
	return _wall_spec(func(): return _stone_post(arch), func(k): return _stone_arm(arch, k), team)


func _stone_post(arch: String) -> Node3D:
	var body := Node3D.new()
	var m: Material = mats.get_mat(WALL_STONE[arch])
	body.add_child(box(Vector3(0.62, 0.8, 0.62), m, Vector3(0, 0.4, 0)))
	for x in [-1, 1]:
		for z in [-1, 1]:
			body.add_child(box(Vector3(0.17, 0.16, 0.17), m, Vector3(x * 0.22, 0.88, z * 0.22)))
	return body


func _stone_arm(arch: String, k: int) -> Node3D:
	var a: Array = _arm(k)
	var body: Node3D = a[0]
	var l: float = a[1]
	var m: Material = mats.get_mat(WALL_STONE[arch])
	body.add_child(box(Vector3(l, 0.72, 0.54), m, Vector3(l / 2, 0.36, 0)))
	var merlons := [l] if owns(k) else []
	if l > 0.6:
		merlons.append(l * 0.55)   # a diagonal is longer: one more between
	for t in merlons:
		for z in [-0.18, 0.18]:
			body.add_child(box(Vector3(0.17, 0.16, 0.17), m, Vector3(t, 0.8, z)))
	rng.seed = 93 + k
	if arch == "junk" and k == 5:   # a tin patch nailed over the brick (one arm only: on every tile it reads as windows)
		body.add_child(box(Vector3(0.26, 0.24, 0.02), mats.get_mat("tin"), Vector3(l * 0.5, 0.4, 0.28), Vector3(0, 0, 6)))
	elif arch in ["reed", "mound"]:   # field stones pressed into the earth
		for n in 2:
			var side := 1 if n == 0 else -1
			body.add_child(ball(0.07, mats.get_mat("stone"), Vector3(rng.randf_range(0.1, l - 0.1), rng.randf_range(0.12, 0.6), 0.27 * side), Vector3(1.2, 0.8, 0.6)))
	return body


## Palisade Wall: sharpened stakes and two lashed rails, with the culture's touch: a stone
## footing, tin sheets, reed bindings, felt and rope, or an earth bank.
func _palisade(arch: String, team: Color) -> Dictionary:
	return _wall_spec(func(): return _stake_post(arch), func(k): return _stake_arm(arch, k), team)


func _stake_post(arch: String) -> Node3D:
	var body := Node3D.new()
	rng.seed = 91
	_stake(body, Vector3.ZERO, 0.88, mats.get_mat("wood"), 0.095)
	_palisade_dress(body, arch, [Vector3.ZERO], 0.0)
	return body


func _stake_arm(arch: String, k: int) -> Node3D:
	var a: Array = _arm(k)
	var body: Node3D = a[0]
	var l: float = a[1]
	var wood := mats.get_mat("wood")
	rng.seed = 101 + k
	var n := 3 if l < 0.6 else 4   # stakes about a sixth of a tile apart
	# Two staggered rows of stakes: a fence with some depth, which still reads as a wall seen
	# end-on (a diagonal line straight down the screen is otherwise one thin pole).
	var spots := []
	for j in range(1, n + (1 if owns(k) else 0)):
		spots.append(Vector3(l * j / n, 0, 0.1))
	for j in n:
		spots.append(Vector3(l * (j + 0.5) / n, 0, -0.1))
	for p in spots:
		_stake(body, p, rng.randf_range(0.72, 0.86), wood)
	for y in [0.25, 0.55]:
		for z in [-0.18, 0.18]:   # rails lashed on both faces
			body.add_child(box(Vector3(l, 0.04, 0.04), wood, Vector3(l / 2, y, z)))
	_palisade_dress(body, arch, spots, l, k)
	return body


## One sharpened stake, leaning a touch.
func _stake(body: Node3D, at: Vector3, h: float, wood: Material, r := 0.08) -> void:
	var p := at + Vector3(0, h / 2, 0)
	body.add_child(cyl(r, r + 0.01, h, wood, p, Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)), 8))
	body.add_child(cyl(0.0, r, 0.13, wood, p + Vector3(0, h / 2 + 0.065, 0), Vector3.ZERO, 8))


## A culture's touch on a stretch of stake fence `l` long along x (0: the post), its stakes at
## `spots`; k varies the odd bits between arms.
func _palisade_dress(body: Node3D, arch: String, spots: Array, l: float, k := 0) -> void:
	var run := maxf(l, 0.24)
	var mid := Vector3(l / 2, 0, 0)
	match arch:
		"stone":   # a dry-stone footing the stakes are set in
			body.add_child(box(Vector3(run, 0.14, 0.46), mats.get_mat("stone"), mid + Vector3(0, 0.07, 0)))
		"junk":   # tin sheets nailed on where the stakes ran short
			# (only on a few arms: the same patch on every tile of a line reads as a row of windows)
			if l > 0.0 and k in [1, 5]:
				body.add_child(box(Vector3(0.3, 0.24, 0.02), mats.get_mat("tin"), mid + Vector3(0, 0.42, 0.2), Vector3(0, 0, 8)))
		"reed":   # every stake bound with reed at two heights
			for p in spots:
				for y in [0.3, 0.6]:
					body.add_child(cyl(0.1, 0.1, 0.06, mats.get_mat("thatch"), p + Vector3(0, y, 0), Vector3.ZERO, 8))
		"tent":   # a felt strip along the top rail, rope lashings
			if l > 0.0:
				body.add_child(box(Vector3(l, 0.08, 0.03), mats.get_mat("felt"), mid + Vector3(0, 0.6, 0.2)))
		"mound":   # an earth bank heaped against the foot
			body.add_child(box(Vector3(run, 0.2, 0.56), mats.get_mat("mud"), mid + Vector3(0, 0.08, 0)))


## Palisade Gate, three tiles long (closed in "body", open in "open"): a stout post at each end
## of the gate, where the wall arms meet it; a lintel resting on the two, exactly as long as the
## gate, with knee braces; the team cloth hung from it; two wide leaves of stakes that swing back.
const GATE_POST := 0.14    # the gate posts' centres in from the gate's ends: their outer faces flush with them
const GATE_POST_R := 0.13
const GATE_TOP := 1.16     # the lintel's underside


func _palisade_gate(arch: String, team: Color) -> Dictionary:
	return {"body": _stake_gate(arch, team, false), "open": _stake_gate(arch, team, true), "anchor": Vector3.ZERO, "lights": [], "team": team}


func _stake_gate(arch: String, team: Color, open: bool) -> Node3D:
	var body := Node3D.new()
	rng.seed = 95
	var wood := mats.get_mat("wood")
	var post := gate_span / 2.0 - GATE_POST
	var posts := [Vector3(-post, 0, 0), Vector3(post, 0, 0)]
	for p in posts:   # the gate posts, taller and thicker than the fence, propped from behind
		body.add_child(cyl(GATE_POST_R, GATE_POST_R + 0.01, GATE_TOP + 0.13, wood, p + Vector3(0, (GATE_TOP + 0.13) / 2, 0), Vector3.ZERO, 10))
		body.add_child(cyl(0.0, GATE_POST_R, 0.16, wood, p + Vector3(0, GATE_TOP + 0.21, 0), Vector3.ZERO, 10))   # its point, over the lintel
		body.add_child(beam(p + Vector3(0, 0.0, -0.42), p + Vector3(0, 0.72, -GATE_POST_R + 0.02), 0.045, wood))   # a prop leaning on it
	# The lintel: one squared beam across the post tops, as long as the gate and no longer,
	# held by a knee brace at each post.
	body.add_child(box(Vector3(2.0 * (post + GATE_POST_R), 0.13, 0.17), wood, Vector3(0, GATE_TOP + 0.065, 0)))
	for side in [-1, 1]:
		body.add_child(beam(Vector3(side * (post - GATE_POST_R + 0.02), GATE_TOP - 0.36, 0.0), Vector3(side * (post - 0.46), GATE_TOP + 0.01, 0.0), 0.035, wood))
	# The team cloth hangs from the lintel: a batten tied on under it by two cords.
	var batten := GATE_TOP - 0.08
	for x in [-0.2, 0.2]:
		body.add_child(beam(Vector3(x, GATE_TOP + 0.01, 0.07), Vector3(x, batten, 0.07), 0.012, mats.get_mat("thatch"), 4))
	body.add_child(box(Vector3(0.52, 0.04, 0.04), wood, Vector3(0, batten, 0.07)))
	body.add_child(box(Vector3(0.44, 0.32, 0.02), cloth(team), Vector3(0, batten - 0.18, 0.07)))
	var leaf_w := post - GATE_POST_R   # each leaf half the way through
	for side in [-1, 1]:
		var leaf := Node3D.new()   # hinged on its post; it swings back (away from the viewer) when open
		leaf.position = Vector3(side * leaf_w, 0, 0)
		leaf.rotation_degrees = Vector3(0, 90 * -side if open else 0, 0)
		body.add_child(leaf)
		for k in int(leaf_w / 0.12):   # stakes 0.12 apart (ten on a straight gate's leaf)
			var x: float = -side * (0.06 + k * 0.12)
			leaf.add_child(cyl(0.05, 0.055, 0.76, wood, Vector3(x, 0.4, 0), Vector3.ZERO, 6))
			leaf.add_child(cyl(0.0, 0.05, 0.1, wood, Vector3(x, 0.83, 0), Vector3.ZERO, 6))
		for y in [0.22, 0.6]:
			leaf.add_child(box(Vector3(leaf_w - 0.05, 0.05, 0.03), wood, Vector3(-side * (leaf_w / 2.0 - 0.015), y, 0.05)))
		leaf.add_child(beam(Vector3(-side * 0.05, 0.22, 0.06), Vector3(-side * (leaf_w - 0.11), 0.6, 0.06), 0.022, wood))   # a brace across
	for p in posts:   # the culture's touch at each post's foot, not in the way through
		var foot := Node3D.new()
		foot.position = p
		_palisade_dress(foot, arch, [Vector3.ZERO], 0.0)
		body.add_child(foot)
		if arch == "reed":   # the reed bindings show on the posts too
			for y in [0.3, 0.6, 0.95]:
				body.add_child(cyl(GATE_POST_R + 0.025, GATE_POST_R + 0.025, 0.06, mats.get_mat("thatch"), p + Vector3(0, y, 0), Vector3.ZERO, 8))
	return body


## Stone Gate, three tiles long (closed and open): a crenellated pier at each end in the
## culture's stone, where the wall arms meet it; between them a way through as wide as the gate
## lets its side walk (all three tiles, so nobody walks through stone), under an arch at the
## front and one at the back with the sky open between (a unit in the gateway shows, rather than
## vanishing under a roof; no floor is drawn, so the ground shows through); the team banner hung
## from the front arch, in the middle; iron-banded double doors filling the arch, which swing
## in flat against the piers.
const GATE_PIER := 0.23    # the piers' centres in from the gate's ends: their outer faces flush with them
const GATE_PIER_W := 0.46
const GATE_ARCH := 1.1    # the arches' undersides


## Wall Tower (milestone 16). PLACEHOLDER until Dominic picks a look from the concept round: a
## squat square tower of the culture's wall stone, half again the wall's height, crenellated, an
## arrow slit and a team rag; the wall's arms reach it like a gate's.
func _wall_tower(arch: String, team: Color) -> Dictionary:
	var body := Node3D.new()
	var m: Material = mats.get_mat(WALL_STONE[arch])
	var h := 1.25
	body.add_child(box(Vector3(0.86, h, 0.86), m, Vector3(0, h / 2, 0)))
	for x in [-1, 0, 1]:
		for z in [-1, 0, 1]:
			if x != 0 or z != 0:
				body.add_child(box(Vector3(0.18, 0.18, 0.18), m, Vector3(x * 0.34, h + 0.09, z * 0.34)))
	for side in [Vector3(0, 0.78, 0.44), Vector3(0.44, 0.78, 0)]:
		body.add_child(box(Vector3(0.07 if side.z != 0.0 else 0.03, 0.24, 0.03 if side.z != 0.0 else 0.07), Materials.flat(Color("#1e1a16"), 1.0), side))   # arrow slits
	body.add_child(box(Vector3(0.24, 0.3, 0.02), cloth(team), Vector3(-0.18, h - 0.22, 0.44)))   # a team rag hung over the parapet
	return {"body": body, "anchor": Vector3.ZERO, "lights": [], "team": team}


## Siege Ladder (milestone 16). PLACEHOLDER until Dominic picks a look: two rails and rungs
## standing almost upright (the sim doesn't say which way its wall is yet), a team rag tied on.
func _ladder(arch: String, team: Color) -> Dictionary:
	var body := Node3D.new()
	var wood := mats.get_mat("wood")
	var h := 1.05
	for z in [-0.14, 0.14]:
		body.add_child(box(Vector3(0.05, h, 0.05), wood, Vector3(-0.08, h / 2, z), Vector3(0, 0, -10)))
	for k in 7:
		var y := 0.1 + k * 0.14
		body.add_child(box(Vector3(0.03, 0.03, 0.3), wood, Vector3(-0.08 - y * 0.17, y, 0)))
	body.add_child(box(Vector3(0.02, 0.14, 0.1), cloth(team), Vector3(-0.2, 0.86, 0.17)))
	return {"body": body, "anchor": Vector3.ZERO, "lights": [], "team": team}


func _stone_gate(arch: String, team: Color) -> Dictionary:
	return {"body": _gatehouse(arch, team, false), "open": _gatehouse(arch, team, true), "anchor": Vector3.ZERO, "lights": [], "team": team}


func _gatehouse(arch: String, team: Color, open: bool) -> Node3D:
	var body := Node3D.new()
	var m: Material = mats.get_mat(WALL_STONE[arch])
	var wood := mats.get_mat("wood")
	var iron := Materials.flat(Color("#4a4c50"), 0.5, 0.7)
	var top := GATE_ARCH + 0.28
	var pier := gate_span / 2.0 - GATE_PIER
	for x in [-pier, pier]:
		body.add_child(box(Vector3(GATE_PIER_W, top + 0.04, 0.98), m, Vector3(x, (top + 0.04) / 2, 0)))   # a pier, as deep as the gate
		for z in [-0.34, 0.0, 0.34]:
			body.add_child(box(Vector3(0.18, 0.18, 0.18), m, Vector3(x, top + 0.13, z)))
		body.add_child(box(Vector3(0.07, 0.22, 0.03), Materials.flat(Color("#1e1a16"), 1.0), Vector3(x, 0.7, 0.5)))   # an arrow slit
	var inner := pier - GATE_PIER_W / 2   # the piers' inner faces
	for z in [-0.37, 0.37]:   # the arches, front and back, open to the sky between
		body.add_child(box(Vector3(2.0 * inner, 0.28, 0.24), m, Vector3(0, GATE_ARCH + 0.14, z)))
		body.add_child(box(Vector3(2.0 * inner, 0.05, 0.2), mats.get_mat("stone"), Vector3(0, GATE_ARCH + 0.025, z)))   # the arch stones' soffit
	for x in [-0.45, 0.45]:
		body.add_child(box(Vector3(0.18, 0.16, 0.18), m, Vector3(x, top + 0.08, 0.37)))
	# The banner: a rod across the front arch, the team cloth hanging from it over the arch's face.
	body.add_child(box(Vector3(0.46, 0.03, 0.03), wood, Vector3(0, top - 0.03, 0.51)))
	body.add_child(box(Vector3(0.36, 0.3, 0.02), cloth(team), Vector3(0, top - 0.19, 0.51)))
	var leaf_w := inner   # each leaf half the way through
	for side in [-1, 1]:
		var leaf := Node3D.new()
		leaf.position = Vector3(side * inner, 0, 0.28)   # hinged on the pier just behind the front arch; they swing in
		leaf.rotation_degrees = Vector3(0, 90 * -side if open else 0, 0)
		body.add_child(leaf)
		leaf.add_child(box(Vector3(leaf_w, GATE_ARCH - 0.02, 0.07), wood, Vector3(-side * leaf_w / 2, (GATE_ARCH - 0.02) / 2, -0.04)))
		for y in [0.2, 0.7]:
			leaf.add_child(box(Vector3(leaf_w, 0.05, 0.02), iron, Vector3(-side * leaf_w / 2, y, 0.005)))
		leaf.add_child(ball(0.035, iron, Vector3(-side * (leaf_w - 0.14), 0.46, 0.01)))   # the ring pull
	return body
