extends RefCounted
## A unit put together in 3D, the way UnitView composes it in 2D: the body's model, its legs at
## their hips (posed for a walk phase), its head on its socket, its gear on its sockets (worn armour
## fitted as the bake fits it), a rider on its mount's seat. Every piece keeps its model, its world
## transform, the joint it hangs from and its parent piece, for tests/placement/geometry_check.gd.
## 2D-only touches (a rider's near leg stretched down the flank, a pegasus's wings at the withers,
## a harness's couched weapon) are left to the projection checks.

const UnitModels := preload("res://scenes/art_pixel/unit_models.gd")
const UnitView := preload("res://src/unit_view.gd")
const Geom := preload("res://tests/placement/geom.gd")

const SCREEN_Y := 0.8660254   # one 3D unit straight up is this many screen units (elevation 30)

var lib
var models = UnitModels.new()
var _spec_cache := {}
var overrides := {}   # fixtures: part id -> Callable(colours) building an old model in its place
var old_seat := false  # fixtures: riders dropped a fixed amount below the seat (before the hips went on it)
var old_bob := false   # fixtures: the walk's bob before the planted foot (the body rose as the legs spread)


func _init(l) -> void:
	lib = l


func spec(id: String, colours: Dictionary) -> Dictionary:
	var k := id + "|" + str(colours.get("skin", "")) + str(colours.get("skin5", ""))
	if not _spec_cache.has(k):
		_spec_cache[k] = overrides[id].call(colours) if overrides.has(id) else models.build(id, colours)
		_spec_cache[k]["_key"] = k + ("|old" if overrides.has(id) else "")
	return _spec_cache[k]


## Frees every model built (call when done with a case).
func clear() -> void:
	for k in _spec_cache:
		var s: Dictionary = _spec_cache[k]
		for n in ["node", "front"]:
			if s.get(n) != null and is_instance_valid(s[n]):
				s[n].free()
	_spec_cache.clear()


## pose: {"hold": "" (the unit's own) or a hold, "walk": phase or -1.0 standing, "body_pose": "" or
## one of the walking body's idle_poses (a cat sitting: "body.cat@sit" with its legs "@sit")}
## Returns {"pieces": [...], "walker": rig name of what stands on the ground, "gait": {...}}.
## A piece: {name, kind, rig, node, xf, joint (world), parent (piece name or ""), side (+1 near, -1 far), anchor}
func unit(r: Dictionary, pose: Dictionary) -> Dictionary:
	var out := {"pieces": [], "flying": false, "body_pose": pose.get("body_pose", "")}
	var colours := UnitView.colours_for(lib, r.skin, r.family, Color.MAGENTA)
	var walk: float = pose.get("walk", -1.0)
	if r.has("mount"):
		var m: Dictionary = r.mount
		var mc: Dictionary = lib.creatures[m.creature]
		var mcol := UnitView.colours_for(lib, m.skin, r.family, Color.MAGENTA)
		var mbody: String = mc.get("fused_body", mc.body) if m.fused else mc.get("mount_body", mc.body)
		var g := _gait(mbody, false)
		out.gait = g
		var lift := _bob(g, walk)
		var mrig := _rig(out, "mount", mbody, "" if m.fused else mc.get("mount_head", mc.head), "", mcol, Transform3D(Basis.IDENTITY, Vector3(0, lift, 0)), true, walk, g, out.body_pose)
		for slot in m.parts:
			if slot == "back" and "flying" in lib.part(m.parts.back).tags:
				out.flying = true   # (a pegasus's wings sit at the withers in 2D only)
				continue
			_gear(out, mrig, slot, m.parts[slot], mcol)
		var seat: Vector3 = mrig.sockets.get("seat", Vector3(0, 20, 0))
		var clinging: bool = not m.fused and spec(r.body, colours).get("carry", "") == "harness"
		var s := 1.0 if m.fused else (0.6 if clinging else 0.8)
		s *= float(mc.get("rider_scale", {}).get(r.creature, 100)) / 100.0
		# UnitView.seat_offset: the rider's hips on the seat (a fused rider grows out of its mount).
		var at := seat if m.fused else seat - UnitModels.hips(spec(r.body, colours)) * s
		if old_seat and not m.fused:
			var drop := Vector2(-1, 9) if clinging else Vector2(0, 6)
			at = seat + Vector3(drop.x, -drop.y / SCREEN_Y, 0)
		var hold := _hold(r, pose)
		var rrig := _rig(out, "rider", r.body, r.head, hold, colours, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), at), false, -1.0, {})
		out["seat"] = seat
		for slot in r.parts:
			_gear(out, rrig, slot, r.parts[slot], colours, pose)
		out.walker = "mount"
		out["fused"] = m.fused
	else:
		var g := _gait(r.body, false)
		var flies: bool = r.parts.has("back") and "flying" in lib.part(r.parts.back).tags
		out.flying = flies
		g = _gait(r.body, flies)
		if lib.creatures.get(r.get("creature", ""), {}).get("gait", "") == "hop" and not flies:
			g = {"hop": true, "swing": 0.0, "bob": 0.0}
		out.gait = g
		var lift := _bob(g, walk)
		var rig := _rig(out, "main", r.body, r.head, _hold(r, pose), colours, Transform3D(Basis.IDENTITY, Vector3(0, lift, 0)), true, walk, g, out.body_pose)
		for slot in r.parts:
			_gear(out, rig, slot, r.parts[slot], colours, pose)
		out.walker = "main"
	if walk >= 0.0 and not old_bob and not out.gait.get("hop", false) and not out.flying:
		# UnitView keeps the lowest foot where it stands (the body rides on its planted foot).
		var stand: Dictionary = unit(r, {"hold": pose.get("hold", "")})
		var d := _lowest_foot(stand) - _lowest_foot(out)
		for p in out.pieces:
			p.xf.origin.y += d
			p.joint.y += d
		if out.has("seat"):
			out.seat.y += d
	return out


