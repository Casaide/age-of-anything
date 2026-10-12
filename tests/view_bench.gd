extends SceneTree
## What the match view costs at size (milestone 15): the 2v2 map with four bots played to a
## grown town (default 10 minutes), extra soldiers spawned until 300+ units are on the map, then
## the frame time, the process time and draw calls over your town (zoomed in and out), and the
## per-frame parts of the view timed one by one (each called on its own, many times).
## Run (needs a display): godot --path . --always-on-top --script res://tests/view_bench.gd [-- <tick> [map_id] [shot.png]]
## With a png path it also saves what the screen shows over the town (zoomed in), to look at.

const Iso := preload("res://src/view/iso.gd")
const Commands := preload("res://src/sim/commands.gd")

const PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans", "greek hoplites"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var at_tick := int(args[0]) if args.size() > 0 else 12000
	var map_id: String = args[1] if args.size() > 1 else "reed_meadow_2v2"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var view = load("res://scenes/sim_debug.tscn").instantiate()
	view.map_id = map_id
	var m = load("res://src/sim/sim_map.gd").load_id(map_id)
	view.prompts = PROMPTS.slice(0, m.starts.size())
	view.player_teams = m.start_teams
	root.add_child(view)
	while view.world == null or view.baking:
		await process_frame
	view.camera.edge_scroll = false
	view.set_process_unhandled_input(false)
	view.camera.set_process_unhandled_input(false)
	view._set_autoplay(true)
	view.clock.speed = 16.0
	while view.world.tick < at_tick and view.world.winner < 0:
		await process_frame
	var w = view.world
	var extra := 0
	while w.units.count() + extra < 320:   # soldiers by each Town Center until the map holds 300+
		for p in w.races.size():
			w.issue(p, Commands.SPAWN, {"slot": "spear", "count": 10, "x": int(m.starts[p][0]) + 3000, "y": int(m.starts[p][1]) + 3000})
			extra += 10
	view.clock.speed = 1.0
	for f in 300:   # the spawns land a couple of turns later
		await process_frame
		if w.units.count() >= 300:
			break
	for f in 30:
		await process_frame
	var s: Array = m.starts[0]
	print("%s at tick %d: %d units, %d buildings, %d resource cells shown" % [map_id, w.tick, w.units.count(), w.buildings.count(), view.rviews.size()])
	for zoom in [3.0, 1.0]:
		view.camera.zoom = Vector2(zoom, zoom)
		view._on_zoom()
		view.camera.look_at_point(Iso.to_screen(s[0] - 1500, s[1] + 2500))
		await _measure("zoom %.0fx over the town" % zoom)
		if zoom == 3.0 and args.size() > 2:
			root.get_texture().get_image().save_png(args[2])
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	_parts(view)
	quit()


func _measure(what: String) -> void:
	for f in 60:
		await process_frame
	var calls := 0
	var t0 := Time.get_ticks_usec()
	var n := 300
	var cpu := 0.0
	var worst := 0
	var last := t0
	for f in n:
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
		calls = maxi(calls, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		cpu += Performance.get_monitor(Performance.TIME_PROCESS)
	print("%-28s %4d draw calls   %.2f ms/frame (worst %.1f)   %.2f ms process (CPU, all scripts)" % [what, calls,
		(Time.get_ticks_usec() - t0) / 1000.0 / n, worst / 1000.0, cpu * 1000.0 / n])


## The match view's per-frame parts, each run on its own 60 times (the minimap's and the fog's
## repaints are forced: in play they run at their own rates).
func _parts(view) -> void:
	var parts := {
		"sync views (units)": func(): view._sync_views(),
		"sync buildings": func(): view._sync_buildings(),
		"sync resources": func(): view._sync_resources(),
		"sync fog (visibility)": func(): view._sync_fog(),
		"fog texture (forced)": func():
			view.fog_view.shown = -1000
			view.fog_view.refresh(view.world, view.active),
		"minimap paint (forced)": func(): view.minimap._paint(),
		"town life": func(): view.town.update(1.0 / 60.0),
		"land": func(): view.land.sync(),
		"top bar + panel": func():
			view._update_top_bar()
			view._update_panel(),
	}
	for k in parts:
		var t0 := Time.get_ticks_usec()
		for r in 60:
			parts[k].call()
		print("  %-26s %.3f ms a call" % [k, (Time.get_ticks_usec() - t0) / 1000.0 / 60])
