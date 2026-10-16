extends Node2D
## Sim debug view: the headless sim drawn isometrically, interpolated between
## ticks. Selection happens on screen (what you see is what you select); every
## order goes through the command queue, so F5 saves a replay of exactly what
## happened and F9 plays it back, checking hashes as it goes.
##
## You command one side at a time (Tab switches). F6 hands both sides to the
## economy bot, which is the easiest way to watch an opening.
##
## F2 (or the top bar's Tech tree button) opens your race's tech tree page (scenes/tech_tree.tscn)
## over the match; Esc closes it. The sim keeps running underneath. (Not T: that is the
## Watchtower's hotkey while workers are selected.)

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const SimClock := preload("res://src/sim_clock.gd")
const Iso := preload("res://src/view/iso.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const TerrainView := preload("res://src/view/art/terrain_view.gd")
const LandView := preload("res://src/view/art/land_view.gd")
const BuildingArt := preload("res://src/view/art/building_art.gd")
const Models := preload("res://src/view/art/bake/models.gd")
const Paths := preload("res://scenes/art_pixel/paths.gd")
const MatchLoader := preload("res://scenes/match_loader.gd")
const CombatFx := preload("res://src/view/combat_fx.gd")
const Tech := preload("res://src/sim/tech.gd")
const Market := preload("res://src/sim/market.gd")
const Pens := preload("res://src/sim/pens.gd")
const Garrison := preload("res://src/sim/garrison.gd")
const RtsCamera := preload("res://src/view/rts_camera.gd")
const CommandPanel := preload("res://src/view/command_panel.gd")
const UiTheme := preload("res://src/view/ui/theme.gd")
const TopBar := preload("res://src/view/top_bar.gd")
const WonderClock := preload("res://src/view/wonder_clock.gd")
const Match := preload("res://src/sim/match.gd")
const UnitCard := preload("res://src/view/unit_card.gd")
const HeroLine := preload("res://src/heroes.gd")
const SimHeroes := preload("res://src/sim/heroes.gd")
const FogView := preload("res://src/view/fog_view.gd")
const Minimap := preload("res://src/view/minimap.gd")
const UiScale := preload("res://src/view/ui_scale.gd")
const Audio := preload("res://src/view/audio.gd")
const Fog := preload("res://src/sim/fog.gd")
const Cursors := preload("res://src/view/art/cursors.gd")
const OrderMarks := preload("res://src/view/order_marks.gd")
const Icons := preload("res://src/view/art/icons.gd")
const Commands := preload("res://src/sim/commands.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Economy := preload("res://src/sim/economy.gd")
const Buildings := preload("res://src/sim/buildings.gd")
const Combat := preload("res://src/sim/combat.gd")
const Abilities := preload("res://src/sim/abilities.gd")
const Replay := preload("res://src/sim/replay.gd")
const SaveGame := preload("res://src/save_game.gd")
const SavesPage := preload("res://src/view/ui/saves_page.gd")
const Bot := preload("res://src/ai/bot.gd")
const Walls := preload("res://src/sim/walls.gd")
const Repair := preload("res://src/sim/repair.gd")
const WALL_PX: float = Models.WALK_H.wall * ArtKit.WALK_PX_PER_UNIT   # a stone wall's walkway over the ground at 1x (as ArtKit walk_px), for a climb
const TechTreeModel := preload("res://src/view/tech_tree_model.gd")
const TownLife := preload("res://src/view/town_life.gd")
const PadPlay := preload("res://src/view/pad_play.gd")
const PadMode := preload("res://src/view/pad_mode.gd")

const MAP_IDS := ["flat_test", "choke_test", "reed_meadow", "reed_meadow_2v2", "old_forest", "river_delta", "river_test"]
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
const HERO_GOLD := Color("#e6b84a")   # a hero's crown and name plate
const HERO_CROWN_LIFT := 7.0           # a hero's crown over its head's socket (head and hat), in part units
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
var kit: ArtKit             # bakes the pixel art for the races in play (the lobby's, when it set one)
var loader: Control         # the match loader (scenes/match_loader.gd) while the first match's art is made
var loader_layer: CanvasLayer   # its layer, until it has faded out (is_loading())
var ground_holder: Node2D   # the terrain (rebuilt per map)
var ground: TerrainView
var land: LandView           # map bridges, tree species, worn trails (rebuilt per map)
var doodads := {}           # cell -> [nodes]: cosmetic props, cleared where buildings go up
var baking := false
var built_shown = null      # the finished buildings shown (ids, who looks) when the paths were last planned
var path_anchors := {}      # player -> {hub, res}: where its paths start and the food and wood they lead to (picked once)
var palette: ColorRect      # optional whole-frame palette pass (P)
var attack_move := false    # the order being given is an attack-move
var queueing := false       # the order being given is shift-queued
var arming_attack := false  # R was pressed: the next left click attack-moves there
var arming_ability := false # the race's ability button was pressed: the next left click uses it there (abilities.gd)
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
var shot_kinds := {}        # shooter id -> the look of its last shot (a miss sticks in the ground as one)
var town: TownLife          # the town at work and at rest: piles, chores, smoke, critters, its sound
var marks: Node2D           # under units: selection rings, move lines, flow arrows
var layer: Node2D           # units, buildings and resource props, y-sorted
var overlay: Node2D         # over everything: selection box, placement ghost, carried loads
var hud: Label
var bar: Label              # the debug line of both sides' stock (not against the AI)
var top_bar: TopBar
var wonder_clock: WonderClock   # the Wonder countdowns everyone sees, under the top bar
var tech_tree: Control      # the tech tree page (F2), over the match while open
var build_menu: Dictionary = DataLib.load_json("res://data/buildings.json").menu   # a worker's two build pages: civilian, military
var build_page := ""        # the page a worker's panel shows: "" (pick a page), "civilian" or "military"
var _build_page_for := ""   # the selection it was opened for; a new selection starts at the top
var show_debug := true      # the debug lines (F1); off by default against the AI
var panel: CommandPanel
var cursors: Cursors
var pad_play: PadPlay       # the battlefield on a pad: reticle, selection circle, wheel (milestone 20)
var views := {}             # unit id -> UnitView (view side only; never feeds the sim)
var bviews := {}            # building id -> BuildingArt
var rviews := {}            # resource cell -> its prop (reed clump, bug bush)
var res_cells := {}         # cell -> its prop variant: every cell that held a resource or changed (props come and go here)
var _fading := {}           # resource cells whose prop is fading out (looked at every frame; the rest at the fog's rate)
var _res_tick := -1000      # the world tick resource props were last all looked at, and for whom
var _res_reveal := false
var _res_left := PackedInt32Array()     # per cell: what was left there, as last shown (-1: never looked at)
var _res_ground := PackedByteArray()    # per cell: the ground (terrain index) as last shown
var _res_active := -1
var ghosts := {}            # building id -> BuildingArt: enemy buildings gone out of sight, shown as last seen
var selected := {}          # unit id -> true
var sheltered := {}         # unit id -> true: went inside a building (garrison.gd); back out it isn't "trained"
var selected_building := 0  # building id, or 0: the lead of the selected buildings (its queue and research show)
var selected_buildings := {} # building id -> true: the lead and every building of its type selected with it
var selected_resource := -1 # a resource cell clicked to see what's left, or -1
var active := 0             # the side you're commanding
var placing := ""           # building type being placed, or ""
var wall_from := Vector2i(-1, -1)   # where a wall drag started (a cell), while placing walls
var gate_along := 0                  # which way a gate goes on open ground (Economy.dims: 0 along sim x, 1 along y, 2 and 3 the diagonals; R turns it)
var flags: Array = []       # [{pos, t}] recent move targets
var rally_flag: Sprite2D    # the selected building's rally point (a baked prop), or null
var order_marks: OrderMarks # selected units' orders, now and shift-queued, as routes of waypoints
var playback := {}          # the replay being played, or empty when live
var checked := 0            # world.hashes entries already compared
var desync := -1
var show_flow := false
var autoplay := false
var army := false           # also spawn a test army per side (F7 toggles and restarts)
var ai_level := "normal"    # easy, normal or hard (data/ai.json levels; picked in the lobby)
var ai_levels: Array = []   # per player in a match against the AI: its level, "" for you (player 0); empty: every other player at ai_level
var player_teams: Array = [] # per player: its team (allies share one); empty: everyone for themselves
var mode := ""                # the game mode (data/modes.json, picked in the lobby; "": the usual match), set on the rules
var vs_ai := false          # side 2 is played by the AI (set by the match setup screen)
var banner: Label           # victory / defeat
var pause_menu: Control     # Esc against the AI: resume, surrender, back to the menu
var saves_page: Control     # the pause menu's Load: the saved matches (src/view/ui/saves_page.gd)
var bot_seats: Array = []   # [{player, level, from_seq, at}] the bots playing (for a save: src/save_game.gd)
var load_save := {}         # a saved match to play on from (set before adding to the tree, as the prompts)
var loaded_at: Array = []   # [tick, state hash] the saved match came back at (tests/save_check.gd)
var hud_family := "?"       # whose culture the HUD wears (the side you command)
var hud_themes := {}        # family -> the HUD's Theme
var fog_view: FogView
var flat: Node2D             # ground-level art (farms, crops), drawn under the y-sorted layer
var minimap: Minimap
var hud_root: Control     # every HUD control lives in here, scaled to the screen's density
var pages_root: Control   # full-screen pages (the tech tree) over the HUD, scaled the same way
var pending_stance := {}  # a stance just clicked, shown at once until the sim applies it: {ids, k, until}
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
	rules = DataLib.load_rules("default")

	clock = SimClock.new()
	add_child(clock)
	if kit == null:   # the lobby hands over its kit, with what it baked already
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
	town = TownLife.new()   # over the y-sorted layer (dust, critters), under the fog
	town.setup(self)
	add_child(town)
	fx = CombatFx.new()
	fx.lib = lib   # (siege shots' baked sprites: data/siege_shots.json)
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
	palette.material = pm   # (its palette is made when P first shows it)
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
	wonder_clock = WonderClock.new()
	wonder_clock.position.y = 195   # under the tip strip and the alert line
	ui.add_child(wonder_clock)
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
	var pages := CanvasLayer.new()   # over the HUD (and the hints that appear later)
	pages.layer = 3
	add_child(pages)
	pages_root = Control.new()   # scaled like the HUD (_fit_hud)
	pages_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages.add_child(pages_root)
	tech_tree = load("res://scenes/tech_tree.tscn").instantiate()
	pages_root.add_child(tech_tree)
	_fit_hud()
	cursors = Cursors.new(DisplayServer.screen_get_scale())
	pad_play = PadPlay.new()
	add_child(pad_play)
	pad_play.setup(self)

	if prompts.is_empty():
		var args := OS.get_cmdline_user_args()
		prompts = DEFAULT_PROMPTS.duplicate()
		for i in mini(args.size(), 2):
			prompts[i] = args[i]
	if load_save.is_empty():
		start_live(prompts)
	else:
		start_saved(load_save)


## The HUD's scale for this window, and its root sized to the window in UI pixels. Its theme is
## the culture of the side you command (src/view/ui/theme.gd): frames, crest, buttons, type.
func _fit_hud() -> void:
	var f := UiScale.factor(get_window(), UiScale.HUD_NEEDS)
	hud_root.scale = Vector2(f, f)
	get_viewport().oversampling_override = f   # text drawn at the size it's shown, not made at 1x and scaled (fuzzy on the Deck)
	hud_root.size = get_viewport_rect().size / f
	CommandPanel.TipButton.ui_scale = f   # tooltip cards are popups outside the HUD: they scale their own type
	var fam := hud_family if hud_family != "?" else ""
	if not hud_themes.has(fam):
		hud_themes[fam] = UiTheme.theme(UiTheme.look(fam), 16)
	var t: Theme = hud_themes[fam]
	t.set_font_size("font_size", "TooltipLabel", roundi(15 * f))   # plain tooltips (the idle button) are popups too
	t.set_stylebox("panel", "TooltipPanel", UiTheme.tip_box(UiTheme.look(fam), f))
	hud_root.theme = t
	if pages_root != null:
		pages_root.scale = hud_root.scale
		pages_root.size = hud_root.size
		pages_root.theme = t


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
		races.append(gen.generate(race_prompts[k], rules, rerolls[k] if k < rerolls.size() else 0))
	await _bake(races)
	var match_rules := rules
	if mode != "":   # the game mode is one of the match's rules (src/sim/modes.gd)
		match_rules = rules.duplicate(true)
		match_rules.mode = mode
	_attach(World.new(SEED, map, races, match_rules, player_teams))
	_loaded()
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
	_loaded()
	playback = rep
	clock.bots = []


## Set up to play on from a saved match (before adding to the tree): the lobby's choices as they were.
func use_save(rep: Dictionary) -> void:
	var v: Dictionary = rep.view
	load_save = rep
	prompts = v.prompts
	rerolls = v.rerolls
	player_teams = v.player_teams
	ai_levels = v.ai_levels
	ai_level = v.ai_level
	map_id = rep.map
	mode = v.mode
	vs_ai = v.vs_ai


## Play on from a saved match (src/save_game.gd): its snapshot poured over a fresh world.
func start_saved(rep: Dictionary) -> void:
	if baking:
		return
	map_id = rep.map
	var ld := SaveGame.begin(rep, lib)
	if not ld.same:
		print("The save comes from another build; changed since: ", ld.changed)
	await _bake(ld.world.races)
	_attach(ld.world)
	loaded_at = [world.tick, world.state_hash()]
	_loaded()
	playback = {}
	var v: Dictionary = rep.view
	active = v.active
	hint_step = v.hint_step
	for k in v.groups:
		groups[int(k)] = v.groups[k].filter(func(id): return world.units.has(id))
	autoplay = false
	clock.bots = ld.bots
	bot_seats = rep.bots.duplicate(true)
	audio.music_age(world.ages[active])
	audio.ambience(true)
	camera.look_at_point(Vector2(v.camera[0], v.camera[1]))


## Save the match as it stands (the pause menu's Save game): a new file each time.
func save_game() -> String:
	var path := SaveGame.new_path()
	var at := camera.get_screen_center_position()
	var keep_groups := {}
	for k in groups:
		keep_groups[k] = groups[k].duplicate()
	SaveGame.save(SaveGame.record(world, bot_seats, clock.bots, {
		"active": active, "prompts": prompts, "rerolls": rerolls, "player_teams": player_teams, "ai_levels": ai_levels,
		"ai_level": ai_level, "map_id": map.id, "mode": mode, "vs_ai": vs_ai, "names": world.races.map(func(r): return r.name),
		"hint_step": hint_step, "groups": keep_groups, "camera": [at.x, at.y]}), path)
	print("Saved the match: ", ProjectSettings.globalize_path(path))
	return path


## Leave this match for a saved one: a fresh match screen takes the kit (what's baked stays).
func load_game(rep: Dictionary) -> void:
	get_tree().paused = false
	var view = load("res://scenes/sim_debug.tscn").instantiate()
	view.use_save(rep)
	remove_child(kit)
	view.kit = kit
	get_tree().root.add_child(view)
	get_tree().current_scene = view
	queue_free()


## Bake the art for these races (only what isn't baked yet). The first match shows the match
## loader meanwhile (it fades out in _loaded once the world is attached); a restart a note.
func _bake(races: Array) -> void:
	baking = true
	clock.paused = true
	var teams := []
	for k in races.size():
		teams.append(Color(lib.palettes.teams[k]))
	if world == null:
		var over := CanvasLayer.new()
		over.layer = 10   # over the HUD and the pages
		add_child(over)
		loader_layer = over
		loader = MatchLoader.new()
		over.add_child(loader)
		loader.start(kit, lib, races, teams, map_id)
	else:
		bar.text = "Baking the art..."
	await kit.prepare(races, teams)
	baking = false


## The match loader is still up (making the art, or fading into the match).
func is_loading() -> bool:
	return baking or is_instance_valid(loader_layer)


## The world is up: the loader fades into it.
func _loaded() -> void:
	if loader != null:
		loader.finish()
		loader = null


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
	for d in [views, bviews, rviews, ghosts]:
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
	if order_marks != null:
		order_marks.clear()
	order_marks = OrderMarks.new(self)
	fx.clear()
	town.reset()
	built_shown = null
	path_anchors.clear()
	res_cells.clear()
	_fading.clear()
	_res_tick = -1000
	_res_left = PackedInt32Array()
	selected.clear()
	selected_building = 0
	selected_buildings.clear()
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
	Iso.set_relief(map)   # high ground lifts everything drawn on it (none on a flat map)
	ground = TerrainView.new()
	ground_holder.add_child(ground)
	ground.build(map)
	ground.build_relief(layer)
	ground.set_art_px(camera.zoom.x / ArtKit.ART_SCALE)
	if land:
		land.queue_free()
	land = LandView.new()
	ground_holder.add_child(land)
	land.setup(w, kit, flat, ground.mat)
	camera.bounds = Iso.map_rect(map.width, map.height)
	var picks := TerrainView.variant_picks(map.resource_cells, map.width, ArtKit.DOODADS.bush, hash(map.id))
	for c in map.resource_cells:
		res_cells[c] = picks[c]
	_sync_resources()
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
			if map.amount[c] > 0 or map.occupied[c] != 0 or land.bridge_at(c) >= 0:
				return true   # (no shore reeds growing through a bridge deck)
	for s in map.starts:
		if t.distance_to(Vector2(s[0], s[1]) / 1000.0) < 4.0:
			return true
	return false


## Each side's paths in its culture's style: from its Town Center's door to its other
## finished buildings and the nearest bug bushes, reeds and shore. Re-planned when a
## building is finished. An enemy's only run between the buildings you've seen.
func _refresh_paths() -> void:
	var bs := world.buildings
	var owners := []
	for p in world.races.size():
		var mine := []
		for b in bs.count():
			if bs.owner[b] == p and _shown_done(b) and not _wall_like(b):   # no path to every wall tile
				mine.append(b)
		if mine.is_empty():
			continue
		mine.sort_custom(func(a, b): return bs.sx[a] * bs.sy[a] > bs.sx[b] * bs.sy[b] or (bs.sx[a] * bs.sy[a] == bs.sx[b] * bs.sy[b] and bs.id[a] < bs.id[b]))
		var style: Dictionary = lib.families[world.races[p].family].get("paths", {"style": "trail", "width": 0.36})
		# The hub and the paths out to food and wood are picked once, from the first town: the
		# ground plans paths to grow (laid ones stay), and a hub or resource that moved with every
		# bush eaten or hall built would re-route roads that had stood for minutes.
		if not path_anchors.has(p):
			var at := _door(mine[0])
			var res := []
			for kind in ["food", "wood"]:
				var t := _nearest_resource_edge(kind, at)
				if t.x >= 0:
					res.append(t)
			path_anchors[p] = {"hub": at, "res": res}
		var hub: Vector2 = path_anchors[p].hub
		var targets := []
		for b in mine:
			if _door(b) != hub:
				targets.append(_door(b))
		targets.append_array(path_anchors[p].res)
		owners.append({"style": style.style, "width": float(style.width), "hub": hub, "targets": targets})
	ground.set_paths(owners)


## The spot in front of a building's door (doors face +y, the viewer's lower left).
func _door(b: int) -> Vector2:
	var bs := world.buildings
	return Vector2(bs.cx[b] + bs.sx[b] * 0.5, bs.cy[b] + bs.sy[b] + 0.45)


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
		bot_seats = []
	elif on:
		_seat_bots(range(world.races.size()).map(func(p): return [p, "normal"]))   # watch the AIs play
	else:
		var seats := []
		if vs_ai:   # a bot for every player but you, each at its own level
			for p in range(1, world.races.size()):
				seats.append([p, ai_levels[p] if p < ai_levels.size() and ai_levels[p] != "" else ai_level])
		_seat_bots(seats)


## Bots for these [player, level]s, and their seats for a save (src/save_game.gd).
func _seat_bots(seats: Array) -> void:
	clock.bots = seats.map(func(s): return Bot.new(s[0], {}, s[1]))
	bot_seats = seats.map(func(s): return {"player": s[0], "level": s[1], "from_seq": world.commands.next_seq.get(s[0], 0), "at": world.tick})


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	var d := UiScale.key_step(event)   # Cmd/Ctrl + minus / plus: the UI a step smaller or larger (saved)
	if d != 0:
		UiScale.step(d)
		_fit_hud()
		get_viewport().set_input_as_handled()
		return
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
		if arming_ability:   # the ability button then a click: the race's ability there
			if event.pressed:
				var m := Iso.pick(get_global_mouse_position())
				world.issue(active, Commands.ABILITY, {"ids": selected.duplicate(), "x": m.x, "y": m.y})
				arming_ability = false
			return
		if placing != "" and _line(placing):   # walls and gates are dragged: press at one end, release at the other
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
		if tech_tree.visible:   # the page is up: only its own keys (Esc closes it, see tech_tree.gd)
			if event.keycode == KEY_F2:
				tech_tree.close()
			return
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
		KEY_U:   # research and the age-up go to the lead only: each is once per player
			if selected_building != 0:
				world.issue(active, Commands.AGE_UP, {"building": selected_building})
			return true
		KEY_PERIOD:
			_next_idle_worker()
			return true
		KEY_F1:
			show_debug = not show_debug
			return true
		KEY_F2:
			toggle_tech_tree()
			return true
	if k == KEY_R and placing != "" and world.btypes[Economy.btype_of(world, placing)].gate:
		gate_along = (gate_along + 1) % 4   # turn the gate an eighth (on a wall it follows the wall anyway)
		return true
	if _selected_workers().size() < _selected_by_owner()[active].size():   # any soldiers (or our sheep) in the selection
		var soldiers: bool = _selected_by_owner()[active].any(func(id): return not _is_animal(id) and not world.types[world.units.kind[world.units.index_of(id)]].worker)
		if k == KEY_R and soldiers:   # soldiers: attack-move (then click where); sheep fight nothing
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
			if palette.material.get_shader_parameter("palette") == null:   # made the first time it's shown (it takes seconds)
				var pal: Image = ArtKit.palette(lib)
				palette.material.set_shader_parameter("palette", ImageTexture.create_from_image(pal))
				palette.material.set_shader_parameter("count", pal.get_width())
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
const PAD_HINTS := [   # the same three on a pad
	"D-pad up: your Town Center. Tap A on it for its commands, point at the worker, A to train.",
	"D-pad down: an idle worker. Aim at a bush, reeds or stone and press X to gather.",
	"Build a House (tap A on a selected worker, Build: Civilian, House, A to place) before your population fills up.",
]

func _update_hint() -> void:
	if not vs_ai or hint_step >= HINTS.size() or world.winner >= 0:
		if hint != null:
			hint.visible = false
		return
	if hint == null:
		hint = _label(18, Vector2(24, 0))
		hint.add_theme_color_override("font_color", Color("#f4ead0"))
		var st: StyleBox = UiTheme.tip_box(UiTheme.look(hud_family))
		st.accent = Color(UiTheme.look(hud_family).accent, 0.6)
		hint.add_theme_stylebox_override("normal", st)
		hint.set_anchors_preset(Control.PRESET_CENTER_TOP)   # under the top bar: tooltip cards live above the panel
		hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
		hint.position.y = 84
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
		hint.text = "Tip %d of 3:  %s" % [hint_step + 1, (PAD_HINTS if PadMode.of(get_tree()).on else HINTS)[hint_step]]


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
	_show_line("Under attack!  (%s to look)" % ("View" if PadMode.of(get_tree()).on else "Space"), Color("#ff8a70"))
	PadMode.of(get_tree()).rumble(0.5, 0.7, 0.35)


## A line at the top of the screen for three seconds (under attack, a farm worked out).
func _show_line(text: String, color: Color) -> void:
	if alert_label == null:
		alert_label = _label(26, Vector2.ZERO)
		alert_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		alert_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		alert_label.position.y = 150   # below the tip strip
		banner.get_parent().add_child(alert_label)
	alert_label.add_theme_color_override("font_color", color)
	alert_label.text = text
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
		if world.types[world.units.kind[i]].worker or world.types[world.units.kind[i]].has("animal"):
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
		pending_stance = {"ids": ids, "k": Combat.POSTURES.find(stance), "until": world.tick + 20}
		_say("ack")


## The stance the panel shows: the sim's, or the one just clicked for these soldiers while
## its command is on the way (it lands a few ticks later; a second at most).
func _shown_stance(mine: Array) -> int:
	var now := _soldier_stance(mine)
	if pending_stance.is_empty():
		return now
	if now == pending_stance.k or world.tick > pending_stance.until:
		pending_stance = {}
		return now
	var soldiers := mine.filter(func(id): return not world.types[world.units.kind[world.units.index_of(id)]].worker)
	return pending_stance.k if soldiers == pending_stance.ids else now


func stop_selected() -> void:
	var mine: Array = _selected_by_owner()[active]
	if not mine.is_empty():
		world.issue(active, Commands.STOP, {"ids": mine})
		_say("ack")


## The selected workers slaughter the selected sheep: the first now, the rest queued (each
## carcass is gathered before the next, as the sim's hunters do).
func slaughter_selected() -> void:
	var workers := _selected_workers()
	var herd: Array = _selected_by_owner()[active].filter(_is_animal)
	if workers.is_empty() or herd.is_empty():
		return
	for n in herd.size():
		world.issue(active, Commands.ATTACK, {"ids": workers, "target": herd[n], "queue": 0 if n == 0 else 1})
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
	selected_buildings.clear()
	selected_resource = -1
	placing = ""


func _body(view: Node2D) -> Vector2:
	return view.ground() - Vector2(0, BODY_LIFT)


## Where the player points: the mouse, or the pad's reticle in pad mode.
func _pointer() -> Vector2:
	return pad_play.pointer() if pad_play != null and pad_play.live() else get_global_mouse_position()


func _cell_at(pos: Vector2) -> int:
	var m := Iso.pick(pos)
	return map.cell_of(m.x, m.y)


## Click: the unit whose body is nearest the cursor (within PICK_PX on screen),
## else the building under it.
func select_at(pos: Vector2, add := false) -> void:
	if not add:
		_clear_selection()
	var best := unit_at(pos)
	if best != 0:
		selected_building = 0
		selected_buildings.clear()
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
			if add and _same_building_type(bid, selected_building):   # shift-click: add or drop one of the same type
				if selected_buildings.has(bid):
					selected_buildings.erase(bid)
					selected_building = _next_lead()
				else:
					selected_buildings[bid] = true
			else:
				selected_building = bid
				selected_buildings = {bid: true}
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


## Double-click: every unit of the clicked unit's type and owner that's on screen; on a
## building, every building of its type and owner on screen (finished ones with a finished one,
## foundations with a foundation), so a row of barracks can be told to train together.
func select_same_type_on_screen(pos: Vector2, add := false) -> void:
	var before := _building_group()
	select_at(pos, false)
	if selected_building != 0 and selected.is_empty():
		_select_same_buildings(before if add else [])
		return
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
				and screen.has_point(views[id].ground()):
			selected[id] = true


func _select_same_buildings(keep: Array) -> void:
	var bs := world.buildings
	var lead := selected_building
	var l := bs.index_of(lead)
	var screen := Rect2(camera.get_screen_center_position() - get_viewport_rect().size * 0.5 / camera.zoom,
		get_viewport_rect().size / camera.zoom)
	for id in keep:
		if _same_building_type(id, lead):
			selected_buildings[id] = true
	for j in bs.count():
		var id := bs.id[j]
		if bs.done[j] == bs.done[l] and _same_building_type(id, lead) and bviews.has(id) and bviews[id].visible \
				and screen.has_point(bviews[id].position):
			selected_buildings[id] = true


## Both buildings stand and have the same type and owner.
func _same_building_type(a: int, b: int) -> bool:
	var bs := world.buildings
	var i := bs.index_of(a)
	var j := bs.index_of(b)
	return i >= 0 and j >= 0 and bs.kind[i] == bs.kind[j] and bs.owner[i] == bs.owner[j]


## The lowest id among the selected buildings still standing (a new lead), or 0.
func _next_lead() -> int:
	var ids := selected_buildings.keys().filter(func(id): return world.buildings.index_of(id) >= 0)
	ids.sort()
	return ids[0] if not ids.is_empty() else 0


## The selected buildings still standing: the lead first, then the rest by id.
func _building_group() -> Array:
	if world.buildings.index_of(selected_building) < 0:
		return []
	var out := [selected_building]
	var ids := selected_buildings.keys()
	ids.sort()
	for id in ids:
		if id != selected_building and world.buildings.index_of(id) >= 0:
			out.append(id)
	return out


## What a building has to get through: its queue plus the train, research and age-up orders
## sent to it that haven't run yet (so a fast run of clicks still spreads).
func _queue_load(bid: int) -> int:
	var n: int = world.buildings.queue[world.buildings.index_of(bid)].size()
	for t in range(world.turn(), world.turn() + Commands.DELAY + 1):   # looked up by turn, never iterated
		for cmd in world.commands.pending.get(t, []):
			if cmd.type in [Commands.TRAIN, Commands.RESEARCH, Commands.AGE_UP] and cmd.args.building == bid:
				n += 1
	return n


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
	var out := []   # one list per owner: every player (four in a 2v2) and the animals' gaia
	for k in world.races.size() + 1:
		out.append([])
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


## Is this unit (by id) an animal (a sheep of ours, or a wild one)?
func _is_animal(id: int) -> bool:
	var i := world.units.index_of(id)
	return i >= 0 and world.types[world.units.kind[i]].has("animal")


## Is building `bid` a finished pen of player p's?
func _is_pen_of(bid: int, p: int) -> bool:
	var b := world.buildings.index_of(bid)
	return b >= 0 and world.buildings.owner[b] == p and world.buildings.done[b] == 1 and not world.btypes[world.buildings.kind[b]].pen.is_empty()


## A selected animal's card: what it is, its food, and what to do with it.
func _animal_info(t: Dictionary, owner: int) -> String:
	if owner == world.gaia and t.behaviour == "herd":
		return "%d food. Nobody's yet: walk one of yours up to it to claim it." % t.food
	if owner == world.gaia:
		return "%d food, wild. %s" % [t.food, "It bolts when hurt: hunt it with a few workers." if t.behaviour == "flee" else "It fights back: hunt it with a big party."]
	if owner != active:
		return "%d food, theirs. Walk one of yours up to it while none of theirs is near to steal it." % t.food
	return "%d food at once: workers slaughter it where it stands (right-click it).\nOr put it in a pen (right-click the pen) for a little food all the time." % t.food


## Right-click: rally for a selected building; for units gather a resource, help
## build your foundation, or move. Ignored while a replay plays.
func smart_order(pos: Vector2) -> void:
	if not playback.is_empty():
		return
	var m := Iso.pick(pos)
	var cell := map.cell_of(m.x, m.y)
	if selected_building != 0:
		var b := world.buildings.index_of(selected_building)
		if b >= 0 and world.buildings.owner[b] == active:
			for bid in _building_group():   # every selected building rallies there
				world.issue(active, Commands.RALLY, {"building": bid, "x": m.x, "y": m.y})
			if map.resource_at(cell) != "":   # the sim puts it in the middle of the resource's tile
				pos = Iso.to_ground((cell % map.width) * SimMap.TILE + SimMap.TILE / 2, (cell / map.width) * SimMap.TILE + SimMap.TILE / 2)
			flags.append({"pos": pos, "t": 1.0})
			audio.play("ui_click", -4.0)
		return
	var groups := _selected_by_owner()
	var bid: int = map.occupied[cell]
	var foe := unit_at(pos)
	var q := 1 if queueing else 0
	for p in groups.size():
		var ids: Array = groups[p].filter(func(id): return not _is_animal(id))
		var herd: Array = groups[p].filter(_is_animal)
		if not herd.is_empty() and bid != 0 and _is_pen_of(bid, p):
			world.issue(p, Commands.PEN, {"ids": herd, "building": bid})   # into our pen
		elif not herd.is_empty():   # our sheep only ever walk (they take no fighting or work orders)
			world.issue(p, Commands.MOVE, {"ids": herd, "x": m.x, "y": m.y, "queue": q})
		if ids.is_empty():
			continue
		if attack_move and land.bridge_at(cell) >= 0 and world.bridge_up[land.bridge_at(cell)] == 1 and foe == 0:
			world.issue(p, Commands.ATTACK, {"ids": ids, "target": world.bridge_id[land.bridge_at(cell)], "queue": q})   # attack-click a bridge: break it
		elif attack_move:
			world.issue(p, Commands.ATTACK_MOVE, {"ids": ids, "x": m.x, "y": m.y, "queue": q})
		elif foe != 0 and world.is_enemy(world.units.owner[world.units.index_of(foe)], p):
			world.issue(p, Commands.ATTACK, {"ids": ids, "target": foe, "queue": q})   # an enemy, or an animal to hunt
		elif foe != 0 and world.units.owner[world.units.index_of(foe)] == p and _is_animal(foe) and not _selected_workers().is_empty():
			world.issue(p, Commands.ATTACK, {"ids": ids, "target": foe, "queue": q})   # slaughter one of our sheep for its food
		elif bid != 0 and world.is_enemy(world.buildings.owner[world.buildings.index_of(bid)], p) and bviews.has(bid) and bviews[bid].visible:
			world.issue(p, Commands.ATTACK, {"ids": ids, "target": bid, "queue": q})
		elif map.resource_at(cell) != "":
			world.issue(p, Commands.GATHER, {"ids": ids, "cell": cell, "queue": q})
		elif land.bridge_at(cell) >= 0 and world.bridge_up[land.bridge_at(cell)] == 0 and not _selected_workers().is_empty():
			world.issue(p, Commands.HELP_BUILD, {"ids": ids, "target": world.bridge_id[land.bridge_at(cell)], "queue": q})   # rebuild a broken bridge
		elif foe != 0 and not _selected_workers().is_empty() and Repair.can_mend(world, p, foe):
			world.issue(p, Commands.REPAIR, {"ids": ids, "target": foe, "queue": q})   # mend our siege engine
		elif bid == 0 and not _selected_workers().is_empty() and not Walls.rebuild_of(world, p, cell).is_empty():
			var r := Walls.rebuild_of(world, p, cell)   # wall up our breach again
			world.issue(p, Commands.BUILD, {"ids": ids, "building": r.building, "cx": r.cx, "cy": r.cy, "along": r.along, "queue": q})
		elif bid != 0 and not _selected_workers().is_empty() and Repair.can_mend(world, p, bid):
			world.issue(p, Commands.REPAIR, {"ids": ids, "target": bid, "queue": q})   # mend our damaged building
		elif bid != 0 and Walls.places(world, cell) > 0 and world.teams[world.buildings.owner[world.buildings.index_of(bid)]] == world.teams[p] \
				and _selected_workers().is_empty():
			world.issue(p, Commands.MOVE, {"ids": ids, "x": m.x, "y": m.y, "queue": q})   # up onto our wall (walls.gd: those who can't climb walk to it)
		elif bid != 0 and _is_foundation_of(bid, p):
			world.issue(p, Commands.HELP_BUILD, {"ids": ids, "target": bid, "queue": q})
		elif bid != 0 and _trade_market(bid, p, ids):
			world.issue(p, Commands.ROUTE, {"ids": ids, "building": bid})   # trade carts: trade with that market (trade.gd)
		elif bid != 0 and _drop_off_kind(bid, p, ids) != "":
			world.issue(p, Commands.DROP_OFF, {"ids": ids, "building": bid, "queue": q})   # take what they carry in
		elif bid != 0 and map.pool[cell] >= 0 and world.buildings.owner[world.buildings.index_of(bid)] == p:
			world.issue(p, Commands.RESEED, {"ids": ids, "building": bid})   # a fallow farm of ours
		elif bid != 0 and _can_garrison(bid, p, ids):
			world.issue(p, Commands.GARRISON, {"ids": ids, "building": bid, "queue": q})   # inside our Town Center or tower
		else:
			world.issue(p, Commands.MOVE, {"ids": ids, "x": m.x, "y": m.y, "queue": q})
	flags.append({"pos": pos, "t": 1.0})
	if q == 1:
		order_marks.flash(groups[active])   # the route shows a while, so you see where it went in the queue
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
		var g: Vector2 = v.ground()
		var r := Rect2(g.x - half_w - slack, g.y - tall - slack, (half_w + slack) * 2.0, tall + slack * 2.0 + 3.0)
		if not r.has_point(pos):
			continue
		var d := _body(v).distance_to(pos)
		if d < best_d or (d == best_d and id < best):
			best_d = d
			best = id
	return best


## Play the sim's hits and deaths as effects: attackers lunge at their target,
## shooters loose a shot that flies as long as the sim's does and lands as a hit or in the
## ground, the struck spark; the dead topple (their view leaves the live set, so the usual
## sync won't just delete it); fallen buildings raise dust.
func _play_events() -> void:
	for e in clock.take_events():
		if e.type == "shot":
			_shot(e)
			continue
		if e.type == "splash":   # a catapult's stone comes down: dirt flies over the whole area
			if reveal or Fog.visible(world, active, e.x, e.y):
				var at := Iso.to_ground(e.x, e.y)
				fx.splash(at, float(e.r) * Iso.RADIUS_PX)
				if _on_screen(at):
					audio.play("catapult_impact", -2.0)
			continue
		if e.type == "blast":   # a sapper's charge goes off (combat.gd _blast): dirt and a bang
			if reveal or Fog.visible(world, active, e.x, e.y):
				var at := Iso.to_ground(e.x, e.y)
				fx.splash(at, float(e.r) * Iso.RADIUS_PX)
				if _on_screen(at):
					audio.play("blast")
			continue
		if e.type == "trade":   # a trade cart of ours home with its gold (trade.gd)
			if e.has("paid") and _owner_of(e.id) == active:
				audio.play("trade_paid", -6.0)
			continue
		if e.type == "pour":   # the defenders' tools (hot oil, scalding cheese...): a burst at the gate's foot
			if reveal or Fog.visible(world, active, e.x, e.y):
				var at := Iso.to_ground(e.x, e.y)
				fx.splash(at, 1.4 * SimMap.TILE * Iso.RADIUS_PX)
				if _on_screen(at):
					audio.play("hit_blunt", -4.0)
			continue
		if e.type == "miss" or (e.type == "hit" and e.has("x")):
			_landed(e)   # a shot in flight came down
			continue
		if e.type == "hit":
			var a: Node2D = views.get(e.by)
			var to := _event_target_pos(e.to)
			if to != Vector2.INF:
				_maybe_alert(e, to)
			if a == null or to == Vector2.INF:
				continue
			a.face_vec(to - a.position)
			var lands := 0.0
			if e.ranged:
				var i := world.units.index_of(e.by)
				var kind := "arrow"
				var look := ""
				if i >= 0:
					kind = CombatFx.shot_kind(world.types[world.units.kind[i]].eval.tags)
					look = CombatFx.shot_look(lib, world.types[world.units.kind[i]].recipe)
				lands = fx.shoot(_body(a) - Vector2(0, 2), to, kind, -1.0, look)
				a.loose()
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
					audio.play(CombatFx.shot_sound(CombatFx.shot_kind(tags)), -4.0)
					audio.play_in("arrow_land", lands, -8.0)
				else:
					audio.play(_blow_sound(tags))
				var side_a := world.units.owner[i] if i >= 0 else -1
				if side_a == active or _owner_of(e.to) == active:
					battle_until = world.tick / float(World.TICK_HZ) + 8.0
		elif e.type == "garrison" or e.type == "ungarrison":
			var gb: BuildingArt = bviews.get(e.building)
			if gb != null:
				gb.door_pulse()   # the door opens for them
			if e.type == "garrison":
				sheltered[e.id] = true
				selected.erase(e.id)
		elif e.type == "upgraded" and e.player == active:
			audio.play("built", -4.0)
		elif e.type == "heal":
			var healer: Node2D = views.get(e.by)
			var patient: Node2D = views.get(e.to)
			if patient == null:
				continue
			if healer != null:
				healer.face_vec(patient.position - healer.position)
			fx.heal(patient)
			if _on_screen(patient.position) and patient.visible:
				audio.play("heal", -6.0)
		elif e.type == "age":
			age_ups.append([e.player, e.age, world.tick / 20])
			if e.player == active:
				audio.play("age")
				audio.music_age(e.age)
		elif e.type == "research":
			if e.player == active:
				audio.play("research", -4.0)
		elif e.type == "farm_done":
			if e.player == active:   # one of our farms is worked out: a sound wherever it is, and a line
				audio.play("farm_done", -4.0)
				var fighting := alert_label != null and alert_label.visible and alert_label.text.begins_with("Under attack")
				if e.reseeded and not fighting:
					_show_line("Farm worked out: reseeded", Color("#e8d27a"))
				elif not e.reseeded and not fighting:
					alert_at = Iso.to_ground(e.x, e.y)
					_show_line("Farm worked out: its farmer waits  (Space to look)", Color("#e8d27a"))
		elif e.type == "wonder":   # a Wonder finished or fallen: everyone hears, wherever it is
			var who: String = WonderClock.possessive(world.races[e.player].name)
			var held: int = Match.hold_ticks(world) / World.TICK_HZ
			if e.x >= 0:
				alert_at = Iso.to_screen(e.x, e.y)
				var m := Vector2(e.x / 1000.0, e.y / 1000.0)
				minimap.ping(m)
			if e.what == "built":
				audio.play("age")
				_show_line("%s Wonder is finished! It wins in %d:%02d unless it falls.  (Space to look)" % [who, held / 60, held % 60],
					Color("#f2c94c"))
			else:
				audio.play("building_fall")
				_show_line("%s Wonder has fallen!" % who, Color("#ff8a70"))
		elif e.type == "won":
			var mine: bool = world.teams[active] == e.team
			audio.play("won" if mine else "lost")
			audio.music("off")
			audio.ambience(false)
			_log_match(e.team)
			banner.text = ("Victory!" if mine else "Defeat") + "\n" + ("%s win" % world.races[_first_of_team(e.team)].name) + (" (their Wonder stood)" if e.has("wonder") else "")
			banner.add_theme_color_override("font_color", Color("#f2c94c") if mine else Color("#e07060"))
			banner.visible = true
			if vs_ai:
				_show_pause_menu(true)   # the match is over: back to the lobby from here
		elif e.type == "hero_up" and e.player == active:   # our hero takes the field, or comes back (sim/heroes.gd)
			audio.play("hero_up", -3.0)
			_show_line("%s %s" % [world.types[e.kind].name, "is back!" if e.revived else "takes the field!"], HERO_GOLD)
		elif e.type == "hero_fell" and e.player == active:   # our hero falls, wherever it is
			audio.play("hero_fell", -2.0)
			_show_line("%s has fallen. Revive at the Town Center in %d s" % [world.types[e.kind].name, int(world.hero_cfg.revive) / 20], Color("#ff8a70"))
		elif e.type == "die" and not e.building:
			var v: Node2D = views.get(e.id)
			if v != null and v.visible and e.kind >= 0 and world.types[e.kind].get("hero", false) and world.teams[e.owner] != world.teams[active]:
				audio.play("hero_fell", -6.0)   # a foe's hero falls where we see it
				_show_line("The enemy's %s has fallen!" % world.types[e.kind].name, HERO_GOLD)
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
				selected_buildings.erase(e.id)
				if selected_building == e.id:
					selected_building = _next_lead()
				var mem = null if reveal else world.fog_seen[active].get(e.id)
				if mem != null and not Fog.sees_area(world, active, mem[2], mem[3], mem[4], mem[8], mem[9]):
					ghosts[e.id] = bv   # it fell where you can't see: you still see it standing
					continue
				var t: Dictionary = world.btypes[e.kind]
				fx.collapse(bv, Iso.to_ground(e.x, e.y), int(t.length))
				if bv.visible and _on_screen(bv.position):
					audio.play("building_fall", -2.0)


## Where a shot or blow lands on a unit (its body) or a building (its middle).
## A watchtower's shot: an arrow from near its top, the target flashing when it lands.
## A shot loosed (the sim's "shot" event): it flies from the shooter (a unit, or along the top
## of a tower, a volley spread out) to the spot the sim aimed at, body high, for the sim's
## flight; its landing comes as a "hit" or a "miss" (_landed).
func _shot(e: Dictionary) -> void:
	var tower: BuildingArt = bviews.get(e.by)
	var a: Node2D = views.get(e.by)
	var to := _event_target_pos(e.to) if world.buildings.index_of(e.to) >= 0 else Iso.to_ground(e.x, e.y) - Vector2(0, BODY_LIFT)
	if to == Vector2.INF:
		return
	var kind := "arrow"
	var look := ""   # a siege engine's baked shot (data/siege_shots.json)
	var from: Vector2
	var seen := false
	if tower != null:
		var k: int = e.get("arrow", 0)
		var spread := Vector2(((k * 5) % 7 - 3) * 2.0, ((k * 3) % 5 - 2) * 1.5)
		from = tower.loose_at() + spread
		to += spread * 0.5
		seen = tower.visible
	elif a != null:
		var i := world.units.index_of(e.by)
		if i >= 0:
			kind = CombatFx.shot_kind(world.types[world.units.kind[i]].eval.tags)
			look = CombatFx.shot_look(lib, world.types[world.units.kind[i]].recipe)
		from = _body(a) - Vector2(0, 2)
		a.face_vec(to - a.position)
		a.loose()
		seen = a.visible
	else:
		return
	shot_kinds[e.by] = kind
	fx.shoot(from, to, kind, e.ticks * SimClock.STEP / maxf(clock.speed, 0.01), look)
	if _on_screen(from) and seen:
		audio.play(CombatFx.shot_sound(kind), -4.0)
		if _owner_of(e.by) == active or _owner_of(e.to) == active:
			battle_until = world.tick / float(World.TICK_HZ) + 8.0


## A shot came down: on its target (it flashes; the alarm if it's ours), or in the ground,
## where it sticks for a while.
func _landed(e: Dictionary) -> void:
	var spot := Iso.to_ground(e.x, e.y)
	var seen: bool = reveal or Fog.visible(world, active, e.x, e.y)
	if e.type == "miss":
		if seen:
			fx.stick(spot, shot_kinds.get(e.by, "arrow"))
			if _on_screen(spot):
				audio.play("arrow_land", -12.0)
		return
	var to := _event_target_pos(e.to)
	if to != Vector2.INF:
		_maybe_alert(e, to)
	var target: Node2D = views.get(e.to)
	if target != null:
		fx.flash(target)
	if seen and _on_screen(spot) and not e.get("splash", false):   # (a stone's or a blast's victims: its one sound was played)
		audio.play("arrow_land", -8.0)


func _event_target_pos(id: int) -> Vector2:
	var v: Node2D = views.get(id)
	if v != null:
		return _body(v)
	var b := world.buildings.index_of(id)
	if b >= 0:
		var bs := world.buildings
		return Iso.to_ground((bs.cx[b] + bs.sx[b] * 0.5) * 1000, (bs.cy[b] + bs.sy[b] * 0.5) * 1000) - Vector2(0, 20)
	return land.target_pos(id)   # a map bridge, or nothing


## Can any of these units of p's go inside building `bid` (p's, finished, with room)?
func _can_garrison(bid: int, p: int, ids: Array) -> bool:
	var b := world.buildings.index_of(bid)
	if b < 0 or world.buildings.owner[b] != p or Garrison.room(world, b) <= 0:
		return false
	return ids.any(func(id):
		var i := world.units.index_of(id)
		return i >= 0 and Garrison.can_hold(world, b, i))


## Is `bid` a finished market of p's or an ally's, and are trade carts among these units? (A
## right-click sends them trading with it: trade.gd picks their home market.)
func _trade_market(bid: int, p: int, ids: Array) -> bool:
	var b := world.buildings.index_of(bid)
	if b < 0 or world.buildings.done[b] == 0 or world.is_enemy(world.buildings.owner[b], p) \
			or world.btypes[world.buildings.kind[b]].id != "market":
		return false
	return ids.any(func(id):
		var i := world.units.index_of(id)
		return i >= 0 and world.types[world.units.kind[i]].get("trader", false))


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
	var m := Iso.pick(pos)
	var groups := _selected_by_owner()
	for p in groups.size():
		if not groups[p].is_empty():
			world.issue(p, Commands.MOVE, {"ids": groups[p], "x": m.x, "y": m.y})
	flags.append({"pos": pos, "t": 1.0})


## The pause menu's UI size button: a step larger, and from the largest back to the smallest.
func _ui_size_cycle() -> void:
	if UiScale.size_pct() >= UiScale.SIZE_MAX:
		while UiScale.size_pct() > UiScale.SIZE_MIN:
			UiScale.step(-1)
	else:
		UiScale.step(1)
	_fit_hud()
	var b: Button = pause_menu.get_node_or_null("card/box/ui")
	if b != null:
		b.text = "UI size: %d%%  (larger)" % UiScale.size_pct()


## Esc against the AI: the game pauses under a small menu.
func _toggle_pause_menu() -> void:
	_show_pause_menu(pause_menu == null or not pause_menu.visible)


func _show_pause_menu(on: bool) -> void:
	if pause_menu == null:
		pause_menu = _make_pause_menu()
		banner.get_parent().add_child(pause_menu)
		PadMode.of(get_tree()).menus.append(pause_menu)   # a pad walks it by focus
	var over: bool = world.winner >= 0
	pause_menu.visible = on
	pause_menu.get_node("card").visible = true
	if saves_page != null:
		saves_page.visible = false
	var box: Control = pause_menu.get_node("card/box")
	box.get_node("resume").visible = not over
	box.get_node("surrender").visible = not over
	box.get_node("tree").visible = not over
	box.get_node("save").visible = not over and playback.is_empty()
	box.get_node("save").text = "Save game"
	var back: Button = box.get_node("menu")   # when it's over, the way back is the call to action
	pause_menu.set_meta("pad_first", back if over else box.get_node("resume"))   # where a pad's focus starts
	back.theme_type_variation = "PrimaryButton" if over else ""
	back.custom_minimum_size.y = 64 if over else 50
	back.add_theme_font_size_override("font_size", 26 if over else 19)
	var title: Label = box.get_node("title")
	var sub: Label = box.get_node("sub")
	if over:
		var won: bool = world.teams[active] == world.winner
		banner.visible = false   # the result is the menu's title (it collided with the menu)
		title.text = "Victory" if won else "Defeat"
		title.add_theme_color_override("font_color", Color("#f6d77a") if won else Color("#e88070"))
		title.add_theme_font_size_override("font_size", 72)
		var secs := world.tick / World.TICK_HZ
		var story := "%s win.\n%d:%02d of battle, %s reached age %d." % [world.races[_first_of_team(world.winner)].name, secs / 60, secs % 60,
			world.races[active].name, world.ages[active]]
		if won and vs_ai and ai_level != "hard":
			story += "\nBeat %s? Try %s next." % [ai_level.capitalize(), "Normal" if ai_level == "easy" else "Hard"]   # so testers know the step up exists
		sub.text = story
	else:
		title.text = "Paused"
		title.remove_theme_color_override("font_color")
		title.add_theme_font_size_override("font_size", 52)
		sub.text = "%s  ·  %s" % [world.races[active].name, map.id.capitalize()]
	clock.paused = on and not over
	if on:
		UiTheme.arrive(pause_menu.get_node("card"), 10.0)
		audio.play("ui_tip")


## The pause menu's Save game: saved at once, the button says so.
func _save_from_menu() -> void:
	save_game()
	var secs := world.tick / World.TICK_HZ
	pause_menu.get_node("card/box/save").text = "Saved  (%d:%02d in)" % [secs / 60, secs % 60]
	audio.play("ui_tip")


## The pause menu's Load game: the saved matches over it; picking one leaves this match for it.
func _open_saves() -> void:
	if saves_page == null:
		saves_page = SavesPage.new(lib, UiTheme.look(hud_family).metal)
		pause_menu.get_parent().add_child(saves_page)
		PadMode.of(get_tree()).menus.append(saves_page)   # over the pause menu, so a pad's focus goes here
		saves_page.chosen.connect(load_game)
		saves_page.closed.connect(_saves_closed)
	pause_menu.get_node("card").visible = false   # the menu stays up under it (the match stays paused)
	saves_page.open()


func _saves_closed() -> void:
	pause_menu.get_node("card").visible = true
	if PadMode.of(get_tree()).on:
		(pause_menu.get_meta("pad_first") as Control).grab_focus()


## Surrender asks once more: the first click turns the button into "Click again to give up".
func _confirm_surrender() -> void:
	var b: Button = pause_menu.get_node("card/box/surrender")
	if b.text == "Surrender":
		b.text = "Click again to give up"
		return
	b.text = "Surrender"
	world.issue(active, Commands.SURRENDER, {})
	_show_pause_menu(false)


## The pause menu (and, when the match is over, the end screen): a framed card in your race's
## culture over the darkened battle, the title in the display face, buttons with weight.
func _make_pause_menu() -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.name = "card"
	card.theme_type_variation = "CrestFrame"
	card.custom_minimum_size = Vector2(420, 0)
	card.set_anchors_preset(Control.PRESET_CENTER)   # centred at any HUD size
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	shade.add_child(card)
	var box := VBoxContainer.new()
	box.name = "box"
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	box.add_child(gap)
	var title := UiTheme.label("", "Title")
	title.name = "title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UiTheme.label("", "Dim", true)
	sub.name = "sub"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 17)
	box.add_child(sub)
	box.add_child(UiTheme.Rule.new(UiTheme.look(hud_family).metal))
	for item in [["resume", "Resume", func(): _show_pause_menu(false)],
			["music", "Music: on", func(): _toggle_music()],
			["ui", "UI size: %d%%  (larger)" % UiScale.size_pct(), func(): _ui_size_cycle()],
			["save", "Save game", func(): _save_from_menu()],
			["load", "Load game", func(): _open_saves()],
			["tree", "Tech tree", func(): _show_pause_menu(false); toggle_tech_tree()],
			["surrender", "Surrender", func(): _confirm_surrender()],
			["menu", "Back to the menu", func(): get_tree().paused = false; get_tree().change_scene_to_file("res://scenes/match_setup.tscn")]]:
		var b := UiTheme.button(item[1], item[0] == "resume")
		b.name = item[0]
		b.custom_minimum_size = Vector2(380, 64 if item[0] == "resume" else 50)
		b.add_theme_font_size_override("font_size", 28 if item[0] == "resume" else 19)
		b.pressed.connect(item[2])
		box.add_child(b)
	return shade


## Shift held (the pad: LB): five at a time.
func _many() -> bool:
	return Input.is_key_pressed(KEY_SHIFT) or (PadMode.of(get_tree()).on and PadMode.of(get_tree()).held(JOY_BUTTON_LEFT_SHOULDER))


## Train one (five with shift held, as far as the queue has room).
func _train(building: int, slot: String) -> void:
	for k in (5 if _many() else 1):
		world.issue(active, Commands.TRAIN, {"building": building, "slot": slot})


## Train one (five with shift) from the selected buildings: each goes to the least busy
## finished one with room (the lowest id on a tie), so pressing Train again and again spreads
## the units over every selected barracks.
## The Town Center's hero buttons (D-138): one per hero of the race, each trained once; one that's out,
## on the way, or waiting to be revived says so; a revival shows its (lower) price.
func _hero_buttons(c: Dictionary, room: bool) -> void:
	for hk in SimHeroes.types_of(world, active):
		var wt: Dictionary = world.types[hk]
		var cost: PackedInt32Array = SimHeroes.cost(world, active, hk)
		var why := SimHeroes.why_not(world, active, hk)
		var ok_age: bool = world.ages[active] >= int(wt.line[0].age)
		var revive: bool = world.hero_fell[hk] != 0
		var verb := "Revive" if revive else "Train"
		var text := "%s %s (%s)" % [verb, wt.name, _cost_text(cost)]
		if not ok_age:
			text = "%s: needs age %d" % [wt.name, wt.line[0].age]
		elif why != "":
			text = "%s: %s" % [wt.name, why]
		var sid: String = wt.recipe.hero
		c.buttons.append({"icon": kit.icons.get("%d:%s" % [active, HeroLine.line_key(wt.recipe)]), "text": text,
			"tip": _unit_tip(wt), "group": "Heroes", "key": "", "cost": _cost_text(cost),
			"enabled": ok_age and why == "" and world.can_afford(active, cost) and room,
			"action": func(): world.issue(active, Commands.TRAIN, {"building": selected_building, "slot": "hero", "hero": sid})})


func _train_group(slot: String) -> void:
	var group := _building_group().filter(func(id):
		var i := world.buildings.index_of(id)
		return world.buildings.owner[i] == active and world.buildings.done[i] == 1)
	for k in (5 if _many() else 1):
		var best := 0
		var least := int(world.econ.queue_max)
		for id in group:
			var busy := _queue_load(id)
			if busy < least:
				best = id
				least = busy
		if best == 0:
			return
		world.issue(active, Commands.TRAIN, {"building": best, "slot": slot})


func train_worker() -> void:
	var b := world.buildings.index_of(selected_building)
	if b < 0 or world.buildings.owner[b] != active or not playback.is_empty():
		return
	_train_group("worker")


func start_placing(building: String) -> void:
	if not _selected_workers().is_empty() and playback.is_empty():
		placing = building


## Does the ghost read as placeable, judged only by what the side you command knows? Ground
## never seen tells nothing (whatever stands there stays hidden: the ghost reads fine), and an
## enemy building you haven't seen doesn't block it. The sim still refuses a foundation that
## can't go there.
func _ghost_ok(k: int, cx: int, cy: int, along: int) -> bool:
	var truth := Economy.can_place(world, active, k, cx, cy, along)
	if truth or reveal:
		return truth
	var t: Dictionary = world.btypes[k]
	var d := Economy.dims(t, along)
	var mc := Economy.builder_class(world, active)
	var fog: PackedByteArray = world.fog[active]
	if cx < 0 or cy < 0 or cx + d.x > map.width or cy + d.y > map.height:
		return false
	for c in Economy._footprint(world, cx, cy, d, along):
		var x: int = c % map.width
		var y: int = c / map.width
		if fog[c] == Fog.UNSEEN or map.can_build(x, y, 1, mc, t.water) or Economy._replaceable(world, active, t, c):
			continue
		var b := world.buildings.index_of(map.occupied[c])
		if b >= 0 and world.is_enemy(active, world.buildings.owner[b]) and fog[c] != Fog.VISIBLE \
				and not world.fog_seen[active].has(world.buildings.id[b]):
			continue   # built since you last looked
		return false
	return true


## Top-left cell of the footprint the ghost shows at a canvas point (centred on the cursor).
func _ghost_cell(pos: Vector2) -> Vector2i:
	var m := Iso.pick(pos)
	var d := Economy.dims(world.btypes[Economy.btype_of(world, placing)], _ghost_along(pos))
	return Vector2i(floori(m.x / 1000.0) - (d.x - 1) / 2, floori(m.y / 1000.0) - (d.y - 1) / 2)


## Which way a gate being placed runs: along the wall under the cursor (walls or gates beside
## it along sim x, or else along sim y; with neither, corner to corner on one diagonal or the
## other), else the way R last turned it. 0 for other buildings.
func _ghost_along(pos: Vector2) -> int:
	var t: Dictionary = world.btypes[Economy.btype_of(world, placing)]
	if not t.gate:
		return 0
	var m := Iso.pick(pos)
	var c := Vector2i(floori(m.x / 1000.0), floori(m.y / 1000.0))
	var along_x := _walled(c + Vector2i(-1, 0)) or _walled(c + Vector2i(1, 0))
	var along_y := _walled(c + Vector2i(0, -1)) or _walled(c + Vector2i(0, 1))
	if along_x != along_y:
		return 0 if along_x else 1
	if not along_x:
		var down := _walled(c + Vector2i(-1, -1)) or _walled(c + Vector2i(1, 1))   # along 2: x and y grow together
		var across := _walled(c + Vector2i(1, -1)) or _walled(c + Vector2i(-1, 1))   # along 3
		if down != across:
			return 2 if down else 3
	return gate_along


## The way building slot b runs, as Economy.dims' `along` (0 for all but gates along y or a diagonal).
func _along_of(b: int) -> int:
	var bs := world.buildings
	if bs.diag[b] != 0:
		return bs.diag[b] + 1
	return 1 if bs.sy[b] > bs.sx[b] else 0


## The ground outlines of building slot b's footprint, as canvas quads: one for a rect, one per
## cell for a diagonal gate (its cells meet at their corners).
func _footprint_quads(cx: int, cy: int, sx: int, sy: int, diag: int) -> Array:
	var out := []
	var tops := [Vector2i(cx, cy)]
	if diag != 0:   # (as Buildings.cells, by coordinates: a ghost may hang off the map's edge)
		tops = range(sy).map(func(k): return Vector2i(cx + (k if diag == 1 else sx - 1 - k), cy + k))
	for t in tops:
		var x0: int = t.x * 1000
		var y0: int = t.y * 1000
		var w: int = 1000 if diag != 0 else sx * 1000
		var h: int = 1000 if diag != 0 else sy * 1000
		var up := Vector2(0, Iso.lift(x0 + w / 2, y0 + h / 2))   # on a hill, on its top
		out.append(PackedVector2Array([Iso.to_screen(x0, y0) - up, Iso.to_screen(x0 + w, y0) - up, Iso.to_screen(x0 + w, y0 + h) - up,
			Iso.to_screen(x0, y0 + h) - up]))
	return out


## Does a wall or gate stand on this cell?
func _walled(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= map.width or c.y >= map.height:
		return false
	var b := world.buildings.index_of(map.occupied[c.y * map.width + c.x])
	return b >= 0 and _wall_like(b)


## Is building slot b part of a wall line (a wall tile or a gate)?
func _wall_like(b: int) -> bool:
	var t: Dictionary = world.btypes[world.buildings.kind[b]]
	return t.line or t.gate or t.joins


func place_at(pos: Vector2, keep := false) -> void:
	var c := _ghost_cell(pos)
	var workers := _selected_workers()
	if workers.is_empty():
		placing = ""
		return
	# Shift both keeps placing and queues: shift-place two houses and a worker builds both in turn.
	var a := {"ids": workers, "building": placing, "cx": c.x, "cy": c.y, "queue": 1 if keep else 0}
	if world.btypes[Economy.btype_of(world, placing)].gate:
		a.along = _ghost_along(pos)
	world.issue(active, Commands.BUILD, a)
	if keep:
		order_marks.flash(workers)
	if not keep:
		placing = ""


## Is this building type laid in lines by dragging (walls and gates: data "line")?
func _line(building: String) -> bool:
	return world.btypes[Economy.btype_of(world, building)].line


## A line of what's being placed (a wall or gate) from one cell to another (straight or
## diagonal, the cells a line through them crosses), one foundation per cell; the workers build
## them in order. Gates dragged along a wall take the place of its tiles.
func place_wall(a: Vector2i, b: Vector2i, keep := false) -> void:
	var workers := _selected_workers()
	if workers.is_empty():
		placing = ""
		return
	var cells := wall_cells(a, b)
	for k in cells.size():
		world.issue(active, Commands.BUILD, {"ids": workers, "building": placing, "cx": cells[k].x, "cy": cells[k].y,
			"queue": 1 if keep or k > 0 else 0})
	order_marks.flash(workers)
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
	panel.keep_left_of(minimap.position.x - 24)   # wide panels (soldiers with stances) wrap rather than run under the minimap
	audio.battle(world.tick / float(World.TICK_HZ) < battle_until)
	_sync_views()
	_sync_buildings()
	_sync_resources()
	land.sync()
	town.update(delta)
	_sync_rally()
	order_marks.update()
	_sync_fog()
	_check_replay()
	for f in flags:
		f.t -= delta
	flags = flags.filter(func(f): return f.t > 0.0)
	marks.queue_redraw()
	overlay.queue_redraw()
	_update_top_bar()
	wonder_clock.show_for(world, lib.palettes.teams)
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
		rally_flag.set_meta("offset_y", rally_flag.offset.y)   # raised on a hill from here
		layer.add_child(rally_flag)
	if rally_flag != null:
		rally_flag.visible = show
		if show:
			rally_flag.position = Iso.to_screen(world.buildings.rally_x[b], world.buildings.rally_y[b])
			rally_flag.offset.y = rally_flag.get_meta("offset_y") - Iso.lift(world.buildings.rally_x[b], world.buildings.rally_y[b]) / rally_flag.scale.y
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
	if "ram" in tags:
		return "ram_hit"   # the log on the wall, the frame creaking (tools/audio/sfx.py)
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
	var b: Button = pause_menu.get_node_or_null("card/box/music") if pause_menu != null else null
	if b != null:
		b.text = "Music: on" if on else "Music: off"


func _sync_views() -> void:
	var u := world.units
	var a := clock.alpha
	var alive := {}
	var shown := _shown_rect(160.0)
	for i in u.count():
		var id := u.id[i]
		alive[id] = true
		var view: UnitView = views.get(id)
		if view != null and (view.get_meta("version", 0) != int(world.types[u.kind[i]].get("version", 0)) or view.get_meta("owner", -1) != u.owner[i]):
			view.queue_free()   # its type moved on (an age-up), or it changed hands (a claimed sheep)
			view = null
		if view == null:
			if not views.has(id) and u.owner[i] == active and world.tick > 40 and not sheltered.has(id):
				audio.play("trained", -6.0)   # a new unit of yours (not one restyled by an age-up, nor one out of shelter)
			sheltered.erase(id)
			view = _make_view(u.kind[i], u.owner[i])
			view.set_meta("version", int(world.types[u.kind[i]].get("version", 0)))
			view.set_meta("owner", u.owner[i])
			views[id] = view
		var dx := u.x[i] - u.px[i]
		var dy := u.y[i] - u.py[i]
		view.position = Iso.to_screen(u.px[i] + dx * a, u.py[i] + dy * a)
		var perch_dy := _perch_sort(i, view.position.y)   # up on a wall: sorted between the wall and its near merlons
		view.position.y += perch_dy
		view.lift = Iso.lift(u.px[i] + dx * a, u.py[i] + dy * a) + _wall_lift(i) + perch_dy   # on a hill (or a wall): drawn raised, sorted on the base plane
		view.walking = dx != 0 or dy != 0
		if int(world.types[u.kind[i]].unpack) > 0:   # the great sling: on its wagon until it's set up (D-129)
			view.set_packed(u.ready[i] < int(world.types[u.kind[i]].unpack))
		# Off screen (or hidden by the fog): no animation, tool or facing work; picked up again
		# the frame it comes into view.
		var on := view.visible and shown.has_point(view.position)
		if view.is_processing() != on:
			view.set_process(on)
			view.struck = false   # (a blow lands only in its own _process)
		if not on:
			continue
		if view.struck and WORK_SOUND.has(view.job) and u.owner[i] == active:
			_sfx_at(WORK_SOUND[view.job], view.position, -8.0)   # the blow you see lands: chop, clink, knock, rustle
		view.job = town.job_for(i, _job(i))
		if world.types[u.kind[i]].worker:
			view.set_tool(lib, town.tool_for(i, _tool_for(i)))
		if _job(i) != "":
			# At work: face what it's working on, whichever of the 8 ways that is (a nudge from
			# the crowd round a mine mustn't turn it, nor a target straight up or down the screen).
			var at := _work_point(i)
			if at.distance_to(view.position) > 2.0:
				view.face_vec(at - view.position)
		elif absi(dx) + absi(dy) > 4:
			view.face_vec(Iso.to_screen(dx, dy))   # the way it walks, on screen (8 facings)
	for id in views.keys():
		if not alive.has(id):
			views[id].queue_free()
			views.erase(id)
			selected.erase(id)


## How far up a wall unit i is drawn (walls.gd): the walkway's height on it, part of it while it
## climbs up or down.
func _wall_lift(i: int) -> float:
	var u := world.units
	var climb := float(world.walk_cfg.climb)
	if u.perch[i] != 0:
		var bv := _perch_view(i)
		var at := Vector2(u.x[i], u.y[i]) / 1000.0
		var top := bv.walk_at(at) if bv != null and bv.walk_px > 0.0 else WALL_PX   # the piece's own walkway: a tower's (and a gatehouse's towers') stand taller
		return top * (float(u.wtime[i]) / climb if u.wtime[i] > 0 else 1.0)
	if u.task[i] == Economy.CLIMB and u.work[i] > 0:
		return WALL_PX * minf(1.0, float(u.work[i]) / climb)
	return 0.0


## The view of the wall piece unit i stands on (null if it isn't up on one, or it isn't drawn).
func _perch_view(i: int) -> BuildingArt:
	if world.units.perch[i] == 0:
		return null
	return bviews.get(map.occupied[world.units.perch[i] - 1])


## How far to move unit i's sort point (canvas y at screen y `y`) so a unit up on a wall sorts just
## after the piece it stands on and before that piece's near merlons (BuildingArt front): drawn on the
## stone, between the merlons. Units on one piece keep their order among themselves. 0 off a wall.
func _perch_sort(i: int, y: float) -> float:
	var bv := _perch_view(i)
	if bv == null or bv.front == null:
		return 0.0
	return bv.perch_sort_at(Vector2(world.units.x[i], world.units.y[i]) / 1000.0, y) - y


## The part of the canvas on screen, grown by `margin` canvas pixels (a body standing just off
## the edge still shows its head).
func _shown_rect(margin: float) -> Rect2:
	var half: Vector2 = get_viewport_rect().size / camera.zoom * 0.5
	return Rect2(camera.get_screen_center_position() - half, half * 2.0).grow(margin)


const WORK_SOUND := {"chop": "chop", "mine": "mine", "build": "build", "forage": "forage", "till": "forage"}


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
	return Iso.to_screen((bs.cx[b] * 2 + bs.sx[b]) * 500, (bs.cy[b] * 2 + bs.sy[b]) * 500)


## Fog of war for the side you command: the overlay, enemy units only where you see now,
## enemy buildings as you last saw them (fog.gd remembers them), and none you never saw.
func _sync_fog() -> void:
	fog_view.visible = not reveal
	fog_view.refresh(world, active)
	minimap.player = active
	minimap.reveal = reveal
	var u := world.units
	for i in u.count():
		var v: Node2D = views.get(u.id[i])
		if v != null:
			v.visible = reveal or not world.is_enemy(active, u.owner[i]) or Fog.visible(world, active, u.x[i], u.y[i])
	var bs := world.buildings
	for b in bs.count():
		var bv: Node2D = bviews.get(bs.id[b])
		if bv != null:
			bv.visible = _memory(b) != null or reveal or not world.is_enemy(active, bs.owner[b])
	for id in ghosts.keys():   # an enemy building gone where you couldn't see: there until you look
		if reveal or not world.fog_seen[active].has(id):
			ghosts[id].queue_free()
			ghosts.erase(id)


## How the side you command last saw an enemy building ([kind, owner, cx, cy, size, done,
## progress, age], fog.gd), or null: for your own and allies' (and with the fog lifted) the
## truth is shown instead; an enemy building never seen isn't shown at all.
func _memory(b: int):
	var bs := world.buildings
	if reveal or not world.is_enemy(active, bs.owner[b]):
		return null
	return world.fog_seen[active].get(bs.id[b])


## Is this building shown finished (to the side you command)? An enemy's only if you've seen it so.
func _shown_done(b: int) -> bool:
	var bs := world.buildings
	if reveal or not world.is_enemy(active, bs.owner[b]):
		return bs.done[b] == 1
	var m = world.fog_seen[active].get(bs.id[b])
	return m != null and m[5] == 1


## Which neighbours a finished wall tile's arms reach (bit k: Models.LINKS[k]): finished walls
## and gates beside it, and corner to corner where no wall beside both closes the corner
## already (an L turns at its corner tile rather than cutting across it).
func _links(b: int) -> int:
	var bs := world.buildings
	var on := func(d: Vector2i) -> bool:
		var x: int = bs.cx[b] + d.x
		var y: int = bs.cy[b] + d.y
		if x < 0 or y < 0 or x >= map.width or y >= map.height:
			return false
		var o := bs.index_of(map.occupied[y * map.width + x])
		return o >= 0 and o != b and bs.done[o] == 1 and _wall_like(o)
	return BuildingArt.links_of(on)


func _sync_buildings() -> void:
	var bs := world.buildings
	# Buildings that are gone without falling just leave (an enemy's you can't see stays as you saw it).
	for id in bviews.keys():
		if bs.index_of(id) < 0:
			var mem = null if reveal else world.fog_seen[active].get(id)
			if mem != null and not Fog.sees_area(world, active, mem[2], mem[3], mem[4], mem[8], mem[9]):
				ghosts[id] = bviews[id]
			else:
				bviews[id].queue_free()
			bviews.erase(id)
	for b in bs.count():
		var id := bs.id[b]
		var view: BuildingArt = bviews.get(id)
		var t: Dictionary = world.btypes[bs.kind[b]]
		var mem = _memory(b)   # an enemy's: as you last saw it (its owner's age then, how far built)
		var look := kit.building_key(lib.architecture(world.races[bs.owner[b]]), t.id, mem[7] if mem != null else world.ages[bs.owner[b]],
			(id * 7 + bs.cx[b] * 3 + bs.cy[b]) % 4)   # which house variant: steady per building, varied along a street
		if t.gate and kit.buildings.has(look + ArtKit.ALONG[_along_of(b)]):
			look += ArtKit.ALONG[_along_of(b)]   # a gate laid along sim y or a diagonal is baked turned that way
		if view != null and view.get_meta("look", look) != look:
			view.queue_free()   # its owner aged up and this building grew with them
			bviews.erase(id)
			view = null
		if view == null:
			view = BuildingArt.new()
			view.setup(kit, look, bs.cx[b], bs.cy[b], bs.sx[b], bs.sy[b], Color(lib.palettes.teams[bs.owner[b]]))
			view.set_meta("look", look)
			(flat if not t.pen.is_empty() else layer).add_child(view)   # a pen lies low, under the sheep standing in it
			bviews[id] = view
			_clear_doodads(bs.cx[b], bs.cy[b], bs.sx[b], bs.sy[b])
		if bs.done[b] == 1 and not view.get_meta("done", false):
			if view.has_meta("done") and bs.owner[b] == active:
				audio.play("built", -4.0)   # finished while you watched (not the ones there from the start)
		view.set_meta("done", bs.done[b] == 1)
		if mem != null:
			view.set_state(mem[5] == 1, float(mem[6]) / float(t.build_ticks))
		else:
			view.set_state(bs.done[b] == 1, float(bs.progress[b]) / float(t.build_ticks))
		if t.line:
			view.set_links(_links(b) if _shown_done(b) else 0)
		if t.gate:
			view.set_open(BuildingArt.gate_open(world, b))
		view.set_garrison(bs.inside[b].size() if world.teams[bs.owner[b]] == world.teams[active] or reveal else 0)
		if _shown_done(b) and not t.becomes.is_empty() and view.get_parent() == layer:
			view.reparent(flat)   # a sown farm is walked across: it lies under the units
	var built := PackedInt32Array([active, int(reveal)])
	for b in bs.count():
		if _shown_done(b):
			built.append(bs.id[b])
	if built != built_shown:
		built_shown = built
		_refresh_paths()


## Doodads under (and right around) a new building go.
func _clear_doodads(cx: int, cy: int, sx: int, sy: int) -> void:
	for y in range(cy - 1, cy + sy + 1):
		for x in range(cx - 1, cx + sx + 1):
			var c := y * map.width + x
			if x >= 0 and y >= 0 and x < map.width and y < map.height and doodads.has(c):
				for n in doodads[c]:
					n.queue_free()
				doodads.erase(c)


## Resource props show what's left in stages; a used-up bush fades away, used-up reeds
## leave stubble for a while first.
## The prop for a resource cell (bug bush, reed clump, stone outcrop, a farm's crops or paddy).
const RESOURCE_PROP := {"bugbush": "bush", "reeds": "reeds", "stone": "quarry", "gold": "gold", "carcass": "carcass", "field": "crops", "paddy": "paddy", "tree": "tree"}


func _add_resource_view(c: int, kind: String, left: int) -> void:
	var pick: int = res_cells[c]
	var full := maxi(left, map.terrain_amount[map.terrain[c]])   # first seen half used: staged as such
	var b := world.buildings.index_of(map.occupied[c])
	if map.pool[c] >= 0 and b >= 0:
		full = maxi(full, int(world.btypes[world.buildings.kind[b]].get("food", 0)))   # a farm's crops: out of its whole harvest
	var holder := Node2D.new()
	holder.position = Iso.to_screen((c % map.width) * 1000 + 500, (c / map.width) * 1000 + 500)
	var prop: Node2D = kit.doodad(kind, pick, ArtKit.resource_stage(kind, left, full))
	prop.position.y -= Iso.lift((c % map.width) * 1000 + 500, (c / map.width) * 1000 + 500)   # on a hill: raised, sorted on the base plane
	holder.add_child(prop)
	holder.set_meta("res", {"kind": kind, "pick": pick, "stage": ArtKit.resource_stage(kind, left, full), "full": full, "gone": 0.0})
	# A farm's crops share its pool (every tile shows them) and lie flat under the farmers.
	(flat if map.pool[c] >= 0 else layer).add_child(holder)
	rviews[c] = holder


## Props show the ground as the side you command last saw it (fog.gd remembers it): an enemy's
## farm sown in the dark isn't there for you until you look, and one you looked at stays as you
## saw it under the fog. Cells that change (a farm's field, a carcass) join the watched cells.
func _sync_resources() -> void:
	var dt := get_process_delta_time()
	var look := {}   # cells to look at this frame: those just changed, and the props fading out
	var changed := {}
	for c in map.changed:
		if not res_cells.has(c):
			res_cells[c] = c * 7 + c / map.width
		look[c] = true
		changed[c] = true
	map.changed.clear()
	map.changed_overflow = false
	# Every cell only when what you'd see may have moved on: your side's fog (and memory) is
	# restamped every fog_cfg.every ticks, and the truth (with the fog lifted) is read as often.
	var full: bool = world.tick - _res_tick >= int(world.fog_cfg.every) or world.tick < _res_tick or reveal != _res_reveal or active != _res_active
	if full:
		_res_tick = world.tick
		_res_reveal = reveal
		_res_active = active
		look = res_cells
	else:
		for c in _fading:
			look[c] = true
	var ground: PackedByteArray = world.fog_ground[active]
	var seen_left: PackedInt32Array = world.fog_left[active]
	if _res_left.size() != map.width * map.height:
		_res_left.resize(map.width * map.height)
		_res_left.fill(-1)
		_res_ground.resize(map.width * map.height)
	for c in look:
		var left: int = map.left_at(c) if reveal else seen_left[c]
		var gi: int = map.terrain[c] if reveal else ground[c]
		if left == _res_left[c] and gi == _res_ground[c] and not changed.has(c) and not _fading.has(c):
			continue   # seen as it was last time: nothing to do
		_res_left[c] = left
		_res_ground[c] = gi
		var kind: String = RESOURCE_PROP.get(map.terrain_ids[gi], "")
		if kind == "tree":
			kind = land.species_at(c)   # the look of the tree from the ground round it
		elif kind == "" and map.terrain_ids[map.terrain[c]] == "stump" and rviews.has(c):
			kind = rviews[c].get_meta("res").kind   # felled: its stump stays
		var h: Node2D = rviews.get(c)
		if h != null and left > 0 and (h.get_meta("res").gone > 0.0 or h.get_meta("res").kind != kind):
			h.queue_free()   # sown again, or what you see there changed (the fog lifted)
			rviews.erase(c)
			_fading.erase(c)
			h = null
		if h == null:
			if left > 0 and kind != "":
				_add_resource_view(c, kind, left)
			continue
		var r: Dictionary = h.get_meta("res")
		var stage := ArtKit.resource_stage(r.kind, left, r.full)
		if stage != r.stage:
			r.stage = stage
			h.get_child(0).queue_free()
			var prop: Node2D = kit.doodad(r.kind, r.pick, stage)
			prop.position.y -= Iso.lift((c % map.width) * 1000 + 500, (c / map.width) * 1000 + 500)
			h.add_child(prop)
		if left <= 0:
			r.gone += dt   # (a farm worked out sounds from its sim event: _play_events)
			var linger := 6.0 if r.kind in ["reeds", "quarry", "gold", "carcass"] else 0.0   # stubble and rubble stay a while
			if r.kind in ArtKit.TREES and map.occupied[c] == 0:
				linger = INF   # a felled tree's stump stays (until something's built on it)
			if is_inf(linger):
				_fading.erase(c)   # nothing more to do each frame
				continue
			_fading[c] = true
			h.modulate.a = clampf(1.0 - (r.gone - linger) / 1.5, 0.0, 1.0)
			if h.modulate.a <= 0.0:
				h.queue_free()
				rviews.erase(c)
				_fading.erase(c)
		else:
			_fading.erase(c)


## The icon for a tech (a research index or Tech.AGE_UP): a line upgrade shows its unit.
func _tech_icon(player: int, t: int, item: Dictionary) -> Texture2D:
	if t == Tech.AGE_UP:
		return Icons.texture("age_up")
	return kit.icons.get("%d:%s" % [player, item.line]) if item.has("line") else Icons.texture(item.id)


## Age-up and research buttons for a building (from data/tech.json), and what it's doing.
func _tech_buttons(c: Dictionary, b: int) -> void:
	var bs := world.buildings
	var bid: int = bs.id[b]
	var age: Dictionary = Tech.next_age(world, active)
	if not age.is_empty():
		var why := Tech.why_not(world, active, b, "")
		if why != "not here":
			c.buttons.append({"text": "Age up: %s (%s)" % [age.name, _cost_text(age.cost)], "key": "U", "cost": _cost_text(age.cost),
				"icon": Icons.texture("age_up"), "tip": _age_tip(age), "group": "Age up", "accent": true,
				"enabled": why == "", "action": func(): world.issue(active, Commands.AGE_UP, {"building": bid})})
	# One slot per track (a line's upgrades, or research that comes `after` another): its next
	# step only, so age 3's upgrade takes age 2's place once that's done (Dominic). A step being
	# researched keeps its slot, greyed, until it's done.
	var shown := {}   # track -> true
	# Line upgrades first (they go with the Train buttons beside them), then the rest: research a
	# later age brings joins at the end instead of pushing an upgrade along.
	var order := range(world.tech.research.size())
	order = order.filter(func(i): return world.tech.research[i].has("line")) + order.filter(func(i): return not world.tech.research[i].has("line"))
	for ri in order:
		var r: Dictionary = world.tech.research[ri]
		var track := Tech.track_of(world, ri)
		if shown.has(track) or r.building != world.btypes[bs.kind[b]].id or world.researched[active][ri] == 1:
			continue
		var why := Tech.why_not(world, active, b, r.id)
		if why.begins_with("needs ") and why.ends_with(" first"):
			continue   # a later step: its turn comes
		if why == "nothing to upgrade":
			continue   # this age brought the line no new kit: the next upgrade, if any, takes the slot
		shown[track] = true
		if why == "" or why == "can't afford it" or why == "queue full" or why == "already being researched":
			var rid: String = r.id
			var icon: Texture2D = kit.icons.get("%d:%s" % [active, r.line]) if r.has("line") else Icons.texture(r.id)   # a line upgrade shows its unit
			var busy := why == "already being researched"
			c.buttons.append({"text": "%s (%s)" % [_research_name(r), _cost_text(r.cost)], "key": "", "cost": "..." if busy else _cost_text(r.cost),
				"icon": icon, "tip": _research_tip(r) + ("\n[i]Being researched.[/i]" if busy else ""), "group": "Research",
				"enabled": why == "", "action": func(): world.issue(active, Commands.RESEARCH, {"building": bid, "id": rid})})


## Buy and sell buttons for each good at a market, priced live.
func _market_buttons(c: Dictionary, b: int) -> void:
	var bid: int = world.buildings.id[b]
	for r in world.resources.size():
		var res: String = world.resources[r]
		if res == "gold":
			continue
		for buy in [true, false]:
			var price := Market.quote(world, active, r, buy)
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


## A farm (or the mill): what's left, Reseed when it's worked out, and the Auto-reseed setting.
func _farm_buttons(c: Dictionary, b: int, t: Dictionary) -> void:
	var bs := world.buildings
	var bid: int = bs.id[b]
	var fk := Economy.btype_of(world, "farm")
	var reseed: PackedInt32Array = world.btypes[fk].reseed
	if not t.becomes.is_empty():
		var left := world.map.left_at(bs.cy[b] * world.map.width + bs.cx[b])
		c.info += ("\n" if c.info != "" else "") + ("Food left: %d" % left if left > 0 else "Worked out: lies fallow")
		if left <= 0:
			c.buttons.append({"icon": Icons.texture("fallow_fields"), "text": "Reseed (%s)" % _cost_text(reseed), "key": "", "cost": _cost_text(reseed),
				"enabled": world.can_afford(active, reseed), "group": "Farm",
				"tip": "[b]Reseed[/b]\nCrops again for %s; its farmer starts the harvest." % _cost_text(reseed),
				"action": func(): world.issue(active, Commands.RESEED, {"ids": [], "building": bid})})
	var on: bool = world.auto_reseed[active] == 1
	c.buttons.append({"icon": Icons.texture("fallow_fields"), "text": "Auto-reseed", "key": "", "cost": "ON" if on else "OFF", "enabled": true,
		"group": "Farm", "accent": on,
		"tip": "[b]Auto-reseed[/b] (%s)\nA farm worked out is sown again at once for %s, and its farmer farms on. Without the wood, or with this off, the farmer waits by it.\n[color=%s]For all your farms.[/color]" % [
			"on" if on else "off", _cost_text(reseed), TIP_DIM],
		"action": func(): world.issue(active, Commands.AUTO_RESEED, {"on": 0 if on else 1})})


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


## Research effects in words, the same as the tech tree page's.
func _effect_text(effects: Array) -> String:
	return TechTreeModel.effect_text(effects)


## Research this player's race can do (the tech tree's culture layer, D-070).
func _my_research() -> Array:
	var race: Dictionary = world.races[active]
	return world.tech.research.filter(func(r): return not Tech.lacks(world, active, r.id) and (r.only.is_empty() or bool(world.rules.get("full_tech_tree", false)) \
		or race.creature in r.only or race.family in r.only))   # (and not what the race lacks: milestone 14)


func _unit_tip(wt: Dictionary) -> String:
	var lines := []
	lines.append("Gathers food, wood, stone and gold, and builds." if wt.worker else UnitCard.text(wt, _foe_types(active), world.combat))
	var ups := []
	for r in _my_research():
		if r.effects.any(func(e): return Tech.reaches(e, wt.eval.tags)):
			ups.append("%s at the %s (%s)" % [r.name, _bname(r.building), _effect_text(r.effects)])
	if not ups.is_empty():
		lines.append("[color=%s]Upgrades: %s[/color]" % [TIP_DIM, "; ".join(ups)])
	for step in wt.line:
		if int(step.age) > world.ages[active] and int(step.age) > int(wt.line[0].age):
			lines.append("[color=%s]Age %d: becomes %s[/color]" % [TIP_DIM, int(step.age), step.recipe.get("name", wt.name)])
	var needs := [] if world.ages[active] >= int(wt.line[0].age) else ["age %d" % int(wt.line[0].age)]
	if wt.get("hero", false):   # one of each out at a time; a fallen one comes back for less, after a wait
		var hk := SimHeroes.type_of(world, wt.player, wt.recipe.hero)
		var why := SimHeroes.why_not(world, active, hk)
		lines.append("[color=%s]One of each hero at a time. If it falls, revive it at the Town Center after %d s for %d%% of its price.[/color]" % [TIP_DIM, int(world.hero_cfg.revive) / 20, int(world.hero_cfg.revive_pct)])
		if why != "" and wt.player == active:
			lines.append("[color=%s]%s[/color]" % [TIP_NEED, why.capitalize() if why.begins_with("revives") else "It's %s" % why])
		return _tip(wt.name, SimHeroes.cost(world, active, hk), lines, needs)
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
	for need in Tech.requires(world, active, age):   # (a race without the building: its stand-in, milestone 14)
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


## Your race's tech tree page, over the match (the sim keeps running).
func toggle_tech_tree() -> void:
	if tech_tree.visible:
		tech_tree.close()
		return
	tech_tree.open(world.races[active], world.rules, lib, kit, active, Color(lib.palettes.teams[active]), world, active)


func _update_top_bar() -> void:
	var fam: String = world.races[active].family
	if fam != hud_family:   # the HUD wears the culture of the side you command
		hud_family = fam
		var lk := UiTheme.look(fam)
		CommandPanel.TipButton.look = lk
		minimap.look = lk
		_fit_hud()
	if top_bar.get_child_count() == 0:
		top_bar.setup(world.resources)
		top_bar.tree_pressed.connect(toggle_tech_tree)
		for info in lib.resource_info:
			panel.res_icons[info.short] = Icons.texture("res_" + info.id)
		top_bar.idle_pressed.connect(_next_idle_worker)
		show_debug = not vs_ai
	top_bar.position = Vector2(10, 8) if not show_debug or vs_ai else Vector2(10, 150)
	var stock := {}
	for r in world.resources.size():
		stock[world.resources[r]] = world.stock[r][active]
	var ages: Array = world.tech.ages.filter(func(a): return int(a.age) == world.ages[active])
	var age: Dictionary = ages[0] if not ages.is_empty() else {}
	top_bar.show_idle(_idle_workers().size())
	top_bar.show_workers(_gatherers(active))
	top_bar.show_state(stock, world.pop[active], world.pop_cap[active], world.races[active].name, world.tick / World.TICK_HZ)
	var next := ""
	var frac := 0.0
	for b in world.buildings.count():   # an age-up queued or under way, wherever it is
		if world.buildings.owner[b] == active and Tech.entry(Tech.AGE_UP) in world.buildings.queue[b]:
			next = Tech.next_age(world, active).get("name", "")
			frac = float(world.buildings.train[b]) / float(Tech.head_ticks(world, b)) if Tech.head(world, b) == Tech.AGE_UP else 0.0   # 0 while it waits its turn
	top_bar.show_age(world.ages[active], age.get("name", "Age %d" % world.ages[active]), next, frac)


## Your workers on each resource, by what they do: {resource id: {verb: count}}. A worker
## counts while it gathers or carries a load home, or chases game; by the ground it works
## (a farm's field or paddy is farming, a carcass hunting, a bush foraging, reeds chopping,
## stone and gold mining). View only.
const WORK_VERBS := {"field": "farming", "paddy": "farming", "carcass": "hunting", "bugbush": "foraging", "reeds": "chopping",
	"stone": "mining", "gold": "mining"}

func _gatherers(p: int) -> Dictionary:
	var out := {}
	var u := world.units
	for i in u.count():
		if u.owner[i] != p or not world.types[u.kind[i]].worker:
			continue
		var res := ""
		var verb := ""
		if (u.task[i] == Economy.GATHER or u.task[i] == Economy.RETURN) and u.carry_kind[i] > 0:
			res = world.resources[u.carry_kind[i] - 1]
			var cell: int = u.home[i] if u.home[i] >= 0 else u.target[i]
			verb = WORK_VERBS.get(map.terrain_at(cell), "gathering") if u.task[i] == Economy.GATHER or u.home[i] >= 0 else "gathering"
		elif u.foe[i] != 0 and _owner_of(u.foe[i]) == world.gaia:
			res = "food"
			verb = "hunting"
		if res == "":
			continue
		if not out.has(res):
			out[res] = {}
		out[res][verb] = int(out[res].get(verb, 0)) + 1
	return out


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
	var cell := _cell_at(_pointer())
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
		var group := _building_group()
		var title: String = t.name if owner == active else "%s %s" % [world.races[owner].name, t.name]
		if group.size() > 1:
			title += " \u00d7%d" % group.size()   # "Barracks ×3"
		var c := {"title": title, "team": Color(lib.palettes.teams[owner]), "hp": [bs.hp[b], world.bmods[owner][bs.kind[b]].hp],
			"portrait": kit.building_icon(_arch(owner), t.id), "buttons": [], "queue": null, "info": "", "hint": ""}
		if bs.done[b] == 0:
			c.info = "Being built: %d%%" % (100 * bs.progress[b] / t.build_ticks)
		elif not t.pen.is_empty():   # a pen: its animals and what they bring in
			var n: int = mini(Pens.animals(world, b, true).size(), int(t.pen.animals))
			c.info = "%d / %d animals: %d food a minute" % [n, t.pen.animals, n * int(t.pen.food) * 1200 / int(t.pen.food_ticks)]
			c.hint = "Two or more breed, now and then."
			if mine:
				c.hint = _hint_add(c, "Right-click it with sheep selected to put them in.")
				c.buttons.append({"icon": Icons.texture("release"), "text": "Release", "key": "", "cost": "", "enabled": n > 0, "group": "Orders",
					"tip": "[b]Release[/b]\nThe animals walk out and stand in front of the pen (to slaughter them, or lead them elsewhere).",
					"action": func(): world.issue(active, Commands.RELEASE, {"building": selected_building})})
		elif not t.trains.is_empty() or not world.tech.research.filter(func(r): return r.building == t.id).is_empty():
			var q: Array = bs.queue[b]
			c.queue = []
			c.queue_max = int(world.econ.queue_max)
			for n in q.size():   # units, research and the age-up in one order; click one to cancel it (refunded)
				var idx := n
				var slot_icon: Texture2D
				var slot_name: String
				var tt := Tech.tech_of(q[n])
				if tt == -1:
					var qt: Dictionary = world.types[q[n]]
					slot_icon = kit.icons.get("%d:%s" % [qt.player, HeroLine.line_key(qt.recipe)])
					slot_name = qt.name
				else:
					var it: Dictionary = Tech.item_of(world, owner, tt)
					slot_icon = _tech_icon(owner, tt, it)
					slot_name = ("Age up to the %s" % it.name) if tt == Tech.AGE_UP else _research_name(it)
				c.queue.append({"icon": slot_icon, "name": slot_name,
					"action": func(): if mine: world.issue(active, Commands.CANCEL, {"building": selected_building, "index": idx})})
			var ht := Tech.head(world, b) if not q.is_empty() else -1
			if ht != -1:
				var item: Dictionary = Tech.item_of(world, owner, ht)
				c.progress = float(bs.train[b]) / float(Tech.head_ticks(world, b))
				c.info = ("Ageing up to the %s" % item.name) if ht == Tech.AGE_UP else "Researching %s" % _research_name(item)
				c.queue_title = "Ageing up" if ht == Tech.AGE_UP else "Researching"
			elif not q.is_empty():
				var head: Dictionary = world.types[q[0]]
				c.progress = float(bs.train[b]) / float(head.train_ticks)
				c.info = "Training %s" % head.name
				if bs.train[b] == 0 and world.pop[owner] + head.pop > world.pop_cap[owner]:
					c.info += " (needs a house)"
			var room := q.size() < int(world.econ.queue_max)
			if group.size() > 1:   # the lead's queue shows; the line says what all of them hold
				var held := 0
				for id in group:
					held += _queue_load(id)
					room = room or _queue_load(id) < int(world.econ.queue_max)
				c.info += ("\n" if c.info != "" else "") + "%d selected, %d queued in all" % [group.size(), held]
			if mine:
				for slot in t.trains:
					var tk := world.type_of(active, slot)
					if tk < 0 or Economy.lacks(world, active, slot):
						continue
					if slot == "hero":   # (each of the race's heroes its own button, D-138)
						_hero_buttons(c, room)
						continue
					var wt: Dictionary = world.types[tk]
					var ok_age: bool = world.ages[active] >= int(wt.line[0].age)
					var afford: bool = world.can_afford(active, wt.cost)
					var tslot: String = slot
					c.buttons.append({"icon": kit.icons.get("%d:%s" % [active, slot]),
						"text": (("Train %s (%s)" % [wt.name, _cost_text(wt.cost)]) if ok_age else "%s: needs age %d" % [wt.name, wt.line[0].age]),
						"tip": _unit_tip(wt), "group": "Train",
						"key": "Q" if slot == "worker" else "", "cost": _cost_text(wt.cost), "enabled": ok_age and afford and room,
						"action": func(): _train_group(tslot)})
				_tech_buttons(c, b)
				if t.id == "market" and bs.done[b] == 1:
					_market_buttons(c, b)
				c.hint = _hint_add(c, "Right-click: set its rally point.")
		elif t.idle_note != "":   # nothing to train or research (yet): say so
			c.info = t.idle_note
			var wk: int = world.wonder_ids.find(bs.id[b])
			if wk >= 0 and Match.hold_ticks(world) > 0:   # a Wonder's countdown, for anyone who looks
				var secs: int = (Match.ticks_left(world, wk) + 19) / 20
				c.info = "Stands for %d:%02d more, and %s win." % [secs / 60, secs % 60, "you" if mine else world.races[owner].name]
		if mine and bs.done[b] == 1 and (not t.becomes.is_empty() or t.id == "mill"):
			_farm_buttons(c, b, t)
		if bs.done[b] == 1 and t.garrison > 0:
			_garrison_buttons(c, b, t, mine)
		panel.show_content(c)
		return
	var mine: Array = _selected_by_owner()[active]
	if not mine.is_empty():
		var u := world.units
		var first := u.index_of(mine[0])
		var ft: Dictionary = world.types[u.kind[first]]
		var c := {"title": ft.name if mine.size() == 1 else "%d selected" % mine.size(), "team": team, "buttons": [], "queue": null,
			"portrait": kit.icons.get("%d:%s" % [ft.player, HeroLine.line_key(ft.recipe)]), "hp": [u.hp[first], ft.hp] if mine.size() == 1 else []}
		var herd: Array = mine.filter(_is_animal)
		var soldiers: int = mine.size() - herd.size() - _selected_workers().size()
		if mine.size() == 1 and ft.worker:
			c.info = ["Idle", "Gathering", "Carrying back", "Building", "Going inside"][u.task[first]]
			if u.carry[first] > 0:
				c.info += " (%d %s)" % [u.carry[first], world.resources[u.carry_kind[first] - 1]]
		elif mine.size() == 1 and ft.has("animal"):
			c.info = _animal_info(ft, active)
		elif mine.size() == 1:
			c.info = UnitCard.short(ft, world.combat)
			c["hint"] = UnitCard.text(ft, _foe_types(active), world.combat)
		else:
			c.info = ""
			var counts := {}
			for id in mine:
				var k := u.kind[u.index_of(id)]
				counts[k] = counts.get(k, 0) + 1
			var kinds := counts.keys()
			kinds.sort()
			c.tray = kinds.map(func(k): return {"icon": kit.icons.get("%d:%s" % [world.types[k].player, HeroLine.line_key(world.types[k].recipe)]), "count": counts[k]})
		if not herd.is_empty() and herd.size() == mine.size():   # only our animals: they walk, or stop
			c.buttons.append({"icon": Icons.texture("stop"), "text": "Stop", "key": "X", "cost": "", "enabled": true, "group": "Orders",
				"tip": "[b]Stop[/b]\nThey stand where they are.", "action": stop_selected})
		if not herd.is_empty() and not _selected_workers().is_empty():   # workers and sheep: the workers slaughter them
			c.buttons.append({"icon": Icons.texture("slaughter"), "text": "Slaughter", "key": "", "cost": "", "enabled": true, "group": "Orders",
				"tip": "[b]Slaughter[/b]\nThe selected workers slaughter the selected animals, one at a time, and gather the meat.", "action": slaughter_selected})
		if soldiers > 0:   # soldiers: attack-move, stop and stances
			c.buttons.append({"icon": Icons.texture("attack_move"), "text": "Attack-move", "key": "R", "cost": "", "enabled": true, "group": "Orders",
				"tip": "[b]Attack-move[/b]\nThen click where: they walk there and fight whatever they meet on the way.", "action": func(): arming_attack = true})
			var ab: Dictionary = Abilities.of(world, active)
			var users := mine.filter(func(id): return Abilities.can_use(world, world.units.kind[world.units.index_of(id)]))
			if not users.is_empty():   # the race's ability (milestone 14): ready on the first that's ready, else its wait
				var wait: int = users.map(func(id): return Abilities.wait(world, world.units.index_of(id))).min()
				c.buttons.append({"icon": Icons.texture("creature_research"), "text": ab.name, "key": "", "cost": "" if wait == 0 else "%ds" % ((wait + 19) / 20),
					"enabled": wait == 0, "group": "Orders",
					"tip": "[b]%s[/b]\n%s\nThen click where (within %d tiles). Again in %d s." % [ab.name, ab.desc, int(ab.range) / 1000, int(ab.cooldown) / 20],
					"action": func(): arming_ability = true})
			c.buttons.append({"icon": Icons.texture("stop"), "text": "Stop", "key": "X", "cost": "", "enabled": true, "group": "Orders",
				"tip": "[b]Stop[/b]\nDrop every order: they stand where they are.", "action": stop_selected})
			var now := _shown_stance(mine)
			for k in STANCES.size():
				var stance: String = Combat.POSTURES[k]
				c.buttons.append({"icon": Icons.texture("stance_" + stance), "text": STANCES[k][0], "key": "", "cost": "ON" if now == k else "", "enabled": true, "group": "Stance", "accent": now == k,
					"tip": "[b]%s[/b]%s\n%s\nOrdered attacks work under every stance." % [STANCES[k][0], " (now)" if now == k else "", STANCES[k][1]],
					"action": func(): set_stance(stance)})
		if not _selected_workers().is_empty():
			if str(mine) != _build_page_for:
				_build_page_for = str(mine)
				build_page = ""
			if build_page == "":
				for page in [["civilian", "Civilian", "house", "Houses, farms, camps, the market, the armoury and Town Centers."],
						["military", "Military", "barracks", "Barracks, ranges, stables, towers, walls and gates; from age 3 the siege workshop and the Wonder."]]:
					var pid: String = page[0]
					c.buttons.append({"icon": kit.building_icon(_arch(active), page[2]), "text": "Build: %s" % page[1], "key": "", "cost": page[1], "enabled": true,
						"glyph": Icons.texture("glyph/" + page[2]), "group": "Build",
						"tip": "[b]%s buildings[/b]\n%s" % [page[1], page[3]], "action": func(): build_page = pid})
			else:
				for id in build_menu[build_page]:
					var bk := Economy.upgraded(world, active, Economy.btype_of(world, id))   # a Watchtower after the Bastion research: a Bastion
					var t: Dictionary = world.btypes[bk]
					if world.ages[active] < t.age or Economy.lacks(world, active, t.id):   # (not in this race's tree: milestone 14)
						continue
					var why := Economy.why_not_build(world, active, bk)   # another Town Center: from age 3
					var afford: bool = world.can_afford(active, Economy.bcost(world, active, bk))
					var bid: String = id
					c.buttons.append({"icon": kit.building_icon(_arch(active), t.id), "text": "Build %s (%s)" % [t.name, _cost_text(Economy.bcost(world, active, bk))] if why == "" else "%s: %s" % [t.name, why],
						"tip": _building_tip(t) + ("" if why == "" else "\n[color=#e07060]%s %s[/color]" % [t.name.capitalize(), why]),
						"glyph": Icons.texture("glyph/" + t.id), "group": build_page.capitalize(),   # what it's for, the same in every culture
						"key": t.hotkey, "cost": _cost_text(Economy.bcost(world, active, bk)), "enabled": afford and why == "", "action": func(): start_placing(bid)})
				c.buttons.append({"icon": Icons.texture("back"), "text": "Back", "key": "Esc", "cost": "", "enabled": true, "group": " ",
					"tip": "[b]Back[/b]\nTo the civilian and military pages.", "action": func(): build_page = ""})
		if placing != "":
			c.info = "Placing: A builds, hold LB to keep placing, B cancels" if PadMode.of(get_tree()).on \
				else "Placing: left-click to build, shift keeps placing, right-click/Esc cancels"
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
			"portrait": kit.icons.get("%d:%s" % [et.player, HeroLine.line_key(et.recipe)]), "hp": [world.units.hp[i], et.hp],
			"info": _animal_info(et, eo) if et.has("animal") else UnitCard.short(et, world.combat),
			"hint": "" if et.has("animal") else UnitCard.text(et, _foe_types(eo), world.combat)})
		return
	panel.show_content({"title": world.races[active].name, "team": team, "portrait": null,
		"info": "Select units or a building." if vs_ai else "Select units or a building.  Tab switches side.  F6: let the bots play.", "buttons": [], "queue": null})


