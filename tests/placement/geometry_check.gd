extends RefCounted
## The 3D half of the placement check (headless): every unit put together in 3D (rig3d.gd) in every
## pose the game draws it in (standing in each hold it's baked in, the walk at eight phases), its
## meshes read in world space and voxelized (geom.gd), and the rules below asserted as numbers:
##   A1 ground: standing, every foot on the ground; walking, a foot planted and none sunk; nothing
##      below the ground; the centre of mass over the feet.
##   A2 attachment: hips, neck and hands on their parent's surface (not floating, not buried deep);
##      a leg and a head mostly outside the body; head gear on the head; worn armour round the body's
##      torso, not off it; a rider's seat on its mount's back; siege crews on the ground or the deck.
##   A3 interpenetration: pieces that aren't jointed don't share volume; jointed ones only near the joint.
##   A4 stance (data: parts.json legs.stance): a standing leg reaches down, not folded up, and its
##      foot is out to its own side by the body's sprawl.
## Results are {rule|case: [failing views]}, like tests/layer_check.gd.

const Geom := preload("res://tests/placement/geom.gd")
const Rig3D := preload("res://tests/placement/rig3d.gd")
const UnitView := preload("res://src/unit_view.gd")

## Tolerances (part units; one part unit is 1.275 art pixels at game size).
const GROUND_TOL := 1.0      # a foot within this of the ground plane; nothing deeper than this below it
const SUPPORT_SLACK := 3.0   # the centre of mass within this of the feet's support polygon
const ATTACH_GAP := 1.0      # a joint at most this far outside its parent's surface (floating)
const BURY := 4.0            # ...and at most this deep inside it (data: legs.stance.bury)
const OUTSIDE := 0.5         # at least this share of a leg's or head's volume outside its parent
const JOINT_R := 4.0         # jointed pieces may share volume this near the joint (or 45% of the child's reach)
const PEN_VOX := 12          # shared voxels allowed anywhere (1.5 cubic units: rounding where surfaces touch)
const PEN_SHARE := 0.03      # ...plus this share of the smaller piece
const ARMOUR_OFF := 0.25     # at most this share of worn armour more than 1.5 units off its body
const ARMOUR_CENTRE := 1.5   # worn armour's middle at most this far (across) from the middle of the body it covers
const SEAT_SINK := 0.3       # at most this share of a rider's body inside its mount
const SEAT_GAP := 1.5        # a rider's lowest point at most this far over its mount's back
const DROP := 0.6            # a standing leg's drop (hip to foot) is at least this share of its reach (data: legs.stance.drop)
const SPRAWL := [-2.0, 6.0]  # a standing foot this far out to its own side of its hip (data: legs.stance.sprawl)
const WALK_PHASES := 8
const BROW_CLEAR := 0.5      # an open cap's lowest edge over the eyes at least this above the brow
const EYE_CLEAR := 3.0       # nothing of the head gear this far out in front of an eye

var lib
var rig: Rig3D
var results := {}
var order := []
var metrics := false
var _vox_cache := {}


func _init(l) -> void:
	lib = l
	rig = Rig3D.new(l)


func note(rule: String, label: String, view: String, bad: bool, detail := "") -> void:
	var key := rule + "|" + label
	if not results.has(key):
		results[key] = []
		order.append(key)
	if bad:
		results[key].append(view + (" (" + detail + ")" if detail != "" else ""))


