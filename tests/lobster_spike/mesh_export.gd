extends SceneTree
## The baker's port (step 6c), stage 1: a part's 3D model as Godot builds it (UnitModels, the creature kit,
## the .glb parts), written out as triangles, so the Lobster baker can render the same geometry and its
## bakes be compared with Godot's. Each part in a race's colours (the team key for the team channel).
## Writes <out>/<part id>.mesh: "mat <texture png | -> [scale x y, offset x y, triplanar]" lines, each followed by
## its "tri" lines of three vertices, "x y z nx ny nz r g b u v" in the model's space (Godot's: y up), the
## albedo colour; the textures as tex<n>.png beside them.
##   godot --headless --path . --script res://tests/lobster_spike/mesh_export.gd -- <out dir> "<prompt>" [part id ...]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitModels := preload("res://scenes/art_pixel/unit_models.gd")
const PartShape := preload("res://src/part_shape.gd")
const Baker := preload("res://src/view/art/bake/baker.gd")


func _colours(lib, race: Dictionary) -> Dictionary:
	var c := {}
	for k in lib.palettes.materials:
		c[k] = Color(lib.palettes.materials[k])
	var sk: Array = lib.palettes.skins[race.units[1].recipe.skin]   # (the spearman's, as bake_check takes)
	c.skin = Color(sk[0])
	c.skin2 = Color(sk[1])
	for i in range(2, sk.size()):
		c["skin%d" % (i + 1)] = Color(sk[i])
	var cloth: Array = lib.families[race.family].cloth
	c.cloth = Color(cloth[0])
	c.cloth2 = Color(cloth[1])
	return PartShape.team_neutral(c)


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


var _textures := {}   # texture -> its file name in the out dir
var _dir := ""


## A material's albedo texture saved beside the meshes (once), and how it's tiled; "-" for none.
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


func _write(node: Node3D, out: PackedStringArray) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible or mi.mesh == null:
			continue
		var t := Transform3D()   # (up to the model's root by hand: it isn't in the tree yet in _init)
		var up: Node = mi
		while up != null and up != node.get_parent():
			t = (up as Node3D).transform * t
			up = up.get_parent()
		var nb := t.basis.inverse().transposed()
		var mesh: Mesh = mi.mesh
		if mi.skin != null or mi.get_skeleton_path() != NodePath(""):   # a skinned .glb part: its vertices as posed now
			var posed = mi.bake_mesh_from_current_skeleton_pose()
			if posed != null:
				mesh = posed
		for s in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var cols = arr[Mesh.ARRAY_COLOR]
			var idx = arr[Mesh.ARRAY_INDEX]
			var c := _albedo(mi, s)
			var mat = _material(mi, s)
			var use_vc: bool = mat is StandardMaterial3D and mat.vertex_color_use_as_albedo   # (as Godot: vertex colours only when asked)
			var uvs = arr[Mesh.ARRAY_TEX_UV]
			out.append("mat " + _texture(mi, s))
			var order: Array = Array(idx) if idx != null and idx.size() > 0 else range(v.size())
			for k in range(0, order.size() - 2, 3):
				var line := "tri"
				for j in 3:
					var i: int = order[k + j]
					var p: Vector3 = t * v[i]
					var nn: Vector3 = (nb * (n[i] if n.size() > i else Vector3.UP)).normalized()
					var cc: Color = c * (cols[i] if use_vc and cols != null and cols.size() > i else Color.WHITE)
					var uv: Vector2 = uvs[i] if uvs != null and uvs.size() > i else Vector2.ZERO
					line += " %.4f %.4f %.4f %.3f %.3f %.3f %.3f %.3f %.3f %.4f %.4f" % [p.x, p.y, p.z, nn.x, nn.y, nn.z, cc.r, cc.g, cc.b, uv.x, uv.y]
				out.append(line)


func _init() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var dir: String = args[0]
	_dir = dir
	DirAccess.make_dir_recursive_absolute(dir)
	var lib = DataLib.new()
	var race: Dictionary = Generator.new(lib).generate(args[1], DataLib.load_rules("default"))
	var colours := _colours(lib, race)
	var ids: Array = args.slice(2)
	if ids.is_empty():   # the race's spearman's parts
		var r: Dictionary = race.units[1].recipe
		ids = [r.body, r.head] + r.parts.values().filter(func(x): return x is String)
	var models := UnitModels.new()
	var holder := Node3D.new()
	root.add_child(holder)
	for id in ids:
		if not models.has(id):
			print("skip %s (no model)" % id)
			continue
		var spec: Dictionary = models.build(id, colours)
		var node: Node3D = spec.node
		holder.add_child(node)
		var out := PackedStringArray()
		out.append("cam %.3f %.3f %.4f" % [35.0, 30.0, Baker.PX_PER_UNIT])
		_write(node, out)
		var f := FileAccess.open(dir.path_join(id + ".mesh"), FileAccess.WRITE)
		f.store_string("\n".join(out) + "\n")
		print("%s: %d triangles" % [id, out.size() - 1])
		holder.remove_child(node)
		node.free()
	quit()
