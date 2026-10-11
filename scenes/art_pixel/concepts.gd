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

const INK := Color("#2a1a12")


func _concept_body_chunky(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var tunic := surf("cloth", c.team, 8.0)
	var trim := plain(c.cloth)
	var skin := plain(c.skin)
	var belt := plain(Color("#5a3a1e"))
	n.add_child(blob(Vector3(3.9, 5.2, 6.0), tunic, Vector3(0.2, 21.4, 0)))        # chest: broad and deep
	n.add_child(cone(4.6, 5.8, 5.2, tunic, Vector3(0, 15.4, 0)))                  # skirt to mid-thigh
	n.add_child(ring(5.3, 6.0, trim, Vector3(0, 12.9, 0)))                        # hem in the culture's colour
	n.add_child(ring(4.3, 5.3, belt, Vector3(0, 17.8, 0)))
	n.add_child(rod(Vector3(0.4, 25.6, 0), Vector3(0.7, 29.2, 0), 1.7, 1.6, skin))   # the neck, visible
	var near_hand := Vector3.ZERO
	var front := Node3D.new()
	for side in [1, -1]:
		var into: Node3D = front if side == 1 else n
		var sh := Vector3(0.3, 25.4, 6.0 * side)
		var elbow := Vector3(1.3, 20.6, 7.2 * side)
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
	var n := Node3D.new()
	var skin := plain(c.skin)
	var strap := plain(Color("#5a3a1e"))
	n.add_child(rod(Vector3(0, 0, 0), Vector3(0.6, -6.6, 0), 2.2, 1.8, skin))
	n.add_child(rod(Vector3(0.6, -6.6, 0), Vector3(0.2, -12.4, 0), 1.7, 1.35, skin))
	n.add_child(ring(1.2, 1.6, strap, Vector3(0.25, -11.4, 0)))
	n.add_child(blob(Vector3(2.7, 1.2, 1.8), strap, Vector3(1.3, -13.2, 0)))
	return {"node": n}


## The face: an egg, taller than wide, chin and nose forward, a brow ledge with a dark eye row
## under it. No cranium: hair or head gear supplies the top of the head.
func _concept_head_egg(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var skin := plain(c.skin)
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
	var hair := plain(Color("#3a2416"))
	n.add_child(dome(Vector3(3.7, 3.6, 3.6), hair, Vector3(-0.3, -3.2, 0)))
	n.add_child(blob(Vector3(2.4, 2.8, 3.2), hair, Vector3(-1.9, -3.8, 0)))   # the back of the skull: the head has a direction
	return {"node": n}


func _concept_cap_montefortino(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var leather := plain(Color("#8a5a32"))
	var dark := plain(Color("#5e3c1e"))
	n.add_child(dome(Vector3(4.1, 4.2, 3.9), leather, Vector3(-0.3, -3.4, 0)))
	n.add_child(ring(3.9, 4.5, dark, Vector3(-0.2, -3.3, 0)))
	n.add_child(cone(0.35, 0.9, 1.6, dark, Vector3(-0.3, 1.2, 0)))                # the top knob
	n.add_child(blob(Vector3(2.3, 0.45, 3.6), leather, Vector3(-3.4, -4.3, 0), Vector3(0, 0, -25)))   # a little neck lip
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.4, 2.3, 0.45), leather, Vector3(1.4, -5.9, 3.6 * side)))   # cheek flaps
	return {"node": n}