func _lowest_foot(a: Dictionary) -> float:
	var lo := INF
	for p in a.pieces:
		if p.kind == "leg" and p.rig == a.walker:
			for v in Geom.vertices(p.node, p.xf):
				lo = minf(lo, v.y)
	return lo if lo < INF else 0.0


func _hold(r: Dictionary, pose: Dictionary) -> String:
	if pose.get("hold", "") != "":
		return pose.hold
	var hand: String = r.parts.get("hand_r", "")
	return UnitView.hold_for(lib.part(hand).tags) if hand != "" else "low"


## The walk cycle UnitView gives this body (swing, bob), from its leg count.
func _gait(body_id: String, flies: bool) -> Dictionary:
	var body: Dictionary = lib.part(body_id)
	var n: int = body.get("legs", {}).get("anchors", []).size()
	var g: Dictionary = UnitView._gait(n, flies)
	if body.get("legs", {}).has("gait"):
		g = g.duplicate()
		g.merge(body.legs.gait, true)
	return g


## How high the body rides at this walk phase (UnitView's bob, screen units up, in 3D units).
func _bob(g: Dictionary, walk: float) -> float:
	if walk < 0.0 or g.get("hop", false) or not old_bob:
		return 0.0
	return absf(sin(walk)) * float(g.bob) / SCREEN_Y


## A leg's rotation at a walk phase (UnitView: sin(phase + leg phase) * swing, screen clockwise),
## as a turn about the body's lateral axis (+z), the walk's swing in 3D.
static func swing(g: Dictionary, walk: float, leg_phase: float) -> float:
	if walk < 0.0 or g.get("hop", false):
		return 0.0
	return -sin(walk + leg_phase) * float(g.swing)


func _rig(out: Dictionary, rig: String, body_id: String, head_id: String, hold: String, colours: Dictionary, xf: Transform3D, with_legs: bool, walk: float, g: Dictionary, body_pose := "") -> Dictionary:
	var model_id := body_id + ("" if hold == "low" or hold == "" else "@" + hold)
	if body_pose != "":
		model_id = body_id + "@" + body_pose   # a resting pose is the whole body baked in it
	if not models.has(body_id):
		return {"sockets": {}, "xf": xf, "body": body_id, "modelled": false}
	var bs := spec(model_id, colours)
	var body: Dictionary = lib.part(body_id)
	var bname := rig + ":body"
	out.pieces.append({"name": bname, "kind": "body", "rig": rig, "id": model_id, "node": bs.node, "geo": bs._key, "xf": xf, "joint": xf.origin, "parent": "", "side": 0,
		"legs_under": bs.get("legs_under", false), "cut": body.get("cut", [])})
	if bs.get("front") != null:
		out.pieces.append({"name": rig + ":arm", "kind": "arm", "rig": rig, "id": model_id, "node": bs.front, "geo": bs._key + ":front", "xf": xf, "joint": xf * bs.sockets.get("hand_r", Vector3.ZERO), "parent": bname, "side": 1})
	var sockets := {}
	for s in bs.get("sockets", {}):
		sockets[s] = xf * bs.sockets[s]
	if with_legs and body.has("legs"):
		var cut: bool = "legs" in body.get("cut", [])
		var anchors: Array = bs.get("anchors", [])
		for i in anchors.size():
			var a: Array = anchors[i]
			var hind: bool = a.size() > 4 and bool(a[4])
			var leg_id: String = body.legs.get("hind", body.legs.part) if hind else body.legs.part
			if not models.has(leg_id):
				continue
			# Posed legs (parts.json legs.poses: a cat's walk baked in steps; its legs in a resting pose)
			# are the step UnitView picks for this phase (UnitView._walk).
			var n_steps := int(body.legs.get("poses", 0))
			var leg_model := leg_id
			if body_pose != "":
				leg_model = leg_id + "@" + body_pose
			elif n_steps > 0 and walk >= 0.0:
				leg_model = "%s@w%d_%d" % [leg_id, int(fposmod((walk + float(a[1])) / TAU, 1.0) * n_steps) % n_steps, n_steps]
			var ls := spec(leg_model, colours)
			var basis: Basis = UnitModels.leg_basis(a, cut)
			var turn := Basis(Vector3(0, 0, 1), swing(g, walk, float(a[1])))
			var lxf := xf * Transform3D(turn * basis, a[0])
			out.pieces.append({"name": "%s:leg%d" % [rig, i], "kind": "leg", "rig": rig, "id": leg_model, "node": ls.node, "geo": ls._key, "xf": lxf,
				"joint": xf * a[0], "parent": bname, "side": 1 if float(a[0].z) > 0.0 else -1, "anchor": i, "hip": a[0], "flip": a.size() > 3 and int(a[3]) == 1})
	var gear_scale := 1.0
	if head_id != "" and models.has(head_id) and sockets.has("head"):
		var hs := spec(head_id, colours)
		var hxf := xf * Transform3D(Basis.IDENTITY, bs.sockets.head)
		out.pieces.append({"name": rig + ":head", "kind": "head", "rig": rig, "id": head_id, "node": hs.node, "geo": hs._key, "xf": hxf, "joint": sockets.head, "parent": bname, "side": 0})
		gear_scale = float(hs.get("gear_scale", 1.0))
		sockets["top"] = hxf * hs.get("sockets", {}).get("top", Vector3(0, 8, 0))
		sockets["top_local"] = hs.get("sockets", {}).get("top", Vector3(0, 8, 0))
	bs["hold"] = hold
	return {"sockets": sockets, "xf": xf, "body": body_id, "spec": bs, "gear_scale": gear_scale, "rig": rig, "carry": bs.get("carry", ""), "modelled": true}


