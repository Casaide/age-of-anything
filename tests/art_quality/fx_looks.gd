extends Node2D
## Art-quality study, direction 4: the energy-weapon looks fx_study.gd compares, drawn over a frozen
## volley (the shots copied from the game's combat_fx). Not in the game.
## Two layers: `ground` (scorch marks, under the units: the study moves it below the y-sorted layer)
## and `glow` (added light, over everything: bolts, flares, light pools that light the units too).

const ArtKit := preload("res://src/view/art/art_kit.gd")
const PartShape := preload("res://src/part_shape.gd")

var shots: Array = []
var look := "today"
var ground := Node2D.new()
var glow := Node2D.new()

const CORE := Color("#f4ffff")
const CYAN := Color("#38c8ff")
const DEEP := Color("#1a4cc8")
const PLASMA := Color("#9cff6a")
const PLASMA_DEEP := Color("#2a9a40")
const SCORCH := Color(0.09, 0.07, 0.05, 0.75)
const EMBER := Color("#ff9a3a")


func _ready() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	glow.z_index = 60
	add_child(glow)
	ground.draw.connect(_draw_ground)
	glow.draw.connect(_draw_glow)


func queue_all() -> void:
	ground.queue_redraw()
	glow.queue_redraw()


func _px() -> float:
	return 1.0 / ArtKit.ART_SCALE


## One art pixel at p (snapped to the art grid).
func _pix(n: CanvasItem, p: Vector2, c: Color) -> void:
	var s := _px()
	n.draw_rect(Rect2((p / s).floor() * s, Vector2(s, s)), c)


func _at(s: Dictionary) -> Vector2:
	return _from(s).lerp(s.to, clampf(s.t / s.dur, 0.0, 1.0))


## Where a shot leaves: its shooter's muzzle as drawn now (the weapon's baked tip, PartShape.rigs "tip" for
## its facing, through the weapon sprite's transform), else where the game launched it (the body).
func _from(s: Dictionary) -> Vector2:
	var v = s.get("shooter")
	if v == null or not is_instance_valid(v) or v.weapon == null:
		return s.from
	var w: Node2D = v.weapon
	var rig: Dictionary = PartShape.rigs.get(w.part_id + PartShape.facing_suffix(v.facing_k), PartShape.rigs.get(w.part_id, {}))
	return get_global_transform().affine_inverse() * (w.get_global_transform() * rig.get("tip", Vector2.ZERO))


static func _h(v: Vector2, k: int) -> float:
	return float(absi(int(v.x * 131.0) * 73856093 ^ int(v.y * 137.0) * 19349663 ^ k * 83492791) % 1000) / 1000.0


func _draw_ground() -> void:
	if look == "today":
		return
	var s := _px()
	for i in shots.size():
		var sh: Dictionary = shots[i]
		if _h(sh.to, 1) > (0.5 if look == "pixel" else 0.75 if look == "beam" else 0.35):
			continue
		var c: Vector2 = sh.to + Vector2(_h(sh.to, 2) - 0.5, _h(sh.to, 3) - 0.5) * 10.0 + Vector2(0, 2)
		var r := (3.5 if look == "plasma" else 2.5) + _h(sh.to, 4) * 1.5
		for y in range(-int(r), int(r) + 1):
			for x in range(-int(r * 2.0), int(r * 2.0) + 1):
				var d := Vector2(x / 2.0, y).length() / r
				var p := c + Vector2(x, y) * s
				if d < 0.6 + 0.4 * _h(p, 5):
					_pix(ground, p, SCORCH if d < 0.55 else Color(SCORCH, 0.4))


func _draw_glow() -> void:
	match look:
		"pixel": _pixel()
		"beam": _beam()
		"plasma": _plasma()


func _pixel() -> void:
	var s := _px()
	for sh in shots:
		var k: float = sh.t / sh.dur
		var p := _at(sh)
		var dir: Vector2 = (sh.to - _from(sh)).normalized()
		var side := Vector2(0, 1) if absf(dir.x) > absf(dir.y) else Vector2(1, 0)
		var n := 14
		for i in n:   # the bolt: a white core two pixels thick, a cyan band each side, a dithered blue edge
			var q := p - dir * i * s * 0.9
			var fade := 1.0 - 0.7 * float(i) / n
			_pix(glow, q, Color(CORE, fade))
			_pix(glow, q + side * s, Color(CORE, 0.8 * fade))
			_pix(glow, q - side * s, Color(CYAN, fade))
			_pix(glow, q + side * 2.0 * s, Color(CYAN, fade))
			if i % 2 == 0:
				_pix(glow, q + side * 3.0 * s, Color(DEEP, 0.9 * fade))
				_pix(glow, q - side * 2.0 * s, Color(DEEP, 0.9 * fade))
		_pool(p + Vector2(0, 6), 4.0, 0.18, true)   # its light on the ground below
		if k > 0.7:   # the hit: a starburst and a pool of light that lights who it hit
			var c: Vector2 = sh.to
			for a in 8:
				var d := Vector2.from_angle(a * PI / 4.0)
				var l := 4 if a % 2 == 0 else 2
				for j in l:
					_pix(glow, c + d * j * s, Color(CORE if j < 2 else CYAN, 1.0 - float(j) / (l + 1)))
			_pool(c, 9.0, 0.3, true)
	_embers()


