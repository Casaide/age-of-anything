extends Node
## The 2D half of the placement check (needs a window: it reads the baked sprites). Every unit is
## composed by UnitView in all 8 facings, standing and at three walk phases, and each part's baked
## sprite laid onto a grid in the unit's own space, in draw order, so "A draws over B" is a count of
## pixels. The layering rules (docs/rendering.md) and these:
##   B5 ground: standing, every weight-bearing leg's lowest pixel is on its foot's ground point (the
##      3D sole projected by the bake camera) within FOOT_PX, and a near leg's foot is in sight in
##      the 3D truth; walking, the lowest foot stays on the standing ground line and none goes below it.
##   B6 visibility: legs and head show where the 3D truth shows them (each leg its own part, turned
##      as it's baked; the truth matches the composed parts one for one); a rider's leg hangs down
##      the flank that faces the camera, and reaches down it.
## The 3D truth: the body's model with its legs at their hips and its head on its socket, rendered
## from the bake camera of the facing in flat colours (body red, head blue, leg i green with i in
## blue), at one pixel per art pixel.

const DataLib := preload("res://src/data_lib.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const UnitModels := preload("res://scenes/art_pixel/unit_models.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const Rig3D := preload("res://tests/placement/rig3d.gd")
const Geom := preload("res://tests/placement/geom.gd")

## Poses: [name, walking, phase].
const POSES := [["stand", false, 0.0], ["walk0", true, 0.0], ["walk1", true, 2.1], ["walk2", true, 4.2]]

## Thresholds (art pixels). Tolerant of a pixel or two of outline, strict enough for a leg on a back.
const MODEL_SLACK := 6         # pixels a leg or head may differ from the 3D model by (the outline, rounding)...
const MODEL_SHARE := 0.08      # ...or this share of the part's pixels
const HIDDEN_MIN := 3          # a weapon or shield shows at least this many pixels in every facing
const ARMOUR_SHARE := 0.8      # worn armour covers at most this share of its body (a whole copy of the body is 1)
const FACE_TEAM_SHARE := 0.3   # team cloth over at most this share of a head facing the camera
const FOOT_PX := 2             # a standing foot's lowest pixel within this of its ground point; the walk's planted foot within this of the standing line
const RIDER_REACH := 0.8       # a person riding: its leg reaches at least this share of the way from the seat down to the girth...
const CLING_REACH := 0.1       # ...a clinging or folded-legged rider's (legs hugging the flank: creatures.json rider_legs) at least onto the flank

var lib
var metrics := false
var debug := false
var results := {}   # "rule|case" -> [fails...]
var order := []
var rig3d: Rig3D
var old_truth := false   # fixtures: the truth before 2026-10-13 (the first leg's part at every hip, unturned)
var _opaque := {}   # bake key -> [points, team flags]
var _gt_cache := {}
var _gt_baker = null
var _team := Color.RED


func setup(l) -> void:
	lib = l
	rig3d = Rig3D.new(l)
	_team = Color(lib.palettes.teams[0])


func note(rule: String, label: String, view: String, bad: bool, detail := "") -> void:
	var key := rule + "|" + label
	if not results.has(key):
		results[key] = []
		order.append(key)
	if bad:
		results[key].append(view + (" (" + detail + ")" if metrics and detail != "" else ""))


## Bakes every part these units are drawn with (skips what's baked; loads what's on disk).
func bake(kit, units: Array) -> void:
	await kit.prepare_units([{"units": units}], [_team])


func clear_caches() -> void:
	_opaque.clear()
	_gt_cache.clear()


## Composes one unit in every facing and pose and checks it. tweak (fixtures): called with each view
## after it's composed, to put an old configuration back.
func check_case(holder: Node2D, label: String, u: Dictionary, tweak := Callable()) -> void:
	# A body that rests in its own poses when idle (parts.json idle_poses: a cat sits) is drawn in each.
	var poses := POSES.duplicate()
	if not u.recipe.has("crew"):
		var walker: String = u.recipe.body
		if u.recipe.has("mount"):
			var mc: Dictionary = lib.creatures[u.recipe.mount.creature]
			walker = mc.get("fused_body", mc.body) if u.recipe.mount.fused else mc.get("mount_body", mc.body)
		for bp in lib.part(walker).get("idle_poses", []):
			poses.append([bp, false, 0.0, bp])
	for k in 8:
		var stand := {}
		for pose in poses:
			if pose[1] and u.recipe.has("crew"):
				continue   # an engine rolls; its crew's walk is a worker's, checked with the workers
			var v = UnitView.new()
			v.facing_k = k
			if pose.size() > 3:
				v.body_pose = pose[3]
			v.build(u.recipe, lib, _team, u.eval.speed)
			v.idle_wait = 1000.0
			holder.add_child(v)
			v.walking = pose[1]
			v.phase = pose[2]
			v._process(0.0)
			v.walking = false
			if pose.size() > 3:
				v.set_process(false)   # (held in its resting pose: left running, it gets up while the truth renders)
			if tweak.is_valid():
				tweak.call(v, pose[0])
				v._sort_layers(v)
			if u.recipe.has("crew"):
				_check_crew(v, label, "f%d" % k)
			else:
				await _check_view(v, label, "f%d %s" % [k, pose[0]], k, u, stand)
			holder.remove_child(v)
			v.free()
	rig3d.clear()


## Every PartShape the unit draws, in draw order, with its role and its pixels.
func _parts(v) -> Array:
	var out := []
	_collect(v, v, Transform2D.IDENTITY, out)
	return out


func _collect(v, n: Node, t: Transform2D, out: Array) -> void:
	for c in n.get_children():
		if not c is Node2D or not c.visible:
			continue
		var ct: Transform2D = t * (c as Node2D).transform
		if c is PartShape:
			out.append(_part(v, c, ct))
		_collect(v, c, ct, out)


func _part(v, ps: PartShape, t: Transform2D) -> Dictionary:
	var p := {"node": ps, "id": ps.part_id, "kind": "", "rig": "main", "near": true, "team": 0, "cells": {}}
	if ps == v._shadow:
		p.kind = "shadow"
	else:
		var base: String = ps.part_id.get_slice("~", 0).get_slice("@", 0)
		p.kind = "arm" if ps.front else lib.part(base).slot
		var a: Node = ps.get_parent()
		while a != null and a.get_parent() != v.bob and a.get_parent() != v.seat_node:
			a = a.get_parent()
		if a != null and a.get_parent() == v.seat_node:
			p.rig = "rider"
		elif v.recipe.has("mount"):
			p.rig = "mount"
	var key := _key(ps)
	if not PartShape.baked.has(key):
		p["unbaked"] = true
		return p
	var px: Array = _pixels(key)
	var s: float = PartShape.baked[key].scale
	for i in px[0].size():
		var q: Vector2 = t * px[0][i]
		var cell := Vector2i(floori(q.x * s), floori(q.y * s))
		p.cells[cell] = true
		if px[1][i]:
			p.team += 1
			p.cells[cell] = false   # false: a team-colour pixel
	return p


func _key(ps: PartShape) -> String:
	var key := PartShape.bake_key(ps.part_id, ps.shapes, PartShape.team_neutral(ps.colours))
	if ps.facing != 0 and PartShape.baked.has(key + PartShape.facing_suffix(ps.facing)):
		key += PartShape.facing_suffix(ps.facing)
	if ps.front:
		key = PartShape.front_key(key)
	return key


## A bake's opaque pixels as points in part units (pixel centres), and which are team colour.
func _pixels(key: String) -> Array:
	if not _opaque.has(key):
		var b: Dictionary = PartShape.baked[key]
		var img: Image = b.img
		var pts := PackedVector2Array()
		var team := []
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.1:
					pts.append((Vector2(x, y) + Vector2(0.5, 0.5) - b.origin) / b.scale)
					team.append(minf(c.r, c.b) - c.g > 0.22 and absf(c.r - c.b) < 0.3)
		_opaque[key] = [pts, team]
	return _opaque[key]


## Pixels of a drawn over pixels of b (0 when a draws first).
func _over(parts: Array, a: int, b: int) -> int:
	if a < b:
		return 0
	var n := 0
	for c in parts[a].cells:
		if parts[b].cells.has(c):
			n += 1
	return n


## Pixels of part i that no later part covers.
func _visible(parts: Array, i: int) -> int:
	var n := 0
	for c in parts[i].cells:
		var hidden := false
		for j in range(i + 1, parts.size()):
			if parts[j].kind != "shadow" and parts[j].node.modulate.a > 0.9 and parts[j].cells.has(c):
				hidden = true
				break
		if not hidden:
			n += 1
	return n


func _find(parts: Array, rig: String, kind: String) -> Array:
	var out := []
	for i in parts.size():
		if parts[i].rig == rig and parts[i].kind == kind:
			out.append(i)
	return out


func _check_view(v, label: String, view: String, k: int, u: Dictionary, stand: Dictionary) -> void:
	var parts := _parts(v)
	# Every part drawn has its bake (else the game draws a magenta marker).
	var missing := parts.filter(func(p): return p.get("unbaked", false) and p.kind != "shadow").map(func(p): return p.id)
	note("every part drawn is baked", label, view, not missing.is_empty(), ", ".join(missing))
	# Which legs are near (on the camera's side of the body), from the bake's anchors (3D truth).
	for leg in v.legs:
		for i in parts.size():
			if parts[i].node == leg.node:
				parts[i].near = _anchor_near(parts, i, leg.rest, k)
	# Shadows under everything.
	var shadow := _find(parts, "main", "shadow")
	note("shadow first", label, view, shadow.is_empty() or shadow[0] != 0)
	for rig in ["main", "mount", "rider"]:
		var bodies := _find(parts, rig, "body")
		if bodies.is_empty():
			continue
		var body: int = bodies[0]
		var body_rig: Dictionary = PartShape.rigs.get(parts[body].id + PartShape.facing_suffix(k), {})
		var depth: Dictionary = body_rig.get("depth", {})
		var under: bool = body_rig.get("legs_under", false)
		for i in _find(parts, rig, "leg"):
			if not parts[i].near and not "~" in parts[i].id:   # (a leg cut by its body may draw over it: it holds only what shows)
				note("far legs behind the body", label, view, _over(parts, i, body) > 0, "%d px" % _over(parts, i, body))
				continue
			if under:
				note("legs under a skirt", label, view, i > body)
		var heads := _find(parts, rig, "head")
		# Legs and head show where the 3D model shows them (the body's own bake of them together).
		if rig != "rider" and (view.ends_with("stand") or v.body_pose != ""):   # (a resting pose stands too)
			await _check_model(v, parts, rig, body, label, view, k, u, stand)
		elif rig != "rider" and not stand.is_empty() and stand.has(rig):
			_check_walk(v, parts, rig, label, view, stand[rig])
		# Back parts: behind the body when the back faces away from the camera, over it when it faces it.
		for i in _find(parts, rig, "back"):
			var d := float(depth.get("wings" if rig == "mount" and depth.has("wings") else "back", 0.0))
			if rig == "mount" and not lib.parts.get(parts[i].id.get_slice("~", 0).get_slice("@", 0), {}).has("blur"):
				# A mount's wings rise from its withers: over its back, unless the withers are turned
				# away (then the rump hides their roots); under the rider always. A wing blur (a
				# hummingbird's own, parts.json "blur") draws like any back part instead (Dominic: over it
				# in every facing it read as a flat grey plate from behind; unit_view.gd _attach).
				note("a mount's wings over its back, behind it turned away", label, view, (i > body) != (k == 0 or d >= -0.5))
				var rider := _find(parts, "rider", "body")
				note("a mount's wings under the rider", label, view, not rider.is_empty() and i > rider[0])
			elif k != 0 and d < -0.5:
				note("back parts behind the body facing the camera", label, view, _over(parts, i, body) > 0, "%d px" % _over(parts, i, body))
			elif k != 0 and d > 0.5:
				note("back parts over the body facing away", label, view, _over(parts, body, i) > 0, "%d px" % _over(parts, body, i))
		# What the near hand holds draws over the body; a weapon or shield never vanishes.
		for slot in ["hand_r", "hand_l"]:
			for i in _find(parts, rig, slot):
				if k != 0 and float(depth.get(slot, 0.0)) >= 0.5:
					note("near hand over the body", label, view, _over(parts, body, i) > 0, "%d px" % _over(parts, body, i))
				if k != 0 and float(depth.get(slot, 0.0)) < -0.5:
					continue   # in the far hand: the body may hide it
				var seen := _visible(parts, i)
				note("weapons and shields show", label, view, seen < mini(HIDDEN_MIN, parts[i].cells.size()), "%s %d px seen" % [parts[i].id, seen])
		# Worn armour is baked on its body with the body cut away: it never carries a copy of the body.
		for i in _find(parts, rig, "torso"):
			if "~" in parts[i].id:
				var share := float(_over(parts, i, body)) / maxf(1.0, parts[body].cells.size())
				note("worn armour holds no body", label, view, share > ARMOUR_SHARE, "%.2f of the body" % share)
		# Team cloth never covers a face turned to the camera.
		var dir: Vector2 = body_rig.get("dir", Vector2.RIGHT)
		if not heads.is_empty() and (k == 0 or dir.y > 0.2) and rig != "mount":
			var h: int = heads[0]
			var team := 0
			for j in range(h + 1, parts.size()):
				if parts[j].kind in ["head_gear", "shadow"] or parts[j].rig != rig:
					continue
				for c in parts[j].cells:
					if parts[j].cells[c] == false and parts[h].cells.has(c):
						team += 1
			var share := float(team) / maxf(1.0, parts[h].cells.size())
			note("team cloth never over the face", label, view, share > FACE_TEAM_SHARE, "%.2f of the head" % share)
	# A rider sits over its mount: no mount part over the rider, its near leg down the flank shows.
	var mb := _find(parts, "mount", "body")
	if not mb.is_empty() and not _find(parts, "rider", "body").is_empty():
		var bad := 0
		for i in parts.size():
			if parts[i].rig != "mount" or parts[i].kind == "shadow":
				continue
			for j in parts.size():
				if parts[j].rig == "rider":
					bad += _over(parts, i, j)
		note("rider over the mount", label, view, bad > 0, "%d px" % bad)
		for i in _find(parts, "rider", "leg"):
			note("rider's near leg over the mount's flank", label, view, i < mb[0])
		if view.ends_with("stand") or v.body_pose != "":
			_check_rider_leg(v, parts, mb[0], label, view, k, u)


## A leg's side from its body's anchors in this facing: the anchor at the leg's rest position.
func _anchor_near(parts: Array, leg: int, rest: Vector2, k: int) -> bool:
	var root: Node = parts[leg].node.get_parent()
	for c in root.get_children():
		if c is PartShape and not c.front and lib.part(c.part_id.get_slice("@", 0)).slot == "body":
			var rig: Dictionary = PartShape.rigs.get(c.part_id + PartShape.facing_suffix(k), PartShape.rigs.get(c.part_id, {}))
			var anchors: Array = rig.get("anchors", lib.part(c.part_id.get_slice("@", 0)).get("legs", {}).get("anchors", []))
			for a in anchors:
				if Vector2(float(a[0]), float(a[1])).distance_to(rest) < 0.01:
					return float(a[3]) > 0.0
	return parts[leg].node.get_meta("z", 0) > 0


## The bake camera of facing k: screen right and screen up in 3D, and the way towards the camera.
static func camera(k: int) -> Array:
	var az := deg_to_rad(PartBaker.AZIMUTH + PartBaker.FACING_STEP * k)
	var el := deg_to_rad(PartBaker.ELEVATION)
	var z := Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))
	var x := Vector3.UP.cross(z).normalized()
	var y := z.cross(x)
	return [x, y, z]


