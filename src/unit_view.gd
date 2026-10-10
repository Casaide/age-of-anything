extends Node2D
## A composed unit: recipe -> node tree of parts on sockets, plus cheap
## procedural animation (walk cycle, bob, breathing, hover, attack lunge).
## Purely visual. The sim (next milestone) will own positions; for the Race Lab
## the view wanders around on its own.

const PartShape := preload("res://src/part_shape.gd")
const Rng := preload("res://src/rng.gd")

const SOCKET_FOR_SLOT := {"hand_r": "hand_r", "hand_l": "hand_l", "head_gear": "top", "torso": "torso", "back": "back"}
const Z_FOR_SLOT := {"back": -3, "torso": 1, "head_gear": 3, "hand_l": 4, "hand_r": 5}

var recipe: Dictionary
var visual: Node2D        # flipped for facing
var bob: Node2D           # moves up/down while walking or hovering
var legs: Array = []      # [{node, phase}]
var breathing: Array = []
var weapon: Node2D
var weapon_rest := Vector2.ZERO
var flying := false
var unit_scale := 1.0
var style := ""           # how parts are drawn (see part_shape.gd); set before build()
var pose_steps := 0       # > 0: stepped pixel-art animation with this many poses per walk cycle
var art_px := 0.0         # stepped mode: art pixels per global unit, for snapping to whole pixels
const STEP_FPS := 8.0
var facing := 1.0

# animation + wander state (cosmetic only, so a local RNG is fine here)
var noise := RandomNumberGenerator.new()
var time := 0.0
var phase := 0.0
var walking := false
var attack_t := 0.0
var speed_px := 30.0
var area := Rect2()
var target := Vector2.ZERO
var pause := 0.0


func build(r: Dictionary, lib, team: Color, speed := 10) -> void:
	recipe = r
	noise.seed = Rng.hash_string(JSON.stringify(r, "", true))
	time = noise.randf() * 10.0
	unit_scale = float(r.scale) / 100.0
	speed_px = float(speed) * 3.0

	var shadow := PartShape.new()   # a plain soft shadow in every style
	shadow.outline = false
	shadow.setup([{"t": "ellipse", "c": [0, 0], "r": [13, 3.5], "ch": "shadow"}], {"shadow": Color(0, 0, 0, 0.28)})
	add_child(shadow)

	visual = Node2D.new()
	add_child(visual)
	bob = Node2D.new()
	visual.add_child(bob)

	var colours := colours_for(lib, r.skin, r.family, team)
	if r.has("mount"):
		var m: Dictionary = r.mount
		var mc: Dictionary = lib.creatures[m.creature]
		var mount_colours := colours_for(lib, m.skin, r.family, team)
		var mount_rig := _make_rig(lib, mc.body, "" if m.fused else mc.head, mount_colours, bob, true)
		for slot in m.parts:
			_attach(lib, mount_rig, slot, m.parts[slot], mount_colours)
		var seat := Node2D.new()
		seat.set_meta("z", 2)
		if m.fused:
			seat.position = Vector2(9, -12)
		else:
			seat.position = mount_rig.sockets.get("seat", Vector2(0, -20)) + Vector2(0, 6)
			seat.scale = Vector2(0.8, 0.8)
		bob.add_child(seat)
		var rider := _make_rig(lib, r.body, r.head, colours, seat, false)
		for slot in r.parts:
			_attach(lib, rider, slot, r.parts[slot], colours)
		flying = m.parts.has("back") and "flying" in lib.part(m.parts.back).tags
	else:
		var rig := _make_rig(lib, r.body, r.head, colours, bob, true)
		for slot in r.parts:
			_attach(lib, rig, slot, r.parts[slot], colours)
	var rides_unwinged: bool = r.has("mount") and not r.mount.fused
	if not rides_unwinged and r.parts.has("back") and "flying" in lib.part(r.parts.back).tags:
		flying = true

	shadow.scale = Vector2(unit_scale, unit_scale) * (0.8 if flying else 1.0)
	if style == "baked":
		# A firmer pixel shadow in the buildings' shadow colour, falling the way their light does.
		shadow.setup([{"t": "ellipse", "c": [3, 1], "r": [15, 4.5], "ch": "shadow"}], {"shadow": Color(0.06, 0.05, 0.03, 0.42)})
	_sort_layers(self)
	_face(facing)


