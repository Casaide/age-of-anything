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
var library := false              # "library": every part in every colour any race can wear (no flipbooks)
var lines_extra := PackedStringArray()
var dumping := false             # "dump": every view's draw list, frame by frame (dumps.txt), for the Lobster composer's check
var dumps := PackedStringArray()
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
	library = args.size() > 2 and args[2] == "library"
	var prompts: Array = [args[2], args[3]] if args.size() > 3 and not library else Export.PROMPTS
	for p in prompts:
		races.append(gen.generate(p, rules))
	var w := World.new(Export.SEED, SimMap.load_id(map_id), races, rules)
	if library:
		lines_extra.append("library 1")
	var teams := []
	for k in races.size():
		teams.append(Color(lib.palettes.teams[k]))
	kit = ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	dumping = "dump" in args
	var t0 := Time.get_ticks_msec()
	if library:
		await _bake_library(gen, rules)
	else:
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
	stage.process_mode = Node.PROCESS_MODE_DISABLED   # (views step by DT by hand, engines' crews with them: the same every run)

	var lines := PackedStringArray()
	var jobs := []   # [type, dir]
	for k in (0 if library else w.types.size()):   # (a library has no flipbooks: the game composes its units)
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
	lines.append("match %s" % map_id)   # (the game makes the races and the start itself: gen/setup.lobster)
	for k in prompts.size():
		lines.append("prompt %d %s" % [k, String(prompts[k]).replace(" ", "_")])
	_parts(lines, out)
	lines.append_array(lines_extra)
	_buildings(w, races, lines)
	_names_and_sounds(w, races, lines)
	_ground(w, lines)
	_pack(out, lines)
	if dumping:
		var d := FileAccess.open(out.path_join("dumps.txt"), FileAccess.WRITE)
		d.store_string("\n".join(dumps) + "\n")
		d.close()
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
		v.time = 0.0   # (each view's clock from 0: the Lobster composer starts there too)
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
			_crew_process(v)
			if moves:
				v.position -= step
				if v._hop_last != Vector2.INF:
					v._hop_last -= step
		if dumping:
			for n in views.size():
				if on[n]:
					_dump_view(views[n], "%d %s %d %d" % [batch[n][0], state, batch[n][1], f])
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


## An engine's crew step with it (in the game the tree processes them, after their engine).
func _crew_process(v: UnitView) -> void:
	for c in v.crew:
		c.view._process(DT)
		_crew_process(c.view)


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
		if b.has("arms"):   # a wall: its arm towards each neighbour (Models.LINKS), and their near merlons
			lines.append("arms %s %s" % [key, " ".join(b.arms.map(func(x): return x if x != "" else "-"))])
			lines.append("armsf %s %s" % [key, " ".join(b.get("arms_front", []).map(func(x): return x if x != "" else "-"))])
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


