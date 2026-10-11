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
const CombatFx := preload("res://src/view/combat_fx.gd")
const Tech := preload("res://src/sim/tech.gd")
const Market := preload("res://src/sim/market.gd")
const RtsCamera := preload("res://src/view/rts_camera.gd")
const CommandPanel := preload("res://src/view/command_panel.gd")
const TopBar := preload("res://src/view/top_bar.gd")
const UnitCard := preload("res://src/view/unit_card.gd")
const FogView := preload("res://src/view/fog_view.gd")
const Minimap := preload("res://src/view/minimap.gd")
const UiScale := preload("res://src/view/ui_scale.gd")
const Audio := preload("res://src/view/audio.gd")
const Fog := preload("res://src/sim/fog.gd")
const Cursors := preload("res://src/view/art/cursors.gd")
const Icons := preload("res://src/view/art/icons.gd")
const Commands := preload("res://src/sim/commands.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Economy := preload("res://src/sim/economy.gd")
const Combat := preload("res://src/sim/combat.gd")
const Replay := preload("res://src/sim/replay.gd")
const Bot := preload("res://src/ai/bot.gd")

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
const PICK_PX := 16.0        # click slack in screen pixels
const FIGURE_H := 26.0       # canvas units: a unit's figure from feet to head (large units 1.6x)
const FIGURE_W := 14.0
const DRAG_START_PX := 6.0   # screen pixels before a left press becomes a box
const RING := Color("#f2e9c9")
## The stance buttons, in Combat.POSTURES order: [label, tooltip].
const STANCES := [
	["Aggressive", "Go for any foe in sight and keep chasing it. The usual stance."],
	["Defensive", "Fight foes that come near, chase them only a short way, then walk back to the spot."],
	["Stand ground", "Never move to fight: hit only what is already in reach (archers shoot, spears stab what is next to them)."],
	["No attack", "Never fight on their own, not even back. For scouts, or to walk past a fight."],
]
const FLOW := Color("#f2c94c")
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
var attack_move := false    # the order being given is an attack-move
var queueing := false       # the order being given is shift-queued
var arming_attack := false  # R was pressed: the next left click attack-moves there
var groups := {}            # control group number -> [unit ids]
var last_group := -1
var last_group_at := 0
var idle_cursor := -1
var alert_at := Vector2.INF  # where we were last attacked (canvas), for Space
var alert_next := 0.0        # seconds of match time before the next alarm may sound
var alert_label: Label
var hint: Label             # the opening hints (against the AI), one at a time
var hint_step := 0
var start_units := 0
var fx: CombatFx            # projectiles, sparks, deaths (from the sim's events)
var marks: Node2D           # under units: selection rings, move lines, flow arrows
var layer: Node2D           # units, buildings and resource props, y-sorted
var overlay: Node2D         # over everything: selection box, placement ghost, carried loads
var hud: Label
var bar: Label              # the debug line of both sides' stock (not against the AI)
var top_bar: TopBar
var build_menu: Dictionary = DataLib.load_json("res://data/buildings.json").menu   # a worker's two build pages: civilian, military
var build_page := ""        # the page a worker's panel shows: "" (pick a page), "civilian" or "military"
var _build_page_for := ""   # the selection it was opened for; a new selection starts at the top
var show_debug := true      # the debug lines (F1); off by default against the AI
var panel: CommandPanel
var cursors: Cursors
var views := {}             # unit id -> UnitView (view side only; never feeds the sim)
var bviews := {}            # building id -> BuildingArt
var rviews := {}            # resource cell -> its prop (reed clump, bug bush)
var selected := {}          # unit id -> true
var selected_building := 0  # building id, or 0
var selected_resource := -1 # a resource cell clicked to see what's left, or -1
var active := 0             # the side you're commanding
var placing := ""           # building type being placed, or ""
var wall_from := Vector2i(-1, -1)   # where a wall drag started (a cell), while placing walls
var flags: Array = []       # [{pos, t}] recent move targets
var rally_flag: Sprite2D    # the selected building's rally point (a baked prop), or null
var playback := {}          # the replay being played, or empty when live
var checked := 0            # world.hashes entries already compared
var desync := -1
var show_flow := false
var autoplay := false
var army := false           # also spawn a test army per side (F7 toggles and restarts)
var ai_level := "normal"    # easy, normal or hard (data/ai.json levels; picked in the lobby)
var vs_ai := false          # side 2 is played by the AI (set by the match setup screen)
var banner: Label           # victory / defeat
var pause_menu: Control     # Esc against the AI: resume, surrender, back to the menu
var fog_view: FogView
var flat: Node2D             # ground-level art (farms, crops), drawn under the y-sorted layer
var minimap: Minimap
var hud_root: Control     # every HUD control lives in here, scaled to the screen's density
var audio: Node           # the game's one audio node (src/view/audio.gd)
var battle_until := 0.0   # seconds of match time until the music's battle layer fades out
var age_ups: Array = []      # [player, age, seconds] this match (for the playtest log)
var reveal := false         # V: see everything (debug)
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
	flat = Node2D.new()   # flat on the ground, under every unit: finished farms and their crops
	add_child(flat)
	marks = Node2D.new()
	marks.draw.connect(_draw_marks)
	add_child(marks)
	layer = Node2D.new()
	layer.y_sort_enabled = true
	add_child(layer)
	fx = CombatFx.new()
	add_child(fx)
	fog_view = FogView.new()
	add_child(fog_view)
	audio = Audio.of(get_tree())
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

	var layer_ui := CanvasLayer.new()
	layer_ui.layer = 2
	add_child(layer_ui)
	# The HUD draws in UI pixels inside one scaled root (src/view/ui_scale.gd), so it reads on a
	# Retina screen while the map keeps its own zoom; the lobby may have scaled the window.
	get_window().content_scale_factor = 1.0
	UiScale.fit_window(get_window())
	var ui := Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root = ui
	layer_ui.add_child(ui)
	get_window().size_changed.connect(_fit_hud)
	_fit_hud()
	hud = _label(12, Vector2(12, 44))
	ui.add_child(hud)
	bar = _label(17, Vector2(12, 10))
	ui.add_child(bar)
	top_bar = TopBar.new()
	ui.add_child(top_bar)
	panel = CommandPanel.new()
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 12
	panel.offset_bottom = -12
	ui.add_child(panel)
	banner = _label(64, Vector2.ZERO)
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.visible = false
	ui.add_child(banner)
	minimap = Minimap.new()
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.anchor_top = 1.0
	minimap.anchor_bottom = 1.0
	minimap.offset_left = -Minimap.SIZE - 24   # its frame (12 right, 8 below) then the panel's 12 px margin
	minimap.offset_top = -Minimap.SIZE * 0.5 - 20
	ui.add_child(minimap)
	cursors = Cursors.new(DisplayServer.screen_get_scale())

	if prompts.is_empty():
		var args := OS.get_cmdline_user_args()
		prompts = DEFAULT_PROMPTS.duplicate()
		for i in mini(args.size(), 2):
			prompts[i] = args[i]
	start_live(prompts)


## The HUD's scale for this window, and its root sized to the window in UI pixels.
func _fit_hud() -> void:
	var f := UiScale.factor(get_window(), UiScale.HUD_NEEDS)
	hud_root.scale = Vector2(f, f)
	hud_root.size = get_viewport_rect().size / f
	CommandPanel.TipButton.ui_scale = f   # tooltip cards are popups outside the HUD: they scale their own type
	var t := Theme.new()   # plain tooltips (queue slots, the idle button) take the HUD's theme
	t.set_font_size("font_size", "TooltipLabel", roundi(14 * f))
	hud_root.theme = t


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
	audio.music_age(world.ages[active])
	audio.ambience(true)
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


## Playtest log: one JSON line per finished match in user://matches.jsonl (races, who won,
## how long it ran, when each side reached each age), for the milestone 10 metrics.
func _log_match(team: int) -> void:
	var f := FileAccess.open("user://matches.jsonl", FileAccess.READ_WRITE if FileAccess.file_exists("user://matches.jsonl") else FileAccess.WRITE)
	f.seek_end()
	f.store_line(JSON.stringify({"time": Time.get_datetime_string_from_system(), "map": map.id, "vs_ai": vs_ai,
		"races": world.races.map(func(r): return r.name), "prompts": prompts, "winner_team": team, "you": active,
		"seconds": world.tick / 20, "ages": world.ages, "age_ups": age_ups, "lost": world.lost}))
	print("Match logged: ", ProjectSettings.globalize_path("user://matches.jsonl"))


func _on_screen(p: Vector2) -> bool:
	var half := get_viewport_rect().size / camera.zoom * 0.5
	return Rect2(camera.get_screen_center_position() - half, half * 2.0).has_point(p)


func _first_of_team(team: int) -> int:
	for p in world.teams.size():
		if world.teams[p] == team:
			return p
	return 0


func _attach(w: World, end_tick := -1) -> void:
	banner.visible = false
	age_ups = []
	minimap.setup(w, lib.palettes.teams.map(func(c): return Color(c)), DataLib.load_json("res://data/terrain.json").terrain, camera)
	for d in [views, bviews, rviews]:
		for k in d:
			d[k].queue_free()
		d.clear()
	for c in doodads:
		for n in doodads[c]:
			n.queue_free()
	doodads.clear()
	if rally_flag != null:
		rally_flag.queue_free()
		rally_flag = null
	fx.clear()
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
		_add_resource_view(c, picks[c])
	map.changed.clear()
	_refresh_paths()
	ground.finish_paths()   # doodads keep off the paths, so they must be there first
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
	if not playback.is_empty():
		clock.bots = []
	elif on:
		clock.bots = [Bot.new(0), Bot.new(1)]   # watch two AIs play
	else:
		clock.bots = [Bot.new(1, {}, ai_level)] if vs_ai else []


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if baking or world == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if arming_attack:   # R then click: attack-move there
			if event.pressed:
				attack_move = true
				smart_order(get_global_mouse_position())
				attack_move = false
				arming_attack = false
			return
		if placing == "wall":   # walls are dragged: press at one end, release at the other
			if event.pressed:
				wall_from = _ghost_cell(get_global_mouse_position())
			elif wall_from.x >= 0:
				place_wall(wall_from, _ghost_cell(get_global_mouse_position()), event.shift_pressed)
				wall_from = Vector2i(-1, -1)
			return
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
			attack_move = event.ctrl_pressed   # Ctrl + right-click: attack-move (A is camera pan)
			queueing = event.shift_pressed     # Shift: add to each unit's order queue
			smart_order(get_global_mouse_position())
			attack_move = false
			queueing = false
	elif event is InputEventMouseMotion and press_screen != Vector2.INF:
		boxing = boxing or event.position.distance_to(press_screen) > DRAG_START_PX
	elif event is InputEventKey and event.pressed and not event.echo:
		if not _play_key(event) and (not vs_ai or show_debug):
			_debug_key(event)


## The keys a player uses. True when the key was one of them.
func _play_key(event: InputEventKey) -> bool:
	var k := event.keycode
	if k >= KEY_1 and k <= KEY_9:
		_control_group(k - KEY_0, event.ctrl_pressed or event.meta_pressed)
		return true
	match k:
		KEY_ESCAPE:
			if arming_attack or placing != "":
				arming_attack = false
				placing = ""
			elif build_page != "" and not _selected_workers().is_empty():
				build_page = ""
			elif vs_ai:
				_toggle_pause_menu()
			return true
		KEY_SPACE:
			if vs_ai:
				_jump_to_alert()
			else:
				clock.paused = not clock.paused
			return true
		KEY_Q:
			train_worker()
			return true
		KEY_U:
			if selected_building != 0:
				world.issue(active, Commands.AGE_UP, {"building": selected_building})
			return true
		KEY_PERIOD:
			_next_idle_worker()
			return true
		KEY_F1:
			show_debug = not show_debug
			return true
	if _selected_workers().size() < _selected_by_owner()[active].size():   # any soldiers in the selection
		if k == KEY_R:   # soldiers: attack-move (then click where)
			arming_attack = true
			return true
		if k == KEY_X:
			stop_selected()
			return true
	if not _selected_workers().is_empty():
		var key := OS.get_keycode_string(k)
		for bt in world.btypes:   # a building's hotkey (data/buildings.json), with workers selected
			if bt.hotkey == key and world.ages[active] >= int(bt.age):
				start_placing(bt.id)
				return true
	return false


## Testing keys: off in a match against the AI unless F1 is on.
func _debug_key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_TAB:
			if not vs_ai:
				active = 1 - active
				_clear_selection()
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
		KEY_V:
			reveal = not reveal
		KEY_F10:
			if world.winner < 0:
				world.issue(active, Commands.SURRENDER, {})
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


## Three one-time hints for the first minutes against the AI; each clears itself when done.
const HINTS := [
	"Click your Town Center, then press Q (or its button) to train a worker.",
	"Select a worker and right-click a bush, reeds or stone to gather.",
	"Build a House (select a worker, press H) before your population fills up: every unit needs room.",
]

func _update_hint() -> void:
	if not vs_ai or hint_step >= HINTS.size():
		if hint != null:
			hint.visible = false
		return
	if hint == null:
		hint = _label(17, Vector2(24, 0))
		hint.add_theme_color_override("font_color", Color("#f2e6c8"))
		var st := StyleBoxFlat.new()
		st.bg_color = Color("#2e2820", 0.92)
		st.border_color = Color("#f2c94c")
		st.set_border_width_all(1)
		st.set_corner_radius_all(4)
		st.set_content_margin_all(10)
		hint.add_theme_stylebox_override("normal", st)
		hint.set_anchors_preset(Control.PRESET_CENTER_TOP)   # under the top bar: tooltip cards live above the panel
		hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
		hint.position.y = 44
		banner.get_parent().add_child(hint)
		var u := world.units
		for i in u.count():
			if u.owner[i] == active:
				start_units += 1
	var done := false
	match hint_step:
		0:
			var n := 0
			for i in world.units.count():
				if world.units.owner[i] == active:
					n += 1
			done = n > start_units
		1:
			for i in world.units.count():
				if world.units.owner[i] == active and world.units.task[i] == Economy.GATHER:
					done = true
		2:
			for b in world.buildings.count():
				if world.buildings.owner[b] == active and world.btypes[world.buildings.kind[b]].house and world.btypes[world.buildings.kind[b]].id != "town_center":
					done = true
			done = done or world.tick > 20 * 240
	if done:
		hint_step += 1
		audio.play("ui_tip")
	hint.visible = hint_step < HINTS.size()
	if hint.visible:
		hint.text = "Tip %d of 3:  %s" % [hint_step + 1, HINTS[hint_step]]


## Under attack: the first enemy blow on one of ours out of view sounds a horn, pings the
## minimap and shows "Under attack!" at the top; Space takes the camera there. At most
## one alarm every 15 seconds.
func _maybe_alert(e: Dictionary, to: Vector2) -> void:
	var ti := world.units.index_of(e.to)
	var tb := world.buildings.index_of(e.to)
	var owner: int = world.units.owner[ti] if ti >= 0 else (world.buildings.owner[tb] if tb >= 0 else -1)
	var by := world.units.index_of(e.by)
	if owner != active or (by >= 0 and world.units.owner[by] == world.gaia):
		return
	alert_at = to
	var now := world.tick / float(World.TICK_HZ)
	if now < alert_next or _on_screen(to):   # only for fights you can't see (an off-screen house counts)
		return
	alert_next = now + 15.0
	audio.play("alarm")
	battle_until = now + 8.0
	var m := Iso.to_milli(to)
	minimap.ping(Vector2(m.x / 1000.0, m.y / 1000.0))
	if alert_label == null:
		alert_label = _label(26, Vector2.ZERO)
		alert_label.add_theme_color_override("font_color", Color("#ff8a70"))
		alert_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		alert_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		alert_label.position.y = 100   # below the tip strip
		banner.get_parent().add_child(alert_label)
	alert_label.text = "Under attack!  (Space to look)"
	alert_label.visible = true
	alert_label.set_meta("until", Time.get_ticks_msec() + 3000)


func _jump_to_alert() -> void:
	if alert_at != Vector2.INF:
		camera.look_at_point(alert_at)


## Ctrl+number keeps the selected units as a group; the number brings them back, and
## pressed twice quickly, the camera goes to them.
func _control_group(n: int, store: bool) -> void:
	if store:
		groups[n] = _selected_by_owner()[active].duplicate()
		return
	var ids: Array = groups.get(n, []).filter(func(id): return world.units.index_of(id) >= 0)
	if ids.is_empty():
		return
	_clear_selection()
	for id in ids:
		selected[id] = true
	var now := Time.get_ticks_msec()
	if last_group == n and now - last_group_at < 400:
		if views.has(ids[0]):
			camera.look_at_point(views[ids[0]].position)
	last_group = n
	last_group_at = now


## The stance shared by every soldier among `ids`, or -1 if they differ.
func _soldier_stance(ids: Array) -> int:
	var out := -2
	for id in ids:
		var i := world.units.index_of(id)
		if world.types[world.units.kind[i]].worker:
			continue
		if out == -2:
			out = world.units.posture[i]
		elif out != world.units.posture[i]:
			return -1
	return out


## Set the selected soldiers' stance (a Combat.POSTURES name); workers are left out.
func set_stance(stance: String) -> void:
	var workers := _selected_workers()
	var ids: Array = _selected_by_owner()[active].filter(func(id): return not id in workers)
	if not ids.is_empty():
		world.issue(active, Commands.STANCE, {"ids": ids, "stance": stance})
		_say("ack")


func stop_selected() -> void:
	var mine: Array = _selected_by_owner()[active]
	if not mine.is_empty():
		world.issue(active, Commands.STOP, {"ids": mine})
		_say("ack")


## "." cycles through idle workers: selects the next one and centres on it.
func _next_idle_worker() -> void:
	var idle := _idle_workers()
	if idle.is_empty():
		return
	idle_cursor = (idle_cursor + 1) % idle.size()
	var id: int = idle[idle_cursor]
	_clear_selection()
	selected[id] = true
	if views.has(id):
		camera.look_at_point(views[id].position)


func _idle_workers() -> Array:
	var out := []
	var u := world.units
	for i in u.count():
		if u.owner[i] == active and world.types[u.kind[i]].worker and u.task[i] == Economy.NONE and u.moving[i] == 0 and u.orders[i].is_empty():
			out.append(u.id[i])
	return out


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
	selected_resource = -1
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
	var best := unit_at(pos)
	if best != 0:
		selected_building = 0
		if add and selected.has(best):
			selected.erase(best)
		else:
			selected[best] = true
			_say("select", world.units.owner[world.units.index_of(best)])
		_take_side(world.units.owner[world.units.index_of(best)])
		return
	for probe in [pos, pos + Vector2(0, 14)]:   # clicking a wall or roof hits the footprint below
		var bid: int = map.occupied[_cell_at(probe)]
		if bid != 0:
			selected.clear()
			selected_building = bid
			audio.play("ui_click", -4.0)
			_take_side(world.buildings.owner[world.buildings.index_of(bid)])
			return
	var cell := _cell_at(pos)
	if map.resource_at(cell) != "" and map.pool[cell] < 0:   # a bush, reeds or stone: show what's left
		selected_resource = cell


## Box: every unit whose body is inside the dragged rectangle (canvas coords; no rotation).
func select_box(a: Vector2, b: Vector2, add := false) -> void:
	if not add:
		_clear_selection()
	var r := Rect2(a, Vector2.ZERO).expand(b)
	for id in views:
		if vs_ai and world.units.owner[world.units.index_of(id)] != active:
			continue   # against the AI a box takes only your own units
		if views[id].visible and r.has_point(_body(views[id])):   # not what the fog hides
			selected[id] = true


## Double-click: every unit of the clicked unit's type and owner that's on screen.
func select_same_type_on_screen(pos: Vector2, add := false) -> void:
	select_at(pos, false)
	if selected.size() != 1:
		return
	var i := world.units.index_of(selected.keys()[0])
	var kind := world.units.kind[i]
	var owner := world.units.owner[i]
	if not add:
		selected.clear()
	var screen := Rect2(camera.get_screen_center_position() - get_viewport_rect().size * 0.5 / camera.zoom,
		get_viewport_rect().size / camera.zoom)
	for j in world.units.count():
		var id := world.units.id[j]
		# The same kind with the same owner, that you can see (unowned sheep under the fog stayed
		# selectable: Dominic).
		if world.units.kind[j] == kind and world.units.owner[j] == owner and views.has(id) and views[id].visible \
				and screen.has_point(views[id].position):
			selected[id] = true


func select_army(player: int, add := false) -> void:
	if vs_ai and player != active:
		return
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
		if i >= 0 and (not vs_ai or world.units.owner[i] == active):   # the AI's units can be inspected, not ordered
			out[world.units.owner[i]].append(id)
	return out


## Selecting something makes its side the one you command (and see), except against the AI:
## there you stay yourself and can only look at the other side's units and buildings.
func _take_side(owner: int) -> void:
	if not vs_ai:
		active = owner


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
			if map.resource_at(cell) != "":   # the sim puts it in the middle of the resource's tile
				pos = Iso.to_screen((cell % map.width) * SimMap.TILE + SimMap.TILE / 2, (cell / map.width) * SimMap.TILE + SimMap.TILE / 2)
			flags.append({"pos": pos, "t": 1.0})
			audio.play("ui_click", -4.0)
		return
	var groups := _selected_by_owner()
	var bid: int = map.occupied[cell]
	var foe := unit_at(pos)
	var q := 1 if queueing else 0
	for p in groups.size():
		var ids: Array = groups[p]
		if ids.is_empty():
			continue
		if attack_move:
			world.issue(p, Commands.ATTACK_MOVE, {"ids": ids, "x": m.x, "y": m.y, "queue": q})
		elif foe != 0 and world.is_enemy(world.units.owner[world.units.index_of(foe)], p):
			world.issue(p, Commands.ATTACK, {"ids": ids, "target": foe, "queue": q})   # an enemy, or an animal to hunt
		elif foe != 0 and world.units.owner[world.units.index_of(foe)] == p and world.types[world.units.kind[world.units.index_of(foe)]].has("animal") \
				and not _selected_workers().is_empty():
			world.issue(p, Commands.ATTACK, {"ids": ids, "target": foe, "queue": q})   # slaughter one of our sheep for its food
		elif bid != 0 and world.is_enemy(world.buildings.owner[world.buildings.index_of(bid)], p) and bviews.has(bid) and bviews[bid].visible:
			world.issue(p, Commands.ATTACK, {"ids": ids, "target": bid, "queue": q})
		elif map.resource_at(cell) != "":
			world.issue(p, Commands.GATHER, {"ids": ids, "cell": cell, "queue": q})
		elif bid != 0 and _is_foundation_of(bid, p):
			world.issue(p, Commands.HELP_BUILD, {"ids": ids, "target": bid, "queue": q})
		elif bid != 0 and _drop_off_kind(bid, p, ids) != "":
			world.issue(p, Commands.DROP_OFF, {"ids": ids, "building": bid, "queue": q})   # take what they carry in
		elif bid != 0 and map.pool[cell] >= 0 and world.buildings.owner[world.buildings.index_of(bid)] == p:
			world.issue(p, Commands.RESEED, {"ids": ids, "building": bid})   # a fallow farm of ours
		else:
			world.issue(p, Commands.MOVE, {"ids": ids, "x": m.x, "y": m.y, "queue": q})
	flags.append({"pos": pos, "t": 1.0})
	if not groups[active].is_empty():
		_say("ack")   # the order's been heard


## The unit whose body is nearest the point (within the click radius), or 0.
## A click anywhere on a unit's figure counts (feet to head, a little slack for small units),
## not just near its middle; where figures overlap, the nearest body wins.
func unit_at(pos: Vector2) -> int:
	var best := 0
	var best_d := INF
	var slack := PICK_PX * 0.5 / camera.zoom.x
	for id in views:
		var v: Node2D = views[id]
		if not v.visible:
			continue   # hidden in the fog
		var i := world.units.index_of(id)
		if i < 0:
			continue
		var t: Dictionary = world.types[world.units.kind[i]]
		var tall: float = FIGURE_H * (1.6 if int(t.pop) > 1 else 1.0) + (9.0 if t.mclass == SimMap.FLYING else 0.0)
		var half_w: float = FIGURE_W * (1.6 if int(t.pop) > 1 else 1.0) * 0.5
		var r := Rect2(v.position.x - half_w - slack, v.position.y - tall - slack, (half_w + slack) * 2.0, tall + slack * 2.0 + 3.0)
		if not r.has_point(pos):
			continue
		var d := _body(v).distance_to(pos)
		if d < best_d or (d == best_d and id < best):
			best_d = d
			best = id
	return best


## Play the sim's hits and deaths as effects: attackers lunge at their target,
## ranged ones loose a shot, the struck spark; the dead topple (their view leaves
## the live set, so the usual sync won't just delete it); fallen buildings raise dust.
func _play_events() -> void:
	for e in clock.take_events():
		if e.type == "hit":
			var a: Node2D = views.get(e.by)
			var to := _event_target_pos(e.to)
			if to != Vector2.INF:
				_maybe_alert(e, to)
			var tower: BuildingArt = bviews.get(e.by)
			if tower != null and to != Vector2.INF:
				_tower_shot(e, tower, to)   # a watchtower looses: shooters aren't always units
				continue
			if a == null or to == Vector2.INF:
				continue
			a.face_vec(to - a.position)
			var lands := 0.0
			if e.ranged:
				var i := world.units.index_of(e.by)
				var kind := "arrow"
				if i >= 0:
					kind = CombatFx.shot_kind(world.types[world.units.kind[i]].eval.tags)
				lands = fx.shoot(_body(a) - Vector2(0, 2), to, kind)
			else:
				a.flourish()
				fx.spark(to, e.damage >= 8)
			var target: Node2D = views.get(e.to)
			if target != null:
				fx.flash(target, lands)
			if _on_screen(to) and a.visible:
				var i := world.units.index_of(e.by)
				var tags: Array = world.types[world.units.kind[i]].eval.tags if i >= 0 else []
				if e.ranged:
					audio.play("shoot_" + CombatFx.shot_kind(tags), -4.0)
					audio.play_in("arrow_land", lands, -8.0)
				else:
					audio.play(_blow_sound(tags))
				var side_a := world.units.owner[i] if i >= 0 else -1
				if side_a == active or _owner_of(e.to) == active:
					battle_until = world.tick / float(World.TICK_HZ) + 8.0
		elif e.type == "age":
			age_ups.append([e.player, e.age, world.tick / 20])
			if e.player == active:
				audio.play("age")
				audio.music_age(e.age)
		elif e.type == "research":
			if e.player == active:
				audio.play("research", -4.0)
		elif e.type == "won":
			var mine: bool = world.teams[active] == e.team
			audio.play("won" if mine else "lost")
			audio.music("off")
			audio.ambience(false)
			_log_match(e.team)
			banner.text = ("Victory!" if mine else "Defeat") + "\n" + ("%s win" % world.races[_first_of_team(e.team)].name)
			banner.add_theme_color_override("font_color", Color("#f2c94c") if mine else Color("#e07060"))
			banner.visible = true
			if vs_ai:
				_show_pause_menu(true)   # the match is over: back to the lobby from here
		elif e.type == "die" and not e.building:
			var v: Node2D = views.get(e.id)
			if v != null:
				views.erase(e.id)
				selected.erase(e.id)
				if v.visible and _on_screen(v.position):
					audio.play("fall", -3.0)
					_say("die", e.owner, -2.0)
				fx.kill(v)
		elif e.type == "die":
			var bv: Node2D = bviews.get(e.id)
			if bv != null:
				bviews.erase(e.id)
				if selected_building == e.id:
					selected_building = 0
				var t: Dictionary = world.btypes[e.kind]
				fx.collapse(bv, Iso.to_screen(e.x, e.y), int(t.size))
				if bv.visible and _on_screen(bv.position):
					audio.play("building_fall", -2.0)


## Where a shot or blow lands on a unit (its body) or a building (its middle).
## A watchtower's shot: an arrow from near its top, the target flashing when it lands.
func _tower_shot(e: Dictionary, tower: BuildingArt, to: Vector2) -> void:
	var lands := fx.shoot(tower.loose_at(), to, "arrow")
	var target: Node2D = views.get(e.to)
	if target != null:
		fx.flash(target, lands)
	if _on_screen(to) and tower.visible:
		audio.play("shoot_arrow", -4.0)
		audio.play_in("arrow_land", lands, -8.0)
		if _owner_of(e.by) == active or _owner_of(e.to) == active:
			battle_until = world.tick / float(World.TICK_HZ) + 8.0


func _event_target_pos(id: int) -> Vector2:
	var v: Node2D = views.get(id)
	if v != null:
		return _body(v)
	var b := world.buildings.index_of(id)
	if b >= 0:
		var bs := world.buildings
		return Iso.to_screen((bs.cx[b] + bs.size[b] * 0.5) * 1000, (bs.cy[b] + bs.size[b] * 0.5) * 1000) - Vector2(0, 20)
	return Vector2.INF


## What the first of these units carrying something building `bid` (p's, finished) takes in
## carries ("food", "wood", ...), or "" if none does.
func _drop_off_kind(bid: int, p: int, ids: Array) -> String:
	var b := world.buildings.index_of(bid)
	if b < 0 or world.buildings.owner[b] != p or world.buildings.done[b] == 0:
		return ""
	var t: Dictionary = world.btypes[world.buildings.kind[b]]
	for id in ids:
		var i := world.units.index_of(id)
		if i >= 0 and Economy.can_drop(world, i, t):
			return world.resources[world.units.carry_kind[i] - 1]
	return ""


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


## Esc against the AI: the game pauses under a small menu.
func _toggle_pause_menu() -> void:
	_show_pause_menu(pause_menu == null or not pause_menu.visible)


func _show_pause_menu(on: bool) -> void:
	if pause_menu == null:
		pause_menu = _make_pause_menu()
		banner.get_parent().add_child(pause_menu)
	var over: bool = world.winner >= 0
	pause_menu.visible = on
	pause_menu.get_node("box/resume").visible = not over
	pause_menu.get_node("box/surrender").visible = not over
	var result := ""
	if over:
		result = "Victory" if world.teams[active] == world.winner else "Defeat"
		banner.visible = false   # the result is the menu's title (it collided with the menu)
	var title := ("%s: %s win" % [result, world.races[_first_of_team(world.winner)].name]) if over else "Paused"
	if over and result == "Victory" and vs_ai and ai_level != "hard":
		title += "\nBeat %s? Try %s next." % [ai_level.capitalize(), "Normal" if ai_level == "easy" else "Hard"]   # so testers know the step up exists
	pause_menu.get_node("box/title").text = title
	clock.paused = on and not over


## Surrender asks once more: the first click turns the button into "Click again to give up".
func _confirm_surrender() -> void:
	var b: Button = pause_menu.get_node("box/surrender")
	if b.text == "Surrender":
		b.text = "Click again to give up"
		return
	b.text = "Surrender"
	world.issue(active, Commands.SURRENDER, {})
	_show_pause_menu(false)


func _make_pause_menu() -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.name = "box"
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(320, 0)
	box.set_anchors_preset(Control.PRESET_CENTER)   # centred, below the victory banner, at any HUD size
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.offset_top = 50
	shade.add_child(box)
	var title := Label.new()
	title.name = "title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#f2c94c"))
	box.add_child(title)
	for item in [["resume", "Resume", func(): _show_pause_menu(false)],
			["music", "Music: on", func(): _toggle_music()],
			["surrender", "Surrender", func(): _confirm_surrender()],
			["menu", "Back to the menu", func(): get_tree().paused = false; get_tree().change_scene_to_file("res://scenes/match_setup.tscn")]]:
		var b := Button.new()
		b.name = item[0]
		b.text = item[1]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(320, 52)
		b.add_theme_font_size_override("font_size", 20)
		var st := StyleBoxFlat.new()
		st.bg_color = Color("#2e2820")
		st.border_color = Color("#6a5a40")
		st.set_border_width_all(2)
		st.set_corner_radius_all(4)
		b.add_theme_stylebox_override("normal", st)
		var hv: StyleBoxFlat = st.duplicate()
		hv.border_color = Color("#f2c94c")
		b.add_theme_stylebox_override("hover", hv)
		b.pressed.connect(item[2])
		box.add_child(b)
	return shade


