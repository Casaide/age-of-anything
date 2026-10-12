extends RefCounted
## Town life props (milestone 17), in world units (1 = a tile, ground at y = 0), baked like the
## buildings (realistic, ground shadow, no outline) into the atlas: drop-off piles that grow with
## deliveries, a house's yard clutter and garden growing with its age, and the stable's tether
## post. Seeded with a cosmetic RandomNumberGenerator (view side). Each pile and growth prop has
## stages 1..3 (stage 0 is nothing there). Options for the concept sheet carry a style letter.

const UnitModels := preload("res://scenes/art_pixel/unit_models.gd")
const PropModels := preload("res://scenes/art_pixel/prop_models.gd")

var um := UnitModels.new()
var pm := PropModels.new()
var rng := RandomNumberGenerator.new()
var models   # src/view/art/bake/models.gd, for the building materials (set by the baker's owner)

const PILE_KINDS := ["food", "wood", "stone", "gold"]
const GROWTH := ["yard", "garden"]
const STAGES := 3


func _wood() -> Material:
	return models.mats.get_mat("wood") if models != null else um.plain(Color("#7a5634"))


## A pile of what's been brought home, by resource, at stage 1..3, in style "a" or "b".
func pile(kind: String, stage: int, style := "a") -> Node3D:
	rng.seed = 7000 + PILE_KINDS.find(kind) * 100 + stage * 10 + (0 if style == "a" else 5)
	return call("_pile_%s_%s" % [kind, style], stage)


# ---------------------------------------------------------------- reeds (wood)

## A reed bundle lying from a to b, tied twice.
func _bundle(n: Node3D, a: Vector3, b: Vector3, r: float) -> void:
	var stalk := um.plain(Color("#b89a58"))
	var tie := um.plain(Color("#5a3a20"))
	var dir := (b - a)
	for k in 5:   # a few stalks round a core, so it reads as a bundle and not a log
		var ang := k * TAU / 5.0 + rng.randf() * 0.4
		var side := dir.cross(Vector3.UP).normalized() * cos(ang) * r * 0.5 + Vector3.UP * sin(ang) * r * 0.5
		var spread := dir.cross(Vector3.UP).normalized() * cos(ang) * r * 0.25
		n.add_child(um.rod(a + side - spread, b + side + spread, r * 0.55, r * 0.4, stalk, false))
	for f in [0.3, 0.7]:
		n.add_child(um.ring(r * 0.75, r * 1.0, tie, a.lerp(b, f), Vector3(0, -rad_to_deg(atan2(dir.z, dir.x)), 90)))
	var tuft := um.plain(Color("#d8c48a"))
	n.add_child(um.blob(Vector3(r * 0.9, r * 0.9, r * 0.9), tuft, b + dir.normalized() * r * 0.4))


## A: bundles lying crosswise in a heap, layer on layer.
func _pile_wood_a(stage: int) -> Node3D:
	var n := Node3D.new()
	var counts := [0, 3, 6, 10]
	var placed := 0
	var layer := 0
	var r := 0.045
	while placed < counts[stage]:
		var across := 4 - layer
		for k in across:
			if placed >= counts[stage]:
				break
			var z := (k - (across - 1) * 0.5) * r * 2.1
			var x0 := -0.24 + rng.randf_range(-0.03, 0.03)
			var y := r + layer * r * 1.7
			_bundle(n, Vector3(x0, y, z), Vector3(x0 + 0.48, y + rng.randf_range(-0.01, 0.01), z + rng.randf_range(-0.04, 0.04)), r)
			placed += 1
		layer += 1
	return n


## B: bundles stood up and leaned together in stooks.
func _pile_wood_b(stage: int) -> Node3D:
	var n := Node3D.new()
	var spots := [Vector3(0, 0, 0), Vector3(0.2, 0, 0.12), Vector3(-0.18, 0, 0.15)]
	for s in stage:
		var c: Vector3 = spots[s]
		for k in 6:
			var a := k * TAU / 6.0 + rng.randf() * 0.3
			var foot := c + Vector3(cos(a), 0, sin(a)) * 0.12
			_bundle(n, foot + Vector3(0, 0.03, 0), c + Vector3(cos(a) * 0.02, 0.42, sin(a) * 0.02), 0.035)
	return n


# ---------------------------------------------------------------- bugs and berries (food)