## The poses a unit's body is drawn in, beyond walking: its own hold standing, and the holds it
## swings through (UnitView._work for workers: wound up with the tool back, reaching down to the
## work; _attack for melee soldiers: the same blow; a spear's thrust, levelled and driven forward).
## Ranged units only loose (their own hold). [name, hold, the weapon's turn (2D radians, clockwise
## on screen), levelled]
func poses(r: Dictionary) -> Array:
	var out := [["stand", "", 0.0, false]]
	if r.has("mount") or r.has("crew"):
		return out
	if rig.models.has(r.body) and rig.spec(r.body, UnitView.colours_for(lib, r.skin, r.family, Color.MAGENTA)).get("carry", "") == "harness":
		return out
	var hand: String = r.parts.get("hand_r", "")
	var tags: Array = lib.part(hand).tags if hand != "" else []
	if r.get("slot", "") == "worker":
		out += [["work wound up", "raise", -1.2, false], ["work blow", "reach", 0.9, false]]
	elif "ranged" in tags or r.get("slot", "") in ["archer", "skirmisher", "healer"]:
		pass
	elif "spear" in tags or "lance" in tags:
		out += [["thrust", "thrust", 0.0, true]]
	elif hand != "":
		out += [["blow wound up", "raise", -1.1, false], ["blow lands", "reach", 0.9, false], ["blow starts", "reach", -0.4, false]]
	return out


func check(label: String, u: Dictionary) -> void:
	var r: Dictionary = u.recipe
	if r.has("crew"):
		_check_engine(label, r)
		rig.clear()
		return
	# The data's 2D anchors (drawn before the body is baked, and the count of legs asked to bake) are
	# the model's hips, one for one.
	for body_id in [r.body, lib.creatures[r.mount.creature].get("mount_body", lib.creatures[r.mount.creature].body) if r.has("mount") else ""]:
		if body_id == "" or not lib.part(body_id).has("legs") or not rig.models.has(body_id):
			continue
		var n3: int = rig.spec(body_id, UnitView.colours_for(lib, r.skin, r.family, Color.MAGENTA)).get("anchors", []).size()
		var n2: int = lib.part(body_id).legs.anchors.size()
		note("A2 the data's legs are the model's", label, body_id, n2 != n3, "%s: %d anchors in parts.json, %d hips in the model" % [body_id, n2, n3])
	for po in poses(r):
		var a: Dictionary = rig.unit(r, {"hold": po[1], "turn": -float(po[2]), "level": po[3]})
		_check_pose(label, po[0], a, po[0] == "stand")
	for i in WALK_PHASES:
		var ph := TAU * i / WALK_PHASES
		var a: Dictionary = rig.unit(r, {"walk": ph})
		_check_walk(label, "walk %d" % i, a)
		if i % 2 == 0:
			_check_pose(label, "walk %d" % i, a, false)
	# A body that rests in its own poses when it stands still (parts.json idle_poses: a cat sits
	# down in steps) is checked in each, as standing: every foot down, the weight over the feet.
	var walker_body: String = r.body
	if r.has("mount"):
		var mc: Dictionary = lib.creatures[r.mount.creature]
		walker_body = mc.get("fused_body", mc.body) if r.mount.fused else mc.get("mount_body", mc.body)
	for bp in lib.part(walker_body).get("idle_poses", []):
		_check_pose(label, bp, rig.unit(r, {"body_pose": bp}), true)
	rig.clear()
	if _vox_cache.size() > 600:
		_vox_cache.clear()   # (kept across units: a mount's body and legs voxelize once for all its riders)


func _vox(p: Dictionary) -> Dictionary:
	var k := "%s|%s" % [p.geo, var_to_str(p.xf)]
	if not _vox_cache.has(k):
		_vox_cache[k] = Geom.voxels(p.node, p.xf)
	return _vox_cache[k]


func _verts(p: Dictionary) -> PackedVector3Array:
	return Geom.vertices(p.node, p.xf)


func _stance(body_id: String) -> Dictionary:
	return lib.part(body_id).get("legs", {}).get("stance", {})


func _by(a: Dictionary, name: String) -> Dictionary:
	for p in a.pieces:
		if p.name == name:
			return p
	return {}


func _legs(a: Dictionary) -> Array:
	return a.pieces.filter(func(p): return p.kind == "leg" and p.rig == a.walker)


