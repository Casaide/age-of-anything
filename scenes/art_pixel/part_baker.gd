extends SubViewport
## Bakes our 2D parts into lit pixel sprites, keeping their design exactly:
## each shape becomes simple 3D in the part's own 2D frame (ellipse -> ellipsoid,
## circle -> sphere, polygon -> flat face, line -> rod), stacked in its 2D draw
## order, lit by one soft matte light from the upper left, rendered front-on at
## SS x the art size, then pixelized. Results go into PartShape.baked.

const PartShape := preload("res://src/part_shape.gd")
const Pixelize := preload("res://scenes/art_pixel/pixelize.gd")
const BakeClock := preload("res://src/view/art/bake/bake_clock.gd")
const UnitModels := preload("res://scenes/art_pixel/unit_models.gd")

const AZIMUTH := 35.0    # hand-built models are seen three-quarter: from the near side, a bit in front
var azimuth := AZIMUTH   # per bake: other facings (90 = facing the camera, -90 = walking away)
var facings := 8         # hand-built models bake this many facings, 45 degrees apart (tests: 1)
const FACING_STEP := 45.0
var elevation := ELEVATION   # camera height in degrees (tests: a steeper look from above)
var outlined := true     # the units' dark edge (tests: without it)
const ELEVATION := 30.0  # and from above, like the map

const SS := 4            # supersampling
const HOLDOUT := Color(0, 1, 0)   # a wearer's body while its armour bakes: cut out of the result
const LAYER := 50.0      # depth between shapes, so later shapes sit in front
const MARGIN := 3.0      # part units of room around the shapes

var art_scale := 1.5     # art pixels per part unit
var bands := 0           # > 0: painted value bands (the paint-over hybrid; see Pixelize.run)
var cam: Camera3D
var key: DirectionalLight3D
var holder: Node3D
var models := UnitModels.new()
var _bodies := {}        # bodies built for cutting or wearing, by name and colours (_body)
static var prof := {}    # phase -> usec spent, summed over every bake (tests/bake_profile.gd reports it)


static func _lap(phase: String, t0: int) -> int:
	var now := Time.get_ticks_usec()
	prof[phase] = prof.get(phase, 0) + now - t0
	return now


func _init() -> void:
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.far = 5000.0
	add_child(cam)
	key = DirectionalLight3D.new()
	key.basis = Basis.looking_at(Vector3(0.55, -0.7, -1.0).normalized(), Vector3.UP)
	key.light_energy = 1.7
	key.light_color = Color("#fff4e0")   # warm sun, cool shade: the same light as the building bakes
	# Real form, like the buildings: the part shadows itself (an arm on the chest, a helmet's
	# brim on the face) and ambient occlusion darkens its creases.
	key.shadow_enabled = true
	key.shadow_bias = 0.03
	key.shadow_blur = 0.6
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 400.0
	add_child(key)
	var fill := DirectionalLight3D.new()   # a little cool light from the other side, so shade isn't flat
	fill.basis = Basis.looking_at(Vector3(-0.6, -0.3, 0.7).normalized(), Vector3.UP)
	fill.light_energy = 0.3
	fill.light_color = Color("#b8c8ff")
	add_child(fill)
	if OS.has_environment("AOW_UNIT_RIM"):   # fidelity study (docs/concepts/fidelity/): a cool light from behind rims the silhouette
		var rim := DirectionalLight3D.new()
		rim.basis = Basis.looking_at(Vector3(-0.3, -0.35, 1.0).normalized(), Vector3.UP)
		rim.light_energy = float(OS.get_environment("AOW_UNIT_RIM"))
		rim.light_color = Color("#dfe8ff")
		add_child(rim)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c8d0e0")
	env.ambient_light_energy = 0.28
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.5
	env.ssao_power = 1.4
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	holder = Node3D.new()
	add_child(holder)