## How-to lines go in the panel's hint (the info's tooltip), not its text: they made the panel
## two rows tall (Dominic).
func _hint_add(c: Dictionary, line: String) -> String:
	return (c.get("hint", "") + "\n" if c.get("hint", "") != "" else "") + line


## A building people shelter in (garrison.gd): how many are inside and what they add, and for
## its owner Ungarrison; a Town Center also rings the call to arms, and sends them back to work.
func _garrison_buttons(c: Dictionary, b: int, t: Dictionary, mine: bool) -> void:
	var n: int = world.buildings.inside[b].size()
	var arrows: int = t.arrows + n if not t.attack.is_empty() else 0
	var line := "%d / %d inside" % [n, t.garrison]
	if not t.attack.is_empty():
		line += ", %d arrow%s a volley" % [arrows, "" if arrows == 1 else "s"] if arrows > 0 else ", no arrows till manned"
	c.info = line + ("\n" + c.info if c.info != "" else "")
	if not mine:
		return
	c.hint = _hint_add(c, "Right-click it with units selected to send them in.")
	c.buttons.append({"icon": Icons.texture("ungarrison"), "text": "Ungarrison", "key": "", "cost": "", "enabled": n > 0, "group": "Orders",
		"tip": "[b]Ungarrison[/b]\nEveryone inside comes out (to the rally point, if it has one).",
		"action": func(): world.issue(active, Commands.UNGARRISON, {"building": selected_building})})
	if t.id == "town_center":
		# One bell, rung and unrung (Dominic): while workers shelter it shows rung, and a second
		# press sends them back to what they were gathering.
		var rung := _sheltering(active) > 0
		c.buttons.append({"icon": Icons.texture("back_to_work" if rung else "call_to_arms"), "text": "Back to work" if rung else "Call to arms",
			"key": "", "cost": "", "enabled": true, "group": "Orders", "accent": rung,
			"tip": ("[b]Back to work[/b]\n%d workers are sheltering: they all come out and go back to what they were gathering." % _sheltering(active)) if rung
				else "[b]Call to arms[/b]\nEvery worker within %d tiles runs into the nearest Town Center or tower with room, and shoots from it. Press again to send them back to work." % int(world.garrison_cfg.call_range),
			"action": func(): world.issue(active, Commands.BACK_TO_WORK if _sheltering(active) > 0 else Commands.CALL_TO_ARMS, {"building": selected_building})})