## Ground contact while standing, attachment, interpenetration, stance.
func _check_pose(label: String, view: String, a: Dictionary, standing: bool) -> void:
	var legs := _legs(a)
	var body := _by(a, a.walker + ":body")
	if body.is_empty():
		return
	var body_id: String = body.id.get_slice("@", 0)
	var st := _stance(body_id)
	if a.get("body_pose", "") != "":
		# A resting pose may relax the stance (legs.stance.poses: a sitting cat's hind legs fold flat).
		st = st.duplicate()
		st.merge(st.get("poses", {}).get(a.body_pose, {}), true)
	if standing and not legs.is_empty() and not a.flying:
		# A1: every foot on the ground; nothing below it; the weight over the feet.
		var feet := []
		var worst := 0.0
		var what := ""
		for l in legs:
			var vs := _verts(l)
			var lo := INF
			for v in vs:
				lo = minf(lo, v.y)
			if absf(lo) > absf(worst):
				worst = lo
				what = l.name
			var sum := Vector2.ZERO
			var n := 0
			for v in vs:
				if v.y <= lo + 0.5:
					sum += Vector2(v.x, v.z)
					n += 1
			feet.append(sum / maxf(n, 1))
			# A4: the leg reaches down (not folded up) and its foot is out to its side by the sprawl.
			var reach := 0.0
			for v in vs:
				reach = maxf(reach, v.distance_to(l.joint))
			var drop: float = (l.joint.y - lo) / maxf(reach, 0.01)
			var want_drop := float(st.get("drop", DROP))
			note("A4 a standing leg reaches down", label, view, drop < want_drop, "%s drop %.2f of its reach, %.2f wanted" % [l.name, drop, want_drop])
			var out_by: float = (feet[-1].y - l.joint.z) * signf(l.hip.z) if absf(l.hip.z) > 0.3 else 0.0
			var sp: Array = st.get("sprawl", SPRAWL)
			note("A4 feet out to their own side", label, view, absf(l.hip.z) > 0.3 and (out_by < float(sp[0]) or out_by > float(sp[1])),
				"%s foot %.1f out from its hip, %s wanted" % [l.name, out_by, str(sp)])
		note("A1 standing feet on the ground", label, view, absf(worst) > GROUND_TOL, "%s lowest point at %.2f" % [what, worst])
		var com := Vector3.ZERO
		var mass := 0
		for p in a.pieces:
			for q in _vox(p):
				com += Geom.centre(q)
				mass += 1
		com /= maxf(mass, 1)
		var off := _outside_polygon(feet, Vector2(com.x, com.z))
		var slack := float(st.get("support", SUPPORT_SLACK))
		note("A1 weight over the feet", label, view, off > slack, "centre of mass %.1f outside the feet, %.1f allowed" % [off, slack])
	if standing and not legs.is_empty():
		# A leg that isn't the same on both sides (it sprawls out to one side, or points back on a
		# rear hip) must be baked at each hip, turned to its side (parts.json "cut": ["legs"]): one
		# sprite for every hip puts the far legs' feet under the body or the rear legs facing forward.
		var cut: bool = "legs" in body.get("cut", [])
		for l in legs:
			var box := AABB()
			var first := true
			for v in Geom.vertices(l.node):
				box = AABB(v, Vector3.ZERO) if first else box.expand(v)
				first = false
			var one_sided := absf(box.get_center().z) > 0.6
			note("A2 one-sided legs baked at each hip", label, view, not cut and (one_sided or l.get("flip", false)),
				"%s %s" % [l.name, "sprawls to one side" if one_sided else "points back on a rear hip"])
	if not view.begins_with("walk"):
		var lowest := INF
		var what := ""
		for p in a.pieces:
			for v in _verts(p):
				if v.y < lowest:
					lowest = v.y
					what = p.name
		note("A1 nothing below the ground", label, view, lowest < -GROUND_TOL, "%s at %.2f" % [what, lowest])
	_check_attachment(label, view, a, st)
	_check_overlap(label, view, a)


## A1 while walking: one foot planted at every phase, none through the ground.
func _check_walk(label: String, view: String, a: Dictionary) -> void:
	var legs := _legs(a)
	if legs.is_empty() or a.flying or a.gait.get("hop", false):
		return
	var lowest := INF
	for l in legs:
		var lo := INF
		for v in _verts(l):
			lo = minf(lo, v.y)
		lowest = minf(lowest, lo)
	note("A1 walking, a foot planted", label, view, lowest > GROUND_TOL, "lowest foot %.2f over the ground" % lowest)
	note("A1 walking, no foot through the ground", label, view, lowest < -GROUND_TOL, "a foot %.2f under the ground" % -lowest)


