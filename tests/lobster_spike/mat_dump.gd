extends SceneTree
## The buildings' materials as Godot makes them (src/view/art/bake/materials.gd), for mat_check.lobster: each
## material's properties as one line of text (<out>/props.txt; matte off and on) and its textures' images
## (<out>/<name>_albedo.png, <out>/<name>_normal.png), plus a few Materials.flat ones.
##   godot --headless --path . --script res://tests/lobster_spike/mat_dump.gd -- <out dir>

const Materials := preload("res://src/view/art/bake/materials.gd")
const NAMES := ["thatch", "wood", "stone", "mud", "tin", "brick", "plaster", "terracotta", "terracotta_dark", "felt",
	"weave", "grass", "swamp", "frog"]


func _f(x: float) -> String:
	return "%.6f" % x


func _v(v) -> String:
	return "%s,%s,%s" % [_f(v.x), _f(v.y), _f(v.z)]


func _c(c: Color) -> String:
	return "%s,%s,%s,%s" % [_f(c.r), _f(c.g), _f(c.b), _f(c.a)]


func _tex(name: String, t: Texture2D) -> String:
	if t == null:
		return "-"
	if t is NoiseTexture2D:
		return "noise:%dx%d" % [t.width, t.height]
	if name == "thatch":
		return "thatch"
	return Materials.AUTHORED[name][0]


func _line(name: String, matte: bool, m: StandardMaterial3D) -> String:
	return "%s matte=%d albedo=%s roughness=%s metallic=%s metallic_specular=%s clearcoat_enabled=%d clearcoat=%s normal_enabled=%d normal_scale=%s uv1_scale=%s uv1_offset=%s triplanar=%d world_triplanar=%d triplanar_sharpness=%s texture_filter=%d albedo_tex=%s normal_tex=%s" % [
		name, int(matte), _c(m.albedo_color), _f(m.roughness), _f(m.metallic), _f(m.metallic_specular),
		int(m.clearcoat_enabled), _f(m.clearcoat), int(m.normal_enabled), _f(m.normal_scale), _v(m.uv1_scale),
		_v(m.uv1_offset), int(m.uv1_triplanar), int(m.uv1_world_triplanar), _f(m.uv1_triplanar_sharpness),
		m.texture_filter, _tex(name, m.albedo_texture), _tex(name, m.normal_texture)]


func _image(t: Texture2D) -> Image:
	# NoiseTexture2D makes its image on a worker thread: wait for it
	for i in 600:
		var img := t.get_image()
		if img != null:
			return img
		await process_frame
	assert(false, "texture never generated")
	return null


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var lines := PackedStringArray()
	for matte in [false, true]:
		var mats := Materials.new()
		mats.matte = matte
		for name in NAMES:
			var m: StandardMaterial3D = mats.get_mat(name)
			lines.append(_line(name, matte, m))
			if matte:
				continue
			for slot in ["albedo", "normal"]:
				var t: Texture2D = m.albedo_texture if slot == "albedo" else m.normal_texture
				if t == null:
					continue
				var img: Image = await _image(t)
				img = img.duplicate()
				img.clear_mipmaps()
				img.convert(Image.FORMAT_RGBA8)
				img.save_png(out.path_join("%s_%s.png" % [name, slot]))
	for f in [[Color(0.2, 0.4, 0.6), 0.6, 0.0], [Color(0.9, 0.1, 0.3), 0.3, 0.8], [Color(1, 1, 1), 1.0, 0.0]]:
		var m := Materials.flat(f[0], f[1], f[2])
		lines.append(_line("flat:%s" % _c(f[0]), false, m))
	var fa := FileAccess.open(out.path_join("props.txt"), FileAccess.WRITE)
	fa.store_string("\n".join(lines) + "\n")
	fa.close()
	print("%d materials" % lines.size())
	quit()


func _init() -> void:
	_run.call_deferred()
