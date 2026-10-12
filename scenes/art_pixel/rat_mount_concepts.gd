extends "res://scenes/art_pixel/unit_models.gd"
## The rats' mount, concept round RM1 (2026-10-13, Dominic: "push the capybara further, bigger
## head, need to avoid it looking like a bear. OR, we need a new mount for rats? cat? tiger?").
## Nothing here is in play: tests/rat_mount_sheet.gd puts these ids into the loaded data only.
## Mounts in the unit parts' frame (x forward, y up, z towards the viewer), composed by UnitView
## like any mount: a body with a seat, a head on its "head" socket, four legs on its anchors.
##   capy_long      the capybara pushed: a much longer brick of a head, flat on top, the rump high
##   capy_long_tan  longer still, carried level, a tan face (tools/blender/capybara.py variants)
##   cat            a scruffy sewer alley cat, muzzled and harnessed (tools/blender/big_cat.py)
##   tiger          a tiger (the same script), for the rats or for another culture later

const CAPY_RED := Color("#a65f36")   # a capybara's reddish brown (the palette's is a duller brown)
const CAT := {"fur": Color("#a8a398"), "stripe": Color("#2c2824"), "pale": Color("#e8e2d6"),
	"iris": Color("#b8c838"), "nose": Color("#c88080")}
const TIGER := {"fur": Color("#e0782a"), "stripe": Color("#1c1612"), "pale": Color("#f2ece0"),
	"iris": Color("#e8b828"), "nose": Color("#b86a60")}
const TIGER_SCALE := 1.1
const CAT_SCALE := 1.2
const CAT_HEAD := 1.35
const TIGER_HEAD := 1.35


# ------------------------------------------------------------------ the capybara, pushed
# The looks themselves live in unit_models.gd (capybara_look "long" and "long_tan"); here they
# are shown in a redder brown, a capybara's real colour (the palette's is a duller brown).

func _red(c: Dictionary) -> Dictionary:
	var r := c.duplicate()
	r.skin = CAPY_RED
	return r


func _body_rm_capy_long(c: Dictionary) -> Dictionary:
	return _body_capybara_long(_red(c))


func _head_rm_capy_long(c: Dictionary) -> Dictionary:
	return _head_capybara_long(_red(c))


func _leg_rm_capy_long(c: Dictionary) -> Dictionary:
	return _leg_capybara_long(_red(c))


func _body_rm_capy_long_tan(c: Dictionary) -> Dictionary:
	return _body_capybara_long_tan(_red(c))


func _head_rm_capy_long_tan(c: Dictionary) -> Dictionary:
	return _head_capybara_long_tan(_red(c))


func _leg_rm_capy_long_tan(c: Dictionary) -> Dictionary:
	return _leg_capybara_long(_red(c))


# ------------------------------------------------------------------ the cats

func _cat_mats(p: Dictionary) -> Dictionary:
	return {"fur": surf("hide", p.fur, 4.0), "stripe": surf("hide", p.stripe, 4.0), "pale": surf("hide", p.pale, 4.0),
		"nose": plain(p.nose), "eye": plain(INK), "iris": plain(p.iris), "ear_in": plain(p.nose.lightened(0.2))}


## A saddle cloth in the team's colour with a pale border, a leather saddle on it, a girth.
func _cat_saddle(n: Node3D, c: Dictionary, x: float, y: float, half: float, girth_c: Vector3, ry: float, rz: float) -> void:
	var cloth := plain(c.team)
	var trim := surf("cloth", Color("#e8e0d0"), 3.0)
	n.add_child(_box(Vector3(9.0, 0.7, half * 1.7), cloth, Vector3(x, y, 0)))
	for side in [1, -1]:
		n.add_child(_box(Vector3(9.0, 4.4, 0.5), cloth, Vector3(x, y - 2.4, (half * 0.85) * side), Vector3(10 * side, 0, 0)))
		n.add_child(_box(Vector3(9.2, 0.7, 0.6), trim, Vector3(x, y - 4.5, (half * 0.85 + 0.35) * side), Vector3(10 * side, 0, 0)))
	n.add_child(_box(Vector3(5.5, 1.2, half * 1.2), surf("leather", Color(0.7, 0.5, 0.35), 3.0), Vector3(x, y + 0.8, 0)))   # the saddle
	harness(n, girth_c, ry, rz, girth_c + Vector3(-1, -1, rz + 0.4), girth_c + Vector3(-1, -1, -rz - 0.4))


