extends Node2D
## A composed unit: recipe -> node tree of parts on sockets, plus cheap
## procedural animation: a walk cycle that suits the body (two legs, four, six or
## eight; flyers hover and flap), work per job (forage, chop, build), idle fidgets,
## breathing and the attack lunge. Cosmetic only: nothing here feeds the sim.
## Purely visual. The sim (next milestone) will own positions; for the Race Lab
## the view wanders around on its own.

const PartShape := preload("res://src/part_shape.gd")
const UnitModels := preload("res://scenes/art_pixel/unit_models.gd")
static var UnitModelsCheck = UnitModels.new()   # which parts have hand-built models
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
var weapon_rot := 0.0     # at rest: couched forward on a harness, else upright
var _hold_suffix := ""
var _clinging := false    # building a riding creature: legs that hug the mount    # "@hold" on the body being built (its arm posed for its weapon)
var harnessed := false    # no arms: gear rides on a harness, work is done with the whole body
const COUCH := Vector2(1.0, -0.3)   # a couched weapon points forward, a little up
const HOP_HEIGHT := 7.0   # part units: how high a hopper leaves the ground
const WITHERS_DROP := Vector2(2.0, 5.0)    # part units: wings on a mount start at its shoulders...
const WITHERS_TILT := -0.5                 # ...and lie back along it, folded, clear of the rider
const WITHERS_SCALE := 2.0                 # a horse's wings are a horse's size (Dominic)
var head_node: Node2D     # the unit's own head (the rider's, when mounted)
var back_node: Node2D     # what's on its back (wings flap)
var job := ""             # "", "forage", "chop" or "build": set by the view each frame
var struck := false       # this frame the tool landed (or a pick was made): the view plays its sound
var _work_p := 0.0        # where in the work cycle it was last frame
var gait := {}            # walk cycle for the body: swing, cadence, bob, rock
var idle_kind := ""
var idle_left := 0.0
var idle_wait := 2.0
var flying := false
var unit_scale := 1.0
var pose_steps := 0       # > 0: stepped pixel-art animation with this many poses per walk cycle
var art_px := 0.0         # stepped mode: art pixels per global unit, for snapping to whole pixels
const STEP_FPS := 8.0
## The shadow: a firmer pixel shadow in the buildings' shadow colour, falling
## the way their light does (baked into the atlas as part "unit_shadow").
const SHADOW_SHAPES := [{"t": "ellipse", "c": [3, 1], "r": [15, 4.5], "ch": "shadow"}]
const SHADOW_COLOURS := {"shadow": Color(0.06, 0.05, 0.03, 0.42)}
var facing := 1.0
var facing_k := 0         # which of the 8 baked facings it's drawn in (0: the classic three-quarter view)
var _facing_body := ""    # the rig its facings are picked by (its body, or its mount's)
var _built := []          # build()'s arguments, to rebuild in another facing
const FACINGS := 8
const FACING_HOLD := 0.12 # a new facing must fit this much better to take over (no flicker)

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
	_built = [r, lib, team, speed]
	recipe = r
	noise.seed = Rng.hash_string(JSON.stringify(r, "", true))
	time = noise.randf() * 10.0
	unit_scale = float(r.scale) / 100.0
	speed_px = float(speed) * 3.0

	var shadow := PartShape.new()
	shadow.part_id = "unit_shadow"
	shadow.setup(SHADOW_SHAPES, SHADOW_COLOURS)
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
		# A fused mount (a centaur's horse half) has its own body, without a neck.
		var mount_body: String = mc.get("fused_body", mc.body) if m.fused else mc.get("mount_body", mc.body)
		var mount_rig := _make_rig(lib, mount_body, "" if m.fused else mc.head, mount_colours, bob, true)
		_facing_body = mount_body
		for slot in m.parts:
			_attach(lib, mount_rig, slot, m.parts[slot], mount_colours)
		var seat := Node2D.new()
		seat.set_meta("z", 2)
		# A creature with no arms (a spider, a beetle) rides low and small, its belly in
		# the saddle and its near legs hugging the mount's flank; people sit up.
		_clinging = not m.fused and PartShape.rigs.get(r.body, {}).get("carry", "") == "harness"
		if m.fused:
			seat.position = mount_rig.sockets.seat
		elif _clinging:
			seat.position = mount_rig.sockets.get("seat", Vector2(0, -20)) + Vector2(-1, 9)
			seat.scale = Vector2(0.6, 0.6)
		else:
			seat.position = mount_rig.sockets.get("seat", Vector2(0, -20)) + Vector2(0, 6)
			seat.scale = Vector2(0.8, 0.8)
		bob.add_child(seat)
		var rider := _make_rig(lib, r.body, r.head, colours, seat, _clinging, r.parts.get("hand_r", ""))
		_clinging = false
		for slot in r.parts:
			_attach(lib, rider, slot, r.parts[slot], colours)
		flying = m.parts.has("back") and "flying" in lib.part(m.parts.back).tags
	else:
		var rig := _make_rig(lib, r.body, r.head, colours, bob, true, r.parts.get("hand_r", ""))
		_facing_body = r.body + _hold_suffix
		for slot in r.parts:
			_attach(lib, rig, slot, r.parts[slot], colours)
	var rides_unwinged: bool = r.has("mount") and not r.mount.fused
	if not rides_unwinged and r.parts.has("back") and "flying" in lib.part(r.parts.back).tags:
		flying = true

	# A figure on two legs casts a narrower shadow than a mount or a many-legged beast.
	shadow.scale = Vector2(unit_scale, unit_scale) * (0.8 if flying else 1.0) * (1.0 if r.has("mount") or legs.size() > 2 else 0.65)
	gait = _gait(legs.size(), flying)
	# A creature can move its own way (data: creatures.json "gait"): frogs hop. A rider's
	# mount decides, so a frog on a beetle scuttles.
	if not r.has("mount") and not flying and lib.creatures.get(r.get("creature", ""), {}).get("gait", "") == "hop":
		gait = {"hop": true, "swing": 0.0, "cadence": 0.55, "bob": 0.0, "rock": 0.0, "rock_rate": 1.0}
	idle_wait = noise.randf_range(1.0, 5.0)
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
	return PartShape.new()


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