## Distance from p to a convex polygon round the points (0 inside); a segment or a point for fewer.
static func _outside_polygon(pts: Array, p: Vector2) -> float:
	var hull: PackedVector2Array = Geometry2D.convex_hull(PackedVector2Array(pts))
	if hull.size() >= 4 and Geometry2D.is_point_in_polygon(p, hull):
		return 0.0
	var best := INF
	for i in hull.size():
		var a: Vector2 = hull[i]
		var b: Vector2 = hull[(i + 1) % hull.size()]
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best if hull.size() > 0 else 0.0


func _check_attachment(label: String, view: String, a: Dictionary, st: Dictionary) -> void:
	for p in a.pieces:
		if p.parent == "":
			continue
		var parent := _by(a, p.parent)
		if parent.is_empty():
			continue
		var pv := _vox(parent)
		if p.parent.ends_with(":body") and not _by(a, p.rig + ":arm").is_empty() and p.kind == "hand_r":
			pv = _vox(_by(a, p.rig + ":arm"))
		match p.kind:
			"leg", "head":
				# Attached: it touches its body (a thigh may rise above its hip into the body), and its
				# joint is neither off the body nor buried deep in it.
				var mine := _vox(p)
				var d := Geom.depth(pv, p.joint, 8.0)
				var bury := float(st.get("bury", BURY)) if p.kind == "leg" else BURY
				var touches := Geom.shared(mine, pv) > 0
				note("A2 %s joint on its body's surface" % p.kind, label, view, (d > ATTACH_GAP and not touches) or d > ATTACH_GAP + 2.0 or d < -bury,
					"%s joint %.1f %s the body%s" % [p.name, absf(d), "outside" if d > 0 else "inside", "" if touches else ", not touching it"])
				var outside := {}
				for q in mine:
					if not pv.has(q):
						outside[q] = true
				if p.kind == "leg" and parent.get("legs_under", false):
					# Under a skirt: the leg shows below the body's hem.
					var hem := INF
					for q in pv:
						hem = minf(hem, Geom.centre(q).y)
					var foot := INF
					for q in mine:
						foot = minf(foot, Geom.centre(q).y)
					note("A2 a leg shows under its skirt", label, view, hem - foot < 3.0, "%s %.1f below the hem" % [p.name, hem - foot])
				else:
					var share := float(outside.size()) / maxf(mine.size(), 1)
					var want := 1.0 - float(st.get("inside" if p.kind == "leg" else "head_inside", 1.0 - OUTSIDE))
					note("A2 a %s mostly outside its body" % p.kind, label, view, share < want, "%s %.2f outside, %.2f wanted" % [p.name, share, want])
				# A3: what's outside comes out of the body in one piece (a leg through the body and out of
				# its back is two pieces).
				var parts := Geom.components(outside)
				var stray := 0
				for i in range(1, parts.size()):
					stray += parts[i]
				note("A3 a %s comes out of its body in one piece" % p.kind, label, view, stray > PEN_VOX + int(PEN_SHARE * mine.size()),
					"%s %d voxels in %d other pieces" % [p.name, stray, parts.size() - 1])
			"hand_r", "hand_l":
				if p.get("harness", false):
					continue
				var d := Geom.depth(pv, p.joint, 8.0)
				note("A2 held in the hand", label, view, d > ATTACH_GAP, "%s %.1f off the hand" % [p.name, d])
			"head_gear":
				var mine := _vox(p)
				var touch := Geom.shared(mine, pv) > 0 or Geom.depth(pv, p.joint, 4.0) <= ATTACH_GAP
				note("A2 head gear on the head", label, view, not touch, p.name)
				_check_brow(label, view, p, parent)
			"back":
				var d := Geom.depth(pv, p.joint, 8.0)
				note("A2 back gear on the back", label, view, d > ATTACH_GAP + 1.0 and Geom.shared(_vox(p), pv) == 0, "%s %.1f off the back, not touching it" % [p.name, d])
			"armour":
				_check_armour(label, view, p, parent)
	# A rider sits on its mount's back: not sunk into it, not floating over it.
	var rb := _by(a, "rider:body")
	var mb := _by(a, "mount:body")
	if not rb.is_empty() and not mb.is_empty() and not a.get("fused", false):
		var rv := _vox(rb)
		var mv := _vox(mb)
		var sunk := float(Geom.shared(rv, mv)) / maxf(rv.size(), 1)
		note("A2 rider not sunk into its mount", label, view, sunk > SEAT_SINK, "%.2f of the rider inside the mount" % sunk)
		# The seat (where the rider's hips go) is on the mount's back: the top of the mount there.
		var seat: Vector3 = a.seat
		var c := Geom.unkey(Geom.cell(seat))
		var top := -INF
		for j in range(c.y - 40, c.y + 40):
			for i in [-1, 0, 1]:
				if mv.has(Geom.key(c.x + i, j, c.z)):
					top = maxf(top, (j + 1) * Geom.RES)
		note("A2 the seat on its mount's back", label, view, absf(seat.y - top) > SEAT_GAP, "seat %.1f %s the back" % [absf(seat.y - top), "over" if seat.y > top else "under"])


