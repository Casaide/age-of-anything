extends "res://scenes/art_pixel/siege_concepts.gd"
## The giant newt as the frogs' cavalry mount (concept round SW1 round 4, D-121: Dominic, "Salamander
## I'm not 100% sure, I wonder if better for cavalry?"). Nothing here is in play. A mount in the unit
## parts' frame (x forward, y up, z towards the viewer), composed by UnitView like the beetle: a body
## with a seat, a head on its "head" socket and four legs on its anchors (baked apart, so they walk).
## Three colourings, each its own ids (body/head/leg.newt_<kind>), so the sheet needs no new palette:
##   fire     black, an orange belly, yellow spots (round 3's catapult carrier)
##   eft      a red eft: orange-red, a paler belly, red spots ringed in black
##   crested  a crested newt: dark olive-brown, black spots, an orange belly, a jagged crest

const NEWT := {
	"fire": {"back": Color("#2e2b26"), "belly": Color("#e2862a"), "spot": Color("#f0c030"), "ring": Color(), "crest": false},
	"eft": {"back": Color("#d0582a"), "belly": Color("#f0a448"), "spot": Color("#d42a1a"), "ring": Color("#1e1410"), "crest": false},
	"crested": {"back": Color("#5a5434"), "belly": Color("#e88a22"), "spot": Color("#1c1a12"), "ring": Color(), "crest": true},
}
const NEWT_SEAT := 19.0   # the saddle's top, before NEWT_SCALE (about the beetle's 21.5 after it)
const NEWT_SCALE := 1.2   # grown so the big frog sits on it, not over it


func _newt_mats(kind: String) -> Dictionary:
	var p: Dictionary = NEWT[kind]
	var skin := surf("frog_skin", p.back, 7.0)
	skin.roughness = 0.3   # wet and glossy
	skin.metallic_specular = 0.6
	var belly := surf("frog_belly", p.belly, 5.0)
	belly.roughness = 0.4
	return {"skin": skin, "belly": belly, "spot": plain(p.spot), "ring": plain(p.ring), "p": p}


## Spots along the flanks and back, placed on the body's ellipsoids (a fixed list, not random).
func _newt_spots(n: Node3D, m: Dictionary, centres: Array, big := 1.0) -> void:
	var dirs := [Vector3(0.2, 0.8, 0.55), Vector3(-0.3, 0.7, -0.6), Vector3(0.1, 0.35, 0.95), Vector3(-0.25, 0.4, -0.9),
		Vector3(0.35, 0.9, 0.1)]
	var i := 0
	for c in centres:
		for d in [dirs[i % dirs.size()], dirs[(i + 2) % dirs.size()]]:
			var at := on_surface(c[0], c[1], d, -0.15)
			var r := (1.6 + 0.5 * float(i % 3)) * big
			if m.p.ring != Color():
				n.add_child(blob(Vector3(r * 1.35, r * 0.6, r * 1.35), m.ring, at + d.normalized() * -0.1))
			n.add_child(blob(Vector3(r, r * 0.55, r), m.spot, at + d.normalized() * 0.25))
			i += 1


func _body_newt_fire(c: Dictionary) -> Dictionary:
	return _scaled(_newt_body("fire", c), NEWT_SCALE)


func _body_newt_eft(c: Dictionary) -> Dictionary:
	return _scaled(_newt_body("eft", c), NEWT_SCALE)


func _body_newt_crested(c: Dictionary) -> Dictionary:
	return _scaled(_newt_body("crested", c), NEWT_SCALE)


func _head_newt_fire(c: Dictionary) -> Dictionary:
	return _scaled(_newt_head("fire", c), NEWT_SCALE)


func _head_newt_eft(c: Dictionary) -> Dictionary:
	return _scaled(_newt_head("eft", c), NEWT_SCALE)


func _head_newt_crested(c: Dictionary) -> Dictionary:
	return _scaled(_newt_head("crested", c), NEWT_SCALE)


func _leg_newt_fire(c: Dictionary) -> Dictionary:
	return _scaled(_newt_leg("fire"), NEWT_SCALE)


func _leg_newt_eft(c: Dictionary) -> Dictionary:
	return _scaled(_newt_leg("eft"), NEWT_SCALE)


