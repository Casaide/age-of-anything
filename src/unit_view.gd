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
## High ground (milestone 15): the unit is drawn this many pixels up from its node, which stays
## on the ground's base plane so the y-sort orders it with the hills (Iso.lift).
var lift := 0.0
var _shadow: Node2D
var bob: Node2D           # moves up/down while walking or hovering
var legs: Array = []      # [{node, phase}]
var breathing: Array = []
var weapon: Node2D
var weapon_rest := Vector2.ZERO
var weapon_rot := 0.0     # at rest: couched forward on a harness, else upright
var _hold_suffix := ""
var _cling_reach := 1.0   # how far a rider's leg stretches down its mount's flank
var rider_reach := 1.7    # a person riding: how far its leg stretches (to its mount's girth)
var _girth_drop := 0.0    # ...from its hips to the girth, in its own units (0: not known)
const CLING_TURN := 0.35  # a rider's leg swings forward this much down the flank
var _clinging := false    # building a riding creature: legs that hug the mount    # "@hold" on the body being built (its arm posed for its weapon)
var harnessed := false    # no arms: gear rides on a harness, work is done with the whole body
const COUCH := Vector2(1.0, -0.3)   # a couched weapon points forward, a little up
const HOP_HEIGHT := 9.0   # part units: how high a hopper leaves the ground
## A hop (2026-10-13; Dominic: the frogs "glide along the ground too much"): node units of ground covered
## per hop at scale 1 (measured on the ground: a hop towards the camera is as long as one across; a bigger
## frog hops further). The cycle: crouch on the ground until HOP_UP, in the air until
## HOP_DOWN, then the landing on the ground; the frog is drawn ahead of or behind its sim position
## (_hop_off) so it stays planted on the ground and covers the ground in the air.
const HOP_LENGTH := 40.0
const HOP_UP := 0.25
const HOP_DOWN := 0.75
## The legs through a hop: [cycle point, leg squash (1: standing), foot shift along the facing (in leg
## lengths; < 0: back)]: crouch, hold, push (legs flung back, long), tuck, reach for the ground, touch
## down, squash, stand. The feet move only in the air; the body rides on its lowest foot.
const HOP_KEYS := [[0.0, 1.0, 0.0], [0.15, 0.7, 0.0], [HOP_UP, 0.7, 0.0], [0.36, 1.15, -0.7], [0.52, 0.75, -0.25],
	[0.66, 0.9, 0.3], [HOP_DOWN, 1.0, 0.0], [0.82, 0.72, 0.0], [1.0, 1.0, 0.0]]
var _hop_off := Vector2.ZERO    # node units: where the hopper is drawn, from its node
var _hop_aim := Vector2.ZERO    # a whole hop the way it last moved, on screen (node units)
var _hop_last := Vector2.INF    # its node's position last frame
var _hop_rate := 0.0            # hops a second while it last moved (to finish a hop when it stops)
const HOP_SETTLE := 25.0        # node units a second: stopped after landing, it eases back onto its node
const WITHERS_DROP := Vector2(2.0, 5.0)    # part units: wings on a mount start at its shoulders...
const WITHERS_TILT := -0.5                 # ...and lie back along it, folded, clear of the rider
const WITHERS_SCALE := 2.0                 # a horse's wings are a horse's size (Dominic)
var head_node: Node2D     # the unit's own head (the rider's, when mounted)
var seat_node: Node2D     # where a rider (or a centaur's human half) sits on its mount
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
var _attack_kind := "blow"   # "blow" (a melee lunge, T1) or "loose" (an archer's release, R1)
var _thrusts := false         # the weapon is a spear: it thrusts instead of swinging
var dying := false            # D-106: the view plays its own death (D3, by body shape)
var die_t := 0.0
var die_tip := 1.0
var _die_offset := Vector2.ZERO
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
	_shadow = shadow

	visual = Node2D.new()
	add_child(visual)
	bob = Node2D.new()
	visual.add_child(bob)

	var colours := colours_for(lib, r.skin, r.family, team)
	if r.has("crew"):
		_build_engine(r, lib, team, colours, speed)
	elif r.has("mount"):
		var m: Dictionary = r.mount
		var mc: Dictionary = lib.creatures[m.creature]
		var mount_colours := colours_for(lib, m.skin, r.family, team)
		# A fused mount (a centaur's horse half) has its own body, without a neck.
		var mount_body: String = mc.get("fused_body", mc.body) if m.fused else mc.get("mount_body", mc.body)
		_pose_body = mount_body
		# A mount may carry its head differently from the creature on its own legs (data: "mount_head").
		var mount_rig := _make_rig(lib, mount_body, "" if m.fused else mc.get("mount_head", mc.head), mount_colours, bob, true)
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
		# A mount may sit some riders smaller (data: creatures.json "rider_scale", percent by rider
		# creature): a bulky frog dwarfed the hummingbird it rode (Dominic).
		seat.scale *= float(mc.get("rider_scale", {}).get(r.creature, 100)) / 100.0
		if not m.fused:
			# The rider's hips (its "sit" socket, else the middle of its hip anchors) on the seat, so
			# every rider sits on the back whatever its build (a fixed drop sank a crouched frog into
			# its mount and floated others over it: the placement check, A2 "the seat on its mount's back").
			var hips: Variant = sit_point(r, lib)
			if hips != null:
				seat.position = mount_rig.sockets.get("seat", Vector2(0, -20)) - (hips as Vector2) * seat.scale
				var girth: Variant = mount_rig.sockets.get("girth")
				if girth != null and not _clinging and hips.y < 0.0 and lib.creatures.get(r.creature, {}).get("rider_legs", "") != "folded":
					# A person's leg reaches down the barrel to the girth whatever the mount's size and
					# its own (a fixed stretch left a rat's or a frog's at mid-flank: the placement check).
					_girth_drop = ((girth as Vector2).y - mount_rig.sockets.seat.y) / seat.scale.y
					rider_reach = clampf(_girth_drop / (-hips.y * cos(CLING_TURN)), 1.0, 2.6)
		bob.add_child(seat)
		seat_node = seat
		# Every rider shows its near leg down the mount's flank, held still (people had none: Dominic).
		# A person's leg reaches down the barrel to the girth, longer than its standing stride
		# (at the seat's scale it ended at the horse's spine: "tiny legs", Dominic).
		_cling_reach = 1.0 if _clinging or lib.creatures.get(r.creature, {}).get("rider_legs", "") == "folded" else rider_reach
		_clinging = not m.fused
		var rider := _make_rig(lib, r.body, r.head, colours, seat, _clinging, r.parts.get("hand_r", ""))
		_clinging = false
		for slot in r.parts:
			_attach(lib, rider, slot, r.parts[slot], colours)
		flying = m.parts.has("back") and "flying" in lib.part(m.parts.back).tags
	else:
		_pose_body = r.body
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
	if not r.has("mount") and not r.has("crew") and not flying and lib.creatures.get(r.get("creature", ""), {}).get("gait", "") == "hop":
		gait = {"hop": true, "swing": 0.0, "cadence": 0.55, "bob": 0.0, "rock": 0.0, "rock_rate": 1.0}
	if r.has("crew"):
		shadow.scale = Vector2.ONE * float(lib.part(r.body).stats.get("radius", 300)) / ENGINE_SHADOW
		gait = {"swing": 0.0, "cadence": 1.0, "bob": 0.0, "rock": 0.012, "rock_rate": 3.0}
	_idle_poses = []
	if _pose_body != "" and not flying:
		# A body can walk its own way (parts.json legs.gait: a cat's low, level walk) and rest
		# in its own poses when it stands still a while (idle_poses: a cat sits down).
		var pb: Dictionary = lib.part(_pose_body)
		if pb.has("legs") and pb.legs.has("gait"):
			gait = gait.duplicate()
			gait.merge(pb.legs.gait, true)
		_idle_poses = pb.get("idle_poses", []) if int(r.get("idle", 1)) != 0 else []   # (a beast in harness stands in its traces)
	if _sit_after < 0.0 and not _idle_poses.is_empty():
		_sit_after = noise.randf_range(SIT_AFTER.x, SIT_AFTER.y)
	idle_wait = noise.randf_range(1.0, 5.0)
	_sort_layers(self)
	_face(facing)


