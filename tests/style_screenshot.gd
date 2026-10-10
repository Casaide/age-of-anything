extends SceneTree
## Captures the art-direction sampler: the grid, then each style full-window.
## Run (needs a display): godot --path . --script res://tests/style_screenshot.gd -- out_dir

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://styles"
	DirAccess.make_dir_recursive_absolute(out)
	var s = load("res://scenes/style_sampler.tscn").instantiate()
	root.add_child(s)
	s.set_process_unhandled_input(false)
	for f in 400:   # the high-fidelity panel bakes its sprites first
		await process_frame
	root.get_texture().get_image().save_png(out + "/all.png")
	for i in s.STYLES.size():
		s.show_one(i)
		for f in 45:
			await process_frame
		root.get_texture().get_image().save_png("%s/%d-%s.png" % [out, i + 1, s.STYLES[i].key])
	print("saved to ", out)
	quit()
