extends SceneTree
## What the living town costs (milestone 17): the match view on reed_meadow, both sides played
## by the bots to about six minutes, then the frame time over the town with town life on and off
## (frame time is capped by the display; the process time is the CPU the scripts take).
## Run (needs a display): godot --path . --script res://tests/town_bench.gd [-- <tick>]

const Iso := preload("res://src/view/iso.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var at_tick := int(args[0]) if args.size() > 0 else 7200
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var view = load("res://scenes/sim_debug.tscn").instantiate()
	view.map_id = "reed_meadow"
	root.add_child(view)
	while view.world == null or view.baking:
		await process_frame
	view.camera.edge_scroll = false
	view.set_process_unhandled_input(false)
	view.camera.set_process_unhandled_input(false)
	view._set_autoplay(true)
	view.clock.speed = 16.0
	while view.world.tick < at_tick:
		await process_frame
	view.clock.speed = 1.0
	var s: Array = view.map.starts[0]
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(s[0] - 1500, s[1] + 2500))
	print("%d units, %d buildings at tick %d" % [view.world.units.count(), view.world.buildings.count(), view.world.tick])
	for on in [true, false, true]:
		view.town.enabled = on
		await _measure(view, "town life %s, sim running" % ("on " if on else "off"))
	quit()


func _measure(view, what: String) -> void:
	for f in 60:
		await process_frame
	var calls := 0
	var t0 := Time.get_ticks_usec()
	var n := 300
	var cpu := 0.0
	for f in n:
		await process_frame
		calls = maxi(calls, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		cpu += Performance.get_monitor(Performance.TIME_PROCESS)
	print("%-32s %4d draw calls   %.2f ms/frame   %.2f ms process (CPU, all scripts)" % [what, calls, (Time.get_ticks_usec() - t0) / 1000.0 / n, cpu * 1000.0 / n])