## Where a rider's body sits on a saddle in this facing (UnitModels.hips, projected): its "sit"
## socket, else the middle of its hips; null before its body is baked.
func sit_point(r: Dictionary, lib) -> Variant:
	var hold := hold_for(lib.part(r.parts.hand_r).tags) if r.parts.has("hand_r") else "low"
	var id: String = r.body + ("" if hold == "low" else "@" + hold)
	var rig: Dictionary = PartShape.rigs.get(id + PartShape.facing_suffix(facing_k), {})
	if rig.get("sockets", {}).has("sit"):
		return rig.sockets.sit
	var anchors: Array = rig.get("anchors", [])
	if anchors.is_empty():
		return null
	var sum := Vector2.ZERO
	for a in anchors:
		sum += Vector2(float(a[0]), float(a[1]))
	return sum / anchors.size()


## A siege engine (milestone 13, D-118/D-119): the engine is one baked part in its facings (the
## recipe's body), and its crew are the race's own workers (the recipe's `crew`), each a UnitView of
## its own on the engine's crew sockets for this facing. A socket's name says how its crew member
## stands: "crew<n>_f<k>[_reach|_raise][_in|_top]": turned k facings from the engine, the arm hold
## it keeps, drawn behind the engine ("in": inside its frame) or over it ("top": riding); else by
## how near the camera the socket is. Crew walk while the engine moves (not those riding on top).
var crew: Array = []      # [{view, top}]
var rest_hold := "low"    # the hold a unit goes back to between blows and jobs (a crew member's own)
const ENGINE_SHADOW := 210.0   # an engine's shadow: its radius (milli-tiles) over this, times the unit's


func _build_engine(r: Dictionary, lib, team: Color, colours: Dictionary, speed: int) -> void:
	var part: Dictionary = lib.part(r.body)
	var engine := _shape()
	engine.part_id = r.body
	engine.facing = facing_k
	engine.setup(part.shapes, colours)
	bob.add_child(engine)
	_body_nodes.append(engine)
	_facing_body = r.body
	var rig: Dictionary = PartShape.rigs.get(r.body + PartShape.facing_suffix(facing_k), PartShape.rigs.get(r.body, {}))
	var sockets: Dictionary = rig.get("sockets", {})
	var depth: Dictionary = rig.get("depth", {})
	# Its crew (the race's workers) and the beasts hauling it (the recipe's `haul`), in one depth order:
	# the members on the camera's side over the engine, the rest under it, the nearest drawn last (a
	# handler beside a trade cart's cat drew under the cat in every facing: Dominic, TC1).
	var names: Array = engine_sockets(r, sockets)
	names.sort_custom(func(a, b): return float(depth[a]) < float(depth[b]) or (depth[a] == depth[b] and a < b))
	var cr := crew_recipe(r)
	var hr := haul_recipe(lib, r) if r.has("haul") else {}
	for n in names.size():
		var name: String = names[n]
		var hauls: bool = name.begins_with("haul")
		var face := facing_k
		var hold := "low"
		# Over the engine or under it: by which is in front where they overlap on screen (the bake's
		# "front", part_baker._members_front), else by the socket's depth.
		var z := 1.0 if rig.get("front", {}).get(name, float(depth[name]) > 0.0) else -1.0
		var top := false
		for t in name.split("_"):
			if t.begins_with("f") and t.length() == 2:
				face = (facing_k + int(t.substr(1))) % FACINGS
			elif t in WORK_HOLDS:
				hold = t
			elif t == "in":
				z = -1.0
			elif t == "top":
				z = 1.0
				top = true
		var v = get_script().new()
		v.facing_k = face
		v.build(hr if hauls else cr, lib, team, speed)
		v.position = sockets[name]
		v.set_meta("z", z + n * 0.01)   # the same layer: nearest the camera last
		if not hauls:
			v.rest_hold = hold
			v.set_hold(hold)
		v.phase = 0.4 if hauls else 0.7 * n
		bob.add_child(v)
		crew.append({"view": v, "top": top, "socket": name})


## The sockets an engine's members stand on: its crew's ("crew<n>_f<k>[_reach|_raise][_in|_top]"; a
## crew member too big for the frame, a centaur, takes the "_wide" ones beside it, not "_in") and the
## beasts hauling it ("haul<n>_f<k>"). The placement check composes the same (tests/placement/composite_3d.gd).
static func engine_sockets(r: Dictionary, sockets: Dictionary) -> Array:
	var wide: bool = r.crew.has("mount")
	# A "_wide" socket stands in for its namesake ("crew0_f0_reach_in", "crew2_f0_reach"; a war beast's rider
	# "crew0_f0_top", D-129) for such a crew.
	# A "_narrow" one is only for a crew that fits a tight file (the great sling's haulers): such a crew leaves it out.
	var out: Array = sockets.keys().filter(func(s): return s.begins_with("crew") and not (wide and s.ends_with("_narrow")) and (s.ends_with("_wide") == wide or (wide and not sockets.has(s.trim_suffix("_in").trim_suffix("_top") + "_wide") and not s.ends_with("_in"))))
	if r.has("haul"):
		out += sockets.keys().filter(func(s): return s.begins_with("haul"))
	return out


## An engine's crew member: the race's age-1 worker (the recipe's `crew`).
static func crew_recipe(r: Dictionary) -> Dictionary:
	var cr: Dictionary = r.crew.duplicate(true)
	cr.merge({"creature": r.creature, "family": r.family, "slot": "worker", "role": "worker", "tier": 1, "name": ""})
	return cr


## The beast hauling an engine (the recipe's `haul`: {creature, skin, parts?}): the bare creature, on
## its mount body if it has one, wearing what the haul names (a draught harness, {"torso": "harness.draught"}).
## It never sits down in its traces ("idle": 0: no idle poses).
static func haul_recipe(lib, r: Dictionary) -> Dictionary:
	var hc: Dictionary = lib.creatures[r.haul.creature]
	return {"slot": "beast", "role": "beast", "tier": 1, "creature": r.haul.creature, "family": r.family, "skin": r.haul.skin,
		"body": hc.get("mount_body", hc.body), "head": hc.head, "parts": r.haul.get("parts", {}).duplicate(true), "scale": 100, "name": "", "idle": 0}


## An engine's frame: it rolls (a little rock while it moves, none of a walker's bob), its crew
## walk with it; a blow is the whole engine lunging at the wall, a shot a kick back; it sags and
## settles when destroyed (its crew fall, each in its own way).
func _engine_process(delta: float) -> void:
	time += delta
	if _thrown_from != "":
		_throw_process(delta)
	bob.position = Vector2.ZERO
	bob.rotation = sin(time * gait.rock_rate * 3.0) * gait.rock if walking else 0.0
	for c in crew:
		c.view.walking = walking and not c.top
	if dying:
		die_t += delta
		var e := minf(die_t / 0.5, 1.0)
		visual.rotation = die_tip * 0.1 * e
		_die_offset = Vector2(0.0, 2.5 * e)
	elif attack_t > 0.0:
		attack_t -= delta
		var k := sin((1.0 - maxf(attack_t, 0.0) / 0.35) * PI)
		bob.position += _forward() * (-2.5 if _attack_kind == "loose" else 6.0) * k
	visual.position = _die_offset - Vector2(0, lift)
	_shadow.position.y = -lift
	if pose_steps > 0 and art_px > 0.0:
		var g := global_position - Vector2(0, lift) * global_transform.get_scale().y
		var px := 1.0 / art_px
		var snapped := Vector2(roundf(g.x / px) * px, roundf(g.y / px) * px)
		visual.position += (snapped - g) / maxf(global_transform.get_scale().x, 0.0001)


## Parts are layered by child order (their "z" meta), not z_index: z_index is global,
## so a part with z above 0 would draw over every y-sorted building and unit.
## Where it stands as drawn (its node's place, raised by the ground it's on).
func ground() -> Vector2:
	return position - Vector2(0, lift)


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
	for i in range(2, sk.size()):   # more colours for a patterned skin (a newt's spots): skin3, skin4...
		c["skin%d" % (i + 1)] = Color(sk[i])
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
	if ("spear" in tags and "heavy" in tags) or "shouldered" in tags:   # (a pike; a hero's anchor or guandao)
		return "shoulder"
	return "low"


