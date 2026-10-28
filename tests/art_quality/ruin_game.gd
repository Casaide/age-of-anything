extends "res://tests/sim_screenshot.gd"
## Destruction in the game (D-171, D-172): a house of side 1's through its broken-up stages as its hp
## drops, its fall under pixel dust, its ruin burning out, and a house laid over the ruin (which clears it).
## Pictures out_dir/fall_NN_<what>.png at play zoom. Run (needs a display):
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/art_quality/ruin_game.gd -- out_dir [prompt A] [prompt B]

const Economy := preload("res://src/sim/economy.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var view = load("res://scenes/sim_debug.tscn").instantiate()
	view.prompts = [args[1], args[2]] if args.size() > 2 else ["centaur romans", "sewer rats with cheese hammers"]
	view.map_id = "reed_meadow"
	view.army = true
	root.add_child(view)
	while view.clock == null:
		await process_frame
	view.clock.hold = true
	Engine.time_scale = FAST
	Engine.max_fps = 0
	while view.world == null or view.is_loading():
		await process_frame
	Engine.time_scale = 1.0
	view.clock.hold = false
	view.clock.frame_steps = 1
	while view.world.tick < FADE_TICKS:
		await process_frame
	view.camera.edge_scroll = false
	view.set_process_unhandled_input(false)
	view.camera.set_process_unhandled_input(false)
	view.reveal = true
	var w = view.world
	var tc := -1   # side 1's Town Center; the study knocks down a house laid beside it (the Town Center would end the match)
	for b in w.buildings.count():
		if w.buildings.owner[b] == 1 and tc < 0:
			tc = b
	var house := -1
	for k in w.btypes.size():
		if w.btypes[k].id == "house":
			house = k
	tc = Economy.place(w, 1, house, w.buildings.cx[tc] - 4, w.buildings.cy[tc] + 1)
	w.buildings.done[tc] = 1
	w.buildings.hp[tc] = w.btypes[house].hp
	var id: int = w.buildings.id[tc]
	var cells := Rect2i(w.buildings.cx[tc], w.buildings.cy[tc], w.buildings.sx[tc], w.buildings.sy[tc])
	var full: int = w.btypes[w.buildings.kind[tc]].hp
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen((cells.position.x + cells.size.x * 0.5) * 1000, (cells.position.y + cells.size.y * 0.5) * 1000 - 600))
	var n := 0
	for f in [1.0, 0.65, 0.4, 0.12]:
		w.buildings.hp[w.buildings.index_of(id)] = maxi(1, int(full * f))
		for k in 40:
			await process_frame
		n += 1
		root.get_texture().get_image().save_png(out.path_join("fall_%02d_hp%d.png" % [n, int(f * 100)]))
	# It falls the game's way: side 0's soldiers knock down its last hit point, the sim's "die" plays the fall.
	w.buildings.hp[w.buildings.index_of(id)] = 1
	var ids := []
	for i in w.units.count():
		var ut: Dictionary = w.types[w.units.kind[i]]
		if w.units.owner[i] == 0 and not ut.worker and not ut.ranged and not ut.healer:
			ids.append(w.units.id[i])
	w.issue(0, "attack", {"ids": ids, "target": id})
	view.clock.speed = 4.0
	while w.buildings.index_of(id) >= 0:
		await process_frame
	view.clock.speed = 1.0
	var t0 := Time.get_ticks_msec()
	for shot in [0.25, 0.8, 1.6, 3.0, 10.0]:
		while Time.get_ticks_msec() - t0 < shot * 1000.0:
			await process_frame
		n += 1
		root.get_texture().get_image().save_png(out.path_join("fall_%02d_fallen_%ss.png" % [n, shot]))
	print("ruins after the fall: ", view.fx.ruins.size())
	Economy.place(w, 1, house, cells.position.x, cells.position.y)   # a foundation laid over the ruin
	for k in 20:
		await process_frame
	n += 1
	root.get_texture().get_image().save_png(out.path_join("fall_%02d_built_over.png" % n))
	print("ruins after building over it: ", view.fx.ruins.size())
	quit()
