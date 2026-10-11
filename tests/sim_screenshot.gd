extends SceneTree
## Opens the sim debug view, plays a scene, saves a PNG.
## Run (needs a display):
##   godot --path . --script res://tests/sim_screenshot.gd -- out.png [map_id] [scene] ["prompt A" "prompt B"]
## Scenes: "armies" (both test armies march at each other; the default) or
## "opening:<tick>" (both sides autoplay their economy; shot at that tick, over player 1's base),
## or "battle:<tick>" (both test armies attack-move at each other; shot mid-fight at that tick).
## "tower" (side 1's town with enemy spears by its Watchtower; shot with arrows in the air).
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
	view.army = scene == "armies" or scene == "card" or scene.begins_with("battle") or scene.begins_with("ageup") or scene == "orders_army"
	root.add_child(view)
	while view.world == null or view.baking:   # the art bakes first
		await process_frame
	view.camera.edge_scroll = false
	view.set_process_unhandled_input(false)          # a real mouse in the window mustn't change the shot
	view.camera.set_process_unhandled_input(false)
	if scene.begins_with("opening"):
		await _opening(view, int(scene.get_slice(":", 1)))
	elif scene == "tower":
		await _tower(view)
	elif scene.begins_with("town"):
		await _town(view, int(scene.get_slice(":", 1)))
	elif scene.begins_with("ageup"):
		await _ageup(view, int(scene.get_slice(":", 1)))
	elif scene == "ageing":
		await _ageing(view)
	elif scene == "farm":
		await _farm(view)
	elif scene.begins_with("enemyfarm"):
		await _enemy_farm(view, scene.ends_with(":seen"))
	elif scene == "orders":
		await _orders(view)
	elif scene == "orders_army":
		await _orders_army(view, map_id)
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


## Side 1 sows a farm west of its Town Center, in side 0's dark; the shot (as side 0) is over it.
## ":seen": side 0's worker looks at the farm and goes home; then, out of its sight, the farm is
## worked out and side 1 puts up a house beside it (side 0 should still see the crops, no house).
func _enemy_farm(view, seen: bool) -> void:
	var w = view.world
	var s: Array = w.map.starts[1]
	var worker := -1
	var scout := -1
	for i in w.units.count():
		if worker < 0 and w.units.owner[i] == 1:
			worker = w.units.id[i]
		if scout < 0 and w.units.owner[i] == 0:
			scout = w.units.id[i]
	var cx: int = s[0] / 1000 - 5
	var cy: int = s[1] / 1000 + 2
	var c: int = cy * w.map.width + cx
	w.stock[1][1] = 1000
	w.issue(1, "build", {"ids": [worker], "building": "farm", "cx": cx, "cy": cy})
	view.clock.speed = 8.0
	var field: int = w.map.terrain_ids.find("field")
	while w.map.terrain[c] != field:
		await process_frame
	view.clock.speed = 1.0
	if seen:
		var i: int = w.units.index_of(scout)
		var home := Vector2i(w.units.x[i], w.units.y[i])
		_teleport(w, scout, cx * 1000 - 2000, cy * 1000 + 500)
		for f in 30:
			await process_frame
		_teleport(w, scout, home.x, home.y)
		for f in 30:
			await process_frame
		w.map.amount[c] = 1   # worked out in a moment
		var Economy = load("res://src/sim/economy.gd")
		var b: int = Economy.place(w, 1, Economy.btype_of(w, "house"), cx - 3, cy)
		w.buildings.done[b] = 1
		view.clock.speed = 4.0
		while w.map.left_at(c) > 0:
			await process_frame
		view.clock.speed = 1.0
		for f in 30:
			await process_frame
	view.camera.zoom = Vector2(2.0, 2.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(cx * 1000, cy * 1000 + 1000))


func _teleport(w, id: int, x: int, y: int) -> void:
	var i: int = w.units.index_of(id)
	w.units.x[i] = x
	w.units.y[i] = y
	w.units.px[i] = x
	w.units.py[i] = y
	w.units.moving[i] = 0