func _make_rig(lib, body_id: String, head_id: String, colours: Dictionary, parent: Node2D, with_legs: bool, hand_r := "") -> Dictionary:
	var hold := hold_for(lib.part(hand_r).tags) if hand_r != "" else "low"
	_hold_suffix = "" if hold == "low" else "@" + hold
	var body: Dictionary = lib.part(body_id)
	var root := Node2D.new()
	parent.add_child(root)
	# A body in one of its baked poses (a cat sitting) is a part of its own, "<body>@<pose>",
	# with its own sockets and hips, and its legs posed to match ("<leg>@<pose>").
	var pose := "@" + body_pose if body_pose != "" and body_id == _pose_body else ""
	# Baked parts from hand-built models bring their own sockets (projected by the bake camera).
	var rig: Dictionary = PartShape.rigs.get(body_id + _hold_suffix + pose + PartShape.facing_suffix(facing_k),
		PartShape.rigs.get(body_id + _hold_suffix + pose, {}))
	var sockets := {}
	for k in body.sockets:
		sockets[k] = PartShape.v2(body.sockets[k])
	if rig.has("sockets"):
		sockets = rig.sockets.duplicate()

	if with_legs and body.has("legs"):
		var anchors: Array = rig.get("anchors", body.legs.anchors)
		var cut: bool = "legs" in body.get("cut", [])
		for i in anchors.size():
			var a: Array = anchors[i]
			if _clinging and (not bool(a[6]) if a.size() > 6 else float(a[3]) < 0.0):
				continue   # a rider shows the leg on the flank that faces the camera (by its side, not by
				# how near its hip is: a leg a step ahead counted as near from the far side, Dominic)
			# A body may give its hind legs their own part (legs.hind: a cat's hock), and bake its
			# legs posed (legs.poses: steps of a walk) instead of swinging one stiff sprite.
			var hind: bool = a.size() > 5 and bool(a[5])
			var leg_id: String = body.legs.get("hind", body.legs.part) if hind else body.legs.part
			var leg_part: Dictionary = lib.part(leg_id)
			var leg := _shape()
			# A body whose legs go into it (parts.json "cut": a newt's hips sit inside its flanks) has
			# each leg baked cut by it, at its own hip: only what the body doesn't hide is left, so
			# every leg draws over the body (the far ones under the near ones).
			leg.part_id = leg_id + pose + ("~%s%s^%d" % [body_id, pose, i] if cut else "")
			leg.facing = facing_k
			leg.setup(leg_part.shapes, colours)
			leg.position = Vector2(float(a[0]), float(a[1]))
			# Legs under the body where clothes hang over the hips (a tunic's skirt); else the
			# near leg draws over the belly, as on a horse.
			var under: bool = rig.get("legs_under", false)
			leg.set_meta("z", -1 if under and float(a[3]) > 0.0 else (1 if float(a[3]) > 0.0 else -2))
			if cut:
				leg.set_meta("z", 1 if float(a[3]) > 0.0 else 0.5)
			if a.size() > 4 and int(a[4]) == 1 and not cut:
				leg.scale.x = -1.0   # (a leg baked at its hip is already turned: UnitModels.leg_basis)
			if rig.has("anchors") and float(a[3]) < 0.0:
				leg.shade = 0.78   # the far leg sits in shadow
			root.add_child(leg)
			var reach := _cling_reach if _clinging else 1.0
			if _clinging and _girth_drop > 0.0 and _cling_reach > 1.0 and leg.bake_of() != null:
				# Stretched by what its sprite shows (a leg cut by its body shows less than its hip's height).
				var low := 0.0
				for p in PartShape.soles(leg.bake_of()):
					low = maxf(low, p.y)
				if low > 0.0:
					reach = clampf(_girth_drop / (low * cos(CLING_TURN)), 1.0, 2.6)
			legs.append({"node": leg, "phase": float(a[2]), "cling": _clinging, "reach": reach, "rest": leg.position,
				"base": leg_id + pose, "walk_id": leg_id, "cut": "~%s^%d" % [body_id, i] if cut else "", "steps": int(body.legs.get("poses", 0)) if pose == "" else 0})

	var body_node := _shape()
	body_node.part_id = body_id + _hold_suffix + pose
	body_node.facing = facing_k
	body_node.setup(body.shapes, colours)
	root.add_child(body_node)
	breathing.append(body_node)
	if body_id == recipe.body:
		_body_nodes.append(body_node)
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
		if body_id == recipe.body:
			_body_nodes.append(arm)

	var gear_scale := 1.0
	if head_id != "":
		var head: Dictionary = lib.part(head_id)
		var head_node := _shape()
		head_node.part_id = head_id + ("~%s%s^head" % [body_id, pose] if "head" in body.get("cut", []) else "")   # cut by its body (as legs; a sitting cat's by its sitting body)
		head_node.facing = facing_k
		head_node.setup(head.shapes, colours)
		head_node.position = sockets.head
		head_node.set_meta("z", 2)
		root.add_child(head_node)
		self.head_node = head_node
		var head_rig: Dictionary = PartShape.rigs.get(head_node.part_id + PartShape.facing_suffix(facing_k), PartShape.rigs.get(head_node.part_id, {}))
		sockets["top"] = sockets.head + (head_rig.sockets.top if head_rig.has("sockets") else PartShape.v2(head.sockets.top))
		gear_scale = float(head_rig.get("gear_scale", 1.0))

	var torso_scale: Vector2 = rig.get("torso_scale", PartShape.v2(body.get("torso_scale", [1, 1])))
	return {"root": root, "sockets": sockets, "torso_scale": torso_scale, "carry": rig.get("carry", ""), "gear_scale": gear_scale,
		"drape_scale": float(body.get("drape_scale", 100)) / 100.0,
		"depth": rig.get("depth", {}), "body": body_id, "modelled": rig.has("sockets")}


func _attach(lib, rig: Dictionary, slot: String, part_id: String, colours: Dictionary) -> void:
	var socket: String = SOCKET_FOR_SLOT[slot]
	var p: Dictionary = lib.part(part_id)
	# Wings on a body with a wing socket (a mount: pony, beetle, spider) rise from its
	# withers, ahead of the seat, not from the rump; drawn over its back, under the rider.
	var withers: bool = slot == "back" and "flying" in p.tags and rig.sockets.has("wings")
	if withers:
		socket = "wings"
	if slot == "back" and "drape" in p.tags and rig.sockets.has("drape"):
		socket = "drape"   # a hanging cape or pelt from where the body's model says it hangs clear (its "drape" socket)
	if not rig.sockets.has(socket):
		return
	var node := _shape()
	node.part_id = part_id
	node.facing = facing_k
	var worn: bool = slot == "torso" and UnitModelsCheck.has(rig.body) and UnitModelsCheck.has(part_id)   # (the body's model, not its bake: the first preview comes before any bake)
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
	if p.has("blur"):
		# A wing blur (parts.json "blur": its opacity in percent): see-through, and it buzzes.
		# Drawn over or under the body like any back part (over it in every facing, the wings
		# lay across a bird seen from behind as a flat grey plate: Dominic, "what's this?").
		node.modulate.a = float(p.blur) / 100.0
		node.set_meta("buzz", true)
	node.set_meta("z", z)
	if slot == "torso" and not worn:
		node.scale = rig.torso_scale
	elif slot == "head_gear":
		node.scale = Vector2.ONE * rig.gear_scale   # head gear sized to the head that wears it
	elif slot == "back" and "drape" in p.tags:
		node.scale = Vector2.ONE * rig.drape_scale   # a hanging cape or pelt sized to the back it hangs from (parts.json drape_scale)
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
		_hand_rest = node.position
		weapon_rot = node.rotation
		harnessed = rig.carry == "harness"
		_thrusts = "spear" in p.tags or "lance" in p.tags
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
	var hold := work_hold
	legs = []
	breathing = []
	crew = []
	weapon = null
	head_node = null
	back_node = null
	seat_node = null
	_body_nodes = []
	work_hold = "low"
	flying = false
	facing = 1.0
	build(_built[0], _built[1], _built[2], _built[3])
	time = keep_time
	phase = keep_phase
	if tool != "" and weapon != null and tool != weapon.part_id:
		set_tool(_built[1], tool)
	set_hold(hold)


## Pushing a load home (D-127: the rats push the scrap barrow with stone, the handcart with gold;
## creatures.json push_home): set_tool("push:<engine part>") makes the view that engine with the unit
## as its crew (an engine composite, checked whole by the placement check), any other tool turns it
## back. Only once the engine is baked (else it carries as before: nothing shows magenta).
var _own_recipe := {}   # the unit's own recipe while it pushes