## Head gear leaves the face clear: every eye seen from in front of it (nothing of the gear within
## EYE_CLEAR out along the eye's look), and on a head with a modelled brow, nothing of an open cap or
## hat (not "face": "covered" in parts.json, as a face-guard helmet is) lower than BROW_CLEAR above
## it over the eyes: a cap's brim across the brows read as a headband (Dominic).
func _check_brow(label: String, view: String, gear: Dictionary, head: Dictionary) -> void:
	var eyes: Array = Geom.features(head.node, "eye", head.xf)
	if eyes.is_empty():
		return
	var gv := _vox(gear)
	var mid := Vector3.ZERO
	var hv := _vox(head)
	for q in hv:
		mid += Geom.centre(q)
	mid /= maxf(hv.size(), 1)
	var covered := 0
	for e in eyes:
		var c: Vector3 = e.get_center()
		var look := (c - mid).normalized()
		for t in range(1, int(EYE_CLEAR / Geom.RES) + 1):
			if gv.has(Geom.cell(c + look * (t * Geom.RES))):
				covered += 1
				break
	note("A2 head gear leaves the eyes in sight", label, view, covered > 0, "%s covers %d of %d eyes" % [gear.id, covered, eyes.size()])
	var brows: Array = Geom.features(head.node, "brow", head.xf)
	if brows.is_empty() or lib.part(gear.id).get("face", "") == "covered":
		return
	var brow := -INF
	for b in brows:
		brow = maxf(brow, b.end.y)
	var low := INF
	for v in _verts(gear):
		for e in eyes + brows:
			var box: AABB = e.grow(0.5)
			if v.x >= box.position.x and v.x <= box.end.x and v.z >= box.position.z and v.z <= box.end.z and v.y < brow + 3.0:
				low = minf(low, v.y)
	note("A2 an open cap clear of the brow", label, view, low < brow + BROW_CLEAR, "%s comes %.2f above the brow, %.2f wanted" % [gear.id, low - brow, BROW_CLEAR])