## Train one (five with shift held, as far as the queue has room).
func _train(building: int, slot: String) -> void:
	for k in (5 if Input.is_key_pressed(KEY_SHIFT) else 1):
		world.issue(active, Commands.TRAIN, {"building": building, "slot": slot})


func train_worker() -> void:
	var b := world.buildings.index_of(selected_building)
	if b < 0 or world.buildings.owner[b] != active or not playback.is_empty():
		return
	_train(selected_building, "worker")


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
	# Shift both keeps placing and queues: shift-place two houses and a worker builds both in turn.
	world.issue(active, Commands.BUILD, {"ids": workers, "building": placing, "cx": c.x, "cy": c.y, "queue": 1 if keep else 0})
	if not keep:
		placing = ""


## A line of wall from one cell to another (straight or diagonal, the cells a line through
## them crosses), one foundation per cell; the workers build them in order.
func place_wall(a: Vector2i, b: Vector2i, keep := false) -> void:
	var workers := _selected_workers()
	if workers.is_empty():
		placing = ""
		return
	var cells := wall_cells(a, b)
	for k in cells.size():
		world.issue(active, Commands.BUILD, {"ids": workers, "building": "wall", "cx": cells[k].x, "cy": cells[k].y,
			"queue": 1 if keep or k > 0 else 0})
	if not keep:
		placing = ""