## How a weapon is held, from its tags: the body is baked with its near arm in that
## pose (unit_models.arm_pose). Spears, swords, lances and tools are held low.
static func hold_for(tags: Array) -> String:
	if "javelin" in tags:
		return "throw"
	if "poison" in tags and "ranged" in tags:
		return "mouth"
	if "sling" in tags:
		return "overhead"
	if "gun" in tags or ("bow" in tags and "heavy" in tags):
		return "aim"
	if "bow" in tags:
		return "draw"
	if "spear" in tags and "heavy" in tags:
		return "shoulder"
	return "low"


func _make_rig(lib, body_id: String, head_id: String, colours: Dictionary, parent: Node2D, with_legs: bool, hand_r := "") -> Dictionary:
	var hold := hold_for(lib.part(hand_r).tags) if hand_r != "" else "low"
	_hold_suffix = "" if hold == "low" else "@" + hold
	var body: Dictionary = lib.part(body_id)
	var root := Node2D.new()
	parent.add_child(root)
	# Baked parts from hand-built models bring their own sockets (projected by the bake camera).
	var rig: Dictionary = PartShape.rigs.get(body_id + _hold_suffix + PartShape.facing_suffix(facing_k),
		PartShape.rigs.get(body_id + _hold_suffix, {}))
	var sockets := {}
	for k in body.sockets:
		sockets[k] = PartShape.v2(body.sockets[k])
	if rig.has("sockets"):
		sockets = rig.sockets.duplicate()

	if with_legs and body.has("legs"):
		var leg_part: Dictionary = lib.part(body.legs.part)
		for a in rig.get("anchors", body.legs.anchors):
			if _clinging and float(a[3]) < 0.0:
				continue   # a riding creature's far legs are hidden behind its mount
			var leg := _shape()
			leg.part_id = body.legs.part
			leg.facing = facing_k
			leg.setup(leg_part.shapes, colours)
			leg.position = Vector2(float(a[0]), float(a[1]))
			leg.set_meta("z", 1 if float(a[3]) > 0.0 else -2)
			if a.size() > 4 and int(a[4]) == 1:
				leg.scale.x = -1.0
			if rig.has("anchors") and float(a[3]) < 0.0:
				leg.shade = 0.78   # the far leg sits in shadow
			root.add_child(leg)
			legs.append({"node": leg, "phase": float(a[2]), "cling": _clinging})

	var body_node := _shape()
	body_node.part_id = body_id + _hold_suffix
	body_node.facing = facing_k
	body_node.setup(body.shapes, colours)
	root.add_child(body_node)
	breathing.append(body_node)
	if rig.get("front", false):
		# The body's near arm, drawn above torso armour and below what the hands hold.
		var arm := _shape()
		arm.part_id = body_id + _hold_suffix
		arm.facing = facing_k
		arm.front = true
		arm.setup(body.shapes, colours)
		# Over the body, unless this facing turns that side away (then behind it).
		arm.set_meta("z", 1.5 if facing_k == 0 or float(rig.get("depth", {}).get("hand_r", 1.0)) >= -0.5 else -1.0)
		root.add_child(arm)

	var gear_scale := 1.0
	if head_id != "":
		var head: Dictionary = lib.part(head_id)
		var head_node := _shape()
		head_node.part_id = head_id
		head_node.facing = facing_k
		head_node.setup(head.shapes, colours)
		head_node.position = sockets.head
		head_node.set_meta("z", 2)
		root.add_child(head_node)
		self.head_node = head_node
		var head_rig: Dictionary = PartShape.rigs.get(head_id + PartShape.facing_suffix(facing_k), PartShape.rigs.get(head_id, {}))
		sockets["top"] = sockets.head + (head_rig.sockets.top if head_rig.has("sockets") else PartShape.v2(head.sockets.top))
		gear_scale = float(head_rig.get("gear_scale", 1.0))

	var torso_scale: Vector2 = rig.get("torso_scale", PartShape.v2(body.get("torso_scale", [1, 1])))
	return {"root": root, "sockets": sockets, "torso_scale": torso_scale, "carry": rig.get("carry", ""), "gear_scale": gear_scale,
		"depth": rig.get("depth", {}), "body": body_id, "modelled": rig.has("sockets")}


