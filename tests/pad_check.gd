extends SceneTree
## The match played with a pad (milestone 20), by a fake pad (PadMode.fake): every step a player
## takes, checked in the sim, with a picture at each look. Exit 1 on a failure.
## Run (needs a display):
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/pad_check.gd -- [out_dir] [map_id]
## Steps: pad mode on (the compact panel, the hints) -> d-pad up: the Town Center -> tap A on it:
## selected only; again: its wheel (the camera holds still), point at the worker, A twice: two queued -> B: closed -> B:
## deselect -> hold A on the workers: the circle sweeps them up -> X on a bush: they gather -> tap A
## on a selected worker: its wheel, Build: Civilian (its page), the House, A: its foundation -> LB
## tap: one kind -> Menu: the pause menu, focused -> B: back.

const PadMode := preload("res://src/view/pad_mode.gd")
const Economy := preload("res://src/sim/economy.gd")
const Iso := preload("res://src/view/iso.gd")
const SimMap := preload("res://src/sim/sim_map.gd")

var view
var pad
var out := "/tmp/pad"
var failed := 0
var shot := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else out
	DirAccess.make_dir_recursive_absolute(out)
	view = load("res://scenes/sim_debug.tscn").instantiate()
	view.prompts = view.DEFAULT_PROMPTS.duplicate()
	view.map_id = args[1] if args.size() > 1 else "reed_meadow"
	view.vs_ai = true
	view.show_debug = false
	root.add_child(view)
	while view.world == null or view.is_loading():
		await process_frame
	view.clock.bots = []   # the AI stands still: only the pad acts
	view.set_process_unhandled_input(false)   # a real mouse in the window mustn't play
	view.camera.set_process_unhandled_input(false)
	pad = PadMode.of(self)
	pad.fake = {"buttons": {}, "left": Vector2.ZERO, "right": Vector2.ZERO}
	pad.set_on(true)
	await _frames(5)
	await _run()
	print("pad_check: %d failed" % failed)
	pad.fake = null
	pad.set_on(false)
	view.queue_free()   # let the match go before the window does (a quit straight away crashed in Metal's teardown)
	await _frames(10)
	quit(1 if failed > 0 else 0)