## Worn armour round its body's torso: most of it on or near the body (not off in front), its middle
## near the torso socket.
func _check_armour(label: String, view: String, p: Dictionary, body: Dictionary) -> void:
	var av := _vox(p)
	var bv := _vox(body)
	var coarse := {}
	for q in bv:
		var c := Geom.centre(q)
		coarse[Vector3i(floori(c.x / 1.5), floori(c.y / 1.5), floori(c.z / 1.5))] = true
	var near := {}
	for c in coarse:
		for i in [-1, 0, 1]:
			for j in [-1, 0, 1]:
				for k in [-1, 0, 1]:
					near[c + Vector3i(i, j, k)] = true
	var off := 0
	var mid := Vector3.ZERO
	for q in av:
		var c := Geom.centre(q)
		mid += c
		if not near.has(Vector3i(floori(c.x / 1.5), floori(c.y / 1.5), floori(c.z / 1.5))):
			off += 1
	mid /= maxf(av.size(), 1)
	var share := float(off) / maxf(av.size(), 1)
	note("A2 worn armour on its body", label, view, share > ARMOUR_OFF, "%s %.2f of it off the body" % [p.id, share])
	var box := AABB(mid, Vector3.ZERO)
	for q in av:
		box = box.expand(Geom.centre(q))
	# Its middle over the middle of the body inside it (the part of the body it covers), not
	# off to the front of it with the head riding on it (Dominic: the rat's).
	var torso := Vector3.ZERO
	var n := 0
	for q in bv:
		var c := Geom.centre(q)
		if box.has_point(c):
			torso += c
			n += 1
	torso /= maxf(n, 1)
	var d := Vector2(mid.x - torso.x, mid.z - torso.z).length()
	note("A2 worn armour centred on the torso", label, view, d > ARMOUR_CENTRE,
		"%s middle %.1f from the middle of the body it covers, %.1f allowed" % [p.id, d, ARMOUR_CENTRE])


## How far the lowest of a's voxels sits over b's top, in the columns they share (0 if they overlap;
## INF if they share no column).
static func _gap_over(a: Dictionary, b: Dictionary) -> float:
	var low := {}
	for q in a:
		var v := Geom.unkey(q)
		var c := Vector2i(v.x, v.z)
		low[c] = mini(low.get(c, 1 << 20), v.y)
	var top := {}
	for q in b:
		var v := Geom.unkey(q)
		var c := Vector2i(v.x, v.z)
		if low.has(c):
			top[c] = maxi(top.get(c, -(1 << 20)), v.y)
	var best := INF
	for c in top:
		best = minf(best, float(low[c] - top[c] - 1) * Geom.RES)
	return maxf(best, 0.0)


## Pairs that are free to overlap: an arm and its own body (the shoulder), armour and what it wraps,
## head gear and its head, a weapon and the arm that holds it.
const WRAPPED := ["leg", "head", "back", "hand_l"]
const HELD := ["hand_r", "hand_l"]
const FREE := [["arm", "body"], ["armour", "body"], ["armour", "arm"], ["head_gear", "head"], ["hand_r", "arm"]]


func _check_overlap(label: String, view: String, a: Dictionary) -> void:
	var ps: Array = a.pieces
	for i in ps.size():
		for j in range(i + 1, ps.size()):
			var p: Dictionary = ps[i]
			var q: Dictionary = ps[j]
			var cross: bool = (p.rig == "rider") != (q.rig == "rider")
			if p.rig != q.rig and not cross:
				continue
			if cross and p.kind == "body" and q.kind == "body":
				continue   # the seat: its own check
			if cross and a.get("fused", false) and (p.kind == "body" or q.kind == "body"):
				continue   # a centaur grows out of its horse half: its tunic and armour cover the join
			var free := false
			if p.rig == q.rig:
				for f in FREE:
					if (p.kind == f[0] and q.kind == f[1]) or (p.kind == f[1] and q.kind == f[0]):
						free = true
			if free:
				continue
			if (p.kind in ["leg", "head"] and p.parent == q.name) or (q.kind in ["leg", "head"] and q.parent == p.name):
				continue   # a leg or head in its own body: the attachment rules above
			var pv := _vox(p)
			var qv := _vox(q)
			var common := Geom.intersect(pv, qv)
			if common.is_empty():
				continue
			# Jointed (one hangs from the other, or armour round a leg's or head's root): only near the joint.
			# The near arm's layer (with its scarf) meets the head at the neck; armour meets what hangs
			# from the body near its root; what a rider holds may rest on its mount near the hand.
			var child := {}
			if p.parent == q.name or (q.kind == "armour" and p.kind in WRAPPED) or (q.kind == "arm" and p.kind == "head") or (cross and p.kind in HELD and p.rig == "rider") or (p.get("mouth", false) and q.kind == "head"):
				child = p
			elif q.parent == p.name or (p.kind == "armour" and q.kind in WRAPPED) or (p.kind == "arm" and q.kind == "head") or (cross and q.kind in HELD and q.rig == "rider") or (q.get("mouth", false) and p.kind == "head"):
				child = q
			if p.kind == "armour" or q.kind == "armour":
				# Inside the body, armour and what it wraps are both hidden: only the rest counts.
				var bv := _vox(_by(a, p.rig + ":body"))
				common = common.filter(func(c): return not bv.has(c))
			var bad := common.size()
			var allowed := PEN_VOX + int(PEN_SHARE * mini(pv.size(), qv.size()))
			var rule := "A3 no cutting through"
			if not child.is_empty():
				var reach := 0.0
				for c in _vox(child):
					reach = maxf(reach, Geom.centre(c).distance_to(child.joint))
				var r := maxf(JOINT_R, 0.45 * reach)
				bad = 0
				for c in common:
					if Geom.centre(c).distance_to(child.joint) > r:
						bad += 1
				rule = "A3 jointed parts overlap only at the joint"
			var mid := Vector3.ZERO
			for c in common:
				mid += Geom.centre(c)
			mid /= maxf(common.size(), 1)
			note(rule, label, view, bad > allowed, "%s and %s share %d voxels, %d allowed, round %s" % [p.name, q.name, bad, allowed, _v(mid)])