## A 3D point in a body's frame as the bake draws it: part units in the body sprite's 2D frame.
static func project(p: Vector3, cam: Array) -> Vector2:
	return Vector2(p.dot(cam[0]), -p.dot(cam[1]))


const ID_BODY := Color(1, 0, 0)
const ID_HEAD := Color(0, 0, 1)


static func id_leg(i: int) -> Color:
	return Color(0, 1, (i + 1) / 16.0)


## B6 and the layering rule 2: legs and head against the 3D truth. B5: feet on their ground points.
func _check_model(v, parts: Array, rig: String, body: int, label: String, view: String, k: int, u: Dictionary, stand: Dictionary) -> void:
	var legs := _find(parts, rig, "leg")
	var heads := _find(parts, rig, "head")
	var body_id: String = parts[body].id
	if legs.is_empty() or not UnitView.UnitModelsCheck.has(body_id):
		return
	var leg_nodes := legs.map(func(i): return parts[i].node)
	var gt: Dictionary = await _truth(parts[body].node, v, rig, heads.map(func(i): return parts[i].node), k)
	# The truth is built from the same parts as the unit: one leg per hip, each its own part and turn.
	var composed := []
	for leg in v.legs:
		if leg.node in leg_nodes and not leg.cling:
			composed.append([leg.base, leg.rest])
	var mismatch: bool = gt.legs.size() != composed.size()
	for i in mini(gt.legs.size(), composed.size()):
		var want: Array = gt.legs[i]
		mismatch = mismatch or want[0] != composed[i][0].get_slice("@", 0) or (want[2] as Vector2).distance_to(composed[i][1]) > 0.3 or want[1] != gt.want_basis[i]
	note("B6 the 3D truth has the unit's legs, one for one", label, view, mismatch, "truth %s, composed %s" % [str(gt.legs.map(func(l): return [l[0], l[2], l[1] == Basis.IDENTITY])), str(composed)])
	if gt.flipped:
		return
	# The composed unit in the rig's own space, at stand: each cell's topmost of body, legs, head.
	var top := {}   # cell -> [kind, part index]
	var order := [body] + legs + heads
	order.sort()
	for i in order:
		var n: PartShape = parts[i].node
		var kind := "body" if i == body else ("leg" if i in legs else "head")
		for c in _cells_in_rig(n):
			top[c] = [kind, i]
	if debug:
		_debug_image(gt.cells, top, "/tmp/placement_%s_%s_f%d.png" % [label.replace(" ", "_"), rig, k])
	var over := {}    # part index -> pixels drawn over the body where the model hides them
	var under := {}   # part index -> pixels of it the body covers where the model shows them
	for c in gt.cells:
		var want: String = gt.cells[c]
		if not _interior(gt.cells, c, want) or not top.has(c):
			continue
		var got: Array = top[c]
		if want == "body" and got[0] != "body":
			over[got[1]] = over.get(got[1], 0) + 1
		elif want != "body" and got[0] == "body":
			for i in (legs if want.begins_with("leg") else heads):
				if _cells_in_rig(parts[i].node).has(c):
					under[i] = under.get(i, 0) + 1
					break
	for i in legs + heads:
		var allowed := maxi(MODEL_SLACK, int(MODEL_SHARE * parts[i].cells.size()))
		var what := "%s %s%s" % [rig, parts[i].kind, "" if parts[i].kind == "head" else (" near" if parts[i].near else " far")]
		note("legs and head over the body only where the model shows them", label, view, over.get(i, 0) > allowed,
			"%s %d px over the body, %d allowed" % [what, over.get(i, 0), allowed])
		note("legs and head not hidden where the model shows them", label, view, under.get(i, 0) > allowed,
			"%s %d px hidden, %d allowed" % [what, under.get(i, 0), allowed])
	# B5: each weight-bearing leg's lowest pixel on its foot's ground point; a near foot in sight.
	var walker: String = "mount" if v.recipe.has("mount") else "main"
	if rig != walker or v.flying:
		return
	var cam := camera(k)
	var a3: Dictionary = rig3d.unit(u.recipe, {"body_pose": v.body_pose})
	var s: float = ArtKit.ART_SCALE * ArtKit.UNIT_SCALE
	var lows := {}
	var n := 0
	for leg in v.legs:
		if leg.cling or not leg.node in leg_nodes:
			continue
		var i: int = n
		n += 1
		var piece := {}
		for p in a3.pieces:
			if p.kind == "leg" and p.rig == a3.walker and p.anchor == i:
				piece = p
		if piece.is_empty():
			continue
		var vs := Geom.vertices(piece.node, piece.xf)
		var lo := INF
		for q in vs:
			lo = minf(lo, q.y)
		var want := -INF
		var sole := Vector2.ZERO   # the foot's ground point on screen
		for q in vs:
			if q.y <= lo + 0.3 and project(q, cam).y > want:
				want = project(q, cam).y
				sole = project(q, cam)
		var cells := _cells_in_rig(leg.node)
		var got := -INF
		for c in cells:
			got = maxf(got, c.y + 1)
		lows[i] = got
		var want_px := want * s
		# Near: on the flank that faces the camera and on the camera's side of the middle (a far leg a
		# step ahead isn't near).
		var flat := Vector3(cam[2].x, 0, cam[2].z)
		var near: bool = piece.hip.z * flat.z > 0.0 and float(piece.joint.dot(flat)) > 0.0
		# In sight: the 3D truth shows this leg's own pixels at its foot (not some other part of it).
		var seen := false
		var at := Vector2i(roundi(sole.x * s), roundi(sole.y * s))
		for dx in range(-FOOT_PX, FOOT_PX + 1):
			for dy in range(-FOOT_PX - 1, FOOT_PX + 1):
				seen = seen or gt.feet.get(i, {}).has(at + Vector2i(dx, dy))
		if near:
			note("B5 a near foot in sight", label, view, not seen, "%s %s foot hidden by its own body in 3D" % [rig, leg.node.part_id])
		if near or seen:
			note("B5 standing feet on the ground", label, view, absf(got - want_px) > FOOT_PX,
				"%s %s lowest pixel %d, its ground point %d" % [rig, leg.node.part_id, int(got), int(roundf(want_px))])
	stand[rig] = lows


