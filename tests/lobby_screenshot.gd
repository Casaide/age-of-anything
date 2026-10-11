extends SceneTree
## Captures the lobby: the title menu, or the battle setup with both armies mustered.
## Run (needs a display): godot --path . --script res://tests/lobby_screenshot.gd -- out.png [menu|setup] ["prompt A" "prompt B"]

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
		if args.size() > 3:
			lobby._regenerate(0)
			lobby._regenerate(1)
		while lobby.sides[0].layer.get_child_count() == 0 or lobby.sides[1].layer.get_child_count() == 0 or lobby.baking:
			await process_frame
	for f in 30:
		await process_frame
	root.get_texture().get_image().save_png(args[0])
	print("saved ", args[0])
	quit()
