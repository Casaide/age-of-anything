extends SubViewport
## Bakes our 2D parts into lit pixel sprites, keeping their design exactly:
## each shape becomes simple 3D in the part's own 2D frame (ellipse -> ellipsoid,
## circle -> sphere, polygon -> flat face, line -> rod), stacked in its 2D draw
## order, lit by one soft matte light from the upper left, rendered front-on at
## SS x the art size, then pixelized. Results go into PartShape.baked.

const PartShape := preload("res://src/part_shape.gd")
const Pixelize := preload("res://scenes/art_pixel/pixelize.gd")

const SS := 4            # supersampling
const LAYER := 50.0      # depth between shapes, so later shapes sit in front
const MARGIN := 3.0      # part units of room around the shapes

var art_scale := 1.5     # art pixels per part unit
var cam: Camera3D
var holder: Node3D


func _init() -> void:
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.far = 5000.0
	add_child(cam)
	var key := DirectionalLight3D.new()
	key.basis = Basis.looking_at(Vector3(0.55, -0.7, -1.0).normalized(), Vector3.UP)
	key.light_energy = 1.05
	add_child(key)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	holder = Node3D.new()
	add_child(holder)


## Bake one part in one colour set (skipped if it's already baked).
func bake(id: String, shapes: Array, colours: Dictionary) -> void:
	var key := PartShape.bake_key(id, shapes, colours)
	if PartShape.baked.has(key):
		return
	var bounds := _bounds(shapes).grow(MARGIN)
	var px := art_scale * SS
	size = Vector2i(ceili(bounds.size.x * px), ceili(bounds.size.y * px))
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = bounds.size.y
	var centre := bounds.get_center()
	cam.position = Vector3(centre.x, -centre.y, 2000.0)
	var model := Node3D.new()
	for i in shapes.size():
		model.add_child(_shape3d(shapes[i], colours, i))
	holder.add_child(model)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := get_texture().get_image()
	holder.remove_child(model)
	model.queue_free()
	var origin := Vector2(-bounds.position.x, -bounds.position.y) * art_scale
	var pix := Pixelize.run(img, SS)
	PartShape.baked[key] = {"tex": ImageTexture.create_from_image(pix), "origin": origin, "scale": art_scale}


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
