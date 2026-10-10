extends SceneTree
## Opens the sim debug view, sends both armies at each other, fast-forwards, saves a PNG.
## Run (needs a display): godot --path . --script res://tests/sim_screenshot.gd -- out.png ["prompt A" "prompt B"]

const MEET := Vector2(23.5, 33.5)   # tiles; just left of the pond
const SHOOT_AT_TICK := 900

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://sim_debug.png"
	var view = load("res://scenes/sim_debug.tscn").instantiate()
	view.prompts = [args[1], args[2]] if args.size() > 2 else view.DEFAULT_PROMPTS.duplicate()
	root.add_child(view)
	await process_frame
	while view.world.units.count() == 0:   # spawns run two turns after they're issued
		await process_frame
	var px: float = view.TILE_PX
	view.select_army(0)
	view.move_selected_to(MEET * px + Vector2(-20, -30))
	view.select_army(1)
	view.move_selected_to(MEET * px + Vector2(20, 30))
	view.clock.speed = 8.0
	while view.world.tick < SHOOT_AT_TICK:
		await process_frame
	view.clock.speed = 1.0
	view.select_army(0)
	view.camera.position = MEET * px
	view.camera.zoom = Vector2(1.7, 1.7)
	for f in 20:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out, " at tick ", view.world.tick)
	quit()