func _leg_newt_crested(c: Dictionary) -> Dictionary:
	return _scaled(_newt_leg("crested"), NEWT_SCALE)


## The body: a long, low trunk in three overlapping lobes, a pale belly under it, a long tail
## flattened side to side and swinging a little; a team saddle cloth and a reed-bundle saddle.
func _newt_body(kind: String, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _newt_mats(kind)
	var lobes := [[Vector3(9.0, 9.8, 0), Vector3(9.0, 5.4, 7.6)], [Vector3(-1.0, 10.2, 0), Vector3(10.0, 5.8, 8.4)],
		[Vector3(-11.0, 9.8, 0), Vector3(8.5, 5.4, 7.6)]]
	for l in lobes:
		n.add_child(blob(l[1], m.skin, l[0]))
	n.add_child(blob(Vector3(19.0, 3.0, 7.2), m.belly, Vector3(-1.0, 6.4, 0)))
	n.add_child(blob(Vector3(5.0, 4.2, 6.2), m.skin, Vector3(16.0, 9.8, 0)))   # the neck, into the head
	# The tail: tapering, flattened side to side (a newt's paddle), curving a little to the near side.
	var tail := [Vector3(-18, 9.8, 0), Vector3(-27, 8.4, 1.5), Vector3(-35, 6.4, 3.5), Vector3(-43, 4.2, 4.0), Vector3(-49, 2.4, 2.5)]
	var r := [4.8, 3.9, 2.8, 1.7, 0.5]
	for k in range(1, tail.size()):
		var seg := rod(tail[k - 1], tail[k], r[k - 1], r[k], m.skin)
		seg.scale = Vector3(1, 1.0, 0.62)   # flattened
		seg.position = tail[k - 1] * Vector3(0, 0, 0.38)   # keep the path where it was
		n.add_child(seg)
		n.add_child(blob(Vector3((tail[k] - tail[k - 1]).length() * 0.5, r[k] * 0.45, r[k] * 0.5), m.belly,
			(tail[k - 1] + tail[k]) * 0.5 + Vector3(0, -r[k] * 0.55, 0)))
	if m.p.crest:   # a jagged crest down the tail (the back's is under the saddle)
		for k in 9:
			var at: Vector3 = tail[0].lerp(tail[3], k / 8.0)
			var h := 3.6 - k * 0.3
			n.add_child(cone(0.1, 1.3, h, m.skin, at + Vector3(0, lerpf(r[0], r[3], k / 8.0) * 0.92 + h * 0.4, 0), Vector3(0, 0, 18), 6))
		for k in 3:
			n.add_child(cone(0.1, 1.1, 2.8, m.skin, Vector3(13.0 - k * 3.0, 15.4, 0), Vector3(0, 0, 18), 6))
	var spot_on := [[lobes[0][0], lobes[0][1]], [lobes[1][0], lobes[1][1]], [lobes[2][0], lobes[2][1]],
		[Vector3(-26, 9, 1), Vector3(8, 3.9, 2.6)], [Vector3(-36, 6.2, 3), Vector3(7, 2.8, 1.9)]]
	_newt_spots(n, m, spot_on)
	# The saddle: a team cloth over the middle lobe hanging down both flanks, a reed-bundle roll
	# behind the seat, a girth under the belly.
	n.add_child(blob(Vector3(7.5, 1.4, 8.8), plain(c.team), Vector3(-1.5, 15.8, 0), Vector3(0, 0, -4)))
	for side in [1, -1]:
		n.add_child(_box(Vector3(10.0, 6.0, 0.5), plain(c.team), Vector3(-1.5, 12.4, 8.6 * side), Vector3(12 * side, 0, 0)))
	var reed := surf("thatch", Color(1.0, 0.95, 0.82), 7.0)
	n.add_child(rod(Vector3(-7.6, 16.8, -5.5), Vector3(-7.6, 16.8, 5.5), 1.9, 1.9, reed))
	n.add_child(rod(Vector3(4.6, 16.2, -4.0), Vector3(4.6, 16.2, 4.0), 1.2, 1.2, reed))
	harness(n, Vector3(2.5, 10.2, 0), 6.2, 9.0, Vector3(3.5, 10.5, 9.2), Vector3(2.5, 10.5, -9.2))
	var hips := [[Vector3(10.0, 7.6, 6.4), 0.0, 1, 0], [Vector3(-10.0, 7.6, 6.4), PI, 1, 0],
		[Vector3(11.0, 7.6, -6.4), PI, -1, 0], [Vector3(-9.0, 7.6, -6.4), 0.0, -1, 0]]
	return {"node": n, "sockets": {
		"head": Vector3(19.0, 9.8, 0), "hand_r": Vector3(3.5, 10.5, 9.8), "hand_l": Vector3(2.5, 10.5, -9.8),
		"torso": Vector3(0, 10.2, 0), "back": Vector3(-9, 15.5, 0), "seat": Vector3(-1.0, NEWT_SEAT, 0),
		"wings": Vector3(6, 15.5, 0)},
		"anchors": hips, "torso_scale": Vector2(0.8, 0.6), "carry": "harness"}


## The head: broad and flat with a rounded snout, small gold-ringed eyes high on the sides, a
## long closed mouth line, the pale throat; a team browband and a reed bridle.
func _newt_head(kind: String, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _newt_mats(kind)
	n.add_child(blob(Vector3(8.0, 3.6, 6.4), m.skin, Vector3(5.0, 0.6, 0)))
	n.add_child(blob(Vector3(6.6, 1.8, 5.6), m.belly, Vector3(4.6, -1.6, 0)))   # the throat
	n.add_child(rod(Vector3(11.8, -0.5, -4.4), Vector3(13.0, -0.4, 0), 0.32, 0.32, plain(INK)))   # the mouth line
	n.add_child(rod(Vector3(13.0, -0.4, 0), Vector3(11.8, -0.5, 4.4), 0.32, 0.32, plain(INK)))
	n.add_child(rod(Vector3(11.8, -0.5, 4.4), Vector3(4.0, -0.2, 6.2), 0.3, 0.3, plain(INK)))
	n.add_child(rod(Vector3(11.8, -0.5, -4.4), Vector3(4.0, -0.2, -6.2), 0.3, 0.3, plain(INK)))
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.9, 1.7, 1.6), m.skin, Vector3(7.6, 3.0, 3.6 * side)))
		n.add_child(blob(Vector3(1.1, 1.1, 0.9), plain(Color("#c8a030")), Vector3(8.4, 3.4, 4.3 * side)))
		n.add_child(blob(Vector3(0.45, 0.8, 0.4), plain(Color("#100c08")), Vector3(9.0, 3.5, 4.8 * side)))
		n.add_child(blob(Vector3(0.4, 0.3, 0.3), plain(INK), Vector3(12.6, 1.2, 1.4 * side)))   # nostrils
	_newt_spots(n, m, [[Vector3(5.0, 0.6, 0), Vector3(8.0, 3.6, 6.4)]], 0.7)
	if m.p.crest:
		n.add_child(cone(0.1, 1.0, 2.4, m.skin, Vector3(1.0, 4.4, 0), Vector3(0, 0, 18), 6))
	n.add_child(ring(5.2, 5.9, plain(c.team), Vector3(3.6, 0.8, 0), Vector3(0, 0, 90), Vector3(1, 0.62, 1.15)))   # browband
	n.add_child(ring(3.0, 3.5, surf("leather", Color.WHITE, 3.0), Vector3(9.8, 0.2, 0), Vector3(0, 0, 90), Vector3(1, 0.75, 1.4)))   # noseband
	return {"node": n, "sockets": {"top": Vector3(3.0, 3.6, 0)}}


## A sprawling leg: the upper limb out to the side and up, the forearm down, a splayed hand.
func _newt_leg(kind: String) -> Dictionary:
	var n := Node3D.new()
	var m := _newt_mats(kind)
	var elbow := Vector3(1.8, 1.4, 6.0)
	var wrist := Vector3(3.4, -5.6, 8.0)
	n.add_child(rod(Vector3.ZERO, elbow, 3.0, 2.4, m.skin))
	n.add_child(rod(elbow, wrist, 2.3, 1.7, m.skin))
	for t in 4:
		var toe := wrist + Vector3(3.2, -1.2, (t - 1.5) * 1.5)
		n.add_child(rod(wrist + Vector3(0, -0.6, 0), toe, 0.75, 0.55, m.skin))
		n.add_child(blob(Vector3.ONE * 0.6, m.belly, toe))
	return {"node": n}