func _attach(lib, rig: Dictionary, slot: String, part_id: String, colours: Dictionary) -> void:
	var socket: String = SOCKET_FOR_SLOT[slot]
	var p: Dictionary = lib.part(part_id)
	# Wings on a body with a wing socket (a mount: pony, beetle, spider) rise from its
	# withers, ahead of the seat, not from the rump; drawn over its back, under the rider.
	var withers: bool = slot == "back" and "flying" in p.tags and rig.sockets.has("wings")
	if withers:
		socket = "wings"
	if not rig.sockets.has(socket):
		return
	var node := _shape()
	node.part_id = part_id
	node.facing = facing_k
	var worn: bool = slot == "torso" and rig.modelled and UnitModelsCheck.has(part_id)
	if worn:
		node.part_id = part_id + "~" + rig.body   # baked on this body: drawn from the body's origin
	node.setup(p.shapes, colours)
	node.position = Vector2.ZERO if worn else rig.sockets[socket]
	if withers:
		node.position += WITHERS_DROP   # the wings' shoulders sit high, for a person's back
		node.rotation = WITHERS_TILT
		node.scale = Vector2.ONE * WITHERS_SCALE
		node.set_meta("rest", WITHERS_TILT)
		node.set_meta("rest_scale", WITHERS_SCALE)
	var z: float = 0.5 if withers else Z_FOR_SLOT[slot]
	if facing_k != 0 and slot in ["hand_l", "hand_r", "back"] and rig.depth.has(socket):
		# In the other facings what's on the camera's side draws over the body, the rest under:
		# a cape shows when it walks away, the far hand's shield goes behind.
		var near: bool = float(rig.depth[socket]) >= -0.5
		z = (1.6 if slot == "back" else absf(z)) if near else (-3.0 if slot == "back" else -absf(z))
	node.set_meta("z", z)
	if slot == "torso" and not worn:
		node.scale = rig.torso_scale
	elif slot == "head_gear":
		node.scale = Vector2.ONE * rig.gear_scale   # head gear sized to the head that wears it
	rig.root.add_child(node)
	if rig.carry == "harness" and slot == "hand_r":
		# No arms: the weapon lies couched in its holder, pointing forward (a tool just leans).
		var tip: Vector2 = PartShape.rigs.get(part_id, {}).get("tip", Vector2.ZERO)
		node.rotation = 0.25 if part_id.begins_with("tool.") or tip == Vector2.ZERO else COUCH.angle() - tip.angle()
	if rig.carry == "harness" and slot == "hand_l":
		node.scale = Vector2(0.7, 0.85)   # the shield lies flat against the flank
	if slot == "hand_r":
		weapon = node
		weapon_rest = node.position
		weapon_rot = node.rotation
		harnessed = rig.carry == "harness"
	if slot == "back":
		back_node = node