## Bake one part in one colour set (skipped if it's already baked), at a size: `at` percent of the art scale, its
## unit's recipe scale, so a unit drawn bigger or smaller keeps the art's pixels (D-180; its rigs are in part units,
## the same at any size).
func bake(id: String, shapes: Array, colours: Dictionary, at := 100) -> void:
	colours = PartShape.team_neutral(colours)   # bake in the team key; the shader recolours per team
	var key := PartShape.bake_key(id, shapes, colours, at)
	if PartShape.baked.has(key):
		return
	await BakeClock.breathe()   # building a model is main-thread work: not in a frame that's spent its budget
	var base := art_scale
	art_scale = base * float(at) / 100.0
	await _bake_at(id, shapes, colours, key)
	art_scale = base


func _bake_at(id: String, shapes: Array, colours: Dictionary, key: String) -> void:
	if models.has(id):
		await _bake_model(id, colours, key)
		return
	cam.basis = Basis.IDENTITY
	self.key.basis = Basis.looking_at(Vector3(0.55, -0.7, -1.0).normalized(), Vector3.UP)
	var bounds := _bounds(shapes).grow(MARGIN)
	var px := art_scale * SS
	size = Vector2i(ceili(bounds.size.x * px), ceili(bounds.size.y * px))
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = bounds.size.y
	var centre := bounds.get_center()
	cam.position = Vector3(centre.x, -centre.y, 2000.0)
	var model: Node3D = await BakeClock.build(func():
		var m := Node3D.new()
		for i in shapes.size():
			m.add_child(_shape3d(shapes[i], colours, i))
		return m)
	holder.add_child(model)
	await _render()
	var img := await BakeClock.read(self)
	holder.remove_child(model)
	model.queue_free()
	var origin := Vector2(-bounds.position.x, -bounds.position.y) * art_scale
	var pix: Image = await BakeClock.off_thread(func(): return Pixelize.run(img, SS))
	PartShape.baked[key] = {"img": pix, "tex": ImageTexture.create_from_image(pix), "origin": origin, "scale": art_scale}


const MEMBER_COLUMN := [3.0, 8.0, 13.0, 18.0]   # a member standing on its socket: points up its middle...
const MEMBER_HALF := Vector2(4.0, 2.5)           # ...each as wide and tall as this on screen (part units)
const MEMBER_AHEAD := [[5.0, 10.0], [9.0, 12.0]]  # ...and ahead of it at chest height, [forward, up]: a body leaning into the
                                                  # work (a hunched rat at the ram) is mostly in front of its hips (placement C4)


