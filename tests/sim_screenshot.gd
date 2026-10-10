extends SceneTree
## Opens the sim debug view, sends both armies at each other, fast-forwards, saves a PNG.
## Run (needs a display):
##   godot --path . --script res://tests/sim_screenshot.gd -- out.png [map_id] ["prompt A" "prompt B"]

const Iso := preload("res://src/view/iso.gd")

const MEET := {"flat_test": Vector2(23.5, 33.5), "choke_test": Vector2(30.5, 16.5)}   # tiles
const SHOOT_AT_TICK := {"flat_test": 1100, "choke_test": 700}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://sim_debug.png"
	var map_id: String = args[1] if args.size() > 1 else "flat_test"
	var view = load("res://scenes/sim_debug.tscn").instantiate()
	view.prompts = [args[2], args[3]] if args.size() > 3 else view.DEFAULT_PROMPTS.duplicate()
	view.map_id = map_id
	root.add_child(view)
	await process_frame
	view.camera.edge_scroll = false
	while view.world.units.count() == 0:   # spawns run two turns after they're issued
		await process_frame
	var meet: Vector2 = MEET[map_id] * 1000.0
	view.select_army(0)
	view.move_selected_to(Iso.to_screen(meet.x - 1000, meet.y - 1000))
	view.select_army(1)
	view.move_selected_to(Iso.to_screen(meet.x + 1000, meet.y + 1000))
	view.clock.speed = 8.0
	while view.world.tick < SHOOT_AT_TICK[map_id]:
		await process_frame
	view.clock.speed = 1.0
	view.select_army(0)
	view.show_flow = true
	view.camera.zoom = Vector2(1.5, 1.5)
	view.camera.look_at_point(Iso.to_screen(meet.x, meet.y))
	for f in 20:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out, " at tick ", view.world.tick)
	quit()