static func wall_cells(a: Vector2i, b: Vector2i) -> Array:
	var out := []
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for k in n + 1:
		var c := Vector2i(a.x + roundi(float(b.x - a.x) * k / maxi(n, 1)), a.y + roundi(float(b.y - a.y) * k / maxi(n, 1)))
		if out.is_empty() or out[-1] != c:
			out.append(c)
	return out


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	if baking or world == null:
		return
	_play_events()
	audio.battle(world.tick / float(World.TICK_HZ) < battle_until)
	_sync_views()
	_sync_buildings()
	_sync_resources()
	_sync_rally()
	_sync_fog()
	_check_replay()
	for f in flags:
		f.t -= delta
	flags = flags.filter(func(f): return f.t > 0.0)
	marks.queue_redraw()
	overlay.queue_redraw()
	_update_top_bar()
	_update_hint()
	if alert_label != null and alert_label.visible and Time.get_ticks_msec() > int(alert_label.get_meta("until", 0)):
		alert_label.visible = false
	hud.visible = show_debug
	bar.visible = show_debug and not vs_ai   # the debug bar shows the other side's stock
	if show_debug:
		bar.text = _bar_text()
		hud.text = _hud_text()
	_update_panel()
	_update_cursor()


## The selected building's rally point, as a baked flag standing in the world (only while
## that building is selected, and only your own).
func _sync_rally() -> void:
	var b := world.buildings.index_of(selected_building)
	var show := b >= 0 and world.buildings.owner[b] == active and world.buildings.rally_x[b] >= 0
	if show and rally_flag == null:
		rally_flag = kit.sprite("rally_flag")
		layer.add_child(rally_flag)
	if rally_flag != null:
		rally_flag.visible = show
		if show:
			rally_flag.position = Iso.to_screen(world.buildings.rally_x[b], world.buildings.rally_y[b])
			rally_flag.self_modulate = Color(lib.palettes.teams[world.buildings.owner[b]])