## Queued orders, seen (Dominic): a worker builds a house, then is shift-told to walk out, lay a
## second house and go cutting reeds; a second worker stands by. Both selected, mid-build.
func _orders(view) -> void:
	var w = view.world
	var s: Array = w.map.starts[0]
	w.stock[w.resources.find("wood")][0] = 500
	var ids := []
	for i in w.units.count():
		if w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker and ids.size() < 2:
			ids.append(w.units.id[i])
	var cx: int = s[0] / 1000 + 3
	var cy: int = s[1] / 1000 - 3
	w.issue(0, "build", {"ids": [ids[0]], "building": "house", "cx": cx, "cy": cy})
	w.issue(0, "move", {"ids": [ids[0]], "x": (cx + 5) * 1000 + 500, "y": (cy + 1) * 1000 + 500, "queue": 1})
	var Economy = load("res://src/sim/economy.gd")
	var hk: int = Economy.btype_of(w, "house")
	var h2 := Vector2i(cx + 6, cy + 3)
	while not Economy.can_place(w, 0, hk, h2.x, h2.y):
		h2 += Vector2i(0, 1)
	w.issue(0, "build", {"ids": [ids[0]], "building": "house", "cx": h2.x, "cy": h2.y, "queue": 1})
	var wood := -1
	var best := 1 << 30
	for c in w.map.resource_cells:
		if w.map.resource_at(c) == "wood":
			var d: int = absi((c % w.map.width) - h2.x - 6) + absi((c / w.map.width) - h2.y + 5)
			if d < best:
				best = d
				wood = c
	w.issue(0, "gather", {"ids": [ids[0]], "cell": wood, "queue": 1})
	view.clock.speed = 4.0
	while w.tick < 160:   # the foundations down, the builder at work
		await process_frame
	view.clock.speed = 1.0
	for id in ids:
		view.selected[id] = true
	for f in 30:
		await process_frame
	view.reveal = true   # the reeds it goes to after are past what it sees yet
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen((cx + 5) * 1000, (cy + 2) * 1000))


## Queued orders for soldiers: side 0's army attack-moves to the meeting point, then is
## shift-told to fall back and attack-move round the flank; selected on the way.
func _orders_army(view, map_id: String) -> void:
	while view.world.tick < 24:   # every spawn has run
		await process_frame
	var w = view.world
	var meet: Vector2 = MEET[map_id] * 1000.0
	var ids := []
	for i in w.units.count():
		if w.units.owner[i] == 0 and not w.types[w.units.kind[i]].worker and not w.types[w.units.kind[i]].has("animal"):
			ids.append(w.units.id[i])
	w.issue(0, "attack_move", {"ids": ids, "x": int(meet.x), "y": int(meet.y)})
	w.issue(0, "move", {"ids": ids, "x": int(meet.x) - 4000, "y": int(meet.y) + 2000, "queue": 1})
	w.issue(0, "attack_move", {"ids": ids, "x": int(meet.x) + 1000, "y": int(meet.y) + 5000, "queue": 1})
	view.clock.speed = 4.0
	while w.tick < 300:
		await process_frame
	view.clock.speed = 1.0
	for id in ids:
		view.selected[id] = true
	var c := Vector2.ZERO
	for id in ids:
		var i: int = w.units.index_of(id)
		c += Vector2(w.units.x[i], w.units.y[i]) / ids.size()
	view.reveal = true
	view.camera.zoom = Vector2(2.0, 2.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen((c.x + meet.x) * 0.5, (c.y + meet.y) * 0.5 + 1500))


## Side 0's workers lay a palisade line by the Town Center with a palisade gate in it, and a
## stone wall with a stone gate (as drags would), and build them; then a worker walks out
## through the palisade gate (it shows open) and the shot is taken as it passes.
func _walls(view) -> void:
	var w = view.world
	var s: Array = w.map.starts[0]
	w.stock[w.resources.find("stone")][0] = 500
	w.stock[w.resources.find("wood")][0] = 500
	w.ages[0] = 2   # stone walls come with age 2
	for i in w.units.count():
		if w.units.owner[i] == 0:
			view.selected[w.units.id[i]] = true
	var a := Vector2i(s[0] / 1000 + 3, s[1] / 1000 - 3)
	for line in [["palisade", a, a + Vector2i(0, 6)], ["palisade_gate", a + Vector2i(0, 3), a + Vector2i(0, 3)],
			["wall", a + Vector2i(1, 6), a + Vector2i(5, 6)], ["stone_gate", a + Vector2i(3, 6), a + Vector2i(3, 6)]]:
		view.placing = line[0]
		view.place_wall(line[1], line[2], line[0] != "palisade")
	view.placing = ""
	view.clock.speed = 8.0
	for f in 1200:
		await process_frame
	view.clock.speed = 1.0
	view.selected.clear()
	var walker: int = -1   # a builder (they end up outside the palisade), sent home through its gate
	var west := 1 << 30
	for i in w.units.count():
		if w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker and w.units.x[i] < west:
			west = w.units.x[i]
			walker = w.units.id[i]
	w.issue(0, "move", {"ids": [walker], "x": (a.x - 2) * 1000 + 500, "y": (a.y + 3) * 1000 + 500})
	view.camera.zoom = Vector2(2.0, 2.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(a.x * 1000 + 2000, a.y * 1000 + 4000))
	for f in 1200:
		var i: int = w.units.index_of(walker)
		if i >= 0 and absi(w.units.x[i] - (a.x * 1000 + 500)) < 400 and absi(w.units.y[i] - ((a.y + 3) * 1000 + 500)) < 600:
			break
		await process_frame


