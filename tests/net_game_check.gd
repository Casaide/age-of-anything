extends SceneTree
## A network match in two game windows on this machine, through the real lobby page and match view
## (networking milestone, phase 1): this process hosts (src/view/ui/net_page.gd waiting with the
## battle setup), and starts a second that finds the game by its LAN beacon and joins with its own
## race. Both start the real match (scenes/sim_debug.tscn, use_network); each side gets a bot for its
## own seat so the match plays; at `ticks` they swap hashes. Saves a picture of each window.
## Run (needs a display):
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/net_game_check.gd -- out_dir [ticks]

const NetPage := preload("res://src/view/ui/net_page.gd")
const Lan := preload("res://src/net/lan.gd")
const Bot := preload("res://src/ai/bot.gd")

var failures := 0
var out_dir := ""


func _initialize() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var joiner := "join" in args
	args = args.filter(func(a): return a != "join")
	out_dir = args[0] if args.size() > 0 else "/tmp"
	var ticks := int(args[1]) if args.size() > 1 else 1200
	DirAccess.make_dir_recursive_absolute(out_dir)
	var page := NetPage.new()
	root.add_child(page)
	var started := []
	page.start.connect(func(link, me, setup): started.append([link, me, setup]))
	var t0 := Time.get_ticks_msec()
	if not joiner:
		print("host: version %s" % Lan.version())
		page.wait_for_player({"prompts": ["centaur romans", "(the joiner's)"], "rerolls": [0, 0], "map": "reed_meadow", "mode": "", "teams": [0, 1]}, "centaurs on Reed Meadow")
		OS.create_process(OS.get_executable_path(), ["--path", ProjectSettings.globalize_path("res://"), "--audio-driver", "Dummy",
			"--script", "res://tests/net_game_check.gd", "--", out_dir, str(ticks), "join"])
	else:
		page.open()
		page.race_field.text = "sewer rats with cheese hammers"
		var heard := false
		while not heard and Time.get_ticks_msec() - t0 < 15000:
			await process_frame
			for h in page.finder.hosts() if page.finder != null else []:
				heard = true
				print("joiner: heard %s at %s" % [h[1], h[0]])
				page._join(String(h[0]), int(h[2]))
				break
		_check(heard, "joiner: found the host's game by its beacon")
	while started.is_empty() and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	var who := "joiner" if joiner else "host"
	_check(not started.is_empty(), "%s: the handshake started the match (%d ms)" % [who, Time.get_ticks_msec() - t0])
	if started.is_empty():
		quit(1)
		return
	var link = started[0][0]
	var me: int = started[0][1]
	var setup: Dictionary = started[0][2]
	_check(me == (1 if joiner else 0), "%s: plays side %d" % [who, me])
	_check(setup.prompts[1] == "sewer rats with cheese hammers", "%s: side 1 is the joiner's race (%s)" % [who, setup.prompts[1]])
	page.queue_free()
	var view = load("res://scenes/sim_debug.tscn").instantiate()
	view.use_network(link, me, setup)
	root.add_child(view)
	current_scene = view
	while (view.world == null or view.baking or view.clock.lockstep == null) and Time.get_ticks_msec() - t0 < 120000:
		await process_frame
	_check(view.clock.lockstep != null, "%s: the match is up, the lockstep pacing it" % who)
	if view.clock.lockstep == null:
		quit(1)
		return
	view.clock.bots = [Bot.new(me)]   # (a test: a bot plays this side, through the lockstep)
	var ls = view.clock.lockstep
	while view.world.tick < ticks and ls.desync == "" and not ls.peer_left and Time.get_ticks_msec() - t0 < 300000:
		await process_frame
	view.clock.paused = true
	_check(view.world.tick >= ticks, "%s: reached tick %d (%d)" % [who, ticks, view.world.tick])
	_check(ls.desync == "", "%s: no desync (%s)" % [who, ls.desync])
	root.get_texture().get_image().save_png("%s/net_%s.png" % [out_dir, who])
	var hashes: Array = view.world.hashes.filter(func(h): return int(h[0]) <= ticks)
	if joiner:
		link.send({"t": "final", "hashes": hashes})
		for f in 60:
			ls.receive()
			await process_frame
		quit(1 if failures > 0 else 0)
		return
	var theirs = null
	var t1 := Time.get_ticks_msec()
	while theirs == null and Time.get_ticks_msec() - t1 < 60000:
		ls.receive()
		for m in ls.others:
			if m.get("t", "") == "final":
				theirs = m.hashes
		await process_frame
	_check(theirs != null, "host: the joiner's hashes came back")
	if theirs != null:
		_check(theirs == hashes, "host: both windows' matches hash the same (%d checkpoints)" % hashes.size())
	print("\nnet game check (host side): %d failed" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
