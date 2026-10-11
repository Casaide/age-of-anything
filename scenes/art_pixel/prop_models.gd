extends RefCounted
## Landscape props for the pixel bake, in world units (1 = a tile): reed beds, bug
## bushes, rock outcrops, field stones, grass tufts and lily pads, built from authored
## texture cards (assets/art/textures/) on simple 3D bodies, drawn realistically.
## Seeded (a cosmetic RandomNumberGenerator is fine view-side): every seed is a
## different shape, size and turn.

const UnitModels := preload("res://scenes/art_pixel/unit_models.gd")

var um := UnitModels.new()
var rng := RandomNumberGenerator.new()


## A reed bed on one tile, built like the bug bushes: a few hundred authored blade
## cards, dark and dense low down, lit towards the tips, in several sub-clumps so the
## outline is ragged; some blades dried tan, some bent over, and velvet cattails at
## varied heights. No base disc: short dark blades hide where the stems meet the mud.
## `size` scales it (shore reeds are small); `stage` 0-3 is how far it has been cut:
## 0 whole, 1 thinned with cut stalks showing, 2 mostly cut, 3 stubble.
func reed_clump(seed_value: int, size := 1.0, stage := 0) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	var keep: float = [1.0, 0.55, 0.22, 0.0][stage]
	var clumps := []
	for k in rng.randi_range(5, 7):   # spread over the whole tile: a bed, not a bunch
		var at := Vector3(rng.randf_range(-0.36, 0.36), 0, rng.randf_range(-0.36, 0.36)) * size
		clumps.append([at, rng.randf_range(0.1, 0.18) * size, rng.randf_range(0.7, 1.1)])
	var cut := um.plain(Color("#a38a52"))
	var cut_top := um.plain(Color("#d8c48a"))
	var blades := int(190 * size)
	for k in blades:
		var c: Array = clumps[k % clumps.size()]
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * float(c[1])
		var base: Vector3 = c[0] + Vector3(cos(a) * r, 0, sin(a) * r)
		var h := rng.randf_range(0.3, 1.0) * float(c[2]) * size
		var low := rng.randf() < 0.3   # the short dark understorey
		if low:
			h *= 0.35
		var yaw := rng.randf() * TAU
		var out := Vector3(cos(yaw), 0, sin(yaw))
		var lean := rng.randf_range(0.04, 0.35) + (0.6 if rng.randf() < 0.08 else 0.0)   # now and then one bent over
		var dry := rng.randf() < 0.14
		var face_turn := rng.randf_range(-1.0, 1.0)
		var shade := rng.randf()
		var width := rng.randf_range(0.035, 0.055)
		var cut_roll := rng.randf()
		var sh := rng.randf_range(0.04, 0.12) * size
		# Every random draw comes first, so a cut stage keeps the same blades as the whole bed.
		var stays := rng.randf() < keep or low and stage < 3
		if not stays:
			if cut_roll < 0.55 and not low:   # a cut stalk
				n.add_child(um.rod(base, base + Vector3(0, sh, 0), 0.012 * size, 0.011 * size, cut, false))
				n.add_child(um.blob(Vector3(0.012, 0.004, 0.012) * size, cut_top, base + Vector3(0, sh, 0)))
			continue
		var up := (Vector3.UP + out * lean).normalized()
		# Face the blade mostly towards the viewer (edge-on cards vanish), turned a little.
		var facing := Vector3(0.6 + face_turn * 0.5, 0.0, 1.0).normalized()
		facing = (facing - up * facing.dot(up)).normalized()
		var lit := clampf(h / (1.05 * size), 0.0, 1.0)
		var tint := Color(0.38, 0.46, 0.3).lerp(Color(1.0, 1.0, 0.86), lit * 0.8 + shade * 0.2)
		if dry:
			tint = Color(1.25, 1.05, 0.6).lerp(Color(1.4, 1.25, 0.8), lit)
		n.add_child(um.decal("reed_leaf", width * size, h, base + up * h * 0.5, facing, true, up, tint))
	var stem := um.plain(Color("#7a8a3a"))
	var velvet := um.plain(Color("#5a361c"))
	for k in int(rng.randi_range(4, 8) * size):
		var c: Array = clumps[rng.randi() % clumps.size()]
		var base: Vector3 = c[0] + Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08)) * size
		var h := rng.randf_range(0.6, 1.15) * float(c[2]) * size
		var top := base + Vector3(rng.randf_range(-0.09, 0.09), h, rng.randf_range(-0.09, 0.09)) * Vector3(size, 1, size)
		if rng.randf() >= keep:
			continue
		n.add_child(um.rod(base, top, 0.011, 0.009, stem, false))
		var head := rng.randf_range(0.07, 0.12)
		n.add_child(um.blob(Vector3(0.026, head, 0.026), velvet, top - Vector3(0, head * 0.9, 0)))
		n.add_child(um.rod(top, top + Vector3(0, 0.08, 0), 0.005, 0.003, stem, false))
	return n