func _basket(n: Node3D, at: Vector3, full: bool) -> void:
	var weave := um.surf("wicker", Color.WHITE, 0.25)
	var b := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.09
	c.bottom_radius = 0.07
	c.height = 0.12
	c.radial_segments = 16
	b.mesh = c
	b.material_override = weave
	b.position = at + Vector3(0, 0.06, 0)
	n.add_child(b)
	n.add_child(um.ring(0.08, 0.1, um.plain(Color("#c8a070")), at + Vector3(0, 0.12, 0)))
	if full:
		for k in 7:
			var a := k * TAU / 7.0 + rng.randf()
			var rr := 0.05 if k > 0 else 0.0
			var bug := um.plain([Color("#c8302a"), Color("#e0607f"), Color("#b04a3a")][k % 3])
			n.add_child(um.blob(Vector3(0.028, 0.022, 0.026), bug, at + Vector3(cos(a) * rr, 0.13 + (0.03 if k == 0 else 0.0), sin(a) * rr)))


## A: baskets of bugs and berries set down in a cluster.
func _pile_food_a(stage: int) -> Node3D:
	var n := Node3D.new()
	var spots := [Vector3(0, 0, 0), Vector3(0.19, 0, 0.04), Vector3(-0.1, 0, 0.16), Vector3(0.1, 0, 0.2), Vector3(-0.17, 0, -0.06)]
	for k in [0, 1, 3, 5][stage]:
		_basket(n, spots[k], true)
	if stage == 3:   # one more stacked on top
		_basket(n, spots[0] + Vector3(0.02, 0.12, 0.01), true)
	return n


## B: a mound of bugs and berries tipped out onto a woven mat.
func _pile_food_b(stage: int) -> Node3D:
	var n := Node3D.new()
	var mat := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.012, 0.42)
	mat.mesh = bm
	mat.material_override = um.surf("wicker", Color("#d8b880"), 0.3)
	mat.position = Vector3(0, 0.006, 0)
	n.add_child(mat)
	var r: float = [0.0, 0.09, 0.14, 0.19][stage]
	for k in [0, 20, 40, 70][stage]:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r
		var h := (1.0 - d / r) * r * 0.9
		var bug := um.plain([Color("#c8302a"), Color("#e0607f"), Color("#b04a3a"), Color("#7a9a3a")][k % 4])
		n.add_child(um.blob(Vector3(0.026, 0.02, 0.024), bug, Vector3(cos(a) * d, 0.02 + h, sin(a) * d * 0.85)))
	return n


# ---------------------------------------------------------------- stone

## A: rough stones tipped in a heap.
func _pile_stone_a(stage: int) -> Node3D:
	var n := Node3D.new()
	var r: float = [0.0, 0.12, 0.17, 0.22][stage]
	for k in [0, 6, 12, 20][stage]:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r
		var mi := MeshInstance3D.new()
		mi.mesh = pm.stone_mesh(8000 + k)
		var s := rng.randf_range(0.05, 0.075)
		mi.scale = Vector3(s, s * 0.8, s)
		mi.position = Vector3(cos(a) * d, s * 0.6 + (1.0 - d / r) * r * 0.55, sin(a) * d)
		mi.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf())
		mi.material_override = um.surf("rock", Color(1.0, 0.96, 0.88), 0.2)
		n.add_child(mi)
	return n


## B: dressed blocks stacked square.
func _pile_stone_b(stage: int) -> Node3D:
	var n := Node3D.new()
	var rock := um.surf("rock", Color(0.88, 0.84, 0.76), 0.2)
	var spots := [Vector3(-0.08, 0, 0), Vector3(0.08, 0, 0), Vector3(-0.08, 0, 0.13), Vector3(0.08, 0, 0.13),
		Vector3(0, 0.09, 0.0), Vector3(0, 0.09, 0.13), Vector3(0.22, 0, 0.06), Vector3(0, 0.18, 0.06)]
	for k in [0, 3, 6, 8][stage]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.15, 0.09, 0.12)
		mi.mesh = bm
		mi.material_override = rock
		mi.position = spots[k] + Vector3(0, 0.045, 0)
		mi.rotation.y = rng.randf_range(-0.12, 0.12)
		n.add_child(mi)
	return n


# ---------------------------------------------------------------- gold

