extends RefCounted
## Landscape props for the pixel bake, in world units (1 = a tile): reed clumps,
## bug bushes and lily pads, built from authored texture cards (assets/art/textures/)
## on simple 3D bodies, like the unit parts.

const UnitModels := preload("res://scenes/art_pixel/unit_models.gd")

var um := UnitModels.new()
var rng := RandomNumberGenerator.new()


## A clump of reeds: a dark wet base, arching ribbon leaves of mixed greens and
## heights, and a few stems topped with velvet cattails. `size` scales the clump.
func reed_clump(seed_value: int, size := 1.0) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	var tints := [Color(1, 1, 1), Color(0.82, 0.95, 0.78), Color(1.08, 1.02, 0.82), Color(0.9, 0.9, 0.7)]
	for k in int(30 * size):
		var base := Vector3(rng.randf_range(-0.34, 0.34), 0, rng.randf_range(-0.34, 0.34)) * size
		var h := rng.randf_range(0.45, 0.95) * size
		var yaw := rng.randf() * TAU
		var lean := rng.randf_range(0.1, 0.55)
		var out := Vector3(cos(yaw), 0, sin(yaw))
		var up := (Vector3.UP + out * lean).normalized()
		var facing := out.cross(up).normalized()
		n.add_child(um.decal("reed_leaf", 0.075 * size, h, base + up * h * 0.5, facing, true, up, tints[k % tints.size()]))
	var stem := um.plain(Color("#7e8e3a"))
	var velvet := um.plain(Color("#5e3a1e"))
	for k in int(6 * size):
		var base := Vector3(rng.randf_range(-0.22, 0.22), 0, rng.randf_range(-0.22, 0.22)) * size
		var h := rng.randf_range(0.75, 1.1) * size
		var top := base + Vector3(rng.randf_range(-0.06, 0.06), h, rng.randf_range(-0.06, 0.06))
		n.add_child(um.rod(base, top, 0.014, 0.011, stem, false))
		n.add_child(um.blob(Vector3(0.034, 0.1, 0.034), velvet, top - Vector3(0, 0.07, 0)))
		n.add_child(um.rod(top + Vector3(0, 0.02, 0), top + Vector3(0, 0.12, 0), 0.006, 0.004, stem, false))
	return n


## A bug bush, drawn realistically like the genre's static props: a dense shrub of
## a few hundred small leaves over irregular lobes, dark inside and lit on top, its
## outline broken by single leaves, dotted all over with small red berries.
## Size varies with the seed.
func bug_bush(seed_value: int) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	var size := rng.randf_range(0.85, 1.15)
	var lobes := []
	for k in 6:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 0.2) * size
		var r := rng.randf_range(0.14, 0.2) * size
		lobes.append([Vector3(cos(a) * d, rng.randf_range(0.14, 0.3) * size, sin(a) * d), Vector3(r, r * 0.8, r)])
	for l in lobes:   # a dark core, so you never see through the leaves
		n.add_child(um.blob(l[1] * 0.8, um.plain(Color("#1c2c12")), l[0]))
	var top := 0.0
	for l in lobes:
		top = maxf(top, l[0].y + l[1].y)
	for k in 340:
		var l: Array = lobes[k % lobes.size()]
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1.0), rng.randf_range(-1, 1)).normalized()
		var depth := rng.randf_range(-0.05, 0.015)
		var at := UnitModels.on_surface(l[0], l[1], d, depth)
		var lit := clampf(at.y / top, 0.0, 1.0) * 0.7 + (depth + 0.05) / 0.065 * 0.3
		var tint := Color(0.42, 0.5, 0.36).lerp(Color(0.95, 1.0, 0.78), lit)
		var face := (d + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.0, 0.6), rng.randf_range(-0.5, 0.5))).normalized()
		n.add_child(um.decal("leaf", 0.06 * size, 0.08 * size, at, face, true, d, tint))
	var berry := um.plain(Color("#c8221a"))
	for k in 46:
		var l: Array = lobes[rng.randi() % lobes.size()]
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.1, 1.0), rng.randf_range(-1, 1)).normalized()
		n.add_child(um.blob(Vector3.ONE * 0.024 * size, berry, UnitModels.on_surface(l[0], l[1], d, 0.012)))
	return n


## Lily pads on the water, some with a flower.
func lily_pads(seed_value: int) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	for k in rng.randi_range(2, 4):
		var p := Vector3(rng.randf_range(-0.3, 0.3), 0.004 + k * 0.001, rng.randf_range(-0.3, 0.3))
		var s := rng.randf_range(0.16, 0.26)
		n.add_child(um.decal("lily_pad", s, s, p, Vector3.UP, true, Vector3(cos(k * 2.1), 0, sin(k * 2.1))))
		if k % 2 == 0:
			n.add_child(um.decal("water_lily", s * 0.55, s * 0.55, p + Vector3(0.02, 0.03, 0.02), Vector3(0.15, 1, 0.25).normalized(), false))
	return n


## An irregular stone: a low-poly sphere with its vertices pushed about by noise,
## shaded with flat facets (chunky, broken stone).
func stone_mesh(seed_value: int) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 9
	sphere.rings = 6
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.3
	var st := SurfaceTool.new()
	st.create_from(sphere, 0)
	st.deindex()
	var arrays := st.commit_to_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		var v := verts[i]
		verts[i] = v * (1.0 + noise.get_noise_3dv(v * 1.7) * 0.45)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = null
	var out := SurfaceTool.new()
	out.create_from_arrays(arrays)
	out.generate_normals()   # deindexed, so each facet keeps its own flat normal
	return out.commit()


## A rock outcrop for impassable rock: one big broken stone with a scatter of smaller
## ones around it, half sunk, in darker varied greys with the authored rock texture.
func boulders(seed_value: int) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	var tints := [Color(0.72, 0.7, 0.66), Color(0.62, 0.6, 0.56), Color(0.8, 0.77, 0.7), Color(0.66, 0.66, 0.62)]
	var stones := [[Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08)), rng.randf_range(0.26, 0.34)]]
	for k in rng.randi_range(6, 9):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.2, 0.45)
		stones.append([Vector3(cos(a) * d, 0, sin(a) * d), rng.randf_range(0.06, 0.15)])
	for k in stones.size():
		var st: Array = stones[k]
		var r: float = st[1]
		var mi := MeshInstance3D.new()
		mi.mesh = stone_mesh(seed_value * 31 + k)
		mi.material_override = um.surf("rock", tints[k % tints.size()], 0.6)
		mi.scale = Vector3(r * rng.randf_range(1.0, 1.4), r * rng.randf_range(0.7, 1.0), r)
		mi.rotation_degrees = Vector3(rng.randf_range(-15, 15), rng.randf_range(0, 180), rng.randf_range(-15, 15))
		mi.position = st[0] + Vector3(0, r * 0.35, 0)   # half sunk into the ground
		n.add_child(mi)
	return n
