extends Node2D
## Sim debug view: the headless sim drawn isometrically, interpolated between
## ticks. Selection happens on screen (what you see is what you select); every
## order goes through the command queue, so F5 saves a replay of exactly what
## happened and F9 plays it back, checking hashes as it goes.
##
## You command one side at a time (Tab switches). F6 hands both sides to the
## economy bot, which is the easiest way to watch an opening.

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const SimClock := preload("res://src/sim_clock.gd")
const Iso := preload("res://src/view/iso.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const TerrainView := preload("res://src/view/art/terrain_view.gd")
const BuildingArt := preload("res://src/view/art/building_art.gd")
const Paths := preload("res://scenes/art_pixel/paths.gd")
const RtsCamera := preload("res://src/view/rts_camera.gd")
const CommandPanel := preload("res://src/view/command_panel.gd")
const Commands := preload("res://src/sim/commands.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Economy := preload("res://src/sim/economy.gd")
const Replay := preload("res://src/sim/replay.gd")
const EcoBot := preload("res://src/ai/eco_bot.gd")

const MAP_IDS := ["flat_test", "choke_test"]
const SEED := 1
const DEFAULT_PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers"]
## Random prompts for Shift/Ctrl+G. Silly is fine; the generator copes with anything.
const RANDOM_PROMPTS := [
	"angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans",
	"flying greeks with wings", "giant spiders", "tiny vikings", "spooky beetle knights",
	"pegasus riding spartans", "ww2 americans riding mongolian ponies", "forest rats on ponies",
	"heavy beetle lancers", "frog knights with iron helmets", "sneaky spider archers",
]
const START_ARMY := [["worker", 3], ["spear", 5], ["skirmisher", 4], ["archer", 4], ["large", 2]]
const REPLAY_PATH := "user://replays/last.json"
const BODY_LIFT := 10.0      # pixels from a unit's feet up to the middle of its body
const PICK_PX := 16.0        # click radius in screen pixels
const DRAG_START_PX := 6.0   # screen pixels before a left press becomes a box
const RING := Color("#f2e9c9")
const FLOW := Color("#f2c94c")
const CARRY := {1: Color("#d65a7a"), 2: Color("#a07a4a")}
const GOOD := Color(0.4, 1.0, 0.4, 0.35)
const BAD := Color(1.0, 0.3, 0.3, 0.35)

var lib
var gen
var rules: Dictionary
var map_id: String = MAP_IDS[0]
var map: SimMap
var world: World
var clock: SimClock
var camera: RtsCamera
var kit: ArtKit             # bakes the pixel art for the races in play
var ground_holder: Node2D   # the terrain (rebuilt per map)
var ground: TerrainView
var doodads := {}           # cell -> [nodes]: cosmetic props, cleared where buildings go up
var baking := false
var built_count := -1       # finished buildings when the paths were last planned
var palette: ColorRect      # optional whole-frame palette pass (P)
var marks: Node2D           # under units: selection rings, move lines, flow arrows
var layer: Node2D           # units, buildings and resource props, y-sorted
var overlay: Node2D         # over everything: selection box, placement ghost, carried loads
var hud: Label
var bar: Label
var panel: CommandPanel
var views := {}             # unit id -> UnitView (view side only; never feeds the sim)
var bviews := {}            # building id -> BuildingArt
var rviews := {}            # resource cell -> its prop (reed clump, bug bush)
var selected := {}          # unit id -> true
var selected_building := 0  # building id, or 0
var active := 0             # the side you're commanding
var placing := ""           # building type being placed, or ""
var flags: Array = []       # [{pos, t}] recent move targets
var playback := {}          # the replay being played, or empty when live
var checked := 0            # world.hashes entries already compared
var desync := -1
var show_flow := false
var autoplay := false
var army := false           # also spawn a test army per side (F7 toggles and restarts)
var prompts: Array = []     # set before adding to the tree, else taken from the command line
var rerolls: Array = [0, 0] # per side; G rerolls side 0
var press_screen := Vector2.INF
var press_world := Vector2.ZERO
var boxing := false


func _ready() -> void:
	lib = DataLib.new()
	gen = Generator.new(lib)
	rules = DataLib.load_json("res://data/rules/default.json")

	clock = SimClock.new()
	add_child(clock)
	kit = ArtKit.new()
	kit.lib = lib
	add_child(kit)
	ground_holder = Node2D.new()
	add_child(ground_holder)
	marks = Node2D.new()
	marks.draw.connect(_draw_marks)
	add_child(marks)
	layer = Node2D.new()
	layer.y_sort_enabled = true
	add_child(layer)
	overlay = Node2D.new()
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	camera = RtsCamera.new()
	# Zoom in whole art pixels (the art is baked at ArtKit.ART_SCALE per canvas unit).
	camera.steps = [ArtKit.ART_SCALE * 0.5, ArtKit.ART_SCALE, ArtKit.ART_SCALE * 2.0, ArtKit.ART_SCALE * 3.0]
	camera.zoom = Vector2.ONE * ArtKit.ART_SCALE * 2.0
	camera.zoomed.connect(_on_zoom)
	add_child(camera)

	var post := CanvasLayer.new()
	post.layer = 1
	add_child(post)
	palette = ColorRect.new()
	palette.set_anchors_preset(Control.PRESET_FULL_RECT)
	palette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = load("res://src/view/art/palette_screen.gdshader")
	var pal: Image = ArtKit.palette(lib)
	pm.set_shader_parameter("palette", ImageTexture.create_from_image(pal))
	pm.set_shader_parameter("count", pal.get_width())
	palette.material = pm
	palette.visible = false
	post.add_child(palette)

	var ui := CanvasLayer.new()
	ui.layer = 2
	add_child(ui)
	hud = _label(12, Vector2(12, 44))
	ui.add_child(hud)
	bar = _label(17, Vector2(12, 10))
	ui.add_child(bar)
	panel = CommandPanel.new()
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 12
	panel.offset_bottom = -12
	ui.add_child(panel)

	if prompts.is_empty():
		var args := OS.get_cmdline_user_args()
		prompts = DEFAULT_PROMPTS.duplicate()
		for i in mini(args.size(), 2):
			prompts[i] = args[i]
	start_live(prompts)


func _label(size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	return l


# ------------------------------------------------------------------ modes

func start_live(race_prompts: Array) -> void:
	if baking:
		return
	map = SimMap.load_id(map_id)
	var races := []
	for k in race_prompts.size():
		races.append(gen.generate(race_prompts[k], rules, rerolls[k]))
	await _bake(races)
	_attach(World.new(SEED, map, races, rules))
	playback = {}
	if army:
		for p in races.size():
			for entry in START_ARMY:
				world.issue(p, Commands.SPAWN, {"slot": entry[0], "count": entry[1], "x": map.starts[p][0], "y": map.starts[p][1]})
	_set_autoplay(autoplay)
	camera.look_at_point(Iso.to_screen(map.starts[active][0], map.starts[active][1]) + Vector2(0, 60))


func start_replay(rep: Dictionary) -> void:
	if baking:
		return
	map_id = rep.map
	var w: World = Replay.build_world(rep, lib)
	await _bake(w.races)
	_attach(w, rep.ticks)
	playback = rep
	clock.bots = []


## Bake the art for these races (only what isn't baked yet), showing a note meanwhile.
func _bake(races: Array) -> void:
	baking = true
	clock.paused = true
	bar.text = "Baking the art..."
	await kit.prepare(races, races.map(func(r): return Color(lib.palettes.teams[races.find(r)])))
	baking = false


func _attach(w: World, end_tick := -1) -> void:
	for d in [views, bviews, rviews]:
		for k in d:
			d[k].queue_free()
		d.clear()
	for c in doodads:
		for n in doodads[c]:
			n.queue_free()
	doodads.clear()
	built_count = -1
	selected.clear()
	selected_building = 0
	placing = ""
	flags.clear()
	world = w
	map = w.map
	checked = 0
	desync = -1
	clock.reset(w, end_tick)
	clock.paused = false
	if ground:
		ground.queue_free()
	ground = TerrainView.new()
	ground_holder.add_child(ground)
	ground.build(map)
	ground.set_art_px(camera.zoom.x / ArtKit.ART_SCALE)
	camera.bounds = Iso.map_rect(map.width, map.height)
	var picks := TerrainView.variant_picks(map.resource_cells, map.width, ArtKit.DOODADS.bush, hash(map.id))
	for c in map.resource_cells:
		var kind := "bush" if map.terrain_resource[map.terrain[c]] == "food" else "reeds"
		var holder := Node2D.new()
		holder.position = Iso.to_screen((c % map.width) * 1000 + 500, (c / map.width) * 1000 + 500)
		holder.add_child(kit.doodad(kind, picks[c]))
		holder.set_meta("res", {"kind": kind, "pick": picks[c], "stage": 0, "full": map.amount[c], "gone": 0.0})
		layer.add_child(holder)
		rviews[c] = holder
	_refresh_paths()
	for n in ground.scatter(kit, layer, _keep_clear):
		var t := Iso.to_milli(n.position)
		var c := map.cell_of(t.x, t.y)
		if not doodads.has(c):
			doodads[c] = []
		doodads[c].append(n)


## Doodads stay off resources, start areas and anything built.
func _keep_clear(t: Vector2) -> bool:
	for y in range(int(t.y) - 1, int(t.y) + 2):
		for x in range(int(t.x) - 1, int(t.x) + 2):
			if x < 0 or y < 0 or x >= map.width or y >= map.height:
				continue
			var c := y * map.width + x
			if map.amount[c] > 0 or map.occupied[c] != 0:
				return true
	for s in map.starts:
		if t.distance_to(Vector2(s[0], s[1]) / 1000.0) < 4.0:
			return true
	return false


## Each side's paths in its culture's style: from its Town Center's door to its other
## finished buildings and the nearest bug bushes, reeds and shore. Re-planned when a
## building is finished.
func _refresh_paths() -> void:
	var bs := world.buildings
	var owners := []
	for p in world.races.size():
		var mine := []
		for b in bs.count():
			if bs.owner[b] == p and bs.done[b] == 1:
				mine.append(b)
		if mine.is_empty():
			continue
		mine.sort_custom(func(a, b): return bs.size[a] > bs.size[b] or (bs.size[a] == bs.size[b] and bs.id[a] < bs.id[b]))
		var style: Dictionary = lib.families[world.races[p].family].get("paths", {"style": "trail", "width": 0.36})
		var hub := _door(mine[0])
		var targets := []
		for b in mine.slice(1):
			targets.append(_door(b))
		for kind in ["food", "wood"]:
			var t := _nearest_resource_edge(kind, hub)
			if t.x >= 0:
				targets.append(t)
		owners.append({"style": style.style, "width": float(style.width), "hub": hub, "targets": targets})
	ground.set_paths(owners)


## The spot in front of a building's door (doors face +y, the viewer's lower left).
func _door(b: int) -> Vector2:
	var bs := world.buildings
	return Vector2(bs.cx[b] + bs.size[b] * 0.5, bs.cy[b] + bs.size[b] + 0.45)


## The free tile beside a resource of this kind that's nearest the hub (within reach).
func _nearest_resource_edge(kind: String, hub: Vector2) -> Vector2:
	var best := Vector2(-1, -1)
	var best_d := Paths.REACH
	for c in map.resource_cells:
		if map.amount[c] <= 0 or map.terrain_resource[map.terrain[c]] != kind:
			continue
		var x := c % map.width
		var y := c / map.width
		if Vector2(x, y).distance_to(hub) > best_d + 2.0:
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var t := Vector2(x + d.x, y + d.y) + Vector2(0.5, 0.5)
			if not ground.blocked(t) and t.distance_to(hub) < best_d:
				best_d = t.distance_to(hub)
				best = t
	return best


func _on_zoom() -> void:
	if ground:
		ground.set_art_px(camera.zoom.x / ArtKit.ART_SCALE)
	palette.material.set_shader_parameter("art_px", camera.zoom.x / ArtKit.ART_SCALE)


func _set_autoplay(on: bool) -> void:
	autoplay = on
	clock.bots = [EcoBot.new(0), EcoBot.new(1)] if on and playback.is_empty() else []


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if baking or world == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if placing != "":
			if event.pressed:
				place_at(get_global_mouse_position(), event.shift_pressed)
			return
		if event.pressed and event.double_click:
			select_same_type_on_screen(get_global_mouse_position(), event.shift_pressed)
			press_screen = Vector2.INF
		elif event.pressed:
			press_screen = event.position
			press_world = get_global_mouse_position()
		elif press_screen != Vector2.INF:
			if boxing:
				select_box(press_world, get_global_mouse_position(), event.shift_pressed)
			else:
				select_at(get_global_mouse_position(), event.shift_pressed)
			press_screen = Vector2.INF
			boxing = false
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if placing != "":
			placing = ""
		else:
			smart_order(get_global_mouse_position())
	elif event is InputEventMouseMotion and press_screen != Vector2.INF:
		boxing = boxing or event.position.distance_to(press_screen) > DRAG_START_PX
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				clock.paused = not clock.paused
			KEY_1, KEY_2:
				select_army(event.keycode - KEY_1, event.shift_pressed)
			KEY_TAB:
				active = 1 - active
				_clear_selection()
			KEY_Q:
				train_worker()
			KEY_H:
				start_placing("house")
			KEY_C:
				start_placing("town_center")
			KEY_ESCAPE:
				placing = ""
			KEY_BRACKETRIGHT:
				clock.speed = minf(clock.speed * 2.0, 16.0)
			KEY_BRACKETLEFT:
				clock.speed = maxf(clock.speed / 2.0, 0.25)
			KEY_F3:
				show_flow = not show_flow
			KEY_P:
				palette.visible = not palette.visible
			KEY_F5:
				Replay.save(Replay.record(world), REPLAY_PATH)
				print("Saved replay: ", ProjectSettings.globalize_path(REPLAY_PATH))
			KEY_F6:
				_set_autoplay(not autoplay)
			KEY_F7:
				army = not army
				start_live(world.races.map(func(r): return r.prompt))
			KEY_F9:
				if FileAccess.file_exists(REPLAY_PATH):
					start_replay(Replay.load_file(REPLAY_PATH))
			KEY_M:
				map_id = MAP_IDS[(MAP_IDS.find(map_id) + 1) % MAP_IDS.size()]
				start_live(world.races.map(func(r): return r.prompt))
			KEY_R:
				start_live(world.races.map(func(r): return r.prompt))
			KEY_G:
				regen_army(1 if event.ctrl_pressed else 0, event.shift_pressed or event.ctrl_pressed)


## Test hotkey: new army for one side and a fresh match. A new random reroll of the
## same prompt, or (with a modifier) a random prompt. View-side randomness only picks
## the inputs; the race itself is generated deterministically from them.
func regen_army(side: int, new_prompt: bool) -> void:
	var ps: Array = world.races.map(func(r): return r.prompt)
	if new_prompt:
		ps[side] = RANDOM_PROMPTS[randi() % RANDOM_PROMPTS.size()]
		rerolls[side] = 0
	else:
		rerolls[side] = randi() % 100000
	start_live(ps)
	print("Side %d is now %s (\"%s\", reroll %d)" % [side + 1, world.races[side].name, ps[side], rerolls[side]])


func _clear_selection() -> void:
	selected.clear()
	selected_building = 0
	placing = ""


func _body(view: Node2D) -> Vector2:
	return view.position - Vector2(0, BODY_LIFT)


func _cell_at(pos: Vector2) -> int:
	var m := Iso.to_milli(pos)
	return map.cell_of(m.x, m.y)


## Click: the unit whose body is nearest the cursor (within PICK_PX on screen),
## else the building under it.
func select_at(pos: Vector2, add := false) -> void:
	if not add:
		_clear_selection()
	var best := 0
	var best_d := PICK_PX / camera.zoom.x
	for id in views:
		var d := _body(views[id]).distance_to(pos)
		if d < best_d or (d == best_d and id < best):
			best_d = d
			best = id
	if best != 0:
		selected_building = 0
		if add and selected.has(best):
			selected.erase(best)
		else:
			selected[best] = true
		active = world.units.owner[world.units.index_of(best)]
		return
	for probe in [pos, pos + Vector2(0, 14)]:   # clicking a wall or roof hits the footprint below
		var bid: int = map.occupied[_cell_at(probe)]
		if bid != 0:
			selected.clear()
			selected_building = bid
			active = world.buildings.owner[world.buildings.index_of(bid)]
			return


## Box: every unit whose body is inside the dragged rectangle (canvas coords; no rotation).
func select_box(a: Vector2, b: Vector2, add := false) -> void:
	if not add:
		_clear_selection()
	var r := Rect2(a, Vector2.ZERO).expand(b)
	for id in views:
		if r.has_point(_body(views[id])):
			selected[id] = true


## Double-click: every unit of the clicked unit's type and owner that's on screen.
func select_same_type_on_screen(pos: Vector2, add := false) -> void:
	select_at(pos, false)
	if selected.size() != 1:
		return
	var i := world.units.index_of(selected.keys()[0])
	var kind := world.units.kind[i]
	if not add:
		selected.clear()
	var screen := Rect2(camera.get_screen_center_position() - get_viewport_rect().size * 0.5 / camera.zoom,
		get_viewport_rect().size / camera.zoom)
	for j in world.units.count():
		var id := world.units.id[j]
		if world.units.kind[j] == kind and views.has(id) and screen.has_point(views[id].position):
			selected[id] = true


func select_army(player: int, add := false) -> void:
	if not add:
		_clear_selection()
	active = player
	for i in world.units.count():
		if world.units.owner[i] == player:
			selected[world.units.id[i]] = true


## Selected unit ids per owner, ascending.
func _selected_by_owner() -> Array:
	var ids := selected.keys()
	ids.sort()
	var out := [[], []]
	for id in ids:
		var i := world.units.index_of(id)
		if i >= 0:
			out[world.units.owner[i]].append(id)
	return out


func _selected_workers() -> Array:
	var out := []
	for id in _selected_by_owner()[active]:
		if world.types[world.units.kind[world.units.index_of(id)]].worker:
			out.append(id)
	return out


## Right-click: rally for a selected building; for units gather a resource, help
## build your foundation, or move. Ignored while a replay plays.
func smart_order(pos: Vector2) -> void:
	if not playback.is_empty():
		return
	var m := Iso.to_milli(pos)
	var cell := map.cell_of(m.x, m.y)
	if selected_building != 0:
		var b := world.buildings.index_of(selected_building)
		if b >= 0 and world.buildings.owner[b] == active:
			world.issue(active, Commands.RALLY, {"building": selected_building, "x": m.x, "y": m.y})
			flags.append({"pos": pos, "t": 1.0})
		return
	var groups := _selected_by_owner()
	var bid: int = map.occupied[cell]
	for p in groups.size():
		var ids: Array = groups[p]
		if ids.is_empty():
			continue
		if map.resource_at(cell) != "":
			world.issue(p, Commands.GATHER, {"ids": ids, "cell": cell})
		elif bid != 0 and _is_foundation_of(bid, p):
			world.issue(p, Commands.HELP_BUILD, {"ids": ids, "target": bid})
		else:
			world.issue(p, Commands.MOVE, {"ids": ids, "x": m.x, "y": m.y})
	flags.append({"pos": pos, "t": 1.0})


func _is_foundation_of(bid: int, p: int) -> bool:
	var b := world.buildings.index_of(bid)
	return b >= 0 and world.buildings.owner[b] == p and world.buildings.done[b] == 0


## Kept for tests and scripts: move the selection to a canvas point.
func move_selected_to(pos: Vector2) -> void:
	if not playback.is_empty() or selected.is_empty():
		return
	var m := Iso.to_milli(pos)
	var groups := _selected_by_owner()
	for p in groups.size():
		if not groups[p].is_empty():
			world.issue(p, Commands.MOVE, {"ids": groups[p], "x": m.x, "y": m.y})
	flags.append({"pos": pos, "t": 1.0})


func train_worker() -> void:
	var b := world.buildings.index_of(selected_building)
	if b < 0 or world.buildings.owner[b] != active or not playback.is_empty():
		return
	world.issue(active, Commands.TRAIN, {"building": selected_building, "slot": "worker"})


func start_placing(building: String) -> void:
	if not _selected_workers().is_empty() and playback.is_empty():
		placing = building


## Top-left cell of the footprint the ghost shows at a canvas point.
func _ghost_cell(pos: Vector2) -> Vector2i:
	var m := Iso.to_milli(pos)
	var size: int = world.btypes[Economy.btype_of(world, placing)].size
	return Vector2i(m.x / 1000 - (size - 1) / 2, m.y / 1000 - (size - 1) / 2)


func place_at(pos: Vector2, keep := false) -> void:
	var c := _ghost_cell(pos)
	var workers := _selected_workers()
	if workers.is_empty():
		placing = ""
		return
	world.issue(active, Commands.BUILD, {"ids": workers, "building": placing, "cx": c.x, "cy": c.y})
	if not keep:
		placing = ""


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	if baking or world == null:
		return
	_sync_views()
	_sync_buildings()
	_sync_resources()
	_check_replay()
	for f in flags:
		f.t -= delta
	flags = flags.filter(func(f): return f.t > 0.0)
	marks.queue_redraw()
	overlay.queue_redraw()
	bar.text = _bar_text()
	hud.text = _hud_text()
	_update_panel()


func _sync_views() -> void:
	var u := world.units
	var a := clock.alpha
	var alive := {}
	for i in u.count():
		var id := u.id[i]
		alive[id] = true
		var view: UnitView = views.get(id)
		if view == null:
			view = _make_view(u.kind[i], u.owner[i])
			views[id] = view
		var dx := u.x[i] - u.px[i]
		var dy := u.y[i] - u.py[i]
		view.position = Iso.to_screen(u.px[i] + dx * a, u.py[i] + dy * a)
		view.walking = dx != 0 or dy != 0
		if absi(dx - dy) > 4:
			view.face(dx - dy)   # screen x direction
		elif u.work[i] > 0 and u.task[i] == Economy.GATHER and u.work[i] % 10 == 1:
			view.flourish()      # chop chop
	for id in views.keys():
		if not alive.has(id):
			views[id].queue_free()
			views.erase(id)
			selected.erase(id)


func _sync_buildings() -> void:
	var bs := world.buildings
	for b in bs.count():
		var id := bs.id[b]
		var view: BuildingArt = bviews.get(id)
		if view == null:
			var t: Dictionary = world.btypes[bs.kind[b]]
			var arch: String = lib.families[world.races[bs.owner[b]].family].get("architecture", "thatch")
			view = BuildingArt.new()
			view.setup(kit, "%s:%s" % [arch, t.id], bs.cx[b], bs.cy[b], bs.size[b], Color(lib.palettes.teams[bs.owner[b]]))
			layer.add_child(view)
			bviews[id] = view
			_clear_doodads(bs.cx[b], bs.cy[b], bs.size[b])
		var t: Dictionary = world.btypes[bs.kind[b]]
		view.set_state(bs.done[b] == 1, float(bs.progress[b]) / float(t.build_ticks))
	var built := 0
	for b in bs.count():
		built += bs.done[b]
	if built != built_count:
		built_count = built
		_refresh_paths()


## Doodads under (and right around) a new building go.
func _clear_doodads(cx: int, cy: int, size: int) -> void:
	for y in range(cy - 1, cy + size + 1):
		for x in range(cx - 1, cx + size + 1):
			var c := y * map.width + x
			if x >= 0 and y >= 0 and x < map.width and y < map.height and doodads.has(c):
				for n in doodads[c]:
					n.queue_free()
				doodads.erase(c)


## Resource props show what's left in stages; a used-up bush fades away, used-up reeds
## leave stubble for a while first.
func _sync_resources() -> void:
	var dt := get_process_delta_time()
	for c in rviews.keys():
		var h: Node2D = rviews[c]
		var r: Dictionary = h.get_meta("res")
		var stage := ArtKit.resource_stage(r.kind, map.amount[c], r.full)
		if stage != r.stage:
			r.stage = stage
			h.get_child(0).queue_free()
			h.add_child(kit.doodad(r.kind, r.pick, stage))
		if map.amount[c] <= 0:
			r.gone += dt
			var linger := 6.0 if r.kind == "reeds" else 0.0
			h.modulate.a = clampf(1.0 - (r.gone - linger) / 1.5, 0.0, 1.0)
			if h.modulate.a <= 0.0:
				h.queue_free()
				rviews.erase(c)


func _make_view(kind: int, owner: int) -> UnitView:
	var t: Dictionary = world.types[kind]
	var view := UnitView.new()
	view.build(t.recipe, lib, Color(lib.palettes.teams[owner]), t.speed / World.SPEED_SCALE)
	view.scale = Vector2.ONE * ArtKit.UNIT_SCALE
	view.pose_steps = 8
	view.art_px = ArtKit.ART_SCALE
	layer.add_child(view)
	return view


func _check_replay() -> void:
	if playback.is_empty() or checked >= world.hashes.size():
		return
	var want := {}
	for c in playback.checkpoints:
		want[c[0]] = c[1]
	while checked < world.hashes.size():
		var got: Array = world.hashes[checked]
		checked += 1
		if desync < 0 and want.has(got[0]) and want[got[0]] != got[1]:
			desync = got[0]


# ------------------------------------------------------------------ text

func _bar_text() -> String:
	var p := active
	var s := "P%d  %s     Food %d    Wood %d    Pop %d/%d" % [
		p + 1, world.races[p].name, world.food[p], world.wood[p], world.pop[p], world.pop_cap[p]]
	var o := 1 - p
	s += "        (P%d %s: %dF %dW %d/%d)" % [o + 1, world.races[o].name, world.food[o], world.wood[o], world.pop[o], world.pop_cap[o]]
	if autoplay:
		s += "    AUTOPLAY"
	return s


func _hud_text() -> String:
	var last := "-"
	if not world.hashes.is_empty():
		last = "%08x @%d" % [world.hashes[-1][1], world.hashes[-1][0]]
	var mode := "LIVE"
	if not playback.is_empty():
		mode = "REPLAY %d/%d  " % [world.tick, playback.ticks]
		mode += ("DESYNC at tick %d" % desync) if desync >= 0 else "in sync"
	var secs := world.tick / World.TICK_HZ
	var lines := [
		"%s   %s   %d:%02d (tick %d)   %d units   hash %s" % [mode, map.id, secs / 60, secs % 60, world.tick, world.units.count(), last],
		"sim tick %.2f ms avg, %.2f ms max   %d fps   speed x%s%s" % [
			clock.tick_usec_avg / 1000.0, clock.tick_usec_max / 1000.0, Engine.get_frames_per_second(),
			clock.speed, "   PAUSED" if clock.paused else ""],
		"click / drag / double-click select   right-click: move, gather, help build, rally   Tab: switch side",
		"Q train worker   H house   C town center   WASD/edges/middle-drag pan   wheel zoom   space pause   [ ] speed",
		"F3 flow   F5 save replay   F9 play replay   F6 autoplay   F7 test armies   M map   R restart   G/shift+G/ctrl+G regen army",
	]
	var cell := _cell_at(get_global_mouse_position())
	if map.resource_at(cell) != "":
		lines.append("%s: %d %s left" % [map.terrain_at(cell), map.amount[cell], map.resource_at(cell)])
	return "\n".join(lines)


func _update_panel() -> void:
	var team := Color(lib.palettes.teams[active])
	var b := world.buildings.index_of(selected_building)
	if b >= 0:
		var t: Dictionary = world.btypes[world.buildings.kind[b]]
		var mine := world.buildings.owner[b] == active
		var info := "HP %d/%d" % [world.buildings.hp[b], t.hp]
		var buttons := []
		if world.buildings.done[b] == 0:
			info += "   being built: %d%%" % (100 * world.buildings.progress[b] / t.build_ticks)
		else:
			var q: Array = world.buildings.queue[b]
			if not q.is_empty():
				var head: Dictionary = world.types[q[0]]
				info += "   training %s %d%%" % [head.name, 100 * world.buildings.train[b] / head.train_ticks]
				if world.buildings.train[b] == 0 and world.pop[active] + head.pop > world.pop_cap[active]:
					info += " (needs a house)"
			if mine and "worker" in t.trains:
				var k := world.type_of(active, "worker")
				var wt: Dictionary = world.types[k]
				var afford: bool = world.food[active] >= wt.food and world.wood[active] >= wt.wood
				buttons.append({"text": "Train %s [Q]  %dF %dW" % [wt.name, wt.food, wt.wood],
					"enabled": afford and q.size() < int(world.econ.queue_max), "action": train_worker})
			for n in q.size():
				var qt: Dictionary = world.types[q[n]]
				var idx := n
				buttons.append({"text": "x %s" % qt.name, "enabled": mine,
					"action": func(): world.issue(active, Commands.CANCEL, {"building": selected_building, "index": idx})})
			if mine:
				info += "   right-click: rally point"
		panel.show_content("%s (P%d)" % [t.name, world.buildings.owner[b] + 1], info, team, buttons)
		return
	var mine: Array = _selected_by_owner()[active]
	if not mine.is_empty():
		var workers := _selected_workers()
		var buttons := []
		if not workers.is_empty():
			for id in ["house", "town_center"]:
				var t: Dictionary = world.btypes[Economy.btype_of(world, id)]
				var key := "H" if id == "house" else "C"
				var afford: bool = world.food[active] >= t.food and world.wood[active] >= t.wood
				var bid: String = id
				buttons.append({"text": "Build %s [%s]  %dW" % [t.name, key, t.wood], "enabled": afford,
					"action": func(): start_placing(bid)})
		var info := "%d workers" % workers.size()
		if mine.size() == 1:
			var i := world.units.index_of(mine[0])
			var t: Dictionary = world.types[world.units.kind[i]]
			info = "%s   hp %d   %s" % [t.name, world.units.hp[i], ["idle", "gathering", "carrying back", "building"][world.units.task[i]]]
			if world.units.carry[i] > 0:
				info += " (%d %s)" % [world.units.carry[i], Economy.KINDS[world.units.carry_kind[i]]]
		var title := "%d selected" % mine.size() if mine.size() > 1 else "Unit #%d" % mine[0]
		if placing != "":
			info += "   placing: left-click to build, shift keeps placing, right-click/Esc cancels"
		panel.show_content(title, info, team, buttons)
		return
	panel.show_content("%s (P%d)" % [world.races[active].name, active + 1],
		"Select units or a building.  Tab switches side.  F6: let the bots play.", team, [])


# ------------------------------------------------------------------ drawing

func _draw_marks() -> void:
	if world == null:
		return
	if show_flow:
		_draw_flow()
	var u := world.units
	for id in selected:
		var i := u.index_of(id)
		var view: Node2D = views.get(id)
		if i < 0 or view == null:
			continue
		marks.draw_set_transform(view.position, 0.0, Vector2(1.0, 0.5))
		marks.draw_arc(Vector2.ZERO, u.radius[i] * Iso.RADIUS_PX, 0.0, TAU, 24, RING, 1.5 / camera.zoom.x)
		marks.draw_set_transform(Vector2.ZERO)
		if u.moving[i] == 1:
			marks.draw_line(view.position, Iso.to_screen(u.wx[i], u.wy[i]), Color(RING, 0.35), 1.0 / camera.zoom.x)
			marks.draw_line(Iso.to_screen(u.wx[i], u.wy[i]), Iso.to_screen(u.tx[i], u.ty[i]), Color(RING, 0.12), 1.0 / camera.zoom.x)
	for f in flags:
		marks.draw_set_transform(f.pos, 0.0, Vector2(1.0, 0.5))
		marks.draw_circle(Vector2.ZERO, 10.0 * f.t, Color(RING, f.t))
		marks.draw_set_transform(Vector2.ZERO)


## Arrows of the flow field the first selected unit is following.
func _draw_flow() -> void:
	if selected.is_empty():
		return
	var i := world.units.index_of(selected.keys()[0])
	if i < 0 or world.units.moving[i] == 0:
		return
	var f = world.fields.get(world.units.fkey[i])
	if f == null:
		return
	var w := 1.0 / camera.zoom.x
	for c in f.next.size():
		var n: int = f.next[c]
		if n < 0:
			continue
		var a := Iso.to_screen((c % map.width) * 1000 + 500, (c / map.width) * 1000 + 500)
		var b := Iso.to_screen((n % map.width) * 1000 + 500, (n / map.width) * 1000 + 500)
		var tip := a.lerp(b, 0.45)
		marks.draw_line(a, tip, Color(FLOW, 0.5), w)
		marks.draw_circle(tip, 1.5 * w, Color(FLOW, 0.7))


func _draw_overlay() -> void:
	if world == null:
		return
	var b := world.buildings.index_of(selected_building)
	if b >= 0:
		var bs := world.buildings
		var s := bs.size[b] * 1000
		var x0 := bs.cx[b] * 1000
		var y0 := bs.cy[b] * 1000
		var pts := PackedVector2Array([Iso.to_screen(x0, y0), Iso.to_screen(x0 + s, y0), Iso.to_screen(x0 + s, y0 + s),
			Iso.to_screen(x0, y0 + s), Iso.to_screen(x0, y0)])
		overlay.draw_polyline(pts, RING, 2.0 / camera.zoom.x)
		if bs.rally_x[b] >= 0:
			var rp := Iso.to_screen(bs.rally_x[b], bs.rally_y[b])
			overlay.draw_line(Iso.to_screen(x0 + s / 2, y0 + s / 2), rp, Color(RING, 0.4), 1.0 / camera.zoom.x)
			overlay.draw_circle(rp, 4.0, RING)
	# What each worker carries, above its head.
	var u := world.units
	for i in u.count():
		if u.carry[i] > 0 and views.has(u.id[i]):
			var p: Vector2 = views[u.id[i]].position + Vector2(7, -24)
			overlay.draw_circle(p, 2.0 + u.carry[i] * 0.25, CARRY[u.carry_kind[i]])
	if placing != "":
		var c := _ghost_cell(get_global_mouse_position())
		var size: int = world.btypes[Economy.btype_of(world, placing)].size
		var ok := map.can_build(c.x, c.y, size)
		var x0 := c.x * 1000
		var y0 := c.y * 1000
		var s := size * 1000
		overlay.draw_colored_polygon(PackedVector2Array([Iso.to_screen(x0, y0), Iso.to_screen(x0 + s, y0),
			Iso.to_screen(x0 + s, y0 + s), Iso.to_screen(x0, y0 + s)]), GOOD if ok else BAD)
	if boxing:
		var r := Rect2(press_world, Vector2.ZERO).expand(get_global_mouse_position())
		overlay.draw_rect(r, Color(RING, 0.12))
		overlay.draw_rect(r, RING, false, 1.0 / camera.zoom.x)
