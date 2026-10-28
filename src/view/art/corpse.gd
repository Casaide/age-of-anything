extends RefCounted
## The dead laid down in 3D (D-165; rounds HF1 to HF2b, 2026-10-19/20: Dominic on turned and squashed
## sprites, "those are all terrible. Just rotating or squishing the image"; on the sprawl, "probably
## the most realistic"). A body with a `corpse` pose in parts.json (the frog's face-down sprawl) dies
## as a few baked frames instead of a turned sprite: the whole unit put together in 3D (rig3d.gd:
## the body, its legs at their hips, its head, armour and gear on their sockets), laid down (the body
## pitched then rolled about its middle, each leg turned at its hip, body and legs swapped for their
## limp models, the head dropped at its neck), what it held dropped flat on the ground beside it,
## and baked in 8 facings with the unit baker's look; the last frame with its own shadow, the posed
## body pressed flat onto the ground. UnitView plays the frames (_corpse_fall); art_kit bakes them
## with the race (_corpse_job). Each piece of a model is named by its kind, for the placement check.
##
## The pose (parts.json body.<x>.corpse):
##   frames    the frames baked and played, in percent of the way down (100: lying)
##   pivot     [x, y, z] what the body turns about (its middle)
##   pitch     about its side axis first (degrees, + nose up: -37 lays the frog's sloping back level)
##   roll      then about its long axis (+ rolls its top towards its near side, +z)
##   body      the body's model in the pose ("limp": "<body>@limp"; "" as built), from frame 30
##   legs      the legs' model, the same way ("limp": "<leg>@limp", stretched out behind)
##   leg_turn  each leg at its hip: [out from the body (a folded leg's knee), about its side axis
##             (+ lifts a forward leg's tip, drops a stretched-back leg's), spread (a stretched-back
##             leg's foot out to its own side; < 0 across under the body)], degrees
##   head      the head (and its helmet) turned at the neck, degrees (- nose down)
##   helm      true: the helmet comes off and lies upturned by the head
##   spots     {kind: [[x, z], turn]}: where what it held lands, over SPOTS (a body wider than most)
##   turn      [8 degrees]: in each facing the body lies turned this much about its spot (+ anticlockwise
##             seen from above), so every view shows it from a side it reads from (Dominic: "slightly
##             different views from different sides so it always looks good is fine"); seen end on
##             from behind, legs stretched out towards the camera read as legs stood on
## What it held (both hands, a banner on its back) leaves it from frame 60.

