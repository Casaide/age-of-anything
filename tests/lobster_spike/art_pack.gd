extends SceneTree
## The Lobster port's match pack, the art half (docs/milestones/lobster-port.md): the races of the
## export's match (export.gd PROMPTS, SEED) baked by the game's own ArtKit, then
##   - every unit type rendered by UnitView in 8 screen directions as flipbooks: idle, walk (16
##     frames), attack, the fall, and for workers each job and each load carried;
##   - every bake the kit made (buildings with their stages and layers, props, doodads, trees);
## all packed into PNG sheets, with index.txt: one line per frame and per building look, the
## doodad counts, the terrain colours and each tree cell's species. Team colour stays the baked key
## (magenta): the Lobster game recolours it (team_mask.gdshader's test). Art pixels throughout:
## a tile is 96 x 48, Iso.to_screen * 1.5.
## Also: each player's team colour and creature voice, unit and building names, each unit type's
## blow and shot sounds, and the sound table (data/audio.json).
## Run (needs a display): godot --path . --audio-driver Dummy --always-on-top --script res://tests/lobster_spike/art_pack.gd -- <out dir> <map> [prompt A] [prompt B]

const Export := preload("res://tests/lobster_spike/export.gd")
const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const LandView := preload("res://src/view/art/land_view.gd")
const CombatFx := preload("res://src/view/combat_fx.gd")

const KEY := Color(1, 0, 1)      # the team key: units drawn in it, recoloured in Lobster
const CELL := 192                # art px per capture cell
const GRID := 10                 # cells a side (100 views a render)
const ANCHOR := Vector2(96, 150) # the unit's ground point in its cell
const DT := 1.0 / 8.0            # UnitView.STEP_FPS
const WALK := 16
const ATTACK := 4
const ENGINE_ATTACK := 8
const WORK := 8
const DIE := 18
const SHEET := 4096
const JOBS := {"forage": "tool.basket", "chop": "tool.axe", "mine": "tool.pick", "build": "tool.hammer"}
const LOADS := {"food": "tool.basket", "wood": "load.reeds", "stone": "load.stone", "gold": "load.gold"}