func _push(engine_id: String) -> void:
	if engine_id == "":
		_built[0] = _own_recipe
		_own_recipe = {}
	elif not PartShape.rigs.has(engine_id + PartShape.facing_suffix(facing_k)) and not PartShape.rigs.has(engine_id):
		return
	elif _own_recipe.is_empty():
		_own_recipe = _built[0]
		_built[0] = push_recipe(_own_recipe, engine_id)
	elif _built[0].body != engine_id:
		_built[0] = push_recipe(_own_recipe, engine_id)
	else:
		return
	_rebuild()


## Packed to move (the great sling, D-129): an engine whose body part names a `packed` look (parts.json:
## "siege.sling_packed.<take>", the frame on its wagon) shows it while it isn't set up (the sim's
## units.ready under its unpack: rolling, packing or unpacking), its own look once it is. Only once the
## packed look is baked (else it stays as it is: nothing shows magenta).
var _set_up_body := ""   # the engine's own body while it shows packed


func set_packed(on: bool) -> void:
	if on and _thrown_from != "":   # (packing up straight after a throw: back to its own look first)
		_built[0] = _built[0].duplicate()
		_built[0].body = _thrown_from
		_thrown_from = ""
		_throw_t = 0.0
	var r: Dictionary = _built[0]
	var lib = _built[1]
	var to := ""
	if on and _set_up_body == "":
		to = lib.part(r.body).get("packed", "")
		if to == "" or not (PartShape.rigs.has(to + PartShape.facing_suffix(facing_k)) or PartShape.rigs.has(to)):
			return
		_set_up_body = r.body
	elif not on and _set_up_body != "":
		to = _set_up_body
		_set_up_body = ""
	else:
		return
	_built[0] = r.duplicate()
	_built[0].body = to
	_rebuild()


## Throwing (the frogs' great sling, D-131): an engine whose body part names a `throw` look (parts.json:
## "siege.sling_throw.frog", the bullfrog landed on the pad and the arm swung through) shows it for THROW_TIME
## after a shot leaves, then its own look again. Only once the throw look is baked.
const THROW_TIME := 0.9
var _throw_t := 0.0
var _thrown_from := ""   # the engine's own body while it shows its throw


func _throw() -> void:
	if _thrown_from != "":
		_throw_t = THROW_TIME
		return
	var r: Dictionary = _built[0]
	var to: String = _built[1].part(r.body).get("throw", "")
	if to == "" or not (PartShape.rigs.has(to + PartShape.facing_suffix(facing_k)) or PartShape.rigs.has(to)):
		return
	_thrown_from = r.body
	_throw_t = THROW_TIME
	_built[0] = r.duplicate()
	_built[0].body = to
	_rebuild()


func _throw_process(delta: float) -> void:
	_throw_t -= delta
	if _throw_t <= 0.0:
		_built[0] = _built[0].duplicate()
		_built[0].body = _thrown_from
		_thrown_from = ""
		_rebuild()


## A worker pushing an engine home: the engine, the worker its crew, its hands on the handles.
static func push_recipe(r: Dictionary, engine_id: String) -> Dictionary:
	var crew := {"body": r.body, "head": r.head, "skin": r.skin, "parts": r.parts.duplicate(), "scale": r.get("scale", 100)}
	crew.parts.erase("hand_r")
	return {"slot": r.slot, "role": r.get("role", r.slot), "tier": r.get("tier", 1), "creature": r.creature, "family": r.family, "skin": r.skin,
		"body": engine_id, "head": "", "parts": {}, "scale": 100, "name": r.get("name", ""), "crew": crew}


## Swap what the hand holds (a worker's tool for the job, or the load it carries home),
## if that part is baked. Job tools are held low; a load tagged "shoulder" (a bundle of reeds,
## a haunch of meat) is carried with the arm up at the shoulder, the load lying back over it
## (the body's "raise" bake), so it never reads as a weapon held out (Dominic: a green sword).
var carry_hold := ""
const LOAD_Z := 1.2   # between the body (0) and its near arm (1.5)


func set_tool(lib, part_id: String) -> void:
	if part_id.begins_with("push:"):
		_push(part_id.substr(5))
		return
	if not _own_recipe.is_empty():
		_push("")   # home: the barrow is left, the worker carries on as itself
	if weapon == null or harnessed or weapon.part_id == part_id:
		return
	var p: Dictionary = lib.part(part_id)
	var key := PartShape.bake_key(part_id, p.shapes, PartShape.team_neutral(weapon.colours))
	if not PartShape.baked.has(key):
		return
	weapon.part_id = part_id
	weapon.setup(p.shapes, weapon.colours)
	carry_hold = "raise" if "shoulder" in p.tags else ""
	# A tool is gripped: drawn over the arm. A load is carried: under the near arm (the arm and
	# hand come over it, holding it to the chest or on the shoulder), not pasted on top of the
	# arm (Dominic: "on top of his arm, not under it or in the hand").
	if not weapon.has_meta("tool_z"):
		weapon.set_meta("tool_z", weapon.get_meta("z", Z_FOR_SLOT.hand_r))
	var tool_z: float = weapon.get_meta("tool_z")
	var z: float = (LOAD_Z if tool_z > 0.0 else -LOAD_Z) if "load" in p.tags else tool_z
	if z != float(weapon.get_meta("z", tool_z)):
		weapon.set_meta("z", z)
		_sort_layers(weapon.get_parent())


## A melee blow lands: the lunge (T1, D-106).
func flourish() -> void:
	attack_t = 0.35
	_attack_kind = "blow"
	for c in crew:
		c.view.flourish()   # the crew heave with it


## A shot leaves: the archer snaps forward on the release (R1, D-106).
func loose() -> void:
	if _built.size() > 0 and _built[0].has("crew"):
		_throw()
	attack_t = 0.35
	_attack_kind = "loose"
	for c in crew:
		c.view.loose()


## The unit has died: from now on the view plays its fall (D3, D-106) and nothing else;
## tip is which way a topple goes where that's a free choice.
func die(tip: float) -> void:
	dying = true
	die_t = 0.0
	die_tip = tip
	walking = false
	job = ""
	attack_t = 0.0
	for c in crew:
		c.view.die(-tip if c.view.position.x < 0.0 else tip)


## Work poses (W1, D-105): the body is baked in three arm holds, "low" (its own, how it
## carries its tool), "raise" (the tool wound up high behind the shoulder) and "reach" (the
## hand out and down to the work), and the work cycle swaps between them. Swapping moves what
## the hand holds to the new hand. Only if that bake exists (bake_units bakes them for
## workers); a missing bake leaves the pose as it is, so nothing shows magenta.
const WORK_HOLDS := ["reach", "raise"]
const ATTACK_HOLDS := ["thrust"]   # baked for spear and lance carriers (art_kit.bake_units)
var work_hold := "low"
var _body_nodes: Array = []   # the body's PartShapes (its bake and its near-arm layer)
var _hand_rest := Vector2.ZERO   # the hand in the body's own hold


func set_hold(hold: String) -> void:
	if hold == work_hold:
		return
	if recipe.has("mount") and not recipe.mount.get("fused", false):
		return   # a rider's body is baked once; mounts don't work with their hands
	var natural: String = recipe.body + _hold_suffix
	var id: String = natural if hold == "low" else recipe.body + "@" + hold
	var rig: Dictionary = PartShape.rigs.get(id + PartShape.facing_suffix(facing_k), PartShape.rigs.get(id, {}))
	if hold != "low":
		if rig.is_empty() or not PartShape.baked.has(PartShape.bake_key(id, _body_nodes[0].shapes, PartShape.team_neutral(_body_nodes[0].colours)) + PartShape.facing_suffix(facing_k)):
			return
	for ps in _body_nodes:
		ps.part_id = id
		ps.setup(ps.shapes, ps.colours)
	work_hold = hold
	if weapon != null:
		weapon.position = rig.sockets.hand_r if hold != "low" and rig.has("sockets") and rig.sockets.has("hand_r") else _hand_rest
		weapon_rest = weapon.position
		# Over or under the body by where the hand is in this hold, as _attach does for the body's own:
		# a tool wound up high facing away is on the camera's side, and drew under the body (the
		# placement check on the catapult and great sling crews, 2026-10-13).
		if facing_k != 0 and not harnessed and rig.has("depth") and rig.depth.has("hand_r"):
			var side := 1.0 if float(rig.depth.hand_r) >= -0.5 else -1.0
			var tool_z: float = weapon.get_meta("tool_z", weapon.get_meta("z", Z_FOR_SLOT.hand_r))
			weapon.set_meta("tool_z", absf(tool_z) * side)
			var cur: float = weapon.get_meta("z", tool_z)
			if absf(cur) * side != cur:
				weapon.set_meta("z", absf(cur) * side)   # (a load keeps its LOAD_Z, a tool its own)
				_sort_layers(weapon.get_parent())