## A bug bush, drawn realistically like the genre's static props: a dense shrub of
## a few hundred small leaves over irregular lobes, dark inside and lit on top, its
## outline broken by single leaves, dotted all over with small red berries.
## Size and shape vary with the seed. `stage` 0-3 is how far it has been picked: each
## stage has fewer berries and a sparser, browner bush.
func bug_bush(seed_value: int, stage := 0) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	var size := rng.randf_range(0.8, 1.2)
	var squash := rng.randf_range(0.8, 1.15)   # some low and wide, some tall
	var lobes := []
	for k in rng.randi_range(4, 7):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 0.22) * size
		var r := rng.randf_range(0.13, 0.21) * size
		lobes.append([Vector3(cos(a) * d, rng.randf_range(0.14, 0.3) * size * squash, sin(a) * d), Vector3(r, r * 0.8 * squash, r)])
	for l in lobes:   # a dark core, so you never see through the leaves
		n.add_child(um.blob(l[1] * 0.8, um.plain(Color("#1c2c12").lerp(Color("#3a2c16"), stage / 3.0)), l[0]))
	var top := 0.0
	for l in lobes:
		top = maxf(top, l[0].y + l[1].y)
	var leaves: float = [1.0, 0.85, 0.7, 0.55][stage]
	var brown: float = [0.0, 0.18, 0.36, 0.55][stage]
	for k in 340:
		var l: Array = lobes[k % lobes.size()]
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1.0), rng.randf_range(-1, 1)).normalized()
		var depth := rng.randf_range(-0.05, 0.015)
		var face := (d + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.0, 0.6), rng.randf_range(-0.5, 0.5))).normalized()
		var wither := rng.randf()
		if rng.randf() > leaves:
			continue
		var at := UnitModels.on_surface(l[0], l[1], d, depth)
		var lit := clampf(at.y / top, 0.0, 1.0) * 0.7 + (depth + 0.05) / 0.065 * 0.3
		var tint := Color(0.42, 0.5, 0.36).lerp(Color(0.95, 1.0, 0.78), lit)
		if wither < brown:
			tint = tint * Color(1.35, 0.95, 0.55)   # a dry, browning leaf
		n.add_child(um.decal("leaf", 0.06 * size, 0.08 * size, at, face, true, d, tint))
	var berry := um.plain(Color("#c8221a"))
	var berries: float = [1.0, 0.5, 0.2, 0.0][stage]
	for k in 46:
		var l: Array = lobes[rng.randi() % lobes.size()]
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.1, 1.0), rng.randf_range(-1, 1)).normalized()
		if rng.randf() > berries:
			continue
		n.add_child(um.blob(Vector3.ONE * 0.024 * size, berry, UnitModels.on_surface(l[0], l[1], d, 0.012)))
	return n


## A tuft of grass: twenty-odd authored blades, dark at the root and lit at the tips.
func grass_tuft(seed_value: int) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	var size := rng.randf_range(0.7, 1.3)
	for k in rng.randi_range(22, 32):
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.08 * size
		var base := Vector3(cos(a) * r, 0, sin(a) * r)
		var h := rng.randf_range(0.1, 0.26) * size
		var out := Vector3(cos(a), 0, sin(a))
		var up := (Vector3.UP + out * rng.randf_range(0.1, 0.7)).normalized()
		var facing := Vector3(rng.randf_range(-0.4, 0.8), 0, 1).normalized()
		facing = (facing - up * facing.dot(up)).normalized()
		var tint := Color(0.5, 0.62, 0.36).lerp(Color(1.0, 1.0, 0.82), rng.randf() * 0.6 + h / (0.2 * size) * 0.4)
		n.add_child(um.decal("reed_leaf", 0.034, h, base + up * h * 0.5, facing, true, up, tint))
	return n