## For each member socket: true when the member stands in front of most of the engine it overlaps on
## screen. The engine is sampled through its meshes' boxes on a 2-unit grid (a box's corners alone
## would weigh a roof like a bolt).
func _members_front(model: Node3D, sockets: Dictionary, names: Array, view: Vector3) -> Dictionary:
	var right := Vector3.UP.cross(view).normalized()
	var up := view.cross(right)
	var pts := []   # [screen x, screen y, depth]
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if not (mi as MeshInstance3D).visible or (mi as MeshInstance3D).mesh == null:
			continue
		var t := (mi as Node3D).transform
		var p: Node = mi.get_parent()
		while p != null and p != model.get_parent():
			t = (p as Node3D).transform * t
			p = p.get_parent()
		var box: AABB = (mi as MeshInstance3D).mesh.get_aabb()
		var n := Vector3i((box.size / 2.0).ceil()).max(Vector3i.ONE)
		for i in n.x + 1:
			for j in n.y + 1:
				for l in n.z + 1:
					var q: Vector3 = t * (box.position + box.size * Vector3(float(i) / n.x, float(j) / n.y, float(l) / n.z))
					pts.append(Vector3(q.dot(right), q.dot(up), q.dot(view)))
	var out := {}
	var apart := []   # members the engine is neither in front of nor behind
	var cover := {}   # how much of the engine is in front of each member
	var seen := {}    # each member's sample points on screen
	for name in names:
		var nearer := 0
		var farther := 0
		var turn := 0.0   # the member's facing on the engine ("crew2_f2_reach": two steps round from it)
		for t in name.split("_"):
			if t.begins_with("f") and t.length() == 2 and t[1].is_valid_int():
				turn = deg_to_rad(FACING_STEP * int(t[1]))
		var fwd := Vector3(cos(turn), 0.0, sin(turn))
		var samples: Array = MEMBER_COLUMN.map(func(h): return Vector3(0, h, 0))
		if "_reach" in name or "_raise" in name:   # (leaning into the work; a rider sits upright)
			samples += MEMBER_AHEAD.map(func(a): return fwd * float(a[0]) + Vector3(0, float(a[1]), 0))
		seen[name] = []
		for o in samples:
			var c: Vector3 = sockets[name] + o
			var sc := Vector2(c.dot(right), c.dot(up))
			seen[name].append(sc)
			var dc := c.dot(view)
			for q in pts:
				if absf(q.x - sc.x) < MEMBER_HALF.x and absf(q.y - sc.y) < MEMBER_HALF.y:
					if q.z > dc + 1.0:
						nearer += 1
					elif q.z < dc - 1.0:
						farther += 1
		out[name] = nearer <= farther if nearer + farther > 0 else sockets[name].dot(Vector3(view.x, 0, view.z)) > 0.0
		cover[name] = nearer
		if nearer + farther == 0:
			apart.append(name)
	# A member nowhere in front of or behind the engine goes under it all the same when one nearer the
	# camera than it does: else it's drawn over that nearer member (the great sling's file of haulers,
	# lined up in a diagonal view, the first partly behind the frame: placement C4).
	# The same for one drawn over the engine where a member nearer the camera that's drawn under it covers
	# it on screen: under, with that member (a member counts for more than the frame's edge behind it).
	var order := names.duplicate()   # nearest the camera first, so it carries on down a file
	order.sort_custom(func(a, b): return sockets[a].dot(view) > sockets[b].dot(view))
	for name in order:
		if not out[name]:
			continue
		var d: float = sockets[name].dot(view)
		var sc := Vector2(sockets[name].dot(right), sockets[name].dot(up))
		for other in names:
			var so := Vector2(sockets[other].dot(right), sockets[other].dot(up))
			if not out[other] and sockets[other].dot(view) > d and (name in apart or (absf(so.x - sc.x) < MEMBER_HALF.x * 2.0 and absf(so.y - sc.y) < MEMBER_COLUMN[-1])):
				out[name] = false
			elif not out[other] and sockets[other].dot(view) > d and _samples_meet(seen[name], seen[other]):
				# Hunched bodies reaching into each other (rats on the great sling's ropes, a diagonal view):
				# both over the engine or both under it, by which the engine hides less of.
				if cover[other] < cover[name]:
					out[other] = true
				else:
					out[name] = false
	return out


## Two members' sample points close enough on screen that their bodies overlap.
static func _samples_meet(a: Array, b: Array) -> bool:
	for p in a:
		for q in b:
			if absf(p.x - q.x) < MEMBER_HALF.x * 2.0 and absf(p.y - q.y) < MEMBER_HALF.y * 2.0:
				return true
	return false


