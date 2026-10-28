extends SceneTree
## The buildings' 3D models as Godot builds them (src/view/art/bake/models.gd), written out for
## building_check.lobster to hold the Lobster port (model/buildings*.lobster) to. A case is ":"-separated:
##   model:<name>[:<seed>]           models.call(name, team) (flowers takes the seed)
##   building:<type>:<arch>[:<opt>]  models.building(type, arch, team)
##   look:<type>:<arch>:<name>[:<opt>]  models.look(type, arch, name, team)
## options: "diag" (gate_span 3 x sqrt 2), "r<k>" (wall_rescale k), "ruin<s>" (a building broken up to stage s by
## ruin.gd, seeded by "<arch>:<type>"; hidden meshes are left out). The models' generator starts at seed 0.
## Writes <out>/<case, ":" as "_">.txt (each part's meshes: triangles, material name or flat colour, emission,
## metadata; non-mesh nodes' metadata; the spec's points) and .bin (corner and normal, 6 floats a vertex).
##   godot --headless --path . --script res://tests/lobster_spike/building_export.gd -- <out dir> <case>...

const Models := preload("res://src/view/art/bake/models.gd")
const Ruin := preload("res://src/view/art/bake/ruin.gd")
const Rng := preload("res://src/rng.gd")
const TEAM := Color(0.85, 0.2, 0.6)

var models
var _floats := PackedFloat32Array()


func _mat_name(m) -> String:
	for k in models.mats.cache:
		if models.mats.cache[k] == m:
			return k
	return "-"


func _v(v: Vector3) -> String:
	return "%.5f %.5f %.5f" % [v.x, v.y, v.z]


func _meta(n: Node) -> String:
	var out := ""
	if n.has_meta("parapet"):
		out += " parapet " + _v(n.get_meta("parapet"))
		if n.has_meta("about"):
			out += " about " + _v(n.get_meta("about"))
		if n.has_meta("roof"):
			out += " roof"
	if n.has_meta("gate_part"):
		out += " gate_part %d gate_centre %s" % [n.get_meta("gate_part"), _v(n.get_meta("gate_centre"))]
	return out


func _write(node: Node3D, out: PackedStringArray) -> void:
	for n in [node] + node.find_children("*", "Node3D", true, false):
		if not (n is MeshInstance3D):
			var m := _meta(n)
			if m != "":
				out.append("n" + m)
			continue
		var mi: MeshInstance3D = n
		if not mi.visible:
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
			var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var idx = arr[Mesh.ARRAY_INDEX]
			var mat = mi.material_override
			var order: Array = Array(idx) if idx != null and idx.size() > 0 else range(v.size())
			var tris := order.size() / 3
			var c: Color = mat.albedo_color
			var e := Vector3.ZERO
			if mat.emission_enabled:
				e = Vector3(mat.emission.r, mat.emission.g, mat.emission.b) * mat.emission_energy_multiplier
			out.append("m %d %s %.5f %.5f %.5f %s%s" % [tris, _mat_name(mat), c.r, c.g, c.b, _v(e), _meta(mi)])
			for k in tris * 3:
				var i: int = order[k]
				var p: Vector3 = t * v[i]
				var q: Vector3 = (nb * nn[i]).normalized()
				_floats.append_array([p.x, p.y, p.z, q.x, q.y, q.z])


func _build(case: String) -> Variant:
	var a := case.split(":")
	models = Models.new()
	models.rng.seed = 0
	for o in a.slice(4 if a[0] == "look" else 3):
		if o == "diag":
			models.gate_span = 3.0 * sqrt(2.0)
		elif o.begins_with("r") and not o.begins_with("ruin"):
			models.wall_rescale = float(o.substr(1))
	var ruin := -1
	for o in a.slice(4 if a[0] == "look" else 3):
		if o.begins_with("ruin"):
			ruin = int(o.substr(4))
	if ruin >= 0 and a[0] == "building":
		var spec: Dictionary = models.building(a[1], a[2], TEAM)
		Ruin.apply(spec.body, ruin, Rng.hash_string("%s:%s" % [a[2], a[1]]), models)
		return spec
	match a[0]:
		"model":
			if a[1] == "flowers":
				return models.flowers(int(a[2]))
			return models.call(a[1], TEAM)
		"building":
			return models.building(a[1], a[2], TEAM)
		"look":
			return models.look(a[1], a[2], a[3], TEAM)
	return null


func _init() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var dir: String = args[0]
	DirAccess.make_dir_recursive_absolute(dir)
	var holder := Node3D.new()
	root.add_child(holder)
	for case in args.slice(1):
		var got: Variant = _build(case)
		var out := PackedStringArray()
		_floats = PackedFloat32Array()
		var parts := []
		if got is Node3D:
			parts = [["body", got]]
		else:
			for k in ["body", "banner", "vane", "open", "icon"]:
				if got.has(k):
					parts.append([k, got[k]])
			if got.has("arms"):
				for i in got.arms.size():
					parts.append(["arm%d" % i, got.arms[i]])
			var keys: Array = got.keys()
			keys.sort()
			for k in keys:
				var val = got[k]
				if val is Vector3:
					out.append("p %s %s" % [k, _v(val)])
				elif val is Color:
					out.append("c %s %.5f %.5f %.5f" % [k, val.r, val.g, val.b])
				elif val is Array and k in ["lights", "doorway"]:
					var row: String = "a " + str(k)
					for p in val:
						row += " " + _v(p)
					out.append(row)
		for p in parts:
			out.append("part " + p[0])
			holder.add_child(p[1])
			_write(p[1], out)
			holder.remove_child(p[1])
			p[1].free()
		var name: String = case.replace(":", "_")
		FileAccess.open(dir.path_join(name + ".bin"), FileAccess.WRITE).store_buffer(_floats.to_byte_array())
		FileAccess.open(dir.path_join(name + ".txt"), FileAccess.WRITE).store_string("\n".join(out) + "\n")
		print("%s: %d lines" % [case, out.size()])
	quit()
