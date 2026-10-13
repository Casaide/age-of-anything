extends SceneTree
## How long the lobby takes to stand a new army up, cold (no unit part loads from the disk bake
## cache, so every part the race needs and no earlier one has made renders; buildings and props load): both sides rolled on entry, then your
## side rerolled (the AI's left alone). Prints the lobby's own "Lobby bake: N ms" lines too.
## Then, unless "quick", how long the tech tree page takes to fill and a match start's loader.
## Run (needs a display):
##   godot --audio-driver Dummy --always-on-top --path . --script res://tests/lobby_bake_time.gd -- ["prompt A" "prompt B" "reroll prompt"] [quick] [idle:<seconds>]

const BakeCache := preload("res://src/view/art/bake_cache.gd")


func _initialize() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var quick := "quick" in args
	var idle := 0.0   # idle:<seconds>: the players choose that long before the tech tree opens
	for a in args:
		if String(a).begins_with("idle:"):
			idle = float(String(a).get_slice(":", 1))
	args = args.filter(func(a): return a != "quick" and not String(a).begins_with("idle:"))
	var prompts: Array = args if args.size() >= 3 else ["centaur romans", "sewer rats with cheese hammers", "angry swamp frogs with reed spears"]
	BakeCache.cold_parts = true
	var lobby = load("res://scenes/match_setup.tscn").instantiate()
	root.add_child(lobby)
	for f in 5:
		await process_frame
	lobby.sides[0].field.text = prompts[0]
	lobby.sides[1].field.text = prompts[1]
	lobby.sides[0].reroll = 0   # (the dice rolled a reroll on entry: the same races every run)
	lobby.sides[1].reroll = 0
	lobby._open_setup()
	var t0 := Time.get_ticks_msec()
	lobby._regenerate(0)
	lobby._regenerate(1)
	await _stood(lobby)
	print("TIME both armies standing: %d ms" % (Time.get_ticks_msec() - t0))
	for f in 20:
		await process_frame
	t0 = Time.get_ticks_msec()
	lobby.sides[0].field.text = prompts[2]
	lobby.sides[0].reroll = 0
	lobby._regenerate(0)
	await _stood(lobby)
	print("TIME reroll, your army standing: %d ms" % (Time.get_ticks_msec() - t0))
	if quick:
		quit()
		return
	if idle > 0.0:
		await create_timer(idle).timeout
	t0 = Time.get_ticks_msec()
	await lobby._open_tree(0)
	while lobby.tree_page.has_method("is_loading") and lobby.tree_page.is_loading():
		await process_frame
	print("TIME tech tree filled: %d ms" % (Time.get_ticks_msec() - t0))
	lobby.tree_page.close()
	t0 = Time.get_ticks_msec()
	lobby._play()
	var view = null
	while view == null or view.world == null or view.is_loading():
		await process_frame
		view = current_scene if current_scene != lobby and is_instance_valid(current_scene) else null
	print("TIME start to match: %d ms" % (Time.get_ticks_msec() - t0))
	quit()


func _stood(lobby) -> void:
	await process_frame
	while lobby.baking or lobby.sides.any(func(s): return s.dirty_at > 0.0 or s.forging):
		await process_frame