## B5 walking: the lowest foot stays on the standing ground line, and no foot goes below it.
func _check_walk(v, parts: Array, rig: String, label: String, view: String, lows: Dictionary) -> void:
	if v.flying or v.gait.get("hop", false) or lows.is_empty():
		return
	var ref := -INF
	for i in lows:
		ref = maxf(ref, lows[i])
	var leg_nodes := _find(parts, rig, "leg").map(func(i): return parts[i].node)
	var low := -INF
	for leg in v.legs:
		if leg.cling or not leg.node in leg_nodes:
			continue
		var t: Transform2D = leg.node.get_parent().transform * leg.node.transform if false else leg.node.transform
		var got := -INF
		for c in _cells_now(leg.node, v):
			got = maxf(got, c.y + 1)
		low = maxf(low, got)
	note("B5 walking, the lowest foot on the ground line", label, view, absf(low - ref) > FOOT_PX, "lowest foot at %d, ground line %d" % [int(low), int(ref)])


## A part's opaque cells in its rig's space with the walk's bob: its own transform and the bob's.
func _cells_now(n: PartShape, v) -> Dictionary:
	var cells := {}
	var key := _key(n)
	if not PartShape.baked.has(key):
		return cells
	var px: Array = _pixels(key)
	var s: float = PartShape.baked[key].scale
	var t: Transform2D = Transform2D(0.0, Vector2.ONE, 0.0, v.bob.position) * n.get_parent().transform * n.transform
	for q in px[0]:
		var p: Vector2 = t * q
		cells[Vector2i(floori(p.x * s), floori(p.y * s))] = true
	return cells


