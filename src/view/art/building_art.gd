extends Node2D
## A building in the pixel-art style, from the art kit's bakes: the body in the team
## colour, chimney smoke, flickering lights, a waving banner and a turning vane.
## While it's being built it shows as a dark shape that brightens with progress,
## with a progress bar; the live parts start once it's done.

const Iso := preload("res://src/view/iso.gd")

var body: Sprite2D
var live: Array = []      # nodes that only run once the building is done
var glows: Array = []
var vane: Node2D
var team := Color.WHITE
var progress := 1.0
var done := true
var time := 0.0
var bar_at := Vector2.ZERO


func setup(kit, name: String, cx: int, cy: int, size: int, p_team: Color) -> void:
	team = p_team
	var info: Dictionary = kit.buildings[name]
	var centre := Iso.to_screen((cx + size * 0.5) * 1000, (cy + size * 0.5) * 1000)
	# Y-sorts by its footprint's centre, not its front corner: a unit beside either lower
	# face is lower on screen than the centre and draws in front; beside an upper face
	# it's higher and goes behind. (Sorting by the front corner hid units standing beside
	# the lower faces.) Art spilling past the footprint doesn't move the sort point.
	position = centre
	var at := centre - position
	body = kit.sprite(info.body)
	body.position = at
	body.self_modulate = Color(team.r, team.g, team.b, 1.0)
	add_child(body)
	bar_at = at + Vector2(0, 6)
	live.append(_smoke(at + info.smoke))
	_glow(at + info.lantern, 14.0, Color(1.0, 0.75, 0.35))
	for p in info.lights:
		_glow(at + p, 9.0, Color(1.0, 0.8, 0.45))
	if info.has("banner"):
		var bs := Sprite2D.new()
		bs.texture = info.banner.tex
		bs.centered = false
		bs.offset = -info.banner.origin
		bs.scale = Vector2.ONE / kit.ART_SCALE
		bs.position = at
		bs.self_modulate = Color(team.r, team.g, team.b, 1.0)
		var m := ShaderMaterial.new()
		m.shader = load("res://src/view/art/bake/banner.gdshader")
		bs.material = m
		add_child(bs)
		live.append(bs)
		vane = Node2D.new()
		vane.position = at + info.vane_at
		var vs: Sprite2D = kit.sprite(info.vane)
		vs.self_modulate = body.self_modulate
		vane.add_child(vs)
		add_child(vane)


func set_state(p_done: bool, p_progress: float) -> void:
	if p_done == done and absf(p_progress - progress) < 0.01:
		return
	done = p_done
	progress = p_progress
	body.self_modulate.a = 1.0 if done else 0.35 + 0.45 * progress
	for n in live:
		n.visible = done
	for g in glows:
		g.node.visible = done
	queue_redraw()


func _process(delta: float) -> void:
	time += delta
	for g in glows:
		var f := 0.8 + 0.2 * sin(time * 7.0 + g.phase) * sin(time * 2.3 + g.phase * 2.0)
		g.node.modulate = Color(g.base.r * f, g.base.g * f, g.base.b * f, 1.0)
	if vane and done:
		vane.scale.x = cos(time * 1.3)


func _draw() -> void:
	if done:
		return
	var w := 40.0
	draw_rect(Rect2(bar_at - Vector2(w * 0.5, 0), Vector2(w, 4)), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bar_at - Vector2(w * 0.5, 0) + Vector2(1, 1), Vector2((w - 2) * progress, 2)), Color("#f2c94c"))


func _smoke(at: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = at
	p.amount = 10
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.direction = Vector2(0.2, -1)
	p.spread = 12.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector2(2.0, -1.0)
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.2
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.5))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(0.8, 0.8, 0.78, 0.0), Color(0.78, 0.78, 0.76, 0.55), Color(0.7, 0.7, 0.7, 0.0)])
	fade.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	p.color_ramp = fade
	p.texture = _dot()
	add_child(p)
	return p


func _glow(at: Vector2, radius: float, c: Color) -> void:
	var s := Sprite2D.new()
	s.texture = _dot()
	s.position = at
	s.scale = Vector2.ONE * radius / 16.0
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	add_child(s)
	glows.append({"node": s, "base": c, "phase": randf() * 10.0})


static var _dot_tex: GradientTexture2D


static func _dot() -> GradientTexture2D:
	if _dot_tex == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.0)])
		_dot_tex = GradientTexture2D.new()
		_dot_tex.gradient = g
		_dot_tex.fill = GradientTexture2D.FILL_RADIAL
		_dot_tex.fill_from = Vector2(0.5, 0.5)
		_dot_tex.fill_to = Vector2(1.0, 0.5)
		_dot_tex.width = 32
		_dot_tex.height = 32
	return _dot_tex