func _face(dir: float) -> void:
	facing = dir if facing_k == 0 else 1.0   # baked facings are never mirrored
	visual.scale = Vector2(unit_scale * facing, unit_scale)


## Face left or right on screen (a little towards the camera, like the classic view).
func face(dir: float) -> void:
	face_vec(Vector2(1.0 if dir >= 0.0 else -1.0, 0.35))


## Face a direction on screen: the baked facing that fits it best, kept until another fits
## clearly better. A body with no facings baked mirrors left and right instead.
func face_vec(v: Vector2) -> void:
	if v == Vector2.ZERO:
		return
	var rigs: Dictionary = PartShape.rigs
	if _built.is_empty() or not rigs.has(_facing_body + PartShape.facing_suffix(1)):
		_face(1.0 if v.x >= 0.0 else -1.0)
		return
	var want := v.normalized()
	var best := facing_k
	var best_fit := -2.0
	var now_fit := -2.0
	for k in FACINGS:
		var rig: Dictionary = rigs.get(_facing_body + PartShape.facing_suffix(k), {})
		if not rig.has("dir"):
			continue
		var fit: float = rig.dir.dot(want)
		if k == facing_k:
			now_fit = fit
		if fit > best_fit:
			best_fit = fit
			best = k
	if best != facing_k and best_fit > now_fit + FACING_HOLD:
		facing_k = best
		_rebuild()


## Rebuild in the current facing, keeping where it is in its animations.
func _rebuild() -> void:
	var keep_time := time
	var keep_phase := phase
	var tool: String = weapon.part_id if weapon != null else ""
	for c in get_children():
		remove_child(c)
		c.queue_free()
	legs = []
	breathing = []
	weapon = null
	head_node = null
	back_node = null
	flying = false
	facing = 1.0
	build(_built[0], _built[1], _built[2], _built[3])
	time = keep_time
	phase = keep_phase
	if tool != "" and weapon != null and tool != weapon.part_id:
		set_tool(_built[1], tool)


## Swap what the hand holds (a worker's tool for the job, or the load it carries home),
## if that part is baked. Same arm pose: job tools are all held low.
func set_tool(lib, part_id: String) -> void:
	if weapon == null or harnessed or weapon.part_id == part_id:
		return
	var p: Dictionary = lib.part(part_id)
	var key := PartShape.bake_key(part_id, p.shapes, PartShape.team_neutral(weapon.colours))
	if not PartShape.baked.has(key):
		return
	weapon.part_id = part_id
	weapon.setup(p.shapes, weapon.colours)


func flourish() -> void:
	attack_t = 0.35


## Let the unit mill about inside a rectangle (Race Lab only).
func wander_in(rect: Rect2) -> void:
	area = rect
	target = position
	pause = noise.randf_range(0.0, 1.5)


