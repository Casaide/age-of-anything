extends "res://scenes/art_pixel/unit_models.gd"
## Concept variations: candidate designs, built with the same kit as the real parts, shown
## side by side on a unit by tests/concept_sheet.gd so Dominic can pick before anything is
## built for the game. Nothing here is used in play. Ids are "concept.<name>".
## Head gear sits on the head's "top" socket: the face looks along +x, the skull's centre is
## about (0.2, -5.8, 0) from the top, the jaw about (1.3, -8.4, 0).

const HAIR := Color("#5a3820")
const RED_HAIR := Color("#8a4a22")


func _concept_current_cap(c: Dictionary) -> Dictionary:
	return _helm_cap(c)


func _concept_current_horned(c: Dictionary) -> Dictionary:
	return _helm_horned(c)


func _concept_current_galea(c: Dictionary) -> Dictionary:
	return _helm_galea(c)


# ------------------------------------------------------------------ Roman, age 1 (recruits)

## A: bare-headed, hair cropped short; the soldier is told by the shield and cloak.
func _concept_roman_bare(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(dome(Vector3(4.7, 3.2, 4.5), surf("mane", HAIR, 2.0), Vector3(-0.3, -4.2, 0)))
	return {"node": n}


## B: a team-colour band tied round cropped hair.
func _concept_roman_fillet(c: Dictionary) -> Dictionary:
	var n: Node3D = _concept_roman_bare(c).node
	n.add_child(ring(4.5, 5.2, plain(c.team), Vector3(0.2, -3.9, 0), Vector3(0, 0, -8)))
	return {"node": n}


## C: a felt pileus, the rounded cone of a common soldier's cap.
func _concept_roman_pileus(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var felt := surf("cloth", Color("#ddd0b2"), 3.0)
	n.add_child(cone(2.4, 5.0, 4.4, felt, Vector3(-0.2, -1.6, 0)))
	n.add_child(blob(Vector3(2.5, 1.4, 2.5), felt, Vector3(-0.3, 0.6, 0)))
	n.add_child(ring(4.7, 5.3, surf("cloth", Color("#b8a888"), 2.0), Vector3(0, -3.8, 0)))
	return {"node": n}


## D: a leather cap with cheek flaps and a short neck lip: the galea's outline in leather,
## so age 2's iron helmet reads as the same soldier promoted.
func _concept_roman_leather(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var leather := surf("leather", Color(1.0, 0.95, 0.9), 2.0)
	n.add_child(dome(Vector3(5.0, 4.6, 4.8), leather, Vector3(0, -3.6, 0)))
	n.add_child(ring(4.8, 5.3, surf("leather", Color(0.7, 0.6, 0.5), 2.0), Vector3(0.3, -3.0, 0)))
	n.add_child(blob(Vector3(2.6, 0.5, 4.4), leather, Vector3(-3.8, -4.0, 0), Vector3(0, 0, -25)))
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.5, 2.4, 0.5), leather, Vector3(2.0, -5.6, 4.3 * side)))
	return {"node": n}


# ------------------------------------------------------------------ Viking, age 1 (and the horns question)

func _beard(n: Node3D, colour: Color, long := true) -> void:
	var hair := surf("mane", colour, 2.0)
	n.add_child(blob(Vector3(2.4, 3.0 if long else 2.0, 3.4), hair, Vector3(2.2, -9.4 if long else -8.8, 0)))
	n.add_child(blob(Vector3(1.4, 0.6, 2.4), hair, Vector3(3.8, -7.4, 0)))   # moustache


func _long_hair(n: Node3D, colour: Color) -> void:
	var hair := surf("mane", colour, 2.0)
	n.add_child(blob(Vector3(3.2, 5.0, 4.6), hair, Vector3(-2.4, -6.2, 0)))
	for side in [1, -1]:   # braids over the shoulders
		n.add_child(rod(Vector3(-1.0, -7.0, 4.2 * side), Vector3(-0.4, -12.0, 4.6 * side), 0.9, 0.6, hair))


