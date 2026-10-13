extends SceneTree
## Captures the tech tree page: from the lobby (a side's banner button) or in a match.
## Run (needs a display):
##   godot --path . --script res://tests/tech_tree_screenshot.gd -- out.png [lobby|loader[:<frames>]|match:<seconds>] ["prompt A" "prompt B"] [scroll px] [node key]
## "loader": opened from the lobby as soon as the stages stand, shot while its loader is up.
## A node key (e.g. "u:spear@2", "r:fletching", "b:castle") hovers that node to show its card.
## "match:<seconds>": two bots play that long (stepped as fast as it goes), then player 1's page opens.

const Bot := preload("res://src/ai/bot.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var mode: String = args[1] if args.size() > 1 else "lobby"
	var prompts: Array = [args[2], args[3]] if args.size() > 3 else []
	var scroll := int(args[4]) if args.size() > 4 else 0
	var page: Control
	if mode == "lobby" or mode.begins_with("loader"):
		var lobby = load("res://scenes/match_setup.tscn").instantiate()
		root.add_child(lobby)
		for f in 5:
			await process_frame
		if not prompts.is_empty():
			lobby.sides[0].field.text = prompts[0]
			lobby.sides[1].field.text = prompts[1]
		lobby._open_setup()
		lobby._regenerate(0)
		lobby._regenerate(1)
		while lobby.baking or lobby.sides.any(func(s): return not lobby._stood(s)):   # the stages first, as a player would
			await process_frame
		await lobby._open_tree(0)
		page = lobby.tree_page
		if mode.begins_with("loader"):   # the page's loader, that many frames in (default 30)
			for f in (int(mode.get_slice(":", 1)) if ":" in mode else 30):
				await process_frame
			root.get_texture().get_image().save_png(out)
			print("saved ", out)
			quit()
			return
		while page.is_loading():
			await process_frame
		await create_timer(0.8).timeout   # (the loader fades out)
	else:
		var view = load("res://scenes/sim_debug.tscn").instantiate()
		if not prompts.is_empty():
			view.prompts = prompts
		view.vs_ai = true
		root.add_child(view)
		while view.world == null or view.baking:
			await process_frame
		view.set_process_unhandled_input(false)
		view.camera.set_process_unhandled_input(false)
		var bots := [Bot.new(0), Bot.new(1)]
		var ticks := int(mode.get_slice(":", 1)) * 20
		while view.world.tick < ticks and view.world.winner < 0:
			for b in bots:
				b.think(view.world)
			view.world.step()
			if view.world.tick % 100 == 0:   # let the view keep up
				await process_frame
		view.toggle_tech_tree()
		page = view.tech_tree
	for f in 20:
		await process_frame
	page._scroll.scroll_horizontal = scroll
	for f in 10:
		await process_frame
	if args.size() > 5:   # hover a node: its card
		var v: Control = page._views[args[5]]
		var ev := InputEventMouseMotion.new()
		ev.position = v.get_global_rect().get_center() + Vector2(0, -10)
		ev.global_position = ev.position
		root.push_input(ev)
		await create_timer(1.5).timeout
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