## A sound from a place on the map: quieter the further it is from the middle of the screen,
## and not at all off screen.
func _sfx_at(kind: String, at: Vector2, volume_db := 0.0) -> void:
	var half := get_viewport_rect().size * 0.5 / camera.zoom
	var off := (at - camera.get_screen_center_position()) / half
	var d := maxf(absf(off.x), absf(off.y))
	if d > 1.15:
		return
	audio.play(kind, volume_db - 8.0 * d)


## A creature's voice for the player's units (its race's creature): "select", "ack", "die".
## Only your own side talks; animals and the enemy keep quiet.
func _say(kind: String, owner := -1, volume_db := 0.0) -> void:
	if owner < 0:
		owner = active
	if owner != active or owner == world.gaia:
		return
	audio.say(lib.creatures[world.races[owner].creature].voice, kind, volume_db)


## Which blow a melee attacker lands, from its weapon's tags.
static func _blow_sound(tags: Array) -> String:
	if "blade" in tags:
		return "hit_blade"
	if "blunt" in tags:
		return "hit_blunt"
	return "hit_pierce"


func _owner_of(id: int) -> int:
	var i := world.units.index_of(id)
	if i >= 0:
		return world.units.owner[i]
	var b := world.buildings.index_of(id)
	return world.buildings.owner[b] if b >= 0 else -1


func _toggle_music() -> void:
	var on: bool = audio.toggle_music()
	var b: Button = pause_menu.get_node_or_null("box/music") if pause_menu != null else null
	if b != null:
		b.text = "Music: on" if on else "Music: off"