## A pose on top of the animation, for concept sheets: kneel (0..1: the front legs fold and
## the chest dips), pitch (radians, nose down is positive), drop (part units down), head
## (radians), tool (radians, added to the hand's rotation).
var concept := {}


func _apply_concept() -> void:
	if concept.is_empty():
		return
	var kneel: float = concept.get("kneel", 0.0)
	if kneel > 0.0 and legs.size() >= 4:
		var xs := legs.map(func(l): return l.node.position.x)
		xs.sort()
		var mid: float = (xs[1] + xs[2]) * 0.5
		for leg in legs:
			if leg.node.position.x > mid:   # the front pair folds under the chest: short, knee forward
				leg.node.scale.y = 1.0 - 0.55 * kneel
				leg.node.rotation = 0.35 * kneel
		bob.rotation += 0.26 * kneel   # the chest dips (about the feet, so the hind end stays up)
		bob.position.y += 2.5 * kneel
	bob.rotation += float(concept.get("pitch", 0.0))
	bob.position.y += float(concept.get("drop", 0.0))
	if head_node != null and concept.has("head"):
		head_node.rotation = float(concept.head)
	if weapon != null and concept.has("tool"):
		weapon.rotation = weapon_rot + float(concept.tool)
		weapon.position = weapon_rest + Vector2(concept.get("tool_dx", 0.0), concept.get("tool_dy", 0.0))


## Let the unit mill about inside a rectangle (Race Lab only).
func wander_in(rect: Rect2) -> void:
	area = rect
	target = position
	pause = noise.randf_range(0.0, 1.5)


func _process(delta: float) -> void:
	if recipe.has("crew"):
		_engine_process(delta)
		return
	time += delta
	struck = false
	if area.has_area():
		_wander(delta)
	_pose_tick(delta)

	# Stepped (pixel-art) mode: a few poses per cycle and whole pixels, not smooth motion.
	var stepped := pose_steps > 0
	var t := floorf(time * STEP_FPS) / STEP_FPS if stepped else time
	var stride := 1.0 if walking else 0.0
	bob.position.x = 0.0   # a lunge, a kneel or a release pushes it this frame; nothing carries over
	var hops: bool = gait.get("hop", false)
	if hops:
		_hop_advance(delta)
		stride = 1.0 if walking or phase != 0.0 else 0.0   # (finishing its hop when it stops)
	elif walking:
		phase += delta * speed_px * 0.25 * gait.cadence
	var ph := phase
	if stepped:
		var step := TAU / pose_steps
		ph = floorf(phase / step) * step
	if hops:
		_hop(ph, stride)
	else:
		for leg in legs:
			leg.node.rotation = CLING_TURN if leg.cling else sin(ph + leg.phase) * gait.swing * stride
			leg.node.scale.y = leg.reach
			if leg.steps > 0:
				# Posed legs: the walk's step for where this leg is in its cycle (baked 3D poses).
				var id: String = leg.base + leg.cut   # (a leg cut by its body: "leg.cat@w3_8~body.cat^1")
				if walking:
					id = "%s@w%d_%d%s" % [leg.walk_id, int(fposmod((phase + leg.phase) / TAU, 1.0) * leg.steps) % leg.steps, leg.steps, leg.cut]
				if id != leg.node.part_id:
					leg.node.part_id = id
					leg.node.queue_redraw()
		var hover := 0.0
		if flying:
			hover = -9.0 + sin(t * 3.0) * 2.0
		var plant: Variant = _planted() if stride > 0.0 and not flying else 0.0
		bob.position.y = hover + (plant if plant != null else -absf(sin(ph)) * gait.bob * stride)
		bob.rotation = sin(ph * gait.rock_rate) * gait.rock * stride
	if head_node:
		head_node.rotation = 0.0
	if back_node and flying:
		# Flap: quick down-strokes, the wings' tips sweeping through a few pixels.
		var f := sin(t * (11.0 if walking else 7.0))
		if back_node.has_meta("buzz"):
			f = [0.0, 1.0, -0.6][int(time * 24.0) % 3]   # a blur flickers through three spreads, too fast for a stroke
		back_node.rotation = back_node.get_meta("rest", 0.0) - 0.12 * f
		var rs: float = back_node.get_meta("rest_scale", 1.0)
		back_node.scale = Vector2(rs, rs * (1.0 + 0.1 * f))

	if stepped:
		# Breathe by a pixel, not by stretching the sprite (stretched pixels shimmer): a short lift
		# now and then (0.5 s in every 4 s, each unit at its own moment). Up for half of every 1.6 s,
		# every unit standing about looked to bounce gently (Dominic).
		bob.position.y -= (1.0 / maxf(art_px, 1.0)) if fmod(t, 4.0) < 0.5 and stride == 0.0 and job == "" else 0.0
	else:
		var breath := 1.0 + sin(time * 2.4) * 0.03
		for b in breathing:
			b.scale.y = breath

	if weapon:
		weapon.position = weapon_rest
		weapon.rotation = weapon_rot
	if dying:
		die_t += delta
		_die_pose()
	elif attack_t > 0.0:
		attack_t -= delta
		var a := 1.0 - maxf(attack_t, 0.0) / 0.35
		if stepped:
			a = floorf(a * 5.0) / 5.0
		_attack(a)
	elif job != "" and not walking:
		_work(t, stepped)
	elif not walking:
		_idle(delta)
	var rest := carry_hold if carry_hold != "" else rest_hold
	if attack_t <= 0.0 and (job == "" or walking) and work_hold != rest:
		set_hold(rest)
	_kneel(delta)
	_apply_concept()
	visual.position = _die_offset - Vector2(0, lift) + _hop_off
	_shadow.position = _hop_off - Vector2(0, lift)
	if stepped and art_px > 0.0:
		# Sit on whole art pixels: offset the drawing so its global position snaps.
		var g := global_position + (_hop_off - Vector2(0, lift)) * global_transform.get_scale().y
		var px := 1.0 / art_px
		var snapped := Vector2(roundf(g.x / px) * px, roundf(g.y / px) * px)
		visual.position += (snapped - g) / maxf(global_transform.get_scale().x, 0.0001)


## How far to move the body so its lowest foot stays where it stands while the legs swing (the
## walk rides on its planted foot: no foot through the ground, none floating; the placement check,
## B5): the lowest sole now against the lowest standing (full_length: standing on legs not squashed,
## for a hopper's crouch). Null before the legs are baked.
func _planted(full_length := false) -> Variant:
	var rest_low := -INF
	var now_low := -INF
	for leg in legs:
		if leg.cling:
			continue
		var n: PartShape = leg.node
		var now: Variant = n.bake_of()
		var rest: Variant = n.bake_of(leg.base + leg.cut) if leg.steps > 0 else now
		if now == null or rest == null:
			return null
		var t := Transform2D(n.rotation, n.scale, 0.0, n.position)
		var t0 := Transform2D(0.0, Vector2(n.scale.x, leg.reach) if full_length else n.scale, 0.0, n.position)
		for p in PartShape.soles(now):
			now_low = maxf(now_low, (t * p).y)
		for p in PartShape.soles(rest):
			rest_low = maxf(rest_low, (t0 * p).y)
	if now_low == -INF:
		return null
	return rest_low - now_low


