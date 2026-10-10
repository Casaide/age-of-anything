extends Node2D
## The sampler scene, high-fidelity pre-rendered: every tile, prop, building and
## unit part is a sprite baked from a detailed 3D model (see baker.gd). Buildings
## get a little life from live parts animated in 2D (banner, smoke, glowing
## windows, a weathervane); frogs are baked parts posed by procedural animation.

const Iso := preload("res://src/view/iso.gd")
const Diorama2D := preload("res://scenes/style_sampler/diorama_2d.gd")
const Models := preload("res://scenes/style_sampler/hifi/models.gd")
const Baker := preload("res://scenes/style_sampler/hifi/baker.gd")
const Materials := preload("res://scenes/style_sampler/hifi/materials.gd")

const S := 1.0 / Baker.SCALE
const UNIT_SCALE := 0.85   # units a touch smaller than "true" scale, as the genre does it
const W := 8
const H := 8

var models := Models.new()
var baker: Baker
var ground: Node2D
var layer: Node2D
var team := Color.BLUE
var frogs: Array = []      # [{root, parts: {name: Node2D}, from, to, t}]
var glows: Array = []      # [{node, phase}]
var vanes: Array = []
var time := 0.0
var ready_now := false


func centre() -> Vector2:
	return Iso.to_screen(W * 500, H * 500)


func build(lib) -> void:
	team = Color(lib.palettes.teams[0])
	baker = Baker.new()
	add_child(baker)
	ground = Node2D.new()
	ground.draw.connect(func(): ground.draw_rect(Rect2(-3000, -3000, 6000, 6000), Color("#2b2620")))
	add_child(ground)
	layer = Node2D.new()
	layer.y_sort_enabled = true
	add_child(layer)
	await _wait_for_textures()

	var grass := []
	for k in 3:
		grass.append(await baker.bake(models.grass_tile(100 + k), [Vector3.ZERO]))
	var swamp := []
	for k in 2:
		swamp.append(await baker.bake(models.swamp_tile(200 + k), [Vector3.ZERO]))
	var reeds := []
	for k in 2:
		reeds.append(await baker.bake(models.reeds(300 + k), [Vector3.ZERO]))
	var bush := await baker.bake(models.bug_bush(400), [Vector3.ZERO])

	# Ground, back to front, then props on their tiles.
	for d in W + H - 1:
		for y in H:
			var x := d - y
			if x < 0 or x >= W:
				continue
			var ch := _at(x, y)
			var b: Dictionary = swamp[(x * 7 + y) % 2] if ch == "s" else grass[(x * 5 + y * 3) % 3]
			ground.add_child(_sprite(b, Iso.to_screen(x * 1000 + 500, y * 1000 + 500)))
			if ch == "r" or ch == "b":
				var prop := _sprite(reeds[(x + y) % 2] if ch == "r" else bush, Vector2.ZERO)
				var holder := Node2D.new()
				holder.position = Iso.to_screen(x * 1000 + 500, y * 1000 + 500)
				holder.add_child(prop)
				layer.add_child(holder)

	await _building(models.town_center(team), 4, 0, 3)
	await _building(models.stilt_house(team), 6, 3, 2)
	var frog_parts := {}
	var spec := models.frog_worker(team)
	for name in spec.order:
		frog_parts[name] = await baker.bake(spec.parts[name], [Vector3.ZERO, spec.pivots[name]])
	_frog(frog_parts, spec.order, Vector2(1.6, 3.6), Vector2(3.4, 4.4), 0.0)
	_frog(frog_parts, spec.order, Vector2(3.6, 5.2), Vector2(2.2, 4.8), 1.3)
	baker.queue_free()
	ready_now = true


func _at(x: int, y: int) -> String:
	var row: String = Diorama2D.ROWS[y]
	return row[x] if x < row.length() and row[x] != " " else "g"


func _wait_for_textures() -> void:
	# Materials use NoiseTexture2D, which generates on a thread: wait for them all.
	for name in ["wood", "thatch", "mud", "stone", "grass", "swamp", "frog", "weave"]:
		var m: StandardMaterial3D = models.mats.get_mat(name)
		for t in [m.albedo_texture, m.normal_texture]:
			while t.get_image() == null:
				await get_tree().process_frame


