extends SceneTree
## Opens the sim debug view, plays a scene, saves a PNG.
## Run (needs a display):
##   godot --path . --script res://tests/sim_screenshot.gd -- out.png [map_id] [scene] ["prompt A" "prompt B"]
## Scenes: "armies" (both test armies march at each other; the default) or
## "opening:<tick>" (both sides autoplay their economy; shot at that tick, over player 1's base),
## or "battle:<tick>" (both test armies attack-move at each other; shot mid-fight at that tick).
## "tower" (side 1's town with enemy spears by its Watchtower; shot with arrows in the air).
## "heal" (side 0's healers by wounded spearmen, shot mid-heal; "heal:card" with a healer selected).
## "look:<x>:<y>[:zoom]" frames a tile with the fog lifted (for art checks).
## "pause" the pause menu; "end" / "defeat" the end screen.
## "loader[:<fraction>]": the match loader, with the bake cache off so it really bakes; shot once
## the bar passes that fraction (default 0.35).
## "life:<tick>[:dx:dy]": living towns (idle workers at chores, a damaged house), see _life.
## Prefix any scene with "ai-" to see it as in a match against the AI.

const Iso := preload("res://src/view/iso.gd")

const MEET := {"flat_test": Vector2(23.5, 33.5), "choke_test": Vector2(30.5, 16.5), "reed_meadow": Vector2(22.5, 26.5), "reed_meadow_2v2": Vector2(30.5, 36.5)}   # tiles
const SHOOT_AT_TICK := {"flat_test": 1100, "choke_test": 700, "reed_meadow": 1100, "reed_meadow_2v2": 1300}


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
	if scene.begins_with("loader"):
		preload("res://src/view/art/bake_cache.gd").enabled = false
	root.add_child(view)
	if scene.begins_with("loader"):
		var at := float(scene.get_slice(":", 1)) if ":" in scene else 0.35
		while view.loader == null or view.loader.shown < at or view.loader.layer.get_child_count() == 0:
			await process_frame
		for f in 30:   # the armies fade in
			await process_frame
		root.get_texture().get_image().save_png(out)
		print("saved ", out, " at ", view.loader.shown)
		quit()
		return
	while view.world == null or view.is_loading():   # the art bakes first, the loader fades out
		await process_frame
	view.camera.edge_scroll = false
	view.set_process_unhandled_input(false)          # a real mouse in the window mustn't change the shot
	view.camera.set_process_unhandled_input(false)
	if scene.begins_with("opening"):
		await _opening(view, int(scene.get_slice(":", 1)), float(scene.get_slice(":", 2)) if scene.get_slice_count(":") > 2 else 3.0)
	elif scene.begins_with("life"):
		var look := Vector2(float(scene.get_slice(":", 2)), float(scene.get_slice(":", 3))) if scene.get_slice_count(":") > 3 else Vector2(-1.5, 2.5)
		await _life(view, int(scene.get_slice(":", 1)), look)
	elif scene.begins_with("sheep"):
		await _sheep(view, scene.trim_prefix("sheep").trim_prefix(":"))
	elif scene == "tower":
		await _tower(view)
	elif scene.begins_with("wear"):
		await _wear(view, int(scene.get_slice(":", 1)))
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
	elif scene == "end" or scene == "defeat":   # the end screen, won (or lost) at once (a look only: the sim isn't played out)
		view.world.tick = 20 * 754
		view.world.winner = view.world.teams[0 if scene == "end" else 1]
		view._show_pause_menu(true)
	elif scene.begins_with("walls"):
		await _walls(view, scene == "walls:far")
	elif scene.begins_with("tip"):
		await _tip(view, int(scene.get_slice(":", 1)))
	elif scene == "card":
		await _card(view)
	elif scene.begins_with("heal"):
		await _heal(view, scene == "heal:card")
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


