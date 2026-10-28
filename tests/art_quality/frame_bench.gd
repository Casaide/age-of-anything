extends "res://tests/sim_screenshot.gd"
## Art-quality study, direction 1 (docs/concepts/art-quality/): what finer bakes cost while playing.
## The showcase battle (both sides in age 3, big armies) at play zoom; then frame time over 300 frames
## with vsync off, draw calls and texture memory. Compare runs with AOW_ART_SCALE=3.0 and without.
## Run (needs a display):
##   [AOW_ART_SCALE=3.0] godot --path . --audio-driver Dummy --always-on-top --script res://tests/art_quality/frame_bench.gd

func _initialize() -> void:
	var view = load("res://scenes/sim_debug.tscn").instantiate()
	view.prompts = ["centaur romans", "sewer rats with cheese hammers"]
	view.map_id = "reed_meadow"
	root.add_child(view)
	while view.clock == null:
		await process_frame
	view.clock.hold = true
	Engine.time_scale = FAST
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
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
	await _showcase(view, "reed_meadow", 1500)
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for f in 30:
		await process_frame
	var gpu := 0.0
	var cpu := 0.0
	var t0 := Time.get_ticks_usec()
	var worst := 0
	var last := t0
	for f in 300:
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / 300.0
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var vid := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	print("BENCH scale %s: %d units, %.2f ms/frame avg (vsync may cap it), render %.2f ms GPU %.2f ms CPU, %.2f ms worst frame, %d draw calls, video memory %d MB, window %s" % [
		OS.get_environment("AOW_ART_SCALE") if OS.has_environment("AOW_ART_SCALE") else "1.5 (default)", view.world.units.count(), ms, gpu / 300.0, cpu / 300.0, worst / 1000.0, calls,
		vid / 1048576, str(DisplayServer.window_get_size())])
	quit()