## A hand-built model in all its facings; its sockets come along, projected into 2D part units.
## The model (and the body that cuts or wears it) is built once and the camera goes round it: each
## facing's lit render (and its near-arm layer), then for a part cut by its body each facing's cut
## mask; then every facing is cut, pixelized and kept. (It was built again for every facing, and
## the cut ran pixel by pixel in GDScript: most of a cold unit bake.)
func _bake_model(id: String, colours: Dictionary, bake_key: String) -> void:
	var tl := Time.get_ticks_usec()
	var spec: Dictionary = await BakeClock.build(func(): return models.build(id, colours))
	var model: Node3D = spec.node
	var front: Node3D = spec.get("front")
	var wearer: Node3D = null
	var pivot := Vector3.ZERO   # where the sprite's origin is (a cut leg's hip, a cut head's socket)
	var joins := false          # a cut head joined to its neck (the body's spec carries a "seam")
	var seam: Node3D = null     # a body's head in place, held out of the body (spec.seam_head)
	var join := Vector3.ZERO    # where the neck joins the head (the body's "join" socket) and how far round it
	var join_r := 0.0           # the seam reaches (spec.seam_r): elsewhere a head in front of the chest keeps its outline
	if spec.has("seam_head") and not "~" in id:
		seam = (await BakeClock.build(func(): return models.build(spec.seam_head, colours))).node
		seam.position = spec.sockets.head
		join = spec.sockets.join
		join_r = float(spec.seam_r)
	var at := id.get_slice("~", 1).get_slice("^", 1) if "^" in id else ""
	if at != "":
		# A leg or head cut by its body ("leg.newt~body.newt^2": the body's anchor 2, "head.pony~body.pony^head"):
		# put on where the body wears it, the body there as the holdout, so the sprite keeps only what
		# the body doesn't hide (a newt's hip inside its flank; a horse's head behind its rump). Its
		# origin stays at the hip or the neck, so it swings and turns from there.
		var body: Dictionary = await _body(id.get_slice("~", 1).get_slice("^", 0), colours)
		wearer = body.node
		joins = at == "head" and body.has("seam_head")   # (a head its neck runs into: no outline where the body hides it)
		if joins:
			join = body.sockets.join
			join_r = float(body.seam_r)
		pivot = body.sockets.head if at == "head" else body.anchors[int(at)][0]
		model.position = pivot
		if at != "head":
			model.basis = UnitModels.leg_basis(body.anchors[int(at)], true) * model.basis   # turned to its own side
		holder.add_child(wearer)
	elif "~" in id:
		# Body armour baked on its wearer: put on at the body's torso, scaled and tilted to it,
		# with the body there as a flat key colour that's cut out afterwards. So the armour
		# wraps the body, and the parts the body hides stay hidden, in every facing.
		var body: Dictionary = await _body(id.get_slice("~", 1), colours)
		wearer = body.node
		var fitted: Dictionary = (await BakeClock.build(func(): return models.fitted(id.get_slice("~", 0), id.get_slice("~", 1), colours))) if models.has_method("fitted") else {}
		if not fitted.is_empty():   # modelled for this body, in its own space: nothing to fit
			model.queue_free()
			model = fitted.node
		else:
			var ts: Vector2 = body.get("torso_scale", Vector2.ONE)
			model.position = body.sockets.torso
			model.scale = body.get("torso_fit", Vector3(ts.x, ts.y, ts.x))
			model.rotation_degrees.z = float(body.get("torso_tilt", 0.0))
		_hold_out(wearer)   # (built bodies used to keep their own colours here: the armour carried a whole body)
		holder.add_child(wearer)
		spec.erase("sockets")
	holder.add_child(model)
	if seam:
		# A body whose neck runs into its head (the creature kit's neck.into): the head in place, cut
		# out below, so the body keeps only what the head doesn't hide and isn't outlined against it.
		holder.add_child(seam)
	var box := _aabb(model)
	if wearer:
		box = box.merge(_aabb(wearer))
	if front:   # the near arm: its own layer, rendered alone after the rest in each facing
		holder.add_child(front)
		box = box.merge(_aabb(front))
		front.visible = false
	var r := box.size.length() * 0.5 + 2.0
	var px := art_scale * SS
	size = Vector2i.ONE * ceili(2.0 * r * px)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = 2.0 * r
	if spec.has("sockets") and spec.sockets.has("seat") and not spec.sockets.has("girth"):
		# The girth: the bottom of the barrel under the seat, where a rider's leg reaches down to.
		var seat: Vector3 = spec.sockets.seat
		var low := seat.y
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var t := Transform3D()
			var p: Node = mi
			while p != model:
				t = (p as Node3D).transform * t
				p = p.get_parent()
			var b: AABB = model.transform * t * mi.get_aabb()
			if b.position.x <= seat.x and b.end.x >= seat.x and b.position.z <= 0.0 and b.end.z >= 0.0:
				low = minf(low, b.position.y)
		spec.sockets["girth"] = Vector3(seat.x, low, 0.0)
	var base := azimuth
	var shots := []   # per facing: {img, front_img, mask, origin, jc}
	tl = _lap("build", tl)
	for k in facings:   # all eight directions, none mirrored (Dominic: 8 baked facings)
		azimuth = base + FACING_STEP * k
		var view := _aim(box)
		await _render()
		tl = _lap("render", tl)
		var shot := {"img": await BakeClock.read(self)}
		tl = _lap("readback", tl)
		if front:   # the near arm alone, so it gets its own outline over the body
			for n in [model, wearer, seam]:
				if n:
					n.visible = false
			front.visible = true
			await _render()
			shot.front_img = await BakeClock.read(self)
			front.visible = false
			for n in [model, wearer, seam]:
				if n:
					n.visible = true
			tl = _lap("render", tl)
		shot.origin = cam.unproject_position(pivot)   # the sprite's origin (a cut part's hip or neck; else the model's)
		shot.jc = cam.unproject_position(join)
		if spec.has("sockets"):
			PartShape.rigs[id + PartShape.facing_suffix(k)] = _rig(spec, model, view, k, px)
		shots.append(shot)
		tl = _lap("rig", tl)
	var cut := at != "" or seam != null
	if cut:
		# The cut: the part in white over what hides it (its body, or a body's head) in black, unlit;
		# only the white is kept (not a key colour, which a green frog's own leg could match).
		_hold_out(model, Color.WHITE)
		_hold_out(wearer if at != "" else seam, Color.BLACK)
		key.shadow_enabled = false
		for k in facings:
			azimuth = base + FACING_STEP * k
			_aim(box)
			await _render()
			tl = _lap("render cut", tl)
			shots[k].mask = await BakeClock.read(self)
		tl = _lap("readback", tl)
		key.shadow_enabled = true
	azimuth = base
	for n in [model, wearer, seam, front]:
		if n:
			holder.remove_child(n)
			n.queue_free()
	# Every facing's cut and pixelize on a worker thread (the frames go on meanwhile), then kept.
	var seamed := joins or seam != null
	var worn := wearer != null
	var reach := join_r * px
	var o := outlined
	var b := bands
	var made: Array = await BakeClock.off_thread(func(): return shots.map(func(shot): return _develop(shot, cut, seamed, worn, reach, o, b)))
	tl = _lap("cut + pixelize", tl)
	for k in facings:
		_keep(made[k], bake_key + PartShape.facing_suffix(k), id + PartShape.facing_suffix(k))


