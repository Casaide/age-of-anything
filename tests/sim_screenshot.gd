extends SceneTree
## Opens the sim debug view, plays a scene, saves a PNG.
## Run (needs a display):
##   godot --path . --script res://tests/sim_screenshot.gd -- out.png [map_id] [scene] ["prompt A" "prompt B"]
## Scenes: "armies" (both test armies march at each other; the default) or
## "opening:<tick>" (both sides autoplay their economy; shot at that tick, over player 1's base).

const Iso := preload("res://src/view/iso.gd")

const MEET := {"flat_test": Vector2(23.5, 33.5), "choke_test": Vector2(30.5, 16.5)}   # tiles
const SHOOT_AT_TICK := {"flat_test": 1100, "choke_test": 700}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://sim_debug.png"
	var map_id: String = args[1] if args.size() > 1 else "flat_test"
	var scene: String = args[2] if args.size() > 2 else "armies"
	var view = load("res://scenes/sim_debug.tscn").instantiate()
	view.prompts = [args[3], args[4]] if args.size() > 4 else view.DEFAULT_PROMPTS.duplicate()
	view.map_id = map_id
	view.army = scene == "armies"
	root.add_child(view)
	await process_frame
	view.camera.edge_scroll = false
	view.set_process_unhandled_input(false)          # a real mouse in the window mustn't change the shot
	view.camera.set_process_unhandled_input(false)
	if scene.begins_with("opening"):
		await _opening(view, int(scene.get_slice(":", 1)))
	else:
		await _armies(view, map_id)
	for f in 20:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out, " at tick ", view.world.tick)
	quit()


func _armies(view, map_id: String) -> void:
	while view.world.units.count() <= 6:   # spawns run two turns after they're issued
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


func _opening(view, at_tick: int) -> void:
	view._set_autoplay(true)
	view.clock.speed = 16.0
	while view.world.tick < at_tick - 40:
		await process_frame
	view.clock.speed = 1.0
	while view.world.tick < at_tick:
		await process_frame
	view.selected_building = view.world.buildings.id[0]
	var s: Array = view.map.starts[0]
	view.camera.zoom = Vector2(1.7, 1.7)
	view.camera.look_at_point(Iso.to_screen(s[0] - 1500, s[1] + 2500))