## A blow (T1): the body lunges forward and the near leg steps; the arm swings through its
## baked holds (wound up, then reaching into the blow), a spear thrusts, an armless creature
## butts with its head. A release (R1): the archer snaps forward and the bow kicks, then settles.
func _attack(a: float) -> void:
	var k := sin(a * PI)
	var fwd := _forward()
	if _attack_kind == "loose":
		bob.rotation += 0.12 * (1.0 - a) * signf(fwd.x if fwd.x != 0.0 else 1.0)
		bob.position += fwd * 3.0 * (1.0 - a)
		if weapon:
			weapon.rotation = weapon_rot + 0.2 * (1.0 - a)
			weapon.position = weapon_rest + fwd * 2.0 * (1.0 - a)
		return
	bob.position += fwd * 6.0 * k
	bob.rotation += 0.14 * k * signf(fwd.x if fwd.x != 0.0 else 1.0)
	if legs.size() == 2:
		legs[0].node.rotation += -0.5 * k
		legs[1].node.rotation += 0.3 * k
	elif legs.size() >= 4:
		for leg in legs:
			leg.node.rotation += (0.25 if leg.node.position.x > 0.0 else -0.2) * k
	if harnessed:
		if head_node:
			head_node.rotation = 0.6 * k
		return
	if weapon == null:
		return
	if _thrusts:
		# A spear: the arm straight out (the thrust hold), the spear levelled at the target and
		# driven forward, then back to the carry.
		var out: float = clampf((a - 0.2) / 0.25, 0.0, 1.0) * (1.0 - clampf((a - 0.75) / 0.25, 0.0, 1.0))
		set_hold("thrust" if out > 0.0 else "low")
		var tip: Vector2 = PartShape.rigs.get(weapon.part_id + PartShape.facing_suffix(facing_k), PartShape.rigs.get(weapon.part_id, {})).get("tip", Vector2.ZERO)
		var level := weapon_rot if tip == Vector2.ZERO else fwd.angle() - tip.angle()
		weapon.rotation = lerp_angle(weapon_rot, level, out)
		weapon.position = weapon_rest + fwd * 9.0 * out
		return
	if a < 0.35:
		set_hold("raise")
		weapon.rotation = weapon_rot - 1.1 * (a / 0.35)
	elif a < 0.8:
		set_hold("reach")
		weapon.rotation = weapon_rot + lerpf(-0.4, 0.9, (a - 0.35) / 0.45)
	else:
		set_hold("low")
		weapon.rotation = weapon_rot + lerpf(0.9, 0.0, (a - 0.8) / 0.2)


## The fall, by body shape (D3): a hopper gives one last hop and lands on its back; a flyer
## drops to the ground, then topples; four or six legs fold and the body sinks (a rider slumps);
## a biped topples backwards, away from the blow, and bounces once. The shadow stays put;
## combat_fx fades the body and raises the dust.
func _die_pose() -> void:
	var t := die_t
	_die_offset = Vector2.ZERO
	if gait.get("hop", false):
		var a := minf(t / 0.45, 1.0)
		var h := _hip_height() + 8.0
		visual.rotation = -PI * a
		_die_offset = Vector2(0.0, -h * (1.0 - cos(PI * a)) * 0.5 - sin(a * PI) * 5.0)
	elif flying:
		var drop := minf(t / 0.3, 1.0)
		bob.position.y = lerpf(bob.position.y, 0.0, drop)
		var a := clampf((t - 0.3) / 0.35, 0.0, 1.0)
		visual.rotation = die_tip * a * a * 1.45
	elif legs.size() >= 4:
		var a := minf(t / 0.4, 1.0)
		var e := a * a * (3.0 - 2.0 * a)
		for leg in legs:
			leg.node.scale.y = 1.0 - 0.7 * e
		bob.position.y += _hip_height() * 0.7 * e
		bob.rotation += 0.3 * e
		if head_node:
			head_node.rotation = 0.6 * e
		if seat_node:
			seat_node.rotation = 0.7 * e
	else:
		var a := minf(t / 0.4, 1.0)
		var e := 1.0 - (1.0 - a) * (1.0 - a)
		visual.rotation = -1.45 * e + 0.12 * sin(clampf((t - 0.4) / 0.25, 0.0, 1.0) * PI)
		if legs.size() == 2:
			legs[0].node.rotation += -0.4 * e
			legs[1].node.rotation += 0.2 * e


## Which way the unit faces, on screen, in the sprite's own space: the baked facing's
## direction, or in the mirrored three-quarter view the couched-weapon direction.
func _forward() -> Vector2:
	if facing_k == 0:
		return COUCH.normalized()
	var rig: Dictionary = PartShape.rigs.get(_facing_body + PartShape.facing_suffix(facing_k), {})
	return (rig.dir as Vector2).normalized() if rig.has("dir") else Vector2.RIGHT


func _hip_height() -> float:
	var h := 6.0
	for leg in legs:
		h = maxf(h, -leg.rest.y)
	return h


## A hop per cycle (HOP_KEYS): a crouch, the push (legs flung back), a tuck in the air with the nose up
## then down, legs reaching for the ground, and a squash on landing. The legs bend by squashing (the
## body riding down on its lowest foot, so the feet stay put) and swing only in the air; their feet
## move along the facing's screen direction (sideways by turning, up or down the screen by length).
func _hop(ph: float, stride: float) -> void:
	var p := fposmod(ph / TAU, 1.0) if stride > 0.0 else 0.0
	var s := 1.0
	var d := 0.0
	for i in range(1, HOP_KEYS.size()):
		if p <= HOP_KEYS[i][0]:
			var a: Array = HOP_KEYS[i - 1]
			var b: Array = HOP_KEYS[i]
			var w := smoothstep(a[0], b[0], p)
			s = lerpf(a[1], b[1], w)
			d = lerpf(a[2], b[2], w)
			break
	var fwd := _forward()
	# Every foot comes up by the same amount as the legs bend (the body rides down by it, so none
	# lifts off nor sinks): a leg reaching further below its hip squashes less.
	var depth := 0.0
	var reach := {}
	for leg in legs:
		var b: Variant = leg.node.bake_of()
		var low := 0.0
		if b != null:
			for q in PartShape.soles(b):
				low = maxf(low, q.y)
		reach[leg.node] = low * leg.reach
		depth = maxf(depth, low * leg.reach)
	for leg in legs:
		var h: float = reach[leg.node]
		var k := maxf(1.0 - (1.0 - s) * depth / h, 0.2) if h > 0.0 else s
		leg.node.rotation = -asin(clampf(d * fwd.x, -0.9, 0.9))
		leg.node.scale.y = leg.reach * (k + d * fwd.y)
	var lift := 0.0
	var tilt := 0.0
	if p > HOP_UP and p < HOP_DOWN:
		var q := (p - HOP_UP) / (HOP_DOWN - HOP_UP)
		lift = sin(q * PI) * HOP_HEIGHT
		tilt = -0.2 * sin(q * TAU) * fwd.x   # nose up on the way up, down on the way in
	var plant: Variant = _planted(true)
	bob.position.y = (plant if plant != null else 0.0) - lift
	bob.rotation = tilt


## How far through the hop's forward travel at cycle point p: none while it crouches, all of it once
## landed; in the air smoothly between (stepped: at the pose shown, so a held pose doesn't slide).
func _hop_f(p: float) -> float:
	if pose_steps > 0:
		p = floorf(p * pose_steps) / pose_steps
	var q := clampf((p - HOP_UP) / (HOP_DOWN - HOP_UP), 0.0, 1.0)
	return lerpf(q, q * q * (3.0 - 2.0 * q), 0.5)