## A body a part is cut by or worn on ({node, sockets, ...} as models.build makes it, without its
## near-arm layer), built once per colour set and copied after: a body took 30 ms to build, and
## each leg of a walk cycle built it again (a war beast's body 32 times).
func _body(name: String, colours: Dictionary) -> Dictionary:
	var key := name + str(colours)
	if not _bodies.has(key):
		var spec: Dictionary = await BakeClock.build(func(): return models.build(name, colours))
		if spec.get("front"):
			spec.front.free()
			spec.erase("front")
		_bodies[key] = spec
	var body: Dictionary = _bodies[key].duplicate()
	body.node = (_bodies[key].node as Node3D).duplicate()
	return body


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for b in _bodies.values():
			if is_instance_valid(b.node):   # (BakeClock frees them first when the game quits)
				b.node.free()


## Point the camera at the model from this facing (azimuth) and height, the key light from the
## viewer's upper left, a little in front. Returns the direction towards the camera.
func _aim(box: AABB) -> Vector3:
	var az := deg_to_rad(azimuth)
	var el := deg_to_rad(elevation)
	var view := Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))
	cam.basis = Basis.looking_at(-view, Vector3.UP)
	cam.position = box.get_center() + view * 150.0   # close enough for the shadow range
	key.basis = Basis.looking_at(cam.basis * Vector3(0.55, -0.75, -1.0).normalized(), Vector3.UP)
	return view