func _sync_views() -> void:
	var u := world.units
	var a := clock.alpha
	var alive := {}
	for i in u.count():
		var id := u.id[i]
		alive[id] = true
		var view: UnitView = views.get(id)
		if view != null and (view.get_meta("version", 0) != int(world.types[u.kind[i]].get("version", 0)) or view.get_meta("owner", -1) != u.owner[i]):
			view.queue_free()   # its type moved on (an age-up), or it changed hands (a claimed sheep)
			view = null
		if view == null:
			if not views.has(id) and u.owner[i] == active and world.tick > 40:
				audio.play("trained", -6.0)   # a new unit of yours (not one restyled by an age-up)
			view = _make_view(u.kind[i], u.owner[i])
			view.set_meta("version", int(world.types[u.kind[i]].get("version", 0)))
			view.set_meta("owner", u.owner[i])
			views[id] = view
		var dx := u.x[i] - u.px[i]
		var dy := u.y[i] - u.py[i]
		view.position = Iso.to_screen(u.px[i] + dx * a, u.py[i] + dy * a)
		view.walking = dx != 0 or dy != 0
		if view.struck and view.job != "" and u.owner[i] == active:
			_sfx_at(view.job, view.position, -8.0)   # the blow you see lands: chop, clink, knock, rustle
		view.job = _job(i)
		if world.types[u.kind[i]].worker:
			view.set_tool(lib, _tool_for(i))
		if absi(dx) + absi(dy) > 4:
			view.face_vec(Iso.to_screen(dx, dy))   # the way it walks, on screen (8 facings)
		elif view.job != "":
			var at := _work_point(i)   # face what it's working on
			if absf(at.x - view.position.x) > 1.0:
				view.face_vec(at - view.position)
	for id in views.keys():
		if not alive.has(id):
			views[id].queue_free()
			views.erase(id)
			selected.erase(id)


## The work animation for a unit standing at its job: forage (bug bushes), chop
## (reeds) or build; "" otherwise. Read from the sim, never written back.
func _job(i: int) -> String:
	var u := world.units
	if u.moving[i] != 0:
		return ""
	# Standing at its job counts, not the work counter: it resets to 0 after every load unit,
	# which snapped the animation back to idle for a frame (Dominic: "restarting at weird points").
	if u.task[i] == Economy.GATHER:
		return {"food": "forage", "wood": "chop", "stone": "mine", "gold": "mine"}.get(world.resources[u.carry_kind[i] - 1], "forage")
	if u.task[i] == Economy.BUILD:
		return "build"
	return ""


## What a worker holds: the tool for its job, the load it carries home, else its own tool.
## (No carry icons: you see the reeds on its shoulder or the stone in its arms.)
func _tool_for(i: int) -> String:
	var u := world.units
	var res: String = world.resources[u.carry_kind[i] - 1] if u.carry_kind[i] > 0 else ""
	if u.task[i] == Economy.RETURN and u.carry[i] > 0:
		return {"food": "tool.basket", "wood": "load.reeds", "stone": "load.stone", "gold": "load.gold"}.get(res, "tool.basket")
	if u.task[i] == Economy.GATHER:
		return {"food": "tool.basket", "wood": "tool.axe", "stone": "tool.pick", "gold": "tool.pick"}.get(res, "tool.basket")
	if u.task[i] == Economy.BUILD:
		return "tool.hammer"
	return world.types[u.kind[i]].recipe.parts.get("hand_r", "tool.basket")


## Where a working unit's job is, on the canvas: its resource cell or building's centre.
func _work_point(i: int) -> Vector2:
	var u := world.units
	if u.task[i] == Economy.GATHER:
		var c: int = u.target[i]
		return Iso.to_screen((c % map.width) * 1000 + 500, (c / map.width) * 1000 + 500)
	var b := world.buildings.index_of(u.target[i])
	var bs := world.buildings
	return Iso.to_screen((bs.cx[b] * 2 + bs.size[b]) * 500, (bs.cy[b] * 2 + bs.size[b]) * 500)


## Fog of war for the side you command: the overlay, enemy units only where you see now,
## enemy buildings once you've explored where they stand.
func _sync_fog() -> void:
	fog_view.visible = not reveal
	fog_view.refresh(world, active)
	minimap.player = active
	var u := world.units
	for i in u.count():
		var v: Node2D = views.get(u.id[i])
		if v != null:
			v.visible = reveal or not world.is_enemy(active, u.owner[i]) or Fog.visible(world, active, u.x[i], u.y[i])
	var bs := world.buildings
	for b in bs.count():
		var bv: Node2D = bviews.get(bs.id[b])
		if bv != null:
			bv.visible = reveal or not world.is_enemy(active, bs.owner[b]) or Fog.explored(world, active, bs.cx[b], bs.cy[b])


func _sync_buildings() -> void:
	var bs := world.buildings
	# Buildings that are gone without falling (a farm becomes its field) just leave.
	for id in bviews.keys():
		if bs.index_of(id) < 0:
			bviews[id].queue_free()
			bviews.erase(id)
	for b in bs.count():
		var id := bs.id[b]
		var view: BuildingArt = bviews.get(id)
		var look := kit.building_key(lib.architecture(world.races[bs.owner[b]]), world.btypes[bs.kind[b]].id, world.ages[bs.owner[b]],
			(id * 7 + bs.cx[b] * 3 + bs.cy[b]) % 4)   # which house variant: steady per building, varied along a street
		if view != null and view.get_meta("look", look) != look:
			view.queue_free()   # its owner aged up and this building grew with them
			bviews.erase(id)
			view = null
		if view == null:
			var t: Dictionary = world.btypes[bs.kind[b]]
			var arch: String = lib.architecture(world.races[bs.owner[b]])
			view = BuildingArt.new()
			view.setup(kit, look, bs.cx[b], bs.cy[b], bs.size[b], Color(lib.palettes.teams[bs.owner[b]]))
			view.set_meta("look", look)
			layer.add_child(view)
			bviews[id] = view
			_clear_doodads(bs.cx[b], bs.cy[b], bs.size[b])
		var t: Dictionary = world.btypes[bs.kind[b]]
		if bs.done[b] == 1 and not view.get_meta("done", false):
			if view.has_meta("done") and bs.owner[b] == active:
				audio.play("built", -4.0)   # finished while you watched (not the ones there from the start)
		view.set_meta("done", bs.done[b] == 1)
		view.set_state(bs.done[b] == 1, float(bs.progress[b]) / float(t.build_ticks))
		if bs.done[b] == 1 and not t.becomes.is_empty() and view.get_parent() == layer:
			view.reparent(flat)   # a sown farm is walked across: it lies under the units
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
## The prop for a resource cell (bug bush, reed clump, stone outcrop, a farm's crops or paddy).
const RESOURCE_PROP := {"bugbush": "bush", "reeds": "reeds", "stone": "quarry", "gold": "gold", "carcass": "carcass", "field": "crops", "paddy": "paddy"}


func _add_resource_view(c: int, pick: int) -> void:
	var kind: String = RESOURCE_PROP[map.terrain_ids[map.terrain[c]]]
	var holder := Node2D.new()
	holder.position = Iso.to_screen((c % map.width) * 1000 + 500, (c / map.width) * 1000 + 500)
	holder.add_child(kit.doodad(kind, pick))
	holder.set_meta("res", {"kind": kind, "pick": pick, "stage": 0, "full": map.left_at(c), "gone": 0.0})
	# A farm's crops share its pool (every tile shows them) and lie flat under the farmers.
	(flat if map.pool[c] >= 0 else layer).add_child(holder)
	rviews[c] = holder


func _sync_resources() -> void:
	var dt := get_process_delta_time()
	# New resources (a farm's field) appear where the map changed.
	for c in map.changed:
		if map.left_at(c) > 0 and not rviews.has(c):
			_add_resource_view(c, c * 7 + c / map.width)
	map.changed.clear()
	map.changed_overflow = false
	for c in rviews.keys():
		var h: Node2D = rviews[c]
		var r: Dictionary = h.get_meta("res")
		var stage := ArtKit.resource_stage(r.kind, map.left_at(c), r.full)
		if stage != r.stage:
			r.stage = stage
			h.get_child(0).queue_free()
			h.add_child(kit.doodad(r.kind, r.pick, stage))
		if map.left_at(c) <= 0:
			if r.gone == 0.0 and map.pool[c] >= 0:
				_sfx_at("farm_done", h.position, -6.0)   # a farm's used up
			r.gone += dt
			var linger := 6.0 if r.kind in ["reeds", "quarry", "gold", "carcass"] else 0.0   # stubble and rubble stay a while
			h.modulate.a = clampf(1.0 - (r.gone - linger) / 1.5, 0.0, 1.0)
			if h.modulate.a <= 0.0:
				h.queue_free()
				rviews.erase(c)