func _nugget(n: Node3D, at: Vector3, s: float) -> void:
	n.add_child(um.blob(Vector3(s, s * 0.7, s * 0.85), um.surf("rock", Color(0.6, 0.55, 0.5), 0.2), at))
	var gold := um.plain(Color("#f2c440"))
	for k in 4:   # the gold showing all over it, so it reads as gold and not as stone (at game size)
		var a := k * TAU / 4.0 + rng.randf() * 0.8
		n.add_child(um.blob(Vector3(s * 0.45, s * 0.35, s * 0.45), gold, at + Vector3(cos(a) * s * 0.55, s * 0.4, sin(a) * s * 0.55)))


## A: ore in an open wooden box, heaping over the rim.
func _pile_gold_a(stage: int) -> Node3D:
	var n := Node3D.new()
	var wood := _wood()
	var w := 0.3
	var d := 0.22
	var h := 0.12
	for side in [-1, 1]:
		n.add_child(_box(Vector3(w, h, 0.02), wood, Vector3(0, h / 2, side * d / 2)))
		n.add_child(_box(Vector3(0.02, h, d), wood, Vector3(side * w / 2, h / 2, 0)))
	n.add_child(_box(Vector3(w, 0.02, d), wood, Vector3(0, 0.01, 0)))
	var fill: float = [0.0, 0.05, 0.1, 0.15][stage]
	for k in [0, 4, 7, 11][stage]:
		_nugget(n, Vector3(rng.randf_range(-w * 0.35, w * 0.35), fill + rng.randf_range(0.0, 0.03), rng.randf_range(-d * 0.3, d * 0.3)), 0.04)
	return n


## B: sacks of ore, one slumped open with the gold showing.
func _pile_gold_b(stage: int) -> Node3D:
	var n := Node3D.new()
	var sack := um.surf("cloth", Color("#c8b48a"), 0.3)
	var spots := [Vector3(0, 0, 0), Vector3(0.16, 0, 0.06), Vector3(-0.12, 0, 0.12)]
	for k in stage:
		var p: Vector3 = spots[k]
		n.add_child(um.blob(Vector3(0.08, 0.1, 0.07), sack, p + Vector3(0, 0.09, 0)))
		n.add_child(um.blob(Vector3(0.03, 0.025, 0.03), sack, p + Vector3(0, 0.2, 0)))
	_nugget(n, Vector3(0.05, 0.03, 0.15), 0.04)
	return n


# ---------------------------------------------------------------- a house's yard and garden

## The yard (style a): a water pot and a stool, then a stack of firewood, then a drying rack
## with a cloth over it. Grows with the house's age.
func yard(stage: int, seed_value := 0) -> Node3D:
	rng.seed = 9000 + seed_value
	var n := Node3D.new()
	var wood := _wood()
	var clay := um.plain(Color("#b8643e"))
	# stage 1: a pot and a stool
	n.add_child(um.blob(Vector3(0.06, 0.07, 0.06), clay, Vector3(0.0, 0.07, 0.0)))
	n.add_child(um.ring(0.03, 0.045, clay, Vector3(0.0, 0.135, 0.0)))
	n.add_child(_box(Vector3(0.12, 0.02, 0.12), wood, Vector3(0.14, 0.1, -0.04)))
	for x in [-1, 1]:
		for z in [-1, 1]:
			n.add_child(_box(Vector3(0.015, 0.1, 0.015), wood, Vector3(0.14 + x * 0.045, 0.05, -0.04 + z * 0.045)))
	if stage >= 2:   # firewood, split and stacked
		var ends := um.plain(Color("#c8a06a"))
		for row in 3:
			for k in 4 - row:
				var z := -0.2 + 0.04 + (k + row * 0.5) * 0.065
				var p := Vector3(-0.18, 0.03 + row * 0.055, z)
				n.add_child(um.rod(p - Vector3(0.11, 0, 0), p + Vector3(0.11, 0, 0), 0.03, 0.03, wood))
				n.add_child(um.blob(Vector3(0.004, 0.026, 0.026), ends, p + Vector3(0.112, 0, 0)))
	if stage >= 3:   # a drying rack with a cloth over it
		for x in [-0.04, 0.2]:   # behind the stool, clear of the woodpile
			n.add_child(um.rod(Vector3(x, 0, -0.22), Vector3(x, 0.28, -0.22), 0.012, 0.01, wood))
		n.add_child(um.rod(Vector3(-0.06, 0.27, -0.22), Vector3(0.22, 0.27, -0.22), 0.01, 0.01, wood))
		var cloth := um.surf("cloth", Color("#d8ccb0"), 0.3)
		n.add_child(_box(Vector3(0.18, 0.14, 0.01), cloth, Vector3(0.08, 0.2, -0.22)))
	return n


