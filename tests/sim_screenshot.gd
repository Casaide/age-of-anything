extends SceneTree
## Opens the sim debug view, plays a scene, saves a PNG.
## Run (needs a display):
##   godot --path . --script res://tests/sim_screenshot.gd -- out.png [map_id] [scene] ["prompt A" "prompt B"]
## Scenes: "armies" (both test armies march at each other; the default) or
## "opening:<tick>" (both sides autoplay their economy; shot at that tick, over player 1's base),
## or "battle:<tick>" (both test armies attack-move at each other; shot mid-fight at that tick).
## "look:<x>:<y>[:zoom]" frames a tile with the fog lifted (for art checks).
## Prefix any scene with "ai-" to see it as in a match against the AI.

const Iso := preload("res://src/view/iso.gd")

const MEET := {"flat_test": Vector2(23.5, 33.5), "choke_test": Vector2(30.5, 16.5)}   # tiles
const SHOOT_AT_TICK := {"flat_test": 1100, "choke_test": 700}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://sim_debug.png"
	var map_id: String = args[1] if args.size() > 1 else "flat_test"
	var scene: String = args[2] if args.size() > 2 else "armies"
	var vs_ai := scene.begins_with("ai-")   # "ai-<scene>": as in a match against the AI (its HUD, its fog)
	scene = scene.trim_prefix("ai-")
	var view = load("res://scenes/sim_debug.tscn").instantiate()
	view.prompts = [args[3], args[4]] if args.size() > 4 else view.DEFAULT_PROMPTS.duplicate()
	view.map_id = map_id
	view.vs_ai = vs_ai
	view.army = scene == "armies" or scene == "card" or scene.begins_with("battle") or scene.begins_with("ageup")
	root.add_child(view)
	while view.world == null or view.baking:   # the art bakes first
		await process_frame
	view.camera.edge_scroll = false
	view.set_process_unhandled_input(false)          # a real mouse in the window mustn't change the shot
	view.camera.set_process_unhandled_input(false)
	if scene.begins_with("opening"):
		await _opening(view, int(scene.get_slice(":", 1)))
	elif scene.begins_with("town"):
		await _town(view, int(scene.get_slice(":", 1)))
	elif scene.begins_with("ageup"):
		await _ageup(view, int(scene.get_slice(":", 1)))
	elif scene == "farm":
		await _farm(view)
	elif scene.begins_with("look"):   # look:<tile x>:<tile y>[:zoom]: the map there, fog lifted
		view.reveal = true
		var z := float(scene.get_slice(":", 3)) if scene.get_slice_count(":") > 3 else 3.0
		view.camera.zoom = Vector2(z, z)
		view._on_zoom()
		view.camera.look_at_point(Iso.to_screen(int(scene.get_slice(":", 1)) * 1000, int(scene.get_slice(":", 2)) * 1000))
	elif scene == "pause":
		view._toggle_pause_menu()
	elif scene == "walls":
		await _walls(view)
	elif scene.begins_with("tip"):
		await _tip(view, int(scene.get_slice(":", 1)))
	elif scene == "card":
		await _card(view)
	elif scene.begins_with("battle"):
		await _battle(view, map_id, int(scene.get_slice(":", 1)))
	else:
		await _armies(view, map_id)
	for f in 20:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out, " at tick ", view.world.tick)
	quit()


## Side 0 builds a farm by the Town Center and works it; the Town Center is selected with a
## rally point, so its flag shows.
func _farm(view) -> void:
	var w = view.world
	var s: Array = w.map.starts[0]
	var ids := []
	for i in w.units.count():
		if w.units.owner[i] == 0 and ids.size() < 2:
			ids.append(w.units.id[i])
	var cx: int = s[0] / 1000 + 3
	var cy: int = s[1] / 1000 + 2
	w.stock[1][0] = 500
	w.issue(0, "build", {"ids": ids, "building": "farm", "cx": cx, "cy": cy})
	view.clock.speed = 8.0
	var field: int = w.map.terrain_ids.find("field")
	while w.map.terrain[cy * w.map.width + cx] != field:
		await process_frame
	for f in 120:
		await process_frame
	view.clock.speed = 1.0
	view.selected_building = w.buildings.id[0]
	w.issue(0, "rally", {"building": w.buildings.id[0], "x": s[0] + 1000, "y": s[1] + 4000})
	for f in 30:
		await process_frame
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(cx * 1000 + 1000, cy * 1000 + 1000))


## Side 0's workers lay a wall line by the Town Center (as a drag would) and build it.
func _walls(view) -> void:
	var w = view.world
	var s: Array = w.map.starts[0]
	w.stock[w.resources.find("stone")][0] = 500
	for i in w.units.count():
		if w.units.owner[i] == 0:
			view.selected[w.units.id[i]] = true
	view.placing = "wall"
	var a := Vector2i(s[0] / 1000 + 3, s[1] / 1000 - 3)
	view.place_wall(a, a + Vector2i(0, 6))
	view.place_wall(a + Vector2i(1, 6), a + Vector2i(5, 6), true)
	view.clock.speed = 8.0
	for f in 900:
		await process_frame
	view.clock.speed = 1.0
	view.selected.clear()
	view.camera.zoom = Vector2(2.0, 2.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(a.x * 1000 + 2000, a.y * 1000 + 4000))