func _run() -> void:
	var w = view.world
	_check(view.panel.compact and not view.camera.edge_scroll, "pad mode: compact panel, no edge scroll")
	_check(view.pad_play.hints.get_child_count() > 0, "pad mode: the hint strip shows")

	# D-pad up: the Town Center, the camera on it.
	await _tap(JOY_BUTTON_DPAD_UP)
	var tc: int = view.selected_building
	_check(tc != 0 and w.btypes[w.buildings.kind[w.buildings.index_of(tc)]].id == "town_center", "d-pad up selects the Town Center")
	await _shoot("tc_selected")

	# Tap A on it: selected again, its wheel open; point at the worker (the camera holds); A twice.
	var before: int = w.buildings.queue[w.buildings.index_of(tc)].size()
	view._clear_selection()
	await _aim(view.bviews[tc].position + Vector2(0, -6))
	await _seconds(0.4)   # (not a double tap with anything before)
	await _tap(JOY_BUTTON_A)
	_check(view.selected_building == tc and not view.pad_play.wheel.visible, "tap A on your Town Center: selected only (its progress shows, no wheel)")
	await _seconds(0.4)   # (not a double tap)
	await _tap(JOY_BUTTON_A)
	_check(view.pad_play.wheel.visible and view.selected_building == tc, "tap A again on the selected Town Center: its wheel")
	var cam_at: Vector2 = view.camera.position
	var items: Array = view.pad_play.wheel.pages[view.pad_play.wheel.page][1]
	var k := items.map(func(b): return b.text).find(items.filter(func(b): return b.text.begins_with("Train"))[0].text)
	await _point(k, items.size())
	_check(view.pad_play.wheel.hot == k, "the stick points at the worker on the wheel")
	_check(view.camera.position == cam_at, "the stick that points doesn't move the camera")
	await _shoot("wheel_tc")
	await _tap(JOY_BUTTON_A)
	await _tap(JOY_BUTTON_A)
	pad.fake.right = Vector2.ZERO
	await _ticks(10)
	_check(w.buildings.queue[w.buildings.index_of(tc)].size() == before + 2, "A twice on the wheel queues two workers: %d -> %d" % [before, w.buildings.queue[w.buildings.index_of(tc)].size()])
	_check(view.pad_play.wheel.visible, "the wheel stays up for more")
	await _tap(JOY_BUTTON_B)
	_check(not view.pad_play.wheel.visible and view.selected_building == tc, "B closes the wheel (the Town Center still selected)")

	# B: deselect. Then hold A over the workers: the circle sweeps them up.
	await _tap(JOY_BUTTON_B)
	_check(view.selected_building == 0, "B deselects")
	var workers := []
	for i in w.units.count():
		if w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker:
			workers.append(w.units.id[i])
	var mid := Vector2.ZERO
	for id in workers:
		mid += view.views[id].ground()
	mid /= workers.size()
	view.camera.look_at_point(mid)
	view.pad_play.offset = Vector2.ZERO
	await _frames(3)
	_hold(JOY_BUTTON_A, true)
	await _seconds(1.1)
	_check(view.pad_play.circle > 100.0, "holding A grows the circle (%.0f px)" % view.pad_play.circle)
	await _shoot("circle")
	_hold(JOY_BUTTON_A, false)
	await _frames(2)
	var got: int = workers.filter(func(id): return view.selected.has(id)).size()
	_check(got >= 3, "the circle took the workers (%d of %d)" % [got, workers.size()])
	_check(view.selected.keys().all(func(id): return w.units.owner[w.units.index_of(id)] == 0), "the circle takes only your own")

	# X on a bush: they gather.
	var bush := _nearest_resource(mid, "food")
	_aim(bush)
	await _frames(2)
	await _shoot("aim_bush")
	await _tap(JOY_BUTTON_X)
	await _ticks(30)
	var gathering: int = view.selected.keys().filter(func(id): var i: int = w.units.index_of(id); return w.units.task[i] == Economy.GATHER or w.units.moving[i] != 0).size()
	_check(gathering == view.selected.size(), "X on a bush: every selected worker goes to gather (%d of %d)" % [gathering, view.selected.size()])

	# Tap A on a selected worker: its wheel; Build: Civilian opens its page; the House; A places it.
	for r in w.resources.size():   # (the three workers stay selected: whichever the reticle catches)
		w.stock[r][0] = 9999
	await _aim(view._body(view.views[workers[0]]))
	await _tap(JOY_BUTTON_A)
	_check(view.pad_play.wheel.visible, "tap A on a selected worker opens its wheel")
	items = view.pad_play.wheel.pages[view.pad_play.wheel.page][1]
	k = items.map(func(b): return b.text).find("Build: Civilian")
	_check(k >= 0, "a worker's wheel has Build: Civilian")
	_check(items[0].text == "All on screen", "a unit's wheel starts with All on screen")
	await _point(k, items.size())
	await _tap(JOY_BUTTON_A)
	pad.fake.right = Vector2.ZERO
	await _frames(3)
	_check(view.pad_play.wheel.visible and view.build_page == "civilian", "A on Build: Civilian: its page on the wheel")
	items = view.pad_play.wheel.pages[view.pad_play.wheel.page][1]
	k = -1
	for n in items.size():
		if items[n].text.begins_with("Build House"):
			k = n
	_check(k >= 0, "the civilian page has the House")
	await _point(k, items.size())
	await _shoot("wheel_build")
	pad.fake.right = Vector2.ZERO
	await _tap(JOY_BUTTON_A)
	_check(view.placing == "house" and not view.pad_play.wheel.visible, "A on the House: placing it, the wheel gone")
	var spot := _open_ground(mid)
	var half: int = (w.btypes[Economy.btype_of(w, "house")].size - 1) / 2   # the ghost centres on the reticle
	_aim(Iso.to_ground((spot.x + half) * 1000 + 500, (spot.y + half) * 1000 + 500))
	await _frames(3)
	await _shoot("placing")
	var nb: int = w.buildings.count()
	await _tap(JOY_BUTTON_A)
	await _ticks(12)
	_check(w.buildings.count() == nb + 1, "A places the house's foundation")

	# LB tap: one kind of a mixed selection.
	view.selected.clear()
	for i in w.units.count():
		if w.units.owner[i] == 0:
			view.selected[w.units.id[i]] = true
	var kinds := {}
	for id in view.selected:
		kinds[w.units.kind[w.units.index_of(id)]] = true
	if kinds.size() > 1:
		await _tap(JOY_BUTTON_LEFT_SHOULDER)
		var now := {}
		for id in view.selected:
			now[w.units.kind[w.units.index_of(id)]] = true
		_check(now.size() == 1, "LB tapped: one kind of the selection")

	# Menu: the pause menu, its first button focused; B: back to the battle.
	await _tap(JOY_BUTTON_START)
	await _frames(4)
	_check(view.pause_menu != null and view.pause_menu.visible, "Menu pauses")
	var focus = view.get_viewport().gui_get_focus_owner()
	_check(focus != null and focus.name == "resume", "the pause menu's Resume has the pad's focus (%s)" % [focus.name if focus else "none"])
	await _shoot("pause")
	await _tap(JOY_BUTTON_B)
	_check(not view.pause_menu.visible, "B resumes")


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failed += 1


func _hold(b: int, on: bool) -> void:
	pad.fake.buttons[b] = on


func _tap(b: int) -> void:
	_hold(b, true)
	await _frames(2)
	_hold(b, false)
	await _frames(2)


func _point(k: int, n: int) -> void:
	pad.fake.right = Vector2.from_angle(-PI * 0.5 + TAU * k / n)
	await _frames(3)


## The reticle onto a canvas point (as the right stick would take it).
func _aim(p: Vector2) -> void:
	view.camera.look_at_point(p)
	await _frames(1)
	view.pad_play.offset = (p - view.camera.get_screen_center_position()) * view.camera.zoom.x


func _frames(n: int) -> void:
	for f in n:
		await process_frame


func _seconds(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _ticks(n: int) -> void:
	var to: int = view.world.tick + n
	while view.world.tick < to:
		await process_frame


func _shoot(name: String) -> void:
	await _frames(2)
	shot += 1
	var path := "%s/%02d-%s.png" % [out, shot, name]
	root.get_texture().get_image().save_png(path)
	print("  saved ", path)


func _nearest_resource(near: Vector2, kind: String) -> Vector2:
	var map = view.map
	var best := Vector2.INF
	for c in map.width * map.height:
		if map.resource_at(c) == kind and map.left_at(c) > 0:
			var p := Iso.to_ground((c % map.width) * SimMap.TILE + SimMap.TILE / 2, (c / map.width) * SimMap.TILE + SimMap.TILE / 2)
			if p.distance_to(near) < best.distance_to(near):
				best = p
	return best


## A cell near pos where a house fits, as the ghost judges it.
func _open_ground(near: Vector2) -> Vector2i:
	var w = view.world
	var k: int = Economy.btype_of(w, "house")
	var c: Vector2i = view._ghost_cell(near)
	for r in range(3, 14):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if view._ghost_ok(k, c.x + dx, c.y + dy, 0) and w.map.can_build(c.x + dx, c.y + dy, w.btypes[k].size):
					return Vector2i(c.x + dx, c.y + dy)
	return c
