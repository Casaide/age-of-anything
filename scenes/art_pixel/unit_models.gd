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
func decal(name: String, w: float, h: float, pos: Vector3, facing: Vector3, lit := true, up := Vector3.UP) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(name)
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