## How many of a player's workers are inside a building or on their way in.
func _sheltering(player: int) -> int:
	var n := 0
	var u = world.units
	for i in u.count():
		if u.owner[i] == player and u.task[i] == Economy.GARRISON and world.types[u.kind[i]].worker:
			n += 1
	var bs = world.buildings
	for b in bs.count():
		if bs.owner[b] == player:
			for rec in bs.inside[b]:
				if world.types[rec[Garrison.REC_KIND]].worker:
					n += 1
	return n


func _arch(player: int) -> String:
	return lib.architecture(world.races[player])


## The cursor shows what a right-click would do for the selection.
func _update_cursor() -> void:
	if PadMode.of(get_tree()).on:
		return   # the mouse is hidden; the reticle shows the same art (pad_play.gd)
	if baking or world == null or placing != "" or get_viewport().gui_get_hovered_control() != null:
		cursors.use("pointer")
		return
	cursors.use(_cursor_kind(get_global_mouse_position()))


## What a right-click (the pad's X) would do at pos, as a cursor's name.
func _cursor_kind(pos: Vector2) -> String:
	if placing != "":
		return "pointer"
	if arming_attack:
		return "attack"
	var b := world.buildings.index_of(selected_building)
	if b >= 0:
		return "pointer"   # right-click sets the rally point; the genre doesn't need a special cursor for it
	if _selected_by_owner()[active].is_empty():
		return "pointer"
	var cell := _cell_at(pos)
	var bid: int = map.occupied[cell]
	var enemy: bool = bid != 0 and world.is_enemy(active, world.buildings.owner[world.buildings.index_of(bid)]) \
		and bviews.has(bid) and bviews[bid].visible   # not over buildings you haven't found
	var under := unit_at(pos)
	var fighters: bool = _selected_by_owner()[active].any(func(id): return not _is_animal(id))   # sheep fight nothing
	enemy = enemy and fighters
	var workers := not _selected_workers().is_empty()
	if under != 0 and fighters:
		var uo := world.units.owner[world.units.index_of(under)]
		if world.is_enemy(active, uo):
			enemy = true   # an enemy, or a wild animal to hunt
		elif uo == active and workers and _is_animal(under):
			enemy = true   # one of our sheep: slaughter it
	if enemy:
		return "attack"
	elif workers and map.resource_at(cell) != "":
		return {"food": "forage", "wood": "chop", "stone": "mine", "gold": "mine"}.get(map.resource_at(cell), "chop")
	elif workers and bid != 0 and _is_foundation_of(bid, active):
		return "build"
	elif workers and bid != 0 and map.pool[cell] >= 0 and world.buildings.owner[world.buildings.index_of(bid)] == active:
		return "build"   # a worked-out farm of ours: right-click reseeds it (Dominic: it showed the plain cursor)
	elif workers and bid != 0 and _drop_off_kind(bid, active, _selected_workers()) != "":
		# taking it in: the carried resource's tool (there's no drop-off cursor art yet)
		var kind := _drop_off_kind(bid, active, _selected_workers())
		return {"food": "forage", "wood": "chop", "stone": "mine", "gold": "mine"}.get(kind, "move")
	else:
		return "move"


