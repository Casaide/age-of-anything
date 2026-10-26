extends SceneTree
## The props' 3D models as Godot builds them (prop_models.gd, tree_models.gd, town_props.gd, bridge_models.gd),
## written out as triangles in mesh_export.gd's format, so prop_check.lobster can hold the Lobster ports to them.
## A case is the builder's name and its arguments, ":" between: "reed_clump:12:1.0:2", "tree:5:pine:1:0",
## "pile:wood:3:b", "bridge:3:4:2:1:1", "stone_mesh:7:1" (the mesh alone, cut when 1, in a white plain material).
## Writes <out>/<case with ":" as "_">.mesh and .bin (and the textures as tex<n>.png beside them).
##   godot --headless --path . --script res://tests/lobster_spike/prop_export.gd -- <out dir> <case>...

const UnitModels := preload("res://scenes/art_pixel/unit_models.gd")
const PropModels := preload("res://scenes/art_pixel/prop_models.gd")
const TreeModels := preload("res://scenes/art_pixel/tree_models.gd")
const TownProps := preload("res://scenes/art_pixel/town_props.gd")
const BridgeModels := preload("res://scenes/art_pixel/bridge_models.gd")

var _textures := {}   # texture -> its file name in the out dir
var _floats := PackedFloat32Array()   # the vertices, 11 floats each (written to <case>.bin)
var _dir := ""
var _mats := 0


func _material(mi: MeshInstance3D, s: int):
	var m = mi.get_surface_override_material(s)
	if m == null:
		m = mi.material_override
	if m == null and mi.mesh:
		m = mi.mesh.surface_get_material(s)
	return m


func _albedo(mi: MeshInstance3D, s: int) -> Color:
	var m = _material(mi, s)
	if m is StandardMaterial3D:
		return m.albedo_color
	return Color(1, 0, 1)


func _texture(mi: MeshInstance3D, s: int) -> String:
	var m = _material(mi, s)
	if not (m is StandardMaterial3D) or m.albedo_texture == null:
		return "-"
	var t: Texture2D = m.albedo_texture
	if not _textures.has(t):
		var name := "tex%d.png" % _textures.size()
		var img := t.get_image()
		if img.is_compressed():
			img.decompress()
		img.save_png(_dir.path_join(name))
		_textures[t] = name
	var sc: Vector3 = m.uv1_scale
	var off: Vector3 = m.uv1_offset
	return "%s %.4f %.4f %.4f %.4f %d" % [_textures[t], sc.x, sc.y, off.x, off.y, 1 if m.uv1_triplanar else 0]


## mesh_export.gd's _write: every visible mesh's triangles, placed by its transforms up to the root.
func _write(node: Node3D, out: PackedStringArray) -> void:
	for mi in [node] + node.find_children("*", "MeshInstance3D", true, false):
		if not (mi is MeshInstance3D) or not mi.visible or mi.mesh == null:
			continue
		var t := Transform3D()
		var up: Node = mi
		while up != null and up != node.get_parent():
			t = (up as Node3D).transform * t
			up = up.get_parent()
		var nb := t.basis.inverse().transposed()
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var cols = arr[Mesh.ARRAY_COLOR]
			var idx = arr[Mesh.ARRAY_INDEX]
			var c := _albedo(mi, s)
			var mat = _material(mi, s)
			var use_vc: bool = mat is StandardMaterial3D and mat.vertex_color_use_as_albedo
			var uvs = arr[Mesh.ARRAY_TEX_UV]
			var order: Array = Array(idx) if idx != null and idx.size() > 0 else range(v.size())
			var tris := order.size() / 3
			out.append("mat " + _texture(mi, s) + " @%d" % _mats + " #%d" % tris)
			_mats += 1
			for k in range(0, tris * 3):
				var i: int = order[k]
				var p: Vector3 = t * v[i]
				var nn: Vector3 = (nb * (n[i] if n.size() > i else Vector3.UP)).normalized()
				var cc: Color = c * (cols[i] if use_vc and cols != null and cols.size() > i else Color.WHITE)
				var uv: Vector2 = uvs[i] if uvs != null and uvs.size() > i else Vector2.ZERO
				_floats.append_array([p.x, p.y, p.z, nn.x, nn.y, nn.z, cc.r, cc.g, cc.b, uv.x, uv.y])


func _arg(a: PackedStringArray, i: int, d):
	if a.size() <= i:
		return d
	if d is int:
		return int(a[i])
	if d is float:
		return float(a[i])
	return a[i]


func _build(case: String) -> Node3D:
	var a := case.split(":")
	match a[0]:
		"reed_clump": return PropModels.new().reed_clump(_arg(a, 1, 0), _arg(a, 2, 1.0), _arg(a, 3, 0))
		"bug_bush": return PropModels.new().bug_bush(_arg(a, 1, 0), _arg(a, 2, 0))
		"grass_tuft": return PropModels.new().grass_tuft(_arg(a, 1, 0))
		"field_stones": return PropModels.new().field_stones(_arg(a, 1, 0))
		"lily_pads": return PropModels.new().lily_pads(_arg(a, 1, 0))
		"stone_mesh":
			var mi := MeshInstance3D.new()
			mi.mesh = PropModels.new().stone_mesh(_arg(a, 1, 0), _arg(a, 2, 0) == 1)
			mi.material_override = UnitModels.new().plain(Color.WHITE)
			return mi
		"boulders": return PropModels.new().boulders(_arg(a, 1, 0))
		"quarry": return PropModels.new().quarry(_arg(a, 1, 0), _arg(a, 2, 0), _arg(a, 3, "stone"))
		"carcass": return PropModels.new().carcass(_arg(a, 1, 0), _arg(a, 2, 0))
		"crops": return PropModels.new().crops(_arg(a, 1, 0))
		"paddy": return PropModels.new().paddy(_arg(a, 1, 0))
		"tree": return TreeModels.new().tree(_arg(a, 1, 0), _arg(a, 2, "broadleaf"), _arg(a, 3, 0), _arg(a, 4, 0))
		"pile": return TownProps.new().pile(_arg(a, 1, "food"), _arg(a, 2, 1), _arg(a, 3, "a"))
		"yard": return TownProps.new().yard(_arg(a, 1, 1), _arg(a, 2, 0))
		"garden": return TownProps.new().garden(_arg(a, 1, 1), _arg(a, 2, 0))
		"tether_post": return TownProps.new().tether_post()
		"bridge": return BridgeModels.new().bridge(_arg(a, 1, 0), _arg(a, 2, 1), _arg(a, 3, 0), _arg(a, 4, 0), _arg(a, 5, 1))
	return null


func _init() -> void:
	var args := Array(OS.get_cmdline_user_args())
	_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	var holder := Node3D.new()
	root.add_child(holder)
	for case in args.slice(1):
		var node := _build(case)
		if node == null:
			print("skip %s (no such prop)" % case)
			continue
		holder.add_child(node)
		var out := PackedStringArray()
		_floats = PackedFloat32Array()
		_mats = 0
		_write(node, out)
		var name: String = case.replace(":", "_")
		FileAccess.open(_dir.path_join(name + ".bin"), FileAccess.WRITE).store_buffer(_floats.to_byte_array())
		FileAccess.open(_dir.path_join(name + ".mesh"), FileAccess.WRITE).store_string("\n".join(out) + "\n")
		print("%s: %d meshes" % [case, out.size()])
		holder.remove_child(node)
		node.free()
	quit()