## Moves a hopper through its cycle by the ground its node covered (a hop every HOP_LENGTH, so the hop
## matches the sim's speed whatever it is), and where it's drawn: on the ground it stays put while the
## node moves on (_hop_off takes the node's move back); in the air it catches up and passes it, to
## the offset D (f(p) - p) along its way, which averages out over a hop (no drift). Whatever is left
## over (a turn, a stop, a hop resumed) is made up in the next air time, never on the ground. Stopped,
## it finishes its hop and lands where its node is (a crouch just begun straightens up instead).
## Moving in place (a sheet, a crew member on its engine) it hops on the spot.
func _hop_advance(delta: float) -> void:
	var D := HOP_LENGTH * sqrt(unit_scale)
	var m := Vector2.ZERO
	if _hop_last != Vector2.INF:
		m = (position - _hop_last) / maxf(scale.x, 0.0001)
	_hop_last = position
	var ground := Vector2(m.x, m.y * 2.0).length()   # the distance on the ground (the screen squashes y by half)
	if ground > D:   # a jump (placed, back on screen): no hop across it
		m = Vector2.ZERO
		ground = 0.0
		_hop_off = Vector2.ZERO
	var p0 := fposmod(phase / TAU, 1.0)
	var moving := walking and ground > 0.0
	var dp := 0.0
	if moving:
		dp = ground / D
		_hop_aim = m / dp   # a whole hop this way, on screen
		_hop_rate = dp / delta if delta > 0.0 else _hop_rate
	elif walking:
		dp = delta * speed_px / D
	elif p0 != 0.0:
		dp = delta * (_hop_rate if _hop_rate > 0.0 else speed_px / D)
		if p0 < HOP_UP and _hop_off.length() < 1.0:
			# Stopped while crouching, nothing to make up: straighten up again.
			_hop_off = _hop_off.move_toward(Vector2.ZERO, HOP_SETTLE * unit_scale * delta)
			phase = maxf(p0 - dp, 0.0) * TAU
			return
	var p1 := p0 + dp
	var f0 := _hop_f(p0)
	var f1 := _hop_f(p1) if p1 < 1.0 else 1.0 + _hop_f(p1 - 1.0)
	var aim := _hop_aim if moving else Vector2.ZERO   # (in place or stopping: it lands on its node)
	var c := _hop_bias()
	if f1 > f0 and f0 < 1.0:
		var left := _hop_off - aim * (f0 - p0 + c)
		_hop_off = aim * (f1 - p1 + c) + left * (1.0 - minf(f1, 1.0)) / (1.0 - f0)
	elif moving:
		_hop_off -= m
	elif not walking and (f0 >= 1.0 or p0 == 0.0):
		_hop_off = _hop_off.move_toward(Vector2.ZERO, HOP_SETTLE * unit_scale * delta)   # stopped after landing
	if not walking and p1 >= 1.0:
		p1 = 0.0   # landed: standing (still easing onto its node, if it came down beside it)
	phase = fposmod(p1, 1.0) * TAU


## The hop's offset averages out to nothing over a hop: D (f(p) - p) does when f is symmetric (smooth
## poses); the stepped f lags a little, made up by this constant share of a hop.
var _hop_bias_for := -1
var _hop_bias_v := 0.0


func _hop_bias() -> float:
	if _hop_bias_for != pose_steps:
		var sum := 0.0
		for i in 1000:
			var p := (i + 0.5) / 1000.0
			sum += p - _hop_f(p)
		_hop_bias_for = pose_steps
		_hop_bias_v = sum / 1000.0
	return _hop_bias_v


## Whether a hopper's feet are on the ground at this point of its hop (crouching or landed; the
## placement check holds them to the ground line then).
func hop_grounded() -> bool:
	var p := fposmod(phase / TAU, 1.0)
	return _hop_f(p) <= 0.0 or _hop_f(p) >= 1.0


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


## Work, per job (D-105). Two arms: the body swaps through its baked holds, the tool wound
## up high behind the shoulder (raise), coming down (low), the blow reaching out and down to
## the work (reach); forage reaches in, then lifts. No arms (a beetle, a spider): the head
## and body drive into the work and rear back between blows (A1). A fused mount (a centaur)
## kneels to forage (C1, see _kneel).
func _work(t: float, stepped: bool) -> void:
	if job in CHORES:
		_chore(t, stepped)
		return
	var period: float = {"forage": 1.1, "chop": 0.9, "mine": 1.0, "build": 0.5, "till": 1.3}[job]
	var p := fmod(t / period + noise.seed % 7 * 0.13, 1.0)
	if stepped:
		p = floorf(p * 6.0) / 6.0
	var land := 0.5 if job == "forage" else 0.72   # the pick, or the blow landing
	struck = (_work_p < land and p >= land) or (p < _work_p and (_work_p < land or p >= land))
	_work_p = p
	var swing := 0.0   # tool rotation: negative raises it back
	var lean := 0.0    # body lean: positive leans forward
	var crouch := 0.0
	var hold := "low"
	var head := 0.0    # the head's dip (armless creatures work with it)
	match job:
		"forage":
			var k := sin(p * TAU) * 0.5 + 0.5
			hold = "reach" if p < 0.5 else "low"
			lean = 0.04 + 0.12 * k
			crouch = 2.0 * k
			swing = 0.3 * k - 0.1 * (1.0 - k)
			head = 0.7 * k
			if weapon and work_hold == "low":
				weapon.position = weapon_rest + Vector2(3.0, 4.0) * k   # no reach bake: the hand goes down anyway
		"chop", "mine", "build", "till":
			var up := 0.9 if job == "build" else 0.7 if job == "till" else 1.2   # a hoe only lifts to the waist
			var wind := 0.6 if job != "build" else 0.5
			var hit := 0.75 if job != "build" else 0.65
			if p < wind:
				hold = "raise"
				var q := p / wind
				swing = -up * (0.7 + 0.3 * q)
				lean = -0.06 - 0.02 * q
				head = -0.5 - 0.2 * q
				crouch = -1.0 * q if harnessed else 0.0
			elif p < hit:
				var q := (p - wind) / (hit - wind)
				hold = "low" if p < land else "reach"
				swing = lerpf(-up * 0.4, 0.9 if job != "build" else 0.5, q)
				lean = lerpf(0.02, 0.14, q)
				head = lerpf(0.3, 0.8, q)
				crouch = lerpf(0.5, 1.5, q)
			else:
				var q := (p - hit) / (1.0 - hit)
				hold = "reach" if p < 0.9 else "low"
				swing = lerpf(0.9 if job != "build" else 0.5, 0.0, q)
				lean = lerpf(0.14, 0.0, q)
				head = lerpf(0.8, 0.0, q)
				crouch = lerpf(1.5, 0.0, q)
	if harnessed:   # no arms: the head and the whole body dig; the tool rides along
		lean = lean * 1.6
		crouch = crouch * 1.4
		swing = 0.0
		if head_node:
			head_node.rotation = head
		if weapon:
			weapon.position = weapon_rest
	else:
		set_hold(hold)
		crouch *= 0.5
	if weapon:
		weapon.rotation = weapon_rot + swing
	bob.rotation += lean
	bob.position.y += crouch


## Small jobs round the house for a worker with nothing to do (milestone 17; the view picks
## them, the sim only knows it's idle): sweep (a broom pushed side to side, head down), sit
## (legs out in front and down on the ground; four or more legs lie down; a hopper settles
## lower), chat (turned to a neighbour: nods, a tilt of the head, a hand lifted now and then).
## How long the legs are (hip to foot, part units): how far a body comes down to sit or lie.
func _leg_len() -> float:
	var hip := 0.0
	for leg in legs:
		hip = maxf(hip, -leg.rest.y)
	return hip


## Animals graze (a claimed sheep by its Town Center): head down to the grass, up to chew.
const CHORES := ["sweep", "sit", "chat", "graze"]


func _chore(t: float, stepped: bool) -> void:
	struck = false
	var p := fmod(t / {"sweep": 1.2, "sit": 5.0, "chat": 2.6, "graze": 4.0}[job] + noise.seed % 5 * 0.21, 1.0)
	if stepped:
		p = floorf(p * 8.0) / 8.0
	match job:
		"sweep":
			var k := sin(p * TAU)
			if not harnessed:
				set_hold("reach")
			if weapon:
				weapon.rotation = weapon_rot + 0.35 + 0.3 * k   # the broom's foot swishes to and fro
			bob.rotation += 0.1 + 0.03 * absf(k)
			bob.position.y += 0.5
			if head_node:
				head_node.rotation = 0.35
		"sit":
			if gait.get("hop", false):
				bob.position.y += 1.5   # a frog sits already: it settles lower and looks about
				if head_node:
					head_node.rotation = -0.15 if p < 0.5 else 0.1
			elif legs.size() >= 4 or harnessed:
				for leg in legs:   # lies down: legs folded under, the body down on them
					leg.node.scale.y = 0.45
				bob.position.y += _leg_len() * 0.55
				if head_node:
					head_node.rotation = 0.25 if p > 0.6 else 0.0
			else:
				for leg in legs:   # sits on the ground, legs out in front
					leg.node.rotation = -1.35 + 0.08 * leg.phase
				bob.position.y += _leg_len() * 0.8
				bob.rotation -= 0.08
				if head_node:
					head_node.rotation = -0.1 if p < 0.7 else 0.12
		"chat":
			var talk := p < 0.55
			if head_node:
				head_node.rotation = (0.12 * sin(p * TAU * 6.0) if talk else -0.08)
			bob.rotation += 0.03 * sin(p * TAU)
			if talk and weapon and not harnessed and p > 0.2 and p < 0.4:
				weapon.rotation = weapon_rot - 0.35   # a hand lifted to make the point
				weapon.position = weapon_rest + Vector2(1.0, -2.0)
		"graze":
			var down := p < 0.7
			if head_node:
				head_node.rotation = 0.95 if down else 0.05
			bob.rotation += 0.08 if down else 0.0


