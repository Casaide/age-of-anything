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


## A bug bush: a cluster of small leafy clumps, dark and olive underneath and lit on
## top, with leaf cards fringing the outline (so it isn't a smooth cushion) and clusters
## of red bugs on the sunny side. Size varies with the seed.
func bug_bush(seed_value: int) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	var size := rng.randf_range(0.8, 1.15)
	var clumps := []
	for k in 11:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 0.26) * size
		var h := rng.randf_range(0.1, 0.36) * size
		var r := rng.randf_range(0.1, 0.16) * size
		clumps.append([Vector3(cos(a) * d, h, sin(a) * d), Vector3(r, r * 0.85, r)])
	clumps.sort_custom(func(x, y): return x[0].y < y[0].y)
	for k in clumps.size():
		var c: Array = clumps[k]
		# Low clumps sit in shade, high ones catch the light: the bush gets a real volume.
		var lift: float = clampf(c[0].y / (0.36 * size), 0.0, 1.0)
		var tint := Color(0.52, 0.6, 0.42).lerp(Color(0.86, 0.92, 0.66), lift)
		n.add_child(um.blob(c[1], um.surf("foliage", tint, 0.3), c[0]))
	# Leaves fringing the outline: pushed out from the clumps, pointing outward.
	var leaf_tints := [Color(0.7, 0.8, 0.55), Color(0.85, 0.9, 0.62), Color(0.6, 0.7, 0.5)]
	for k in 34:
		var c: Array = clumps[rng.randi() % clumps.size()]
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1.0), rng.randf_range(-1, 1)).normalized()
		var at := UnitModels.on_surface(c[0], c[1], d, 0.02)
		n.add_child(um.decal("leaf", 0.09 * size, 0.12 * size, at, (d + Vector3.UP * 0.4).normalized(), true, d, leaf_tints[k % 3]))
	# Bugs in little groups on the lit top, facing the sun.
	for g in 3:
		var c: Array = clumps[clumps.size() - 1 - g * 2]
		var base_d := Vector3(rng.randf_range(-0.6, 0.6), 1.0, rng.randf_range(0.0, 0.9)).normalized()
		for k in 3:
			var d := (base_d + Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35))).normalized()
			n.add_child(um.decal("ladybird", 0.14 * size, 0.14 * size, UnitModels.on_surface(c[0], c[1], d, 0.015), d, false, Vector3(rng.randf_range(-1, 1), 0, 1).normalized()))
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