# ------------------------------------------------------------------ drawing

func _draw_marks() -> void:
	if world == null:
		return
	if show_flow:
		_draw_flow()
	_draw_webs()
	var u := world.units
	for id in selected:
		var i := u.index_of(id)
		var view: Node2D = views.get(id)
		if i < 0 or view == null:
			continue
		marks.draw_set_transform(view.ground(), 0.0, Vector2(1.0, 0.5))
		marks.draw_arc(Vector2.ZERO, u.radius[i] * Iso.RADIUS_PX, 0.0, TAU, 24, Color(0, 0, 0, 0.6), 3.5 / camera.zoom.x)   # a dark edge...
		marks.draw_arc(Vector2.ZERO, u.radius[i] * Iso.RADIUS_PX, 0.0, TAU, 24, RING, 2.0 / camera.zoom.x)   # ...under a bright ring (Fable: 1.5 px was too thin)
		marks.draw_set_transform(Vector2.ZERO)
	order_marks.draw(marks)   # what they're doing and what's queued, as routes
	for f in flags:
		marks.draw_set_transform(f.pos, 0.0, Vector2(1.0, 0.5))
		marks.draw_circle(Vector2.ZERO, 10.0 * f.t, Color(RING, f.t))
		marks.draw_set_transform(Vector2.ZERO)


