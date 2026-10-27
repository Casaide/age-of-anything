extends RefCounted
## The 2D placement rules for composites (2026-10-13, after Dominic's TC1 A for rats: "this is
## bugged, did the tests not catch it?"). Before this the 2D check composed an engine only standing
## and asked one thing of it, "siege crew by socket" (each member over or under the engine by its
## socket's depth): its members' own parts were never checked (a hauling cat's legs, feet, head
## against its 3D truth), nor which member draws over which (the cat drew over the rat beside it in
## every facing, so the rat stood inside the cat), nor anything walking. Now, for every engine view
## (all 8 facings, standing and walking):
##   C4 depth order: the whole composite (engine, crew, haulers in their harness) rendered in 3D from
##      the bake camera, one flat colour per member, is the truth of who is in front: where the
##      truth shows a member, no other member's sprite is drawn over it (6 px or 8% of it, slack).
##   members as units: every member's view goes through the unit checks (layering, B5 feet, B6 legs
##      and head against its 3D truth), standing and walking, under the composite's label.
## For every unit (composite or not):
##   B6 walk steps: walking, each hip's leg is drawn, in the walk step the 3D rig has for that phase
##      (one for one: a missing or wrong-step leg in the walk fails, not just standing).
##   every drawn part is checked: each sprite in the view belongs to the unit itself, a member the
##      checks composed, or the engine; anything else fails (no silent passes).

const ArtKit := preload("res://src/view/art/art_kit.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const Composite3D := preload("res://tests/placement/composite_3d.gd")

const SLACK := 6          # pixels a member may be overdrawn by (outline, rounding)...
const SHARE := 0.08       # ...or this share of its pixels in the truth
const IDS := [Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1), Color(1, 1, 0), Color(0, 1, 1), Color(1, 0, 1), Color(1, 1, 1), Color(0.5, 0.5, 0)]


## A composite (engine) view: its members posed like the engine (walking with it, but those riding on
## top), checked as units, then the depth order. pose: [name, walking, phase].
static func check_engine_view(pc, v, label: String, k: int, u: Dictionary, stand: Dictionary, pose: Array) -> void:
	var view := "f%d %s" % [k, pose[0]]
	for c in v.crew:
		var m = c.view
		m.walking = pose[1] and not c.top
		m.phase = float(pose[2])
		m._process(0.0)
		m.walking = false
		m.set_process(false)   # (held as posed while the truths render)
	for c in v.crew:
		var m = c.view
		var key: String = "member " + c.socket
		if not stand.has(key):
			stand[key] = {}
		var mu := {"recipe": m.recipe, "eval": {"speed": 10}}
		await pc._check_view(m, label, "f%d %s %s" % [k, c.socket, pose[0]], m.facing_k, mu, stand[key])
		if pose[1] and not c.top:
			walk_legs(pc, m, label, "f%d %s %s" % [k, c.socket, pose[0]], mu, float(pose[2]))
	if not pose[1]:
		await depth_order(pc, v, label, view, k, u)
	coverage(pc, v, label, view)


## B6 walk steps: each hip's leg drawn, in the 3D rig's walk step for this phase.
static func walk_legs(pc, v, label: String, view: String, u: Dictionary, phase: float) -> void:
	if v.flying or v.gait.get("hop", false):
		return
	var a: Dictionary = pc.rig3d.unit(u.recipe, {"walk": phase})
	var want: Array = a.pieces.filter(func(p): return p.kind == "leg" and p.rig == a.walker)
	want.sort_custom(func(x, y): return x.anchor < y.anchor)
	var got: Array = v.legs.filter(func(l): return not l.cling and not (v.seat_node != null and v.seat_node.is_ancestor_of(l.node)))
	var bad := []
	if want.size() != got.size():
		bad.append("%d legs drawn, %d hips" % [got.size(), want.size()])
	for i in mini(want.size(), got.size()):
		var n: PartShape = got[i].node
		var id: String = n.part_id.get_slice("~", 0)
		if id != want[i].id:
			bad.append("hip %d: %s drawn, %s in 3D" % [i, id, want[i].id])
		if not n.visible or n.modulate.a < 0.5 or not PartShape.baked.has(pc._key(n)):
			bad.append("hip %d: %s not drawn" % [i, id])
	pc.rig3d.clear()
	pc.note("B6 every hip's leg in every walk step", label, view, not bad.is_empty(), "; ".join(bad.slice(0, 3)))


## Every sprite in the view is the unit's own, a composed member's, or the engine's.
static func coverage(pc, v, label: String, view: String) -> void:
	var members := {}
	if v.recipe.has("crew"):
		for c in v.crew:
			members[c.view] = true
	var stray := []
	for ps in v.find_children("*", "PartShape", true, false):
		if not ps.visible:
			continue
		var owner: Node = ps.get_parent()
		while owner != null and not owner.has_method("build"):
			owner = owner.get_parent()
		if owner != v and not members.has(owner):
			stray.append(ps.part_id)
	pc.note("every drawn part is checked", label, view, not stray.is_empty(), "unchecked: " + ", ".join(stray.slice(0, 3)))


