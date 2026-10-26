extends RefCounted
## Art-quality study (docs/concepts/art-quality/), direction 2: a building broken up in 3D before
## it bakes, in stages, the way _hold_back in art_kit.gd holds parts back for construction.
## Not in the game: tests/art_quality/ruin_sheet.gd draws it.
##
## Stages (by damage taken): 0 whole, 1 battered (roof holed, a few pieces knocked askew, scorch),
## 2 breaking (the top half falling in, beams sagging, rubble spilling), 3 collapsed (stumps of
## wall in a heap, charred beams), 4 ruin (what lies there after it falls: footings, the heap).

const Rng := preload("res://src/rng.gd")

## Per stage: the share of the height above which pieces may go, how many of those go, how many
## of the rest tilt (and how far, degrees), how many pieces scorch, rubble count, charred beams,
## and the height wall stumps are cut down to (0: no cut).
const STAGES := [
	{"above": 1.0, "gone": 0.0, "tilt": 0.0, "deg": 0.0, "scorch": 0.0, "rubble": 0, "beams": 0, "cut": 0.0},
	{"above": 0.55, "gone": 0.3, "tilt": 0.25, "deg": 12.0, "scorch": 0.2, "rubble": 26, "beams": 0, "cut": 0.0},
	{"above": 0.4, "gone": 0.6, "tilt": 0.6, "deg": 26.0, "scorch": 0.45, "rubble": 70, "beams": 3, "cut": 0.0},
	{"above": 0.3, "gone": 1.0, "tilt": 0.3, "deg": 18.0, "scorch": 0.7, "rubble": 140, "beams": 6, "cut": 0.42},
	{"above": 0.12, "gone": 1.0, "tilt": 0.0, "deg": 0.0, "scorch": 1.0, "rubble": 190, "beams": 8, "cut": 0.16},
]


## Break `body` (a building model, not yet in the tree) to stage `s`, seeded by `seed_value`.
static func apply(body: Node3D, s: int, seed_value: int, models) -> void:
	var st: Dictionary = STAGES[s]
	if s == 0:
		return
	var rng := Rng.new(seed_value * 7919 + s * 104729)
	var boxes := {}
	var chain := {}
	var all := AABB()
	var first := true
	var meshes: Array = body.find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		var t := Transform3D()
		var p: Node = mi
		while p != body:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		chain[mi] = t * (mi as Node3D).transform.affine_inverse()   # the parents' part
		var b: AABB = t * (mi as MeshInstance3D).get_aabb()
		boxes[mi] = b
		all = b if first else all.merge(b)
		first = false
	var h := all.size.y
	var base := all.position.y
	var mats := []   # what fell: the rubble is made of it
	for mi in meshes:
		var b: AABB = boxes[mi]
		var m: Material = (mi as MeshInstance3D).get_active_material(0)
		if not mi.visible or not (mi as Node3D).is_visible_in_tree():
			continue
		var centre := b.get_center()
		var rel := (centre.y - base) / h
		if st.cut > 0.0 and b.position.y - base < st.cut * h * 0.6 and b.end.y - base > st.cut * h:
			# A wall stump: what stands on the ground is squashed down from its foot to a ragged height.
			var top: float = base + h * st.cut * (0.55 + 0.6 * _roll(rng))
			if m and (b.size.x > all.size.x * 0.35 or b.size.z > all.size.z * 0.35):
				mi.visible = false   # a whole wall (or a hall's core) as one block: broken into ragged stumps along its sides
				_stumps(body, b, top, m, rng, models)
			else:
				var k := (top - b.position.y) / maxf(b.size.y, 0.001)
				var foot := Vector3(centre.x, b.position.y, centre.z)
				_move(mi, chain[mi], Transform3D(Basis.from_scale(Vector3(1, k, 1)), Vector3.ZERO), foot)
			if m:
				mats.append(m)
		elif (rel > st.above or (st.cut > 0.0 and b.end.y - base > st.cut * h)) and _roll(rng) < st.gone:
			mi.visible = false
			if m:
				mats.append(m)
			continue
		elif rel > st.above * 0.6 and _roll(rng) < st.tilt:
			# Knocked askew: turned about its lowest edge and sagging a little.
			var axis := Vector3(_roll(rng) - 0.5, 0.0, _roll(rng) - 0.5).normalized()
			var deg: float = st.deg * (0.5 + _roll(rng))
			var foot := Vector3(centre.x, b.position.y, centre.z)
			var m3 := Transform3D(Basis(axis, deg_to_rad(deg)), Vector3(0, -h * 0.04 * s * _roll(rng), 0))
			_move(mi, chain[mi], m3, foot)
		if _roll(rng) < st.scorch:
			_scorch(mi, 0.35 + 0.35 * _roll(rng))
	if mats.is_empty():
		mats.append(models.mats.get_mat("stone"))
	_rubble(body, all, st.rubble, st.cut, mats, rng, models)
	var char_mat := StandardMaterial3D.new()
	char_mat.albedo_color = Color("#2a2420")
	char_mat.roughness = 1.0
	for k in st.beams:
		var a := Vector3(lerpf(all.position.x, all.end.x, 0.15 + 0.7 * _roll(rng)), 0.0, lerpf(all.position.z, all.end.z, 0.15 + 0.7 * _roll(rng)))
		var d := Vector3(_roll(rng) - 0.5, 0.0, _roll(rng) - 0.5).normalized() * h * (0.25 + 0.3 * _roll(rng))
		d.y = h * (0.12 + 0.25 * _roll(rng)) * (1.0 if s < 4 else 0.3)
		body.add_child(models.beam(a, a + d, 0.022 + 0.012 * _roll(rng), char_mat))