func _process(delta: float) -> void:
	time += delta
	struck = false
	if area.has_area():
		_wander(delta)

	# Stepped (pixel-art) mode: a few poses per cycle and whole pixels, not smooth motion.
	var stepped := pose_steps > 0
	var t := floorf(time * STEP_FPS) / STEP_FPS if stepped else time
	var stride := 1.0 if walking else 0.0
	if walking:
		phase += delta * speed_px * 0.25 * gait.cadence
	var ph := phase
	if stepped:
		var step := TAU / pose_steps
		ph = floorf(phase / step) * step
	if gait.get("hop", false):
		_hop(ph, stride)
	else:
		for leg in legs:
			leg.node.rotation = 0.35 if leg.cling else sin(ph + leg.phase) * gait.swing * stride
		var hover := 0.0
		if flying:
			hover = -9.0 + sin(t * 3.0) * 2.0
		bob.position.y = hover - absf(sin(ph)) * gait.bob * stride
		bob.rotation = sin(ph * gait.rock_rate) * gait.rock * stride
	if head_node:
		head_node.rotation = 0.0
	if back_node and flying:
		# Flap: quick down-strokes, the wings' tips sweeping through a few pixels.
		var f := sin(t * (11.0 if walking else 7.0))
		back_node.rotation = back_node.get_meta("rest", 0.0) - 0.12 * f
		var rs: float = back_node.get_meta("rest_scale", 1.0)
		back_node.scale = Vector2(rs, rs * (1.0 + 0.1 * f))

	if stepped:
		# Breathe by a pixel, not by stretching the sprite (stretched pixels shimmer).
		bob.position.y -= (1.0 / maxf(art_px, 1.0)) if fmod(t, 1.6) < 0.8 and stride == 0.0 and job == "" else 0.0
	else:
		var breath := 1.0 + sin(time * 2.4) * 0.03
		for b in breathing:
			b.scale.y = breath

	if weapon:
		weapon.position = weapon_rest
		weapon.rotation = weapon_rot
	if attack_t > 0.0:
		attack_t -= delta
		var a := 1.0 - maxf(attack_t, 0.0) / 0.35
		if stepped:
			a = floorf(a * 5.0) / 5.0
		var k := sin(a * PI)
		if weapon:
			weapon.position = weapon_rest + Vector2(6.0 * k, -2.0 * k)
			weapon.rotation = weapon_rot - 0.4 * k
	elif job != "" and not walking:
		_work(t, stepped)
	elif not walking:
		_idle(delta)
	if stepped and art_px > 0.0:
		# Sit on whole art pixels: offset the drawing so its global position snaps.
		var g := global_position
		var px := 1.0 / art_px
		var snapped := Vector2(roundf(g.x / px) * px, roundf(g.y / px) * px)
		visual.position = (snapped - g) / maxf(global_transform.get_scale().x, 0.0001)


## A hop per cycle: push off (legs kick back), an arc through the air with the nose up then
## down, and a little squash on landing; at rest, sitting still.
func _hop(ph: float, stride: float) -> void:
	var p := fposmod(ph / TAU, 1.0)
	var air := 0.6   # the share of the cycle spent in the air
	var lift := 0.0
	var kick := 0.0
	var tilt := 0.0
	var squash := 0.0
	if stride > 0.0:
		if p < air:
			var q := p / air
			lift = sin(q * PI) * HOP_HEIGHT
			kick = -0.7 * sin(minf(q * 2.0, 1.0) * PI * 0.5) * (1.0 - q)   # legs flung back, then tucked
			tilt = -0.18 * cos(q * PI)   # nose up on the way up, down on the way in
		else:
			squash = sin((p - air) / (1.0 - air) * PI) * 1.2
	for leg in legs:
		leg.node.rotation = kick
	bob.position.y = -lift + squash
	bob.rotation = tilt