## C4: who is in front, against the composite's 3D truth (one flat colour per member).
static func depth_order(pc, v, label: String, view: String, k: int, u: Dictionary) -> void:
	var r: Dictionary = u.recipe
	var lib = pc.lib
	var colours := PartShape.team_neutral(UnitView.colours_for(lib, r.skin, r.family, pc._team))
	var es: Dictionary = pc.rig3d.spec(r.body, colours)
	var ms := Composite3D.members(lib, r, es.get("sockets", {}))
	var index := {}   # socket -> member id (1..); the engine is 0
	for i in ms.size():
		index[ms[i].name] = i + 1
	var model := Node3D.new()
	var e: Node3D = es.node.duplicate()
	pc._paint(e, IDS[0])
	model.add_child(e)
	if lib.part(r.body).has("legs"):   # a war beast's legs and head, baked apart: the beast's too
		for p in pc.rig3d.unit(UnitView.beast_recipe(lib, r), {}).pieces:
			if p.kind == "body":
				continue
			var wrap := Node3D.new()
			wrap.transform = p.xf
			var d: Node3D = p.node.duplicate()
			pc._paint(d, IDS[0])
			wrap.add_child(d)
			model.add_child(wrap)
	for i in ms.size():
		var m: Dictionary = ms[i]
		var a: Dictionary = pc.rig3d.unit(m.recipe, {"hold": m.hold})
		for p in a.pieces:
			var wrap := Node3D.new()
			wrap.transform = m.xf * p.xf
			var d: Node3D = p.node.duplicate()
			pc._paint(d, IDS[i + 1])
			wrap.add_child(d)
			model.add_child(wrap)
	pc.rig3d.clear()
	if pc._gt_baker == null:
		pc._gt_baker = PartBaker.new()
		pc._gt_baker.msaa_3d = Viewport.MSAA_DISABLED
		pc.add_child(pc._gt_baker)
	var pb = pc._gt_baker
	var cam: Array = pc.camera(k)
	pb.holder.add_child(model)
	var box: AABB = pb._aabb(model)
	var rad := box.size.length() * 0.5 + 2.0
	var s: float = ArtKit.ART_SCALE * ArtKit.UNIT_SCALE
	pb.size = Vector2i.ONE * ceili(2.0 * rad * s)
	pb.cam.keep_aspect = Camera3D.KEEP_HEIGHT
	pb.cam.size = 2.0 * rad
	pb.cam.basis = Basis.looking_at(-cam[2], Vector3.UP)
	pb.cam.position = box.get_center() + cam[2] * 150.0
	await pb._render()
	var img: Image = pb.get_texture().get_image()
	var origin: Vector2 = pb.cam.unproject_position(Vector3.ZERO)
	pb.holder.remove_child(model)
	model.queue_free()
	var truth := {}
	var sizes := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var best := 0
			for i in IDS.size():
				if _dist(c, IDS[i]) < _dist(c, IDS[best]):
					best = i
			var cell := Vector2i(floori(x + 0.5 - origin.x), floori(y + 0.5 - origin.y))
			truth[cell] = best
			sizes[best] = sizes.get(best, 0) + 1
	# The drawn composite: each cell's topmost member (draw order is tree order), shadows left out.
	var top := {}
	_draw_cells(pc, v, v, Transform2D.IDENTITY, 0, index, top, s)
	var over := {}   # "drawn>shown" -> pixels
	for c in truth:
		var want: int = truth[c]
		if not top.has(c) or top[c] == want:
			continue
		var inner := true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			inner = inner and truth.get(c + d, -1) == want
		if inner:
			var key := "%d>%d" % [top[c], want]
			over[key] = over.get(key, 0) + 1
	if pc.debug:   # the truth (left) beside the drawn composite (right), a colour per member
		var dbg := Image.create(400, 300, false, Image.FORMAT_RGBA8)
		dbg.fill(Color.BLACK)
		for c in truth:
			if absi(c.x) < 100 and c.y > -250 and c.y < 50:
				dbg.set_pixel(c.x + 100, c.y + 250, IDS[truth[c]])
		for c in top:
			if absi(c.x) < 100 and c.y > -250 and c.y < 50:
				dbg.set_pixel(c.x + 300, c.y + 250, IDS[top[c]])
		dbg.resize(1200, 900, Image.INTERPOLATE_NEAREST)
		dbg.save_png("/tmp/placement_c4_%s_f%d.png" % [label.replace(" ", "_").replace(":", ""), k])
	var names := ["the engine"] + ms.map(func(m): return m.name)
	var bad := []
	for key in over:
		var shown := int(key.get_slice(">", 1))
		if int(key.get_slice(">", 0)) == 0 and shown > 0 and ms[shown - 1].name.ends_with("_in"):
			continue   # inside the frame, behind the engine by design (layering rule 10): the engine is one
			# sprite, so its far side covers them too (a known limit, docs/rendering.md)
		if over[key] > maxi(SLACK, int(SHARE * sizes.get(shown, 0))):
			bad.append("%s drawn over %s by %d px" % [names[int(key.get_slice(">", 0))], names[shown], over[key]])
	pc.note("C4 composite members drawn in depth order", label, view, not bad.is_empty(), "; ".join(bad))


static func _dist(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


static func _draw_cells(pc, v, n: Node, t: Transform2D, owner: int, index: Dictionary, top: Dictionary, s: float) -> void:
	for c in n.get_children():
		if not c is Node2D or not c.visible:
			continue
		var ct: Transform2D = t * (c as Node2D).transform
		var o := owner
		if n == v.bob:
			for m in v.crew:
				if m.view == c:
					o = index.get(m.socket, 0)
		if c is PartShape:
			var parent_view: Node = c.get_parent()
			if parent_view.has_method("build") and parent_view._shadow == c:
				continue
			var key: String = pc._key(c)
			if PartShape.baked.has(key):
				for q in pc._pixels(key)[0]:
					var p: Vector2 = ct * q
					top[Vector2i(floori(p.x * s), floori(p.y * s))] = o
		_draw_cells(pc, v, c, ct, o, index, top, s)