## A fused mount kneels to forage (C1): the front legs fold short with a small forward knee,
## the chest dips about the feet (the hind end stays up) and the rider half comes forward with
## it. Eased in and out over a third of a second on the unit's own clock (so a sheet of single
## frames shows it too); walking stands it up again.
var kneel := 0.0
var _kneel_want := 0.0
var _kneel_from := 0.0    # the kneel when it last changed its mind
var _kneel_at := 0.0      # ...and the time then
var _kneel_seen := false


func _kneel(_delta: float) -> void:
	var want := 1.0 if job == "forage" and not walking and recipe.has("mount") and recipe.mount.get("fused", false) else 0.0
	if not _kneel_seen:
		_kneel_seen = true   # a view made of a unit already at work starts in the pose
		_kneel_want = want
		_kneel_from = want
		_kneel_at = time
	if want != _kneel_want:
		_kneel_want = want
		_kneel_from = kneel
		_kneel_at = time
	kneel = move_toward(_kneel_from, want, maxf(0.0, time - _kneel_at) * 3.0)
	if kneel <= 0.0 or legs.size() < 4:
		for leg in legs:
			if leg.has("shin"):
				leg.shin.visible = false
		if seat_node != null and seat_node.rotation != 0.0:
			seat_node.rotation = 0.0
			seat_node.position.x = seat_node.get_meta("rest_x", seat_node.position.x)
		return
	if seat_node != null and not seat_node.has_meta("rest_x"):
		seat_node.set_meta("rest_x", seat_node.position.x)
	var xs := legs.map(func(l): return l.node.position.x)
	xs.sort()
	var mid: float = (xs[1] + xs[2]) * 0.5
	for leg in legs:
		if leg.node.position.x <= mid:
			continue
		# A front leg bends at the knee (Dominic: "the knees aren't bent"): the upper leg, the
		# leg's own sprite, shortens to the knee; a second copy of it, the shin, folds back
		# from the knee to lie along the ground.
		var upper := 1.0 - 0.45 * kneel
		leg.node.scale.y = upper
		leg.node.rotation += 0.1 * kneel
		var shin: Node2D = leg.get("shin")
		if shin == null:
			shin = _shape()
			shin.part_id = leg.node.part_id
			shin.facing = leg.node.facing
			shin.shade = leg.node.shade
			shin.setup(leg.node.shapes, leg.node.colours)
			shin.set_meta("z", leg.node.get_meta("z", 0))
			leg.node.add_sibling(shin)
			leg.shin = shin
		shin.visible = kneel > 0.03
		var hip_to_ground: float = -leg.rest.y
		shin.position = leg.node.position + Vector2(0.0, hip_to_ground * upper).rotated(leg.node.rotation)
		shin.rotation = leg.node.rotation + 1.45 * kneel   # back along the ground, hoof behind the knee
		shin.scale = Vector2(leg.node.scale.x, 0.5)
	# The chest comes down with the folded legs, pivoting about the hind hooves (which stay
	# planted), and the human half leans back over the hindquarters to keep its balance.
	var a := 0.17 * kneel
	var pivot := Vector2((xs[0] + xs[1]) * 0.5, 0.0)
	bob.rotation += a
	bob.position += pivot - pivot.rotated(a)
	if seat_node != null:
		seat_node.rotation = -0.4 * kneel
		seat_node.position.x = seat_node.get_meta("rest_x", seat_node.position.x) - 1.5 * kneel


## Resting poses (concept C2, the cat: "including sitting when idle", Dominic): a body with
## `idle_poses` in parts.json (["sit1", "sit"]) goes down through them, a step at a time, once it
## has stood still a few seconds, and comes back up through them the moment it has to move, fight
## or work. Each pose is the body baked whole in it ("<body>@sit", its sockets and hips moved, so
## the rider sits where the saddle went) with its legs baked to match; changing pose rebuilds the
## view, like turning to another facing. View only: the sim never knows.
var body_pose := ""         # "" standing, else one of the body's idle_poses (set before build for a sheet)
var _pose_body := ""        # the body that takes the poses (the mount's, when ridden)
var _idle_poses: Array = []
var _still := 0.0           # how long it has stood still with nothing to do
var _sit_after := -1.0      # how long it waits before it sits (each unit its own, 3-6 s)
var _pose_t := 0.0          # since the last pose step
const SIT_AFTER := Vector2(3.0, 6.0)
const POSE_DOWN := 0.22     # seconds per step going down; getting up is quicker
const POSE_UP := 0.08


func _pose_tick(delta: float) -> void:
	if _idle_poses.is_empty():
		return
	var busy := walking or attack_t > 0.0 or dying or job != ""
	_still = 0.0 if busy else _still + delta
	var steps: Array = [""] + _idle_poses
	var now := steps.find(body_pose)
	var want := steps.size() - 1 if _still >= _sit_after else 0
	_pose_t += delta
	if now == want:
		_pose_t = 0.0
		return
	if _pose_t < (POSE_DOWN if want > now else POSE_UP) and not (busy and now == steps.size() - 1):
		return   # (rising from the full pose starts at once)
	_pose_t = 0.0
	body_pose = steps[now + (1 if want > now else -1)]
	_rebuild()


## The extra parts a recipe is drawn with beyond what one build shows: its body's idle poses
## and its legs in them, and the steps of a posed walk (art_kit bakes these with the rest).
## Every leg a body draws, one per hip for a body whose legs bake at each hip ("cut").
static func leg_parts(lib, body_id: String) -> Array:
	var body: Dictionary = lib.part(body_id)
	if not body.has("legs"):
		return []
	var out := []
	for i in body.legs.anchors.size():
		var a: Array = body.legs.anchors[i]
		var hind: bool = a.size() > 5 and bool(a[5])
		var leg_id: String = body.legs.get("hind", body.legs.part) if hind else body.legs.part
		out.append(leg_id + ("~%s^%d" % [body_id, i] if "legs" in body.get("cut", []) else ""))
	return out


static func pose_parts(lib, r: Dictionary) -> Array:
	if r.has("crew"):
		return []
	var body_id: String = r.body
	var head_id: String = r.head
	if r.has("mount"):
		var mc: Dictionary = lib.creatures[r.mount.creature]
		body_id = mc.get("fused_body", mc.body) if r.mount.fused else mc.get("mount_body", mc.body)
		head_id = "" if r.mount.fused else mc.get("mount_head", mc.head)
	var body: Dictionary = lib.part(body_id)
	if not body.has("legs"):
		return []
	# Each leg as _compose draws it: [leg id, what follows the pose] (a leg cut by its body is a
	# bake of its own per hip, "leg.cat@w3_8~body.cat^1"; the body's posed rig keeps the anchor order).
	var cut: bool = "legs" in body.get("cut", [])
	var legs := []
	for i in body.legs.anchors.size():
		var a: Array = body.legs.anchors[i]
		var id: String = body.legs.get("hind", body.legs.part) if a.size() > 5 and bool(a[5]) else body.legs.part
		var leg := [id, i]
		if not cut:
			if legs.any(func(l): return l[0] == id):
				continue
			leg[1] = -1
		legs.append(leg)
	var out := []
	for pose in body.get("idle_poses", []):
		out.append([body_id + "@" + pose, body.shapes])
		if head_id != "" and "head" in body.get("cut", []):   # a cut head is cut by the body in that pose
			out.append(["%s~%s@%s^head" % [head_id, body_id, pose], lib.part(head_id).shapes])
		for l in legs:
			out.append([l[0] + "@" + pose + ("~%s@%s^%d" % [body_id, pose, l[1]] if cut else ""), lib.part(l[0]).shapes])
	var n := int(body.legs.get("poses", 0))
	for l in legs:
		for i in n:
			out.append(["%s@w%d_%d%s" % [l[0], i, n, "~%s^%d" % [body_id, l[1]] if cut else ""], lib.part(l[0]).shapes])
	return out


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