var vp: SubViewport
var stage: Node2D
var frames := []   # [name, Image, ox, oy]
var lib
var kit


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var map_id: String = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	lib = DataLib.new()
	var rules = DataLib.load_json("res://data/rules/default.json")
	rules.animals = false
	var gen = Generator.new(lib)
	var races := []
	var prompts: Array = [args[2], args[3]] if args.size() > 3 else Export.PROMPTS
	for p in prompts:
		races.append(gen.generate(p, rules))
	var w := World.new(Export.SEED, SimMap.load_id(map_id), races, rules)
	var teams := []
	for k in races.size():
		teams.append(Color(lib.palettes.teams[k]))
	kit = ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	var t0 := Time.get_ticks_msec()
	await kit.prepare(races, teams)
	print("baked in %d ms" % (Time.get_ticks_msec() - t0))

	vp = SubViewport.new()
	vp.size = Vector2i(CELL * GRID, CELL * GRID)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	stage = Node2D.new()
	stage.scale = Vector2.ONE * ArtKit.ART_SCALE   # canvas units to art px
	vp.add_child(stage)

	var lines := PackedStringArray()
	var jobs := []   # [type, dir]
	for k in w.types.size():
		for d in 8:
			jobs.append([k, d])
	for at in range(0, jobs.size(), GRID * GRID):
		await _units(w, jobs.slice(at, at + GRID * GRID), lines)
		print("units %d / %d" % [mini(at + GRID * GRID, jobs.size()), jobs.size()])
	for name in kit.bakes:
		var b: Dictionary = kit.bakes[name]
		var img: Image = b.img
		if img == null or img.is_empty():
			continue
		frames.append([name, img, int(round(b.origin.x)), int(round(b.origin.y))])
	_buildings(w, races, lines)
	_names_and_sounds(w, races, lines)
	_ground(w, lines)
	_pack(out, lines)
	var f := FileAccess.open(out.path_join("index.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("pack: %d frames, %s" % [frames.size(), out])
	quit()


## A batch of (type, direction) views in the grid, played through each state; frames named
## u<type>.<state>.<dir>.<n>, and a line per (type, state): "anim <type> <state> <frames>".
func _units(w: World, batch: Array, lines: PackedStringArray) -> void:
	var views := []
	for n in batch.size():
		var k: int = batch[n][0]
		var t: Dictionary = w.types[k]
		var v := UnitView.new()
		v.build(t.recipe, lib, KEY, t.speed / World.SPEED_SCALE)
		v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
		v.pose_steps = 8
		v.art_px = ArtKit.ART_SCALE
		v.set_process(false)
		v.position = _anchor(n) / ArtKit.ART_SCALE
		stage.add_child(v)
		var dir := Vector2.RIGHT.rotated(batch[n][1] * PI / 4.0)
		v.face_vec(dir)
		v.face_vec(dir)
		views.append(v)
	var is_worker := func(n): return bool(w.types[batch[n][0]].worker)
	var engine := func(n): return w.types[batch[n][0]].recipe.has("crew")
	await _state(batch, views, "idle", 1, func(_v, _n, _f): pass, lines)
	await _state(batch, views, "walk", WALK, func(v, n, _f): v.walking = true, lines, true)
	for v in views:
		v.walking = false
	await _state(batch, views, "attack", ENGINE_ATTACK, func(v, n, f):
		if f == 0:
			if w.types[batch[n][0]].ranged or engine.call(n):
				v.loose()
			else:
				v.flourish(), lines)
	for job in JOBS:
		await _state(batch, views, "work_" + job, WORK, func(v, n, f):
			if f == 0 and is_worker.call(n):
				v.set_tool(lib, JOBS[job])
				v.job = job, lines, false, is_worker)
	for v in views:
		v.job = ""
	for res in LOADS:
		await _state(batch, views, "carry_" + res, WALK, func(v, n, f):
			if f == 0 and is_worker.call(n):
				v.set_tool(lib, LOADS[res])
				v.walking = true, lines, true, is_worker)
	for n in views.size():
		views[n].walking = false
		if is_worker.call(n):
			views[n].set_tool(lib, w.types[batch[n][0]].recipe.parts.get("hand_r", "tool.basket"))
	await _state(batch, views, "die", DIE, func(v, _n, f):
		if f == 0:
			v.die(1.0), lines)
	for v in views:
		v.queue_free()
	await process_frame


## One state: `count` frames, each after `prep` (view, slot, frame) and a step of DT. Walking
## views step their way and back (a hopper hops on), so they stay in their cell. `only`: the
## slots the state is for (workers' jobs and loads).
func _state(batch: Array, views: Array, state: String, count: int, prep: Callable, lines: PackedStringArray, moves := false, only := Callable()) -> void:
	var on := []
	for n in views.size():
		on.append(not only.is_valid() or only.call(n))
	for f in count:
		for n in views.size():
			if not on[n]:
				views[n].visible = false
				continue
			var v: UnitView = views[n]
			v.visible = true
			prep.call(v, n, f)
			var step := Vector2.ZERO
			if moves:
				step = Vector2.RIGHT.rotated(batch[n][1] * PI / 4.0) * v.speed_px * DT
				v.position += step
			v._process(DT)
			if moves:
				v.position -= step
				if v._hop_last != Vector2.INF:
					v._hop_last -= step
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		for n in views.size():
			if on[n]:
				var a := _anchor(n)
				var cell := img.get_region(Rect2i(Vector2i(a - ANCHOR), Vector2i(CELL, CELL)))
				var used := cell.get_used_rect()
				if used.size.x == 0:
					used = Rect2i(0, 0, 1, 1)
				frames.append(["u%d.%s.%d.%d" % [batch[n][0], state, batch[n][1], f], cell.get_region(used),
					int(ANCHOR.x) - used.position.x, int(ANCHOR.y) - used.position.y])
	for n in views.size():
		views[n].visible = true
		if on[n] and batch[n][1] == 0:
			lines.append("anim %d %s %d" % [batch[n][0], state, count])


func _anchor(n: int) -> Vector2:
	return Vector2((n % GRID) * CELL, (n / GRID) * CELL) + ANCHOR


## Each player's architecture and every building look the kit has: "arch <player> <arch>", then
## "look <key> <body> <stages...>" (the four construction stages, "-" for none), and the doodad
## counts and the resource props.
func _buildings(w: World, races: Array, lines: PackedStringArray) -> void:
	for p in races.size():
		lines.append("arch %d %s" % [p, lib.architecture(races[p])])
	for key in kit.buildings:
		var b: Dictionary = kit.buildings[key]
		var stages: Array = b.get("stages", [])
		var row := ["look", key, b.body]
		for s in 4:
			row.append(stages[s] if s < stages.size() and stages[s] != null and stages[s] != "" else "-")
		row.append(b.get("front", "-") if b.get("front", "") != "" else "-")
		lines.append(" ".join(row))
	for kind in ArtKit.DOODADS:
		lines.append("doodad %s %d" % [kind, ArtKit.DOODADS[kind]])
	for terrain in ["bugbush", "reeds", "stone", "gold", "carcass", "field", "paddy", "tree"]:
		lines.append("prop %s %s" % [terrain, {"bugbush": "bush", "reeds": "reeds", "stone": "quarry", "gold": "gold", "carcass": "carcass", "field": "crops", "paddy": "paddy", "tree": "tree"}[terrain]])


## Team colours, voices, names (spaces as underscores) and sounds.
func _names_and_sounds(w: World, races: Array, lines: PackedStringArray) -> void:
	for p in races.size():
		var c := Color(lib.palettes.teams[p])
		lines.append("team %d %d %d %d" % [p, c.r8, c.g8, c.b8])
		lines.append("voice %d %s" % [p, lib.creatures[races[p].creature].voice])
	for k in w.types.size():
		var t: Dictionary = w.types[k]
		var tags: Array = t.eval.get("tags", [])
		lines.append("uname %d %s" % [k, String(t.get("name", t.slot)).replace(" ", "_")])
		lines.append("usound %d %s %s" % [k, _blow(tags), CombatFx.shot_sound(CombatFx.shot_kind(tags))])
	for k in w.btypes.size():
		lines.append("bname %d %s" % [k, String(w.btypes[k].name).replace(" ", "_")])
	for r in w.tech.research.size():
		lines.append("rname %d %s" % [r, String(w.tech.research[r].get("name", w.tech.research[r].id)).replace(" ", "_")])
	var a: Dictionary = DataLib.load_json("res://data/audio.json")
	for name in a.sounds:
		var s: Dictionary = a.sounds[name]
		lines.append("sound %s %d %d %s" % [name, int(s.get("takes", 1)), int(s.get("gap_ms", 0)), s.get("bus", "Sfx")])
	for bus in a.buses:
		lines.append("bus %s %d" % [bus, int(a.buses[bus])])
	var v: Dictionary = a.voices.kinds
	for kind in v:
		lines.append("voicekind %s %d" % [kind, int(v[kind])])


## The sim view's blow sound for a melee weapon's tags (sim_debug.gd _blow_sound).
static func _blow(tags: Array) -> String:
	if "ram" in tags:
		return "ram_hit"
	if "blade" in tags:
		return "hit_blade"
	if "blunt" in tags:
		return "hit_blunt"
	return "hit_pierce"


## Terrain colours (data/terrain.json, in the map's terrain order) and each tree cell's species.
func _ground(w: World, lines: PackedStringArray) -> void:
	var m = w.map
	var d: Dictionary = DataLib.load_json("res://data/terrain.json").terrain
	for t in m.terrain_ids:
		var c := Color(d[t].colour)
		var c2 := Color(d[t].get("colour2", d[t].colour))
		lines.append("ground %s %d %d %d %d %d %d" % [t, c.r8, c.g8, c.b8, c2.r8, c2.g8, c2.b8])
	var land := LandView.new()
	land.world = w
	land._noise.seed = hash(m.id)
	land._noise.frequency = 0.09
	var row := ["species"]
	for c in m.width * m.height:
		row.append(land.species_at(c) if m.terrain_ids[m.terrain[c]] == "tree" else "-")
	lines.append(" ".join(row))
	land.free()


## Shelf-packs every frame into SHEET x SHEET sheets (tallest first): sheet<n>.png, and a line a
## frame: "frame <name> <sheet> <x> <y> <w> <h> <ox> <oy>" (ox, oy: the anchor inside the frame).
func _pack(out: String, lines: PackedStringArray) -> void:
	frames.sort_custom(func(a, b): return a[1].get_height() > b[1].get_height() if a[1].get_height() != b[1].get_height() else a[0] < b[0])
	var sheets := []
	var sheet := Image.create(SHEET, SHEET, false, Image.FORMAT_RGBA8)
	var x := 0
	var y := 0
	var row_h := 0
	for f in frames:
		var img: Image = f[1]
		img.convert(Image.FORMAT_RGBA8)
		var fw := img.get_width()
		var fh := img.get_height()
		assert(fw + 2 <= SHEET and fh + 2 <= SHEET, "%s is too big for a sheet" % f[0])
		if x + fw + 2 > SHEET:
			x = 0
			y += row_h + 2
			row_h = 0
		if y + fh + 2 > SHEET:
			sheets.append(sheet)
			sheet = Image.create(SHEET, SHEET, false, Image.FORMAT_RGBA8)
			x = 0
			y = 0
			row_h = 0
		sheet.blit_rect(img, Rect2i(0, 0, fw, fh), Vector2i(x, y))
		lines.append("frame %s %d %d %d %d %d %d %d" % [f[0], sheets.size(), x, y, fw, fh, f[2], f[3]])
		x += fw + 2
		row_h = maxi(row_h, fh)
	sheets.append(sheet)
	for n in sheets.size():
		sheets[n].save_png(out.path_join("sheet%d.png" % n))
	lines.insert(0, "sheets %d %d" % [sheets.size(), SHEET])