## Webs on the ground (abilities.gd): a placeholder mark, pale rings and spokes on the ground,
## fading as it wears off, until the web's look has its concept round (D-080).
func _draw_webs() -> void:
	var webs: PackedInt32Array = world.webs
	for n in range(0, webs.size(), Abilities.WEB):
		var left := clampf(float(webs[n + 4] - world.tick) / 100.0, 0.25, 1.0)
		var col := Color(0.92, 0.92, 0.86, 0.55 * left)
		var r: float = webs[n + 3] * Iso.RADIUS_PX
		marks.draw_set_transform(Iso.to_ground(webs[n + 1], webs[n + 2]), 0.0, Vector2(1.0, 0.5))
		for ring in [0.35, 0.7, 1.0]:
			marks.draw_arc(Vector2.ZERO, r * ring, 0.0, TAU, 28, col, 1.5 / camera.zoom.x)
		for k in 8:
			marks.draw_line(Vector2.ZERO, Vector2.from_angle(TAU * k / 8.0) * r, col, 1.2 / camera.zoom.x)
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


## How far over a unit's feet its health bar sits: a hero stands taller (its signature's scale).
func _bar_lift(k: int) -> float:
	var t: Dictionary = world.types[k]
	return BODY_LIFT * 2.6 * (float(t.recipe.scale) / 100.0 if t.get("hero", false) else 1.0)


