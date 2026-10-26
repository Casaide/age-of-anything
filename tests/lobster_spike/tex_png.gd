extends SceneTree
## The model kit's textures (step 6d): every authored SVG texture (assets/art/textures/, and each mod's
## textures/) rasterised as UnitModels.tex does (scale 1) and saved as a png beside the Lobster port, which
## can't read SVG. Run again after a texture changes.
##   godot --headless --path . --script res://tests/lobster_spike/tex_png.gd


func _png(svg: String, out: String) -> void:
	var img := Image.new()
	img.load_svg_from_string(FileAccess.get_file_as_string(svg), 1.0)
	img.save_png(out)


func _init() -> void:
	var dir := "res://tests/lobster_spike/textures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var n := 0
	for f in DirAccess.get_files_at("res://assets/art/textures/"):
		if f.ends_with(".svg"):
			_png("res://assets/art/textures/" + f, dir.path_join(f.get_basename() + ".png"))
			n += 1
	for m in DirAccess.get_directories_at("res://mods/"):
		var td := "res://mods/%s/textures/" % m
		if DirAccess.dir_exists_absolute(td):
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir.path_join(m)))
			for f in DirAccess.get_files_at(td):
				if f.ends_with(".svg"):
					_png(td + f, dir.path_join(m).path_join(f.get_basename() + ".png"))
					n += 1
	print("%d textures" % n)
	quit()
