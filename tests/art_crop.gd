extends SceneTree
## Captures the pixel-art scene at 3x, centred on a tile point (for close looks at a detail).
## Run: godot --path . --script res://tests/art_crop.gd -- out.png tile_x tile_y ["prompt A" "prompt B"]
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var s = load("res://scenes/art_pixel.tscn").instantiate()
	if args.size() > 4:
		s.prompts = [args[3], args[4]]
	root.add_child(s)
	s.set_process_unhandled_input(false)
	while not s.built:
		await process_frame
	s.set_zoom(3)
	s.cam.position = s.Iso.to_screen(float(args[1]) * 1000, float(args[2]) * 1000) * s.ART_SCALE
	for f in 40:
		await process_frame
	root.get_texture().get_image().save_png(args[0])
	quit()