## A tail as a chain of rods along `pts`, ringed dark every other segment.
func _cat_tail(n: Node3D, pts: Array, r0: float, r1: float, fur: Material, dark: Material, tip_dark := true) -> void:
	var count := pts.size() - 1
	for k in count:
		var ra := lerpf(r0, r1, float(k) / count)
		var rb := lerpf(r0, r1, float(k + 1) / count)
		var m := dark if (k % 2 == 1 or (tip_dark and k == count - 1)) else fur
		n.add_child(rod(pts[k], pts[k + 1], ra, rb, m))


func _cat_rig(head: Vector3, seat: Vector3, front: float, back: float, hip_y: float, z: float) -> Dictionary:
	return {"sockets": {
		"head": head, "hand_r": seat + Vector3(5, -6, 5.0), "hand_l": seat + Vector3(4, -6, -5.0),
		"torso": Vector3(0, seat.y - 5, 0), "back": seat + Vector3(-7, -1.5, 0), "seat": seat, "wings": seat + Vector3(7, -1.5, 0)},
		"anchors": _four_legs(front, back, hip_y, z), "torso_scale": Vector2(1.3, 1.0), "carry": "harness"}


## The alley cat: lean and long-legged on the game's legs, its tail held up in a hook.
func _body_rm_cat(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _cat_mats(CAT)
	n.add_child(glb("body_cat", m))
	_cat_tail(n, [Vector3(-12.5, 17.0, 0), Vector3(-15.5, 21.0, 0), Vector3(-17.0, 26.0, 0.3), Vector3(-16.6, 30.5, 0.5),
		Vector3(-14.8, 33.1, 0.6), Vector3(-12.8, 33.3, 0.6)], 1.6, 1.1, m.fur, m.stripe)
	_cat_saddle(n, c, -1.5, 19.5, 4.8, Vector3(1.5, 15.3, 0), 5.0, 5.0)
	var r := _cat_rig(Vector3(13.4, 19.6, 0), Vector3(-1.5, 21.1, 0), 7.5, -9.0, 13.0, 3.0)
	r["node"] = n
	return _scaled(r, CAT_SCALE)


## Round skull, big pointed ears (one notched), a short muzzle in a leather muzzle and bridle.
func _head_rm_cat(c: Dictionary) -> Dictionary:
	var root := Node3D.new()
	var n := glb("head_cat", _cat_mats(CAT))
	n.rotation_degrees.z = -8
	n.scale = Vector3.ONE * CAT_HEAD
	root.add_child(n)
	_cat_bridle(root, c, Vector3(4.9, -0.3, 0) * CAT_HEAD, 1.85 * CAT_HEAD, Vector3(-0.3, 1.2, 0) * CAT_HEAD, 3.3 * CAT_HEAD, -8)
	return _scaled({"node": root, "sockets": {"top": Vector3(1.6, 4.0, 0) * CAT_HEAD}}, CAT_SCALE)


## A muzzle strap round the snout, a headstall behind the eyes, its brow band in team colour.
func _cat_bridle(n: Node3D, c: Dictionary, snout: Vector3, sr: float, crown: Vector3, cr: float, tilt: float) -> void:
	var leather := surf("leather", Color(0.55, 0.4, 0.28), 2.0)
	var q := Basis(Vector3(0, 0, 1), deg_to_rad(tilt))
	n.add_child(ring(sr * 0.92, sr * 1.08, leather, q * snout, Vector3(0, 0, 90 + tilt), Vector3(1, 1.4, 1)))
	n.add_child(ring(cr * 0.9, cr * 1.04, leather, q * crown, Vector3(0, 0, 70 + tilt), Vector3(1, 1.6, 1)))
	n.add_child(rod(q * (snout + Vector3(-0.6, sr * 0.6, 0)), q * (crown + Vector3(1.6, cr * 0.7, 0)), 0.3, 0.3, leather))
	n.add_child(blob(Vector3(0.5, 0.5, 0.5), surf("bronze", Color.WHITE, 2.0), q * (snout + Vector3(-0.8, 0, sr * 1.02))))   # the ring the rein ties to


## Long slim legs: a thigh, a long shin, a white-socked paw.
func _leg_rm_cat(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("hide", CAT.fur, 4.0)
	var dark := surf("hide", CAT.stripe, 4.0)
	var pale := surf("hide", CAT.pale, 4.0)
	n.add_child(blob(Vector3(2.8, 4.6, 2.5), fur, Vector3(0, -1.6, 0)))   # the thigh, deep into the leg
	n.add_child(rod(Vector3(0, -3.5, 0), Vector3(0.3, -8.6, 0), 1.6, 1.1, fur))
	n.add_child(rod(Vector3(0.3, -8.6, 0), Vector3(0.5, -11.2, 0), 1.05, 1.0, pale))
	n.add_child(blob(Vector3(1.7, 1.0, 1.4), pale, Vector3(1.0, -11.6, 0)))
	return _scaled({"node": n}, CAT_SCALE)


## The tiger: longer and heavier, the head low and broad, the tail long and low.
func _body_rm_tiger(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _cat_mats(TIGER)
	n.add_child(glb("body_tiger", m))
	_cat_tail(n, [Vector3(-16.5, 20.0, 0), Vector3(-20.0, 17.5, 0), Vector3(-22.6, 13.5, 0.3), Vector3(-24.0, 9.5, 0.5),
		Vector3(-24.2, 6.6, 0.6), Vector3(-23.0, 4.8, 0.6)], 1.9, 1.3, m.fur, m.stripe)
	_cat_saddle(n, c, -1.5, 22.8, 6.6, Vector3(2.0, 18.0, 0), 6.6, 7.0)
	var r := _cat_rig(Vector3(15.0, 21.0, 0), Vector3(-1.5, 24.4, 0), 8.0, -12.5, 14.5, 4.0)
	r["node"] = n
	return _scaled(r, TIGER_SCALE)


func _head_rm_tiger(c: Dictionary) -> Dictionary:
	var root := Node3D.new()
	var n := glb("head_tiger", _cat_mats(TIGER))
	n.rotation_degrees.z = -10
	n.scale = Vector3.ONE * TIGER_HEAD
	root.add_child(n)
	_cat_bridle(root, c, Vector3(6.0, -0.6, 0) * TIGER_HEAD, 2.5 * TIGER_HEAD, Vector3(-0.4, 1.0, 0) * TIGER_HEAD, 4.0 * TIGER_HEAD, -10)
	return _scaled({"node": root, "sockets": {"top": Vector3(1.6, 4.0, 0) * TIGER_HEAD}}, TIGER_SCALE)


func _leg_rm_tiger(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("hide", TIGER.fur, 4.0)
	var dark := surf("hide", TIGER.stripe, 4.0)
	var pale := surf("hide", TIGER.pale, 4.0)
	n.add_child(blob(Vector3(3.4, 4.4, 3.0), fur, Vector3(0, -1.0, 0)))
	n.add_child(rod(Vector3(0, -2.5, 0), Vector3(0.3, -8.6, 0), 2.1, 1.65, fur))
	for y in [-4.5, -7.2]:
		n.add_child(ring(1.5, 2.05, dark, Vector3(0.15, y, 0), Vector3(0, 0, 8), Vector3(1, 0.6, 1)))
	n.add_child(rod(Vector3(0.3, -8.6, 0), Vector3(0.6, -12.8, 0), 1.55, 1.4, fur))
	n.add_child(blob(Vector3(2.2, 1.1, 1.9), pale, Vector3(1.2, -13.3, 0)))   # the big paw
	return _scaled({"node": n}, TIGER_SCALE)