func _beam() -> void:
	for sh in shots:
		var k: float = sh.t / sh.dur
		if k > 0.6:
			continue   # a beam is on for a moment of the shot's flight
		var a: Vector2 = _from(sh)
		var b: Vector2 = sh.to
		var flick := 0.75 + 0.25 * _h(a, 7)
		glow.draw_line(a, b, Color(CYAN, 0.15 * flick), 3.0)
		glow.draw_line(a, b, Color(CYAN, 0.45 * flick), 1.4)
		glow.draw_line(a, b, Color(CORE, 0.95), 0.6)
		glow.draw_circle(a, 2.0, Color(CYAN, 0.6))
		glow.draw_circle(b, 3.2, Color(CYAN, 0.55))
		glow.draw_circle(b, 1.4, CORE)
		_pool(b, 10.0, 0.22, false)
	_embers()


func _plasma() -> void:
	var s := _px()
	for sh in shots:
		var k: float = sh.t / sh.dur
		var p := _at(sh)
		var dir: Vector2 = (sh.to - _from(sh)).normalized()
		for i in range(2, 16):   # its trail: pixels thrown off behind it, thinning
			var q := p - dir * i * s * 1.3 + Vector2(0, (_h(p, i) - 0.5) * 3.0 * s)
			_pix(glow, q, Color(PLASMA, 0.85 * (1.0 - i / 16.0)))
		for y in range(-3, 4):   # the ball: a white heart in a green shell
			for x in range(-3, 4):
				var d := Vector2(x, y).length()
				if d <= 3.2:
					_pix(glow, p + Vector2(x, y) * s, CORE if d < 1.5 else (PLASMA if d < 2.5 else Color(PLASMA_DEEP, 0.9)))
		_pool(p + Vector2(0, 7), 5.0, 0.2, true)
		if k > 0.75:   # the splash: a ring of pixels going out
			var r := 3.0 + (k - 0.75) * 24.0
			for a in 20:
				var d := Vector2.from_angle(a * TAU / 20.0) * Vector2(1.0, 0.5)
				_pix(glow, sh.to + d * r * s * 1.5, Color(PLASMA, 0.85))
			_pool(sh.to, 11.0, 0.3, true)
	_embers()


## A pool of added light on the ground (and on whoever stands in it): dithered on the art grid or smooth.
func _pool(c: Vector2, r: float, a: float, pixel: bool) -> void:
	var col := PLASMA if look == "plasma" else CYAN
	if not pixel:
		for k in 4:
			var f := 1.0 - k / 4.0
			glow.draw_set_transform(c, 0.0, Vector2(1.0, 0.5))
			glow.draw_circle(Vector2.ZERO, r * f, Color(col, a * 0.35))
			glow.draw_set_transform(Vector2.ZERO)
		return
	var s := _px()
	var n := int(r / s)
	for y in range(-n / 2, n / 2 + 1):
		for x in range(-n, n + 1):
			var d := Vector2(x, y * 2.0).length() / n
			if d > 1.0:
				continue
			var band := a * (1.0 if d < 0.4 else 0.6 if d < 0.7 else 0.3)
			if d >= 0.7 and (x + y) % 2 == 0:
				continue
			_pix(glow, c + Vector2(x, y) * s, Color(col, band))


## Embers in the scorch marks: a few warm pixels.
func _embers() -> void:
	var s := _px()
	for sh in shots:
		if _h(sh.to, 1) > (0.5 if look == "pixel" else 0.75 if look == "beam" else 0.35):
			continue
		var c: Vector2 = sh.to + Vector2(_h(sh.to, 2) - 0.5, _h(sh.to, 3) - 0.5) * 10.0 + Vector2(0, 2)
		for e in 3:
			_pix(glow, c + Vector2(_h(c, e + 10) - 0.5, (_h(c, e + 20) - 0.5) * 0.5) * 4.0, Color(EMBER, 0.8))