## Age-up and research buttons for a building (from data/tech.json), and what it's doing.
func _tech_buttons(c: Dictionary, b: int) -> void:
	var bs := world.buildings
	var bid: int = bs.id[b]
	if bs.research[b] != -1:
		var r: int = bs.research[b]
		var item: Dictionary = Tech.next_age(world, active) if r == Tech.AGE_UP else world.tech.research[r]
		var label: String = ("Ageing up to the %s" % item.name) if r == Tech.AGE_UP else "Researching %s" % _research_name(item)
		c.info = label
		c.progress = float(bs.research_t[b]) / float(item.ticks)
		# In the big first slot, ahead of the training it holds up (Dominic: an age-up didn't show).
		var icon: Texture2D = Icons.texture("age_up") if r == Tech.AGE_UP else \
			(kit.icons.get("%d:%s" % [active, item.line]) if item.has("line") else Icons.texture(item.id))
		if c.get("queue") == null:
			c.queue = []
			c.queue_max = int(world.econ.queue_max)
		c.queue.push_front({"icon": icon, "name": label, "action": func(): pass})
		c.queue_title = "Ageing up" if r == Tech.AGE_UP else "Researching"
		return
	var age: Dictionary = Tech.next_age(world, active)
	if not age.is_empty():
		var why := Tech.why_not(world, active, b, "")
		if why != "not here":
			c.buttons.append({"text": "Age up: %s (%s)" % [age.name, _cost_text(age.cost)], "key": "U", "cost": _cost_text(age.cost),
				"icon": Icons.texture("age_up"), "tip": _age_tip(age), "group": "Age up", "accent": true,
				"enabled": why == "", "action": func(): world.issue(active, Commands.AGE_UP, {"building": bid})})
	for r in world.tech.research:
		var why := Tech.why_not(world, active, b, r.id)
		if why == "" or why == "can't afford it":
			var rid: String = r.id
			var icon: Texture2D = kit.icons.get("%d:%s" % [active, r.line]) if r.has("line") else Icons.texture(r.id)   # a line upgrade shows its unit
			c.buttons.append({"text": "%s (%s)" % [_research_name(r), _cost_text(r.cost)], "key": "", "cost": _cost_text(r.cost),
				"icon": icon, "tip": _research_tip(r), "group": "Research",
				"enabled": why == "", "action": func(): world.issue(active, Commands.RESEARCH, {"building": bid, "id": rid})})


## Buy and sell buttons for each good at a market, priced live.
func _market_buttons(c: Dictionary, b: int) -> void:
	var bid: int = world.buildings.id[b]
	for r in world.resources.size():
		var res: String = world.resources[r]
		if res == "gold":
			continue
		for buy in [true, false]:
			var price := Market.quote(world, r, buy)
			var why := Market.why_not(world, active, b, r, buy)
			var name: String = lib.resource_info[r].name
			var verb := "Buy" if buy else "Sell"
			var rr: String = res
			var flag := 1 if buy else 0
			c.buttons.append({"icon": Icons.texture("res_" + res), "key": "+" if buy else "-", "group": verb,
				"cost": "%d%s" % [price, lib.resource_info[Economy.kind_of(world, "gold")].short], "enabled": why == "",
				"text": "%s %d %s for %d gold" % [verb, Market.LOT, name.to_lower(), price],
				"tip": "[b]%s %d %s[/b]\n%s %d gold.\n[color=%s]Each trade moves the price: buying pushes it up, selling down. Prices are the same for everyone.[/color]%s" % [
					verb, Market.LOT, name.to_lower(), "Costs" if buy else "Pays", price, TIP_DIM,
					("" if why == "" else "\n[color=%s]%s[/color]" % [TIP_NEED, why.capitalize()])],
				"action": func(): world.issue(active, Commands.TRADE, {"building": bid, "resource": rr, "buy": flag})})


# ------------------------------------------------------------------ tooltips
# What each button is, costs, needs and unlocks, as BBCode for the panel's tooltip cards.

const TIP_NEED := "#e88a70"
const TIP_GOOD := "#a8d880"
const TIP_DIM := "#b8ad94"


func _tip(title: String, cost: PackedInt32Array, lines: Array, needs: Array = [], unlocks: Array = []) -> String:
	var out := "[b]%s[/b]" % title
	var parts := []
	for r in cost.size():
		if cost[r] > 0:
			var short_of: bool = world.stock[r][active] < cost[r]   # what you can't pay yet shows red
			var tint: String = TIP_NEED if short_of else "#" + Color(lib.resource_info[r].colour).lightened(0.3).to_html(false)
			parts.append("[color=%s]%d %s[/color]" % [tint, cost[r], lib.resource_info[r].name])
	if not parts.is_empty():
		out += "\n" + "    ".join(parts)
	for l in lines:
		if l != "":
			out += "\n" + l
	for n in needs:
		out += "\n[color=%s]Needs %s[/color]" % [TIP_NEED, n]
	if not unlocks.is_empty():
		out += "\n[color=%s]Unlocks: %s[/color]" % [TIP_GOOD, ", ".join(unlocks)]
	return out


func _bname(id: String) -> String:
	return world.btypes[Economy.btype_of(world, id)].name


func _effect_text(effects: Array) -> String:
	return ", ".join(effects.map(_one_effect))


func _one_effect(e: Dictionary) -> String:
	if e.has("tag"):
		return "%+d %s for %s units" % [int(e.add), e.stat, e.tag]
	return "%s gathered %d%% faster" % [String(e.gather).capitalize(), int(e.pct)]


## Research this player's race can do (the tech tree's culture layer, D-070).
func _my_research() -> Array:
	var race: Dictionary = world.races[active]
	return world.tech.research.filter(func(r): return r.only.is_empty() or bool(world.rules.get("full_tech_tree", false)) \
		or race.creature in r.only or race.family in r.only)


func _unit_tip(wt: Dictionary) -> String:
	var lines := []
	lines.append("Gathers food, wood, stone and gold, and builds." if wt.worker else UnitCard.text(wt, _foe_types(active)))
	var ups := []
	for r in _my_research():
		if r.effects.any(func(e): return e.has("tag") and e.tag in wt.eval.tags):
			ups.append("%s at the %s (%s)" % [r.name, _bname(r.building), _effect_text(r.effects)])
	if not ups.is_empty():
		lines.append("[color=%s]Upgrades: %s[/color]" % [TIP_DIM, "; ".join(ups)])
	for step in wt.line:
		if int(step.age) > world.ages[active] and int(step.age) > int(wt.line[0].age):
			lines.append("[color=%s]Age %d: becomes %s[/color]" % [TIP_DIM, int(step.age), step.recipe.get("name", wt.name)])
	var needs := [] if world.ages[active] >= int(wt.line[0].age) else ["age %d" % int(wt.line[0].age)]
	return _tip(wt.name, wt.cost, lines, needs)


func _building_tip(t: Dictionary) -> String:
	var lines := [t.desc]
	var trains := []
	for slot in t.trains:
		var tk := world.type_of(active, slot)
		if tk >= 0:
			trains.append(world.types[tk].name)
	if not trains.is_empty():
		lines.append("Trains: " + ", ".join(trains))
	var research := _my_research().filter(func(r): return r.building == t.id).map(func(r): return r.name)
	if not research.is_empty():
		lines.append("Research: " + ", ".join(research))
	if t.house or int(t.pop) > 0:
		lines.append("Houses %d" % int(t.pop))
	var takes := []
	for r in t.drop.size():
		if t.drop[r] == 1:
			takes.append(lib.resource_info[r].name.to_lower())
	if not takes.is_empty():
		lines.append("Takes in: " + ", ".join(takes))
	var for_ages: Array = world.tech.ages.filter(func(a): return t.id in a.requires).map(func(a): return a.name)
	if not for_ages.is_empty():
		lines.append("[color=%s]Needed to reach the %s[/color]" % [TIP_GOOD, " and the ".join(for_ages)])
	var needs := [] if world.ages[active] >= int(t.age) else ["age %d" % int(t.age)]
	return _tip(t.name, t.cost, lines, needs)


func _age_tip(age: Dictionary) -> String:
	var lines := [age.desc, "[color=%s]Takes %d s at the %s[/color]" % [TIP_DIM, age.ticks / 20, _bname(age.building)]]
	var needs := []
	for need in age.requires:
		if not Tech.has_building(world, active, need):
			needs.append("a " + _bname(need))
	var unlocks := []
	for bt in world.btypes:
		if int(bt.age) == int(age.age):
			unlocks.append(bt.name)
	for t in world.types:
		if t.player == active:
			for k in t.line.size():
				var step: Dictionary = t.line[k]
				var named: String = step.recipe.get("name", t.name)
				# New units unlock; renamed ones become something else (the rest just get better gear).
				if int(step.age) != int(age.age):
					continue
				if k == 0:
					unlocks.append(named)   # (later steps come with each line's upgrade, not the age)
	return _tip("Age up: " + age.name, age.cost, lines, needs, unlocks)


func _research_tip(r: Dictionary) -> String:
	var needs := [] if world.ages[active] >= int(r.age) else ["age %d" % int(r.age)]
	if r.has("line"):   # a line upgrade: what the line becomes, and how it changes
		var steps := _line_steps(r)
		var lines := [r.desc]
		if not steps.is_empty():
			var a: Dictionary = steps[0].eval
			var b: Dictionary = steps[1].eval
			lines.append("[color=%s]Becomes: %s[/color]" % [TIP_GOOD, steps[1].recipe.get("name", "")])
			lines.append("[color=%s]%s[/color]" % [TIP_GOOD, "\n".join(_step_changes(a, b))])
		return _tip(_research_name(r), r.cost, lines, needs)
	return _tip(r.name, r.cost, [r.desc, "[color=%s]%s[/color]" % [TIP_GOOD, _effect_text(r.effects)]], needs)


## What a line step changes, stat by stat ("Attack 4 -> 5"); attack, armour and hit points
## always show, so even a step that looks the same reads as an upgrade.
func _step_changes(a: Dictionary, b: Dictionary) -> Array:
	var out := ["Attack %d -> %d" % [int(a.attack), int(b.attack)],
		"Armour %d/%d -> %d/%d" % [int(a.armour.get("melee", 0)), int(a.armour.get("pierce", 0)), int(b.armour.get("melee", 0)), int(b.armour.get("pierce", 0))],
		"Hit points %d -> %d" % [int(a.hp), int(b.hp)]]
	if int(a["range"]) != int(b["range"]):
		out.append("Range %d -> %d" % [int(a["range"]), int(b["range"])])
	if int(a.speed) != int(b.speed):
		out.append("Speed %d -> %d" % [int(a.speed), int(b.speed)])
	return out