## How a body walks, by its number of legs: bipeds stride long and bob twice a
## cycle; four legs swing less and rock fore and aft; six and eight legs scuttle with
## short, quick steps and hardly bob; flyers let their legs dangle.
static func _gait(n: int, flies: bool) -> Dictionary:
	if flies:
		return {"swing": 0.12, "cadence": 0.8, "bob": 0.0, "rock": 0.04, "rock_rate": 1.0}
	if n >= 8:
		return {"swing": 0.26, "cadence": 1.9, "bob": 0.25, "rock": 0.0, "rock_rate": 2.0}
	if n >= 6:
		return {"swing": 0.32, "cadence": 1.6, "bob": 0.3, "rock": 0.015, "rock_rate": 2.0}
	if n >= 4:
		return {"swing": 0.42, "cadence": 1.0, "bob": 0.9, "rock": 0.035, "rock_rate": 1.0}
	return {"swing": 0.5, "cadence": 1.0, "bob": 1.5, "rock": 0.0, "rock_rate": 1.0}


## Work, per job, with the tool in the right hand (it turns about the hand):
## forage: stoop and reach in, pick, lift; chop: wind the axe back over the shoulder,
## strike down hard, recover; build: short quick hammer blows.
func _work(t: float, stepped: bool) -> void:
	var period: float = {"forage": 1.1, "chop": 0.9, "mine": 1.0, "build": 0.5}[job]
	var p := fmod(t / period + noise.seed % 7 * 0.13, 1.0)
	if stepped:
		p = floorf(p * 6.0) / 6.0
	var land := 0.5 if job == "forage" else 0.72   # the pick, or the blow landing
	struck = (_work_p < land and p >= land) or (p < _work_p and (_work_p < land or p >= land))
	_work_p = p
	var swing := 0.0   # tool rotation: negative raises it back
	var lean := 0.0    # body lean: positive leans forward
	var crouch := 0.0
	match job:
		"forage":
			var k := sin(p * TAU) * 0.5 + 0.5
			lean = 0.1 + 0.08 * k
			crouch = 1.5 * k
			swing = 0.35 * k
			if weapon:
				weapon.position = weapon_rest + Vector2(3.0, 4.0) * k
		"chop", "mine", "build":
			var up := 1.2 if job == "build" else 2.0
			var wind := 0.6
			var hit := 0.75
			if p < wind:
				swing = -up * (p / wind)
				lean = -0.04 * (p / wind)
			elif p < hit:
				var q := (p - wind) / (hit - wind)
				swing = lerpf(-up, 0.45, q)
				lean = lerpf(-0.04, 0.1, q)
			else:
				var q := (p - hit) / (1.0 - hit)
				swing = lerpf(0.45, 0.0, q)
				lean = lerpf(0.1, 0.0, q)
			crouch = 0.5 if job == "build" else 0.0
			if weapon:
				weapon.position = weapon_rest + Vector2(-1.5, -3.0) * clampf(-swing / up, 0.0, 1.0)
	if harnessed:   # no arms: the whole body digs, rocks or butts at the work
		lean = lean * 0.6 + absf(swing) * 0.06
		swing = 0.0
		if weapon:
			weapon.position = weapon_rest
	if weapon:
		weapon.rotation = weapon_rot + swing
	bob.rotation += lean
	bob.position.y += crouch


## Now and then, standing still, a unit fidgets: shifts its weight, looks up and
## about, lifts what it holds, or settles back. Each picks its own moments.
func _idle(delta: float) -> void:
	if idle_left > 0.0:
		idle_left -= delta
		match idle_kind:
			"shift":
				bob.position.y += 1.0 / maxf(art_px, 1.0)
				bob.rotation += 0.03
			"look":
				if head_node:
					head_node.rotation = -0.18
			"lift":
				if weapon and not harnessed:
					weapon.rotation = -0.3
					weapon.position = weapon_rest + Vector2(0, -1.5)
			"settle":
				bob.rotation -= 0.04
		return
	idle_wait -= delta
	if idle_wait <= 0.0:
		idle_kind = ["shift", "look", "lift", "settle"][noise.randi() % 4]
		idle_left = noise.randf_range(0.5, 1.2)
		idle_wait = noise.randf_range(2.5, 7.0)


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
