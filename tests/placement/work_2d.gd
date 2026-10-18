extends RefCounted
## The 2D placement check at work (2026-10-17): a worker is drawn foraging in every facing, and a fused
## mount's kneel (UnitView._kneel: the front legs fold at the knee, the chest dips, the human half leans
## back) is measured. Until then the 2D check drew units standing and walking only, so the kneel, a 2D
## pose put on the baked sprites, was never checked outside the side-on view it was designed in: picked
## by screen x and bent as if seen from the side, it folded a flank's legs sideways and sank the hind end
## in the other seven facings, and Dominic saw a centaur from behind in a match ("i thought our tooling
## and tests protected against this"). The rules, from the 3D model and the bake camera, not from UnitView:
##   K1 the legs that fold are the body's fore legs (its model's hips ahead of the middle), the hind
##      legs keep their length;
##   K2 a folded shin lies back along the ground: from its knee towards where the model's tail is on screen;
##   K3 a shin hangs from its knee (its pixels touch the shortened leg's);
##   K4 the hind hooves stay planted: each hind leg's lowest pixel where it is standing;
##   K5 nothing goes below the standing ground line.

const PartShape := preload("res://src/part_shape.gd")
const UnitView := preload("res://src/unit_view.gd")

const WORK_POSES := [["forage", false, 0.0]]   # [job, walking, phase], drawn for every worker
const KNEEL_LEGS := 4   # a body kneels on four or more legs


static func is_work(pose: Array) -> bool:
	return WORK_POSES.any(func(w): return w[0] == pose[0])


## Called by projection_check with a view composed at work.
static func check(pc, v, label: String, view: String, k: int) -> void:
	if not (v.recipe.has("mount") and v.recipe.mount.get("fused", false) and v.legs.size() >= KNEEL_LEGS and v.kneel > 0.0):
		return
	var cam: Array = pc.camera(k)
	var back: Vector2 = -pc.project(Vector3(20, 0, 0), cam)   # the model's tail end, from its middle, on screen
	var mc: Dictionary = pc.lib.creatures[v.recipe.mount.creature]
	var body_id: String = mc.get("fused_body", mc.body)
	var colours := UnitView.colours_for(pc.lib, v.recipe.mount.skin, v.recipe.family, pc._team)
	var hips: Array = pc.rig3d.spec(body_id, colours).get("anchors", []).map(func(a): return a[0])
	var mid := 0.0
	for h in hips:
		mid += h.x / hips.size()
	var ground := -INF   # the standing ground line: the lowest leg's lowest pixel, standing
	var stand_low := {}
	for leg in v.legs:
		stand_low[leg] = _lowest(pc, _cells(pc, leg.node, _standing(v, leg)))
		ground = maxf(ground, stand_low[leg].y)
	for leg in v.legs:
		var hip: Vector3 = _hip_of(pc, v, leg, k, hips)
		var fore: bool = hip.x > mid
		var shin: Node2D = leg.get("shin")
		var folded: bool = shin != null and shin.visible
		pc.note("K1 a kneel folds the fore legs", label, view, folded != fore,
			"%s leg (hip x %.1f) %s" % ["fore" if fore else "hind", hip.x, "folded" if folded else "straight"])
		var cells := _cells(pc, leg.node, pc._to_unit(leg.node, v) * leg.node.transform)
		if folded:
			var st := _cells(pc, shin, pc._to_unit(shin, v) * shin.transform)
			var t: Transform2D = pc._to_unit(shin, v) * shin.transform
			var along: Vector2 = t.basis_xform(Vector2.DOWN)   # the shin's own length, knee to hoof
			pc.note("K2 a folded shin lies back along the ground", label, view, along.normalized().dot(back.normalized()) < 0.3,
				"shin %s, back %s" % [str(along.normalized()), str(back.normalized())])
			pc.note("K3 a shin hangs from its knee", label, view, _gap(cells, st) > 1.5, "%.1f px from its leg" % _gap(cells, st))
			cells.merge(st)
		else:
			var low := _lowest(pc, cells)
			pc.note("K4 kneeling, the hind hooves stay planted", label, view, low.distance_to(stand_low[leg]) > pc.FOOT_PX,
				"%s lowest pixel %s, standing %s" % [leg.node.part_id, str(low), str(stand_low[leg])])
		pc.note("K5 kneeling, nothing below the ground", label, view, _lowest(pc, cells).y > ground + pc.FOOT_PX,
			"%s down to %d, the ground line %d" % [leg.node.part_id, int(_lowest(pc, cells).y), int(ground)])


## Where a leg stands: the unit's own transform with the bob at rest and the leg straight, at its reach.
static func _standing(v, leg: Dictionary) -> Transform2D:
	var root: Node2D = leg.node.get_parent()
	var t := Transform2D(0.0, Vector2(leg.node.scale.x, leg.reach), 0.0, leg.rest)
	return v.visual.transform * root.transform * t


## The 3D hip a leg is drawn at: the facing's projected anchor at its rest position (the bake's own order).
static func _hip_of(pc, v, leg: Dictionary, k: int, hips: Array) -> Vector3:
	var body: PartShape = null
	for c in leg.node.get_parent().get_children():
		if c is PartShape and not c.front and pc.lib.part(c.part_id.get_slice("~", 0).get_slice("@", 0)).slot == "body":
			body = c
	var rig: Dictionary = PartShape.rigs.get(body.part_id + PartShape.facing_suffix(k), {})
	var anchors: Array = rig.get("anchors", [])
	for i in anchors.size():
		if Vector2(float(anchors[i][0]), float(anchors[i][1])).distance_to(leg.rest) < 0.01:
			return hips[i]
	assert(false, "work_2d: no anchor at %s" % str(leg.rest))
	return Vector3.ZERO


static func _cells(pc, n: PartShape, t: Transform2D) -> Dictionary:
	var cells := {}
	var key: String = pc._key(n)
	if not PartShape.baked.has(key):
		return cells
	var px: Array = pc._pixels(key)
	var s: float = PartShape.baked[key].scale
	for q in px[0]:
		var p: Vector2 = t * q
		cells[Vector2i(floori(p.x * s), floori(p.y * s))] = true
	return cells


## The lowest cell (the middle of the lowest row).
static func _lowest(_pc, cells: Dictionary) -> Vector2:
	var y := -(1 << 20)
	for c in cells:
		y = maxi(y, c.y)
	var xs := 0.0
	var n := 0
	for c in cells:
		if c.y == y:
			xs += c.x
			n += 1
	return Vector2(xs / maxf(n, 1.0), y)


static func _gap(a: Dictionary, b: Dictionary) -> float:
	var best := INF
	for p in b:
		for q in a:
			best = minf(best, Vector2(p).distance_to(Vector2(q)))
			if best <= 1.0:
				return best
	return best
