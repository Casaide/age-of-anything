extends SceneTree
## The mouse cursors side by side on grass, at 1x (as played) and 4x (to judge the drawing).
## Run: godot --headless --path . --script res://tests/cursor_sheet.gd -- out.png

const Cursors := preload("res://src/view/art/cursors.gd")


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var names: Array = Cursors.HOTSPOT.keys()
	var sheet := Image.create(names.size() * 140 + 20, 200, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#56782e"))
	for k in names.size():
		var svg := FileAccess.get_file_as_string(Cursors.DIR + names[k] + ".svg")
		for s in [[1.0, Vector2i(20 + k * 140, 20)], [4.0, Vector2i(20 + k * 140, 64)]]:
			var img := Image.new()
			img.load_svg_from_string(svg, s[0])
			img.convert(Image.FORMAT_RGBA8)
			sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), s[1])
	sheet.save_png(out)
	print("saved ", out)
	quit()