## A facing's rig: the model's sockets on screen (part units from its origin) and how deep each is.
func _rig(spec: Dictionary, model: Node3D, view: Vector3, k: int, px: float) -> Dictionary:
	var zero := cam.unproject_position(Vector3.ZERO)   # the model's origin: sockets are relative to it
	var to2d := func(p: Vector3) -> Vector2: return (cam.unproject_position(p) - zero) / px
	var flat := Vector3(view.x, 0.0, view.z).normalized()   # towards the camera, along the ground
	var rig := {"sockets": {}, "depth": {}}
	for s in spec.sockets:
		rig.sockets[s] = to2d.call(spec.sockets[s])
		rig.depth[s] = spec.sockets[s].dot(flat)   # > 0: nearer the camera than the body's middle
	# An engine's members beside it (crew, haulers; not those inside its frame or riding on top) are
	# drawn over it or under it by which is in front where they overlap on screen, not by the socket's
	# depth alone (a centaur crew's torso rose in front of a ram's roof drawn under it: placement C4).
	var members: Array = spec.sockets.keys().filter(func(s): return (s.begins_with("crew") or s.begins_with("haul")) and not s.ends_with("_in") and not s.ends_with("_top"))
	if not members.is_empty():
		rig["front"] = _members_front(model, spec.sockets, members, view)
	# Which way the model's front (+x) points on screen in this facing, to pick facings by.
	rig.dir = (cam.unproject_position(Vector3(20, 0, 0)) - zero).normalized()
	rig.ahead = to2d.call(Vector3(1, 0, 0))   # one unit forward on screen (part units): a crew member standing back from its place
	if spec.has("anchors"):   # a leg on the camera's side of the body is the near leg
		rig.anchors = spec.anchors.map(func(a): var v: Vector2 = to2d.call(a[0]); return [v.x, v.y, a[1],
			a[2] if k == 0 else (1 if a[0].dot(flat) > 0.0 else -1), a[3] if a.size() > 3 else 0, a[4] if a.size() > 4 else false,
			a[0].z * flat.z > 0.0])   # a[4]: a hind leg (its body's legs.hind part); [6]: its side of the body faces the camera
	if spec.has("torso_scale"):
		rig.torso_scale = spec.torso_scale
	if spec.has("gear_scale"):
		rig.gear_scale = spec.gear_scale
	if spec.has("carry"):
		rig.carry = spec.carry
	if spec.has("legs_under"):
		rig.legs_under = spec.legs_under
	return rig


## One facing's sprite from its shot (images only: it runs on a worker thread): cut by its body
## (cut: the mask's white kept, seamed: no outline where it joins; worn: the holdout key cleared),
## cropped, pixelized (with its near-arm layer), and where the drawn part reaches furthest from its
## grip. {pix, top (the near-arm layer or null), origin, tip (sprite px)}.
static func _develop(shot: Dictionary, cut: bool, seamed: bool, worn: bool, reach: float, outlined: bool, bands: int) -> Dictionary:
	var img: Image = shot.img
	var seam_img: Image = null  # where the part meets another of the unit's parts: no outline there
	if cut:
		if seamed:
			seam_img = _seam_mask(shot.mask, shot.jc, reach)
		img = _keep_white(img, shot.mask)
	elif worn:
		_cut_holdout(img)
	var front_img: Image = shot.get("front_img")
	var used := img.get_used_rect()
	if front_img:
		used = used.merge(front_img.get_used_rect())
	used = used.grow(SS * 2).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	used.position = used.position / SS * SS
	var pix := Pixelize.run(img.get_region(used), SS, outlined, bands, seam_img.get_region(used) if seam_img else null)
	var top: Image = Pixelize.run(front_img.get_region(used), SS, outlined, bands) if front_img else null
	var o: Vector2 = (shot.origin - Vector2(used.position)) / SS
	# Where the drawn part reaches furthest from its grip: a weapon's tip,
	# so a body with no arms can lay it couched whatever way it was modelled.
	var tip := Vector2.ZERO
	var data := pix.get_data()
	var w := pix.get_width()
	for i in range(3, data.size(), 4):
		if data[i] > 229:   # (alpha over 0.9)
			var d := Vector2((i / 4) % w, (i / 4) / w) - o
			if d.length() > tip.length():
				tip = d
	return {"pix": pix, "top": top, "origin": o, "tip": tip}