## The garden (style b): a tilled bed with seedlings, then a wattle fence round it and fuller
## plants, then bean poles and a few gourds.
func garden(stage: int, seed_value := 0) -> Node3D:
	rng.seed = 9500 + seed_value
	var n := Node3D.new()
	var wood := _wood()
	var w := 0.42
	var d := 0.3
	var soil := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, 0.025, d)
	soil.mesh = bm
	soil.material_override = um.plain(Color("#5e4228"))
	soil.position = Vector3(0, 0.012, 0)
	n.add_child(soil)
	var leaves := [um.plain(Color("#5e8a2c")), um.plain(Color("#76a038")), um.plain(Color("#4a7424"))]
	for row in 3:
		n.add_child(um.blob(Vector3(w * 0.46, 0.012, 0.025), um.plain(Color("#6e4e30")), Vector3(0, 0.028, -d * 0.3 + row * d * 0.3)))
		for k in 5:
			var base := Vector3(-w * 0.38 + k * w * 0.19, 0.03, -d * 0.3 + row * d * 0.3)
			var s := 0.02 if stage == 1 else 0.035
			for l in 3:
				var a := l * TAU / 3.0 + rng.randf()
				n.add_child(um.blob(Vector3(s, s * 0.35, s * 0.55), leaves[(row + k + l) % 3], base + Vector3(cos(a) * s * 0.6, s * 0.6, sin(a) * s * 0.6), Vector3(0, rad_to_deg(a), 25)))
	if stage >= 2:   # a low wattle fence round it, a gap on the near side
		var stake := um.plain(Color("#6a4a2c"))
		var weave := um.surf("wicker", Color("#b89a6a"), 0.25)
		var hw := w / 2 + 0.03
		var hd := d / 2 + 0.03
		for x in range(5):
			var fx := -hw + x * hw * 0.5
			n.add_child(um.rod(Vector3(fx, 0, -hd), Vector3(fx, 0.1, -hd), 0.008, 0.007, stake))
		for z in range(3):
			var fz := -hd + z * hd
			for sx in [-1, 1]:
				n.add_child(um.rod(Vector3(sx * hw, 0, fz), Vector3(sx * hw, 0.1, fz), 0.008, 0.007, stake))
		n.add_child(_box(Vector3(hw * 2, 0.05, 0.012), weave, Vector3(0, 0.06, -hd)))
		for sx in [-1, 1]:
			n.add_child(_box(Vector3(0.012, 0.05, hd * 2), weave, Vector3(sx * hw, 0.06, 0)))
	if stage >= 3:   # bean poles and gourds
		for k in 3:
			var foot := Vector3(-0.14 + k * 0.14, 0, -0.1)
			n.add_child(um.rod(foot + Vector3(-0.03, 0, 0), foot + Vector3(0, 0.3, 0.02), 0.007, 0.005, wood))
			n.add_child(um.rod(foot + Vector3(0.03, 0, 0), foot + Vector3(0, 0.3, 0.02), 0.007, 0.005, wood))
			for l in 4:
				n.add_child(um.blob(Vector3(0.018, 0.012, 0.018), leaves[l % 3], foot + Vector3(rng.randf_range(-0.02, 0.02), 0.08 + l * 0.055, 0.01)))
		var gourd := um.plain(Color("#d8902a"))
		for p in [Vector3(-0.12, 0.035, 0.08), Vector3(0.1, 0.035, 0.1)]:
			n.add_child(um.blob(Vector3(0.035, 0.03, 0.035), gourd, p))
	return n


## The stable's tether post: a stout post with a ring and a rope trailing to the ground.
func tether_post() -> Node3D:
	var n := Node3D.new()
	var wood := _wood()
	n.add_child(um.rod(Vector3(0, 0, 0), Vector3(0, 0.26, 0), 0.025, 0.022, wood))
	n.add_child(um.ring(0.015, 0.024, um.plain(Color("#4a4c50")), Vector3(0.02, 0.21, 0), Vector3(0, 0, 90)))
	var rope := um.plain(Color("#c8b48a"))
	n.add_child(um.rod(Vector3(0.02, 0.21, 0), Vector3(0.14, 0.12, 0.05), 0.006, 0.006, rope, false))
	return n


func _box(size: Vector3, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	return mi
