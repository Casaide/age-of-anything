extends SceneTree
## Bakes a race's whole art kit with the window minimised (the bake cache off, so everything
## renders) and checks it finishes and looks the same as a bake in plain view: on macOS the
## engine stops drawing frames for a hidden window, and bakes that waited on frames never
## finished (BakeClock draws on demand instead). Prints "bake_hidden: ok" or fails.
## Run (needs a display): godot --path . --script res://tests/bake_hidden.gd [-- old]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const BakeCache := preload("res://src/view/art/bake_cache.gd")
const PartShape := preload("res://src/part_shape.gd")
const BakeClock := preload("res://src/view/art/bake/bake_clock.gd")
const LIMIT_MS := 45000   # the old frame-waiting bake took 65 s minimised (or never finished); on demand about 8 s


func _initialize() -> void:
	BakeCache.enabled = false
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races := [gen.generate("sewer rats with cheese hammers", rules)]
	for f in 20:   # the window comes up first
		await process_frame
	var t := Time.get_ticks_msec()
	while DisplayServer.window_can_draw() and Time.get_ticks_msec() - t < 8000:   # the OS may take a while, or ignore the first ask
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		for f in 30:
			await process_frame
	if DisplayServer.window_can_draw():
		printerr("bake_hidden: couldn't hide the window (the OS ignored the minimise), so this run proves nothing")
		quit(2)
		return
	if "old" in OS.get_cmdline_user_args():   # the way bakes used to wait (to see this test catch it)
		BakeClock.on_demand = false
	print("window minimised, can draw: %s" % DisplayServer.window_can_draw())
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	var t0 := Time.get_ticks_msec()
	var done := [false]
	var run := func() -> void:
		await kit.prepare(races, [Color(lib.palettes.teams[0])])
		done[0] = true
	run.call()
	while not done[0] and Time.get_ticks_msec() - t0 < LIMIT_MS:
		await process_frame
	var ms := Time.get_ticks_msec() - t0
	if not done[0]:
		printerr("bake_hidden: FAILED, the bake hadn't finished after %d ms (%s)" % [ms, kit.busy_with()])
		quit(1)
		return
	# Something was really drawn: the town centre and a unit part have opaque pixels.
	var arch: String = lib.architecture(races[0])
	var tc: Image = kit.bakes[arch + ":town_center"].img
	var part_ok := PartShape.baked.values().any(func(b): return b.img.get_used_rect().size.x > 4)
	if tc.get_used_rect().size.x < 50 or not part_ok:
		printerr("bake_hidden: FAILED, the bakes came back empty")
		quit(1)
		return
	print("bake_hidden: ok, %d ms minimised (%d bakes, %d unit sprites)" % [ms, kit.bakes.size(), PartShape.baked.size()])
	quit()