## A: bare head, long hair in braids, a full beard: the silhouette does the work.
func _concept_viking_bare(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(dome(Vector3(4.8, 3.4, 4.6), surf("mane", RED_HAIR, 2.0), Vector3(-0.3, -4.0, 0)))
	_long_hair(n, RED_HAIR)
	_beard(n, RED_HAIR)
	return {"node": n}


## B: a wool hood, pointed, falling over the shoulders, with a beard.
func _concept_viking_hood(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var wool := surf("cloth", Color("#7e6e50"), 3.0)
	n.add_child(dome(Vector3(5.6, 5.6, 5.4), wool, Vector3(-0.4, -4.0, 0)))
	n.add_child(blob(Vector3(4.0, 3.6, 5.6), wool, Vector3(-2.2, -7.6, 0)))
	n.add_child(cone(0.2, 1.6, 4.0, wool, Vector3(-3.2, 1.0, 0), Vector3(0, 0, 50)))
	_beard(n, RED_HAIR)
	return {"node": n}


## C: a round fur cap with a thick brim, and a beard.
func _concept_viking_fur(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", Color("#7a5a3c"), 2.0)
	n.add_child(blob(Vector3(5.0, 3.4, 4.9), surf("leather", Color(0.9, 0.85, 0.8), 2.0), Vector3(-0.2, -2.6, 0)))
	n.add_child(ring(4.4, 6.0, fur, Vector3(0, -3.6, 0)))
	_long_hair(n, RED_HAIR)
	_beard(n, RED_HAIR)
	return {"node": n}


## D: a plain conical iron cap with a nose guard (no horns), and a beard.
func _concept_viking_conical(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color.WHITE, 3.0)
	n.add_child(cone(0.3, 5.1, 5.6, iron, Vector3(0, -1.2, 0)))
	n.add_child(ring(4.8, 5.4, iron, Vector3(0, -3.8, 0)))
	n.add_child(rod(Vector3(5.0, -3.6, 0), Vector3(5.5, -7.0, 0), 0.6, 0.5, iron))
	_long_hair(n, RED_HAIR)
	_beard(n, RED_HAIR)
	return {"node": n}


## E (later ages): a rounded iron helmet with a spectacle guard round the eyes.
func _concept_viking_spectacle(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color.WHITE, 3.0)
	n.add_child(dome(Vector3(5.0, 5.4, 4.8), iron, Vector3(0, -3.8, 0)))
	n.add_child(ring(4.8, 5.4, iron, Vector3(0, -3.6, 0)))
	n.add_child(rod(Vector3(-5, -1.0, 0), Vector3(5, -1.0, 0), 0.5, 0.5, iron))
	for side in [1, -1]:
		n.add_child(ring(0.9, 1.5, iron, Vector3(4.6, -5.4, 1.7 * side), Vector3(0, 0, 90)))
	_beard(n, RED_HAIR)
	return {"node": n}


# ------------------------------------------------------------------ Greek, age 1

## A: a conical felt pilos.
func _concept_greek_pilos(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var felt := surf("cloth", Color("#c8a878"), 3.0)
	n.add_child(cone(0.5, 5.0, 6.6, felt, Vector3(-0.2, -0.6, 0)))
	n.add_child(ring(4.7, 5.3, surf("cloth", Color("#a08458"), 2.0), Vector3(0, -3.8, 0)))
	return {"node": n}


## B: a wide-brimmed petasos sun hat.
func _concept_greek_petasos(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var felt := surf("cloth", Color("#d8c49a"), 3.0)
	n.add_child(dome(Vector3(4.9, 3.4, 4.7), felt, Vector3(0, -3.2, 0)))
	n.add_child(cone(7.4, 7.6, 0.5, felt, Vector3(0, -3.2, 0), Vector3(0, 0, -6), 28))
	return {"node": n}


# ------------------------------------------------------------------ R0 "A+": the tuned 3D human
# Built to the proposed spec (docs/concepts/direction.md): about 4.5 heads tall, a visible neck,
# shoulders two heads wide, chunky hands and feet, bare legs; the head is a face (egg, chin and
# nose forward, brow ledge, dark eye row, no white) and its cranium comes from hair or head gear.
# Untextured skin. Nothing here is used in play.



func _concept_body_chunky(c: Dictionary) -> Dictionary:
	return _human_body(c, 6.0, 0.0)


## The slim, realistic build: narrower shoulders, raised on longer legs (see leg_long).
func _concept_body_slim(c: Dictionary) -> Dictionary:
	return _human_body(c, 4.8, 3.0)


func _human_body(c: Dictionary, shoulder: float, lift: float) -> Dictionary:
	var spec := _human_body_built(c, shoulder)
	if lift != 0.0:
		var wrap := Node3D.new()
		wrap.position.y = lift
		wrap.add_child(spec.node)
		spec.node = wrap
		var fw := Node3D.new()
		fw.position.y = lift
		fw.add_child(spec.front)
		spec.front = fw
		for k in spec.sockets:
			spec.sockets[k] += Vector3(0, lift, 0)
		spec.anchors = spec.anchors.map(func(a): return [a[0] + Vector3(0, lift, 0)] + a.slice(1))
	return spec


func _human_body_built(c: Dictionary, shoulder: float) -> Dictionary:
	var n := Node3D.new()
	var tunic := surf("cloth", c.team, 5.0)
	var trim := surf("cloth", c.cloth, 3.0)
	var skin := surf("skin", c.skin, 5.0)
	var belt := surf("leather", Color.WHITE, 2.0)
	n.add_child(blob(Vector3(3.9, 5.2, 6.0), tunic, Vector3(0.2, 21.4, 0)))        # chest: broad and deep
	n.add_child(cone(4.6, 5.8, 5.2, tunic, Vector3(0, 15.4, 0)))                  # skirt to mid-thigh
	n.add_child(ring(5.3, 6.0, trim, Vector3(0, 12.9, 0)))                        # hem in the culture's colour
	n.add_child(ring(4.3, 5.3, belt, Vector3(0, 17.8, 0)))
	n.add_child(rod(Vector3(0.4, 25.6, 0), Vector3(0.7, 29.2, 0), 1.7, 1.6, skin))   # the neck, visible
	var near_hand := Vector3.ZERO
	var front := Node3D.new()
	for side in [1, -1]:
		var into: Node3D = front if side == 1 else n
		var sh := Vector3(0.3, 25.4, shoulder * side)
		var elbow := Vector3(1.3, 20.6, (shoulder + 1.2) * side)
		var hand := Vector3(6.2, 18.4, 6.4) if side == 1 else Vector3(5.8, 19.4, -5.6)
		if side == 1:
			var pose := arm_pose(sh, elbow, hand, Vector3(0.7, 29.5, 0))
			elbow = pose[0]
			hand = pose[1]
			near_hand = hand
		into.add_child(blob(Vector3(2.6, 2.5, 2.6), tunic, sh))                      # shoulder, in the tunic
		into.add_child(rod(sh, sh.lerp(elbow, 0.5), 2.0, 1.9, tunic))               # short sleeve
		into.add_child(rod(sh.lerp(elbow, 0.5), elbow, 1.8, 1.7, skin))
		into.add_child(rod(elbow, hand, 1.7, 1.5, skin))
		into.add_child(blob(Vector3(1.9, 1.9, 1.7), skin, hand))                   # a fist you can see
	return {"node": n, "front": front, "sockets": {
		"head": Vector3(0.8, 29.2, 0), "hand_r": near_hand, "hand_l": Vector3(5.8, 19.4, -5.6),
		"torso": Vector3(0.3, 20.8, 0), "back": Vector3(-4.4, 24, 0)},
		"anchors": [[Vector3(-0.6, 13.6, -2.6), 0.0, -1], [Vector3(0.6, 13.6, 2.6), PI, 1]],
		"torso_scale": Vector2(0.75, 0.85)}


## A bare leg with a sandal: longer than today's, light against the grass.
func _concept_leg_chunky(c: Dictionary) -> Dictionary:
	return _human_leg(c, 1.0)


## Longer legs for the slim build (it stands on them 3 units higher).
func _concept_leg_long(c: Dictionary) -> Dictionary:
	return _human_leg(c, 1.23)


func _human_leg(c: Dictionary, k: float) -> Dictionary:
	var n := Node3D.new()
	var skin := surf("skin", c.skin, 5.0)
	var strap := surf("leather", Color.WHITE, 2.0)
	n.add_child(rod(Vector3(0, 0, 0), Vector3(0.6, -6.6 * k, 0), 2.2, 1.8, skin))
	n.add_child(rod(Vector3(0.6, -6.6 * k, 0), Vector3(0.2, -12.4 * k, 0), 1.7, 1.35, skin))
	n.add_child(ring(1.2, 1.6, strap, Vector3(0.25, -12.4 * k + 1.0, 0)))
	n.add_child(blob(Vector3(2.7, 1.2, 1.8), strap, Vector3(1.3, -12.4 * k - 0.8, 0)))
	return {"node": n}


## The face: an egg, taller than wide, chin and nose forward, a brow ledge with a dark eye row
## under it. No cranium: hair or head gear supplies the top of the head.
func _concept_head_egg(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var skin := surf("skin", c.skin, 4.0)
	var shade := plain(c.skin.darkened(0.25))
	n.add_child(blob(Vector3(3.3, 4.3, 3.4), skin, Vector3(0.5, 4.5, 0)))
	n.add_child(blob(Vector3(2.5, 1.9, 2.7), skin, Vector3(1.7, 1.9, 0)))         # jaw and chin, forward
	n.add_child(cone(0.0, 1.1, 1.8, skin, Vector3(4.1, 4.0, 0), Vector3(0, 0, -90)))   # nose
	n.add_child(blob(Vector3(0.9, 0.55, 2.9), shade, Vector3(3.2, 5.7, 0)))        # brow ledge
	for side in [1, -1]:
		n.add_child(blob(Vector3(0.35, 0.5, 0.6), plain(INK), Vector3(3.55, 4.95, 1.25 * side)))   # dark eyes, no white
		n.add_child(blob(Vector3(0.9, 1.3, 0.6), skin, Vector3(-0.6, 4.6, 3.3 * side)))       # ears
	return {"node": n, "sockets": {"top": Vector3(0.2, 8.8, 0)}}


## Cranium options. Each sits on the head's top socket: its rim at the brow, over the ears.

func _concept_hair_crop(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var hair := surf("mane", Color("#3a2416"), 2.0)
	n.add_child(dome(Vector3(3.7, 3.6, 3.6), hair, Vector3(-0.3, -3.2, 0)))
	n.add_child(blob(Vector3(2.4, 2.8, 3.2), hair, Vector3(-1.9, -3.8, 0)))   # the back of the skull: the head has a direction
	return {"node": n}


func _concept_cap_montefortino(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var leather := surf("leather", Color(1.15, 1.0, 0.9), 2.0)
	var dark := surf("leather", Color(0.75, 0.65, 0.55), 2.0)
	n.add_child(dome(Vector3(4.1, 4.2, 3.9), leather, Vector3(-0.3, -3.4, 0)))
	n.add_child(ring(3.9, 4.5, dark, Vector3(-0.2, -3.3, 0)))
	n.add_child(cone(0.35, 0.9, 1.6, dark, Vector3(-0.3, 1.2, 0)))                # the top knob
	n.add_child(blob(Vector3(2.3, 0.45, 3.6), leather, Vector3(-3.4, -4.3, 0), Vector3(0, 0, -25)))   # a little neck lip
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.4, 2.3, 0.45), leather, Vector3(1.4, -5.9, 3.6 * side)))   # cheek flaps
	return {"node": n}


func _concept_galea_heavy(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color.WHITE, 3.0)
	var bronze := surf("bronze", Color.WHITE, 2.0)
	n.add_child(dome(Vector3(4.3, 4.5, 4.1), iron, Vector3(-0.3, -3.4, 0)))
	n.add_child(ring(4.1, 4.7, bronze, Vector3(-0.1, -3.2, 0)))
	n.add_child(blob(Vector3(1.0, 0.35, 3.8), iron, Vector3(3.7, -3.0, 0)))        # brow peak
	n.add_child(blob(Vector3(3.4, 0.6, 4.8), iron, Vector3(-3.6, -4.8, 0), Vector3(0, 0, -30)))   # deep neck guard
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.7, 2.7, 0.5), iron, Vector3(1.6, -6.2, 3.9 * side)))
	crest(n, c.crimson, Vector3(-0.3, 1.0, 0), 8.5, 4.5)
	return {"node": n}


# ------------------------------------------------------------------ frogs, rethought (CU1)
# Built from what makes a frog (design review, D-080): eyes on top of the head (never covered),
# a wide mouth line and throat, long folded hind legs, gripping fingers with pads, wet saturated
# skin. Three directions: A a crouched leaper, B a slim tree frog, C a bullfrog warrior.





func _concept_frog_a_body(c: Dictionary) -> Dictionary:
	return _body_frog(c)

func _concept_frog_a_leg(c: Dictionary) -> Dictionary:
	return _leg_frog(c)

func _concept_frog_a_head(c: Dictionary) -> Dictionary:
	return _head_frog(c)

func _concept_frog_b_body(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _frog_mats(c)
	n.add_child(blob(Vector3(4.4, 7.6, 4.8), m[0], Vector3(0, 15.5, 0), Vector3(0, 0, 10)))
	n.add_child(blob(Vector3(3.0, 6.0, 3.6), m[1], Vector3(1.8, 15.0, 0), Vector3(0, 0, 10)))
	var front := Node3D.new()
	var near_hand := Vector3.ZERO
	for side in [1, -1]:
		var into: Node3D = front if side == 1 else n
		var sh := Vector3(1.5, 21.0, 4.6 * side)
		var elbow := Vector3(3.5, 15.5, 6.2 * side)
		var hand := Vector3(7.0, 14.0, 5.2 * side) if side == 1 else Vector3(6.5, 14.5, -4.6)
		if side == 1:
			var pose := arm_pose(sh, elbow, hand, Vector3(2.0, 23.5, 0))
			elbow = pose[0]
			hand = pose[1]
			near_hand = hand
		into.add_child(rod(sh, elbow, 1.3, 1.1, m[0]))
		into.add_child(rod(elbow, hand, 1.1, 0.95, m[0]))
		_frog_hand(into, hand, Vector3(1, 0.2, 0), m[0], m[1])
	kerchief(front, c, Vector3(1.6, 22.0, 0), 3.0, 10)
	return {"node": n, "front": front, "sockets": {
		"head": Vector3(2.0, 23.5, 0), "hand_r": near_hand, "hand_l": Vector3(6.5, 14.5, -4.6),
		"torso": Vector3(0.5, 15.5, 0), "back": Vector3(-4.0, 18.0, 0)},
		"anchors": [[Vector3(-1.0, 9.5, -3.0), 0.0, -1], [Vector3(-1.0, 9.5, 3.0), PI, 1]],
		"torso_scale": Vector2(0.6, 0.85)}


func _concept_frog_b_leg(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _frog_mats(c)
	var knee := Vector3(4.5, -4.5, 1.0)
	var ankle := Vector3(-1.5, -8.0, 0.8)
	n.add_child(rod(Vector3.ZERO, knee, 1.9, 1.4, m[0]))
	n.add_child(rod(knee, ankle, 1.3, 0.9, m[0]))
	var heel := ankle + Vector3(0.5, -1.2, 0)
	for t in 4:
		var toe := heel + Vector3(4.5, -0.2, (t - 1.5) * 1.5)
		n.add_child(rod(heel, toe, 0.4, 0.36, m[0], false))
		n.add_child(blob(Vector3(1.0, 0.65, 1.0), m[1], toe))   # big sticky pads
	return {"node": n}


func _concept_frog_b_head(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _frog_mats(c)
	n.add_child(blob(Vector3(4.2, 3.2, 4.2), m[0], Vector3(1.8, 3.0, 0)))
	n.add_child(blob(Vector3(3.2, 1.4, 3.4), m[1], Vector3(2.4, 1.5, 0)))
	n.add_child(rod(Vector3(5.4, 2.4, -2.8), Vector3(5.8, 2.4, 0), 0.28, 0.28, plain(INK)))
	n.add_child(rod(Vector3(5.8, 2.4, 0), Vector3(5.4, 2.4, 2.8), 0.28, 0.28, plain(INK)))
	_frog_eyes(n, Vector3(2.6, 4.8, 0), 3.4, 2.1, m[0])   # bulging out at the sides
	return {"node": n, "sockets": {"top": Vector3(-0.4, 5.6, 0)}}


# --- C: the bullfrog warrior. Low and broad, a deep chest, thick legs, a big throat sac.
func _concept_frog_c_body(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _frog_mats(c)
	n.add_child(blob(Vector3(8.8, 7.0, 8.4), m[0], Vector3(0, 10.5, 0), Vector3(0, 0, 20)))
	n.add_child(blob(Vector3(6.4, 5.4, 6.6), m[1], Vector3(2.8, 9.4, 0), Vector3(0, 0, 20)))
	var front := Node3D.new()
	var near_hand := Vector3.ZERO
	for side in [1, -1]:
		var into: Node3D = front if side == 1 else n
		var sh := Vector3(4.0, 13.0, 6.4 * side)
		var elbow := Vector3(6.5, 8.0, 7.8 * side)
		var hand := Vector3(9.0, 8.5, 6.6 * side) if side == 1 else Vector3(9.0, 3.0, -6.6)
		if side == 1:
			var pose := arm_pose(sh, elbow, hand, Vector3(6.0, 16.5, 0))
			elbow = pose[0]
			hand = pose[1]
			near_hand = hand
		into.add_child(rod(sh, elbow, 2.0, 1.7, m[0]))
		into.add_child(rod(elbow, hand, 1.7, 1.5, m[0]))
		_frog_hand(into, hand, Vector3(1, 0.1, 0), m[0], m[1])
	kerchief(front, c, Vector3(4.6, 14.6, 0), 4.0, 30)
	return {"node": n, "front": front, "sockets": {
		"head": Vector3(6.0, 16.5, 0), "hand_r": near_hand, "hand_l": Vector3(9.0, 3.0, -6.6),
		"torso": Vector3(1.0, 11.0, 0), "back": Vector3(-5.5, 15.0, 0)},
		"anchors": [[Vector3(-4.0, 6.5, -6.5), 0.0, -1], [Vector3(-4.0, 6.5, 6.5), PI, 1]],
		"torso_scale": Vector2(0.9, 0.75)}


func _concept_frog_c_leg(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _frog_mats(c)
	var knee := Vector3(6.0, 2.5, 1.8)
	var ankle := Vector3(-1.0, -3.5, 1.4)
	n.add_child(rod(Vector3.ZERO, knee, 3.2, 2.4, m[0]))
	n.add_child(rod(knee, ankle, 2.2, 1.5, m[0]))
	var heel := ankle + Vector3(0, -2.4, 0)
	n.add_child(rod(ankle, heel, 1.5, 1.2, m[0]))
	for t in 4:
		var toe := heel + Vector3(6.0, -0.4, (t - 1.5) * 1.8)
		n.add_child(rod(heel, toe, 0.6, 0.5, m[0], false))
		n.add_child(blob(Vector3(0.85, 0.6, 0.85), m[1], toe))
	return {"node": n}


func _concept_frog_c_head(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _frog_mats(c)
	n.add_child(blob(Vector3(6.2, 3.4, 6.0), m[0], Vector3(2.4, 2.8, 0)))
	n.add_child(blob(Vector3(4.4, 3.0, 5.0), plain(c.skin2.lightened(0.45)), Vector3(3.0, 0.2, 0)))   # the throat sac, puffed
	n.add_child(rod(Vector3(8.0, 2.2, -4.0), Vector3(8.4, 2.2, 0), 0.36, 0.36, plain(INK)))
	n.add_child(rod(Vector3(8.4, 2.2, 0), Vector3(8.0, 2.2, 4.0), 0.36, 0.36, plain(INK)))
	_frog_eyes(n, Vector3(3.4, 5.6, 0), 3.4, 2.3, m[0])
	return {"node": n, "sockets": {"top": Vector3(-0.2, 6.0, 0)}}


## The slim build's head: the same face, a little smaller (a realistic head-to-body ratio).
func _concept_head_small(c: Dictionary) -> Dictionary:
	var spec := _scaled(_concept_head_egg(c), 0.85)
	spec.gear_scale = 0.85
	return spec


# ------------------------------------------------------------------ RB2: the rats' own kit, by age
# Junk, never human bronze; head gear sits on the crown between the ears, which always show.
# Age 1 rags and string, age 2 tin and bottle caps, age 3 cutlery steel copying the Romans.

func _concept_rat_thimble(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var brass := surf("bronze", Color(1.1, 1.0, 0.75), 1.2)
	n.add_child(cone(1.7, 2.2, 3.0, brass, Vector3(0.6, -0.4, 0), Vector3(0, 0, -12)))
	n.add_child(blob(Vector3(1.7, 0.6, 1.7), brass, Vector3(0.9, 1.1, 0)))
	n.add_child(ring(2.1, 2.5, brass, Vector3(0.4, -1.8, 0), Vector3(0, 0, -12)))
	return {"node": n}


func _concept_rat_tin_cap(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var tin := surf("iron", Color(0.95, 0.95, 1.0), 2.0)
	n.add_child(dome(Vector3(4.0, 2.6, 2.5), tin, Vector3(0.6, -1.6, 0)))   # narrow: the ears stay out
	n.add_child(ring(0.97, 1.08, plain(Color("#6a6c66")), Vector3(0.6, -1.5, 0), Vector3.ZERO, Vector3(4.0, 1.0, 2.5)))
	n.add_child(blob(Vector3(0.7, 0.5, 0.7), tin, Vector3(0.6, 1.1, 0)))   # a rivet knob
	return {"node": n}


## Age 3 pride: a spoon's bowl as the helmet, its handle down the neck as a guard, and a
## toothbrush along the top as the crest (copying the Romans' crested helmet).
func _concept_rat_spoon_helm(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var steel := surf("iron", Color.WHITE, 2.0)
	n.add_child(dome(Vector3(4.4, 2.8, 2.6), steel, Vector3(0.8, -1.6, 0)))
	n.add_child(rod(Vector3(-3.2, -1.4, 0), Vector3(-6.2, -5.2, 0), 0.55, 0.45, steel))   # the handle as a neck guard
	n.add_child(rod(Vector3(-1.6, 1.5, 0), Vector3(3.6, 1.5, 0), 0.35, 0.35, plain(Color("#e8e0d0"))))   # toothbrush handle
	n.add_child(_box(Vector3(4.0, 1.6, 0.9), plain(c.crimson), Vector3(0.6, 2.6, 0)))   # bristles, in the crest's red
	return {"node": n}


## Sardine-tin bands as a segmented cuirass (age 3), fitted to the lean rat.
func _concept_rat_sardine_armour(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var tin := surf("iron", Color(0.95, 0.97, 1.0), 2.0)
	var label := plain(Color("#c8a040"))
	var tilt := Node3D.new()   # follow the rat's forward hunch; torso armour is built ~1.6x and scaled down by the body
	tilt.rotation_degrees = Vector3(0, 0, 15)
	tilt.scale = Vector3.ONE * 1.45
	n.add_child(tilt)
	for k in 4:
		var y := 4.0 - k * 2.4
		tilt.add_child(cone(6.6 - k * 0.35, 6.9 - k * 0.35, 2.0, tin if k % 2 == 0 else label, Vector3(0.6, y, 0), Vector3.ZERO, 20))
	tilt.add_child(_box(Vector3(1.2, 0.5, 3.2), plain(Color("#6a6c66")), Vector3(7.0, 4.6, 0), Vector3(0, 0, -20)))   # the key, rolled
	return {"node": n}


## A shield cut from a can: a curved tall rectangle (copying the Roman scutum), a bottle-cap boss.
func _concept_rat_can_scutum(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var tin := surf("iron", Color(0.95, 0.95, 1.0), 2.0)
	for k in 5:
		var a := deg_to_rad(-30 + k * 15)
		n.add_child(_box(Vector3(0.4, 11.0, 2.2), tin if k != 2 else plain(c.team), Vector3(sin(a) * 4.0, 0, cos(a) * 4.0 - 4.0), Vector3(0, rad_to_deg(a), 0)))
	n.add_child(cone(1.2, 1.4, 0.6, surf("bronze", Color.WHITE, 1.0), Vector3(0.6, 0, 0), Vector3(0, 0, 90), 14))
	return {"node": n}



# ------------------------------------------------------------------ RB1: the rats' large unit
# Options for a large rodent that isn't just a bigger rat (Dominic). Low and wide or spiky, so
# the silhouette says "big" without only being taller.

func _rodent_legs(n: Node3D, m: Material, hips: Array, r: float, h: float) -> void:
	for hp in hips:
		n.add_child(rod(hp, hp + Vector3(0.5, -h, 0), r, r * 0.8, m))
		n.add_child(blob(Vector3(r * 1.5, r * 0.6, r * 1.1), m, hp + Vector3(1.2, -h, 0)))


## Capybara "big cousin" cavalry: a barrel body, a blunt square head, tiny ears, a tea-towel saddle.
func _concept_capybara_body(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", Color("#9a6a40"), 5.0)
	n.add_child(blob(Vector3(13.0, 8.0, 8.5), fur, Vector3(0, 12, 0)))
	_rodent_legs(n, fur, [Vector3(8, 6, 5), Vector3(8, 6, -5), Vector3(-8, 6, 5.5), Vector3(-8, 6, -5.5)], 2.4, 5.0)
	var head := Node3D.new()
	head.position = Vector3(13, 15, 0)
	n.add_child(head)
	head.add_child(_box(Vector3(9.0, 6.0, 6.0), fur, Vector3(3.5, 0, 0), Vector3(0, 0, -12)))   # the blunt square head
	head.add_child(_box(Vector3(2.0, 3.6, 4.8), surf("rat_fur", Color("#5a3e26"), 4.0), Vector3(7.8, -1.2, 0), Vector3(0, 0, -12)))   # its flat nose
	for side in [1, -1]:
		head.add_child(blob(Vector3(0.9, 1.0, 0.7), fur, Vector3(-0.2, 3.4, 2.6 * side)))   # tiny ears
		head.add_child(blob(Vector3(0.45, 0.45, 0.45), plain(INK), Vector3(3.4, 1.8, 2.9 * side)))
	n.add_child(_box(Vector3(9.0, 1.0, 12.0), plain(Color("#e8e0d0")), Vector3(-1, 20.2, 0)))   # tea-towel saddle
	n.add_child(_box(Vector3(9.2, 1.1, 2.4), plain(c.team), Vector3(-1, 20.3, 0)))              # its team stripe
	return {"node": n, "sockets": {"head": Vector3(13, 22, 0), "hand_r": Vector3(6, 18, 6), "hand_l": Vector3(6, 18, -6),
		"torso": Vector3(0, 12, 0), "back": Vector3(-8, 18, 0)}, "anchors": [], "torso_scale": Vector2(1.4, 0.9)}


## Porcupine pin-fortress: low, with a fan of quills that breaks the outline from every side.
func _concept_porcupine_body(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", Color("#4a3a2e"), 5.0)
	var quill := plain(Color("#e8e0c8"))
	var dark := plain(Color("#2a2420"))
	n.add_child(blob(Vector3(11.0, 7.5, 8.0), fur, Vector3(0, 10, 0)))
	_rodent_legs(n, fur, [Vector3(6, 5, 4.5), Vector3(6, 5, -4.5), Vector3(-6, 5, 4.5), Vector3(-6, 5, -4.5)], 1.8, 4.0)
	var k := 0
	for a in range(-150, 151, 15):   # quills over the back, fanning out
		for row in 3:
			var ang := deg_to_rad(a)
			var base := Vector3(-2.0 + row * 3.5, 14 + cos(ang) * 2.0, sin(ang) * 6.0)
			var tip := base + Vector3(-5.0 - row, 6.0 + cos(ang) * 4.0, sin(ang) * 6.0)
			n.add_child(rod(base, tip, 0.45, 0.12, quill if (k + row) % 3 != 0 else dark, false))
		k += 1
	n.add_child(blob(Vector3(4.0, 3.4, 3.4), fur, Vector3(10.5, 9.0, 0)))   # a small blunt head, low and forward
	n.add_child(blob(Vector3(0.6, 0.6, 0.6), plain(Color("#3a2a24")), Vector3(14.2, 8.4, 0)))
	for side in [1, -1]:
		n.add_child(blob(Vector3(0.45, 0.45, 0.45), plain(INK), Vector3(12.4, 10.0, 1.9 * side)))
	return {"node": n, "sockets": {"head": Vector3(10, 13, 0), "hand_r": Vector3(9, 8, 5), "hand_l": Vector3(9, 8, -5),
		"torso": Vector3(0, 10, 0), "back": Vector3(-6, 16, 0)}, "anchors": [], "torso_scale": Vector2(1.2, 0.8)}


## Naked mole-rat rammer: pink, wrinkled, low and long, big cream incisors, no ears.
func _concept_molerat_body(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var skin := surf("frog_skin", Color("#e8a8a0"), 4.0)
	n.add_child(blob(Vector3(14.0, 6.5, 6.8), skin, Vector3(0, 8, 0)))
	for k in 6:   # wrinkles
		n.add_child(ring(5.8 - absf(k - 2.5) * 0.5, 6.8 - absf(k - 2.5) * 0.5, surf("frog_skin", Color("#c88880"), 4.0), Vector3(-9 + k * 3.6, 8, 0), Vector3(0, 0, 90)))
	_rodent_legs(n, skin, [Vector3(8, 4, 4.5), Vector3(8, 4, -4.5), Vector3(-8, 4, 4.5), Vector3(-8, 4, -4.5)], 1.6, 3.0)
	n.add_child(blob(Vector3(5.0, 4.2, 4.6), skin, Vector3(14, 8.5, 0)))   # the head
	for side in [1, -1]:
		n.add_child(_box(Vector3(1.0, 3.0, 1.0), plain(Color("#f4ead0")), Vector3(18.6, 6.2, 0.7 * side), Vector3(0, 0, -15)))   # incisors
		n.add_child(blob(Vector3(0.3, 0.3, 0.3), plain(INK), Vector3(16.2, 10.4, 2.4 * side)))   # tiny eyes
	return {"node": n, "sockets": {"head": Vector3(14, 12, 0), "hand_r": Vector3(10, 8, 5), "hand_l": Vector3(10, 8, -5),
		"torso": Vector3(0, 8, 0), "back": Vector3(-6, 14, 0)}, "anchors": [], "torso_scale": Vector2(1.4, 0.7)}


## Sewer brute: the same rat, a different build: hunched over huge forearms, knuckles on the ground.
func _concept_brute_body(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", c.skin, 6.0)
	var pink := surf("frog_belly", c.skin2, 5.0)
	n.add_child(blob(Vector3(9.0, 9.0, 8.5), fur, Vector3(-1, 15, 0), Vector3(0, 0, 40)))   # a hunched hump of a back
	n.add_child(blob(Vector3(5.0, 6.0, 5.6), pink, Vector3(3.5, 12, 0), Vector3(0, 0, 40)))
	for side in [1, -1]:   # huge forearms down to the knuckles
		n.add_child(rod(Vector3(4, 19, 6.5 * side), Vector3(9, 9, 7.5 * side), 3.4, 3.0, fur))
		n.add_child(rod(Vector3(9, 9, 7.5 * side), Vector3(10, 1.5, 7 * side), 3.0, 2.6, fur))
		n.add_child(blob(Vector3(2.8, 2.0, 2.6), pink, Vector3(10.5, 1.2, 7 * side)))
	n.add_child(_box(Vector3(6, 3, 0.8), plain(c.team), Vector3(-1, 21, 0), Vector3(0, 0, 40)))   # a team rag over the hump
	for side in [1, -1]:
		n.add_child(rod(Vector3(-4, 8, 3.5 * side), Vector3(-3.5, 1, 4 * side), 2.2, 1.6, fur))
		n.add_child(blob(Vector3(2.6, 0.8, 1.6), pink, Vector3(-2.2, 0.6, 4 * side)))
	return {"node": n, "sockets": {"head": Vector3(8, 18, 0), "hand_r": Vector3(10, 4, 7.5), "hand_l": Vector3(10, 4, -7.5),
		"torso": Vector3(0, 14, 0), "back": Vector3(-6, 20, 0)}, "anchors": [], "torso_scale": Vector2(1.2, 1.0)}

func _box(size: Vector3, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	return mi


## No head (bodies that carry their own).
func _concept_empty(c: Dictionary) -> Dictionary:
	return {"node": Node3D.new(), "sockets": {"top": Vector3.ZERO}}


# ------------------------------------------------------------------ BG1: bug posture
# Beetles today are mount bodies used as infantry. Options for how a beetle soldier stands.

func _insect_leg(n: Node3D, m: Material, hip: Vector3, knee: Vector3, foot: Vector3) -> void:
	n.add_child(rod(hip, knee, 1.1, 0.9, m))
	n.add_child(rod(knee, foot, 0.8, 0.5, m))


## (a) Rearing taur: wing cases low behind on four legs, the pronotum up like a chest, the front
## pair as arms. Stag beetles rear like this to fight.
func _concept_beetle_rear(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var shell := surf("chitin", c.skin, 5.0)
	var plate := surf("chitin", c.skin2, 4.0)
	var leg := surf("chitin", c.skin.darkened(0.45), 3.0)
	for side in [1, -1]:   # the wing cases, low and behind
		n.add_child(blob(Vector3(8.0, 4.6, 3.4), shell, Vector3(-4.5, 8.5, 2.3 * side), Vector3(0, 0, 12)))
		_insect_leg(n, leg, Vector3(-1, 7, 3 * side), Vector3(1, 6, 7 * side), Vector3(2.5, 0, 7.5 * side))
		_insect_leg(n, leg, Vector3(-6, 7, 3 * side), Vector3(-8, 6, 7 * side), Vector3(-10, 0, 7 * side))
	n.add_child(blob(Vector3(4.2, 7.0, 5.4), plate, Vector3(2.5, 15, 0), Vector3(0, 0, -18)))   # pronotum, up like a chest
	n.add_child(blob(Vector3(4.0, 1.0, 5.6), plain(c.team), Vector3(-4.5, 13.2, 0), Vector3(0, 0, 12)))   # a team band across the wing cases
	for side in [1, -1]:   # the front pair as arms
		n.add_child(rod(Vector3(3.5, 17, 4 * side), Vector3(6.5, 13, 6 * side), 0.9, 0.7, leg))
	return {"node": n, "sockets": {"head": Vector3(4, 21.5, 0), "hand_r": Vector3(6.5, 13, 6), "hand_l": Vector3(6.5, 13, -6),
		"torso": Vector3(2.5, 15, 0), "back": Vector3(-6, 13, 0)}, "anchors": [], "torso_scale": Vector2(0.55, 0.65)}


## (b) Upright bug knight: the whole beetle stood on its back pair of legs, like a person.
func _concept_beetle_upright(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var shell := surf("chitin", c.skin, 5.0)
	var plate := surf("chitin", c.skin2, 4.0)
	var leg := surf("chitin", c.skin.darkened(0.45), 3.0)
	for side in [1, -1]:
		n.add_child(blob(Vector3(3.6, 8.0, 3.0), shell, Vector3(-1.6, 13, 2.0 * side), Vector3(0, 0, 8)))   # wing cases as a back
		_insect_leg(n, leg, Vector3(0, 6, 2.5 * side), Vector3(2.5, 3.5, 3 * side), Vector3(0.5, 0, 3.2 * side))
		n.add_child(rod(Vector3(0.5, 12, 3.6 * side), Vector3(2.5, 9, 5.5 * side), 0.8, 0.6, leg))   # middle pair, folded
		n.add_child(rod(Vector3(1.5, 19, 3.6 * side), Vector3(5, 15, 5 * side), 0.9, 0.7, leg))    # front pair, arms
	n.add_child(blob(Vector3(3.4, 4.4, 4.2), plate, Vector3(1.2, 19, 0)))   # pronotum, the chest
	n.add_child(blob(Vector3(1.2, 3.6, 4.4), plain(c.team), Vector3(-3.6, 12, 0)))
	return {"node": n, "sockets": {"head": Vector3(2.5, 23.5, 0), "hand_r": Vector3(5, 15, 5), "hand_l": Vector3(5, 15, -5),
		"torso": Vector3(1, 15, 0), "back": Vector3(-4, 15, 0)}, "anchors": [], "torso_scale": Vector2(0.5, 0.7)}
