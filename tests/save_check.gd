extends SceneTree
## Save and load through the screens (D-140): a match against the AI saved from the pause menu and
## loaded from its saves page (the buttons pressed), then the same with a pad (real pad events walk
## the menus by focus; B on the saves page goes back to the menu, not on into the battle), then
## from the lobby's Load game. Every load must come back at the saved state hash, the bot playing.
## Saves go to a test folder, not your own. Exit 1 on a failure.
## Run (needs a display):
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/save_check.gd -- [out_dir]

const PadMode := preload("res://src/view/pad_mode.gd")
const SaveGame := preload("res://src/save_game.gd")

var out := "/tmp/save_check"
var failed := 0
var shot := 0
var pad


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else out
	DirAccess.make_dir_recursive_absolute(out)
	SaveGame.dir = "user://test_saves"
	_clear_saves()
	pad = PadMode.of(self)
	var view = load("res://scenes/sim_debug.tscn").instantiate()
	view.prompts = view.DEFAULT_PROMPTS.duplicate()
	view.ai_levels = ["", "normal"]
	view.map_id = "reed_meadow"
	view.vs_ai = true
	view.show_debug = false
	root.add_child(view)
	current_scene = view
	view = await _loaded()
	view.clock.speed = 8.0
	await _until(func(): return view.world.tick >= 1200)
	view.clock.speed = 1.0

	# The mouse: Esc's menu, Save game, Load game, the newest save.
	print("-- the mouse")
	view._toggle_pause_menu()
	await _frames(3)
	var box: Control = view.pause_menu.get_node("card/box")
	_check(box.get_node("save").visible and box.get_node("load").visible, "the pause menu has Save game and Load game")
	box.get_node("save").pressed.emit()
	var saved: Array = SaveGame.list()
	_check(saved.size() == 1 and box.get_node("save").text.begins_with("Saved"), "Save game writes a save and says so")
	await _shoot("pause_menu_saved")
	var want := SaveGame.load_file(saved[0].path)
	view.world.step()   # the match moves on past the save (paused under the menu, so by hand)
	box.get_node("load").pressed.emit()
	await _frames(3)
	_check(view.saves_page.visible and view.saves_page.list.get_child_count() == 1, "Load game lists the save")
	await _shoot("saves_page")
	view.saves_page.list.get_child(0).pressed.emit()
	view = await _loaded()
	_back_at(view, want)

	# A pad: Menu, down to Save game, A; down to Load game, A; B goes back; Load game, A on the newest.
	print("-- a pad")
	pad.fake = {"buttons": {}, "left": Vector2.ZERO, "right": Vector2.ZERO}
	pad.set_on(true)
	await _frames(3)
	await _pad_tap(JOY_BUTTON_START)
	await _frames(3)
	_check(view.pause_menu.visible and _focus() == "resume", "Menu: the pause menu, Resume focused (%s)" % _focus())
	await _down_to("save")
	await _pad_tap(JOY_BUTTON_A)
	_check(SaveGame.list().size() == 2, "A on Save game saves")
	want = SaveGame.load_file(SaveGame.list()[0].path)
	await _down_to("load")
	await _pad_tap(JOY_BUTTON_A)
	await _frames(3)
	_check(view.saves_page.visible and _focus() == view.saves_page.list.get_child(0).name, "A on Load game: the saves page, the newest save focused (%s)" % _focus())
	await _shoot("saves_page_pad")
	await _pad_tap(JOY_BUTTON_B)
	await _frames(3)
	_check(not view.saves_page.visible and view.pause_menu.visible and view.pause_menu.get_node("card").visible, "B on the saves page: back to the pause menu, still paused")
	_check(view.clock.paused, "the match stays paused")
	_check(_focus() == "resume", "the pause menu has the focus again (%s)" % _focus())
	await _down_to("load")
	await _pad_tap(JOY_BUTTON_A)
	await _frames(3)
	await _pad_tap(JOY_BUTTON_A)
	view = await _loaded()
	_back_at(view, want)
	pad.fake = null
	pad.set_on(false)

	# The lobby: Load game on the title menu, the newest save.
	print("-- the lobby")
	view.queue_free()
	await _frames(3)
	var lobby = load("res://scenes/match_setup.tscn").instantiate()
	root.add_child(lobby)
	current_scene = lobby
	await _frames(10)
	var load_button: Button = lobby.menu.find_children("*", "Button", true, false).filter(func(b): return b.text == "Load game")[0]
	load_button.pressed.emit()
	await _frames(3)
	_check(lobby.saves_page.visible and lobby.saves_page.list.get_child_count() == 2, "the lobby's Load game lists both saves")
	await _frames(20)
	await _shoot("lobby_saves")
	want = SaveGame.load_file(SaveGame.list()[0].path)
	lobby.saves_page.list.get_child(0).pressed.emit()
	view = await _loaded()
	_back_at(view, want)

	_clear_saves()
	print("save_check: %d failed" % failed)
	view.queue_free()   # let the match go before the window does
	await _frames(10)
	quit(1 if failed > 0 else 0)


## The new match screen once it's up and its art is made.
func _loaded():
	await _frames(2)
	await _until(func(): return current_scene != null and current_scene.get("world") != null and not current_scene.is_loading())
	await _frames(5)
	return current_scene


## A loaded match is where the save left it, and plays on with its bot.
func _back_at(view, want: Dictionary) -> void:
	var w = view.world
	_check(view.loaded_at == [want.ticks, want.hash], "loaded at the saved tick and state: %s, saved [%d, %d]" % [view.loaded_at, want.ticks, want.hash])
	_check(view.clock.bots.size() == 1 and view.bot_seats.size() == 1, "the bot is back")
	_check(not view.clock.paused, "the match runs")
	var t: int = w.tick
	await _until(func(): return w.tick >= t + 40)
	await _shoot("loaded_%d" % want.ticks)


func _clear_saves() -> void:
	for f in DirAccess.get_files_at(SaveGame.dir):
		DirAccess.remove_absolute(SaveGame.dir.path_join(f))


func _focus() -> String:
	var f := root.gui_get_focus_owner()
	return f.name if f != null else "none"


## Down the pause menu to a button (the d-pad, as a real pad sends it).
func _down_to(name: String) -> void:
	for i in 8:
		if _focus() == name:
			return
		await _pad_tap(JOY_BUTTON_DPAD_DOWN)
	_check(_focus() == name, "the d-pad reaches %s" % name)


## A button as the Deck sends it: the event (menus take it as ui_accept / ui_cancel / ui_down)
## and the pad's own state (what the battlefield reads).
func _pad_tap(b: int) -> void:
	for down in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = down
		pad.fake.buttons[b] = down
		Input.parse_input_event(e)
		await _frames(2)


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failed += 1


func _frames(n: int) -> void:
	for f in n:
		await process_frame


func _until(cond: Callable, secs := 120.0) -> void:
	var stop := Time.get_ticks_msec() + int(secs * 1000.0)
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() < stop:
		await process_frame
	if Time.get_ticks_msec() >= stop:
		_check(false, "timed out waiting (%.0f s)" % secs)
	print("  (waited %.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))


func _shoot(name: String) -> void:
	await _frames(2)
	shot += 1
	var path := "%s/%02d-%s.png" % [out, shot, name]
	root.get_texture().get_image().save_png(path)
	print("  saved ", path)
