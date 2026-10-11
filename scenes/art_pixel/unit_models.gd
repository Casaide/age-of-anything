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


func has(id: String) -> bool:
	return has_method("_" + id.replace(".", "_"))


## {node: Node3D, sockets: {name: Vector3}, anchors: [[Vector3 hip, phase, z]]}
func build(id: String, colours: Dictionary) -> Dictionary:
	return call("_" + id.replace(".", "_"), colours)


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


# ------------------------------------------------------------------ frog

func _body_frog(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var skin := surf("frog_skin", c.skin, 10.0)
	var belly := surf("frog_belly", c.skin2, 8.0)
	# A slimmer, upright frog body leaning back on its haunches.
	n.add_child(blob(Vector3(10.0, 11.5, 9.0), skin, Vector3(-0.5, 14, 0), Vector3(0, 0, 14)))
	n.add_child(blob(Vector3(6.8, 9.0, 7.0), belly, Vector3(3.6, 12.5, 0.6), Vector3(0, 0, 14)))
	# Slim arms with round finger pads; the near arm is a front layer with its own outline.
	var front := Node3D.new()
	for side in [1, -1]:
		var into: Node3D = front if side == 1 else n
		var sh := Vector3(4, 18.5, 6.8 * side)
		var elbow := Vector3(6.5, 13.5, 8.6 * side)
		var hand := Vector3(10.5, 12, 7.5 * side) if side == 1 else Vector3(10, 13, -6.5)
		into.add_child(rod(sh, elbow, 2.0, 1.6, skin))
		into.add_child(rod(elbow, hand, 1.6, 1.4, skin))
		into.add_child(blob(Vector3(1.8, 1.3, 1.8), skin, hand))
		for f in 3:
			var tip := hand + Vector3(2.4, -0.9, (f - 1) * 1.5)
			into.add_child(rod(hand, tip, 0.5, 0.45, skin, false))
			into.add_child(blob(Vector3(0.8, 0.8, 0.8), belly, tip))
	return {"node": n, "front": front, "sockets": {
		"head": Vector3(3, 23, 0), "hand_r": Vector3(10.5, 12, 7.5), "hand_l": Vector3(10, 13, -6.5),
		"torso": Vector3(0.5, 14, 0), "back": Vector3(-8, 18, 0)},
		"anchors": [[Vector3(-3, 7.0, -6.5), 0.0, -1], [Vector3(-3, 7.0, 6.5), PI, 1]],
		"torso_scale": Vector2.ONE}


func _head_frog(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var skin := surf("frog_skin", c.skin, 10.0)
	var chin := surf("frog_belly", c.skin2, 8.0)
	var head_c := Vector3(3, 4.5, 0)
	var head_r := Vector3(10.0, 5.8, 9.0)
	n.add_child(blob(head_r, skin, head_c))
	n.add_child(blob(Vector3(8.6, 3.0, 7.6), chin, Vector3(4, 2.2, 0)))
	# Big eyes set high and wide: the frog's signature.
	for side in [1, -1]:
		var dome := Vector3(4.5, 10.2, 5.4 * side)
		var dome_r := Vector3(4.8, 4.6, 4.8)
		n.add_child(blob(dome_r, skin, dome))
		var look := Vector3(0.55, 0.3, 0.8 * side)
		n.add_child(decal("frog_eye", 6.6, 6.6, on_surface(dome, dome_r, look, 0.15), look, false))
		n.add_child(blob(Vector3(0.55, 0.4, 0.55), plain(Color("#1a120a")), on_surface(head_c, head_r, Vector3(1, 0.35, 0.18 * side), 0.0)))
	var mouth_dir := Vector3(0.8, -0.1, 0.6)
	n.add_child(decal("frog_mouth", 12.5, 3.0, on_surface(head_c, head_r, mouth_dir, 0.2), mouth_dir))
	return {"node": n, "sockets": {"top": Vector3(1, 12.5, 0)}}


## A long, folded hind leg: thigh forward, shin back, a big webbed foot with toe pads.
func _leg_frog(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var skin := surf("frog_skin", c.skin, 10.0)
	var pad := surf("frog_belly", c.skin2, 6.0)
	var hip := Vector3(0, 0, 0)
	var knee := Vector3(7.5, -2.5, 0.8)
	var ankle := Vector3(0.5, -5.8, 0.6)
	n.add_child(blob(Vector3(5.5, 3.0, 3.0), skin, (hip + knee) * 0.5, Vector3(0, 0, -18)))
	n.add_child(rod(knee, ankle, 1.9, 1.4, skin))
	var heel := ankle + Vector3(0.5, -0.8, 0)
	n.add_child(blob(Vector3(4.2, 0.9, 2.6), skin, heel + Vector3(3.2, -0.2, 0)))
	n.add_child(blob(Vector3(3.6, 0.35, 3.6), surf("frog_belly", c.skin.lerp(c.skin2, 0.4), 6.0), heel + Vector3(5.2, -0.6, 0)))   # the web
	for t in 4:
		var toe := heel + Vector3(8.6, -0.6, (t - 1.5) * 1.9)
		n.add_child(rod(heel + Vector3(2.5, -0.3, (t - 1.5) * 0.6), toe, 0.5, 0.45, skin, false))
		n.add_child(blob(Vector3(0.95, 0.75, 0.95), pad, toe))
	return {"node": n}


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
	var a := Vector3(-7, -4.5, 0)
	var b := Vector3(16, 9.5, 0)
	n.add_child(rod(a, b, 1.05, 1.0, surf("reed_stalk", Color.WHITE, 5.0), false))
	var d := (b - a).normalized()
	var head := CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = 2.4
	head.height = 7.5
	head.radial_segments = 4
	var tip := MeshInstance3D.new()
	tip.mesh = head
	tip.material_override = surf("bone", Color.WHITE, 4.0)
	tip.position = b + d * 3.0
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
	n.add_child(blob(Vector3(7.6, 11.0, 7.0), fur, Vector3(-0.5, 15, 0), Vector3(0, 0, 8)))
	n.add_child(blob(Vector3(4.6, 7.6, 5.0), pink, Vector3(2.8, 13.5, 0.5), Vector3(0, 0, 8)))
	# A long tail curling behind, thinning to a point.
	var pts := [Vector3(-5, 7, 0), Vector3(-11, 4.5, 1.5), Vector3(-16.5, 5.5, 2.5), Vector3(-19.5, 9.5, 3.0), Vector3(-19, 14, 3.0), Vector3(-16.5, 16, 2.5)]
	for k in range(1, pts.size()):
		n.add_child(rod(pts[k - 1], pts[k], 1.25 - k * 0.17, 1.25 - (k + 1) * 0.17, pink))
	var front := Node3D.new()
	for side in [1, -1]:
		var into: Node3D = front if side == 1 else n
		var sh := Vector3(3, 19.5, 5.5 * side)
		var elbow := Vector3(4, 16.5, 7.0 * side)
		var hand := Vector3(7.5, 15.5, 5.5 * side) if side == 1 else Vector3(7, 16.5, -5)
		into.add_child(rod(sh, elbow, 1.6, 1.3, fur))
		into.add_child(rod(elbow, hand, 1.3, 1.1, fur))
		into.add_child(blob(Vector3(1.4, 1.1, 1.4), pink, hand))
	return {"node": n, "front": front, "sockets": {
		"head": Vector3(2, 25, 0), "hand_r": Vector3(7.5, 15.5, 5.5), "hand_l": Vector3(7, 16.5, -5),
		"torso": Vector3(0, 15, 0), "back": Vector3(-6, 19, 0)},
		"anchors": [[Vector3(-1, 6.0, -4.0), 0.0, -1], [Vector3(-1, 6.0, 4.0), PI, 1]],
		"torso_scale": Vector2(0.85, 1.15)}


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
	var a := Vector3(-7, -4.5, 0)
	var b := Vector3(15.5, 9.2, 0)
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
	n.add_child(blob(Vector3(4.6, 1.8, 4.4), surf("leather", Color.WHITE, 3.0), Vector3(-5, 22.0, 0), Vector3(0, 0, -6)))
	var hips := []
	var xs := [7.5, 4.5, 1.0, -2.5]
	var phases := [0.0, 0.8, 1.6, 2.4]
	for k in 4:
		hips.append([Vector3(xs[k], 10.5, 5.0), phases[k], 1, 1 if k >= 2 else 0])
		hips.append([Vector3(xs[k] + 0.5, 11.5, -5.0), phases[k] + PI, -1, 1 if k >= 2 else 0])
	return {"node": n, "sockets": {
		"head": Vector3(11, 11, 0), "hand_r": Vector3(12, 9, 4), "hand_l": Vector3(9, 9, -4),
		"torso": Vector3(-7, 13, 0), "back": Vector3(-8, 20, 0), "seat": Vector3(-5, 22.5, 0)},
		"anchors": hips, "torso_scale": Vector2(1.3, 1.1)}


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
	n.add_child(rod(Vector3(0, 0, 0), Vector3(4, -6, 0.5), 0.35, 0.35, cord))
	n.add_child(rod(Vector3(0.5, 0, 0), Vector3(1.6, -7.6, -0.5), 0.35, 0.35, cord))
	n.add_child(blob(Vector3(1.7, 1.2, 1.4), cord, Vector3(2.4, -7.6, 0)))
	n.add_child(blob(Vector3(1.4, 1.4, 1.4), surf("iron", Color("#b8b4a8"), 3.0), Vector3(2.4, -6.8, 0)))
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
	n.add_child(rod(Vector3(-6.8, 0.8, 0), Vector3(-12.5, 1.8, 0), 0.7, 0.6, surf("wood_grain", Color.WHITE, 4.0)))
	return {"node": n}


func _weapon_blowgun(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3(-2, 2, 0), Vector3(14, 6, 0), 1.0, 0.9, surf("reed_stalk", Color.WHITE, 5.0), false))
	n.add_child(ring(0.9, 1.4, surf("leather", Color.WHITE, 3.0), Vector3(0, 2.5, 0), Vector3(0, 0, -76)))
	n.add_child(blob(Vector3(0.6, 0.6, 0.6), plain(Color("#1a1a1a")), Vector3(14.2, 6.05, 0)))
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
	var cloth := surf("cloth", c.cloth, 6.0)
	var skin := surf("skin", c.skin, 8.0)
	var belt := surf("leather", Color.WHITE, 3.0)
	# A belted tunic: chest and shoulders, a flared skirt over the hips.
	n.add_child(blob(Vector3(4.4, 5.8, 5.4), cloth, Vector3(0.3, 19.6, 0)))
	n.add_child(cone(4.3, 5.5, 4.6, cloth, Vector3(0, 12.9, 0)))
	n.add_child(ring(4.2, 5.1, belt, Vector3(0, 15.0, 0)))
	n.add_child(blob(Vector3(1.0, 1.0, 0.5), surf("bronze", Color.WHITE, 2.0), Vector3(4.9, 15.0, 0.6)))
	n.add_child(rod(Vector3(0.3, 23.5, 0), Vector3(0.6, 27, 0), 1.8, 1.7, skin))
	var front := Node3D.new()
	for side in [1, -1]:
		var into: Node3D = front if side == 1 else n
		var sh := Vector3(0.3, 23.2, 5.0 * side)
		var elbow := Vector3(1.4, 18.4, 6.4 * side)
		var hand := Vector3(6.0, 16.2, 5.6) if side == 1 else Vector3(5.5, 17.2, -4.8)
		into.add_child(blob(Vector3(2.5, 2.4, 2.5), cloth, sh))
		into.add_child(rod(sh, elbow, 1.8, 1.55, cloth))
		into.add_child(rod(elbow, hand, 1.35, 1.15, skin))
		into.add_child(blob(Vector3(1.5, 1.6, 1.3), skin, hand))
	return {"node": n, "front": front, "sockets": {
		"head": Vector3(0.6, 27, 0), "hand_r": Vector3(6.0, 16.2, 5.6), "hand_l": Vector3(5.5, 17.2, -4.8),
		"torso": Vector3(0.3, 17.8, 0), "back": Vector3(-4.2, 22, 0)},
		"anchors": [[Vector3(-1.6, 11.0, -2.4), 0.0, -1], [Vector3(1.4, 11.0, 2.4), PI, 1]],
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
	return {"node": n, "sockets": {"top": Vector3(0.3, 10.3, 0)}}


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

func _pony_barrel(n: Node3D, c: Dictionary) -> void:
	var hide := surf("hide", c.skin, 6.0)
	var mane := surf("mane", c.skin2, 3.0)
	n.add_child(blob(Vector3(10.5, 6.6, 6.0), hide, Vector3(0, 19, 0)))
	n.add_child(blob(Vector3(5.6, 6.6, 5.6), hide, Vector3(8.0, 19.6, 0)))    # chest
	n.add_child(blob(Vector3(6.4, 7.0, 6.0), hide, Vector3(-8.5, 20.2, 0)))   # rump
	var tail := [Vector3(-14, 23, 0), Vector3(-17, 19.5, 0.5), Vector3(-18.6, 14, 1.0), Vector3(-18.2, 9, 1.2)]
	var r := [2.2, 2.1, 1.7, 1.0]
	for k in range(1, tail.size()):
		n.add_child(rod(tail[k - 1], tail[k], r[k - 1], r[k], mane))


func _pony_anchors() -> Array:
	return [[Vector3(8.5, 14, 4.0), 0.0, 1, 0], [Vector3(-9.5, 14, 4.0), PI, 1, 0],
		[Vector3(7.0, 14, -4.0), PI, -1, 0], [Vector3(-11.0, 14, -4.0), 0.0, -1, 0]]


func _body_pony(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	_pony_barrel(n, c)
	var hide := surf("hide", c.skin, 6.0)
	n.add_child(rod(Vector3(8.5, 22, 0), Vector3(14.2, 30.5, 0), 4.2, 2.9, hide))   # neck
	n.add_child(rod(Vector3(6.4, 24.0, 0), Vector3(12.0, 32.4, 0), 1.9, 1.5, surf("mane", c.skin2, 3.0)))
	return {"node": n, "sockets": {
		"head": Vector3(14.6, 31.5, 0), "hand_r": Vector3(10, 18, 4), "hand_l": Vector3(8, 18, -4),
		"torso": Vector3(0, 19, 0), "back": Vector3(-8, 24, 0), "seat": Vector3(-1, 25.8, 0)},
		"anchors": _pony_anchors(), "torso_scale": Vector2(1.3, 1.0)}


## A centaur's horse half: no neck; the rider's torso stands where it would be.
func _body_pony_fused(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	_pony_barrel(n, c)
	return {"node": n, "sockets": {
		"head": Vector3(14.6, 31.5, 0), "hand_r": Vector3(10, 18, 4), "hand_l": Vector3(8, 18, -4),
		"torso": Vector3(0, 19, 0), "back": Vector3(-8, 24, 0), "seat": Vector3(7.5, 15.5, 0)},
		"anchors": _pony_anchors(), "torso_scale": Vector2(1.3, 1.0)}


func _head_pony(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
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
	return {"node": n, "sockets": {"top": Vector3(0.5, 2.6, 0)}}


func _leg_hoof(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var hide := surf("hide", c.skin, 5.0)
	n.add_child(blob(Vector3(2.6, 4.2, 2.4), hide, Vector3(0, -2.8, 0)))
	n.add_child(rod(Vector3(0, -5.5, 0), Vector3(0.2, -10.6, 0), 1.15, 0.95, hide))
	n.add_child(blob(Vector3(1.3, 1.2, 1.2), hide, Vector3(0.3, -10.8, 0)))
	n.add_child(rod(Vector3(0.3, -10.8, 0), Vector3(0.8, -11.8, 0), 1.0, 1.0, hide))
	n.add_child(cone(1.1, 1.6, 1.4, plain(Color("#2a2420")), Vector3(1.0, -12.4, 0)))
	return {"node": n}


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
	return {"node": n, "sockets": {
		"head": Vector3(16, 12.5, 0), "hand_r": Vector3(15, 10, 4), "hand_l": Vector3(13, 10, -4),
		"torso": Vector3(-1, 17, 0), "back": Vector3(-8, 19, 0), "seat": Vector3(-1.5, 21.5, 0)},
		"anchors": hips, "torso_scale": Vector2(1.0, 0.6)}


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
	_pole(n, Vector3(-8, -5, 0), Vector3(22, 13, 0), 0.85, [Vector2(0, -1.3), Vector2(8, 0), Vector2(0, 1.3), Vector2(-1, 0)], surf("iron", Color.WHITE, 3.0))
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
	var a := Vector3(-4, -3, 0)
	var b := Vector3(12, 8, 0)
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
	var wood := surf("wood_grain", Color("#c09060"), 4.0)
	var pts := [Vector3(3.4, -11.4, 0), Vector3(2, -10, 0), Vector3(5, -5, 0), Vector3(6, 0, 0), Vector3(5, 5, 0), Vector3(2, 10, 0), Vector3(3.4, 11.4, 0)]
	for k in range(1, pts.size()):
		var r := 0.85 if k in [3, 4] else 0.6
		n.add_child(rod(pts[k - 1], pts[k], r, r, wood))
	n.add_child(rod(Vector3(2, -10, 0), Vector3(2, 10, 0), 0.14, 0.14, plain(Color("#e8e0c8")), false))
	n.add_child(cone(1.05, 1.05, 2.4, surf("leather", Color.WHITE, 2.0), Vector3(5.7, 0, 0), Vector3(0, 0, 8)))
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
	var bronze := surf("bronze", Color.WHITE, 3.0)
	var centre := Vector3(0.4, -4.4, 0)
	var r := Vector3(4.8, 5.6, 4.6)
	n.add_child(blob(r, bronze, centre))   # covers the face, as it should
	for side in [1, -1]:   # eye openings
		n.add_child(blob(Vector3(0.5, 0.75, 1.4), plain(Color("#120c08")), on_surface(centre, r, Vector3(1, 0.05, 0.42 * side), -0.25)))
	n.add_child(blob(Vector3(0.5, 2.6, 0.5), plain(Color("#120c08")), on_surface(centre, r, Vector3(1, -0.55, 0), -0.25)))   # the mouth slot
	crest(n, c.team, Vector3(-0.5, 0.8, 0), 9.0, 4.5)
	return {"node": n}


# ------------------------------------------------------------------ armour (frog-sized; bodies scale it)

func _armour_leather(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var leather := surf("leather", Color.WHITE, 5.0)
	n.add_child(blob(Vector3(8.8, 8.2, 10.4), leather, Vector3(1.5, 0.5, 0), Vector3(0, 0, -10)))
	for side in [1, -1]:
		n.add_child(ring(9.4, 10.4, surf("leather", Color("#8a6a4a"), 3.0), Vector3(1.2, 1.0, 0), Vector3(0, 0, 70 * side)))
	n.add_child(ring(8.6, 9.8, surf("leather", Color("#5a3a20"), 3.0), Vector3(1.0, -5.5, 0), Vector3(0, 0, -10), Vector3(0.9, 1, 1.1)))
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
	# Two panels hanging from the shoulders, so it reads as a cape and not a flag.
	var cloth := surf("cloth", c.team, 4.0)
	for side in [1, -1]:
		var panel := slab([Vector2(2, 1), Vector2(3.5, -1), Vector2(-1.5, -15.5), Vector2(-6.5, -16), Vector2(-9, -12.5), Vector2(-2, 0.5)], 0.7, cloth)
		panel.position = Vector3(0, 0, 2.6 * side)
		panel.rotation_degrees = Vector3(0, -20 * side, 0)
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


## Wings at the back: the near one fanned towards the viewer, the far one peeking out above.
func _wings(texture: String, tint: Color) -> Dictionary:
	var n := Node3D.new()
	n.add_child(decal(texture, 26, 26, Vector3(-9.5, 10.0, -2.5), Vector3(0.35, 0.1, 1), true, Vector3.UP, tint.darkened(0.25)))
	n.add_child(decal(texture, 26, 26, Vector3(-10.7, 8.8, 2.0), Vector3(-0.15, 0.15, 1), true, Vector3.UP, tint))
	return {"node": n}


func _wings_feather(c: Dictionary) -> Dictionary:
	return _wings("wing_feather", Color.WHITE)


func _wings_bat(c: Dictionary) -> Dictionary:
	return _wings("wing_bat", Color.WHITE)