## Side 0's walls east of its Town Center, every way a line runs, put up finished: a palisade
## along sim y with a three-tile palisade gate in it, a stone wall along sim x with a stone gate,
## a palisade on each diagonal (down the screen and across it) and a stone wall that bends from
## straight to diagonal. Workers are laid as drags would (place_wall), the gates as clicks
## (BUILD with `along`). Then a worker walks out through the palisade gate (it shows open) and
## an enemy spearman stands at the stone gate (it stays shut); the shot is taken as the worker passes.
## "walls:far" frames them all at zoom 1.3 instead of 2.
func _walls(view, far := false) -> void:
	var w = view.world
	var Economy = load("res://src/sim/economy.gd")
	view.reveal = true   # the far walls and the enemy at the gate are past side 0's sight
	w.ages[0] = 2   # stone walls come with age 2
	var lines := [["palisade", Vector2i(16, 8), Vector2i(16, 18)], ["wall", Vector2i(17, 19), Vector2i(25, 19)],
		["palisade", Vector2i(22, 9), Vector2i(27, 14)], ["palisade", Vector2i(18, 24), Vector2i(23, 19)],
		["wall", Vector2i(26, 19), Vector2i(29, 19)], ["wall", Vector2i(30, 20), Vector2i(33, 23)]]
	for line in lines:
		var k: int = Economy.btype_of(w, line[0])
		for c in view.wall_cells(line[1], line[2]):
			if w.map.occupied[c.y * w.map.width + c.x] == 0 and w.map.can_build(c.x, c.y, 1):
				var b: int = Economy.place(w, 0, k, c.x, c.y)
				w.buildings.done[b] = 1
				w.buildings.hp[b] = w.btypes[k].hp
	for gate in [["palisade_gate", 16, 12, 1], ["stone_gate", 20, 19, 0]]:
		var k: int = Economy.btype_of(w, gate[0])
		for c in Economy._footprint(w, gate[1], gate[2], Economy.dims(w.btypes[k], gate[3])):
			if w.map.occupied[c] != 0:
				Economy.demolish(w, w.buildings.index_of(w.map.occupied[c]))
		var b: int = Economy.place(w, 0, k, gate[1], gate[2], gate[3])
		w.buildings.done[b] = 1
		w.buildings.hp[b] = w.btypes[k].hp
	w.issue(1, "spawn", {"slot": "spear", "count": 1, "x": 21500, "y": 20600})   # at the stone gate, outside
	for f in 30:
		await process_frame
	var walker: int = -1   # one of the workers by the Town Center, sent out through the palisade gate
	for i in w.units.count():
		if walker < 0 and w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker:
			walker = w.units.id[i]
	w.issue(0, "move", {"ids": [walker], "x": 19500, "y": 13500})
	view.camera.zoom = Vector2(1.3, 1.3) if far else Vector2(2.0, 2.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(23000, 16000) if far else Iso.to_screen(19000, 15000))
	for f in 1200:
		var i: int = w.units.index_of(walker)
		if i >= 0 and w.units.x[i] > 16000 and w.units.x[i] < 16800:
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


## Side 0's healers at work: four wounded spearmen by two healers by the Town Center; shot as a
## heal's motes rise. "heal:card" selects a healer, so the card says what it heals.
func _heal(view, card: bool) -> void:
	var w = view.world
	var Commands = load("res://src/sim/commands.gd")
	var s: Array = w.map.starts[0]
	var at := Vector2i(int(s[0]) + 4500, int(s[1]) + 3500)
	var before: int = w.units.count()
	w.issue(0, Commands.SPAWN, {"slot": "healer", "count": 2, "x": at.x - 1200, "y": at.y})
	w.issue(0, Commands.SPAWN, {"slot": "spear", "count": 4, "x": at.x + 900, "y": at.y + 300})
	while w.units.count() < before + 6:
		await process_frame
	var healers := []
	for i in w.units.count():
		var t: Dictionary = w.types[w.units.kind[i]]
		if w.units.owner[i] == 0 and t.slot == "spear":
			w.units.hp[i] = int(t.hp) / 4
		elif w.units.owner[i] == 0 and t.slot == "healer":
			healers.append(w.units.id[i])
	if card:
		view.selected[healers[0]] = true
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(at.x, at.y - 500))
	for f in 1200:   # until a heal's motes are well up
		await process_frame
		if view.fx.heals.any(func(h): return h.t > 0.35 and h.t < 0.5):
			break


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


## Living towns: a side's town (as "town") with its house at a fifth of its hit points (burning)
## and its barracks at a half (cracked); shot close.
func _wear(view, side: int) -> void:
	await _town(view, side)
	view.reveal = side != 0   # the other side's town: lift the fog
	var w = view.world
	for b in w.buildings.count():
		var t: Dictionary = w.btypes[w.buildings.kind[b]]
		if w.buildings.owner[b] == side and t.id in ["house", "barracks"]:
			w.buildings.hp[b] = t.hp * (20 if t.id == "house" else 55) / 100
	for f in 200:
		await process_frame
	for f in 30:   # and someone at every door, so the doorways show lit
		for v in view.bviews.values():
			v.door_pulse()
		await process_frame


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