## The turn about z that points a held item's tip (its farthest point from the grip) along dir.
static func _level(n: Node3D, dir: Vector2) -> float:
	var tip := Vector2.ZERO
	for v in Geom.vertices(n):
		if Vector2(v.x, v.y).length() > tip.length():
			tip = Vector2(v.x, v.y)
	return 0.0 if tip == Vector2.ZERO else dir.angle() - tip.angle()


func _gear(out: Dictionary, rig: Dictionary, slot: String, part_id: String, colours: Dictionary, pose := {}) -> void:
	if not rig.modelled:
		return
	var sock: String = UnitView.SOCKET_FOR_SLOT[slot]
	var r: String = rig.rig
	var xf: Transform3D = rig.xf
	if slot == "torso":
		if not models.has(part_id):
			return
		var bs: Dictionary = rig.spec
		var fitted: Dictionary = models.fitted(part_id, rig.body, colours)
		var node: Node3D
		var axf := xf
		if not fitted.is_empty():
			node = fitted.node
			_spec_cache[part_id + "~" + rig.body + "|fitted%d" % _spec_cache.size()] = fitted
		else:
			var gs := spec(part_id, colours)
			node = gs.node
			var ts: Vector2 = bs.get("torso_scale", Vector2.ONE)
			var fit: Vector3 = bs.get("torso_fit", Vector3(ts.x, ts.y, ts.x))
			var b := Basis.from_euler(Vector3(0, 0, deg_to_rad(float(bs.get("torso_tilt", 0.0))))) * Basis.from_scale(fit)
			axf = xf * Transform3D(b, bs.sockets.torso)
		out.pieces.append({"name": r + ":armour", "kind": "armour", "rig": r, "id": part_id, "node": node, "geo": part_id + "~" + rig.body + ("|fitted" if not fitted.is_empty() else ""), "xf": axf,
			"joint": xf * rig.spec.sockets.torso, "parent": r + ":body", "side": 0})
		return
	if not rig.sockets.has(sock) or not models.has(part_id):
		return
	var gs := spec(part_id, colours)
	var gxf := Transform3D(Basis.IDENTITY, rig.sockets[sock])
	var parent := r + ":body"
	if slot == "head_gear":
		gxf = Transform3D(xf.basis * Basis.from_scale(Vector3.ONE * rig.gear_scale), rig.sockets[sock])
		parent = r + ":head"
	else:
		gxf = Transform3D(xf.basis, rig.sockets[sock])
	if slot == "hand_r":
		# What the near hand holds turns with the swing (UnitView._attack, _work), or lies levelled
		# forward (a spear's thrust; couched on a harness: UnitView.COUCH, a tool leant at 0.25).
		var turn: float = pose.get("turn", 0.0)
		if pose.get("level", false):
			turn = _level(gs.node, Vector2(1, 0.05))
			gxf.origin += xf.basis * Vector3(9.0, 0, 0)
		elif rig.carry == "harness":
			turn = -0.25 if part_id.begins_with("tool.") else _level(gs.node, Vector2(1.0, 0.3))
		gxf.basis = gxf.basis * Basis(Vector3(0, 0, 1), turn)
	if slot == "hand_r" and rig.spec.get("front") != null:
		parent = r + ":arm"
	var harness: bool = rig.carry == "harness" and slot in ["hand_r", "hand_l"]
	out.pieces.append({"name": r + ":" + slot, "kind": slot, "rig": r, "id": part_id, "node": gs.node, "geo": gs._key, "xf": gxf,
		"joint": rig.sockets[sock], "parent": parent, "side": 0, "harness": harness,
		"mouth": slot == "hand_r" and rig.spec.get("hold", "") == "mouth"})