## A few field stones, broken and faceted like the rock outcrops, half sunk in the grass.
func field_stones(seed_value: int) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	for k in rng.randi_range(2, 4):
		var r := rng.randf_range(0.05, 0.12)
		var mi := MeshInstance3D.new()
		mi.mesh = stone_mesh(seed_value * 17 + k)
		mi.material_override = um.surf("rock", Color(0.74, 0.74, 0.66).lerp(Color(0.6, 0.62, 0.55), rng.randf()), 0.5)
		mi.scale = Vector3(r * rng.randf_range(1.0, 1.5), r * rng.randf_range(0.5, 0.8), r)
		mi.rotation_degrees = Vector3(rng.randf_range(-10, 10), rng.randf_range(0, 180), rng.randf_range(-10, 10))
		mi.position = Vector3(rng.randf_range(-0.16, 0.16), r * 0.2, rng.randf_range(-0.16, 0.16))
		n.add_child(mi)
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
func stone_mesh(seed_value: int, cut := false) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 8
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
		if cut:   # split stone: sheared flat across the top and down one face, rough elsewhere
			verts[i].y = minf(verts[i].y, 0.5 + noise.get_noise_2d(v.x * 3.0, v.z * 3.0) * 0.06)
			verts[i].x = minf(verts[i].x, 0.65)
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
	# Surface detail at the bushes' density (Dominic: the rocks read low-res next to them):
	# lichen and moss on the tops, dark cracks, and pebbles and grass round the foot.
	var lichen := [um.plain(Color("#b8b46a")), um.plain(Color("#d8d6c8")), um.plain(Color("#5e7a34"))]
	for k in stones.size():
		var st: Array = stones[k]
		var r: float = st[1]
		for d in (8 if k == 0 else 2):
			var a := rng.randf() * TAU
			var up := rng.randf_range(0.3, 0.75)
			var p: Vector3 = st[0] + Vector3(cos(a) * r * 0.7 * (1.0 - up * 0.4), r * 0.35 + r * up * 0.7, sin(a) * r * 0.7 * (1.0 - up * 0.4))
			var sz := r * rng.randf_range(0.14, 0.26)
			n.add_child(um.blob(Vector3(sz * 1.4, sz * 0.3, sz), lichen[(k + d) % 3], p))
		if k == 0:
			for c in 3:   # cracks: thin dark seams down the big stone's face
				var a := rng.randf_range(-0.6, 1.6)
				var p: Vector3 = st[0] + Vector3(cos(a) * r * 0.95, r * 0.55, sin(a) * r * 0.95)
				var crack := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.012, r * 0.6, 0.012)
				crack.mesh = bm
				crack.material_override = um.plain(Color("#2a2622"))
				crack.position = p
				crack.rotation_degrees = Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-25, 25))
				n.add_child(crack)
	for k in 12:   # pebbles and grass at the foot
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.3, 0.55)
		if k % 3 == 0:   # a grass tuft: a few blades from one root
			var root := Vector3(cos(a) * d, 0.0, sin(a) * d)
			for g in 4:
				var lean := Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(0.07, 0.12), rng.randf_range(-0.03, 0.03))
				n.add_child(um.rod(root, root + lean, 0.012, 0.003, um.plain(Color("#4e7a2c") if g % 2 == 0 else Color("#6a9238")), false))
		else:
			var pr := rng.randf_range(0.015, 0.035)
			var peb := MeshInstance3D.new()
			peb.mesh = stone_mesh(seed_value * 13 + k)
			peb.material_override = um.surf("rock", tints[k % tints.size()], 0.6)
			peb.scale = Vector3(pr * 1.3, pr * 0.7, pr)
			peb.position = Vector3(cos(a) * d, pr * 0.3, sin(a) * d)
			n.add_child(peb)
	return n


