extends SceneTree
## The baker's port (step 6c), stage 1: a part's 3D model as Godot builds it (UnitModels, the creature kit,
## the .glb parts), written out as triangles, so the Lobster baker can render the same geometry and its
## bakes be compared with Godot's. Each part in a race's colours (the team key for the team channel).
## Writes <out>/<part id>.mesh: "mat <texture png | -> [scale x y, offset x y, triplanar] @<albedo> #<triangles>"
## lines, and <part id>.bin: their triangles' vertices in order, 11 little-endian floats each ("x y z nx ny nz r g b
## u v" in the model's space, Godot's: y up; the albedo colour); the textures as tex<n>.png beside them.
##   godot --headless --path . --script res://tests/lobster_spike/mesh_export.gd -- <out dir> "<prompt>" [part id ...]
## Library mode (`library` for the prompt): every modelled part, with each material's colour as a channel of
## the race's colours ("ch skin m.r m.g m.b b.r b.g b.b": albedo = m x the channel's colour + b, per component)
## or fixed ("ch - r g b"), found by building it three times with different colours in the race channels. So
## the Lobster baker can bake any race's parts in its colours (`mat` lines then carry a `ch` part).

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitModels := preload("res://scenes/art_pixel/unit_models.gd")
const CreatureKit := preload("res://scenes/art_pixel/creature_kit.gd")
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
var _albedos := []    # each material's albedo, in the order written (library mode: matched across builds)
var _floats := PackedFloat32Array()   # the vertices, 11 floats each (written to <id>.bin)
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
			_albedos.append(c)
			var mat = _material(mi, s)
			var use_vc: bool = mat is StandardMaterial3D and mat.vertex_color_use_as_albedo   # (as Godot: vertex colours only when asked)
			var uvs = arr[Mesh.ARRAY_TEX_UV]
			var order: Array = Array(idx) if idx != null and idx.size() > 0 else range(v.size())
			var tris := order.size() / 3
			out.append("mat " + _texture(mi, s) + " @%d" % (_albedos.size() - 1) + " #%d" % tris)
			for k in range(0, tris * 3):
				var i: int = order[k]
				var p: Vector3 = t * v[i]
				var nn: Vector3 = (nb * (n[i] if n.size() > i else Vector3.UP)).normalized()
				var cc: Color = c * (cols[i] if use_vc and cols != null and cols.size() > i else Color.WHITE)
				var uv: Vector2 = uvs[i] if uvs != null and uvs.size() > i else Vector2.ZERO
				_floats.append_array([p.x, p.y, p.z, nn.x, nn.y, nn.z, cc.r, cc.g, cc.b, uv.x, uv.y])


## The race channels (what varies from race to race); the rest of the colours are the palette's fixed materials.
const CHANNELS := ["skin", "skin2", "skin3", "skin4", "cloth", "cloth2", "team"]


func _sentinels(seed_value: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var out := {}
	for ch in CHANNELS:
		out[ch] = Color(r.randf_range(0.15, 0.85), r.randf_range(0.15, 0.85), r.randf_range(0.15, 0.85))
	return out


## Which channel a material's albedo follows across three builds, and how (m, b per component); or fixed.
func _channel(alb: Array, sent: Array) -> String:
	if alb[0].is_equal_approx(alb[1]) and alb[1].is_equal_approx(alb[2]):
		return "ch - %.4f %.4f %.4f" % [alb[0].r, alb[0].g, alb[0].b]
	var best := ""
	var best_err := 1e9
	for ch in CHANNELS:
		var m := []
		var b := []
		var err := 0.0
		for k in 3:
			var a0: float = alb[0][k]
			var a1: float = alb[1][k]
			var s0: float = sent[0][ch][k]
			var s1: float = sent[1][ch][k]
			var mk := (a0 - a1) / (s0 - s1) if absf(s0 - s1) > 1e-4 else 0.0
			var bk := a0 - mk * s0
			m.append(mk)
			b.append(bk)
			err += absf(mk * sent[2][ch][k] + bk - alb[2][k])
		if err < best_err:
			best_err = err
			best = "ch %s %.4f %.4f %.4f %.4f %.4f %.4f" % [ch, m[0], m[1], m[2], b[0], b[1], b[2]]
	if best_err > 0.03:
		print("  (a material isn't linear in any channel: %.3f off; kept as its nearest)" % best_err)
	return best


func _save_bin(dir: String, id: String) -> void:
	var f := FileAccess.open(dir.path_join(id + ".bin"), FileAccess.WRITE)
	f.store_buffer(_floats.to_byte_array())


func _library(dir: String, lib) -> void:
	var models := UnitModels.new()
	var base := {}
	for k in lib.palettes.materials:
		base[k] = Color(lib.palettes.materials[k])
	var sent := [_sentinels(1), _sentinels(2), _sentinels(3)]
	var ids: Array = lib.parts.keys()
	ids.sort()
	var n := 0
	for id in ids:
		if not models.has(id):
			continue
		var outs := []
		var albs := []
		for k in 3:
			var cols := base.duplicate()
			cols.merge(sent[k], true)
			var spec: Dictionary = models.build(id, cols)
			var out := PackedStringArray()
			_albedos = []
			_floats = PackedFloat32Array()
			_write(spec.node, out)
			if k == 0:
				_save_bin(dir, id)
			spec.node.free()
			if spec.has("front") and spec.front != null:
				spec.front.free()
			outs.append(out)
			albs.append(_albedos.duplicate())
		if albs[0].size() != albs[1].size() or albs[0].size() != albs[2].size():
			print("skip %s (its builds differ)" % id)
			continue
		var lines: PackedStringArray = outs[0]
		for i in lines.size():
			if lines[i].begins_with("mat "):
				var at := int(lines[i].get_slice("@", 1).get_slice(" ", 0))
				lines[i] = lines[i].get_slice(" @", 0) + " #" + lines[i].get_slice("#", 1) + " | " + _channel([albs[0][at], albs[1][at], albs[2][at]], sent)
		var f := FileAccess.open(dir.path_join(id + ".mesh"), FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
		n += 1
	print("library: %d parts" % n)


func _init() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var dir: String = args[0]
	_dir = dir
	DirAccess.make_dir_recursive_absolute(dir)
	var lib = DataLib.new()
	if args[1] == "library":
		_library(dir, lib)
		quit()
		return
	var race: Dictionary = Generator.new(lib).generate(args[1], DataLib.load_rules("default"))
	var colours := _colours(lib, race)
	var ids: Array = args.slice(2).filter(func(a): return not a.begins_with("stage:"))
	for a in args.slice(2):   # stage:<res path>: a staged data file first (the concept parts it brings: trade carts)
		if a.begins_with("stage:"):
			CreatureKit.stage(lib, a.trim_prefix("stage:"))
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
		_floats = PackedFloat32Array()
		_write(node, out)
		_save_bin(dir, id)
		var f := FileAccess.open(dir.path_join(id + ".mesh"), FileAccess.WRITE)
		f.store_string("\n".join(out) + "\n")
		print("%s: %d triangles" % [id, out.size() - 1])
		holder.remove_child(node)
		node.free()
	quit()
