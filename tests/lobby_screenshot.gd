extends SceneTree
## Captures the lobby: the title menu, or the battle setup with both armies mustered.
## Run (needs a display): godot --path . --script res://tests/lobby_screenshot.gd -- out.png [menu|setup|setup:<map_id>|forging[:<frames>]] ["prompt A" "prompt B"]
## forging: once both armies stand, throws your side's dice and shoots that many frames later
## (default 10): the die mid-tumble, the old army dimmed under the forge veil.
## start[:<frames>]: presses Start and shoots the match loader that many frames later (default 6).

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var lobby = load("res://scenes/match_setup.tscn").instantiate()
	root.add_child(lobby)
	for f in 5:
		await process_frame
	if args.size() < 2 or args[1] != "menu":
		if args.size() > 3:
			lobby.sides[0].field.text = args[2]
			lobby.sides[1].field.text = args[3]
		lobby._open_setup()
		if args.size() > 1 and args[1].begins_with("setup:"):
			lobby._set_map(lobby.MAPS.find(args[1].get_slice(":", 1)))
		if args.size() > 3:
			lobby._regenerate(0)
			lobby._regenerate(1)
		while lobby.sides[0].layer.get_child_count() == 0 or lobby.sides[1].layer.get_child_count() == 0 or lobby.baking:
			await process_frame
	else:   # the title screen: both armies on its hill
		while lobby.menu_layer.get_child_count() == 0 or lobby.baking:
			await process_frame
	for f in 30:
		await process_frame
	if args.size() > 1 and args[1].begins_with("start"):
		var t0 := Time.get_ticks_msec()
		lobby._play()
		for f in (int(args[1].get_slice(":", 1)) if ":" in args[1] else 6):
			await process_frame
		root.get_texture().get_image().save_png(args[0])
		print("saved ", args[0])
		var view = current_scene if current_scene != lobby else null
		while view == null or view.world == null or view.is_loading():
			await process_frame
			view = current_scene if current_scene != lobby else null
		print("Start to match: %d ms" % (Time.get_ticks_msec() - t0))
		quit()
		return
	if args.size() > 1 and args[1].begins_with("forging"):
		var d = lobby.sides[0].dice
		d.tumble()
		lobby._roll(0)
		for f in (int(args[1].get_slice(":", 1)) if ":" in args[1] else 10):
			await process_frame
	if lobby.setup.visible:   # does it fit? (the lobby is laid out for match_setup.gd's DESIGN)
		print("side panel needs ", lobby.sides[0].panel.get_combined_minimum_size(), ", the screen is ", lobby.get_viewport_rect().size)
	root.get_texture().get_image().save_png(args[0])
	print("saved ", args[0])
	quit()