static func _v(v: Vector3) -> String:
	return "(%.0f, %.0f, %.0f)" % [v.x, v.y, v.z]


## A siege engine's crew sockets: on the ground (or on the deck for those riding on top), and the
## crew member put there not cut through the engine.
func _check_engine(label: String, r: Dictionary) -> void:
	var colours := UnitView.colours_for(lib, r.skin, r.family, Color.MAGENTA)
	var es: Dictionary = rig.spec(r.body, colours)
	var ev := Geom.voxels(es.node, Transform3D.IDENTITY)
	var cr: Dictionary = r.crew.duplicate(true)
	cr.merge({"creature": r.creature, "family": r.family, "slot": "worker", "role": "worker", "tier": 1, "name": ""})
	var wide: bool = r.crew.has("mount")
	for name in es.get("sockets", {}):
		if not name.begins_with("crew") or name.ends_with("_wide" if not wide else "_in"):
			continue
		var at: Vector3 = es.sockets[name]
		if name.ends_with("_top"):
			# Something to stand on just under the feet (a deck, a saddle, a basket's floor); not
			# floating over it (how deep a crew member stands in a basket is the next check's business).
			var c := Geom.unkey(Geom.cell(at))
			var gap := INF
			for j in range(c.y, c.y - 16, -1):
				for i in [-1, 0, 1]:
					for k in [-1, 0, 1]:
						if gap == INF and ev.has(Geom.key(c.x + i, j, c.z + k)):
							gap = (c.y - j) * Geom.RES
			note("A2 crew on top stand on the deck", label, name, gap > ATTACH_GAP + 0.5, "%.1f over the deck" % gap)
		else:
			note("A2 crew stand on the ground", label, name, absf(at.y) > GROUND_TOL, "socket at height %.1f" % at.y)
		var turn := 0
		for t in name.split("_"):
			if t.begins_with("f") and t.length() == 2:
				turn = int(t.substr(1))
		var hold := "low"
		for t in name.split("_"):
			if t in UnitView.WORK_HOLDS:
				hold = t
		var s := float(cr.get("scale", 100)) / 100.0
		var a: Dictionary = rig.unit(cr, {"hold": hold})
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(-45.0 * turn)).scaled(Vector3.ONE * s), at)
		var crew_vox := {}
		for p in a.pieces:
			for q in Geom.voxels(p.node, xf * p.xf):
				crew_vox[q] = true
		var share := float(Geom.shared(crew_vox, ev)) / maxf(crew_vox.size(), 1)
		note("A3 crew not cut through their engine", label, name, share > 0.12, "%.2f of the crew member inside the engine" % share)
