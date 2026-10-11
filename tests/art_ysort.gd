extends SceneTree
## Draw order around a building: puts a unit beside each face and corner of player 1's
## Town Center, then captures it close up. Every unit must show whole where it stands
## in front of the building, and be hidden only where it is behind it.
## Run (needs a display): godot --path . --script res://tests/art_ysort.gd -- out.png ["prompt A" "prompt B"]

const Iso := preload("res://src/view/iso.gd")
const Commands := preload("res://src/sim/commands.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://ysort.png"
	var view = load("res://scenes/sim_debug.tscn").instantiate()
	view.prompts = [args[1], args[2]] if args.size() > 2 else ["centaur romans", "sewer rats with cheese hammers"]
	view.map_id = "flat_test"
	view.army = true
	root.add_child(view)
	while view.world == null or view.baking:
		await process_frame
	view.camera.edge_scroll = false
	view.set_process_unhandled_input(false)
	view.camera.set_process_unhandled_input(false)
	var w = view.world
	while w.units.count() <= 6:
		await process_frame
	var bs = w.buildings
	var cx: float = bs.cx[0]
	var cy: float = bs.cy[0]
	var s: float = bs.size[0]
	# Outside each face's middle, then outside each corner (tiles).
	var spots := [Vector2(cx + s + 0.5, cy + s * 0.5), Vector2(cx + s * 0.5, cy + s + 0.5),
		Vector2(cx - 0.5, cy + s * 0.5), Vector2(cx + s * 0.5, cy - 0.5),
		Vector2(cx + s + 0.5, cy - 0.5), Vector2(cx - 0.5, cy + s + 0.5),
		Vector2(cx + s + 0.5, cy + s + 0.5), Vector2(cx - 0.5, cy - 0.5)]
	var mine := []
	for i in w.units.count():
		if w.units.owner[i] == 0 and mine.size() < spots.size():
			mine.append(w.units.id[i])
	for k in mine.size():
		w.issue(0, Commands.MOVE, {"ids": [mine[k]], "x": int(spots[k].x * 1000), "y": int(spots[k].y * 1000)})
	view.clock.speed = 8.0
	while w.tick < 500:
		await process_frame
	view.clock.speed = 1.0
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen((cx + s * 0.5) * 1000, (cy + s * 0.5) * 1000))
	for f in 20:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