func _concept_galea_heavy(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := plain(Color("#b8bcc0"))
	var bronze := plain(Color("#c89048"))
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

## The frog's skin, wetter and more saturated than today's: poison-dart colours.
func _vivid(c: Color) -> Color:
	return Color.from_hsv(c.h, minf(1.0, c.s * 1.6 + 0.15), minf(1.0, c.v * 1.2 + 0.05))


func _frog_mats(c: Dictionary) -> Array:
	var skin := surf("frog_skin", _vivid(c.skin), 7.0)
	skin.roughness = 0.35   # wet
	skin.metallic_specular = 0.6
	var belly := surf("frog_belly", c.skin2.lightened(0.25), 6.0)
	return [skin, belly]


## Fingers: three long digits ending in round pads, spread from a hand.
func _frog_hand(into: Node3D, hand: Vector3, dir: Vector3, skin: Material, pad: Material) -> void:
	into.add_child(blob(Vector3(1.2, 0.9, 1.2), skin, hand))
	for f in 3:
		var tip := hand + dir * 2.6 + Vector3(0, 0, (f - 1) * 1.3)
		into.add_child(rod(hand, tip, 0.42, 0.38, skin, false))
		into.add_child(blob(Vector3(0.75, 0.6, 0.75), pad, tip))


## Eye domes on top of the head, each with an eye decal looking out and a little forward.
func _frog_eyes(n: Node3D, at: Vector3, spread: float, r: float, skin: Material) -> void:
	for side in [1, -1]:
		var dome := at + Vector3(0, 0, spread * side)
		n.add_child(blob(Vector3(r, r * 1.05, r), skin, dome))
		var look := Vector3(0.6, 0.35, 0.75 * side)
		n.add_child(decal("frog_eye", r * 1.45, r * 1.45, on_surface(dome, Vector3(r, r * 1.05, r), look, 0.1), look, false))


# --- A: the crouched leaper. Back sloping up from the rump to the head, front arms braced on the
# ground, hind legs folded high beside the body, ready to spring.
func _concept_frog_a_body(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _frog_mats(c)
	n.add_child(blob(Vector3(8.2, 5.6, 6.6), m[0], Vector3(-0.5, 9.5, 0), Vector3(0, 0, 32)))
	n.add_child(blob(Vector3(6.0, 3.8, 5.0), m[1], Vector3(1.6, 8.0, 0), Vector3(0, 0, 32)))
	var front := Node3D.new()
	var near_hand := Vector3.ZERO
	for side in [1, -1]:
		var into: Node3D = front if side == 1 else n
		var sh := Vector3(4.2, 11.0, 4.6 * side)
		var elbow := Vector3(6.0, 6.5, 5.6 * side)
		var hand := Vector3(8.0, 1.2, 5.4 * side)
		if side == 1:
			var pose := arm_pose(sh, elbow, Vector3(8.5, 8.5, 5.4), Vector3(7.0, 14.0, 0))
			elbow = pose[0]
			hand = pose[1]
			near_hand = hand
		into.add_child(rod(sh, elbow, 1.5, 1.3, m[0]))
		into.add_child(rod(elbow, hand, 1.3, 1.1, m[0]))
		_frog_hand(into, hand, Vector3(1, -0.15, 0) if side == -1 else Vector3(0.8, 0.5, 0), m[0], m[1])
	kerchief(front, c, Vector3(5.0, 12.2, 0), 3.2, 40)
	return {"node": n, "front": front, "sockets": {
		"head": Vector3(7.0, 14.0, 0), "hand_r": near_hand, "hand_l": Vector3(8.0, 1.2, -5.4),
		"torso": Vector3(1.0, 10.0, 0), "back": Vector3(-4.5, 13.0, 0)},
		"anchors": [[Vector3(-4.5, 6.0, -5.2), 0.0, -1], [Vector3(-4.5, 6.0, 5.2), PI, 1]],
		"torso_scale": Vector2(0.75, 0.6)}


## A long hind leg folded up beside the body: thigh forward and up, shin back down, a long foot.
func _concept_frog_a_leg(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _frog_mats(c)
	var knee := Vector3(5.5, 3.8, 1.6)
	var ankle := Vector3(-2.0, -3.2, 1.2)
	n.add_child(rod(Vector3.ZERO, knee, 2.6, 1.8, m[0]))
	n.add_child(rod(knee, ankle, 1.7, 1.1, m[0]))
	var heel := ankle + Vector3(0, -2.4, 0)
	n.add_child(rod(ankle, heel, 1.1, 0.9, m[0]))
	for t in 4:
		var toe := heel + Vector3(6.5, -0.4, (t - 1.5) * 1.6)
		n.add_child(rod(heel, toe, 0.5, 0.42, m[0], false))
		n.add_child(blob(Vector3(0.8, 0.55, 0.8), m[1], toe))
	return {"node": n}


## A wide, flat head: eyes high on top, a long mouth line, a pale throat.
func _concept_frog_a_head(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _frog_mats(c)
	n.add_child(blob(Vector3(5.8, 3.0, 5.4), m[0], Vector3(2.4, 2.4, 0)))
	n.add_child(blob(Vector3(4.6, 1.6, 4.4), m[1], Vector3(2.8, 0.9, 0)))           # the throat
	n.add_child(rod(Vector3(7.6, 1.9, -3.6), Vector3(7.9, 1.9, 0), 0.32, 0.32, plain(INK)))   # the mouth line, round the front
	n.add_child(rod(Vector3(7.9, 1.9, 0), Vector3(7.6, 1.9, 3.6), 0.32, 0.32, plain(INK)))
	_frog_eyes(n, Vector3(3.2, 5.2, 0), 3.0, 2.2, m[0])
	return {"node": n, "sockets": {"top": Vector3(0.0, 5.4, 0)}}   # behind the eyes: gear never covers them


# --- B: the slim tree frog. Upright but lean, long limbs, big toe pads, eyes bulging at the sides.
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