## Heroes in the field (milestone 14): a small gold crown over each one you can see, over its health
## bar; its name over the crown while it's selected. Drawn at a fixed size on screen.
func _draw_heroes() -> void:
	var font := UiTheme.text_font(true)
	var inv := Vector2.ONE / camera.zoom.x
	for k in world.hero_types:
		var hid: int = world.hero_id[k]
		var view: Node2D = views.get(hid) if hid != 0 else null
		if view == null or not view.visible or world.units.index_of(hid) < 0:
			continue
		var top: Vector2 = view.ground() - Vector2(0, _bar_lift(k) + 1.0)
		if view.head_node != null:   # just over its head and hat (a crouched frog's head is far under a standing man's)
			var hn: Node2D = view.head_node
			top = Vector2(view.ground().x, overlay.to_local(hn.global_position).y - HERO_CROWN_LIFT * hn.global_transform.get_scale().y)
		overlay.draw_set_transform(top, 0.0, inv)   # (one unit: one screen pixel)
		var crown := PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2(10, -11), Vector2(4.5, -5), Vector2(0, -13), Vector2(-4.5, -5), Vector2(-10, -11)])
		overlay.draw_colored_polygon(crown, HERO_GOLD)
		overlay.draw_polyline(crown + PackedVector2Array([crown[0]]), Color(0.18, 0.1, 0.02, 0.9), 2.0)
		if selected.has(hid):
			var name: String = world.types[k].name
			var fs := 14
			var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			overlay.draw_string_outline(font, Vector2(-w * 0.5, -18), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.08, 0.05, 0.02, 0.9))
			overlay.draw_string(font, Vector2(-w * 0.5, -18), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, HERO_GOLD.lightened(0.35))
		overlay.draw_set_transform(Vector2.ZERO)


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
		var at: Vector2 = view.ground() - Vector2(bar_w * 0.5, _bar_lift(u.kind[i]))
		var k := clampf(float(u.hp[i]) / float(full), 0.0, 1.0)
		overlay.draw_rect(Rect2(at, Vector2(bar_w, 2)), Color(0, 0, 0, 0.6))
		overlay.draw_rect(Rect2(at, Vector2(bar_w * k, 2)), Color(1.0 - k, 0.3 + 0.6 * k, 0.15).lerp(Color.WHITE, 0.1))
	_draw_heroes()
	for bid in _building_group():
		var bs := world.buildings
		var b := bs.index_of(bid)
		var sx := bs.sx[b] * 1000
		var sy := bs.sy[b] * 1000
		var x0 := bs.cx[b] * 1000
		var y0 := bs.cy[b] * 1000
		var up := Vector2(0, Iso.lift(x0 + sx / 2, y0 + sy / 2))   # on a hill, the outline sits on its top
		for q in _footprint_quads(bs.cx[b], bs.cy[b], bs.sx[b], bs.sy[b], bs.diag[b]):
			var pts: PackedVector2Array = q + PackedVector2Array([q[0]])
			overlay.draw_polyline(pts, Color(0, 0, 0, 0.6), 4.0 / camera.zoom.x)
			overlay.draw_polyline(pts, RING, 2.0 / camera.zoom.x)
		if bs.rally_x[b] >= 0:
			var rp := Iso.to_ground(bs.rally_x[b], bs.rally_y[b])
			overlay.draw_line(Iso.to_screen(x0 + sx / 2, y0 + sy / 2) - up, rp, Color(RING, 0.4), 1.0 / camera.zoom.x)   # the flag itself is in the marks
	if placing != "":
		var c := _ghost_cell(_pointer())
		var along := _ghost_along(_pointer())
		var d := Economy.dims(world.btypes[Economy.btype_of(world, placing)], along)
		var ghosts := wall_cells(wall_from, c) if _line(placing) and wall_from.x >= 0 else [c]
		for g in ghosts:
			var ok := _ghost_ok(Economy.btype_of(world, placing), g.x, g.y, along)
			for q in _footprint_quads(g.x, g.y, d.x, d.y, Economy.diag_of(along)):
				overlay.draw_colored_polygon(q, GOOD if ok else BAD)
	if boxing:
		var r := Rect2(press_world, Vector2.ZERO).expand(get_global_mouse_position())
		overlay.draw_rect(r, Color(RING, 0.12))
		overlay.draw_rect(r, RING, false, 1.0 / camera.zoom.x)
	pad_play.draw(overlay)