## A line upgrade's [step it leaves, step it gives] for this player, or [] if the line has none.
func _line_steps(r: Dictionary) -> Array:
	var k := world.type_of(active, r.line)
	if k < 0:
		return []
	var line: Array = world.types[k].line
	for l in range(1, line.size()):
		if int(line[l].age) == int(r.line_age):
			return [line[l - 1], line[l]]
	return []


func _research_name(r: Dictionary) -> String:
	if not r.has("line"):
		return r.name
	var steps := _line_steps(r)
	return ("Upgrade to %s" % steps[1].recipe.get("name", r.name)) if not steps.is_empty() else r.name


func _make_view(kind: int, owner: int) -> UnitView:
	var t: Dictionary = world.types[kind]
	var view := UnitView.new()
	var team := ArtKit.ANIMAL_TEAM if owner == world.gaia else Color(lib.palettes.teams[owner])
	view.build(t.recipe, lib, team, t.speed / World.SPEED_SCALE)
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

## A player's stock of every resource, e.g. "Food 200   Wood 200   Stone 0" (or short: "200F 200W 0S").
func _stock_text(p: int, short: bool) -> String:
	var parts := []
	for r in world.resources.size():
		var label: String = lib.resource_info[r].short if short else lib.resource_info[r].name
		parts.append(("%d%s" if short else "%s %d") % ([world.stock[r][p], label] if short else [label, world.stock[r][p]]))
	return " ".join(parts) if short else "    ".join(parts)


## A cost vector as text, e.g. "30W" or "15F 10W" (resources it doesn't use are left out).
func _cost_text(cost: PackedInt32Array) -> String:
	var parts := []
	for r in cost.size():
		if cost[r] > 0:
			parts.append("%d%s" % [cost[r], lib.resource_info[r].short])
	return " ".join(parts) if not parts.is_empty() else "free"


func _update_top_bar() -> void:
	if top_bar.get_child_count() == 0:
		top_bar.setup(world.resources)
		for info in lib.resource_info:
			panel.res_icons[info.short] = Icons.texture("res_" + info.id)
		top_bar.idle_pressed.connect(_next_idle_worker)
		show_debug = not vs_ai
	top_bar.position = Vector2(0, 0) if not show_debug or vs_ai else Vector2(0, 150)
	var stock := {}
	for r in world.resources.size():
		stock[world.resources[r]] = world.stock[r][active]
	var ages: Array = world.tech.ages.filter(func(a): return int(a.age) == world.ages[active])
	var age: Dictionary = ages[0] if not ages.is_empty() else {}
	top_bar.show_idle(_idle_workers().size())
	top_bar.show_state(stock, world.pop[active], world.pop_cap[active], world.races[active].name, world.tick / World.TICK_HZ)
	var next := ""
	var frac := 0.0
	for b in world.buildings.count():   # an age-up under way, wherever it is
		if world.buildings.owner[b] == active and world.buildings.research[b] == Tech.AGE_UP:
			var na: Dictionary = Tech.next_age(world, active)
			next = na.get("name", "")
			frac = float(world.buildings.research_t[b]) / float(maxi(1, int(na.get("ticks", 1))))
	top_bar.show_age(world.ages[active], age.get("name", "Age %d" % world.ages[active]), next, frac)


func _bar_text() -> String:
	var p := active
	var s := "P%d  %s   Age %d     %s    Pop %d/%d" % [p + 1, world.races[p].name, world.ages[p], _stock_text(p, false), world.pop[p], world.pop_cap[p]]
	var o := 1 - p
	s += "        (P%d %s: %s %d/%d)" % [o + 1, world.races[o].name, _stock_text(o, true), world.pop[o], world.pop_cap[o]]
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
		"click / drag / double-click select   right-click: move, gather, help build, drop off, rally   Tab: switch side",
		"Q train worker   H house   C town center   WASD/edges/middle-drag pan   wheel zoom   space pause   [ ] speed",
		"F1 hide this   F3 flow   F5 save replay   F9 play replay   F6 autoplay   F10 surrender   V reveal fog   F7 test armies   M map   R restart   G/shift+G/ctrl+G regen army",
	]
	var cell := _cell_at(get_global_mouse_position())
	if map.resource_at(cell) != "":
		lines.append("%s: %d %s left" % [map.terrain_at(cell), map.amount[cell], map.resource_at(cell)])
	return "\n".join(lines)


## The unit types of every player this one fights (for the unit card's strong/weak lines).
func _foe_types(player: int) -> Array:
	return world.types.filter(func(t): return world.is_enemy(player, t.player) and not t.worker)


func _update_panel() -> void:
	var team := Color(lib.palettes.teams[active])
	var b := world.buildings.index_of(selected_building)
	if b >= 0:
		var bs := world.buildings
		var owner := bs.owner[b]
		var t: Dictionary = world.btypes[bs.kind[b]]
		var mine := owner == active
		var c := {"title": t.name if owner == active else "%s %s" % [world.races[owner].name, t.name], "team": Color(lib.palettes.teams[owner]), "hp": [bs.hp[b], t.hp],
			"portrait": kit.building_icon(_arch(owner), t.id), "buttons": [], "queue": null, "info": ""}
		if bs.done[b] == 0:
			c.info = "Being built: %d%%" % (100 * bs.progress[b] / t.build_ticks)
		elif not t.trains.is_empty() or not world.tech.research.filter(func(r): return r.building == t.id).is_empty():
			var q: Array = bs.queue[b]
			c.queue = []
			c.queue_max = int(world.econ.queue_max)
			for n in q.size():
				var qt: Dictionary = world.types[q[n]]
				var idx := n
				c.queue.append({"icon": kit.icons.get("%d:%s" % [qt.player, qt.slot]), "name": qt.name,
					"action": func(): if mine: world.issue(active, Commands.CANCEL, {"building": selected_building, "index": idx})})
			if not q.is_empty():
				var head: Dictionary = world.types[q[0]]
				c.progress = float(bs.train[b]) / float(head.train_ticks)
				c.info = "Training %s" % head.name
				if bs.train[b] == 0 and world.pop[owner] + head.pop > world.pop_cap[owner]:
					c.info += " (needs a house)"
			if mine:
				for slot in t.trains:
					var tk := world.type_of(active, slot)
					if tk < 0:
						continue
					var wt: Dictionary = world.types[tk]
					var ok_age: bool = world.ages[active] >= int(wt.line[0].age)
					var afford: bool = world.can_afford(active, wt.cost)
					var tslot: String = slot
					c.buttons.append({"icon": kit.icons.get("%d:%s" % [active, slot]),
						"text": (("Train %s (%s)" % [wt.name, _cost_text(wt.cost)]) if ok_age else "%s: needs age %d" % [wt.name, wt.line[0].age]),
						"tip": _unit_tip(wt), "group": "Train",
						"key": "Q" if slot == "worker" else "", "cost": _cost_text(wt.cost), "enabled": ok_age and afford and q.size() < int(world.econ.queue_max),
						"action": func(): _train(selected_building, tslot)})
				_tech_buttons(c, b)
				if t.id == "market" and bs.done[b] == 1:
					_market_buttons(c, b)
				c.info += ("\n" if c.info != "" else "") + "Right-click: rally point"
		panel.show_content(c)
		return
	var mine: Array = _selected_by_owner()[active]
	if not mine.is_empty():
		var u := world.units
		var first := u.index_of(mine[0])
		var ft: Dictionary = world.types[u.kind[first]]
		var c := {"title": ft.name if mine.size() == 1 else "%d selected" % mine.size(), "team": team, "buttons": [], "queue": null,
			"portrait": kit.icons.get("%d:%s" % [ft.player, ft.slot]), "hp": [u.hp[first], ft.hp] if mine.size() == 1 else []}
		if mine.size() == 1 and ft.worker:
			c.info = ["Idle", "Gathering", "Carrying back", "Building"][u.task[first]]
			if u.carry[first] > 0:
				c.info += " (%d %s)" % [u.carry[first], world.resources[u.carry_kind[first] - 1]]
		elif mine.size() == 1:
			c.info = UnitCard.text(ft, _foe_types(active))
		else:
			c.info = ""
			var counts := {}
			for id in mine:
				var k := u.kind[u.index_of(id)]
				counts[k] = counts.get(k, 0) + 1
			var kinds := counts.keys()
			kinds.sort()
			c.tray = kinds.map(func(k): return {"icon": kit.icons.get("%d:%s" % [world.types[k].player, world.types[k].slot]), "count": counts[k]})
		if _selected_workers().size() < mine.size():   # soldiers: attack-move and stop
			c.buttons.append({"icon": Icons.texture("attack_move"), "text": "Attack-move", "key": "R", "cost": "", "enabled": true, "group": "Orders",
				"tip": "[b]Attack-move[/b]\nThen click where: they walk there and fight whatever they meet on the way.", "action": func(): arming_attack = true})
			c.buttons.append({"icon": Icons.texture("stop"), "text": "Stop", "key": "X", "cost": "", "enabled": true, "group": "Orders",
				"tip": "[b]Stop[/b]\nDrop every order: they stand where they are.", "action": stop_selected})
			var now := _soldier_stance(mine)
			for k in STANCES.size():
				var stance: String = Combat.POSTURES[k]
				c.buttons.append({"icon": Icons.texture("stance_" + stance), "text": STANCES[k][0], "key": "", "cost": "ON" if now == k else "", "enabled": true, "group": "Stance", "accent": now == k,
					"tip": "[b]%s[/b]%s\n%s\nOrdered attacks work under every stance." % [STANCES[k][0], " (now)" if now == k else "", STANCES[k][1]],
					"action": func(): set_stance(stance)})
			c.info += ("\n" if c.info != "" else "") + "Stance: %s" % (STANCES[now][0] if now >= 0 else "mixed")
		if not _selected_workers().is_empty():
			if str(mine) != _build_page_for:
				_build_page_for = str(mine)
				build_page = ""
			if build_page == "":
				for page in [["civilian", "Civilian", "house", "Houses, farms, camps, the market and Town Centers."],
						["military", "Military", "barracks", "Barracks, ranges, stables, the armoury, towers and walls."]]:
					var pid: String = page[0]
					c.buttons.append({"icon": kit.building_icon(_arch(active), page[2]), "text": "Build: %s" % page[1], "key": "", "cost": page[1], "enabled": true,
						"glyph": Icons.texture("glyph/" + page[2]), "group": "Build",
						"tip": "[b]%s buildings[/b]\n%s" % [page[1], page[3]], "action": func(): build_page = pid})
			else:
				for id in build_menu[build_page]:
					var t: Dictionary = world.btypes[Economy.btype_of(world, id)]
					if world.ages[active] < t.age:
						continue
					var afford: bool = world.can_afford(active, t.cost)
					var bid: String = id
					c.buttons.append({"icon": kit.building_icon(_arch(active), id), "text": "Build %s (%s)" % [t.name, _cost_text(t.cost)],
						"tip": _building_tip(t), "glyph": Icons.texture("glyph/" + id), "group": build_page.capitalize(),   # what it's for, the same in every culture
						"key": t.hotkey, "cost": _cost_text(t.cost), "enabled": afford, "action": func(): start_placing(bid)})
				c.buttons.append({"icon": Icons.texture("back"), "text": "Back", "key": "Esc", "cost": "", "enabled": true, "group": " ",
					"tip": "[b]Back[/b]\nTo the civilian and military pages.", "action": func(): build_page = ""})
		if placing != "":
			c.info = "Placing: left-click to build, shift keeps placing, right-click/Esc cancels"
		panel.show_content(c)
		return
	if selected_resource >= 0:
		var left := map.left_at(selected_resource)
		if left <= 0:
			selected_resource = -1
		else:
			var tname: String = map.terrain_ids[map.terrain[selected_resource]]
			var what: String = {"bugbush": "Bug bush", "reeds": "Reeds", "stone": "Stone", "gold": "Gold", "carcass": "Carcass"}.get(tname, tname.capitalize())
			panel.show_content({"title": what, "team": Color("#8a7a5a"), "buttons": [], "queue": null, "portrait": null,
				"hp": [left, rviews[selected_resource].get_meta("res").full] if rviews.has(selected_resource) else [],
				"info": "%d %s left" % [left, map.resource_at(selected_resource)]})
			return
	var seen := selected.keys().filter(func(id): return world.units.index_of(id) >= 0)
	if not seen.is_empty():   # the other side's unit, inspected (against the AI): its card, no orders
		var i := world.units.index_of(seen[0])
		var et: Dictionary = world.types[world.units.kind[i]]
		var eo := world.units.owner[i]
		panel.show_content({"title": et.name if eo == world.gaia else "%s, %s" % [et.name, world.races[eo].name], "team": Color(lib.palettes.teams[eo]) if eo != world.gaia else ArtKit.ANIMAL_TEAM, "buttons": [], "queue": null,
			"portrait": kit.icons.get("%d:%s" % [et.player, et.slot]), "hp": [world.units.hp[i], et.hp],
			"info": UnitCard.text(et, _foe_types(eo))})
		return
	panel.show_content({"title": world.races[active].name, "team": team, "portrait": null,
		"info": "Select units or a building." if vs_ai else "Select units or a building.  Tab switches side.  F6: let the bots play.", "buttons": [], "queue": null})


