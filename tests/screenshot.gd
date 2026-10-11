extends SceneTree
## Opens the Race Lab, optionally sets the two prompts, waits for the art to bake,
## then saves a PNG.
## Run (needs a display): godot --path . --script res://tests/screenshot.gd -- out.png "prompt A" "prompt B"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://race_lab.png"
	var lab = load("res://scenes/race_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	await process_frame
	for i in 2:
		if args.size() > i + 1:
			lab.sides[i].prompt.text = args[i + 1]
			lab._generate(i, false)
	while lab.kit_busy or lab.sides.any(func(s): return s.race.is_empty() or s.baked != s.race.key):
		await process_frame
	for f in 90:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