## B6: a rider's leg hangs down the flank that faces the camera, and reaches down it.
func _check_rider_leg(v, parts: Array, mount_body: int, label: String, view: String, k: int, u: Dictionary) -> void:
	if u.recipe.mount.get("fused", false):
		return
	var cam := camera(k)
	var flat := Vector3(cam[2].x, 0, cam[2].z)
	var colours := UnitView.colours_for(lib, u.recipe.skin, u.recipe.family, _team)
	var hold := UnitView.hold_for(lib.part(u.recipe.parts.hand_r).tags) if u.recipe.parts.has("hand_r") else "low"
	var spec: Dictionary = rig3d.spec(u.recipe.body + ("" if hold == "low" else "@" + hold), colours)
	var mcells: Dictionary = parts[mount_body].cells
	var two_legged: bool = spec.get("anchors", []).size() == 2   # (many-legged riders grip with several short legs)
	for leg in v.legs:
		if not leg.cling:
			continue
		var hip := Vector3.INF
		for a in spec.get("anchors", []):
			if hip == Vector3.INF or project(a[0], cam).distance_to(leg.node.position) < project(hip, cam).distance_to(leg.node.position):
				hip = a[0]
		if hip == Vector3.INF:
			continue
		note("B6 a rider's leg on the flank facing the camera", label, view, hip.z * flat.z < 0.0,
			"the %s leg (hip z %.1f) shown with the camera on the %s side" % ["right" if hip.z > 0 else "left", hip.z, "right" if flat.z > 0 else "left"])
		# It reaches down the flank: its lowest pixel well below the mount's back in that column.
		var leg_cells: Dictionary = {}
		for i in parts.size():
			if parts[i].node == leg.node:
				leg_cells = parts[i].cells
		# It reaches down from the seat to the mount's girth (the bottom of the barrel under the seat).
		var foot := -(1 << 20)
		for c in leg_cells:
			foot = maxi(foot, c.y + 1)
		var mrig: Dictionary = PartShape.rigs.get(parts[mount_body].id + PartShape.facing_suffix(k), {})
		if not two_legged or not mrig.get("sockets", {}).has("girth"):
			continue
		var t := _to_unit(parts[mount_body].node, v)
		var s: float = ArtKit.ART_SCALE * ArtKit.UNIT_SCALE
		var seat_y: float = (t * mrig.sockets.seat).y * s
		var girth_y: float = (t * mrig.sockets.girth).y * s
		var reach := (foot - seat_y) / maxf(girth_y - seat_y, 1.0)
		var want: float = RIDER_REACH if leg.reach > 1.0 else CLING_REACH
		note("B6 a rider's leg reaches down the flank", label, view, reach < want, "%.2f of the way from the seat to the girth, %.2f wanted" % [reach, want])