## Stone you can mine, unlike the grey boulders that only block: pale, warm sandstone split
## along flat faces (worked stone, not cubes: rough everywhere a split didn't go), with
## pieces and chips around. `stage` 0-3 is how far it's been mined: fewer, smaller rocks,
## then chips. `ore` "gold" is the same deposit (the shared base: one shape for every mine)
## in darker rock with gold nuggets and veins showing, so the two read apart at a glance.
func quarry(seed_value: int, stage := 0, ore := "stone") -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	var gold := ore == "gold"
	var tints := [Color(0.98, 0.88, 0.7), Color(0.9, 0.79, 0.62), Color(1.0, 0.93, 0.8), Color(0.86, 0.75, 0.6)]
	if gold:
		tints = [Color(0.62, 0.56, 0.5), Color(0.55, 0.5, 0.46), Color(0.68, 0.62, 0.55), Color(0.5, 0.46, 0.42)]
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("#f2c440")
	metal.metallic = 0.85
	metal.roughness = 0.25
	metal.emission_enabled = true
	metal.emission = Color("#7a5a10")
	var keep: float = [1.0, 0.65, 0.35, 0.0][stage]
	var rocks := []
	for k in rng.randi_range(5, 7):   # every random draw first, so each stage is the same heap, cut down
		var a := rng.randf() * TAU
		var d := 0.0 if k == 0 else rng.randf_range(0.16, 0.38)
		var r := rng.randf_range(0.3, 0.36) if k == 0 else rng.randf_range(0.09, 0.17)
		rocks.append([Vector3(cos(a) * d, 0, sin(a) * d), r, rng.randf_range(0, 360), rng.randf_range(1.0, 1.3), rng.randf() < keep])
	for k in rocks.size():
		var rk: Array = rocks[k]
		var r: float = rk[1] * (1.0 - 0.25 * stage if k == 0 else 1.0)
		if not (rk[4] or k == 0 and stage < 3):
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = stone_mesh(seed_value * 31 + k, true)
		mi.material_override = um.surf("rock", tints[k % tints.size()], 0.6)
		mi.scale = Vector3(r * rk[3], r * 0.9, r)
		mi.rotation_degrees = Vector3(0, rk[2], 0)
		mi.position = rk[0] + Vector3(0, r * 0.3, 0)
		n.add_child(mi)
		if gold:   # nuggets set into the rock, poking out of it; a vein of them across the big one
			var count := 11 if k == 0 else 3
			for g in count:
				var a := (float(g) / count) * PI * 1.4 - 0.2 if k == 0 else rng.randf() * TAU
				var h := 0.1 + 0.3 * absf(sin(g * 1.7)) if k == 0 else rng.randf_range(0.05, 0.35)
				var gr := r * (0.17 if k == 0 else rng.randf_range(0.18, 0.24))
				var nug := MeshInstance3D.new()
				nug.mesh = stone_mesh(seed_value * 7 + k * 5 + g)
				nug.material_override = metal
				nug.scale = Vector3(gr * 1.3, gr * 0.8, gr)
				# Just inside the rock's own (scaled, turned) outline, so it sits in the surface.
				var local := Vector3(cos(a) * 0.68, h, sin(a) * 0.68)
				nug.position = mi.position + (mi.basis * local)
				n.add_child(nug)
	for k in 9 - stage:   # chips and rubble
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.15, 0.48)
		var r := rng.randf_range(0.025, 0.05)
		var chip := MeshInstance3D.new()
		chip.mesh = stone_mesh(seed_value * 17 + k, true)
		chip.material_override = metal if gold and k % 3 == 0 else um.surf("rock", tints[k % tints.size()], 0.6)
		chip.scale = Vector3(r * 1.3, r * 0.8, r)
		chip.position = Vector3(cos(a) * d, r * 0.3, sin(a) * d)
		n.add_child(chip)
	return n


