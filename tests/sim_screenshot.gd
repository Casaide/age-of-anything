extends SceneTree
## Opens the sim debug view, plays a scene, saves a PNG.
## Run (needs a display):
##   godot --path . --script res://tests/sim_screenshot.gd -- out.png [map_id] [scene] ["prompt A" "prompt B"]
## Scenes: "armies" (both test armies march at each other; the default) or
## "opening:<tick>" (both sides autoplay their economy; shot at that tick, over player 1's base),
## or "battle:<tick>" (both test armies attack-move at each other; shot mid-fight at that tick).

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
	view.army = scene == "armies" or scene.begins_with("battle") or scene.begins_with("ageup")
	root.add_child(view)
	while view.world == null or view.baking:   # the art bakes first
		await process_frame
	view.camera.edge_scroll = false
	view.set_process_unhandled_input(false)          # a real mouse in the window mustn't change the shot
	view.camera.set_process_unhandled_input(false)
	if scene.begins_with("opening"):
		await _opening(view, int(scene.get_slice(":", 1)))
	elif scene.begins_with("ageup"):
		await _ageup(view, int(scene.get_slice(":", 1)))
	elif scene.begins_with("battle"):
		await _battle(view, map_id, int(scene.get_slice(":", 1)))
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
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(meet.x, meet.y))


func _battle(view, map_id: String, at_tick: int) -> void:
	while view.world.units.count() <= 6:
		await process_frame
	var meet: Vector2 = MEET[map_id] * 1000.0
	var w = view.world
	for p in 2:
		var ids := []
		for i in w.units.count():
			if w.units.owner[i] == p and not w.types[w.units.kind[i]].worker:
				ids.append(w.units.id[i])
		w.issue(p, "attack_move", {"ids": ids, "x": int(meet.x), "y": int(meet.y)})
	view.clock.speed = 8.0
	while w.tick < at_tick - 20:
		await process_frame
	view.clock.speed = 1.0
	while w.tick < at_tick:
		await process_frame
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(meet.x, meet.y))
	# Look where the fighting is: the middle of the units still alive.
	var c := Vector2.ZERO
	for i in w.units.count():
		c += Vector2(w.units.x[i], w.units.y[i])
	if w.units.count() > 0:
		c /= w.units.count()
		view.camera.look_at_point(Iso.to_screen(c.x, c.y))


## Both sides' armies stand by their Town Centers; both age up (twice, up to `to_age`);
## the shot is player 1's army in its new kit.
func _ageup(view, to_age: int) -> void:
	var w = view.world
	while w.units.count() <= 6:
		await process_frame
	for r in w.resources.size():
		for p in 2:
			w.stock[r][p] = 99999
	view.clock.speed = 16.0
	for age in range(2, to_age + 1):
		for p in 2:
			w.issue(p, "age_up", {"building": w.buildings.id[p]})
		while w.ages[0] < age:
			await process_frame
	view.clock.speed = 1.0
	for f in 30:
		await process_frame
	var s: Array = w.map.starts[0]
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(s[0] + 1500, s[1] + 3500))


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
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(s[0] - 1500, s[1] + 2500))
