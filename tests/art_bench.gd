extends SceneTree
## Draw calls and frame time in the pixel-art scene with 200+ units: atlas and a
## shared team material vs separate textures. Run (needs a display):
##   godot --path . --script res://tests/art_bench.gd
const PartShape := preload("res://src/part_shape.gd")

func _initialize() -> void:
	var s = load("res://scenes/art_pixel.tscn").instantiate()
	root.add_child(s)
	s.set_process_unhandled_input(false)
	while not s.built:
		await process_frame
	s.set_zoom(1)
	s.cam.position = s.Iso.to_screen(8000, 7000) * s.ART_SCALE
	await _measure("scene (%d units)" % s.units.size())
	s.spawn_bench(200)
	await _measure("+200 units, atlas on (%d units)" % s.units.size())
	PartShape.use_atlas = false
	for v in s.units:
		for ps in v.find_children("*", "Node2D", true, false):
			if ps is PartShape:
				ps.queue_redraw()
	await _measure("+200 units, atlas off")
	quit()


func _measure(what: String) -> void:
	for f in 30:
		await process_frame
	var calls := 0
	var t0 := Time.get_ticks_usec()
	var n := 120
	for f in n:
		await process_frame
		calls = maxi(calls, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	print("%-36s %4d draw calls   %.2f ms/frame" % [what, calls, (Time.get_ticks_usec() - t0) / 1000.0 / n])