## Parts are layered by child order (their "z" meta), not z_index: z_index is global,
## so a part with z above 0 would draw over every y-sorted building and unit.
func _sort_layers(n: Node) -> void:
	var kids := n.get_children()
	var order := []
	for i in kids.size():
		order.append([float(kids[i].get_meta("z", 0)), i, kids[i]])
	order.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for i in order.size():
		n.move_child(order[i][2], i)
		_sort_layers(order[i][2])


func _shape() -> PartShape:
	var s := PartShape.new()
	s.style = style
	return s


static func colours_for(lib, skin: String, family: String, team: Color) -> Dictionary:
	var c := {}
	for k in lib.palettes.materials:
		c[k] = Color(lib.palettes.materials[k])
	var sk: Array = lib.palettes.skins[skin]
	c.skin = Color(sk[0])
	c.skin2 = Color(sk[1])
	var cloth: Array = lib.families[family].cloth
	c.cloth = Color(cloth[0])
	c.cloth2 = Color(cloth[1])
	c.team = team
	return c


func _make_rig(lib, body_id: String, head_id: String, colours: Dictionary, parent: Node2D, with_legs: bool) -> Dictionary:
	var body: Dictionary = lib.part(body_id)
	var root := Node2D.new()
	parent.add_child(root)
	# Baked parts from hand-built models bring their own sockets (projected by the bake camera).
	var rig: Dictionary = PartShape.rigs.get(body_id, {}) if style == "baked" else {}
	var sockets := {}
	for k in body.sockets:
		sockets[k] = PartShape.v2(body.sockets[k])
	if rig.has("sockets"):
		sockets = rig.sockets.duplicate()

	if with_legs and body.has("legs"):
		var leg_part: Dictionary = lib.part(body.legs.part)
		for a in rig.get("anchors", body.legs.anchors):
			var leg := _shape()
			leg.pin = true
			leg.part_id = body.legs.part
			leg.setup(leg_part.shapes, colours)
			leg.position = Vector2(float(a[0]), float(a[1]))
			leg.set_meta("z", 1 if float(a[3]) > 0.0 else -2)
			if a.size() > 4 and int(a[4]) == 1:
				leg.scale.x = -1.0
			if rig.has("anchors") and float(a[3]) < 0.0:
				leg.modulate = Color(0.78, 0.78, 0.78)   # the far leg sits in shadow
			root.add_child(leg)
			legs.append({"node": leg, "phase": float(a[2])})

	var body_node := _shape()
	body_node.part_id = body_id
	body_node.setup(body.shapes, colours)
	root.add_child(body_node)
	breathing.append(body_node)
	if rig.get("front", false):
		# The body's near arm, drawn above torso armour and below what the hands hold.
		var arm := _shape()
		arm.part_id = body_id
		arm.front = true
		arm.setup(body.shapes, colours)
		arm.set_meta("z", 1.5)
		root.add_child(arm)

	if head_id != "":
		var head: Dictionary = lib.part(head_id)
		var head_node := _shape()
		head_node.pin = true
		head_node.part_id = head_id
		head_node.setup(head.shapes, colours)
		head_node.position = sockets.head
		head_node.set_meta("z", 2)
		root.add_child(head_node)
		var head_rig: Dictionary = PartShape.rigs.get(head_id, {}) if style == "baked" else {}
		sockets["top"] = sockets.head + (head_rig.sockets.top if head_rig.has("sockets") else PartShape.v2(head.sockets.top))

	var torso_scale: Vector2 = rig.get("torso_scale", PartShape.v2(body.get("torso_scale", [1, 1])))
	return {"root": root, "sockets": sockets, "torso_scale": torso_scale}