## The transform from a part's parent's space to the unit's (as the part's pixels are laid out).
func _to_unit(n: Node, v) -> Transform2D:
	var t := Transform2D.IDENTITY
	var p: Node = n.get_parent()
	while p != v:
		t = (p as Node2D).transform * t
		p = p.get_parent()
	return t


## A part's opaque cells in its rig's space (its own transform only: legs, head, body are the rig root's children).
func _cells_in_rig(n: PartShape) -> Dictionary:
	if n.has_meta("rig_cells"):
		return n.get_meta("rig_cells")
	var cells := {}
	var key := _key(n)
	if PartShape.baked.has(key):
		var px: Array = _pixels(key)
		var s: float = PartShape.baked[key].scale
		for q in px[0]:
			var p: Vector2 = n.transform * q
			cells[Vector2i(floori(p.x * s), floori(p.y * s))] = true
	n.set_meta("rig_cells", cells)
	return cells


func _debug_image(gt: Dictionary, top: Dictionary, path: String) -> void:
	var img := Image.create(240, 120, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	var cols := {"body": Color.RED, "leg": Color.GREEN, "head": Color.BLUE}
	for c in gt:
		if c.x > -60 and c.x < 60 and c.y > -100 and c.y < 20:
			img.set_pixel(c.x + 60, c.y + 100, cols[gt[c].get_slice(":", 0)] if cols.has(gt[c].get_slice(":", 0)) else Color.GREEN)
	for c in top:
		if c.x > -60 and c.x < 60 and c.y > -100 and c.y < 20:
			img.set_pixel(c.x + 180, c.y + 100, cols[top[c][0]])
	img.resize(960, 480, Image.INTERPOLATE_NEAREST)
	img.save_png(path)


## A truth pixel two pixels inside its region (the bake's outline and rounding stay out of the count).
func _interior(cells: Dictionary, c: Vector2i, want: String) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
		if cells.get(c + d, "") != want:
			return false
	return true


## The 3D truth of a body in facing k: {cells: {cell: "body"|"head"|"leg:<i>"}, feet: {i: lowest leg-i
## cell y}, legs: [[leg part, basis, hip 2D]], want_basis: [the basis each hip's leg should have],
## flipped}. Each hip gets the leg part the body puts there (its hind part at a hind hip) turned by
## UnitModels.leg_basis, as the bake turns it (old_truth: the first leg's part, unturned).
func _truth(body: PartShape, v, rig: String, heads: Array, k: int) -> Dictionary:
	var pose: String = "@" + v.body_pose if v.body_pose != "" and body.part_id.get_slice("@", 0) == v._pose_body else ""
	var body_id: String = body.part_id.get_slice("@", 0)
	var bdata: Dictionary = lib.part(body_id)
	var cut: bool = "legs" in bdata.get("cut", [])
	var head: PartShape = heads[0] if not heads.is_empty() else null
	var key := "%s|%s|%d|%s" % [PartShape.bake_key(body.part_id, body.shapes, PartShape.team_neutral(body.colours)), head.part_id if head else "", k, str(old_truth)]
	if _gt_cache.has(key):
		return _gt_cache[key]
	if _gt_baker == null:
		_gt_baker = PartBaker.new()
		_gt_baker.msaa_3d = Viewport.MSAA_DISABLED
		add_child(_gt_baker)
	var pb = _gt_baker
	var colours := PartShape.team_neutral(body.colours)
	var spec: Dictionary = pb.models.build(body.part_id, colours)
	var model := Node3D.new()
	_paint(spec.node, ID_BODY)
	model.add_child(spec.node)
	if spec.get("front") != null:
		spec.front.free()   # the near arm is its own layer, left out on both sides (a raised arm before the face is a known limit)
	var flipped := false
	var legs := []
	var want_basis := []
	var anchors: Array = spec.get("anchors", [])
	var cam := camera(k)
	for i in anchors.size():
		var a: Array = anchors[i]
		var hind: bool = a.size() > 4 and bool(a[4])
		var leg_id: String = (bdata.legs.get("hind", bdata.legs.part) if hind else bdata.legs.part) + pose
		var basis := UnitModels.leg_basis(a, cut)
		want_basis.append(basis)
		if old_truth:
			leg_id = (bdata.legs.part + pose)
			basis = Basis.IDENTITY
		if not cut and basis.determinant() < 0.0:
			flipped = true   # an uncut leg mirrored in 2D: its truth isn't one render
		legs.append([leg_id.get_slice("@", 0), basis, project(a[0], cam)])
		var l: Node3D = pb.models.build(leg_id, colours).node
		_paint(l, id_leg(i))
		var wrap := Node3D.new()
		wrap.transform = Transform3D(basis, a[0])
		wrap.add_child(l)
		model.add_child(wrap)
	if head:
		var h: Node3D = pb.models.build(head.part_id.get_slice("~", 0), colours).node
		_paint(h, ID_HEAD)
		h.position = spec.sockets.head
		model.add_child(h)
	pb.holder.add_child(model)
	var box: AABB = pb._aabb(model)
	var r := box.size.length() * 0.5 + 2.0
	var s: float = ArtKit.ART_SCALE * ArtKit.UNIT_SCALE
	pb.size = Vector2i.ONE * ceili(2.0 * r * s)
	pb.cam.keep_aspect = Camera3D.KEEP_HEIGHT
	pb.cam.size = 2.0 * r
	pb.cam.basis = Basis.looking_at(-cam[2], Vector3.UP)
	pb.cam.position = box.get_center() + cam[2] * 150.0
	await pb._render()
	var img: Image = pb.get_texture().get_image()
	var origin: Vector2 = pb.cam.unproject_position(Vector3.ZERO)
	pb.holder.remove_child(model)
	model.queue_free()
	var cells := {}
	var feet := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var cell := Vector2i(floori(x + 0.5 - origin.x), floori(y + 0.5 - origin.y))
			var id := "body"
			if c.g > 0.5:
				var i := roundi(c.b * 16.0) - 1
				id = "leg"
				if not feet.has(i):
					feet[i] = {}
				feet[i][cell] = true
			elif c.b > c.r:
				id = "head"
			cells[cell] = id
	_gt_cache[key] = {"cells": cells, "feet": feet, "legs": legs, "want_basis": want_basis, "flipped": flipped}
	return _gt_cache[key]


func _paint(n: Node, colour: Color) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour
	var meshes := n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		meshes.append(n)
	for mi in meshes:
		if (mi as MeshInstance3D).material_override != null:
			(mi as MeshInstance3D).material_override = m
		else:   # (a modelled .glb: per surface, as the bake does it; an override there logs errors)
			for surface in (mi as MeshInstance3D).mesh.get_surface_count():
				(mi as MeshInstance3D).set_surface_override_material(surface, m)
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Siege crews by socket: "_in" behind the engine, "_top" over it, the rest by the socket's depth.
func _check_crew(v, label: String, view: String) -> void:
	var engine: Node = null
	for c in v.bob.get_children():
		if c is PartShape:
			engine = c
	var rig: Dictionary = PartShape.rigs.get(v.recipe.body + PartShape.facing_suffix(v.facing_k), {})
	for c in v.crew:
		var name := ""
		for s in rig.get("sockets", {}):
			if s.begins_with("crew") and rig.sockets[s].distance_to(c.view.position) < 0.01:
				name = s
		var over: bool = c.view.get_index() > engine.get_index()
		var want: bool = float(rig.depth[name]) > 0.0
		if name.ends_with("_in"):
			want = false
		elif name.ends_with("_top"):
			want = true
		note("siege crew by socket", label, view, over != want, name)