const Rig3D := preload("res://src/view/art/rig3d.gd")
const Geom := preload("res://src/view/art/geom.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const BakeClock := preload("res://src/view/art/bake/bake_clock.gd")

const LET_GO := 0.6     # from this far down its hands are empty
const LIMP_FROM := 0.3  # ...and from this far its body and legs are the limp models
## Where what it held lands, in the body's space: [x, z] and its turn on the ground (radians).
## Each clear of the body (placement D2): the banner behind (at x -9 it lay hidden under the body), what the
## near hand held out past the flung arm (at z 10 a worker's basket lay in it).
const SPOTS := {"hand_r": [Vector2(6.0, 21.0), 0.35], "hand_l": [Vector2(-4.0, -11.0), -0.5], "head_gear": [Vector2(14.0, 4.0), 0.0],
	"back": [Vector2(-17.0, 6.0), 2.4]}
const SHADOW := Color(0.06, 0.05, 0.03, 0.42)   # UnitView's shadow colour


## The posed unit as one Node3D (body space: x forward, y up), its lowest point on the ground.
## Children: "body" (a node of the posed pieces, each named by its kind: body, arm, leg, head,
## armour, head_gear, ...) and one node per dropped item, named "dropped:<kind>".
static func model(lib, rig, r: Dictionary, p: Dictionary, f: float) -> Node3D:
	var a: Dictionary = rig.unit(r, {})
	var colours := UnitView.colours_for(lib, r.skin, r.family, Color.MAGENTA)
	var e := clampf(f, 0.0, 1.0)
	var pivot := Vector3(p.pivot[0], p.pivot[1], p.pivot[2])
	var turn := Basis(Vector3(1, 0, 0), deg_to_rad(float(p.roll) * e)) * Basis(Vector3(0, 0, 1), deg_to_rad(float(p.pitch) * e))
	var lay := Transform3D(turn, pivot) * Transform3D(Basis.IDENTITY, -pivot)
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "body"
	root.add_child(body)
	var heads := {}
	for q in a.pieces:
		if q.kind == "head":
			heads[q.name] = q
	var dropped := []
	for q in a.pieces:
		var node: Node3D = q.node
		var xf: Transform3D = q.xf
		var limp: bool = e > LIMP_FROM
		if q.kind in ["body", "arm"] and p.get("body", "") != "" and limp:
			var bs: Dictionary = rig.spec(q.id.get_slice("@", 0) + "@" + p.body, colours)
			node = bs.node if q.kind == "body" else bs.front
		if p.has("head") and (q.kind == "head" or q.parent.ends_with(":head")):
			var neck: Vector3 = heads[q.name if q.kind == "head" else q.parent].joint
			xf = _about(neck, Basis(Vector3(0, 0, 1), deg_to_rad(float(p.head) * e))) * xf
		if q.kind == "leg":
			if p.get("legs", "") != "" and limp:
				node = rig.spec(q.id.get_slice("@", 0) + "@" + p.legs, colours).node
			var side := 1.0 if float(q.hip.z) > 0.0 else -1.0
			var lt: Array = p.leg_turn
			var bend := Basis(Vector3(0, 1, 0), deg_to_rad(float(lt[2]) * e * side)) * Basis(Vector3(1, 0, 0), deg_to_rad(float(lt[0]) * e * side)) \
				* Basis(Vector3(0, 0, 1), deg_to_rad(float(lt[1]) * e))
			xf = _about(q.joint, bend) * xf
		var w := Node3D.new()
		w.name = q.kind
		w.add_child(node.duplicate())
		var banner: bool = q.kind == "back" and "banner" in lib.part(q.id.get_slice("@", 0)).get("tags", [])
		if (q.kind in ["hand_r", "hand_l"] or banner or (q.kind == "head_gear" and p.get("helm", false))) and e >= LET_GO:
			dropped.append([q, w])
			continue
		w.transform = lay * xf
		body.add_child(w, true)
	_ground(body, 0.0)
	# What it held lands flat beside it: the weapon in front on its near side, the shield behind on
	# its far side, the banner behind it, a helmet upturned by its head.
	for d in dropped:
		var q: Dictionary = d[0]
		var w: Node3D = d[1]
		var s: Array = SPOTS[q.kind]
		if p.get("spots", {}).has(q.kind):   # the body's own (a wide one's: the frog's shield lay in its flank)
			s = [Vector2(p.spots[q.kind][0][0], p.spots[q.kind][0][1]), float(p.spots[q.kind][1])]
		w.transform = Transform3D(_flat(w.get_child(0), float(s[1]), q.kind == "head_gear") * q.xf.basis.orthonormalized().inverse() * q.xf.basis, Vector3.ZERO)
		var wrap := Node3D.new()
		wrap.name = "dropped:" + q.kind
		wrap.add_child(w)
		root.add_child(wrap)
		_ground(wrap, 0.2)
		var c := _centre(wrap)
		wrap.position += Vector3(s[0].x - c.x, 0, s[0].y - c.z)
	return root


static func _about(at: Vector3, b: Basis) -> Transform3D:
	return Transform3D(b, at) * Transform3D(Basis.IDENTITY, -at)


## A dropped item's turn to lie flat: its longest side along the ground (turned by yaw), its
## thinnest straight up (a helmet: upside down, the crown on the ground).
static func _flat(n: Node3D, yaw: float, upturned: bool) -> Basis:
	if upturned:
		return Basis(Vector3(1, 0, 0), PI)
	var vs := Geom.vertices(n)
	if vs.is_empty():
		vs = _corners(n, Transform3D.IDENTITY)
	var box := AABB(vs[0], Vector3.ZERO)
	for v in vs:
		box = box.expand(v)
	var axes := [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
	var sizes := [box.size.x, box.size.y, box.size.z]
	var order := [0, 1, 2]
	order.sort_custom(func(i, j): return sizes[i] > sizes[j])
	var long: Vector3 = axes[order[0]]
	var thin: Vector3 = axes[order[2]]
	var along := Vector3(cos(yaw), 0, sin(yaw))
	return Basis(along, Vector3.UP, along.cross(Vector3.UP)) * Basis(long, thin, long.cross(thin)).inverse()


## Moves a node up or down so its lowest vertex is at height y.
static func _ground(n: Node3D, y: float) -> void:
	var lo := INF
	for v in verts(n):
		lo = minf(lo, v.y)
	n.position.y += y - lo


static func _centre(n: Node3D) -> Vector3:
	var sum := Vector3.ZERO
	var vs := verts(n)
	for v in vs:
		sum += v
	return sum / vs.size()


## Every vertex under n's children, in n's parent's space; an item with no solid mesh (only flat
## decals: Geom skips them) by its meshes' box corners.
static func verts(n: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for c in n.get_children():
		var vs := Geom.vertices(c, n.transform)
		out.append_array(vs if not vs.is_empty() else _corners(c, n.transform))
	return out


## The corners of every mesh's box under n (n included), placed by xf * n's own transform.
static func _corners(n: Node3D, xf: Transform3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var t := xf * n.transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var b: AABB = (n as MeshInstance3D).mesh.get_aabb()
		for i in 8:
			out.append(t * b.get_endpoint(i))
	for c in n.get_children():
		if c is Node3D:
			out.append_array(_corners(c, t))
	return out


## Bakes the posed unit at f (0..1 of the way down) in 8 facings with the unit baker's look, kept
## under UnitView.corpse_id (drawn by a PartShape with that id and no shapes); with shadow, its
## shadow too, under that id + "~shadow".
static func bake(baker, lib, rig, r: Dictionary, p: Dictionary, f: float, shadow: bool) -> void:
	var id := UnitView.corpse_id(r, p, roundi(f * 100.0))
	var at := int(r.get("scale", 100))   # at the size its unit is drawn (D-180)
	var key := PartShape.bake_key(id, [], {}, at)
	var art: float = baker.art_scale
	baker.art_scale = art * float(at) / 100.0
	var m := model(lib, rig, r, p, f)
	baker.holder.add_child(m)
	var box: AABB = baker._aabb(m)
	var rad := box.size.length() * 0.5 + Vector2(box.get_center().x, box.get_center().z).length() + 2.0   # (room for it turned about its spot)
	var turns: Array = p.get("turn", [0, 0, 0, 0, 0, 0, 0, 0])
	var px: float = baker.art_scale * baker.SS
	baker.size = Vector2i.ONE * ceili(2.0 * rad * px)
	baker.cam.keep_aspect = Camera3D.KEEP_HEIGHT
	baker.cam.size = 2.0 * rad
	var base: float = baker.azimuth
	var shots := []
	var boxes := []   # each facing's aim, kept for its shadow (the same camera, so the two line up)
	for k in 8:
		baker.azimuth = base + baker.FACING_STEP * k
		m.rotation.y = deg_to_rad(float(turns[k]))
		boxes.append(baker._aabb(m))
		baker._aim(boxes[k])
		await baker._render()
		var shot := {"img": await BakeClock.read(baker)}
		shot.origin = baker.cam.unproject_position(Vector3.ZERO)
		shot.jc = shot.origin
		shots.append(shot)
	# Its shadow: the posed body pressed flat onto the ground (its footprint as the camera sees it),
	# a little wider, so a body lying down sits in its own shadow (Dominic on HF2's sprawl: the
	# standing unit's round shadow "makes it look like it's floating").
	var flats := []
	if shadow:
		var flat := m.duplicate() as Node3D
		baker._hold_out(flat, Color.BLACK)
		flat.scale = Vector3(1.0, 0.01, 1.0)
		m.visible = false
		baker.holder.add_child(flat)
		baker.key.shadow_enabled = false
		for k in 8:
			baker.azimuth = base + baker.FACING_STEP * k
			flat.rotation.y = deg_to_rad(float(turns[k]))
			baker._aim(boxes[k])
			await baker._render()
			flats.append(await BakeClock.read(baker))
		baker.key.shadow_enabled = true
		baker.holder.remove_child(flat)
		flat.queue_free()
	baker.azimuth = base
	baker.holder.remove_child(m)
	m.queue_free()
	var o: bool = baker.outlined
	var bands: int = baker.bands
	var ss: int = baker.SS
	var made: Array = await BakeClock.off_thread(func(): return [shots.map(func(s): return baker._develop(s, false, false, false, 0.0, o, bands)),
		flats.map(func(img): return _shadow(img, ss))])
	for k in 8:
		baker._keep(made[0][k], key + PartShape.facing_suffix(k), id + PartShape.facing_suffix(k))
		if shadow:
			var sh: Image = made[1][k]
			PartShape.baked[PartShape.bake_key(id + "~shadow", [], {}, at) + PartShape.facing_suffix(k)] = {"img": sh,
				"tex": ImageTexture.create_from_image(sh), "origin": shots[k].origin / float(ss), "scale": baker.art_scale}
	baker.art_scale = art


## The footprint render down to art pixels, grown by one and nudged away from the light (down and
## to the right), in the shadow colour.
static func _shadow(img: Image, ss: int) -> Image:
	var w := img.get_width() / ss
	var h := img.get_height() / ss
	var small := img.duplicate() as Image
	small.convert(Image.FORMAT_RGBA8)
	small.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var src := small.get_data()
	var out := PackedByteArray()
	out.resize(w * h * 4)
	var c := [roundi(SHADOW.r * 255), roundi(SHADOW.g * 255), roundi(SHADOW.b * 255), roundi(SHADOW.a * 255)]
	for y in h:
		for x in w:
			if src[(y * w + x) * 4 + 3] < 128:
				continue
			for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(2, 1)]:
				var qx: int = x + d.x
				var qy: int = y + d.y
				if qx >= 0 and qy >= 0 and qx < w and qy < h:
					for i in 4:
						out[(qy * w + qx) * 4 + i] = c[i]
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)
