extends SceneTree
## The baker's port (step 6c), stage 1: a part's 3D model as Godot builds it (UnitModels, the creature kit,
## the .glb parts), written out as triangles, so the Lobster baker can render the same geometry and its
## bakes be compared with Godot's. Each part in a race's colours (the team key for the team channel).
## Writes <out>/<part id>.mesh: "tri" lines of three vertices, each "x y z nx ny nz r g b" in the model's
## space (Godot's: y up), the material's albedo, and the bake camera's settings on a "cam" line.
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
	var sk: Array = lib.palettes.skins[race.units[0].recipe.skin]
	c.skin = Color(sk[0])
	c.skin2 = Color(sk[1])
	for i in range(2, sk.size()):
		c["skin%d" % (i + 1)] = Color(sk[i])
	var cloth: Array = lib.families[race.family].cloth
	c.cloth = Color(cloth[0])
	c.cloth2 = Color(cloth[1])
	return PartShape.team_neutral(c)


func _albedo(mi: MeshInstance3D, s: int) -> Color:
	var m = mi.get_surface_override_material(s)
	if m == null:
		m = mi.material_override
	if m == null and mi.mesh:
		m = mi.mesh.surface_get_material(s)
	if m is StandardMaterial3D:
		return m.albedo_color
	return Color(1, 0, 1)


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
			var order: Array = Array(idx) if idx != null and idx.size() > 0 else range(v.size())
			for k in range(0, order.size() - 2, 3):
				var line := "tri"
				for j in 3:
					var i: int = order[k + j]
					var p: Vector3 = t * v[i]
					var nn: Vector3 = (nb * (n[i] if n.size() > i else Vector3.UP)).normalized()
					var cc: Color = c * (cols[i] if cols != null and cols.size() > i else Color.WHITE)
					line += " %.4f %.4f %.4f %.3f %.3f %.3f %.3f %.3f %.3f" % [p.x, p.y, p.z, nn.x, nn.y, nn.z, cc.r, cc.g, cc.b]
				out.append(line)


func _init() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var dir: String = args[0]
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