## One facing's developed sprite kept in PartShape.baked (its near-arm layer as its own sprite:
## UnitView layers it above torso armour), its tip (part units) in its rig.
func _keep(d: Dictionary, bake_key: String, rig_id: String) -> void:
	if d.top:
		PartShape.baked[PartShape.front_key(bake_key)] = {"img": d.top, "tex": ImageTexture.create_from_image(d.top),
			"origin": d.origin, "scale": art_scale}
		PartShape.rigs[rig_id]["front"] = true
	PartShape.baked[bake_key] = {"img": d.pix, "tex": ImageTexture.create_from_image(d.pix), "origin": d.origin, "scale": art_scale}
	if not PartShape.rigs.has(rig_id):
		PartShape.rigs[rig_id] = {}
	PartShape.rigs[rig_id]["tip"] = d.tip / art_scale


## The render with only what the cut mask shows white (r >= 0.5) kept, the rest cleared: done by
## the engine (the mask thresholded, its red and green read as luminance and alpha, a masked blit),
## not pixel by pixel.
static func _keep_white(img: Image, mask: Image) -> Image:
	var out := Image.create(img.get_width(), img.get_height(), false, img.get_format())
	var m: Image = mask.duplicate()
	m.convert(Image.FORMAT_RG8)
	var white := Image.create_from_data(m.get_width(), m.get_height(), false, Image.FORMAT_LA8, m.get_data()).get_used_rect()
	if white.size == Vector2i.ZERO:
		return out   # the body hides it all in this facing
	var crop := mask.get_region(white)   # the rest works on the part's own box (the render holds its whole body)
	crop.convert(Image.FORMAT_RGBA8)
	crop.adjust_bcs(1.0, 1000.0, 1.0)   # each channel to 0 or 1 at 0.5
	crop.convert(Image.FORMAT_RG8)
	var la := Image.create_from_data(crop.get_width(), crop.get_height(), false, Image.FORMAT_LA8, crop.get_data())
	out.blit_rect_mask(img.get_region(white), la, Rect2i(Vector2i.ZERO, white.size), white.position)
	return out


## Where a cut part meets what cuts it, near the join (within reach px of jc): the mask's black
## (the body or head over it), white in an L8 image the size of the render.
static func _seam_mask(mask: Image, jc: Vector2, reach: float) -> Image:
	var w := mask.get_width()
	var h := mask.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_L8)
	var m: Image = mask.duplicate()
	m.convert(Image.FORMAT_RGBA8)
	var d := m.get_data()
	var lo := Vector2i((jc - Vector2.ONE * reach).floor()).clamp(Vector2i.ZERO, Vector2i(w, h))
	var hi := Vector2i((jc + Vector2.ONE * (reach + 1.0)).ceil()).clamp(Vector2i.ZERO, Vector2i(w, h))
	for y in range(lo.y, hi.y):
		for x in range(lo.x, hi.x):
			var i := (y * w + x) * 4
			if d[i] < 128 and d[i + 3] >= 128 and jc.distance_to(Vector2(x, y)) <= reach:
				out.set_pixel(x, y, Color.WHITE)
	return out


static func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D()
		var p: Node = mi
		while p != n:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		var b: AABB = t * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


static func _bounds(shapes: Array) -> Rect2:
	var r := Rect2()
	var first := true
	for s in shapes:
		var pts := []
		match s.t:
			"ellipse":
				var c := PartShape.v2(s.c)
				var rr := PartShape.v2(s.r)
				pts = [c - rr, c + rr]
			"circle":
				var c := PartShape.v2(s.c)
				pts = [c - Vector2.ONE * float(s.r), c + Vector2.ONE * float(s.r)]
			_:
				for p in s.p:
					pts.append(PartShape.v2(p))
				if s.t == "line":
					var w := float(s.w)
					pts = pts.map(func(p): return p + Vector2(w, w)) + pts.map(func(p): return p - Vector2(w, w))
		for p in pts:
			if first:
				r = Rect2(p, Vector2.ZERO)
				first = false
			else:
				r = r.expand(p)
	return r


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.metallic_specular = 0.15
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	return m


