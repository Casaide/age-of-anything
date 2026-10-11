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


## A bug bush: a few lumpy foliage masses (authored leaf texture), some edge
## leaves breaking the silhouette, and red bugs crawling on top.
func bug_bush(seed_value: int) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	var foliage := um.surf("foliage", Color(1, 1, 1), 0.35)
	var lumps := [[Vector3(0, 0.24, 0), Vector3(0.3, 0.24, 0.3)]]
	for k in 5:
		var a := TAU * k / 5.0 + rng.randf_range(-0.4, 0.4)
		var r := rng.randf_range(0.14, 0.2)
		lumps.append([Vector3(cos(a) * 0.2, rng.randf_range(0.14, 0.3), sin(a) * 0.2), Vector3(r, r * 0.85, r)])
	for l in lumps:
		n.add_child(um.blob(l[1], foliage, l[0]))
	var tints := [Color(1, 1, 1), Color(0.8, 0.92, 0.72), Color(0.9, 1.0, 0.8)]
	for k in 22:
		var l: Array = lumps[1 + k % 5]
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.1, 0.8), rng.randf_range(-1, 1)).normalized()
		var pos := UnitModels.on_surface(l[0], l[1], d, -0.01)
		n.add_child(um.decal("leaf", 0.11, 0.15, pos + d * 0.05, (d + Vector3.UP * 0.6).normalized(), true, d, tints[k % tints.size()]))
	for k in 6:
		var d := Vector3(rng.randf_range(-0.8, 0.8), 1.0, rng.randf_range(-0.3, 1)).normalized()
		var l: Array = lumps[k % lumps.size()]
		n.add_child(um.decal("ladybird", 0.1, 0.1, UnitModels.on_surface(l[0], l[1], d, 0.012), d, false, Vector3(rng.randf_range(-1, 1), 0, 1).normalized()))
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
