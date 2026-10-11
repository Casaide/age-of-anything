extends RefCounted
## Hand-built 3D models for unit parts, keyed by part id, using the 2D parts as
## design reference. Each model is in its part's frame (part units, about one 2D
## pixel each): x = the way the unit faces, y = up, z = towards the viewer's side.
## Bodies and heads also declare 3D sockets (and bodies their leg hips); the baker
## projects them into 2D so UnitView composes the baked parts as usual.
## Surfaces use authored, tileable textures (assets/art/textures/) mapped
## triplanar and tinted by the race's colours; features (eyes, mouths, leaves,
## lily pads) are authored decals.

const TEX_DIR := "res://assets/art/textures/"

var tex_cache := {}
var hold := "low"   # the body being built: how its near hand holds the weapon (see arm_pose)


## Part ids may carry a hold after "@" (a body posed for its weapon: "body.frog@throw").
func has(id: String) -> bool:
	return has_method("_" + id.get_slice("@", 0).replace(".", "_"))


## {node: Node3D, sockets: {name: Vector3}, anchors: [[Vector3 hip, phase, z]]}
func build(id: String, colours: Dictionary) -> Dictionary:
	hold = id.get_slice("@", 1) if "@" in id else "low"
	return call("_" + id.get_slice("@", 0).replace(".", "_"), colours)


## The near arm's elbow and hand for the body's hold, from its shoulder, its resting
## elbow and hand, and its head socket. The weapon is built around its grip at the
## hand, so the hand always holds it:
## low (spears, swords, tools), throw (a javelin raised over the shoulder), mouth (a
## blowgun at the lips), overhead (a sling whirled above), draw (a bow at arm's length),
## shoulder (a pike), aim (a crossbow or musket held forward).
const INK := Color("#2a1a12")


func arm_pose(sh: Vector3, elbow: Vector3, hand: Vector3, head: Vector3) -> Array:
	var z := sh.z
	match hold:
		"throw":
			return [sh + Vector3(1.0, 3.5, 1.8), sh + Vector3(-2.5, 9.0, 0.8)]
		"mouth":
			var at := Vector3(head.x + 6.0, head.y + 1.0, z * 0.45)
			return [Vector3(sh.x + 4.5, sh.y - 3.5, z + 1.2), at]
		"overhead":
			return [sh + Vector3(1.5, 4.5, 1.2), sh + Vector3(0.5, 9.0, 0.0)]
		"draw":
			return [sh + Vector3(4.5, -0.4, 1.0), sh + Vector3(9.5, -0.5, 0.8)]
		"shoulder":
			return [sh + Vector3(2.0, -4.5, 1.8), sh + Vector3(3.5, -2.0, 1.4)]
		"aim":
			return [sh + Vector3(3.0, -3.0, 1.4), sh + Vector3(7.5, -1.0, 0.6)]
	return [elbow, hand]


# ------------------------------------------------------------------ materials

func tex(name: String) -> Texture2D:
	if not tex_cache.has(name):
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string(TEX_DIR + name + ".svg"), 1.0)
		img.generate_mipmaps()
		tex_cache[name] = ImageTexture.create_from_image(img)
	return tex_cache[name]