func _arch(player: int) -> String:
	return lib.architecture(world.races[player])


## The cursor shows what a right-click would do for the selection.
func _update_cursor() -> void:
	if baking or world == null or placing != "" or get_viewport().gui_get_hovered_control() != null:
		cursors.use("pointer")
		return
	if arming_attack:
		cursors.use("attack")
		return
	var pos := get_global_mouse_position()
	var b := world.buildings.index_of(selected_building)
	if b >= 0:
		cursors.use("pointer")   # right-click sets the rally point; the genre doesn't need a special cursor for it
		return
	if _selected_by_owner()[active].is_empty():
		cursors.use("pointer")
		return
	var cell := _cell_at(pos)
	var bid: int = map.occupied[cell]
	var enemy: bool = bid != 0 and world.is_enemy(active, world.buildings.owner[world.buildings.index_of(bid)]) \
		and bviews.has(bid) and bviews[bid].visible   # not over buildings you haven't found
	var under := unit_at(pos)
	if under != 0 and world.is_enemy(active, world.units.owner[world.units.index_of(under)]):
		enemy = true
	var workers := not _selected_workers().is_empty()
	if enemy:
		cursors.use("attack")
	elif workers and map.resource_at(cell) != "":
		cursors.use({"food": "forage", "wood": "chop", "stone": "mine", "gold": "mine"}.get(map.resource_at(cell), "chop"))
	elif workers and bid != 0 and _is_foundation_of(bid, active):
		cursors.use("build")
	elif workers and bid != 0 and _drop_off_kind(bid, active, _selected_workers()) != "":
		# taking it in: the carried resource's tool (there's no drop-off cursor art yet)
		var kind := _drop_off_kind(bid, active, _selected_workers())
		cursors.use({"food": "forage", "wood": "chop", "stone": "mine", "gold": "mine"}.get(kind, "move"))
	else:
		cursors.use("move")


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
		marks.draw_arc(Vector2.ZERO, u.radius[i] * Iso.RADIUS_PX, 0.0, TAU, 24, Color(0, 0, 0, 0.6), 3.5 / camera.zoom.x)   # a dark edge...
		marks.draw_arc(Vector2.ZERO, u.radius[i] * Iso.RADIUS_PX, 0.0, TAU, 24, RING, 2.0 / camera.zoom.x)   # ...under a bright ring (Fable: 1.5 px was too thin)
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
	var u := world.units
	# Health bars over anyone hurt (and anyone selected).
	var bar_w := 12.0
	for i in u.count():
		var id := u.id[i]
		var full: int = world.types[u.kind[i]].hp
		if u.hp[i] >= full and not selected.has(id):
			continue
		var view: Node2D = views.get(id)
		if view == null or not view.visible:
			continue
		var at := view.position - Vector2(bar_w * 0.5, BODY_LIFT * 2.6)
		var k := clampf(float(u.hp[i]) / float(full), 0.0, 1.0)
		overlay.draw_rect(Rect2(at, Vector2(bar_w, 2)), Color(0, 0, 0, 0.6))
		overlay.draw_rect(Rect2(at, Vector2(bar_w * k, 2)), Color(1.0 - k, 0.3 + 0.6 * k, 0.15).lerp(Color.WHITE, 0.1))
	var b := world.buildings.index_of(selected_building)
	if b >= 0:
		var bs := world.buildings
		var s := bs.size[b] * 1000
		var x0 := bs.cx[b] * 1000
		var y0 := bs.cy[b] * 1000
		var pts := PackedVector2Array([Iso.to_screen(x0, y0), Iso.to_screen(x0 + s, y0), Iso.to_screen(x0 + s, y0 + s),
			Iso.to_screen(x0, y0 + s), Iso.to_screen(x0, y0)])
		overlay.draw_polyline(pts, Color(0, 0, 0, 0.6), 4.0 / camera.zoom.x)
		overlay.draw_polyline(pts, RING, 2.0 / camera.zoom.x)
		if bs.rally_x[b] >= 0:
			var rp := Iso.to_screen(bs.rally_x[b], bs.rally_y[b])
			overlay.draw_line(Iso.to_screen(x0 + s / 2, y0 + s / 2), rp, Color(RING, 0.4), 1.0 / camera.zoom.x)   # the flag itself is in the marks
	if placing != "":
		var c := _ghost_cell(get_global_mouse_position())
		var size: int = world.btypes[Economy.btype_of(world, placing)].size
		var bt: Dictionary = world.btypes[Economy.btype_of(world, placing)]
		var ghosts := wall_cells(wall_from, c) if placing == "wall" and wall_from.x >= 0 else [c]
		for g in ghosts:
			var ok := map.can_build(g.x, g.y, size, Economy.builder_class(world, active), bt.water)
			var x0: int = g.x * 1000
			var y0: int = g.y * 1000
			var s := size * 1000
			overlay.draw_colored_polygon(PackedVector2Array([Iso.to_screen(x0, y0), Iso.to_screen(x0 + s, y0),
				Iso.to_screen(x0 + s, y0 + s), Iso.to_screen(x0, y0 + s)]), GOOD if ok else BAD)
	if boxing:
		var r := Rect2(press_world, Vector2.ZERO).expand(get_global_mouse_position())
		overlay.draw_rect(r, Color(RING, 0.12))
		overlay.draw_rect(r, RING, false, 1.0 / camera.zoom.x)
