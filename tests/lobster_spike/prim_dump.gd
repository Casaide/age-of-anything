extends SceneTree
## Godot's primitive meshes (and polygon triangulation) as numbers, for model/kit.lobster's check
## (prim_check.lobster): the Lobster kit must build the same vertices, normals, UVs and triangles.
##   godot --headless --path . --script res://tests/lobster_spike/prim_dump.gd -- <out.txt>


func _dump(name: String, mesh: PrimitiveMesh, out: PackedStringArray) -> void:
	var arr := mesh.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	out.append("mesh %s %d %d" % [name, v.size(), idx.size()])
	for i in v.size():
		out.append("v %.5f %.5f %.5f %.5f %.5f %.5f %.5f %.5f" % [v[i].x, v[i].y, v[i].z, n[i].x, n[i].y, n[i].z, uv[i].x, uv[i].y])
	out.append("i " + " ".join(Array(idx).map(func(x): return str(x))))


func _init() -> void:
	var out := PackedStringArray()
	var s := SphereMesh.new()
	s.radius = 1.0; s.height = 2.0; s.radial_segments = 32; s.rings = 16
	_dump("sphere", s, out)
	var h := SphereMesh.new()
	h.radius = 1.0; h.height = 1.0; h.is_hemisphere = true; h.radial_segments = 28; h.rings = 10
	_dump("hemi", h, out)
	var c := CylinderMesh.new()
	c.top_radius = 1.5; c.bottom_radius = 2.0; c.height = 3.0; c.radial_segments = 14
	_dump("cyl", c, out)
	var c0 := CylinderMesh.new()
	c0.top_radius = 0.0; c0.bottom_radius = 2.0; c0.height = 3.0; c0.radial_segments = 18; c0.rings = 1; c0.cap_bottom = false
	_dump("cone", c0, out)
	var t := TorusMesh.new()
	t.inner_radius = 2.0; t.outer_radius = 3.0; t.rings = 28; t.ring_segments = 10
	_dump("torus", t, out)
	var b := BoxMesh.new()
	b.size = Vector3(2, 3, 4)
	_dump("box", b, out)
	var b2 := BoxMesh.new()
	b2.size = Vector3(2, 3, 4); b2.subdivide_width = 2; b2.subdivide_height = 1; b2.subdivide_depth = 3
	_dump("boxsub", b2, out)
	var q := QuadMesh.new()
	q.size = Vector2(2, 3)
	_dump("quad", q, out)
	var p := PlaneMesh.new()
	p.size = Vector2(2, 3); p.subdivide_width = 2; p.subdivide_depth = 1
	_dump("plane", p, out)
	var poly := PackedVector2Array([Vector2(0, 0), Vector2(4, -1), Vector2(6, 2), Vector2(3, 1), Vector2(2, 5), Vector2(-1, 3)])
	out.append("poly " + " ".join(Array(Geometry2D.triangulate_polygon(poly)).map(func(x): return str(x))))
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	quit()