## Where a hunted or slaughtered animal fell: cuts of meat on the hide, a few bones.
## `stage` 0-3: less and less left.
func carcass(seed_value: int, stage := 0) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	var hide := um.plain(Color("#6a4a30"))
	var meat := um.plain(Color("#b04a3a"))
	var fat := um.plain(Color("#e8c8b0"))
	var bone := um.plain(Color("#f0e8d8"))
	n.add_child(um.blob(Vector3(0.34 - stage * 0.06, 0.03, 0.24 - stage * 0.04), hide, Vector3(0, 0.02, 0), Vector3(0, rng.randf_range(0, 90), 0)))
	var cuts: int = [4, 3, 2, 0][stage]
	for k in 4:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a) * 0.12, 0.06, sin(a) * 0.1)
		if k < cuts:
			n.add_child(um.blob(Vector3(0.07, 0.045, 0.05), meat, p, Vector3(0, rng.randf_range(0, 180), 0)))
			n.add_child(um.blob(Vector3(0.05, 0.02, 0.035), fat, p + Vector3(0.01, 0.035, 0)))
	for k in 2 + stage:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a) * 0.2, 0.03, sin(a) * 0.15)
		n.add_child(um.rod(p, p + Vector3(rng.randf_range(-0.1, 0.1), 0.01, rng.randf_range(-0.08, 0.08)), 0.015, 0.012, bone))
	return n


## A farm's field, one tile: tilled earth in furrows with rows of crops (green
## stalks with golden ears), the realistic static style.
func crops(seed_value: int) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	var soil := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.98, 0.04, 0.98)
	soil.mesh = bm
	soil.material_override = um.plain(Color("#5e4228"))
	soil.position = Vector3(0, 0.02, 0)
	n.add_child(soil)
	# Leafy plants in ridged rows at the bushes' detail (Dominic: farms read low-res): each a
	# little clump of leaves, some with a golden head, clods of earth between the rows.
	var leaves := [um.plain(Color("#5e8a2c")), um.plain(Color("#4a7424")), um.plain(Color("#76a038"))]
	var ear := um.plain(Color("#d8b44a"))
	for row in 6:
		var z := -0.4 + row * 0.16
		n.add_child(um.blob(Vector3(0.48, 0.025, 0.045), um.plain(Color("#6e4e30")), Vector3(0, 0.045, z)))   # the ridge
		for k in 8:
			var x := -0.42 + k * 0.12 + rng.randf_range(-0.02, 0.02)
			var base := Vector3(x, 0.06, z + rng.randf_range(-0.015, 0.015))
			var h := rng.randf_range(0.12, 0.2)
			for l in 3:
				var a := l * TAU / 3.0 + rng.randf()
				n.add_child(um.blob(Vector3(0.045, 0.014, 0.022), leaves[(row + k + l) % 3], base + Vector3(cos(a) * 0.03, h * (0.35 + l * 0.22), sin(a) * 0.03), Vector3(0, rad_to_deg(a), 30)))
			if rng.randf() < 0.55:
				n.add_child(um.blob(Vector3(0.02, 0.04, 0.02), ear, base + Vector3(0, h + 0.03, 0)))
		for c in 3:   # clods
			n.add_child(um.blob(Vector3(0.02, 0.012, 0.018), um.plain(Color("#4a3420")), Vector3(rng.randf_range(-0.45, 0.45), 0.045, z + 0.08)))
	return n


## An amphibian farm in the shallows, one tile: still water with rows of rice shoots.
func paddy(seed_value: int) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	var water := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.98, 0.02, 0.98)
	water.mesh = bm
	water.material_override = um.plain(Color("#3e6e6a"))
	water.position = Vector3(0, 0.01, 0)
	n.add_child(water)
	for side in [-1, 1]:   # low mud banks along two edges
		n.add_child(um.blob(Vector3(0.5, 0.03, 0.04), um.plain(Color("#5a4630")), Vector3(0, 0.02, side * 0.47)))
	var shoot := um.plain(Color("#7aa83e"))
	for row in 5:
		for k in 6:
			var base := Vector3(-0.4 + k * 0.16 + rng.randf_range(-0.03, 0.03), 0.02, -0.38 + row * 0.19)
			for blade in 3:
				var tip := base + Vector3(rng.randf_range(-0.04, 0.04), rng.randf_range(0.1, 0.16), rng.randf_range(-0.04, 0.04))
				n.add_child(um.rod(base, tip, 0.008, 0.004, shoot, false))
	return n
