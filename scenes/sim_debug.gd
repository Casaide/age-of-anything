extends Node2D
## Sim debug view: the headless sim drawn with UnitViews, interpolated between ticks.
## Click to select (shift adds), right-click to MOVE, 1/2 select a whole army.
## Every order goes through the command queue, so F5 saves a replay of exactly
## what happened and F9 plays it back, checking hashes as it goes.

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const SimClock := preload("res://src/sim_clock.gd")
const Commands := preload("res://src/sim/commands.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Replay := preload("res://src/sim/replay.gd")

const MAP_ID := "flat_test"
const SEED := 1
const DEFAULT_PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers"]
const START_ARMY := [["worker", 3], ["spear", 5], ["skirmisher", 4], ["archer", 4], ["large", 2]]
const TILE_PX := 32.0
const PICK_RADIUS := 600
const REPLAY_PATH := "user://replays/last.json"
const PAN_SPEED := 900.0
const GRASS := Color("#4a5a32")
const GRASS_2 := Color("#46552f")
const ROCK := Color("#2e2a24")
const RING := Color("#f2e9c9")

var lib
var gen
var rules: Dictionary
var map: SimMap
var world: World
var clock: SimClock
var camera: Camera2D
var ground: Node2D
var marks: Node2D
var layer: Node2D
var hud: Label
var views := {}          # unit id -> UnitView (view side only; never feeds the sim)
var selected := {}       # unit id -> true
var flags: Array = []    # [{pos, t}] recent move targets
var playback := {}       # the replay being played, or empty when live
var checked := 0         # world.hashes entries already compared
var desync := -1
var prompts: Array = []  # set before adding to the tree, else taken from the command line


func _ready() -> void:
	lib = DataLib.new()
	gen = Generator.new(lib)
	rules = DataLib.load_json("res://data/rules/default.json")
	map = SimMap.load_id(MAP_ID)

	clock = SimClock.new()
	add_child(clock)
	ground = Node2D.new()
	ground.draw.connect(_draw_ground)
	add_child(ground)
	marks = Node2D.new()
	marks.draw.connect(_draw_marks)
	add_child(marks)
	layer = Node2D.new()
	layer.y_sort_enabled = true
	add_child(layer)
	camera = Camera2D.new()
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

func start_live(prompts: Array) -> void:
	var races := []
	for p in prompts:
		races.append(gen.generate(p, rules))
	_attach(World.new(SEED, map, races))
	playback = {}
	for p in races.size():
		for entry in START_ARMY:
			world.issue(p, Commands.SPAWN, {"slot": entry[0], "count": entry[1], "x": map.starts[p][0], "y": map.starts[p][1]})
	camera.position = _to_px(map.starts[0][0], map.starts[0][1]) + Vector2(160, 120)


func start_replay(rep: Dictionary) -> void:
	_attach(Replay.build_world(rep, lib), rep.ticks)
	playback = rep


func _attach(w: World, end_tick := -1) -> void:
	for id in views:
		views[id].queue_free()
	views.clear()
	selected.clear()
	flags.clear()
	world = w
	checked = 0
	desync = -1
	clock.reset(w, end_tick)
	clock.paused = false
	ground.queue_redraw()


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_select_at(get_global_mouse_position(), event.shift_pressed)
			MOUSE_BUTTON_RIGHT:
				move_selected_to(get_global_mouse_position())
			MOUSE_BUTTON_WHEEL_UP:
				camera.zoom = (camera.zoom * 1.1).clampf(0.3, 4.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				camera.zoom = (camera.zoom / 1.1).clampf(0.3, 4.0)
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
			KEY_F5:
				Replay.save(Replay.record(world), REPLAY_PATH)
				print("Saved replay: ", ProjectSettings.globalize_path(REPLAY_PATH))
			KEY_F9:
				if FileAccess.file_exists(REPLAY_PATH):
					start_replay(Replay.load_file(REPLAY_PATH))
			KEY_R:
				start_live(world.races.map(func(r): return r.prompt))


func _select_at(pos: Vector2, add: bool) -> void:
	var m := _to_milli(pos)
	var id := world.pick(m.x, m.y, PICK_RADIUS)
	if not add:
		selected.clear()
	if id != 0:
		if selected.has(id):
			selected.erase(id)
		else:
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
	var m := _to_milli(pos)
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
	flags.append({"pos": _to_px(m.x, m.y), "t": 1.0})


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	var pan := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	pan += Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	camera.position += pan * PAN_SPEED * delta / camera.zoom.x

	_sync_views()
	_check_replay()
	for f in flags:
		f.t -= delta
	flags = flags.filter(func(f): return f.t > 0.0)
	marks.queue_redraw()
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
		view.position = _to_px(u.px[i] + dx * a, u.py[i] + dy * a)
		view.walking = dx != 0 or dy != 0
		if absi(dx) > 4:
			view.face(dx)
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
	if playback.is_empty():
		return
	var want := {}
	while checked < world.hashes.size():
		var got: Array = world.hashes[checked]
		checked += 1
		if want.is_empty():
			for c in playback.checkpoints:
				want[c[0]] = c[1]
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
	var lines := [
		"%s   tick %d  turn %d   %d units   hash %s" % [mode, world.tick, world.turn(), world.units.count(), last],
		"sim tick %.2f ms avg, %.2f ms max   %d fps   speed x%s%s" % [
			clock.tick_usec_avg / 1000.0, clock.tick_usec_max / 1000.0, Engine.get_frames_per_second(),
			clock.speed, "   PAUSED" if clock.paused else ""],
		"%s  vs  %s" % [world.races[0].name, world.races[1].name],
		"click select (shift adds)  right-click move  1/2 army  WASD pan  wheel zoom",
		"space pause  [ ] speed  F5 save replay  F9 play replay  R restart",
	]
	if selected.size() == 1:
		var i := world.units.index_of(selected.keys()[0])
		var t: Dictionary = world.types[world.units.kind[i]]
		lines.append("#%d %s (player %d)  hp %d  speed %d mt/tick  radius %d" % [
			world.units.id[i], t.name, t.player + 1, world.units.hp[i], t.speed, t.radius])
	elif selected.size() > 1:
		lines.append("%d selected" % selected.size())
	return "\n".join(lines)


# ------------------------------------------------------------------ drawing

func _draw_ground() -> void:
	for ty in map.height:
		for tx in map.width:
			var c := ROCK
			if map.walk[ty * map.width + tx] == 1:
				c = GRASS if (tx + ty) % 2 == 0 else GRASS_2
			ground.draw_rect(Rect2(tx * TILE_PX, ty * TILE_PX, TILE_PX, TILE_PX), c)


func _draw_marks() -> void:
	var u := world.units
	for id in selected:
		var i := u.index_of(id)
		if i < 0:
			continue
		var view: Node2D = views.get(id)
		if view == null:
			continue
		var r := u.radius[i] * TILE_PX / 1000.0
		marks.draw_arc(view.position, r, 0.0, TAU, 24, RING, 1.5)
		if u.moving[i] == 1:
			marks.draw_line(view.position, _to_px(u.tx[i], u.ty[i]), Color(RING, 0.15), 1.0)
	for f in flags:
		marks.draw_circle(f.pos, 6.0 * f.t, Color(RING, f.t))


func _to_px(x: float, y: float) -> Vector2:
	return Vector2(x, y) * (TILE_PX / 1000.0)


func _to_milli(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x * 1000.0 / TILE_PX), int(pos.y * 1000.0 / TILE_PX))
