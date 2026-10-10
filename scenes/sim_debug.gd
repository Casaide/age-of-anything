extends Node2D
## Sim debug view: the headless sim drawn isometrically with UnitViews,
## interpolated between ticks. Selection happens on screen (what you see is
## what you select); orders go through the command queue, so F5 saves a replay
## of exactly what happened and F9 plays it back, checking hashes as it goes.

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const SimClock := preload("res://src/sim_clock.gd")
const Iso := preload("res://src/view/iso.gd")
const MapView := preload("res://src/view/map_view.gd")
const RtsCamera := preload("res://src/view/rts_camera.gd")
const Commands := preload("res://src/sim/commands.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Replay := preload("res://src/sim/replay.gd")

const MAP_IDS := ["flat_test", "choke_test"]
const SEED := 1
const DEFAULT_PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers"]
const START_ARMY := [["worker", 3], ["spear", 5], ["skirmisher", 4], ["archer", 4], ["large", 2]]
const REPLAY_PATH := "user://replays/last.json"
const BODY_LIFT := 10.0      # pixels from a unit's feet up to the middle of its body
const PICK_PX := 16.0        # click radius in screen pixels
const DRAG_START_PX := 6.0   # screen pixels before a left press becomes a box
const RING := Color("#f2e9c9")
const FLOW := Color("#f2c94c")

var lib
var gen
var rules: Dictionary
var map_id: String = MAP_IDS[0]
var map: SimMap
var world: World
var clock: SimClock
var camera: RtsCamera
var tiles: MapView
var marks: Node2D           # under units: selection rings, move lines, flow arrows
var layer: Node2D           # units, y-sorted
var overlay: Node2D         # over units: the selection box
var hud: Label
var views := {}             # unit id -> UnitView (view side only; never feeds the sim)
var selected := {}          # unit id -> true
var flags: Array = []       # [{pos, t}] recent move targets
var playback := {}          # the replay being played, or empty when live
var checked := 0            # world.hashes entries already compared
var desync := -1
var show_flow := false
var prompts: Array = []     # set before adding to the tree, else taken from the command line
var press_screen := Vector2.INF
var press_world := Vector2.ZERO
var boxing := false


func _ready() -> void:
	lib = DataLib.new()
	gen = Generator.new(lib)
	rules = DataLib.load_json("res://data/rules/default.json")

	clock = SimClock.new()
	add_child(clock)
	tiles = MapView.new()
	add_child(tiles)
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
	camera.zoom = Vector2(1.6, 1.6)
	add_child(camera)

	var ui := CanvasLayer.new()
	add_child(ui)
	hud = Label.new()
	hud.position = Vector2(12, 8)
	hud.add_theme_font_size_override("font_size", 14)
	hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hud.add_theme_constant_override("outline_size", 5)
	ui.add_child(hud)

	if prompts.is_empty():
		var args := OS.get_cmdline_user_args()
		prompts = DEFAULT_PROMPTS.duplicate()
		for i in mini(args.size(), 2):
			prompts[i] = args[i]
	start_live(prompts)


# ------------------------------------------------------------------ modes

func start_live(race_prompts: Array) -> void:
	map = SimMap.load_id(map_id)
	var races := []
	for p in race_prompts:
		races.append(gen.generate(p, rules))
	_attach(World.new(SEED, map, races))
	playback = {}
	for p in races.size():
		for entry in START_ARMY:
			world.issue(p, Commands.SPAWN, {"slot": entry[0], "count": entry[1], "x": map.starts[p][0], "y": map.starts[p][1]})
	camera.look_at_point(Iso.to_screen(map.starts[0][0], map.starts[0][1]) + Vector2(0, 80))


func start_replay(rep: Dictionary) -> void:
	map_id = rep.map
	_attach(Replay.build_world(rep, lib), rep.ticks)
	playback = rep


func _attach(w: World, end_tick := -1) -> void:
	for id in views:
		views[id].queue_free()
	views.clear()
	selected.clear()
	flags.clear()
	world = w
	map = w.map
	checked = 0
	desync = -1
	clock.reset(w, end_tick)
	clock.paused = false
	tiles.build(map)
	camera.bounds = Iso.map_rect(map.width, map.height)


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
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
		move_selected_to(get_global_mouse_position())
	elif event is InputEventMouseMotion and press_screen != Vector2.INF:
		boxing = boxing or event.position.distance_to(press_screen) > DRAG_START_PX
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				clock.paused = not clock.paused
			KEY_1, KEY_2:
				select_army(event.keycode - KEY_1, event.shift_pressed)
			KEY_BRACKETRIGHT:
				clock.speed = minf(clock.speed * 2.0, 16.0)
			KEY_BRACKETLEFT:
				clock.speed = maxf(clock.speed / 2.0, 0.25)
			KEY_F3:
				show_flow = not show_flow
			KEY_F5:
				Replay.save(Replay.record(world), REPLAY_PATH)
				print("Saved replay: ", ProjectSettings.globalize_path(REPLAY_PATH))
			KEY_F9:
				if FileAccess.file_exists(REPLAY_PATH):
					start_replay(Replay.load_file(REPLAY_PATH))
			KEY_M:
				map_id = MAP_IDS[(MAP_IDS.find(map_id) + 1) % MAP_IDS.size()]
				start_live(world.races.map(func(r): return r.prompt))
			KEY_R:
				start_live(world.races.map(func(r): return r.prompt))


func _body(view: Node2D) -> Vector2:
	return view.position - Vector2(0, BODY_LIFT)


## Click: the unit whose body is nearest the cursor, within PICK_PX on screen.
func select_at(pos: Vector2, add := false) -> void:
	if not add:
		selected.clear()
	var best := 0
	var best_d := PICK_PX / camera.zoom.x
	for id in views:
		var d := _body(views[id]).distance_to(pos)
		if d < best_d or (d == best_d and id < best):
			best_d = d
			best = id
	if best != 0:
		if add and selected.has(best):
			selected.erase(best)
		else:
			selected[best] = true


## Box: every unit whose body is inside the dragged rectangle (canvas coords; no rotation).
func select_box(a: Vector2, b: Vector2, add := false) -> void:
	if not add:
		selected.clear()
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
		selected.clear()
	for i in world.units.count():
		if world.units.owner[i] == player:
			selected[world.units.id[i]] = true


## One MOVE per owning player, ids ascending. Ignored while a replay plays.
func move_selected_to(pos: Vector2) -> void:
	if not playback.is_empty() or selected.is_empty():
		return
	var m := Iso.to_milli(pos)
	var ids := selected.keys()
	ids.sort()
	for p in world.races.size():
		var mine := []
		for id in ids:
			var i := world.units.index_of(id)
			if i >= 0 and world.units.owner[i] == p:
				mine.append(id)
		if not mine.is_empty():
			world.issue(p, Commands.MOVE, {"ids": mine, "x": m.x, "y": m.y})
	flags.append({"pos": pos, "t": 1.0})


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	_sync_views()
	_check_replay()
	for f in flags:
		f.t -= delta
	flags = flags.filter(func(f): return f.t > 0.0)
	marks.queue_redraw()
	overlay.queue_redraw()
	hud.text = _hud_text()


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
	for id in views.keys():
		if not alive.has(id):
			views[id].queue_free()
			views.erase(id)
			selected.erase(id)


func _make_view(kind: int, owner: int) -> UnitView:
	var t: Dictionary = world.types[kind]
	var view := UnitView.new()
	view.build(t.recipe, lib, Color(lib.palettes.teams[owner]), t.speed / World.SPEED_SCALE)
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


func _hud_text() -> String:
	var last := "-"
	if not world.hashes.is_empty():
		last = "%08x @%d" % [world.hashes[-1][1], world.hashes[-1][0]]
	var mode := "LIVE"
	if not playback.is_empty():
		mode = "REPLAY %d/%d  " % [world.tick, playback.ticks]
		mode += ("DESYNC at tick %d" % desync) if desync >= 0 else "in sync"
	var moving := 0
	var stuck := 0
	for i in world.units.count():
		moving += world.units.moving[i]
		stuck += 1 if world.units.stuck[i] >= World.STUCK_LIMIT else 0
	var lines := [
		"%s   %s   tick %d  turn %d   %d units (%d moving, %d stuck)   hash %s" % [
			mode, map.id, world.tick, world.turn(), world.units.count(), moving, stuck, last],
		"sim tick %.2f ms avg, %.2f ms max   %d fps   speed x%s%s" % [
			clock.tick_usec_avg / 1000.0, clock.tick_usec_max / 1000.0, Engine.get_frames_per_second(),
			clock.speed, "   PAUSED" if clock.paused else ""],
		"%s  vs  %s" % [world.races[0].name, world.races[1].name],
		"click / drag box / double-click type (shift adds)   right-click move   1/2 army",
		"WASD, edges, middle-drag pan   wheel zoom   space pause   [ ] speed",
		"F3 flow field   F5 save replay   F9 play replay   M next map   R restart",
	]
	if selected.size() == 1:
		var i := world.units.index_of(selected.keys()[0])
		var t: Dictionary = world.types[world.units.kind[i]]
		lines.append("#%d %s (player %d)  hp %d  speed %d mt/tick  radius %d  group %d" % [
			world.units.id[i], t.name, t.player + 1, world.units.hp[i], t.speed, t.radius, world.units.group[i]])
	elif selected.size() > 1:
		lines.append("%d selected" % selected.size())
	return "\n".join(lines)


# ------------------------------------------------------------------ drawing

func _draw_marks() -> void:
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
	if i < 0 or world.units.group[i] == 0:
		return
	var cell := (world.units.ty[i] / 1000) * map.width + world.units.tx[i] / 1000
	var f = world.fields.get(cell)
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
	if not boxing:
		return
	var r := Rect2(press_world, Vector2.ZERO).expand(get_global_mouse_position())
	overlay.draw_rect(r, Color(RING, 0.12))
	overlay.draw_rect(r, RING, false, 1.0 / camera.zoom.x)
