extends SceneTree
## Captures the pixel-art candidate at 2x (default) and 3x zoom, palette on.
## Run (needs a display): godot --path . --script res://tests/art_screenshot.gd -- out_dir ["prompt A" "prompt B"]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://art"
	DirAccess.make_dir_recursive_absolute(out)
	var s = load("res://scenes/art_pixel.tscn").instantiate()
	if args.size() > 2:
		s.prompts = [args[1], args[2]]
	root.add_child(s)
	s.set_process_unhandled_input(false)
	while not s.built:
		await process_frame
	for f in 60:
		await process_frame
	root.get_texture().get_image().save_png(out + "/pixel-2x.png")
	s.set_zoom(3)
	s.cam.position = s.Iso.to_screen(6200, 7200) * s.ART_SCALE
	for f in 30:
		await process_frame
	root.get_texture().get_image().save_png(out + "/pixel-3x.png")
	s.set_zoom(1)
	s.cam.position = s.Iso.to_screen(8000, 7000) * s.ART_SCALE
	for f in 30:
		await process_frame
	root.get_texture().get_image().save_png(out + "/pixel-1x.png")
	print("saved to ", out)
	quit()
