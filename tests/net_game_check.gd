extends SceneTree
## A network match in two game windows on this machine, through the real lobby and match view
## (networking milestone, phase 1): this process hosts (the battle setup as a shared lobby,
## src/view/net_lobby.gd) on the 2v2 map, and starts a second that finds the game by its LAN beacon,
## joins, moves to the other team's open side and types its own race; both press Ready and the lobby
## starts the real match (scenes/sim_debug.tscn, use_network) on both, the two AI sides playing on both. Each side gets a bot for its own seat so the match plays; at `ticks` they
## swap hashes. Saves a picture of each window (the lobby too).
## Run (needs a display):
## save:<path>: the host opens a saved match instead, the joiner taking over its ally's AI (side 3 in a
## 2v2: player 2), the other AIs playing on both machines; `ticks` on from the save.
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/net_game_check.gd -- out_dir [ticks] [save:<path>]

const NetPage := preload("res://src/view/ui/net_page.gd")
const Lan := preload("res://src/net/lan.gd")
const Bot := preload("res://src/ai/bot.gd")
const SaveGame := preload("res://src/save_game.gd")

var failures := 0
var out_dir := ""


func _initialize() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var joiner := "join" in args
	var save_path := ""
	for a in args:
		if String(a).begins_with("save:"):
			save_path = String(a).trim_prefix("save:")
	args = args.filter(func(a): return a != "join" and not String(a).begins_with("save:"))
	out_dir = args[0] if args.size() > 0 else "/tmp"
	var ticks := int(args[1]) if args.size() > 1 else 1200
	DirAccess.make_dir_recursive_absolute(out_dir)
	var started := []
	var t0 := Time.get_ticks_msec()
	var who := "joiner" if joiner else "host"
	var lobby = null   # a new game: the battle setup, shared
	var page
	if save_path == "":
		lobby = load("res://scenes/match_setup.tscn").instantiate()
		root.add_child(lobby)
		current_scene = lobby
		await process_frame
		lobby._open_net()
		page = lobby.net_page
	else:
		page = NetPage.new()
		root.add_child(page)
		page.start.connect(func(link, me, setup): started.append([link, me, setup]))
	if not joiner:
		print("host: version %s" % Lan.version())
		if save_path != "":
			var rep := SaveGame.load_file(save_path)
			var seat := 2 if rep.view.player_teams.size() > 2 else 1
			page.wait_for_player({"save": rep, "seat": seat, "humans": [int(rep.view.active), seat]}, "a saved match")
		else:
			page.host_chosen.emit()
			_check(lobby.net_lobby != null and lobby.net_lobby.link != null, "host: the battle setup opened listening")
			lobby._set_map(lobby.MAPS.find("reed_meadow_2v2"))
			_check(lobby.sides.size() == 4, "host: on the 2v2 map, four sides")
		OS.create_process(OS.get_executable_path(), ["--path", ProjectSettings.globalize_path("res://"), "--audio-driver", "Dummy",
			"--script", "res://tests/net_game_check.gd", "--", out_dir, str(ticks), "join"] + (["save:" + save_path] if save_path != "" else []))
	else:
		if save_path != "":
			page.open()
		var heard := false
		while not heard and Time.get_ticks_msec() - t0 < 15000:
			await process_frame
			for h in page.finder.hosts() if page.finder != null else []:
				heard = true
				print("joiner: heard %s at %s" % [h[1], h[0]])
				page._join(String(h[0]), int(h[2]))
				break
		_check(heard, "joiner: found the host's game by its beacon")
	var view = null
	var lobby_map := ""
	var lobby_host_prompt := ""
	if lobby != null:   # the shared lobby: the joiner types its race, both press Ready
		var nl = null
		while (nl == null or nl.humans().size() < 2) and Time.get_ticks_msec() - t0 < 40000:
			await process_frame
			nl = lobby.net_lobby
		_check(nl != null and nl.humans().size() == 2, "%s: both in the lobby (%d ms)" % [who, Time.get_ticks_msec() - t0])
		if nl == null or nl.humans().size() < 2:
			quit(1)
			return
		if joiner:
			_check(lobby.sides.size() == 4 and nl.owners[1] == nl.my_id, "joiner: on the host's 2v2 map, in the first open side (%s)" % str(nl.owners))
			nl.take(3)   # the other team
			while nl.owners[3] != nl.my_id and Time.get_ticks_msec() - t0 < 40000:
				await process_frame
			_check(nl.owners == [1, 0, 0, nl.my_id], "joiner: took side 4, its old side an AI again (%s)" % str(nl.owners))
			lobby.sides[3].field.text = "sewer rats with cheese hammers"
			lobby.sides[3].reroll = 0
			lobby._regenerate(3)
		else:
			while lobby.sides[3].field.text != "sewer rats with cheese hammers" and Time.get_ticks_msec() - t0 < 40000:
				await process_frame
			_check(lobby.sides[3].race.name == lobby.gen.generate("sewer rats with cheese hammers", lobby.rules, 0).name, "host: sees the joiner's race on side 4 (%s)" % lobby.sides[3].race.name)
		var mine: int = nl.owners.find(nl.my_id)
		_check(lobby.sides[mine].field.editable and not lobby.sides[3 if mine == 0 else 0].field.editable, "%s: its own side can be edited, the other player's not" % who)
		_check(lobby.sides[1].field.editable == (not joiner), "%s: an AI's side is the host's to edit" % who)
		for f in 30:
			await process_frame
		lobby_map = lobby.MAPS[lobby.map_index]
		lobby_host_prompt = lobby._prompt(0)
		root.get_texture().get_image().save_png("%s/lobby_%s.png" % [out_dir, who])
		lobby._play()   # Ready
		while not (root.get_tree().current_scene != null and root.get_tree().current_scene.has_method("use_network")) and Time.get_ticks_msec() - t0 < 60000:
			await process_frame
		view = root.get_tree().current_scene
		_check(view != null and view.has_method("use_network"), "%s: both ready: the lobby started the match (%d ms)" % [who, Time.get_ticks_msec() - t0])
		if view == null or not view.has_method("use_network"):
			quit(1)
			return
		started.append([view.net_link, view.net_me, view.net_setup])
	else:
		while started.is_empty() and Time.get_ticks_msec() - t0 < 40000:
			await process_frame
		_check(not started.is_empty(), "%s: the handshake started the match (%d ms)" % [who, Time.get_ticks_msec() - t0])
		if started.is_empty():
			quit(1)
			return
	var link = started[0][0]
	var me: int = started[0][1]
	var setup: Dictionary = started[0][2]
	if setup.has("save"):
		_check(me == (int(setup.seat) if joiner else int(setup.humans[0])), "%s: plays seat %d of the saved match" % [who, me])
	else:
		_check(me == (3 if joiner else 0), "%s: plays side %d" % [who, me])
		_check(setup.humans == [0, 3], "%s: the people are sides 0 and 3 (%s)" % [who, str(setup.humans)])
		_check(setup.prompts[3] == "sewer rats with cheese hammers", "%s: side 4 is the joiner's race (%s)" % [who, setup.prompts[3]])
		_check(setup.map == lobby_map and setup.prompts[0] == lobby_host_prompt, "%s: the match is the lobby as shown (%s, %s)" % [who, setup.map, setup.prompts[0]])
	if view == null:
		page.queue_free()
		view = load("res://scenes/sim_debug.tscn").instantiate()
		view.use_network(link, me, setup)
		root.add_child(view)
		current_scene = view
	while (view.world == null or view.baking or view.clock.lockstep == null) and Time.get_ticks_msec() - t0 < 120000:
		await process_frame
	_check(view.clock.lockstep != null, "%s: the match is up, the lockstep pacing it" % who)
	if not setup.has("save"):
		_check(view.bot_seats.map(func(b): return b.player) == [1, 2], "%s: the AI sides play here too (%s)" % [who, str(view.bot_seats)])
	if view.clock.lockstep == null:
		quit(1)
		return
	var start_tick: int = view.world.tick
	print("%s: loaded at tick %d, state hash %d, loaded_at %s, bots %s" % [who, view.world.tick, view.world.state_hash(), str(view.loaded_at), str(view.bot_seats)])
	ticks += start_tick   # (a saved match goes on from where it was)
	if setup.has("save"):
		_check(view.clock.bots.size() == view.world.races.size() - 2, "%s: the AIs left play on (%d bots for %d sides)" % [who, view.clock.bots.size(), view.world.races.size()])
		_check(view.active == me, "%s: commands its own seat (%d)" % [who, view.active])
	view.clock.bots = view.clock.bots + [Bot.new(me)]   # (a test: a bot plays this side too, through the lockstep)
	var ls = view.clock.lockstep
	while view.world.tick < ticks and ls.desync == "" and not ls.peer_left and Time.get_ticks_msec() - t0 < 300000:
		await process_frame
	view.clock.paused = true
	var hist := FileAccess.open("%s/history_%s.txt" % [out_dir, who], FileAccess.WRITE)
	for c in view.world.history:
		if int(c.turn) * 4 >= start_tick - 16:
			hist.store_line("%d %d %d %s %s" % [c.turn, c.player, c.seq, c.type, JSON.stringify(c.args)])
	hist.store_line("pending " + JSON.stringify(view.world.commands.pending.keys()))
	hist.close()
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
