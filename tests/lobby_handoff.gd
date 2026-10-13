extends SceneTree
## The lobby hands the match what each side showed (Dominic: "the enemy was the same as me; I swear
## we weren't when I was making them"): types a race on each side, changes the map to the 2v2 and
## back, presses Start, and checks the match's races are the lobby's, side for side, each side in
## its own team colour (yours blue, the AI's red). It was never mixed up: the cause was a poison-red
## frog skin on the blue side, which read as the enemy; tests/run_tests.gd keeps every skin off the
## team colours. Prints "0 failed" when all is well.
## Run (needs a display): godot --path . --audio-driver Dummy --script res://tests/lobby_handoff.gd

var checks := 0
var failures := 0


func _initialize() -> void:
	var lobby = load("res://scenes/match_setup.tscn").instantiate()
	root.add_child(lobby)
	for f in 5:
		await process_frame
	lobby._open_setup()
	await _settle(lobby)
	lobby._set_map(lobby.MAPS.find("reed_meadow_2v2"))
	await _settle(lobby)
	lobby._set_map(lobby.MAPS.find("old_forest"))
	await _settle(lobby)
	for k in 2:
		var words: String = ["viking frogs", "legionary soldiers"][k]
		lobby.sides[k].field.text = words
		lobby.sides[k].field.text_changed.emit(words)
	lobby._roll(1)   # another roll of the AI's words
	await _settle(lobby)
	var want: Array = lobby.sides.map(func(s): return s.race.name)
	var lib = lobby.lib
	lobby._play()
	var view = null
	while view == null or view.world == null or view.is_loading():
		await process_frame
		view = current_scene if current_scene != lobby else null
	var w = view.world
	check(w.races.map(func(r): return r.name) == want, "the match's races are the lobby's, side for side (%s, the lobby showed %s)" % [w.races.map(func(r): return r.name), want])
	check(w.teams[0] != w.teams[1] and view.active == 0, "you are side 0, on your own team against the AI (teams %s, active %d)" % [w.teams, view.active])
	var cols := {}
	for id in view.views:
		var i: int = w.units.index_of(id)
		if i >= 0 and w.units.owner[i] < w.races.size():
			cols[w.units.owner[i]] = view.views[id]._built[2]
	check(cols.get(0) == Color(lib.palettes.teams[0]) and cols.get(1) == Color(lib.palettes.teams[1]),
		"each side's units wear its own team colour (%s)" % cols)
	print("\n%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _settle(lobby) -> void:
	for f in 3:
		await process_frame
	while lobby.baking or lobby.sides.any(func(s): return s.dirty_at > 0.0):
		await process_frame