func _attach(lib, rig: Dictionary, slot: String, part_id: String, colours: Dictionary) -> void:
	var socket: String = SOCKET_FOR_SLOT[slot]
	if not rig.sockets.has(socket):
		return
	var p: Dictionary = lib.part(part_id)
	var node := _shape()
	node.part_id = part_id
	node.setup(p.shapes, colours)
	node.position = rig.sockets[socket]
	node.set_meta("z", Z_FOR_SLOT[slot])
	if slot == "torso":
		node.scale = rig.torso_scale
	rig.root.add_child(node)
	if slot == "hand_r":
		weapon = node
		weapon_rest = node.position


func _face(dir: float) -> void:
	facing = dir
	visual.scale = Vector2(unit_scale * facing, unit_scale)


func face(dir: float) -> void:
	_face(1.0 if dir >= 0.0 else -1.0)


func flourish() -> void:
	attack_t = 0.35


## Let the unit mill about inside a rectangle (Race Lab only).
func wander_in(rect: Rect2) -> void:
	area = rect
	target = position
	pause = noise.randf_range(0.0, 1.5)


func _process(delta: float) -> void:
	time += delta
	if area.has_area():
		_wander(delta)

	# Stepped (pixel-art) mode: a few poses per cycle and whole pixels, not smooth motion.
	var stepped := pose_steps > 0
	var t := floorf(time * STEP_FPS) / STEP_FPS if stepped else time
	var stride := 1.0 if walking else 0.0
	if walking:
		phase += delta * speed_px * 0.25
	var ph := phase
	if stepped:
		var step := TAU / pose_steps
		ph = floorf(phase / step) * step
	for leg in legs:
		leg.node.rotation = sin(ph + leg.phase) * 0.5 * stride

	var hover := 0.0
	if flying:
		hover = -9.0 + sin(t * 3.0) * 2.0
	bob.position.y = hover - absf(sin(ph)) * 1.5 * stride

	if stepped:
		# Breathe by a pixel, not by stretching the sprite (stretched pixels shimmer).
		bob.position.y -= (1.0 / maxf(art_px, 1.0)) if fmod(t, 1.6) < 0.8 and stride == 0.0 else 0.0
	else:
		var breath := 1.0 + sin(time * 2.4) * 0.03
		for b in breathing:
			b.scale.y = breath

	if weapon:
		if attack_t > 0.0:
			attack_t -= delta
			var a := 1.0 - maxf(attack_t, 0.0) / 0.35
			if stepped:
				a = floorf(a * 5.0) / 5.0
			var k := sin(a * PI)
			weapon.position = weapon_rest + Vector2(6.0 * k, -2.0 * k)
			weapon.rotation = -0.4 * k
		else:
			weapon.position = weapon_rest
			weapon.rotation = 0.0

	if stepped and art_px > 0.0:
		# Sit on whole art pixels: offset the drawing so its global position snaps.
		var g := global_position
		var px := 1.0 / art_px
		var snapped := Vector2(roundf(g.x / px) * px, roundf(g.y / px) * px)
		visual.position = (snapped - g) / maxf(global_transform.get_scale().x, 0.0001)


func _wander(delta: float) -> void:
	if pause > 0.0:
		pause -= delta
		walking = false
		if pause <= 0.0:
			target = Vector2(noise.randf_range(area.position.x, area.end.x), noise.randf_range(area.position.y, area.end.y))
		return
	var d := target - position
	if d.length() < 2.0:
		walking = false
		pause = noise.randf_range(0.6, 2.8)
		if noise.randf() < 0.35:
			flourish()
		return
	walking = true
	position += d.normalized() * minf(speed_px * delta, d.length())
	if absf(d.x) > 1.0:
		face(d.x)