## Living towns (milestone 17): both sides play their opening to the tick, then side 0 is left
## alone: four of its workers walk to just south of the Town Center and stand idle (two by two,
## so they chat, sit and sweep), one house is knocked to half and one building to a quarter (cracks,
## then fire). Shot over side 0's town. "life:<tick>:<tile dx>:<tile dy>" moves the camera.
func _life(view, at_tick: int, look: Vector2) -> void:
	view._set_autoplay(true)
	view.clock.speed = 16.0
	while view.world.tick < at_tick - 40:
		await process_frame
	view.clock.speed = 1.0
	view.clock.bots = [load("res://src/ai/bot.gd").new(1)]   # side 0 stops managing itself
	var w = view.world
	var Commands = load("res://src/sim/commands.gd")
	var s: Array = w.map.starts[0]
	var picked := []
	for i in w.units.count():
		if w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker and w.units.carry[i] == 0 and picked.size() < 4:
			picked.append(w.units.id[i])
	for k in picked.size():
		w.issue(0, Commands.MOVE, {"ids": [picked[k]], "x": s[0] - 3000 + (k / 2) * 3000 + (k % 2) * 900, "y": s[1] + 3200 + (k % 2) * 400})
	var near := []   # side 0's buildings nearest its start, but the Town Center and farms
	for b in w.buildings.count():
		var t: Dictionary = w.btypes[w.buildings.kind[b]]
		if w.buildings.owner[b] == 0 and w.buildings.done[b] == 1 and t.id != "town_center" and t.id != "farm":
			near.append([absi(w.buildings.cx[b] * 1000 - s[0]) + absi(w.buildings.cy[b] * 1000 - s[1]), b])
	near.sort()
	for k in mini(2, near.size()):
		var b: int = near[k][1]
		w.buildings.hp[b] = w.btypes[w.buildings.kind[b]].hp * (55 if k == 0 else 20) / 100
	var until: int = w.tick + 20 * 9
	while w.tick < until:
		await process_frame
	view.selected_building = 0
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(s[0] + look.x * 1000, s[1] + look.y * 1000))


## "sheep[:card|:mixed|:pen|:pen:card]": a worker walks round side 0's sheep and claims them; they gather in
## their pen by the Town Center, shot close up a while later. ":card" selects a sheep (its card
## and orders), ":mixed" a sheep and a worker (Stop and Slaughter).
func _sheep(view, what: String) -> void:
	var w = view.world
	var Commands = load("res://src/sim/commands.gd")
	var s: Array = w.map.starts[0]
	var worker := -1
	var sheep := []
	for i in w.units.count():
		if worker < 0 and w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker:
			worker = w.units.id[i]
		if w.types[w.units.kind[i]].get("animal", "") == "sheep" and absi(w.units.x[i] - s[0]) + absi(w.units.y[i] - s[1]) < 15000:
			sheep.append(w.units.id[i])
	var pen_id := 0
	if what.begins_with("pen"):   # a pen of side 0's by its Town Center first: the sheep go in
		var Economy = load("res://src/sim/economy.gd")
		var k: int = Economy.btype_of(w, "pen")
		var at: Array = load("res://src/sim/animals.gd").herd_spot(w, 0)   # the open patch by the Town Center
		var pb: int = Economy.place(w, 0, k, at[0] / 1000 - 1, at[1] / 1000 - 1, 0)
		w.buildings.done[pb] = 1
		w.buildings.hp[pb] = w.btypes[k].hp
		Economy.Pens.opened(w, pb)
		pen_id = w.buildings.id[pb]
	for id in sheep:
		var i: int = w.units.index_of(id)
		w.issue(0, Commands.MOVE, {"ids": [worker], "x": w.units.x[i], "y": w.units.y[i], "queue": 1})
	view.clock.speed = 16.0
	while w.tick < 1800:
		await process_frame
	view.clock.speed = 1.0
	var tc := -1
	for b in w.buildings.count():
		if tc < 0 and w.buildings.owner[b] == 0 and w.btypes[w.buildings.kind[b]].id == "town_center":
			tc = b
	var pen: Array = w.herd_spots.get(w.buildings.id[tc], [s[0], s[1]])
	if pen_id != 0:
		pen = load("res://src/sim/pens.gd").centre(w, w.buildings.index_of(pen_id))
	view.selected_building = pen_id if what == "pen:card" else 0
	if what == "card" or what == "mixed":
		view.selected[sheep[0]] = true
	if what == "mixed":
		view.selected[worker] = true
	for f in 40:
		await process_frame
	view.camera.zoom = Vector2(3.0, 3.0)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen((pen[0] + w.buildings.cx[tc] * 1000 + 1500) / 2, (pen[1] + w.buildings.cy[tc] * 1000 + 1500) / 2))


func _opening(view, at_tick: int, zoom := 3.0) -> void:
	view._set_autoplay(true)
	view.clock.speed = 16.0
	while view.world.tick < at_tick - 40:
		await process_frame
	view.clock.speed = 1.0
	while view.world.tick < at_tick:
		await process_frame
	view.selected_building = view.world.buildings.id[0]
	var s: Array = view.map.starts[0]
	view.camera.zoom = Vector2(zoom, zoom)
	view._on_zoom()
	view.camera.look_at_point(Iso.to_screen(s[0] - 1500, s[1] + 2500))