## Every unit part bake (PartShape.baked) as a frame "p:<bake key>" and a line "bake <key> <origin x>
## <origin y> <scale>" (texture px of the part's 0,0; texture px per part unit), legs' soles and spans
## ("soles <key> x y ...", "span <key> x y x y": UnitView plants feet and folds knees by them), and the
## rigs the bakes made (PartShape.rigs: sockets, hips, depth, facing directions) as rigs.json.
func _parts(lines: PackedStringArray, out: String) -> void:
	var keys: Array = PartShape.baked.keys()
	keys.sort()
	for key in keys:
		var b: Dictionary = PartShape.baked[key]
		var img: Image = b.img
		if img == null or img.is_empty():
			continue
		frames.append(["p:" + key, img, int(round(b.origin.x)), int(round(b.origin.y))])
		lines.append("bake %s %f %f %f" % [key, b.origin.x, b.origin.y, b.scale])
		if String(key).begins_with("leg."):
			var row := ["soles", key]
			for p in PartShape.soles(b):
				row.append("%f %f" % [p.x, p.y])
			lines.append(" ".join(row))
			var sp := _span_of(b)
			if not sp.is_empty():
				lines.append("span %s %f %f %f %f" % [key, sp[0].x, sp[0].y, sp[1].x, sp[1].y])
	var check = UnitView.UnitModelsCheck
	var kit_parts := {}
	for id in lib.parts:
		if check.has(id):
			lines.append("modelled %s" % id)
		var p: Dictionary = lib.parts[id]
		if p.has("kit"):   # a creature-kit body as DataLib completed it, and the head and legs it made
			kit_parts[id] = p
			for made in [p.legs.part, p.legs.get("hind", ""), lib.creatures.values().filter(func(c): return c.body == id).map(func(c): return c.head)]:
				for m in (made if made is Array else [made]):
					if m != "" and lib.parts.has(m):
						kit_parts[m] = lib.parts[m]
	var kf := FileAccess.open(out.path_join("kit_parts.json"), FileAccess.WRITE)
	kf.store_string(JSON.stringify(_plain(kit_parts), "", true))
	kf.close()
	var rigs := {}
	for id in PartShape.rigs:
		rigs[id] = _plain(PartShape.rigs[id])
	var f := FileAccess.open(out.path_join("rigs.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(rigs, "", true, true))
	f.close()


## UnitView._span: a bake's top and bottom opaque rows, each at its middle (part units from the origin).
static func _span_of(b: Dictionary) -> Array:
	var img: Image = b.img
	var rows := []
	for y in img.get_height():
		var xs := 0.0
		var count := 0
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				xs += x + 0.5
				count += 1
		if count > 0:
			rows.append((Vector2(xs / count, y + 0.5) - b.origin) / b.scale)
	return [rows[0], rows[-1]] if not rows.is_empty() else []


## A rig's values as JSON (vectors as [x, y]).
static func _plain(v):
	match typeof(v):
		TYPE_VECTOR2:
			return [v.x, v.y]
		TYPE_VECTOR3:
			return [v.x, v.y, v.z]
		TYPE_DICTIONARY:
			var o := {}
			for k in v:
				o[str(k)] = _plain(v[k])
			return o
		TYPE_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_INT32_ARRAY:
			return Array(v).map(func(x): return _plain(x))
	return v


## A view's draw list as it stands: "d <type> <state> <dir> <frame> <n> <view x> <view y>", then a line a
## part drawn, in draw order: its bake key and the transform from its texture px to the stage's
## (art px: xx xy yx yy ox oy), and its alpha.
func _dump_view(v: UnitView, head: String) -> void:
	var rows := PackedStringArray()
	_dump_walk(v, 1.0, rows)
	var g := v.get_global_transform()
	dumps.append("d %s %d %f %f" % [head, rows.size(), g.origin.x, g.origin.y])
	dumps.append_array(rows)


func _dump_walk(n: Node, alpha: float, rows: PackedStringArray) -> void:
	if n is CanvasItem and not n.visible:
		return
	var a: float = alpha * (n.modulate.a if n is CanvasItem else 1.0)
	if n is PartShape:
		var ps: PartShape = n
		var key := PartShape.bake_key(ps.part_id, ps.shapes, PartShape.team_neutral(ps.colours))
		if ps.facing != 0 and PartShape.baked.has(key + PartShape.facing_suffix(ps.facing)):
			key += PartShape.facing_suffix(ps.facing)
		if ps.front:
			key = PartShape.front_key(key)
		var b = PartShape.baked.get(key)
		if b != null:
			var t: Transform2D = ps.get_global_transform() * Transform2D(0.0, Vector2.ONE / b.scale, 0.0, -b.origin / b.scale)
			rows.append("%s %f %f %f %f %f %f %f" % [key, t.x.x, t.x.y, t.y.x, t.y.y, t.origin.x, t.origin.y, a * ps.self_modulate.a])
		else:
			rows.append("%s missing" % key)
	for c in n.get_children():
		_dump_walk(c, a, rows)


## The library: races covering the kit (every creature with every culture, then each copied into
## every skin of its creature and of its mount), each distinct unit step probed once by the kit's own
## job listing (holds, poses, cut legs, crews and haulers, workers' tools and loads, corpses), every
## architecture's buildings and the props.
func _bake_library(gen, rules: Dictionary) -> void:
	var cw := {}
	var fw := {}
	for word in lib.lexicon:
		var e: Dictionary = lib.lexicon[word]
		if e.has("era"):
			continue
		if e.has("creature") and lib.creatures[e.creature].get("playable", false) and not cw.has(e.creature):
			cw[e.creature] = word
		if e.has("family") and not fw.has(e.family):
			fw[e.family] = word
	var base := []
	for c in cw:
		for f in fw:
			base.append(gen.generate("%s %s" % [cw[c], fw[f]], rules))
	var races := []
	for r in base:
		var text := JSON.stringify(r)
		races.append(r)
		var own: String = r.units[0].recipe.skin
		for s in lib.creatures[r.creature].skins:   # the rider's skins
			if s != own:
				races.append(JSON.parse_string(text.replace('"skin":"%s"' % own, '"skin":"%s"' % s)))
		var mounts := {}
		for u in r.units:
			if u.recipe.has("mount") and not u.recipe.mount.get("fused", false):
				mounts[u.recipe.mount.creature] = u.recipe.mount.skin
		for m in mounts:   # the mounts' skins
			for s in lib.creatures[m].skins:
				if s != mounts[m]:
					races.append(JSON.parse_string(text.replace('"skin":"%s"' % mounts[m], '"skin":"%s"' % s)))
	var seen := {}
	var units := []
	for r in races + [ArtKit.animal_race()]:
		for u in r.units:
			for l in u.get("line", [{"recipe": u.recipe, "eval": u.eval}]):
				var key := JSON.stringify(l.recipe, "", true)
				if not seen.has(key):
					seen[key] = true
					units.append(l)
	units.append_array(_library_extras(races, seen))
	var arch := {}
	var by_arch := []
	for r in base:
		var a: String = lib.architecture(r)
		if not arch.has(a):
			arch[a] = true
			by_arch.append(r)
	print("library: %d races, %d distinct unit steps, %d architectures" % [races.size(), units.size(), by_arch.size()])
	var unit_ids: Array = await kit._steps_jobs(units)
	var rest_ids: Array = kit._props_jobs() + kit._building_jobs(by_arch)
	print("library: %d part jobs, %d other jobs" % [unit_ids.size(), rest_ids.size()])
	kit._ask(unit_ids + rest_ids, true)
	await kit._await_jobs(unit_ids + rest_ids)
	PartShape.bake_flat("unit_shadow", UnitView.SHADOW_SHAPES, UnitView.SHADOW_COLOURS, ArtKit.ART_SCALE * ArtKit.UNIT_SCALE)


## What no generated race happened to show: every arm hold on every creature in each skin and
## culture (a body's holds are baked in its cloth), and every part on every creature's body, cloth
## parts in every culture's colours (worn armour bakes onto the body it's worn by).
func _library_extras(races: Array, seen: Dictionary) -> Array:
	var holds := {}   # hold -> a weapon held that way
	var by_slot := {}
	var ids: Array = lib.parts.keys()
	ids.sort()
	for id in ids:
		var p: Dictionary = lib.parts[id]
		if p.get("innate", false) or String(id).begins_with("siege."):
			continue
		if p.slot == "hand_r" and not p.has("requires_role"):
			var h := UnitView.hold_for(p.tags)
			if not holds.has(h):
				holds[h] = id
			if ("spear" in p.tags or "lance" in p.tags) and not holds.has("thrust"):
				holds["thrust"] = id
		if p.slot in ["hand_r", "hand_l", "head_gear", "torso", "back"]:
			if not by_slot.has(p.slot):
				by_slot[p.slot] = []
			by_slot[p.slot].append(id)
	var out := []
	var base_done := {}
	for r in races:
		var w: Dictionary = {}
		for u in r.units:
			if u.recipe.slot == "worker":
				w = u
		if w.is_empty():
			continue
		var rec: Dictionary = w.recipe
		var bkey := "%s|%s|%s" % [rec.body, rec.skin, rec.family]
		if base_done.has(bkey):
			continue
		base_done[bkey] = true
		var first_of_creature := not base_done.has(rec.body)
		base_done[rec.body] = true
		for h in holds:   # every hold, in this skin and culture
			out.append(_extra_step(rec, "infantry", {"hand_r": holds[h]}, w.eval, seen))
		for slot in by_slot:   # every part, on this body: once a creature; cloth parts in every culture
			for id in by_slot[slot]:
				var cloth: bool = lib.part(id).shapes.any(func(sh): return String(sh.get("ch", "")).begins_with("cloth"))
				if first_of_creature or cloth:
					var parts := {slot: id}
					if slot != "hand_r":
						parts.hand_r = holds["low"]
					out.append(_extra_step(rec, "infantry", parts, w.eval, seen))
	return out.filter(func(x): return not x.is_empty())


func _extra_step(rec: Dictionary, role: String, parts: Dictionary, e: Dictionary, seen: Dictionary) -> Dictionary:
	var r: Dictionary = rec.duplicate(true)
	r.slot = role
	r.role = role
	r.parts = parts
	var key := JSON.stringify(r, "", true)
	if seen.has(key):
		return {}
	seen[key] = true
	return {"recipe": r, "eval": e}