## The Town Center selected (or a worker, for "tip:1"), with the tooltip card of the panel's
## last button shown where a hover would put it.
func _tip(view, which: int) -> void:
	var w = view.world
	if which == 1:
		for i in w.units.count():
			if w.units.owner[i] == 0:
				view.selected[w.units.id[i]] = true
				break
	else:
		view.selected_building = w.buildings.id[0]
	for f in 10:
		await process_frame
	var buttons: Array = view.panel._buttons.get_children()
	var b = buttons[buttons.size() - 1 if which != 1 else 3]
	var card: Control = b._make_custom_tooltip(b.tooltip_text)
	view.panel.get_parent().add_child(card)
	card.position = b.global_position + Vector2(0, -260)


## One of side 0's spearmen selected, so the panel shows its unit card.
func _card(view) -> void:
	while view.world.units.count() <= 6:
		await process_frame
	var u = view.world.units
	for i in u.count():
		if u.owner[i] == 0 and view.world.types[u.kind[i]].slot == "spear":
			view.selected[u.id[i]] = true
			view.camera.look_at_point(Iso.to_screen(u.x[i], u.y[i]))
			break
	view.camera.zoom = Vector2(2.0, 2.0)
	view._on_zoom()


func _armies(view, map_id: String) -> void:
	while view.world.units.count() <= 6:   # spawns run two turns after they're issued
		await process_frame
	var meet: Vector2 = MEET[map_id] * 1000.0
	view.select_army(0)
	view.move_selected_to(Iso.to_screen(meet.x - 1000, meet.y - 1000))
	view.select_army(1)
	view.move_selected_to(Iso.to_screen(meet.x + 1000, meet.y + 1000))
	view.clock.speed = 8.0
	while view.world.tick < SHOOT_AT_TICK[map_id]:
		await process_frame
	view.clock.speed = 1.0
	view.select_army(0)
	view.show_flow = true
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(meet.x, meet.y))


func _battle(view, map_id: String, at_tick: int) -> void:
	while view.world.units.count() <= 6:
		await process_frame
	var meet: Vector2 = MEET[map_id] * 1000.0
	var w = view.world
	for p in 2:
		var ids := []
		for i in w.units.count():
			if w.units.owner[i] == p and not w.types[w.units.kind[i]].worker:
				ids.append(w.units.id[i])
		w.issue(p, "attack_move", {"ids": ids, "x": int(meet.x), "y": int(meet.y)})
	view.clock.speed = 8.0
	while w.tick < at_tick - 20:
		await process_frame
	view.clock.speed = 1.0
	while w.tick < at_tick:
		await process_frame
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(meet.x, meet.y))
	# Look where the fighting is: the middle of the units still alive.
	var c := Vector2.ZERO
	for i in w.units.count():
		c += Vector2(w.units.x[i], w.units.y[i])
	if w.units.count() > 0:
		c /= w.units.count()
		view.camera.look_at_point(Iso.to_screen(c.x, c.y))


## Both sides' armies stand by their Town Centers; both age up (twice, up to `to_age`);
## the shot is player 1's army in its new kit.
func _ageup(view, to_age: int) -> void:
	var w = view.world
	while w.units.count() <= 6:
		await process_frame
	for r in w.resources.size():
		for p in 2:
			w.stock[r][p] = 99999
	view.clock.speed = 16.0
	var Economy = load("res://src/sim/economy.gd")
	var Tech = load("res://src/sim/tech.gd")
	for age in range(2, to_age + 1):
		for p in 2:
			var s: Array = w.map.starts[p]
			for need in Tech.next_age(w, p).requires:   # what this age asks for, put up finished
				if not Tech.has_building(w, p, need):
					var k: int = Economy.btype_of(w, need)
					for tries in 30:
						var cx: int = s[0] / 1000 - 8 + (tries % 6) * 3
						var cy: int = s[1] / 1000 + 5 + (tries / 6) * 3
						if w.map.can_build(cx, cy, w.btypes[k].size):
							var b: int = Economy.place(w, p, k, cx, cy)
							w.buildings.done[b] = 1
							w.buildings.hp[b] = w.btypes[k].hp
							break
			w.issue(p, "age_up", {"building": w.buildings.id[p]})
		while w.ages[0] < age:
			await process_frame
	view.clock.speed = 1.0
	for f in 30:
		await process_frame
	var s: Array = w.map.starts[0]
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(s[0] + 1500, s[1] + 3500))


## A finished town for player `side`: Barracks, Stable, Watchtower and a house round
## the Town Center (placed straight into the world: a picture, not a match).
func _town(view, side: int) -> void:
	var w = view.world
	var Economy = load("res://src/sim/economy.gd")
	var s: Array = w.map.starts[side]
	var cx: int = s[0] / 1000
	var cy: int = s[1] / 1000
	for spec in [["barracks", cx + 3, cy - 1], ["stable", cx - 1, cy + 3], ["watchtower", cx + 3, cy + 3], ["house", cx - 4, cy - 1]]:
		var k: int = Economy.btype_of(w, spec[0])
		if w.map.can_build(spec[1], spec[2], w.btypes[k].size):
			var i: int = Economy.place(w, side, k, spec[1], spec[2])
			w.buildings.done[i] = 1
			w.buildings.hp[i] = w.btypes[k].hp
	for f in 40:
		await process_frame
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(s[0] + 1000, s[1] + 1500))


func _opening(view, at_tick: int) -> void:
	view._set_autoplay(true)
	view.clock.speed = 16.0
	while view.world.tick < at_tick - 40:
		await process_frame
	view.clock.speed = 1.0
	while view.world.tick < at_tick:
		await process_frame
	view.selected_building = view.world.buildings.id[0]
	var s: Array = view.map.starts[0]
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(s[0] - 1500, s[1] + 2500))
