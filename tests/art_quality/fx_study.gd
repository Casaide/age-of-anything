extends "res://tests/sim_screenshot.gd"
## Art-quality study, direction 4 (docs/concepts/art-quality/): energy weapons for a sci-fi mod.
## A real volley in the game (the scifi_test mod's pulse troopers firing on charging rats), frozen with
## its shots in the air; then the same moment drawn in each look, the game's own effects hidden:
##   today   the game's combat_fx: the mod's "pulse" (a line with a halo line)
##   pixel   bolts drawn on the art-pixel grid in three bands, added light; a pixel starburst where they
##           hit, a dithered pool of light on the ground, scorch marks with embers
##   beam    unbroken lasers from muzzle to target, soft glow, a flare at each end, lit ground under it
##   plasma  slow glowing balls with a trail of pixels, a ring splash, scorches that linger
## Run (needs a display):
##   AOW_MODS=scifi_test godot --path . --audio-driver Dummy --always-on-top --script res://tests/art_quality/fx_study.gd -- out_dir

const Fx := preload("res://tests/art_quality/fx_looks.gd")


func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var view = load("res://scenes/sim_debug.tscn").instantiate()
	view.prompts = ["space marines", "sewer rats"]
	view.map_id = "reed_meadow"
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
	await _pulse_volley(view, "reed_meadow")
	var shots: Array = view.fx.shots.duplicate(true)
	var looks := Fx.new()
	looks.shots = shots
	looks.z_index = 50
	view.add_child(looks)
	view.move_child(looks, view.fx.get_index() + 1)
	looks.remove_child(looks.ground)
	view.add_child(looks.ground)
	view.move_child(looks.ground, view.layer.get_index())   # scorch marks under the units
	for name in ["today", "pixel", "beam", "plasma"]:
		view.fx.visible = name == "today"
		looks.look = name
		looks.queue_all()
		for f in 6:
			await process_frame
		root.get_texture().get_image().save_png(out.path_join("fx_%s.png" % name))
		print("saved ", out.path_join("fx_%s.png" % name))
	quit()


## As sim_screenshot's volley, with the pulse troopers (side 0's `slot`) in a block and side 1's spears
## charging; frozen with shots in the air.
func _pulse_volley(view, map_id: String, slot := "skirmisher") -> void:
	var w = view.world
	var meet: Vector2 = MEET[map_id] * 1000.0
	view.reveal = true
	while w.units.count() == 0:
		await process_frame
	var start: int = w.units.count()
	for q in 12:
		w.issue(0, "spawn", {"slot": slot, "count": 1, "x": int(meet.x) - 3000 - (q / 4) * 800, "y": int(meet.y) + (q % 4 - 2) * 800})
	w.issue(1, "spawn", {"slot": "spear", "count": 14, "x": int(meet.x) + 4500, "y": int(meet.y)})
	while w.units.count() < start + 26:
		await process_frame
	var ids := []
	for i in w.units.count():
		if w.units.owner[i] == 1 and w.types[w.units.kind[i]].slot == "spear":
			ids.append(w.units.id[i])
	w.issue(1, "attack_move", {"ids": ids, "x": int(meet.x) - 4000, "y": int(meet.y)})
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(meet.x - 500, meet.y))
	for f in 1500:
		await process_frame
		var late: int = view.fx.shots.filter(func(sh): return sh.t / sh.dur > 0.75).size()
		if f > 60 and view.fx.shots.size() >= 8 and late >= 3:   # some about to hit
			break
	view.clock.paused = true
	view.fx.set_process(false)