func _shape3d(s: Dictionary, colours: Dictionary, i: int) -> Node3D:
	var col: Color = colours.get(s.ch, Color.MAGENTA)
	var z := i * LAYER
	match s.t:
		"ellipse", "circle":
			var r := PartShape.v2(s.r) if s.t == "ellipse" else Vector2.ONE * float(s.r)
			var c := PartShape.v2(s.c)
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			sm.radial_segments = 32
			sm.rings = 16
			var mi := MeshInstance3D.new()
			mi.mesh = sm
			mi.material_override = _mat(col)
			mi.scale = Vector3(r.x, r.y, minf(r.x, r.y) * 0.85)
			mi.position = Vector3(c.x, -c.y, z)
			return mi
		"poly":
			var pts := PartShape.points(s.p)
			var tris := Geometry2D.triangulate_polygon(pts)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var centre := Vector2.ZERO
			for p in pts:
				centre += p
			centre /= pts.size()
			for k in tris:
				var p := pts[k]
				# Tilt normals outward a little, so flat pieces still catch the light like a bevel.
				var out := (p - centre).normalized() * 0.35
				st.set_normal(Vector3(out.x, -out.y, 1.0).normalized())
				st.add_vertex(Vector3(p.x, -p.y, z))
			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
			mi.material_override = _mat(col)
			mi.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
			return mi
		"line":
			var n := Node3D.new()
			var pts := PartShape.points(s.p)
			var r := maxf(0.6, float(s.w) * 0.5)
			for k in range(1, pts.size()):
				var a := Vector3(pts[k - 1].x, -pts[k - 1].y, z)
				var b := Vector3(pts[k].x, -pts[k].y, z)
				var cm := CylinderMesh.new()
				cm.top_radius = r
				cm.bottom_radius = r
				cm.height = a.distance_to(b)
				cm.radial_segments = 10
				var mi := MeshInstance3D.new()
				mi.mesh = cm
				mi.material_override = _mat(col)
				mi.position = (a + b) * 0.5
				var dir := (b - a).normalized()
				mi.basis = Basis(Quaternion(Vector3.UP, dir)) if not dir.is_equal_approx(Vector3.DOWN) else Basis(Vector3.RIGHT, PI)
				n.add_child(mi)
				var cap := MeshInstance3D.new()
				var sp := SphereMesh.new()
				sp.radius = r
				sp.height = r * 2.0
				cap.mesh = sp
				cap.material_override = mi.material_override
				cap.position = b
				n.add_child(cap)
			return n
	return Node3D.new()


## Make the holdout colour (and the edge pixels mostly made of it) transparent.
## Paint a body as the flat holdout key. Surface by surface on modelled (.glb) meshes:
## material_override there made the renderer log 'Parameter "material" is null' hundreds of times
## per bake (humans, centaurs); built meshes carry a material_override, which wins, so it's replaced.
static func _hold_out(body: Node3D, colour := HOLDOUT) -> void:
	var key_mat := StandardMaterial3D.new()
	key_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	key_mat.albedo_color = colour
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).material_override != null:
			(mi as MeshInstance3D).material_override = key_mat
		else:
			for surface in (mi as MeshInstance3D).mesh.get_surface_count():
				(mi as MeshInstance3D).set_surface_override_material(surface, key_mat)


static func _cut_holdout(img: Image) -> void:
	img.convert(Image.FORMAT_RGBA8)
	var d := img.get_data()
	for i in range(0, d.size(), 4):
		var g := d[i + 1]
		if d[i + 3] > 0 and g > 140 and g > d[i] * 1.8 and g > d[i + 2] * 1.8:   # (green over 0.55, well above red and blue)
			d[i] = 0
			d[i + 1] = 0
			d[i + 2] = 0
			d[i + 3] = 0
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d)


## Render this viewport once (BakeClock: drawn on demand, even while the window is hidden).
func _render() -> void:
	await BakeClock.render(self)