## A tileable texture wrapped over any shape (triplanar), tinted.
func surf(name: String, tint := Color.WHITE, units := 10.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(name)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true   # blobs are scaled unit spheres: in local space a whole body would get a sliver of texture
	m.uv1_triplanar_sharpness = 2.0
	m.uv1_scale = Vector3.ONE / units
	m.roughness = 1.0
	m.metallic_specular = 0.2
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


func plain(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.metallic_specular = 0.2
	return m


## A decal: an authored picture with crisp alpha on a quad.
func decal(name: String, w: float, h: float, pos: Vector3, facing: Vector3, lit := true, up := Vector3.UP, tint := Color.WHITE) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(name)
	m.albedo_color = tint
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not lit:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.position = pos
	var f := facing.normalized()
	var u := up if absf(f.dot(up)) < 0.95 else Vector3.FORWARD
	mi.basis = Basis.looking_at(-f, u)   # a QuadMesh faces +z; point that along `facing`
	return mi


# ------------------------------------------------------------------ shapes

## The point on an ellipsoid's surface in direction `dir` from its centre, nudged out a little.
static func on_surface(centre: Vector3, radii: Vector3, dir: Vector3, out := 0.25) -> Vector3:
	var d := dir.normalized()
	var k := 1.0 / sqrt(pow(d.x / radii.x, 2) + pow(d.y / radii.y, 2) + pow(d.z / radii.z, 2))
	return centre + d * (k + out)

func blob(r: Vector3, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 32
	s.rings = 16
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = m
	mi.scale = r
	mi.rotation_degrees = rot
	mi.position = pos
	return mi


## A rod from a to b (radius r1 at a, r2 at b), with rounded ends.
func rod(a: Vector3, b: Vector3, r1: float, r2: float, m: Material, caps := true) -> Node3D:
	var n := Node3D.new()
	var c := CylinderMesh.new()
	c.bottom_radius = r1
	c.top_radius = r2
	c.height = a.distance_to(b)
	c.radial_segments = 14
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	mi.position = (a + b) * 0.5
	var d := (b - a).normalized()
	mi.basis = Basis(Quaternion(Vector3.UP, d)) if not d.is_equal_approx(Vector3.DOWN) else Basis(Vector3.RIGHT, PI)
	n.add_child(mi)
	if caps:
		n.add_child(blob(Vector3.ONE * r1, m, a))
		n.add_child(blob(Vector3.ONE * r2, m, b))
	return n


func ring(inner: float, outer: float, m: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 28
	t.ring_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	return mi


## A team-colour kerchief knotted at the neck, with a tail hanging in front. It goes in
## the front layer, so armour never hides it: every infantry body shows its team.
func kerchief(into: Node3D, c: Dictionary, neck: Vector3, r: float, lean := 0.0) -> void:
	var team := surf("cloth", c.team, 3.0)
	into.add_child(ring(r * 0.75, r * 1.3, team, neck, Vector3(0, 0, lean), Vector3(1, 1.6, 1)))
	var knot := neck + Vector3(r * 0.95, -r * 0.2, r * 0.35)
	into.add_child(blob(Vector3(1.1, 1.1, 1.0) * r * 0.32, team, knot))
	into.add_child(slab([Vector2(0, 0), Vector2(r * 0.45, -r * 0.2), Vector2(r * 0.25, -r * 1.3), Vector2(-r * 0.15, -r * 1.1)], 0.5, team, knot + Vector3(-r * 0.1, -r * 0.1, 0.3)))


# ------------------------------------------------------------------ frog

## Frog helpers (the crouched leaper, picked by Dominic 2026-10-11).
## The frog's skin, wetter and more saturated than today's: poison-dart colours.
const FROG_SCALE := 1.25   # the crouched frog is built small; infantry of every creature stand one height


## Scale a built part about its origin, with its sockets and anchors (front layer too).
func _scaled(spec: Dictionary, k: float) -> Dictionary:
	for key in ["node", "front"]:
		if spec.get(key) != null:
			var wrap := Node3D.new()
			wrap.scale = Vector3.ONE * k
			wrap.add_child(spec[key])
			spec[key] = wrap
	if spec.has("sockets"):
		for name in spec.sockets:
			spec.sockets[name] *= k
	if spec.has("anchors"):
		spec.anchors = spec.anchors.map(func(a): return [a[0] * k] + a.slice(1))
	return spec


func _vivid(c: Color) -> Color:
	return Color.from_hsv(c.h, minf(1.0, c.s * 1.25 + 0.05), minf(1.0, c.v * 1.08 + 0.02))


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


func _body_frog(c: Dictionary) -> Dictionary:
	return _scaled(_body_frog_built(c), FROG_SCALE)


func _body_frog_built(c: Dictionary) -> Dictionary:
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

func _head_frog(c: Dictionary) -> Dictionary:
	return _scaled(_head_frog_built(c), FROG_SCALE)


func _head_frog_built(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _frog_mats(c)
	n.add_child(blob(Vector3(5.8, 3.0, 5.4), m[0], Vector3(2.4, 2.4, 0)))
	n.add_child(blob(Vector3(4.6, 1.6, 4.4), m[1], Vector3(2.8, 0.9, 0)))           # the throat
	n.add_child(rod(Vector3(7.6, 1.9, -3.6), Vector3(7.9, 1.9, 0), 0.32, 0.32, plain(INK)))   # the mouth line, round the front
	n.add_child(rod(Vector3(7.9, 1.9, 0), Vector3(7.6, 1.9, 3.6), 0.32, 0.32, plain(INK)))
	_frog_eyes(n, Vector3(3.2, 5.2, 0), 3.0, 2.2, m[0])
	# The top sits behind the eyes, and gear is sized to this small head: it never covers them.
	return {"node": n, "sockets": {"top": Vector3(-0.6, 5.0, 0)}, "gear_scale": 0.62}


# --- B: the slim tree frog. Upright but lean, long limbs, big toe pads, eyes bulging at the sides.

func _leg_frog(c: Dictionary) -> Dictionary:
	return _scaled(_leg_frog_built(c), FROG_SCALE)


func _leg_frog_built(c: Dictionary) -> Dictionary:
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

func _tool_basket(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var weave := surf("wicker", Color.WHITE, 4.0)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 4.6
	cyl.bottom_radius = 3.6
	cyl.height = 6.0
	cyl.radial_segments = 20
	var b := MeshInstance3D.new()
	b.mesh = cyl
	b.material_override = weave
	b.position = Vector3(1.0, -5.5, 0.5)
	n.add_child(b)
	n.add_child(ring(4.3, 5.1, surf("bark_plate", Color("#c8a070"), 6.0), Vector3(1.0, -2.5, 0.5)))
	n.add_child(ring(4.3, 4.9, surf("wicker", Color("#d8b880"), 3.0), Vector3(1.0, -2.0, 0.5), Vector3(90, 0, 0), Vector3(1, 1, 0.9)))
	for k in 6:
		n.add_child(blob(Vector3(1.1, 0.8, 1.1), plain(Color("#e0607f")), Vector3(-1.5 + k * 1.0, -2.2, -1.5 + (k % 3) * 1.4)))
	return {"node": n}


func _weapon_spear_reed(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var a := Vector3(-4, -8, 0)     # held upright: a spear stands tall
	var b := Vector3(6, 19, 0)
	n.add_child(rod(a, b, 1.05, 1.0, surf("reed_stalk", Color.WHITE, 5.0), false))
	var d := (b - a).normalized()
	var head := CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = 3.4   # a big, pale blade: it must read as a spear, not a blowgun
	head.height = 9.5
	head.radial_segments = 4
	var tip := MeshInstance3D.new()
	tip.mesh = head
	tip.material_override = surf("bone", Color.WHITE, 4.0)
	tip.position = b + d * 4.0
	tip.basis = Basis(Quaternion(Vector3.UP, d)).scaled(Vector3(1.0, 1.0, 0.45))
	n.add_child(tip)
	for k in 3:
		n.add_child(ring(0.7, 1.1, surf("leather", Color.WHITE, 3.0), b - d * (0.6 + k * 0.9), Vector3(0, 0, rad_to_deg(atan2(d.y, d.x)) - 90)))
	return {"node": n}


func _armour_bark(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(blob(Vector3(9.0, 8.4, 10.8), surf("bark_plate", Color.WHITE, 9.0), Vector3(2.0, 0.5, 0), Vector3(0, 0, -10)))
	for side in [1, -1]:
		n.add_child(ring(9.6, 10.6, surf("leather", Color.WHITE, 4.0), Vector3(1.5, 1.0, 0), Vector3(0, 0, 70 * side), Vector3(1, 1, 1.0)))
	n.add_child(blob(Vector3(1.2, 1.2, 0.6), plain(Color("#c08a3e")), Vector3(10.6, 2.0, 2.0)))
	return {"node": n}


func _shield_lilypad(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(decal("lily_pad", 15.0, 15.0, Vector3(4.0, 0.5, 2.0), Vector3(1.0, 0.1, 0.45)))
	return {"node": n}


func _helm_acorn(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(blob(Vector3(6.6, 3.8, 6.6), surf("acorn_cap", Color.WHITE, 3.5), Vector3(0, 0.6, 0)))
	n.add_child(rod(Vector3(0, 3.8, 0), Vector3(0.8, 6.8, 0), 0.8, 0.55, surf("bark_plate", Color("#8a6a40"), 3.0)))
	return {"node": n}


func _hat_leaf(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(decal("leaf", 10.0, 13.0, Vector3(0, 2.2, 0), Vector3(0.25, 1.0, 0.35), true, Vector3.RIGHT))
	n.add_child(rod(Vector3(-5.5, 1.5, -0.5), Vector3(-7.5, 3.0, -0.8), 0.35, 0.3, plain(Color("#6b4a2a"))))
	return {"node": n}


func _cape_leaf(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(decal("leaf", 13.0, 17.0, Vector3(-3.0, -6.0, 1.5), Vector3(-0.5, 0.2, 0.85), true, Vector3(0.4, 1, 0)))
	return {"node": n}


## An extruded outline (blades, spearheads): points in the xy plane, thickness along z.
func slab(points: Array, thick: float, m: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var pts := PackedVector2Array(points)
	var tris := Geometry2D.triangulate_polygon(pts)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := thick * 0.5
	for face in [1.0, -1.0]:
		for k in range(0, tris.size(), 3):
			var order := [tris[k], tris[k + 1], tris[k + 2]] if face > 0 else [tris[k], tris[k + 2], tris[k + 1]]
			for i in order:
				st.set_normal(Vector3(0, 0, face))
				st.add_vertex(Vector3(pts[i].x, pts[i].y, h * face))
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var nrm := Vector3(b.y - a.y, a.x - b.x, 0).normalized()
		for v in [Vector3(a.x, a.y, h), Vector3(b.x, b.y, h), Vector3(b.x, b.y, -h), Vector3(a.x, a.y, h), Vector3(b.x, b.y, -h), Vector3(a.x, a.y, -h)]:
			st.set_normal(nrm)
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.position = pos
	return mi


# ------------------------------------------------------------------ rat

func _body_rat(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", c.skin, 7.0)
	var pink := surf("frog_belly", c.skin2, 6.0)
	# Lean and hunched (Dominic: "less fat"): a narrow body tilted forward, the belly showing in front.
	n.add_child(blob(Vector3(5.4, 10.4, 5.0), fur, Vector3(0.2, 15, 0), Vector3(0, 0, 15)))
	n.add_child(blob(Vector3(3.4, 7.0, 3.6), pink, Vector3(2.6, 13.6, 0.4), Vector3(0, 0, 15)))
	# A long tail curling behind, thinning to a point.
	var pts := [Vector3(-5, 7, 0), Vector3(-11, 4.5, 1.5), Vector3(-16.5, 5.5, 2.5), Vector3(-19.5, 9.5, 3.0), Vector3(-19, 14, 3.0), Vector3(-16.5, 16, 2.5)]
	for k in range(1, pts.size()):
		n.add_child(rod(pts[k - 1], pts[k], 1.25 - k * 0.17, 1.25 - (k + 1) * 0.17, pink))
	var near_hand := Vector3.ZERO
	var front := Node3D.new()
	for side in [1, -1]:
		var into: Node3D = front if side == 1 else n
		var sh := Vector3(3.6, 19.5, 4.4 * side)
		var elbow := Vector3(5, 16.5, 5.8 * side)
		var hand := Vector3(8, 15.5, 4.6 * side) if side == 1 else Vector3(7.5, 16.5, -4.2)
		if side == 1:
			var pose := arm_pose(sh, elbow, hand, Vector3(4, 24.5, 0))
			elbow = pose[0]
			hand = pose[1]
			near_hand = hand
		into.add_child(rod(sh, elbow, 1.9, 1.7, fur))
		into.add_child(rod(elbow, hand, 1.7, 1.5, fur))
		into.add_child(blob(Vector3(1.7, 1.4, 1.7), pink, hand))
	kerchief(front, c, Vector3(3.2, 22.2, 0), 3.0, 15)   # a small scarf at the neck (a big one read as a bib)
	return {"node": n, "front": front, "sockets": {
		"head": Vector3(4, 24.5, 0), "hand_r": near_hand, "hand_l": Vector3(7.5, 16.5, -4.2),
		"torso": Vector3(2.2, 17.5, 0), "back": Vector3(-4.5, 19, 0)},
		"anchors": [[Vector3(-0.5, 6.0, -3.2), 0.0, -1], [Vector3(-0.5, 6.0, 3.2), PI, 1]],
		"torso_scale": Vector2(0.58, 0.74)}


func _head_rat(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", c.skin, 6.0)
	var pink := surf("frog_belly", c.skin2, 5.0)
	var skull_c := Vector3(1, 4.5, 0)
	var skull_r := Vector3(5.2, 4.8, 4.6)
	n.add_child(blob(skull_r, fur, skull_c))
	n.add_child(rod(Vector3(3, 4, 0), Vector3(11, 2.6, 0), 3.4, 1.1, fur))   # the snout
	n.add_child(blob(Vector3(1.3, 1.1, 1.3), plain(Color("#e8909c")), Vector3(11.4, 2.7, 0)))
	n.add_child(blob(Vector3(0.6, 1.0, 1.4), plain(Color("#f4f0e0")), Vector3(9.6, 0.9, 0)))   # buck teeth
	for side in [1, -1]:
		var look := Vector3(0.5, 0.35, 0.8 * side)
		n.add_child(decal("rat_eye", 2.6, 2.6, on_surface(skull_c, skull_r, look, 0.1), look, false))
		n.add_child(blob(Vector3(0.8, 4.0, 3.6), fur, Vector3(-1.2, 9.0, 3.4 * side), Vector3(0, 20 * side, -10)))
		n.add_child(blob(Vector3(0.5, 3.0, 2.6), pink, Vector3(-0.7, 9.0, 3.6 * side), Vector3(0, 20 * side, -10)))
		for w in 3:
			n.add_child(rod(Vector3(9.5, 2.8, 1.2 * side), Vector3(12.5, 2.2 + w * 1.0, (3.5 + w * 0.4) * side), 0.12, 0.08, plain(Color("#3a3430")), false))
	return {"node": n, "sockets": {"top": Vector3(0, 9.5, 0)}}


func _leg_rat(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", c.skin, 6.0)
	var pink := surf("frog_belly", c.skin2, 5.0)
	n.add_child(blob(Vector3(2.8, 3.4, 2.6), fur, Vector3(0.3, -1.8, 0)))
	n.add_child(rod(Vector3(0.5, -3.5, 0), Vector3(0.2, -6.0, 0), 1.0, 0.8, pink))
	n.add_child(blob(Vector3(3.0, 0.6, 1.3), pink, Vector3(2.4, -6.4, 0)))
	for t in 3:
		n.add_child(blob(Vector3(0.5, 0.4, 0.4), pink, Vector3(5.3, -6.5, (t - 1) * 0.8)))
	return {"node": n}


func _tool_axe(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3(-1, -3.5, 0), Vector3(3, 9.5, 0), 0.75, 0.7, surf("wood_grain", Color.WHITE, 6.0)))
	n.add_child(slab([Vector2(2.2, 9.0), Vector2(7.5, 10.5), Vector2(7.0, 4.5), Vector2(3.0, 6.5)], 0.9, surf("bronze", Color.WHITE, 4.0)))
	n.add_child(ring(0.6, 1.1, surf("leather", Color.WHITE, 3.0), Vector3(2.6, 8.0, 0), Vector3(0, 0, -17)))
	return {"node": n}


func _weapon_spear_bronze(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var a := Vector3(-4, -8, 0)
	var b := Vector3(6, 18.5, 0)
	n.add_child(rod(a, b, 0.85, 0.8, surf("wood_grain", Color.WHITE, 8.0), false))
	var d := (b - a).normalized()
	var ang := atan2(d.y, d.x)
	var blade := slab([Vector2(0, -1.6), Vector2(6.5, 0), Vector2(0, 1.6), Vector2(-1.2, 0)], 0.8, surf("bronze", Color.WHITE, 3.0))
	blade.position = b
	blade.rotation.z = ang
	n.add_child(blade)
	n.add_child(ring(0.7, 1.15, surf("bronze", Color.WHITE, 3.0), b - d * 0.4, Vector3(0, 0, rad_to_deg(ang) - 90)))
	return {"node": n}


func _shield_bottlecap(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var face := Vector3(1.0, 0.1, 0.45).normalized()
	var holder := Node3D.new()
	holder.position = Vector3(3.0, 0.5, 1.5)
	holder.basis = Basis.looking_at(-face, Vector3.UP)   # local +z points along `face`
	n.add_child(holder)
	var iron := surf("iron", Color.WHITE, 4.0)
	var cap := CylinderMesh.new()
	cap.top_radius = 6.0
	cap.bottom_radius = 6.4
	cap.height = 1.6
	cap.radial_segments = 24
	var body := MeshInstance3D.new()
	body.mesh = cap
	body.material_override = iron
	body.rotation_degrees = Vector3(90, 0, 0)
	holder.add_child(body)
	for k in 21:   # the crimped rim
		var a := TAU * k / 21.0
		holder.add_child(blob(Vector3(0.75, 0.75, 0.9), iron, Vector3(cos(a) * 6.3, sin(a) * 6.3, 0.1)))
	var disc := CylinderMesh.new()
	disc.top_radius = 4.3
	disc.bottom_radius = 4.3
	disc.height = 0.3
	disc.radial_segments = 24
	var centre := MeshInstance3D.new()
	centre.mesh = disc
	centre.material_override = plain(c.team)
	centre.rotation_degrees = Vector3(90, 0, 0)
	centre.position = Vector3(0, 0, 0.85)
	holder.add_child(centre)
	holder.add_child(ring(4.2, 4.6, plain(c.team.darkened(0.4)), Vector3(0, 0, 0.9), Vector3(90, 0, 0)))
	return {"node": n}


# ------------------------------------------------------------------ spider (a mount)

func _body_spider(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var hair := surf("rat_fur", c.skin, 6.0)
	var front := surf("rat_fur", c.skin2, 5.0)
	n.add_child(blob(Vector3(11.5, 8.5, 9.5), hair, Vector3(-7, 13, 0), Vector3(0, 0, -8)))      # abdomen
	n.add_child(blob(Vector3(4.0, 1.2, 4.0), plain(c.cloth), Vector3(-10, 20.5, 0), Vector3(0, 0, -8)))   # marking
	n.add_child(blob(Vector3(6.5, 4.6, 5.8), front, Vector3(6, 11, 0)))                           # cephalothorax
	# A saddle with a team-colour cloth for the rider.
	n.add_child(blob(Vector3(6.5, 1.4, 6.8), plain(c.team), Vector3(-5, 21.2, 0), Vector3(0, 0, -6)))
	var hips := []
	var xs := [7.5, 4.5, 1.0, -2.5]
	var phases := [0.0, 0.8, 1.6, 2.4]
	for k in 4:
		hips.append([Vector3(xs[k], 10.5, 5.0), phases[k], 1, 1 if k >= 2 else 0])
		hips.append([Vector3(xs[k] + 0.5, 11.5, -5.0), phases[k] + PI, -1, 1 if k >= 2 else 0])
	harness(n, Vector3(-1.5, 12.5, 0), 6.0, 7.0, Vector3(0, 12, 7.0), Vector3(-1, 12, -7.0))
	return {"node": n, "sockets": {
		"head": Vector3(11, 11, 0), "hand_r": Vector3(0, 12, 7.6), "hand_l": Vector3(-1, 12, -7.6),
		"torso": Vector3(6, 12.5, 0), "back": Vector3(-8, 20, 0), "seat": Vector3(-5, 22.5, 0),
		"wings": Vector3(5, 16, 0)},
		"anchors": hips, "torso_scale": Vector2(0.6, 0.55), "carry": "harness"}


func _head_spider(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var hair := surf("rat_fur", c.skin2, 4.0)
	var head_c := Vector3(3, 1, 0)
	var head_r := Vector3(4.2, 3.6, 4.0)
	n.add_child(blob(head_r, hair, head_c))
	# Eight eyes: two big ones in front, six small ones around them.
	var eyes := [[Vector3(1, 0.45, 0.3), 1.3], [Vector3(1, 0.45, -0.3), 1.3], [Vector3(0.8, 0.8, 0.6), 0.8], [Vector3(0.8, 0.8, -0.6), 0.8],
		[Vector3(0.6, 1, 0.25), 0.7], [Vector3(0.6, 1, -0.25), 0.7], [Vector3(0.9, 0.2, 0.75), 0.6], [Vector3(0.9, 0.2, -0.75), 0.6]]
	for e in eyes:
		n.add_child(decal("rat_eye", e[1] * 2.0, e[1] * 2.0, on_surface(head_c, head_r, e[0], 0.05), e[0], false))
	for side in [1, -1]:   # fangs
		n.add_child(rod(Vector3(6.2, -0.5, 1.2 * side), Vector3(7.4, -3.2, 0.8 * side), 0.9, 0.35, plain(Color("#1e1612"))))
	return {"node": n, "sockets": {"top": Vector3(2, 4.5, 0)}}


## A hairy jointed leg: up and out to the knee, then down to a dark tip.
func _leg_spider(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var hair := surf("rat_fur", c.skin, 4.0)
	var knee := Vector3(6, 7, 1.5)
	var tip := Vector3(11, -10, 2.5)
	n.add_child(rod(Vector3.ZERO, knee, 1.4, 1.2, hair))
	n.add_child(rod(knee, knee.lerp(tip, 0.6), 1.2, 0.9, hair))
	n.add_child(rod(knee.lerp(tip, 0.6), tip, 0.9, 0.5, plain(c.skin.darkened(0.5))))
	return {"node": n}


# ------------------------------------------------------------------ more gear

func _weapon_cheese_hammer(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3(-1, -3.5, 0), Vector3(3, 10, 0), 0.8, 0.75, surf("wood_grain", Color.WHITE, 6.0)))
	var wedge := slab([Vector2(-3, 9.5), Vector2(8, 13.5), Vector2(8.5, 7.5), Vector2(-0.5, 5.5)], 4.5, surf("cheese", Color.WHITE, 5.0))
	n.add_child(wedge)
	n.add_child(blob(Vector3(1.2, 1.2, 0.6), plain(Color("#b0841a")), Vector3(3.5, 9.5, 2.3)))
	return {"node": n}


func _armour_mail(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(blob(Vector3(8.6, 8.2, 10.4), surf("mail", Color.WHITE, 2.5), Vector3(1.5, 0.5, 0), Vector3(0, 0, -10)))
	n.add_child(ring(9.0, 10.2, surf("iron", Color.WHITE, 3.0), Vector3(1.5, 6.0, 0), Vector3(0, 0, -10), Vector3(0.95, 1, 1.1)))
	return {"node": n}


func _weapon_sling(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var cord := surf("leather", c.cloth2, 2.0)
	# Whirled from the raised hand: two cords out to the pouch and its stone, swinging behind.
	n.add_child(rod(Vector3(0, 0, 0), Vector3(-6.5, 3.5, 0.6), 0.4, 0.4, cord))
	n.add_child(rod(Vector3(0.5, 0, 0), Vector3(-6.0, 4.5, -0.6), 0.4, 0.4, cord))
	n.add_child(blob(Vector3(1.9, 1.3, 1.5), cord, Vector3(-6.6, 4.3, 0)))
	n.add_child(blob(Vector3(1.5, 1.5, 1.5), surf("iron", Color("#b8b4a8"), 3.0), Vector3(-7.0, 5.0, 0)))
	return {"node": n}


func _weapon_crossbow(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(slab([Vector2(-5, -0.8), Vector2(10, 0.6), Vector2(10, 2.4), Vector2(-5, 1.4), Vector2(-6, -1.8)], 1.8, surf("wood_grain", Color.WHITE, 6.0)))
	var iron := surf("iron", Color.WHITE, 3.0)
	n.add_child(rod(Vector3(9, 1.5, 0), Vector3(7.5, 2.0, 7.0), 0.55, 0.4, iron))   # the bow arms
	n.add_child(rod(Vector3(9, 1.5, 0), Vector3(7.5, 2.0, -7.0), 0.55, 0.4, iron))
	n.add_child(rod(Vector3(7.5, 2.0, 7.0), Vector3(1.0, 1.6, 0), 0.12, 0.12, plain(Color("#e8e0c8")), false))
	n.add_child(rod(Vector3(7.5, 2.0, -7.0), Vector3(1.0, 1.6, 0), 0.12, 0.12, plain(Color("#e8e0c8")), false))
	n.add_child(rod(Vector3(1.0, 2.4, 0), Vector3(10.5, 2.6, 0), 0.25, 0.25, plain(Color("#6b4a2a")), false))   # a bolt
	return {"node": n}


## "Saucepan" helmet: an iron dome with a rolled brim (and the handle, of course).
func _helm_dome(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color.WHITE, 3.0)
	n.add_child(blob(Vector3(6.4, 4.4, 6.4), iron, Vector3(0, 0.5, 0)))
	n.add_child(ring(6.2, 7.4, iron, Vector3(0, 0.6, 0)))
	# A cooking pot's two loop handles at the sides (a long pan handle read as a stray line).
	for side in [1, -1]:
		n.add_child(ring(0.7, 1.4, iron, Vector3(-1.0, 1.6, 6.9 * side), Vector3(90, 0, 0)))
	return {"node": n}


func _weapon_blowgun(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	# Held at the lips (the hand is at the mouth end), pointing ahead and a little up.
	n.add_child(rod(Vector3(-2.5, -0.6, 0), Vector3(15, 2.6, 0), 1.0, 0.9, surf("reed_stalk", Color.WHITE, 5.0), false))
	n.add_child(ring(0.9, 1.4, surf("leather", Color.WHITE, 3.0), Vector3(0.6, 0, 0), Vector3(0, 0, -77)))   # the grip wrap
	n.add_child(blob(Vector3(0.6, 0.6, 0.6), plain(Color("#1a1a1a")), Vector3(15.2, 2.65, 0)))
	return {"node": n}


# ------------------------------------------------------------------ more shapes

## A truncated cone (r_top at the top), centred on `pos`.
func cone(r_top: float, r_bot: float, h: float, m: Material, pos: Vector3, rot := Vector3.ZERO, seg := 18) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	return mi


## The top half of an ellipsoid (helmets), its flat side at `pos`.
func dome(r: Vector3, m: Material, pos: Vector3) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 1.0
	s.is_hemisphere = true
	s.radial_segments = 28
	s.rings = 10
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = m
	mi.scale = r
	mi.position = pos
	return mi


## A node at `pos` whose local +z points along `face`: shields are built flat in its xy plane.
func facing(n: Node3D, pos: Vector3, face: Vector3) -> Node3D:
	var h := Node3D.new()
	h.position = pos
	h.basis = Basis.looking_at(-face.normalized(), Vector3.UP)
	n.add_child(h)
	return h


## A disc (flat cylinder) in a facing node's xy plane.
func disc(r: float, thick: float, m: Material, z: float) -> MeshInstance3D:
	var mi := cone(r, r, thick, m, Vector3(0, 0, z), Vector3(90, 0, 0), 28)
	return mi


## A blade or head flat in the xy plane, set at `at` and turned to angle `ang` (radians).
func blade(points: Array, thick: float, m: Material, at: Vector3, ang: float) -> MeshInstance3D:
	var b := slab(points, thick, m)
	b.position = at
	b.rotation.z = ang
	return b


## A horsehair crest along the helmet's ridge, tinted (team key, crimson).
func crest(n: Node3D, tint: Color, pos: Vector3, length: float, height: float) -> void:
	n.add_child(decal("plume", length, height, pos + Vector3(0, height * 0.5, 0), Vector3(0, 0, 1), true, Vector3.UP, tint))


# ------------------------------------------------------------------ human

func _body_human(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	# The tunic is the team colour, as the genre does; the culture shows in sleeves and trim.
	var tunic := surf("cloth", c.team, 6.0)
	var cloth := surf("cloth", c.cloth, 6.0)
	var skin := surf("skin", c.skin, 8.0)
	var belt := surf("leather", Color.WHITE, 3.0)
	# A belted tunic: chest and shoulders, a flared skirt over the hips.
	n.add_child(blob(Vector3(4.4, 5.8, 5.4), tunic, Vector3(0.3, 19.6, 0)))
	n.add_child(cone(4.3, 5.5, 4.6, tunic, Vector3(0, 12.9, 0)))
	n.add_child(ring(5.0, 5.7, cloth, Vector3(0, 10.75, 0)))   # hem trim in the culture's colour
	n.add_child(ring(4.2, 5.1, belt, Vector3(0, 15.0, 0)))
	n.add_child(blob(Vector3(1.0, 1.0, 0.5), surf("bronze", Color.WHITE, 2.0), Vector3(4.9, 15.0, 0.6)))
	n.add_child(rod(Vector3(0.3, 23.5, 0), Vector3(0.6, 27, 0), 1.8, 1.7, skin))
	var near_hand := Vector3.ZERO
	var front := Node3D.new()
	for side in [1, -1]:
		var into: Node3D = front if side == 1 else n
		var sh := Vector3(0.3, 23.2, 5.0 * side)
		var elbow := Vector3(1.4, 18.4, 6.4 * side)
		var hand := Vector3(6.0, 16.2, 5.6) if side == 1 else Vector3(5.5, 17.2, -4.8)
		if side == 1:
			var pose := arm_pose(sh, elbow, hand, Vector3(0.6, 27, 0))
			elbow = pose[0]
			hand = pose[1]
			near_hand = hand
		into.add_child(blob(Vector3(2.5, 2.4, 2.5), cloth, sh))
		into.add_child(rod(sh, elbow, 1.8, 1.55, cloth))
		into.add_child(rod(elbow, hand, 1.35, 1.15, skin))
		into.add_child(blob(Vector3(1.5, 1.6, 1.3), skin, hand))
	kerchief(front, c, Vector3(0.5, 24.6, 0), 2.6)
	return {"node": n, "front": front, "sockets": {
		"head": Vector3(0.6, 27, 0), "hand_r": near_hand, "hand_l": Vector3(5.5, 17.2, -4.8),
		"torso": Vector3(0.3, 17.8, 0), "back": Vector3(-4.2, 22, 0)},
		"anchors": [[Vector3(-2.3, 11.0, -2.4), 0.0, -1], [Vector3(2.0, 11.0, 2.4), PI, 1]],
		"torso_scale": Vector2(0.66, 0.82)}


func _head_human(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var skin := surf("skin", c.skin, 6.0)
	var hair := surf("mane", c.skin2.darkened(0.45), 3.0)
	var skull_c := Vector3(0.5, 5.2, 0)
	var skull_r := Vector3(4.4, 5.0, 4.2)
	n.add_child(blob(skull_r, skin, skull_c))
	n.add_child(blob(Vector3(3.2, 2.6, 3.3), skin, Vector3(1.6, 2.6, 0)))   # jaw
	n.add_child(blob(Vector3(1.0, 1.3, 0.8), skin, on_surface(skull_c, skull_r, Vector3(1, -0.1, 0), -0.2)))   # nose
	n.add_child(rod(Vector3(4.2, 2.2, -0.9), Vector3(4.3, 2.3, 0.9), 0.3, 0.3, plain(c.skin2.darkened(0.5))))   # mouth
	for side in [1, -1]:
		var look := Vector3(0.78, 0.12, 0.45 * side)
		n.add_child(decal("human_eye", 1.9, 1.9, on_surface(skull_c, skull_r, look, 0.05), look, false))
		n.add_child(blob(Vector3(0.8, 1.4, 0.6), skin, Vector3(-0.4, 5.0, 4.2 * side)))   # ears
	n.add_child(blob(Vector3(4.6, 3.0, 4.5), hair, Vector3(-0.3, 8.1, 0)))
	n.add_child(blob(Vector3(3.2, 3.8, 4.2), hair, Vector3(-1.6, 6.0, 0)))
	return {"node": n, "sockets": {"top": Vector3(0.3, 11.0, 0)}}


func _leg_human(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var cloth := surf("cloth", c.cloth2, 5.0)
	var boot := surf("leather", Color("#6a4a30"), 3.0)
	n.add_child(rod(Vector3(0, 0, 0), Vector3(0.7, -5.4, 0), 2.0, 1.6, cloth))
	n.add_child(rod(Vector3(0.7, -5.4, 0), Vector3(0.1, -9.4, 0), 1.5, 1.3, cloth))
	n.add_child(cone(1.35, 1.5, 1.8, boot, Vector3(0.2, -9.4, 0)))
	n.add_child(blob(Vector3(2.4, 1.1, 1.5), boot, Vector3(1.1, -10.3, 0)))
	return {"node": n}


# ------------------------------------------------------------------ pony (a mount; centaurs use the fused body)

const PONY_LIFT := 3.0   # longer legs than the 2D pony: ponies, not sheep


func _pony_barrel(n: Node3D, c: Dictionary) -> void:
	var hide := surf("hide", c.skin, 6.0)
	var mane := surf("mane", c.skin2.darkened(0.35), 3.0)
	n.add_child(blob(Vector3(10.5, 6.6, 6.0), hide, Vector3(0, 19, 0)))
	n.add_child(blob(Vector3(5.6, 6.6, 5.6), hide, Vector3(8.0, 19.6, 0)))    # chest
	n.add_child(blob(Vector3(6.4, 7.0, 6.0), hide, Vector3(-8.5, 20.2, 0)))   # rump
	var tail := [Vector3(-14, 23, 0), Vector3(-17, 19.5, 0.5), Vector3(-18.6, 14, 1.0), Vector3(-18.2, 9, 1.2)]
	var r := [2.2, 2.1, 1.7, 1.0]
	for k in range(1, tail.size()):
		n.add_child(rod(tail[k - 1], tail[k], r[k - 1], r[k], mane))


## Bodies with no arms carry their gear on a harness: a leather girth strap round the
## body, a holder sleeve on the near flank where the weapon is couched (UnitView lays
## it forward, like a lance in its rest), and a strap pad on the far flank for a shield.
## `ry`, `rz`: the girth's radii (up and across) around `centre`.
func harness(n: Node3D, centre: Vector3, ry: float, rz: float, hand_r: Vector3, hand_l: Vector3) -> void:
	var leather := surf("leather", Color.WHITE, 3.0)
	var dark := surf("leather", Color(0.55, 0.42, 0.32), 2.0)
	n.add_child(ring(0.86, 1.0, leather, centre, Vector3(0, 0, 90), Vector3(ry, 1.6, rz)))   # the girth, across the back and belly
	n.add_child(rod(hand_r + Vector3(-1.6, -0.6, 0.6), hand_r + Vector3(1.6, 0.6, 0.6), 1.15, 1.15, dark))   # the holder
	n.add_child(blob(Vector3(0.7, 0.7, 0.5), surf("bronze", Color.WHITE, 2.0), hand_r + Vector3(0, 0, 1.6)))   # its buckle
	n.add_child(blob(Vector3(2.2, 2.6, 0.8), dark, hand_l))   # the shield pad


func _pony_anchors() -> Array:
	var y := 14.0 + PONY_LIFT
	return [[Vector3(8.5, y, 4.0), 0.0, 1, 0], [Vector3(-9.5, y, 4.0), PI, 1, 0],
		[Vector3(7.0, y, -4.0), PI, -1, 0], [Vector3(-11.0, y, -4.0), 0.0, -1, 0]]


func _body_pony(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var lift := Node3D.new()
	lift.position.y = PONY_LIFT
	n.add_child(lift)
	_pony_barrel(lift, c)
	var hide := surf("hide", c.skin, 6.0)
	lift.add_child(rod(Vector3(8.5, 22, 0), Vector3(14.6, 31.5, 0), 4.4, 3.1, hide))   # neck, arched up
	lift.add_child(rod(Vector3(6.4, 24.0, 0), Vector3(12.4, 33.4, 0), 2.1, 1.7, surf("mane", c.skin2.darkened(0.35), 3.0)))
	harness(lift, Vector3(4, 19, 0), 7.0, 6.3, Vector3(3, 18, 6.4), Vector3(3, 18, -6.4))
	return {"node": n, "sockets": _lifted({
		"head": Vector3(15.0, 32.5, 0), "hand_r": Vector3(3, 18, 6.9), "hand_l": Vector3(3, 18, -6.9),
		"torso": Vector3(0, 19, 0), "back": Vector3(-8, 24, 0), "seat": Vector3(-1, 25.8, 0),
		"wings": Vector3(7.5, 25.5, 0)}),
		"anchors": _pony_anchors(), "torso_scale": Vector2(1.3, 1.0), "carry": "harness"}


func _lifted(sockets: Dictionary) -> Dictionary:
	for k in sockets:
		sockets[k] += Vector3(0, PONY_LIFT, 0)
	return sockets


## A centaur's horse half: no neck; the rider's torso stands where it would be.
func _body_pony_fused(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var lift := Node3D.new()
	lift.position.y = PONY_LIFT
	n.add_child(lift)
	_pony_barrel(lift, c)
	return {"node": n, "sockets": _lifted({
		"head": Vector3(14.6, 31.5, 0), "hand_r": Vector3(10, 18, 4), "hand_l": Vector3(8, 18, -4),
		"torso": Vector3(0, 19, 0), "back": Vector3(-8, 24, 0), "seat": Vector3(7.5, 15.5, 0)}),
		"anchors": _pony_anchors(), "torso_scale": Vector2(1.3, 1.0)}


func _head_pony(c: Dictionary) -> Dictionary:
	var root := Node3D.new()
	var n := Node3D.new()
	n.scale = Vector3.ONE * 1.25
	root.add_child(n)
	var hide := surf("hide", c.skin, 5.0)
	var a := Vector3(0.5, 0.5, 0)
	var b := Vector3(7.5, -3.5, 0)
	n.add_child(rod(a, b, 2.9, 1.9, hide))
	n.add_child(blob(Vector3(3.0, 3.0, 2.4), hide, Vector3(1.6, -0.4, 0)))   # cheek
	n.add_child(blob(Vector3(2.2, 1.9, 1.9), surf("hide", c.skin.darkened(0.15), 4.0), Vector3(7.6, -3.6, 0)))
	for side in [1, -1]:
		n.add_child(blob(Vector3(0.5, 0.45, 0.4), plain(Color("#1a1210")), Vector3(9.4, -3.3, 0.9 * side)))
		n.add_child(decal("rat_eye", 1.7, 1.7, Vector3(2.3, 0.9, 2.45 * side), Vector3(0.3, 0.3, side), false))
		n.add_child(cone(0.0, 0.85, 2.8, hide, Vector3(-0.2, 2.8, 1.2 * side), Vector3(-12 * side, 0, 8)))
	n.add_child(blob(Vector3(1.3, 1.7, 1.4), surf("mane", c.skin2, 3.0), Vector3(1.4, 1.8, 0)))   # forelock
	var ang := rad_to_deg(atan2(b.y - a.y, b.x - a.x)) - 90.0
	n.add_child(ring(1.9, 2.4, surf("leather", Color.WHITE, 3.0), Vector3(6.0, -2.7, 0), Vector3(0, 0, ang)))
	n.add_child(ring(2.5, 3.0, plain(c.team), Vector3(1.4, 0.4, 0), Vector3(0, 0, ang)))   # browband
	return {"node": root, "sockets": {"top": Vector3(0.5, 2.6, 0) * 1.25}}


func _leg_hoof(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var hide := surf("hide", c.skin, 5.0)
	n.add_child(blob(Vector3(2.6, 4.2, 2.4), hide, Vector3(0, -2.8, 0)))
	n.add_child(rod(Vector3(0, -5.5, 0), Vector3(0.2, -13.6, 0), 1.15, 0.95, hide))
	n.add_child(blob(Vector3(1.3, 1.2, 1.2), hide, Vector3(0.3, -13.8, 0)))
	n.add_child(rod(Vector3(0.3, -13.8, 0), Vector3(0.8, -14.8, 0), 1.0, 1.0, hide))
	n.add_child(cone(1.1, 1.6, 1.4, plain(Color("#2a2420")), Vector3(1.0, -15.4, 0)))
	return {"node": n}


# ------------------------------------------------------------------ capybara (the rats' mount, RB1)
# The rats' "big cousin" (Dominic's pick): a barrel of a body on short legs, a blunt square
# head with tiny ears, a tea towel for a saddle with the team's stripe across it.

func _body_capybara(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", c.skin, 5.0)
	n.add_child(blob(Vector3(13.0, 8.0, 8.5), fur, Vector3(0, 13, 0)))
	n.add_child(blob(Vector3(6.0, 4.0, 6.4), surf("rat_fur", c.skin.lightened(0.12), 4.0), Vector3(3, 9.5, 0)))   # a paler belly
	n.add_child(blob(Vector3(4.6, 5.0, 4.8), fur, Vector3(-11.0, 13.5, 0)))   # the round rump
	n.add_child(_box(Vector3(9.0, 0.9, 13.0), plain(Color("#e8e0d0")), Vector3(-1, 20.9, 0)))   # the tea-towel saddle
	n.add_child(_box(Vector3(9.2, 1.0, 2.4), plain(c.team), Vector3(-1, 21.0, 0)))              # its team stripe
	for side in [1, -1]:
		n.add_child(_box(Vector3(9.0, 4.0, 0.5), plain(Color("#e8e0d0")), Vector3(-1, 18.6, 6.6 * side), Vector3(10 * side, 0, 0)))   # hanging down the flanks
	return {"node": n, "sockets": {
		"head": Vector3(12.5, 17.5, 0), "hand_r": Vector3(4, 16, 7.6), "hand_l": Vector3(3, 16, -7.6),
		"torso": Vector3(0, 14, 0), "back": Vector3(-8, 20, 0), "seat": Vector3(-1, 22.5, 0), "wings": Vector3(6, 20, 0)},
		"anchors": [[Vector3(8.0, 7.5, 5.0), 0.0, 1, 0], [Vector3(-8.0, 7.5, 5.2), PI, 1, 0],
			[Vector3(7.0, 7.5, -5.0), PI, -1, 0], [Vector3(-9.0, 7.5, -5.2), 0.0, -1, 0]],
		"torso_scale": Vector2(1.4, 0.9), "carry": "harness"}


func _head_capybara(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", c.skin, 5.0)
	n.add_child(_box(Vector3(8.5, 6.0, 6.0), fur, Vector3(3.5, 0, 0), Vector3(0, 0, -14)))   # the blunt square head
	n.add_child(_box(Vector3(2.0, 3.6, 5.0), surf("rat_fur", c.skin.darkened(0.4), 4.0), Vector3(7.6, -1.4, 0), Vector3(0, 0, -14)))   # its flat nose
	for side in [1, -1]:
		n.add_child(blob(Vector3(0.9, 1.0, 0.7), fur, Vector3(-0.4, 3.4, 2.5 * side)))   # tiny ears
		n.add_child(blob(Vector3(0.5, 0.5, 0.45), plain(INK), Vector3(3.4, 1.8, 3.0 * side)))
	return {"node": n, "sockets": {"top": Vector3(1, 3.2, 0)}}


func _leg_capybara(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", c.skin, 5.0)
	n.add_child(rod(Vector3.ZERO, Vector3(0.4, -6.4, 0), 2.4, 1.9, fur))
	n.add_child(blob(Vector3(2.4, 0.9, 1.8), surf("rat_fur", c.skin.darkened(0.45), 3.0), Vector3(1.0, -7.0, 0)))   # a broad dark foot
	return {"node": n}


# ------------------------------------------------------------------ animals (milestone 11)
# Wild and herded animals: deer to hunt (they bolt), boar (they fight back), sheep to herd.
# skin = coat, skin2 = the darker parts (muzzle, hooves, a deer's white tail).

func _four_legs(front: float, back: float, y: float, z: float) -> Array:
	return [[Vector3(front, y, z), 0.0, 1, 0], [Vector3(back, y, z), PI, 1, 0],
		[Vector3(front - 1.0, y, -z), PI, -1, 0], [Vector3(back - 1.0, y, -z), 0.0, -1, 0]]


func _body_deer(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var coat := surf("hide", c.skin, 5.0)
	n.add_child(blob(Vector3(9.0, 5.2, 4.4), coat, Vector3(0, 17, 0)))
	n.add_child(blob(Vector3(4.5, 2.4, 3.6), surf("hide", c.skin.lightened(0.35), 4.0), Vector3(1, 13.6, 0)))   # pale belly
	n.add_child(rod(Vector3(6.5, 18.5, 0), Vector3(10.5, 25, 0), 2.4, 1.7, coat))   # the neck, up
	n.add_child(blob(Vector3(1.6, 1.9, 1.2), plain(Color("#f2ece0")), Vector3(-9.0, 18.6, 0)))   # a white tail
	return {"node": n, "sockets": {"head": Vector3(10.8, 25.5, 0), "torso": Vector3(0, 17, 0), "back": Vector3(-5, 21, 0)},
		"anchors": _four_legs(6.0, -6.5, 13.5, 2.6), "carry": "harness"}


func _head_deer(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var coat := surf("hide", c.skin, 5.0)
	n.add_child(blob(Vector3(2.4, 2.1, 1.9), coat, Vector3(0.6, 0.5, 0)))
	n.add_child(rod(Vector3(1.5, 0.3, 0), Vector3(5.2, -1.6, 0), 1.5, 0.8, coat))   # the long face
	n.add_child(blob(Vector3(0.7, 0.6, 0.7), plain(INK), Vector3(5.3, -1.6, 0)))
	var antler := plain(Color("#d8c8a4"))
	for side in [1, -1]:
		n.add_child(blob(Vector3(0.5, 1.3, 0.7), coat, Vector3(-0.6, 2.4, 1.6 * side), Vector3(0, 0, -20)))   # ears
		n.add_child(blob(Vector3(0.45, 0.45, 0.4), plain(INK), Vector3(2.0, 1.2, 1.5 * side)))
		var base := Vector3(0.2, 2.2, 0.8 * side)
		var tip := base + Vector3(-1.0, 5.5, 2.2 * side)
		n.add_child(rod(base, tip, 0.35, 0.18, antler))
		n.add_child(rod(base.lerp(tip, 0.45), base.lerp(tip, 0.45) + Vector3(1.8, 1.6, 0.4 * side), 0.25, 0.12, antler))
		n.add_child(rod(base.lerp(tip, 0.75), base.lerp(tip, 0.75) + Vector3(1.5, 1.4, 0.2 * side), 0.22, 0.1, antler))
	return {"node": n, "sockets": {"top": Vector3(0, 2.5, 0)}}


func _leg_deer(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var coat := surf("hide", c.skin, 4.0)
	n.add_child(rod(Vector3.ZERO, Vector3(0.3, -7.0, 0), 1.2, 0.6, coat))
	n.add_child(rod(Vector3(0.3, -7.0, 0), Vector3(0.6, -13.0, 0), 0.55, 0.45, coat))
	n.add_child(blob(Vector3(0.7, 0.6, 0.6), plain(c.skin2), Vector3(0.8, -13.3, 0)))
	return {"node": n}


func _body_boar(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var hide := surf("hide", c.skin, 5.0)
	n.add_child(blob(Vector3(9.5, 6.4, 5.6), hide, Vector3(0, 11, 0)))
	n.add_child(blob(Vector3(5.5, 5.0, 4.6), hide, Vector3(5.5, 12.5, 0)))   # the heavy shoulders
	var bristle := plain(c.skin2)
	for k in 8:   # a crest of bristles down the back
		var x := 7.0 - k * 1.9
		n.add_child(rod(Vector3(x, 16.5 - absf(x - 3.0) * 0.18, 0), Vector3(x - 0.9, 19.0 - absf(x - 3.0) * 0.2, 0), 0.5, 0.15, bristle, false))
	n.add_child(rod(Vector3(-9, 12, 0), Vector3(-11, 9, 0), 0.4, 0.2, hide))   # the tail
	return {"node": n, "sockets": {"head": Vector3(10.5, 11.5, 0), "torso": Vector3(0, 11, 0), "back": Vector3(-4, 16, 0)},
		"anchors": _four_legs(5.5, -6.0, 7.5, 3.4), "carry": "harness"}


func _head_boar(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var hide := surf("hide", c.skin, 5.0)
	n.add_child(rod(Vector3(-0.5, 0.5, 0), Vector3(5.5, -1.5, 0), 3.0, 1.6, hide))   # the long head, low
	n.add_child(blob(Vector3(0.9, 1.4, 1.5), plain(Color("#b08070")), Vector3(5.9, -1.6, 0)))   # the snout disc
	var tusk := plain(Color("#f2ead6"))
	for side in [1, -1]:
		n.add_child(rod(Vector3(4.6, -2.4, 1.2 * side), Vector3(5.2, -0.4, 2.0 * side), 0.35, 0.12, tusk))
		n.add_child(blob(Vector3(0.4, 0.4, 0.4), plain(INK), Vector3(2.6, 1.0, 1.9 * side)))
		n.add_child(blob(Vector3(0.6, 1.2, 0.5), hide, Vector3(0.4, 2.6, 1.8 * side), Vector3(0, 0, -25)))
	return {"node": n, "sockets": {"top": Vector3(0, 2.5, 0)}}


func _leg_boar(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3.ZERO, Vector3(0.3, -6.6, 0), 1.6, 0.9, surf("hide", c.skin, 4.0)))
	n.add_child(blob(Vector3(0.9, 0.6, 0.8), plain(c.skin2), Vector3(0.5, -7.0, 0)))
	return {"node": n}


func _body_sheep(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var wool := surf("felt", c.skin, 2.0)
	var shade := surf("felt", c.skin.darkened(0.22), 2.0)   # curls in shadow, so the fleece has texture
	# One smooth oval of fleece, deep and round, with soft curls on its surface (not a heap of
	# lumps), sitting low on short dark legs; a small tail tuft.
	n.add_child(blob(Vector3(7.5, 5.0, 4.6), wool, Vector3(-0.5, 10.5, 0)))
	n.add_child(blob(Vector3(4.2, 3.6, 4.0), wool, Vector3(4.0, 11.0, 0)))   # the chest, full
	var rng := RandomNumberGenerator.new()   # seeded: the same fleece every bake
	rng.seed = 31
	for k in 22:
		var a := rng.randf() * TAU
		var up := rng.randf_range(-0.2, 1.0)
		var p := Vector3(rng.randf_range(-7.0, 6.0), 10.5 + up * 4.3, cos(a) * 4.2 * sqrt(1.0 - up * up * 0.5))
		n.add_child(blob(Vector3(1.4, 1.1, 1.3), wool if k % 3 else shade, p))
	n.add_child(blob(Vector3(1.4, 1.6, 1.3), wool, Vector3(-8.0, 11.5, 0)))   # the tail tuft
	return {"node": n, "sockets": {"head": Vector3(8.0, 12.5, 0), "torso": Vector3(0, 10.5, 0), "back": Vector3(-3, 14, 0)},
		"anchors": _four_legs(4.5, -4.5, 7.0, 2.4), "carry": "harness"}


func _head_sheep(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var face := surf("hide", c.skin2, 4.0)
	n.add_child(blob(Vector3(1.8, 1.4, 1.6), surf("felt", c.skin, 2.0), Vector3(-0.4, 1.2, 0)))   # the poll of wool
	n.add_child(blob(Vector3(2.6, 1.7, 1.5), face, Vector3(1.6, -0.6, 0), Vector3(0, 0, -25)))   # the long dark face, nose down
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.5, 0.4, 0.7), face, Vector3(0.0, 0.4, 1.9 * side), Vector3(0, 25 * side, -10)))   # ears out sideways
		n.add_child(blob(Vector3(0.3, 0.3, 0.3), plain(Color("#d8c8a0")), Vector3(1.2, 0.0, 1.1 * side)))   # pale eyes on the dark face
	return {"node": n, "sockets": {"top": Vector3(0, 2, 0)}}


func _leg_sheep(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3.ZERO, Vector3(0.2, -6.6, 0), 0.8, 0.6, surf("hide", c.skin2, 4.0)))
	n.add_child(blob(Vector3(0.7, 0.45, 0.6), plain(c.skin2.darkened(0.3)), Vector3(0.4, -6.8, 0)))   # a hoof
	return {"node": n}


# ------------------------------------------------------------------ beetle soldier (rearing, BG1)
# Dominic's pick: wing cases low behind on four legs, the pronotum up like a chest, the front
# pair as arms that hold the weapon. Stag beetles rear like this to fight. Ridden beetles keep
# the horizontal mount body below.

func _body_beetle_rear(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var shell := surf("chitin", c.skin, 5.0)
	var plate := surf("chitin", c.skin2, 4.0)
	var limb := surf("chitin", c.skin.darkened(0.45), 3.0)
	for side in [1, -1]:   # the wing cases, low and behind, meeting at a seam
		n.add_child(blob(Vector3(8.0, 4.6, 3.4), shell, Vector3(-4.5, 9.5, 2.3 * side), Vector3(0, 0, 12)))
	n.add_child(rod(Vector3(-11.5, 8.0, 0), Vector3(1.5, 12.5, 0), 0.35, 0.35, plain(c.skin.darkened(0.6)), false))
	n.add_child(blob(Vector3(4.2, 7.0, 5.4), plate, Vector3(2.5, 16, 0), Vector3(0, 0, -18)))   # pronotum, up like a chest
	n.add_child(blob(Vector3(4.0, 1.0, 5.6), plain(c.team), Vector3(-4.5, 14.0, 0), Vector3(0, 0, 12)))   # a team band across the wing cases
	var front := Node3D.new()
	var hand_r := Vector3(7.5, 13.5, 5.6)
	var pose := arm_pose(Vector3(3.5, 18, 4), Vector3(6, 15.5, 6), hand_r, Vector3(4, 22.5, 0))
	front.add_child(rod(Vector3(3.5, 18, 4), pose[0], 0.95, 0.8, limb))
	front.add_child(rod(pose[0], pose[1], 0.8, 0.6, limb))
	n.add_child(rod(Vector3(3.5, 18, -4), Vector3(6.5, 14.5, -6), 0.95, 0.75, limb))   # the far arm
	return {"node": n, "front": front, "sockets": {"head": Vector3(4, 22.5, 0), "hand_r": pose[1], "hand_l": Vector3(6.5, 14.5, -6),
		"torso": Vector3(2.5, 16, 0), "back": Vector3(-6, 14, 0)},
		"anchors": [[Vector3(0.5, 8.0, 3.2), 0.0, 1, 0], [Vector3(-6.0, 8.0, 3.2), PI, 1, 1],
			[Vector3(0.5, 8.0, -3.2), PI, -1, 0], [Vector3(-6.0, 8.0, -3.2), 0.0, -1, 1]],
		"torso_scale": Vector2(0.55, 0.65)}


# ------------------------------------------------------------------ beetle (a mount)

func _body_beetle(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var shell := surf("chitin", c.skin, 5.0)
	var plate := surf("chitin", c.skin2, 4.0)
	var under := plain(c.skin.darkened(0.55))
	n.add_child(blob(Vector3(13.5, 4.0, 7.6), under, Vector3(0, 9.6, 0)))
	for side in [1, -1]:   # the two wing cases, meeting at a seam
		n.add_child(blob(Vector3(14.0, 6.8, 4.6), shell, Vector3(-2.5, 13.5, 3.0 * side)))
	n.add_child(rod(Vector3(-15.5, 14.5, 0), Vector3(10, 19.4, 0), 0.45, 0.45, plain(c.skin.darkened(0.6)), false))
	n.add_child(blob(Vector3(5.6, 5.4, 7.4), plate, Vector3(11.0, 13.0, 0)))   # pronotum
	# A team-colour cloth over the back (a saddle blanket when ridden).
	n.add_child(blob(Vector3(5.0, 1.2, 6.6), plain(c.team), Vector3(-1.5, 20.0, 0), Vector3(0, 0, -6)))
	var hips := [[Vector3(10, 9.5, 6.0), 0.0, 1, 0], [Vector3(2, 9.5, 6.5), 2.1, 1, 0], [Vector3(-7, 9.5, 6.0), 4.2, 1, 1],
		[Vector3(11, 10, -6.0), 3.14, -1, 0], [Vector3(3, 10, -6.5), 5.2, -1, 0], [Vector3(-6, 10, -6.0), 1.0, -1, 1]]
	harness(n, Vector3(4, 13.5, 0), 7.2, 8.0, Vector3(4, 13.5, 8.0), Vector3(3, 13.5, -8.0))
	return {"node": n, "sockets": {
		"head": Vector3(16, 12.5, 0), "hand_r": Vector3(4, 13.5, 8.6), "hand_l": Vector3(3, 13.5, -8.6),
		"torso": Vector3(11, 14, 0), "back": Vector3(-8, 19, 0), "seat": Vector3(-1.5, 21.5, 0),
		"wings": Vector3(6, 19.5, 0)},
		"anchors": hips, "torso_scale": Vector2(0.65, 0.6), "carry": "harness"}


func _head_beetle(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var shell := surf("chitin", c.skin, 4.0)
	var horn := surf("chitin", c.skin2, 3.0)
	n.add_child(blob(Vector3(4.6, 3.6, 4.4), shell, Vector3(2.5, 0, 0)))
	var pts := [Vector3(5.5, 1.0, 0), Vector3(9.5, 3.5, 0), Vector3(12, 8, 0), Vector3(12.6, 12, 0)]
	var r := [2.0, 1.5, 1.0, 0.4]
	for k in range(1, pts.size()):
		n.add_child(rod(pts[k - 1], pts[k], r[k - 1], r[k], horn))
	n.add_child(rod(Vector3(10.6, 5.5, 0), Vector3(13.4, 6.5, 0), 0.6, 0.3, horn))   # a tine
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.1, 1.1, 0.8), plain(Color("#141018")), Vector3(4.6, 0.8, 3.3 * side)))
		n.add_child(blob(Vector3(0.4, 0.4, 0.3), plain(Color("#c8c0d8")), Vector3(5.0, 1.2, 3.8 * side)))
		n.add_child(rod(Vector3(6.2, -1.0, 2.0 * side), Vector3(9.0, -0.5, 4.2 * side), 0.25, 0.2, plain(c.skin.darkened(0.5))))
		n.add_child(blob(Vector3(0.7, 0.45, 0.7), plain(c.skin.darkened(0.5)), Vector3(9.2, -0.5, 4.3 * side)))
	return {"node": n, "sockets": {"top": Vector3(2, 3.6, 0)}}


func _leg_insect(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var shell := surf("chitin", c.skin.darkened(0.45), 3.0)
	var knee := Vector3(4, -1.8, 2.0)
	var foot := Vector3(6.2, -8.2, 3.0)
	n.add_child(rod(Vector3.ZERO, knee, 1.3, 1.0, shell))
	n.add_child(rod(knee, foot, 0.9, 0.6, shell))
	n.add_child(rod(foot, foot + Vector3(1.8, -0.4, 0.3), 0.45, 0.3, shell))
	return {"node": n}


# ------------------------------------------------------------------ weapons

## A pole arm: shaft from a to b, and a flat head past b.
func _pole(n: Node3D, a: Vector3, b: Vector3, r: float, head: Array, head_mat: Material) -> Vector3:
	n.add_child(rod(a, b, r, r * 0.95, surf("wood_grain", Color.WHITE, 8.0), false))
	var d := (b - a).normalized()
	n.add_child(blade(head, 0.8, head_mat, b, atan2(d.y, d.x)))
	n.add_child(ring(r * 0.8, r * 1.4, head_mat, b - d * 0.4, Vector3(0, 0, rad_to_deg(atan2(d.y, d.x)) - 90)))
	return d


func _weapon_pike_iron(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	_pole(n, Vector3(5, -5, 0), Vector3(-13, 27, 0), 0.85, [Vector2(0, -1.3), Vector2(8, 0), Vector2(0, 1.3), Vector2(-1, 0)], surf("iron", Color.WHITE, 3.0))
	return {"node": n}


func _weapon_dory(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bronze := surf("bronze", Color.WHITE, 3.0)
	var d := _pole(n, Vector3(-8, -5, 0), Vector3(20, 11, 0), 0.85, [Vector2(0, -1.8), Vector2(3, -1.6), Vector2(7, 0), Vector2(3, 1.6), Vector2(0, 1.8), Vector2(-1.2, 0)], bronze)
	n.add_child(rod(Vector3(-8, -5, 0), Vector3(-8, -5, 0) - d * 3.0, 0.9, 0.3, bronze))   # the butt spike
	return {"node": n}


func _weapon_pilum(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color.WHITE, 3.0)
	var a := Vector3(-7, -4.5, 0)   # gripped at its balance: raised over the shoulder, ready to throw
	var b := Vector3(6, 3.5, 0)
	n.add_child(rod(a, b, 0.8, 0.8, surf("wood_grain", Color.WHITE, 6.0), false))
	var d := (b - a).normalized()
	var tip := b + d * 6.0
	n.add_child(rod(b, tip, 0.4, 0.35, iron, false))
	n.add_child(blob(Vector3(1.2, 1.0, 1.0), surf("wood_grain", Color("#b08050"), 3.0), b))
	n.add_child(blade([Vector2(0, -0.8), Vector2(2.2, 0), Vector2(0, 0.8)], 0.8, iron, tip, atan2(d.y, d.x)))
	return {"node": n}


func _weapon_lance(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var a := Vector3(-10, -2, 0)
	var b := Vector3(26, 4, 0)
	var d := (b - a).normalized()
	var ang := atan2(d.y, d.x)
	n.add_child(rod(a, b, 1.3, 0.7, surf("wood_grain", Color.WHITE, 8.0), false))
	n.add_child(cone(0.9, 3.0, 2.4, surf("iron", Color.WHITE, 3.0), a + d * 12.0, Vector3(0, 0, rad_to_deg(ang) + 90)))   # vamplate
	n.add_child(blade([Vector2(0, -0.9), Vector2(5, 0), Vector2(0, 0.9)], 1.0, surf("iron", Color.WHITE, 3.0), b, ang))
	n.add_child(blade([Vector2(0, 0), Vector2(-6.5, -0.6), Vector2(-4.5, -2.0), Vector2(-6.5, -3.6), Vector2(-0.5, -3.4)], 0.3, surf("cloth", c.team, 4.0), b - d * 2.5, ang))   # pennon
	return {"node": n}


func _weapon_club_bone(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bone := surf("bone", Color.WHITE, 4.0)
	n.add_child(rod(Vector3(-2, -2, 0), Vector3(6, 8.5, 0), 1.2, 1.8, bone))
	n.add_child(blob(Vector3(3.0, 3.2, 2.8), bone, Vector3(6.6, 10, 0)))
	for k in 3:
		n.add_child(blob(Vector3(1.0, 1.0, 1.0), bone, Vector3(6.6, 10, 0) + Vector3(cos(k * 2.1), sin(k * 2.1), 0.6) * 2.8))
	n.add_child(ring(1.2, 1.8, surf("leather", Color.WHITE, 3.0), Vector3(-0.8, -0.4, 0), Vector3(0, 0, -36)))
	return {"node": n}


## A sword: blade outline along +x before turning, a guard across it, grip and pommel.
func _sword(blade_pts: Array, tip: Vector3, metal: Material, fittings: Material) -> Node3D:
	var n := Node3D.new()
	var d := tip.normalized()
	var ang := atan2(d.y, d.x)
	n.add_child(blade(blade_pts, 0.6, metal, Vector3.ZERO, ang))
	var across := Vector3(-d.y, d.x, 0)
	n.add_child(rod(-across * 3.0 + Vector3(0, 0, 0.6), across * 3.0 - Vector3(0, 0, 0.6), 0.55, 0.55, fittings))
	n.add_child(rod(Vector3.ZERO, -d * 3.0, 0.6, 0.6, surf("leather", Color.WHITE, 2.0), false))
	n.add_child(blob(Vector3(0.9, 0.9, 0.9), fittings, -d * 3.6))
	return n


func _weapon_sword_bronze(c: Dictionary) -> Dictionary:
	var bronze := surf("bronze", Color.WHITE, 3.0)
	return {"node": _sword([Vector2(0, -1.0), Vector2(8, -1.5), Vector2(14.4, 0), Vector2(8, 1.5), Vector2(0, 1.0)], Vector3(3, 14, 0), bronze, surf("wood_grain", Color.WHITE, 3.0))}


func _weapon_sword_iron(c: Dictionary) -> Dictionary:
	var iron := surf("iron", Color.WHITE, 3.0)
	return {"node": _sword([Vector2(0, -1.1), Vector2(13.5, -0.9), Vector2(15.4, 0), Vector2(13.5, 0.9), Vector2(0, 1.1)], Vector3(3, 15, 0), iron, iron)}


func _weapon_gladius(c: Dictionary) -> Dictionary:
	return {"node": _sword([Vector2(0, -1.4), Vector2(5, -1.2), Vector2(8.5, -1.4), Vector2(11.2, 0), Vector2(8.5, 1.4), Vector2(5, 1.2), Vector2(0, 1.4)],
		Vector3(2, 11, 0), surf("iron", Color.WHITE, 3.0), surf("bronze", Color.WHITE, 2.0))}


func _weapon_bow_short(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	# Pale wood, thick limbs and a bright string: it has to stand out against dark armour
	# (a dark bow vanished, and testers called the archer a spearman).
	var wood := surf("wood_grain", Color("#e8c48a"), 4.0)
	# Held out at its leather grip (the origin), the string drawn back towards the face.
	var g := Vector3(5.7, 0, 0)
	var pts := [Vector3(3.8, -13.6, 0), Vector3(2, -12, 0), Vector3(5.5, -6, 0), Vector3(6.6, 0, 0), Vector3(5.5, 6, 0), Vector3(2, 12, 0), Vector3(3.8, 13.6, 0)]
	for k in range(1, pts.size()):
		var r := 1.15 if k in [3, 4] else 0.85
		n.add_child(rod(pts[k - 1] - g, pts[k] - g, r, r, wood))
	var nock := Vector3(-3.5, 0, 0) - g
	n.add_child(rod(Vector3(2, -12, 0) - g, nock, 0.25, 0.25, plain(Color("#f8f2e0")), false))
	n.add_child(rod(nock, Vector3(2, 12, 0) - g, 0.25, 0.25, plain(Color("#f8f2e0")), false))
	n.add_child(rod(nock, Vector3(9, 0, 0) - g, 0.3, 0.3, surf("wood_grain", Color.WHITE, 2.0), false))   # the arrow
	n.add_child(cone(1.05, 1.05, 2.4, surf("leather", Color.WHITE, 2.0), Vector3.ZERO, Vector3(0, 0, 8)))
	return {"node": n}


func _weapon_musket(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(slab([Vector2(-5, -2.2), Vector2(-4, 0.6), Vector2(14, 3.6), Vector2(14, 2.0), Vector2(-1, -0.6), Vector2(-2, -2.6)], 1.6, surf("wood_grain", Color.WHITE, 5.0)))
	var iron := surf("iron", Color.WHITE, 3.0)
	n.add_child(rod(Vector3(5, 2.4, 0), Vector3(19.5, 5.3, 0), 0.75, 0.7, iron, false))
	n.add_child(ring(0.7, 1.0, iron, Vector3(18.6, 5.1, 0), Vector3(0, 0, -79)))
	n.add_child(blob(Vector3(1.2, 0.8, 0.9), iron, Vector3(3.5, 2.0, 0.6)))   # the lock
	return {"node": n}


func _tool_sack(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var sack := surf("cloth", c.cloth2.lerp(Color("#c8b48a"), 0.55), 3.0)
	n.add_child(blob(Vector3(3.8, 4.6, 3.4), sack, Vector3(0, -2.6, 0)))
	n.add_child(cone(0.9, 2.0, 1.8, sack, Vector3(0, 2.0, 0)))
	n.add_child(ring(0.8, 1.3, surf("leather", Color.WHITE, 2.0), Vector3(0, 2.2, 0)))
	n.add_child(blob(Vector3(1.4, 0.9, 1.3), sack, Vector3(0, 3.3, 0)))
	return {"node": n}


# ------------------------------------------------------------------ shields

const SHIELD_FACE := Vector3(1.0, 0.1, 0.45)


func _shield_round(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var h := facing(n, Vector3(3.0, 0.5, 1.5), SHIELD_FACE)
	var iron := surf("iron", Color.WHITE, 3.0)
	h.add_child(disc(6.0, 1.0, surf("wood_grain", Color.WHITE, 4.0), 0))
	h.add_child(disc(3.4, 0.3, plain(c.team), 0.55))
	h.add_child(ring(5.6, 6.5, iron, Vector3.ZERO, Vector3(90, 0, 0)))
	h.add_child(blob(Vector3(1.6, 1.6, 1.1), iron, Vector3(0, 0, 0.7)))
	return {"node": n}


func _shield_kite(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var h := facing(n, Vector3(3.0, 0.5, 1.5), SHIELD_FACE)
	var outline := [Vector2(-1, 8), Vector2(5, 6), Vector2(4, -4), Vector2(0, -9), Vector2(-4, -4), Vector2(-4, 6)]
	var body := slab(outline, 0.8, plain(c.team))
	body.position.x = -0.5
	h.add_child(body)
	var iron := surf("iron", Color.WHITE, 3.0)
	for k in outline.size():
		var a: Vector2 = outline[k]
		var b: Vector2 = outline[(k + 1) % outline.size()]
		h.add_child(rod(Vector3(a.x - 0.5, a.y, 0.3), Vector3(b.x - 0.5, b.y, 0.3), 0.35, 0.35, iron))
	h.add_child(rod(Vector3(0, 7, 0.5), Vector3(-0.5, -7.5, 0.5), 0.35, 0.35, iron))
	h.add_child(rod(Vector3(-3.5, 3, 0.5), Vector3(4, 3, 0.5), 0.35, 0.35, iron))
	return {"node": n}


func _shield_scutum(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var h := facing(n, Vector3(3.0, 0.0, 1.5), SHIELD_FACE)
	var bronze := surf("bronze", Color.WHITE, 3.0)
	var team := plain(c.team)
	var R := 6.0
	for i in 5:   # curved: five strips round a vertical axis behind the shield
		var a := deg_to_rad((i - 2) * 17.0)
		var strip := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.85, 17, 0.6)
		strip.mesh = bm
		strip.material_override = team
		strip.position = Vector3(sin(a) * R, 0, cos(a) * R - R)
		strip.rotation.y = a
		h.add_child(strip)
	for y in [8.5, -8.5]:
		for i in 5:
			var a := deg_to_rad((i - 2) * 17.0)
			h.add_child(rod(Vector3(sin(a - 0.15) * R, y, cos(a - 0.15) * R - R + 0.2), Vector3(sin(a + 0.15) * R, y, cos(a + 0.15) * R - R + 0.2), 0.35, 0.35, bronze))
	h.add_child(blob(Vector3(1.7, 1.7, 1.1), bronze, Vector3(0, 0, 0.5)))
	h.add_child(rod(Vector3(0, 7.8, 0.4), Vector3(0, 1.7, 0.4), 0.3, 0.3, bronze))
	h.add_child(rod(Vector3(0, -1.7, 0.4), Vector3(0, -7.8, 0.4), 0.3, 0.3, bronze))
	return {"node": n}


func _shield_hoplon(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var h := facing(n, Vector3(3.0, 0.5, 1.5), SHIELD_FACE)
	var bronze := surf("bronze", Color.WHITE, 3.0)
	h.add_child(disc(6.8, 1.4, bronze, 0))
	h.add_child(disc(4.6, 0.3, plain(c.team), 0.75))
	h.add_child(ring(6.3, 7.5, bronze, Vector3(0, 0, 0.3), Vector3(90, 0, 0)))
	return {"node": n}


# ------------------------------------------------------------------ helmets (around the head's top socket)

func _helm_bronze(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bronze := surf("bronze", Color.WHITE, 3.0)
	n.add_child(dome(Vector3(5.0, 5.0, 4.8), bronze, Vector3(0, -3.8, 0)))
	n.add_child(ring(4.7, 5.5, bronze, Vector3(0, -3.6, 0)))
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.5, 2.4, 0.5), bronze, Vector3(2.0, -5.4, 4.3 * side)))
	n.add_child(rod(Vector3(0, 0.8, 0), Vector3(0, 2.0, 0), 0.5, 0.5, bronze))
	crest(n, c.team, Vector3(-0.3, 1.6, 0), 8.0, 4.0)
	return {"node": n}


func _helm_iron(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color.WHITE, 3.0)
	n.add_child(cone(0.5, 5.2, 6.2, iron, Vector3(0, -0.9, 0)))
	n.add_child(blob(Vector3(0.8, 0.6, 0.8), iron, Vector3(0, 2.3, 0)))
	n.add_child(ring(5.0, 5.7, iron, Vector3(0, -3.9, 0)))
	n.add_child(rod(Vector3(5.4, -3.6, 0), Vector3(5.6, -7.6, 0), 0.55, 0.45, iron))   # nose guard
	return {"node": n}


func _helm_horned(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color.WHITE, 3.0)
	var bone := surf("bone", Color.WHITE, 3.0)
	n.add_child(dome(Vector3(5.0, 5.2, 4.8), iron, Vector3(0, -3.8, 0)))
	n.add_child(ring(4.7, 5.5, iron, Vector3(0, -3.6, 0)))
	n.add_child(rod(Vector3(-5, -1.0, 0), Vector3(5, -1.0, 0), 0.5, 0.5, iron))
	for side in [1, -1]:
		var pts := [Vector3(0.5, -1.5, 4.4 * side), Vector3(0.5, 0.5, 7.2 * side), Vector3(0.2, 3.8, 8.4 * side), Vector3(-0.4, 6.4, 8.0 * side)]
		var r := [1.4, 1.1, 0.7, 0.3]
		for k in range(1, pts.size()):
			n.add_child(rod(pts[k - 1], pts[k], r[k - 1], r[k], bone))
	return {"node": n}


func _helm_galea(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color.WHITE, 3.0)
	var bronze := surf("bronze", Color.WHITE, 2.0)
	n.add_child(dome(Vector3(5.0, 5.0, 4.8), iron, Vector3(0, -3.8, 0)))
	n.add_child(ring(4.8, 5.4, bronze, Vector3(0.3, -2.8, 0)))   # brow band
	n.add_child(blob(Vector3(3.0, 0.6, 5.0), iron, Vector3(-4.0, -4.2, 0), Vector3(0, 0, -25)))   # neck guard
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.6, 2.6, 0.5), iron, Vector3(2.0, -5.6, 4.3 * side)))
	crest(n, c.crimson, Vector3(-0.2, 1.0, 0), 9.0, 4.5)
	return {"node": n}


func _helm_corinthian(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bronze := surf("bronze", Color(0.82, 0.74, 0.62), 3.0)
	var bright := surf("bronze", Color.WHITE, 2.0)
	n.add_child(dome(Vector3(5.0, 5.0, 4.8), bronze, Vector3(0, -3.6, 0)))
	n.add_child(ring(4.8, 5.4, bright, Vector3(0, -3.5, 0)))
	# Cheek guards sweep down each side, leaving the T-shaped opening: eyes, nose, mouth show.
	for side in [1, -1]:
		n.add_child(blob(Vector3(2.4, 3.6, 0.7), bronze, Vector3(2.4, -6.6, 4.2 * side), Vector3(0, 0, 8)))
	n.add_child(rod(Vector3(4.9, -3.4, 0), Vector3(5.2, -6.8, 0), 0.7, 0.55, bronze))   # nose guard
	n.add_child(blob(Vector3(3.0, 3.6, 4.4), bronze, Vector3(-2.6, -6.2, 0)))   # the back of the neck
	n.add_child(rod(Vector3(0, 1.0, 0), Vector3(0, 2.0, 0), 0.5, 0.5, bright))
	crest(n, c.team, Vector3(-0.4, 1.6, 0), 9.0, 4.5)
	return {"node": n}


# ------------------------------------------------------------------ armour (frog-sized; bodies scale it)

func _armour_leather(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var leather := surf("leather", Color.WHITE, 5.0)
	n.add_child(blob(Vector3(8.8, 8.2, 10.4), leather, Vector3(1.5, 0.5, 0), Vector3(0, 0, -10)))
	# The belt hugs the jerkin where it is at that height (a wider ring floated off the body as a
	# dark hoop round the belly; so did the old shoulder straps).
	n.add_child(ring(0.97, 1.1, surf("leather", Color("#5a3a20"), 3.0), Vector3(1.4, -5.0, 0), Vector3(0, 0, -10), Vector3(6.6, 1.0, 7.8)))
	return {"node": n}


func _armour_bronze(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bronze := surf("bronze", Color.WHITE, 4.0)
	n.add_child(blob(Vector3(8.8, 8.2, 10.4), bronze, Vector3(1.5, 0.5, 0), Vector3(0, 0, -10)))
	for side in [1, -1]:   # the muscled chest
		n.add_child(blob(Vector3(3.2, 2.6, 3.8), bronze, Vector3(7.6, 2.6, 3.6 * side)))
	n.add_child(blob(Vector3(2.4, 3.6, 2.4), bronze, Vector3(8.4, -2.8, 0)))
	var flaps := surf("leather", Color.WHITE, 3.0)
	for k in 7:   # leather strips below
		var a := deg_to_rad(-75 + k * 25)
		var strip := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 4.0, 2.6)
		strip.mesh = bm
		strip.material_override = flaps
		strip.position = Vector3(cos(a) * 8.2 + 1.0, -8.5, sin(a) * 9.6)
		strip.rotation.y = -a
		n.add_child(strip)
	return {"node": n}


func _armour_lorica(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color.WHITE, 4.0)
	var dark := surf("iron", Color(0.62, 0.64, 0.68), 3.0)
	n.add_child(blob(Vector3(8.8, 8.2, 10.4), iron, Vector3(1.5, 0.5, 0), Vector3(0, 0, -10)))
	for y in [-5.0, -2.0, 1.0, 4.0]:   # overlapping bands
		var k := sqrt(1.0 - pow(y / 8.6, 2))
		n.add_child(ring(8.3 * k, 9.4 * k, dark, Vector3(1.5, y + 0.5, 0), Vector3(0, 0, -10), Vector3(1, 1, 10.4 / 8.8)))
	for side in [1, -1]:
		n.add_child(blob(Vector3(4.2, 2.0, 4.0), iron, Vector3(0.5, 7.0, 6.6 * side), Vector3(20 * side, 0, 0)))
	return {"node": n}


# ------------------------------------------------------------------ backs

func _cape_cloth(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	# Two panels hanging close down the back from the shoulders: a cape, not a flag (wide panels
	# fanned out behind and read as a board stuck to the unit).
	var cloth := surf("cloth", c.team, 4.0)
	for side in [1, -1]:
		var panel := slab([Vector2(2, 1), Vector2(3, -1), Vector2(0.5, -14), Vector2(-2.5, -14.5), Vector2(-4, -10.5), Vector2(-1.5, 0.5)], 0.6, cloth)
		panel.position = Vector3(0, 0, 3.0 * side)
		panel.rotation_degrees = Vector3(0, -10 * side, 0)
		n.add_child(panel)
	n.add_child(blob(Vector3(1.0, 1.0, 0.6), surf("bronze", Color.WHITE, 2.0), Vector3(1.5, 0, 1.2)))   # clasp
	return {"node": n}


func _banner_team(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3(0, -4, 0), Vector3(0, 22, 0), 0.5, 0.45, surf("wood_grain", Color.WHITE, 5.0), false))
	n.add_child(blob(Vector3(0.9, 1.2, 0.9), surf("bronze", Color.WHITE, 2.0), Vector3(0, 22.8, 0)))
	n.add_child(rod(Vector3(-0.3, 21.2, 0), Vector3(9.6, 21.2, 0), 0.3, 0.3, surf("wood_grain", Color.WHITE, 3.0)))
	n.add_child(slab([Vector2(0.3, 21), Vector2(9.3, 21), Vector2(9.3, 13.2), Vector2(7.0, 15.4), Vector2(4.8, 13.2), Vector2(0.3, 14.4)], 0.4, surf("cloth", c.team, 4.0)))
	n.add_child(blob(Vector3(1.6, 1.6, 0.5), plain(Color("#e8e4d8")), Vector3(4.8, 17.6, 0.3)))
	return {"node": n}


func _quiver(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var leather := surf("leather", Color.WHITE, 3.0)
	n.add_child(cone(2.0, 1.6, 12.0, leather, Vector3(0, 2, 0)))
	n.add_child(ring(1.8, 2.4, surf("leather", Color("#5a3a20"), 2.0), Vector3(0, 7.8, 0)))
	n.add_child(ring(1.6, 2.1, surf("leather", Color("#5a3a20"), 2.0), Vector3(0, -2.5, 0)))
	var fletch := plain(Color("#e8e2d0"))
	for k in 4:
		var off := Vector3(cos(k * 1.7) * 0.8, 0, sin(k * 1.7) * 0.8)
		var top := Vector3(0, 11.5 + (k % 2) * 0.8, 0) + off
		n.add_child(rod(Vector3(0, 7, 0) + off, top, 0.2, 0.2, surf("wood_grain", Color.WHITE, 2.0), false))
		n.add_child(blob(Vector3(0.3, 1.4, 0.7), fletch, top - Vector3(0, 0.9, 0)))
	return {"node": n}


## Wings at the back: the near one fanned towards the viewer, the far one raised
## steeper behind it. Both are rooted at the shoulders and sweep back and up (the
## texture's root is its lower right, its tip the upper left). The far one used to sit
## with its root over the head, so it read as pointing forward.
func _wings(texture: String, tint: Color) -> Dictionary:
	var n := Node3D.new()
	n.scale = Vector3.ONE * 0.8   # full size, they hid the unit wearing them
	var x := Vector3(1, -0.3, -0.3).normalized()   # the far wing's picture axes: right...
	var y := Vector3(0.3, 1, 0).normalized()       # ...and up, so its tip goes back and steeply up
	var root := Vector3(0.5, 3.0, -4.0)
	n.add_child(decal(texture, 24, 24, root - x * 9.0 + y * 8.2, x.cross(y), true, y, tint.darkened(0.3)))
	n.add_child(decal(texture, 26, 26, Vector3(-10.7, 8.8, 2.0), Vector3(-0.15, 0.15, 1), true, Vector3.UP, tint))
	return {"node": n}


func _wings_feather(c: Dictionary) -> Dictionary:
	return _wings("wing_feather", Color.WHITE)


func _wings_bat(c: Dictionary) -> Dictionary:
	return _wings("wing_bat", Color.WHITE)


# ------------------------------------------------------------------ job tools and carried loads
# Shown on workers by the view: the tool for the job at hand, and what they carry home.

func _tool_hammer(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3(-1, -3.5, 0), Vector3(2.5, 8.5, 0), 0.7, 0.65, surf("wood_grain", Color.WHITE, 6.0)))
	var head := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(4.6, 2.2, 2.2)
	head.mesh = bm
	head.material_override = surf("iron", Color.WHITE, 3.0)
	head.position = Vector3(2.8, 9.2, 0)
	head.rotation.z = -0.28
	n.add_child(head)
	return {"node": n}


func _tool_pick(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3(-1, -3.5, 0), Vector3(2.5, 9.5, 0), 0.7, 0.65, surf("wood_grain", Color.WHITE, 6.0)))
	var iron := surf("iron", Color.WHITE, 3.0)
	n.add_child(rod(Vector3(2.6, 9.6, 0), Vector3(-2.2, 7.4, 0), 0.75, 0.3, iron))   # the point
	n.add_child(rod(Vector3(2.6, 9.6, 0), Vector3(7.4, 8.4, 0), 0.75, 0.35, iron))   # the blade
	return {"node": n}


## A bundle of cut reeds over the shoulder, tied in the middle.
func _load_reeds(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var reed := surf("reed_stalk", Color.WHITE, 5.0)
	for k in 7:
		var off := Vector3(0, (k % 3) * 0.7, (k - 3) * 0.55)
		n.add_child(rod(Vector3(-7, 3.5, 0) + off, Vector3(8, 9.5, 0) + off, 0.55, 0.45, reed, false))
	n.add_child(ring(1.6, 2.2, surf("leather", Color.WHITE, 2.0), Vector3(0.5, 6.8, 0), Vector3(0, 0, 68)))
	for k in 3:
		n.add_child(decal("reed_leaf", 0.9, 4.0, Vector3(8.5, 10.5 + k * 0.4, (k - 1) * 0.8), Vector3(0.2, 0.3, 1), true, Vector3(1, 0.4, 0)))
	return {"node": n}


## A rough block of stone held at the chest.
func _load_stone(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(5.0, 3.6, 4.0)
	mi.mesh = bm
	mi.material_override = surf("rock", Color(0.8, 0.78, 0.72), 3.0)
	mi.position = Vector3(1.5, 1.0, 0)
	mi.rotation = Vector3(0.15, 0.4, 0.1)
	n.add_child(mi)
	return {"node": n}


## Gold ore carried home: a lump of the deposit's dark rock with the gold showing in it.
func _load_gold(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(blob(Vector3(2.6, 1.9, 2.1), surf("rock", Color(0.6, 0.55, 0.5), 3.0), Vector3(1.5, 1.0, 0)))
	var gold := plain(Color("#f2c440"))
	for p in [Vector3(2.8, 2.2, 1.0), Vector3(0.6, 2.4, -0.6), Vector3(2.0, 0.6, 1.8), Vector3(3.6, 1.2, -0.8)]:
		n.add_child(blob(Vector3(0.75, 0.6, 0.7), gold, p))
	return {"node": n}


# ------------------------------------------------------------------ first-age kit for everyone

## A fire-hardened wooden spear: a plain shaft, the point charred dark.
func _weapon_spear_wood(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var a := Vector3(-4, -8, 0)
	var b := Vector3(6, 19, 0)
	n.add_child(rod(a, b, 0.95, 0.85, surf("wood_grain", Color.WHITE, 6.0), false))
	var d := (b - a).normalized()
	n.add_child(rod(b, b + d * 4.0, 0.85, 0.1, surf("wood_grain", Color("#3a2a1e"), 3.0), false))
	n.add_child(ring(0.7, 1.15, surf("leather", Color.WHITE, 3.0), a + d * 9.0, Vector3(0, 0, rad_to_deg(atan2(d.y, d.x)) - 90)))
	return {"node": n}


## A padded leather cap with a rolled brim.
func _helm_cap(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var leather := surf("leather", Color(0.9, 0.82, 0.72), 3.0)
	n.add_child(dome(Vector3(4.9, 3.6, 4.7), leather, Vector3(0, -3.0, 0)))
	n.add_child(ring(4.6, 5.3, surf("leather", Color(0.7, 0.6, 0.5), 2.0), Vector3(0, -3.0, 0)))
	n.add_child(blob(Vector3(0.6, 0.6, 0.6), leather, Vector3(0, 0.7, 0)))
	return {"node": n}


# ------------------------------------------------------------------ the rats' junk kit, by age (RB2)
# Never human bronze; head gear sits on the crown between the ears, which always show.
# Age 1 a thimble, age 2 tin, age 3 cutlery steel copying the Romans.

func _helm_thimble(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var brass := surf("bronze", Color(1.1, 1.0, 0.75), 1.2)
	n.add_child(cone(1.7, 2.2, 3.0, brass, Vector3(0.6, -0.4, 0), Vector3(0, 0, -12)))
	n.add_child(blob(Vector3(1.7, 0.6, 1.7), brass, Vector3(0.9, 1.1, 0)))
	n.add_child(ring(2.1, 2.5, brass, Vector3(0.4, -1.8, 0), Vector3(0, 0, -12)))
	return {"node": n}


func _helm_tin_cap(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var tin := surf("iron", Color(0.95, 0.95, 1.0), 2.0)
	n.add_child(dome(Vector3(4.0, 2.6, 2.5), tin, Vector3(0.6, -1.6, 0)))   # narrow: the ears stay out
	n.add_child(ring(0.97, 1.08, plain(Color("#6a6c66")), Vector3(0.6, -1.5, 0), Vector3.ZERO, Vector3(4.0, 1.0, 2.5)))
	n.add_child(blob(Vector3(0.7, 0.5, 0.7), tin, Vector3(0.6, 1.1, 0)))   # a rivet knob
	return {"node": n}


## Age 3 pride: a spoon's bowl as the helmet, its handle down the neck as a guard, and a
## toothbrush along the top as the crest (copying the Romans' crested helmet).
func _helm_spoon(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var steel := surf("iron", Color.WHITE, 2.0)
	n.add_child(dome(Vector3(4.4, 2.8, 2.6), steel, Vector3(0.8, -1.6, 0)))
	n.add_child(rod(Vector3(-3.2, -1.4, 0), Vector3(-6.2, -5.2, 0), 0.55, 0.45, steel))   # the handle as a neck guard
	n.add_child(rod(Vector3(-1.6, 1.5, 0), Vector3(3.6, 1.5, 0), 0.35, 0.35, plain(Color("#e8e0d0"))))   # toothbrush handle
	n.add_child(_box(Vector3(4.0, 1.6, 0.9), plain(c.crimson), Vector3(0.6, 2.6, 0)))   # bristles, in the crest's red
	return {"node": n}


## Sardine-tin bands as a segmented cuirass (age 3), fitted to the lean rat.
func _armour_sardine(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var tin := surf("iron", Color(0.95, 0.97, 1.0), 2.0)
	var label := plain(Color("#c8a040"))
	var tilt := Node3D.new()   # follow the rat's forward hunch; torso armour is built ~1.6x and scaled down by the body
	tilt.rotation_degrees = Vector3(0, 0, 15)
	tilt.scale = Vector3.ONE * 1.45
	n.add_child(tilt)
	for k in 4:
		var y := 4.0 - k * 2.4
		tilt.add_child(cone(6.6 - k * 0.35, 6.9 - k * 0.35, 2.0, tin if k % 2 == 0 else label, Vector3(0.6, y, 0), Vector3.ZERO, 20))
	tilt.add_child(_box(Vector3(1.2, 0.5, 3.2), plain(Color("#6a6c66")), Vector3(7.0, 4.6, 0), Vector3(0, 0, -20)))   # the key, rolled
	return {"node": n}


## A shield cut from a can: a curved tall rectangle (copying the Roman scutum), a bottle-cap boss.
func _shield_can_scutum(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var h := facing(n, Vector3(3.0, 0.0, 1.5), SHIELD_FACE)
	var tin := surf("iron", Color(0.95, 0.95, 1.0), 2.0)
	var R := 5.5
	for i in 5:   # a can cut open and curved, like the scutum; its label band in the team colour
		var a := deg_to_rad((i - 2) * 17.0)
		for part in [[tin, 6.0, 4.2], [plain(c.team), 4.4, -1.0], [tin, 4.2, -5.3]]:
			var strip := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.75, part[1], 0.5)
			strip.mesh = bm
			strip.material_override = part[0]
			strip.position = Vector3(sin(a) * R, part[2], cos(a) * R - R)
			strip.rotation.y = a
			h.add_child(strip)
	h.add_child(cone(1.2, 1.4, 0.6, surf("bronze", Color.WHITE, 1.0), Vector3(0, 0.5, 0.4), Vector3(90, 0, 0), 14))   # a bottle-cap boss
	return {"node": n}


func _box(size: Vector3, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	return mi


## Age 2: the leather jerkin with bottle caps sewn on as scales.
func _armour_bottlecap(c: Dictionary) -> Dictionary:
	var spec := _armour_leather(c)
	var n: Node3D = spec.node
	var cap := surf("iron", Color(1.0, 0.92, 0.75), 1.0)
	var centre := Vector3(1.5, 0.5, 0)
	var radii := Vector3(8.8, 8.2, 10.4)
	for row in 3:
		for k in 5:
			var look := Vector3(1.0, 0.45 - row * 0.4, (k - 2) * 0.45).normalized()
			var p: Vector3 = on_surface(centre, radii, look, 0.2)
			var disc := cone(1.5, 1.7, 0.5, cap, p, Vector3.ZERO, 12)
			disc.look_at_from_position(p, p + look, Vector3.UP)
			disc.rotate_object_local(Vector3.RIGHT, PI / 2)
			n.add_child(disc)
	return spec