static func _roll(rng) -> float:
	return float(rng.next_u32() % 10000) / 10000.0


## Apply a body-space transform `m` about `pivot` to a mesh whose parents' part is `parents`.
static func _move(mi: Node3D, parents: Transform3D, m: Transform3D, pivot: Vector3) -> void:
	var about := Transform3D(Basis(), pivot) * m * Transform3D(Basis(), -pivot)
	mi.transform = parents.affine_inverse() * about * parents * mi.transform


static func _scorch(mi: MeshInstance3D, k: float) -> void:
	var m := mi.get_active_material(0)
	if not m is StandardMaterial3D:
		return
	var d: StandardMaterial3D = m.duplicate()
	d.albedo_color = d.albedo_color.darkened(k)
	mi.material_override = d


## A heap of broken pieces over the footprint, highest in the middle, spilling past the walls.
static func _rubble(body: Node3D, all: AABB, n: int, cut: float, mats: Array, rng, models) -> void:
	var c := all.get_center()
	var half := Vector2(all.size.x, all.size.z) * 0.5
	var heap: float = all.size.y * (0.1 + cut * 0.6)
	for k in n:
		var r := sqrt(_roll(rng)) * 1.15
		var a := _roll(rng) * TAU
		var x := c.x + cos(a) * r * half.x
		var z := c.z + sin(a) * r * half.y
		var u := maxf(all.size.x, all.size.z) * 0.045   # pieces sized to the building: a hall breaks into bigger blocks
		var size := Vector3(u * (0.6 + 1.2 * _roll(rng)), u * (0.4 + 0.7 * _roll(rng)), u * (0.6 + 1.0 * _roll(rng)))
		var y := heap * maxf(0.0, 1.0 - r) * _roll(rng) + size.y * 0.4
		var m: Material = mats[rng.next_u32() % mats.size()]
		var rot := Vector3(_roll(rng) * 40.0 - 20.0, _roll(rng) * 180.0, _roll(rng) * 40.0 - 20.0)
		body.add_child(models.box(size, m, Vector3(x, y, z), rot))


## Ragged wall stumps along the sides of a box (body space): short pieces of its own material, each
## a different height up to `top`, some missing (the breaches).
static func _stumps(body: Node3D, b: AABB, top: float, m: Material, rng, models) -> void:
	var t := minf(b.size.x, b.size.z) * 0.12
	var lo := b.position
	var hi := b.end
	var corners := [Vector3(lo.x, 0, lo.z), Vector3(hi.x, 0, lo.z), Vector3(hi.x, 0, hi.z), Vector3(lo.x, 0, hi.z)]
	for e in 4:
		var a: Vector3 = corners[e]
		var c: Vector3 = corners[(e + 1) % 4]
		var n := maxi(2, int(a.distance_to(c) / (t * 2.2)))
		for i in n:
			if _roll(rng) < 0.18:
				continue   # a breach
			var f0 := float(i) / n
			var f1 := float(i + 1) / n
			var at := a.lerp(c, (f0 + f1) * 0.5)
			var hgt := maxf(t, (top - lo.y) * (0.25 + 0.75 * _roll(rng)))
			var along := a.distance_to(c) / n
			var size := Vector3(along if absf(c.x - a.x) > 0.001 else t, hgt, t if absf(c.x - a.x) > 0.001 else along)
			body.add_child(models.box(size, m, Vector3(at.x, lo.y + hgt * 0.5, at.z), Vector3(_roll(rng) * 6.0 - 3.0, 0.0, _roll(rng) * 6.0 - 3.0)))
