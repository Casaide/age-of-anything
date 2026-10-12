extends RefCounted
## Map bridges for the pixel bake (milestone 15, phase 3), in world units (1 = a tile): a
## neutral timber look, owned by nobody (no team colour). Built along +X, `length` tiles of
## water, reaching a little onto each bank; the view turns the bake for bridges running
## along sim y. Concept looks (`style`) for Dominic's pick (D-080):
##   0 trestle: plank deck on beams, post bents with cross braces, pole rails
##   1 log bridge: a deck of round logs on stone-filled cribs, no rails
##   2 humped: a deck rising in the middle, posts with rope rails
## `broken` 1: what's left after it's been broken: stumps of posts, a few planks hanging off
## the bank ends, the middle gone.

const UnitModels := preload("res://scenes/art_pixel/unit_models.gd")

const DECK := 0.16        # deck height above the water
const WIDTH := 0.78       # across

var um := UnitModels.new()
var rng := RandomNumberGenerator.new()


func bridge(seed_value: int, length: int, style := 0, broken := 0) -> Node3D:
	rng.seed = seed_value
	var n := Node3D.new()
	var half := length * 0.5 + 0.45   # onto the banks
	var wood := um.surf("wood_grain", Color(0.78, 0.74, 0.66), 0.6)
	var dark := um.surf("wood_grain", Color(0.5, 0.47, 0.42), 0.6)
	var gone := func(x: float) -> bool: return broken == 1 and absf(x) < half - 0.7
	match style:
		1:
			# Cribs: log boxes filled with stones, standing in the water.
			for k in range(1, length):
				var x := -length * 0.5 + k
				if broken == 1 and absf(x) < 0.6:
					_crib(n, x, 0.6, dark)   # the cribs stand; only their logs went
					continue
				_crib(n, x, 1.0, dark)
			var logs := int(half * 2.0 / 0.11)
			for k in logs:
				var x := -half + (k + 0.5) * half * 2.0 / logs
				if gone.call(x) and rng.randf() < 0.9:
					continue
				var r := rng.randf_range(0.045, 0.06)
				var y := DECK + _hump(x, half, 0.0) + r
				var a := Vector3(x + rng.randf_range(-0.01, 0.01), y, -WIDTH * 0.5 - rng.randf_range(0.0, 0.06))
				var b := Vector3(x + rng.randf_range(-0.01, 0.01), y, WIDTH * 0.5 + rng.randf_range(0.0, 0.06))
				n.add_child(um.rod(a, b, r, r * 0.95, wood if k % 3 else dark, true))
		_:
			var rise := 0.14 if style == 2 else 0.0
			# Beams under the deck, end to end.
			for side in [-1, 1]:
				var z: float = side * WIDTH * 0.36
				var segs := 8
				for k in segs:
					var x0 := -half + k * half * 2.0 / segs
					var x1 := x0 + half * 2.0 / segs
					if gone.call((x0 + x1) * 0.5):
						continue
					n.add_child(um.rod(Vector3(x0, DECK - 0.04 + _hump(x0, half, rise), z), Vector3(x1, DECK - 0.04 + _hump(x1, half, rise), z), 0.04, 0.04, dark, false))
			# Bents: posts down into the water, braced.
			for k in range(0, length + 1):
				var x := -length * 0.5 + k
				var top := DECK + _hump(x, half, rise)
				var stub: bool = gone.call(x)
				for side in [-1, 1]:
					var z: float = side * WIDTH * 0.42
					var h := (0.12 if stub else top + 0.02) + 0.25
					n.add_child(um.rod(Vector3(x, -0.1, z), Vector3(x, h - 0.25, z), 0.045, 0.04, dark, true))
				if not stub and style == 0:
					n.add_child(um.rod(Vector3(x, -0.1, -WIDTH * 0.42), Vector3(x, top - 0.04, WIDTH * 0.42), 0.02, 0.02, dark, false))
			# Planks across.
			var planks := int(half * 2.0 / 0.085)
			for k in planks:
				var x := -half + (k + 0.5) * half * 2.0 / planks
				if gone.call(x) and rng.randf() < 0.92:
					continue
				var y := DECK + _hump(x, half, rise)
				var p := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(0.075, 0.025, WIDTH + rng.randf_range(-0.04, 0.04))
				p.mesh = box
				p.material_override = wood if rng.randf() < 0.75 else dark
				p.position = Vector3(x, y, rng.randf_range(-0.02, 0.02))
				p.rotation = Vector3(0, rng.randf_range(-0.04, 0.04), atan(_slope(x, half, rise)))
				n.add_child(p)
			# Rails.
			for side in [-1, 1]:
				var z: float = side * WIDTH * 0.47
				var posts := length + 2
				var prev := Vector3.ZERO
				for k in posts:
					var x := -half + 0.12 + k * (half * 2.0 - 0.24) / (posts - 1)
					var y := DECK + _hump(x, half, rise)
					var top := Vector3(x, y + 0.24, z)
					if gone.call(x):
						prev = Vector3.ZERO
						continue
					n.add_child(um.rod(Vector3(x, y, z), top, 0.022, 0.02, dark, true))
					if prev != Vector3.ZERO:
						if style == 2:   # a rope sagging between posts
							var mid := (prev + top) * 0.5 - Vector3(0, 0.05, 0)
							var rope := um.plain(Color("#b8a070"))
							n.add_child(um.rod(prev, mid, 0.008, 0.008, rope, false))
							n.add_child(um.rod(mid, top, 0.008, 0.008, rope, false))
						else:
							n.add_child(um.rod(prev, top, 0.018, 0.018, wood, true))
					prev = top
	if broken == 1:   # a few planks caught in the water below the gap
		for k in 4:
			var p := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.075, 0.02, WIDTH * rng.randf_range(0.5, 0.9))
			p.mesh = box
			p.material_override = wood
			p.position = Vector3(rng.randf_range(-0.8, 0.8), -0.01, rng.randf_range(-0.5, 0.5))
			p.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0, PI), 0)
			n.add_child(p)
	return n


## A log crib filled with stones: a pier for the log bridge.
func _crib(n: Node3D, x: float, h: float, wood: Material) -> void:
	var top := (DECK - 0.03) * h
	var layers := 4
	for k in layers:
		var y := -0.15 + k * (top + 0.15) / layers
		if k % 2 == 0:
			for z in [-WIDTH * 0.4, WIDTH * 0.4]:
				n.add_child(um.rod(Vector3(x - 0.2, y, z), Vector3(x + 0.2, y, z), 0.035, 0.035, wood, true))
		else:
			for dx in [-0.17, 0.17]:
				n.add_child(um.rod(Vector3(x + dx, y, -WIDTH * 0.45), Vector3(x + dx, y, WIDTH * 0.45), 0.035, 0.035, wood, true))
	var stone := um.surf("rock", Color(0.7, 0.68, 0.6), 0.5)
	for k in 5:
		n.add_child(um.blob(Vector3(0.09, 0.06, 0.09), stone, Vector3(x + rng.randf_range(-0.1, 0.1), top - 0.02, rng.randf_range(-0.25, 0.25))))


## How far the deck rises at x (a humped bridge), and its slope there.
func _hump(x: float, half: float, rise: float) -> float:
	var f := clampf(1.0 - absf(x) / half, 0.0, 1.0)
	return rise * sin(f * PI * 0.5)


func _slope(x: float, half: float, rise: float) -> float:
	return (_hump(x + 0.01, half, rise) - _hump(x - 0.01, half, rise)) / 0.02