## The Town Center selected (or a worker: "tip:1" its build pages, "tip:2" the military page),
## with the tooltip card of the panel's last button (a worker's first) shown where a hover would put it.
func _tip(view, which: int) -> void:
	var w = view.world
	if which >= 1:
		for i in w.units.count():
			if w.units.owner[i] == 0:
				view.selected[w.units.id[i]] = true
				break
	else:
		view.selected_building = w.buildings.id[0]
		for k in 6:   # a queue to show: one in training, five waiting
			view._train(view.selected_building, "worker")
		for f in 300:   # orders run a couple of turns after they're given
			if w.buildings.queue[0].size() >= 6:
				break
			await process_frame
	for f in 10:
		await process_frame
	if which == 2:
		view.build_page = "military"
		for f in 10:
			await process_frame
	var buttons: Array = view.panel.action_buttons()
	var b = buttons[buttons.size() - 1 if which == 0 else 0]
	var card: Control = b._make_custom_tooltip(b.tooltip_text)   # a popup in the game: outside the scaled HUD
	view.hud_root.get_parent().add_child(card)
	await process_frame
	card.position = Vector2(b.global_position.x, view.panel.global_position.y - card.size.y - 12)   # above the panel, clear of its captions


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
		for p in 2:   # and every line's upgrade for this age (line kit no longer comes with the age)
			for r in w.tech.research.size():
				if w.tech.research[r].get("line_age", 0) == age:
					w.researched[p][r] = 1
			Tech.retype(w, p)
	view.clock.speed = 1.0
	for f in 30:
		await process_frame
	var s: Array = w.map.starts[0]
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(s[0] + 1500, s[1] + 3500))


## Side 0 a third of the way through its age-up, its Town Center selected (the top bar's
## age badge and the panel's queue show it).
func _ageing(view) -> void:
	var w = view.world
	while w.units.count() <= 6:
		await process_frame
	for r in w.resources.size():
		w.stock[r][0] = 99999
	var Economy = load("res://src/sim/economy.gd")
	var Tech = load("res://src/sim/tech.gd")
	var s: Array = w.map.starts[0]
	for need in Tech.next_age(w, 0).requires:
		var k: int = Economy.btype_of(w, need)
		for tries in 30:
			var cx: int = s[0] / 1000 - 8 + (tries % 6) * 3
			var cy: int = s[1] / 1000 + 5 + (tries / 6) * 3
			if w.map.can_build(cx, cy, w.btypes[k].size):
				var b: int = Economy.place(w, 0, k, cx, cy)
				w.buildings.done[b] = 1
				w.buildings.hp[b] = w.btypes[k].hp
				break
	var tc := -1
	for b in w.buildings.count():
		if tc < 0 and w.buildings.owner[b] == 0 and w.btypes[w.buildings.kind[b]].id == "town_center":
			tc = b
	print("ageing: ", Tech.why_not(w, 0, tc, ""))
	w.issue(0, "age_up", {"building": w.buildings.id[tc]})
	for n in 2:   # workers queued behind it: one queue, units and research in the order clicked
		w.issue(0, "train", {"building": w.buildings.id[tc], "slot": "worker"})
	view.clock.speed = 16.0
	while Tech.head(w, tc) != Tech.AGE_UP or w.buildings.train[tc] * 3 < Tech.head_ticks(w, tc):
		await process_frame
	view.clock.speed = 1.0
	view.clock.paused = true
	view.selected_building = w.buildings.id[tc]
	view.camera.look_at_point(Iso.to_screen(s[0] + 1500, s[1] + 1500))


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


## Side 1's town, and a few of side 0's spears by its Watchtower: shot once the tower's
## arrows are in the air.
func _tower(view) -> void:
	await _town(view, 1)
	var w = view.world
	var s: Array = w.map.starts[1]
	view.reveal = true
	w.issue(0, load("res://src/sim/commands.gd").SPAWN, {"slot": "spear", "count": 4, "x": s[0] + 7000, "y": s[1] + 6000})
	for f in 600:
		await process_frame
		if view.fx.shots.size() > 0:
			break
	for f in 4:
		await process_frame
	view.camera.look_at_point(Iso.to_screen(s[0] + 4500, s[1] + 4500))


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