## A sprite from a bake, drawn so its first projected point sits at `at`.
func _sprite(b: Dictionary, at: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = b.tex
	s.centered = false
	s.offset = -b.points[0]
	s.scale = Vector2(S, S)
	s.position = at
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return s


func _building(spec: Dictionary, cx: int, cy: int, size: int) -> void:
	var centre_px := Iso.to_screen((cx + size * 0.5) * 1000, (cy + size * 0.5) * 1000)
	var front := Iso.to_screen((cx + size) * 1000, (cy + size) * 1000)
	var holder := Node2D.new()   # sits at the front corner so it y-sorts with units
	holder.position = front
	layer.add_child(holder)
	var pts: Array = [Vector3.ZERO, spec.smoke, spec.lantern]
	pts.append_array(spec.lights)
	var body := await baker.bake(spec.body, pts)
	holder.add_child(_sprite(body, centre_px - front))
	var to_local := func(p: Vector2) -> Vector2: return centre_px - front + (p - body.points[0]) * S
	_smoke(holder, to_local.call(body.points[1]))
	_glow(holder, to_local.call(body.points[2]), 26.0, Color(1.0, 0.75, 0.35))
	for k in spec.lights.size():
		_glow(holder, to_local.call(body.points[3 + k]), 18.0, Color(1.0, 0.8, 0.45))
	if spec.has("banner"):
		var ban := await baker.bake(spec.banner, [Vector3.ZERO, spec.banner_pivot])
		var bs := _sprite(ban, centre_px - front)
		var m := ShaderMaterial.new()
		m.shader = load("res://scenes/style_sampler/hifi/banner.gdshader")
		bs.material = m
		holder.add_child(bs)
		var vane := await baker.bake(spec.vane, [Vector3.ZERO, spec.vane_pivot])
		var pivot := Node2D.new()
		pivot.position = centre_px - front + (vane.points[1] - vane.points[0]) * S
		var vs := _sprite(vane, Vector2.ZERO)
		vs.offset = -vane.points[1]
		pivot.add_child(vs)
		holder.add_child(pivot)
		vanes.append(pivot)


func _smoke(parent: Node2D, at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.amount = 14
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.direction = Vector2(0.2, -1)
	p.spread = 12.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector2(3.0, -1.5)
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.25
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(0.85, 0.85, 0.85, 0.0), Color(0.8, 0.8, 0.8, 0.45), Color(0.7, 0.7, 0.7, 0.0)])
	fade.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	p.color_ramp = fade
	p.texture = _soft_dot(64)
	parent.add_child(p)


func _glow(parent: Node2D, at: Vector2, radius: float, c: Color) -> void:
	var s := Sprite2D.new()
	s.texture = _soft_dot(64)
	s.position = at
	s.scale = Vector2.ONE * radius / 32.0
	s.modulate = c
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	parent.add_child(s)
	glows.append({"node": s, "phase": randf() * 10.0, "base": c})


func _soft_dot(size: int) -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t


func _frog(baked: Dictionary, order: Array, from: Vector2, to: Vector2, t0: float) -> void:
	var root := Node2D.new()
	layer.add_child(root)
	var shadow := Sprite2D.new()
	shadow.texture = _soft_dot(64)
	shadow.modulate = Color(0, 0, 0, 0.8)
	shadow.scale = Vector2(0.55, 0.25)
	root.add_child(shadow)
	var parts := {}
	for name in order:
		var b: Dictionary = baked[name]
		var pivot := Node2D.new()
		pivot.position = (b.points[1] - b.points[0]) * S
		var s := _sprite(b, Vector2.ZERO)
		s.offset = -b.points[1]
		pivot.add_child(s)
		root.add_child(pivot)
		parts[name] = {"node": pivot, "rest": pivot.position}
	frogs.append({"root": root, "parts": parts, "from": from, "to": to, "t": t0})


func _process(delta: float) -> void:
	if not ready_now:
		return
	time += delta
	for g in glows:
		var f := 0.85 + 0.15 * sin(time * 7.0 + g.phase) * sin(time * 2.3 + g.phase * 2.0)
		g.node.modulate = Color(g.base.r * f, g.base.g * f, g.base.b * f, 1.0)
	for v in vanes:
		v.scale.x = cos(time * 1.3)
	for f in frogs:
		f.t += delta * 0.09
		var k := pingpong(f.t, 1.0)
		var a: Vector2 = f.from.lerp(f.to, smoothstep(0.0, 1.0, k))
		var going := fmod(f.t, 2.0) < 1.0
		var dir: Vector2 = (f.to - f.from) * (1.0 if going else -1.0)
		f.root.position = Iso.to_screen(a.x * 1000, a.y * 1000)
		f.root.scale = Vector2(UNIT_SCALE if (dir.x - dir.y) >= 0.0 else -UNIT_SCALE, UNIT_SCALE)
		var step := sin(time * 8.0 + f.t * 5.0)
		var bob := absf(step) * 2.0
		for name in f.parts:
			var p: Dictionary = f.parts[name]
			p.node.position = p.rest + Vector2(0, -bob)
		f.parts.leg_near.node.rotation = step * 0.35
		f.parts.leg_far.node.rotation = -step * 0.35
		f.parts.arm_near.node.rotation = -step * 0.25
		f.parts.arm_far.node.rotation = step * 0.25
		f.parts.head.node.rotation = sin(time * 4.0 + f.t) * 0.04
		f.parts.leg_near.node.position = f.parts.leg_near.rest
		f.parts.leg_far.node.position = f.parts.leg_far.rest
