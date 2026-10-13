extends Node
## Everything the pixel-art look needs for one match, baked once: every part of both
## races' units, each culture's buildings, resource props (reeds, bug bushes, rock)
## and ground doodads, all packed into the shared atlas (PartShape.atlas). Sprites
## made here share one material, so the whole y-sorted layer batches.
## View side only; the sim never sees any of this.

const PartShape := preload("res://src/part_shape.gd")
const UnitView := preload("res://src/unit_view.gd")
const CombatFx := preload("res://src/view/combat_fx.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const Baker := preload("res://src/view/art/bake/baker.gd")
const Models := preload("res://src/view/art/bake/models.gd")
const PropModels := preload("res://scenes/art_pixel/prop_models.gd")
const TreeModels := preload("res://scenes/art_pixel/tree_models.gd")
const BridgeModels := preload("res://scenes/art_pixel/bridge_models.gd")
const TownProps := preload("res://scenes/art_pixel/town_props.gd")
const DataLib := preload("res://src/data_lib.gd")
const UnitModels := preload("res://scenes/art_pixel/unit_models.gd")
const BakeCache := preload("res://src/view/art/bake_cache.gd")
const BakeClock := preload("res://src/view/art/bake/bake_clock.gd")

const ART_SCALE := 1.5     # art pixels per canvas unit (a tile is 96 x 48 art pixels)
const UNIT_SCALE := 0.85   # units at about a third of a building's height
const UNIT_BANDS := 4      # value bands in unit shading (Pixelize.run; the paint-over hybrid)
const SS := 4              # supersampling for the building and prop bakes
const HOUSE_SCALE := 1.1   # houses read smaller than the halls (Fable; Dominic: rat house too big)
const ALONG_Z := "^z"       # bake-name suffix of a gate turned a quarter, for a wall line running along sim y
## Bake-name suffixes of a gate on a diagonal wall line, by Economy `along`: 2 (x and y grow
## together: straight down the screen) and 3 (x falls as y grows: across the screen).
const ALONG := ["", ALONG_Z, "^d", "^a"]
## Parts a worker swaps in by job (see UnitView.set_tool and sim_debug's _tool_for).
const JOB_PARTS := ["tool.axe", "tool.basket", "tool.hammer", "tool.pick", "tool.hoe", "tool.broom", "load.reeds", "load.stone", "load.gold", "load.meat"]
const LOAD_SLICE_MS := 8   # cache loads per frame, at most this long
const ICON_CELL := 240    # screen pixels per unit when rendering portraits; each is clipped to its cell (a frog on a newt overran 160 into its neighbours' portraits)   # houses read about 2.5x a footman
const TOWN := {"thatch": "town_center", "junk": "junk_town_center_small", "stone": "stone_town_center", "tent": "tent_town_center",
	"reed": "reed_town_center", "mound": "mound_town_center"}
const HOUSE := {"thatch": "stilt_house", "junk": "tin_can_house", "stone": "villa_house", "tent": "tent_house",
	"reed": "reed_house", "mound": "mound_house"}
const MATERIALS := ["wood", "thatch", "mud", "stone", "tin", "brick", "plaster", "terracotta", "terracotta_dark", "felt", "weave"]
## Prop and doodad kinds and how many variants of each (each a different shape, size
## and turn; picked per tile so neighbours differ).
const DOODADS := {"reeds": 6, "bush": 6, "rock": 6, "quarry": 4, "gold": 4, "carcass": 3, "stones": 6, "tuft": 6, "flowers": 6, "shore": 4, "lily": 4, "crops": 4, "paddy": 4,
	"tree_broadleaf": 4, "tree_pine": 4, "tree_swamp": 4}
## Trees (milestone 15): each species in the look picked from its concept round
## (tree_models.gd styles; the sheet is waiting on Dominic's pick, D-080).
const TREE_STYLE := {"broadleaf": 0, "pine": 0, "swamp": 1}
const TREES := ["tree_broadleaf", "tree_pine", "tree_swamp"]
## Map bridges: the look (bridge_models.gd style). Every size a map uses is baked (bridge_sizes),
## along sim x and along sim y (^z), standing and broken (.1).
const BRIDGE_STYLE := 0
## Resources show how much is left: reeds, bug bushes and quarry stone each have this many stages
## (0 whole ... 3 nearly gone: stubble for reeds, a bare brown bush).
const STAGES := 4
## Town life (milestone 17): which concept-sheet style each drop-off pile is baked in.
const PILE_STYLE := {"food": "a", "wood": "a", "stone": "b", "gold": "a"}
## A building under construction shows four stages: foundations; the scaffold with what
## stands low; the walls; the roof going on. Each keeps the parts whose top (first two)
## or middle (last two) is below this fraction of the building's height.
const BUILD_STAGES := [0.15, 0.4, 0.45, 0.72]

var lib
var bakes := {}       # name -> {img: Image, origin: Vector2 (baked px of the anchor)}
var regions := {}     # name -> Rect2 in the atlas
var buildings := {}   # "arch:type" -> {body, smoke, lantern, lights, banner, vane, vane_at, stages} (canvas units from the centre)
var icons := {}       # "side:slot" -> Texture2D: a portrait of that unit, rendered from its baked art
var _building_icons := {}   # "arch:type" -> AtlasTexture
var _wall_looks := {}       # "arch:type|links" -> {tex, origin}: a wall tile with its arms (wall_look)
var part_workers := 4       # unit-part bakers rendering at once
var hifi_workers := 4       # building and prop bakers rendering at once (2048 px viewports each)
var track: Array = []       # the job ids the running prepare() waits on (progress())
var report := ""            # how long the last prepare() took, in words

var _jobs := {}             # job id -> {kind: part | hifi | load, weight, what, done, running, make, apply}
var _queue := {"part": [], "hifi": [], "load": []}   # job ids waiting, per kind of worker
var _workers := {"part": 0, "hifi": 0, "load": 0}
var _front := {}            # job ids a prepare asked for (a warm-up never drops these)
var _warming := {}          # job ids the last warm-up asked for
var _dirty := false         # something was baked or loaded since the atlas was last built
var _models                 # the building and prop models (Models), shared by the bakers
var _unit_models := UnitModels.new()   # which parts are modelled (eight facings) rather than flat
var _bdata := {}            # data/buildings.json (_buildings_data)
var _icon_cache := {}       # recipe + team -> Texture2D: a portrait already painted (a side rerolled repaints only its own)
var _warm_gen := 0          # bumped by each warm-up: a later one cancels the last one's portraits
var tree_track: Array = []  # the jobs a tech tree page's bake waits on (tree_progress())

signal units_ready          # prepare(): every unit part is baked and in the atlas
signal atlas_rebuilt        # the atlas texture was replaced: anything drawn from it should redraw


## Bake what these races need (anything already baked or on disk is kept), then rebuild the
## atlas. The units come first (units_ready: a loader can stand the armies up), then the props
## and the buildings, then the portraits. A loader follows it with progress() and busy_with().
## Prints how long each part took (bake time at match start is a budget we watch).
func prepare(races: Array, teams: Array) -> void:
	var t0 := Time.get_ticks_msec()
	var unit_ids := _unit_jobs(races + [animal_race()])
	var rest_ids: Array = _props_jobs() + _building_jobs(races)
	track = unit_ids + rest_ids
	var rendered := _count_cold(track)
	_ask(unit_ids, true)
	await _await_jobs(unit_ids)   # the armies first, on their own (a loader stands them up)
	_ask(rest_ids, true)
	PartShape.bake_flat("unit_shadow", UnitView.SHADOW_SHAPES, UnitView.SHADOW_COLOURS, ART_SCALE * UNIT_SCALE)
	if _dirty or PartShape.atlas == null:
		rebuild_atlas()
	var t1 := Time.get_ticks_msec()
	units_ready.emit()
	await _await_jobs(rest_ids)
	var t2 := Time.get_ticks_msec()
	rebuild_atlas()
	var t3 := Time.get_ticks_msec()
	await bake_icons(races, teams)
	track = []
	report = "units %d ms, props + buildings %d ms, atlas %d ms, icons %d ms; total %d ms (%d of %d bakes rendered, the rest loaded or already baked)" % [
		t1 - t0, t2 - t1, t3 - t2, Time.get_ticks_msec() - t3, Time.get_ticks_msec() - t0, rendered, unit_ids.size() + rest_ids.size()]
	print("Art kit: ", report)


## Bake in the background, behind anything asked for up front (the lobby, while players choose),
## so the tech tree and a match start find it done: every age of these races' unit lines, the
## animals, the props and these races' buildings, then the portraits (teams: each race's colour;
## none: no portraits). Drops the last warm-up's pending work (a prompt changed: its old race).
func warm(races: Array, teams := []) -> void:
	var unit_ids := _unit_jobs(races)
	var ids: Array = unit_ids + _unit_jobs([animal_race()]) + _props_jobs() + _building_jobs(races)
	for kind in _queue:
		_queue[kind] = _queue[kind].filter(func(id): return _front.has(id) or id in ids or not _warming.has(id))
	_warming = {}
	for id in ids:
		_warming[id] = true
	_ask(ids, false)
	_warm_gen += 1
	if not teams.is_empty():
		_warm_icons(races, teams, unit_ids, _warm_gen)


## Stop the warm-up: its pending jobs leave the queue (those under way finish; anything asked for
## up front stays) and its portraits aren't painted.
func cancel_warm() -> void:
	_warm_gen += 1
	for kind in _queue:
		_queue[kind] = _queue[kind].filter(func(id): return _front.has(id) or not _warming.has(id))
	_warming = {}


## The warm-up's portraits, once its races' parts are baked (unless a later warm-up came first).
func _warm_icons(races: Array, teams: Array, unit_ids: Array, gen: int) -> void:
	while unit_ids.any(func(id): return not _jobs[id].done):
		if gen != _warm_gen:
			return
		await get_tree().process_frame
	if gen == _warm_gen:
		await bake_icons(races, teams)


## What one race's tech tree page needs, up front: every age of its lines, their portraits (as
## kit.icons "side:slot@age"), its culture's buildings.
func bake_tree(race: Dictionary, side: int, team: Color) -> void:
	var ids: Array = _unit_jobs([race]) + _building_jobs([race])
	tree_track = ids
	_ask(ids, true)
	await _await_jobs(ids)
	PartShape.bake_flat("unit_shadow", UnitView.SHADOW_SHAPES, UnitView.SHADOW_COLOURS, ART_SCALE * UNIT_SCALE)
	await _icons(_icon_list([race], [team], [side]))
	tree_track = []


## How far the tech tree page's bake is (0..1; 1 when there's none).
func tree_progress() -> float:
	var p := progress(tree_track)
	return 1.0 if p.y <= 0.0 else p.x / p.y


## Is everything this race's tech tree page shows ready for this side: every portrait of its lines
## and its culture's buildings?
func tree_ready(race: Dictionary, side: int) -> bool:
	if not buildings.has(lib.architecture(race) + ":house"):
		return false
	for u in race.units:
		if not icons.has("%d:%s" % [side, u.recipe.slot]):
			return false
		for l in u.get("line", []):
			if not icons.has("%d:%s@%d" % [side, u.recipe.slot, int(l.age)]):
				return false
	return true


## How far the tracked work is: Vector2(done, total) in estimated renders (a loader's bar).
func progress(ids := track) -> Vector2:
	var p := Vector2.ZERO
	for id in ids:
		var j: Dictionary = _jobs[id]
		p.y += j.weight
		if j.done:
			p.x += j.weight
	return p


## What the tracked work is busy with, in words.
func busy_with() -> String:
	for id in track:
		if _jobs[id].running or not _jobs[id].done:
			return _jobs[id].what
	return "Painting the portraits"


func _count_cold(ids: Array) -> int:
	return ids.filter(func(id): return not _jobs[id].done and _jobs[id].kind != "load").size()


# ------------------------------------------------------------------ bake jobs
#
# Every bake is a job: a unit part (all its facings), a building (with its stages and extra
# looks), the prop set. A job found in the disk cache (BakeCache) just loads; the rest render
# on a few bakers at once (each its own viewport: BakeClock draws them together, and a draw
# costs hardly more with four than with one). A job
# asked for twice runs once; a match start asks for its jobs at the front of the queue, the
# lobby's warm-up at the back.

## Queue jobs (front: ahead of background work) and start workers for them.
func _ask(ids: Array, front: bool) -> void:
	for id in ids:
		if front:
			_front[id] = true
	for kind in _queue:
		var mine := ids.filter(func(id): return _jobs[id].kind == kind and not _jobs[id].done and not _jobs[id].running)
		if mine.is_empty():
			continue
		var rest: Array = _queue[kind].filter(func(id): return not id in mine)
		_queue[kind] = mine + rest if front else rest + mine
		_spawn(kind)


func _await_jobs(ids: Array) -> void:
	while ids.any(func(id): return not _jobs[id].done):
		await get_tree().process_frame


## A job, made once per id (done: already baked in this run).
func _job(id: String, kind: String, weight: float, what: String, done: bool, make: Callable, apply: Callable) -> String:
	if not _jobs.has(id):
		var cached := not done and BakeCache.has(id)
		_jobs[id] = {"kind": "load" if cached else kind, "weight": 0.2 if cached else weight, "what": what, "done": done,
			"running": false, "make": make, "apply": apply}
	return id


func _spawn(kind: String) -> void:
	var cap: int = {"part": part_workers, "hifi": hifi_workers, "load": 1}[kind]
	while _workers[kind] < mini(cap, _queue[kind].size()):
		_workers[kind] += 1
		_work(kind)


## One worker: takes jobs of its kind off the queue until there are none.
func _work(kind: String) -> void:
	var baker: Node = null
	if kind == "part":
		baker = PartBaker.new()
		baker.art_scale = ART_SCALE * UNIT_SCALE   # baked at the size they're drawn: crisp pixels
		baker.bands = UNIT_BANDS   # the paint-over look: painted value bands, not plastic gradients
		add_child(baker)
	elif kind == "hifi":
		baker = await _hifi_baker()
	var slice := Time.get_ticks_msec()
	while not _queue[kind].is_empty():
		var id: String = _queue[kind].pop_front()
		var j: Dictionary = _jobs[id]
		if j.done or j.running:
			continue
		j.running = true
		if kind == "load":
			j.apply.call(BakeCache.read(id))
			if Time.get_ticks_msec() - slice > LOAD_SLICE_MS:   # loading never holds a frame up for long
				await get_tree().process_frame
				slice = Time.get_ticks_msec()
		else:
			var entry: Dictionary = await j.make.call(baker)
			BakeCache.write(id, entry)
		j.running = false
		j.done = true
		_dirty = true
	if baker != null:
		baker.queue_free()
	_workers[kind] -= 1


## A unit-part job for each part these races' units are drawn with (every age of every line,
## the workers' tools, loads and work holds), each once.
func _unit_jobs(races: Array) -> Array:
	var units := []
	for race in races:
		for u in race.units:   # every age of every unit line: ageing up never waits on a bake
			units.append_array(u.get("line", [{"recipe": u.recipe, "eval": u.eval}]))
	return _steps_jobs(units)


## Only these units ({recipe, eval}: e.g. the few a lobby stage shows, at their first age), up
## front; returns when they can be drawn (from their own textures: the atlas isn't rebuilt).
func bake_steps(units: Array) -> void:
	var ids := _steps_jobs(units)
	_ask(ids, true)
	await _await_jobs(ids)
	PartShape.bake_flat("unit_shadow", UnitView.SHADOW_SHAPES, UnitView.SHADOW_COLOURS, ART_SCALE * UNIT_SCALE)


## The part jobs for these units ({recipe, eval}) with an engine's crew and haulers and what a
## worker pushes home, each part once.
func _steps_jobs(units: Array) -> Array:
	var ids := []
	var steps := []
	for l in units:
		steps.append(l)
		# An engine's members are composed on its sockets, which come with its bake: probed
		# before it, the engine shows none, so its crew and haulers are asked for as units (a
		# trade cart's cat went unbaked: the placement check, "every part drawn is baked").
		if l.recipe.has("crew"):
			steps.append({"recipe": UnitView.crew_recipe(l.recipe), "eval": l.eval})
			var packed: String = lib.part(l.recipe.body).get("packed", "")
			if packed != "":   # the great sling on its wagon (UnitView.set_packed, D-129)
				var pr: Dictionary = l.recipe.duplicate()
				pr.body = packed
				steps.append({"recipe": pr, "eval": l.eval})
			var shot: String = lib.part(l.recipe.body).get("shot", "")
			if shot != "":   # what it throws (data/siege_shots.json), drawn in flight by combat_fx.gd
				var sp: String = CombatFx.look(shot).part
				ids.append(_part_job(sp, lib.part(sp).shapes, UnitView.colours_for(lib, l.recipe.skin, l.recipe.family, ANIMAL_TEAM)))
		if l.recipe.has("haul"):
			steps.append({"recipe": UnitView.haul_recipe(lib, l.recipe), "eval": l.eval})
		# What a worker pushes home (D-127, creatures.json push_home: the rats' barrow and handcart).
		if l.recipe.slot == "worker":
			var pushes: Dictionary = lib.creatures.get(l.recipe.get("creature", ""), {}).get("push_home", {})
			for res in pushes:
				steps.append({"recipe": UnitView.push_recipe(l.recipe, pushes[res]), "eval": l.eval})
	for u in steps:
		var probe := UnitView.new()
		probe.build(u.recipe, lib, ANIMAL_TEAM, u.eval.speed)   # parts bake in the team key: any team will do
		for ps in probe.find_children("*", "Node2D", true, false):
			if ps is PartShape and ps.part_id != "" and ps.part_id != "unit_shadow":   # (the shadow is drawn flat: bake_flat)
				ids.append(_part_job(ps.part_id, ps.shapes, ps.colours))
		probe.free()
		if u.recipe.has("mount") and not u.recipe.mount.get("fused", false):
			# A rider shows the leg on the flank facing the camera: the probe (facing 0) shows one
			# side, so a rider whose legs bake at each hip has every hip's leg asked for (the far
			# flank's went unbaked: the placement check, "every part drawn is baked").
			var rider_colours := UnitView.colours_for(lib, u.recipe.skin, u.recipe.family, ANIMAL_TEAM)
			for id in UnitView.leg_parts(lib, u.recipe.body):
				ids.append(_part_job(id, lib.part(id.get_slice("~", 0)).shapes, rider_colours))
		if not UnitView.pose_parts(lib, u.recipe).is_empty():   # a body's idle poses and posed walk (a cat)
			var mount_skin: String = u.recipe.mount.skin if u.recipe.has("mount") else u.recipe.skin
			var pose_colours := UnitView.colours_for(lib, mount_skin, u.recipe.family, ANIMAL_TEAM)
			for pp in UnitView.pose_parts(lib, u.recipe):
				ids.append(_part_job(pp[0], pp[1], pose_colours))
		var colours := UnitView.colours_for(lib, u.recipe.skin, u.recipe.family, ANIMAL_TEAM)
		if u.recipe.slot == "worker":
			# Workers change tools for the job and carry their load home in their hands.
			for id in JOB_PARTS:
				ids.append(_part_job(id, lib.part(id).shapes, colours))
		# Every body with arms is baked in the work holds too (raised, reaching): workers
		# swing their tools with them (D-105) and soldiers their weapons (D-106).
		var rides: bool = u.recipe.has("mount") and not u.recipe.mount.get("fused", false)
		if not rides and not u.recipe.has("crew") and PartShape.rigs.get(u.recipe.body, {}).get("carry", "") != "harness":   # (an engine's crew are the workers)
			var holds: Array = UnitView.WORK_HOLDS.duplicate()
			var hand: String = u.recipe.parts.get("hand_r", "")
			if hand != "" and ("spear" in lib.part(hand).tags or "lance" in lib.part(hand).tags):
				holds += UnitView.ATTACK_HOLDS   # spear carriers thrust (D-106)
			for h in holds:
				ids.append(_part_job(u.recipe.body + "@" + h, lib.part(u.recipe.body).shapes, colours))
	var seen := {}
	var out := []
	for id in ids:
		if not seen.has(id):
			seen[id] = true
			out.append(id)
	return out


func _part_job(id: String, shapes: Array, colours: Dictionary) -> String:
	var key := PartShape.bake_key(id, shapes, PartShape.team_neutral(colours))
	var modelled: bool = _unit_models.has(id)
	var make := func(pb) -> Dictionary:
		await pb.bake(id, shapes, colours)
		return _part_entry(id, key, modelled)
	var apply := func(e: Dictionary) -> void:
		for k in e.baked:
			var img := BakeCache.unpack(e.baked[k].img)
			PartShape.baked[k] = {"img": img, "tex": ImageTexture.create_from_image(img), "origin": e.baked[k].origin, "scale": e.baked[k].scale}
		PartShape.rigs.merge(e.rigs, true)
	return _job("part|%s|%s|%d" % [key, ART_SCALE * UNIT_SCALE, UNIT_BANDS], "part", 1 + 8 * int(modelled), "Mustering the armies",
		PartShape.baked.has(key), make, apply)


## What a part bake made, to keep: its sprites (every facing, front layers) and rigs.
func _part_entry(id: String, key: String, modelled: bool) -> Dictionary:
	var e := {"baked": {}, "rigs": {}}
	for k in (8 if modelled else 1):
		var kk := key + PartShape.facing_suffix(k) if modelled else key
		for name in [kk, PartShape.front_key(kk)]:
			if PartShape.baked.has(name):
				var b: Dictionary = PartShape.baked[name]
				e.baked[name] = {"img": BakeCache.pack(b.img), "origin": b.origin, "scale": b.scale}
		var rig := id + PartShape.facing_suffix(k)
		if PartShape.rigs.has(rig):
			e.rigs[rig] = PartShape.rigs[rig]
	return e


## Prop jobs: nine props to a render, each render a job (so several bakers share them).
func _props_jobs() -> Array:
	if _models == null:
		_models = Models.new()
		_models.mats.matte = true
	var specs := _doodad_specs()
	var ids := []
	# [list, per render, shadow, columns, shadow reach, what the loader says]
	var groups := [[specs[0], 9, true, 3, 1.0, "Growing the reeds"], [specs[1], 9, false, 3, 1.0, "Growing the reeds"],
		[specs[2], 4, true, 2, 2.0, "Planting the woods"], [specs[3], 1, true, 1, 1.0, "Building the bridges"]]   # bridges: one to a whole frame (a long one overflows a third)
	for g in groups:
		var list: Array = g[0]
		for first in range(0, list.size(), g[1]):
			var todo: Array = list.slice(first, first + g[1])
			var shadow: bool = g[2]
			var cols: int = g[3]
			var reach: float = g[4]
			var make := func(baker) -> Dictionary:
				var made: Dictionary = await _bake_set(baker, todo, shadow, cols, reach)
				bakes.merge(made, true)
				return {"bakes": _pack_bakes(made)}
			var apply := func(e: Dictionary) -> void:
				_unpack_bakes(e.bakes)
			ids.append(_job("props|%s" % ",".join(todo.map(func(t): return t[0])), "hifi", 4 if shadow else 2, g[5],
				bakes.has(todo[0][0]), make, apply))
	return ids


## A building job for each look of each building of these races' cultures (town centre and
## houses first: they stand from the first second).
func _building_jobs(races: Array) -> Array:
	var archs := []
	for r in races:
		var a: String = lib.architecture(r)
		if not a in archs:
			archs.append(a)
	archs.sort()
	var d: Dictionary = _buildings_data()
	var types: Array = ["town_center", "house"]
	for t in d.menu.civilian + d.menu.military:
		if not t in types:
			types.append(t)
	var rest: Array = d.buildings.keys().filter(func(t): return not t in types and d.buildings[t].get("status", "") != "planned")
	rest.sort()
	types.append_array(rest)   # built but in no menu: what research turns a building into (the Bastion)
	var ids := []
	for arch in archs:
		for type in types:
			ids.append(_building_job(d, arch, type))
			var looks: Dictionary = d.get("age_looks", {}).get(arch, {}).get(type, {})
			for age in looks:   # the same building, grown with the ages (a culture's story, D-081)
				ids.append(_building_job(d, arch, type, looks[age], "@" + str(age)))
			for v in range(1, int(d.get("variants", {}).get(type, 1))):   # a few of each house, turned and sized apart
				ids.append(_building_job(d, arch, type, "", "#" + str(v)))
			if bool(d.buildings[type].get("gate", false)):   # gates face the way their wall runs, diagonals too
				for suffix in ALONG.slice(1):
					ids.append(_building_job(d, arch, type, "", suffix))
	return ids


func _building_job(d: Dictionary, arch: String, type: String, model := "", suffix := "") -> String:
	var name := "%s:%s%s" % [arch, type, suffix]
	var make := func(baker) -> Dictionary:
		var e: Dictionary = await _bake_building(baker, _models, arch, type, model, suffix)
		bakes.merge(e.bakes, true)
		buildings[name] = e.info
		var keep: Dictionary = e.info.duplicate()
		if keep.has("banner"):
			keep.banner = {"img": BakeCache.pack((keep.banner.tex as Texture2D).get_image()), "origin": keep.banner.origin}
		return {"bakes": _pack_bakes(e.bakes), "info": keep}
	var apply := func(e: Dictionary) -> void:
		_unpack_bakes(e.bakes)
		var info: Dictionary = e.info
		if info.has("banner"):
			info.banner = {"tex": ImageTexture.create_from_image(BakeCache.unpack(info.banner.img)), "origin": info.banner.origin}
		buildings[name] = info
	var label: String = d.buildings[type].get("name", type.capitalize())
	return _job("bld|%s|%s" % [name, model], "hifi", 22, "Raising the %s" % label.to_lower(), buildings.has(name), make, apply)


func _pack_bakes(made: Dictionary) -> Dictionary:
	var out := {}
	for n in made:
		out[n] = {"img": BakeCache.pack(made[n].img), "origin": made[n].origin}
	return out


func _unpack_bakes(packed: Dictionary) -> void:
	for n in packed:
		bakes[n] = {"img": BakeCache.unpack(packed[n].img), "origin": packed[n].origin}


## A baker for buildings and props, with the shared models (their noise textures ready).
func _hifi_baker() -> Node:
	if _models == null:
		_models = Models.new()
		_models.mats.matte = true
	var baker := Baker.new()
	add_child(baker)
	baker.set_pixel_mode(ART_SCALE, SS)
	baker.outline = false   # props and buildings are drawn realistically, without the units' outline
	for name in MATERIALS:
		var m: StandardMaterial3D = _models.mats.get_mat(name)
		for t in [m.albedo_texture, m.normal_texture]:
			while t != null and t.get_image() == null:   # noise textures build in a thread
				await get_tree().process_frame
	return baker


## A portrait of every unit of these races, for the command panel: each unit's own
## UnitView (its baked parts, in its team colour) rendered in one SubViewport at two
## screen pixels per art pixel, cropped square. Needs the atlas built. Keys: "side:slot" (the
## line's first step) and "side:slot@age" for every step (the tech tree page shows each).
## Each portrait is painted once per recipe and team (_icon_cache): baking again after one side
## changed paints only that side's new ones.
func bake_icons(races: Array, teams: Array) -> void:
	await _icons(_icon_list(races, teams, range(races.size())))


## [team, unit or line step, icon key] for every line and step of these races (sides: their keys').
func _icon_list(races: Array, teams: Array, sides: Array) -> Array:
	var list := []
	for k in races.size():
		var side: int = sides[k]
		for u in races[k].units:
			list.append([teams[k], u, "%d:%s" % [side, u.recipe.slot]])
			for l in u.get("line", []):
				list.append([teams[k], l, "%d:%s@%d" % [side, u.recipe.slot, int(l.age)]])
	return list


static func _icon_key(recipe: Dictionary, team: Color) -> String:
	return "%s|%s" % [team.to_html(false), var_to_str(recipe).md5_text()]


## Portraits for a list from _icon_list: those not painted yet are painted (each recipe and team
## once), then every key gets its picture.
func _icons(all: Array) -> void:
	var todo := []
	var asked := {}
	for e in all:
		var ck := _icon_key(e[1].recipe, e[0])
		if not _icon_cache.has(ck) and not asked.has(ck):
			asked[ck] = true
			todo.append(e)
	if not todo.is_empty():
		await _paint_icons(todo)
	for e in all:
		icons[e[2]] = _icon_cache[_icon_key(e[1].recipe, e[0])]


func _paint_icons(list: Array) -> void:
	var cols := 8
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.size = Vector2i(cols, ceili(list.size() / float(cols))) * ICON_CELL
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var zoom := ART_SCALE * 2.0
	for k in list.size():
		var u: Dictionary = list[k][1]
		var view := UnitView.new()
		view.build(u.recipe, lib, list[k][0], u.eval.speed)
		view.scale = Vector2.ONE * UNIT_SCALE * zoom
		view.position = Vector2(0.5, 0.8) * ICON_CELL
		view.set_process(false)       # a still pose
		view.get_child(0).visible = false   # no ground shadow
		var hold := Control.new()     # its own cell: a big unit is cut at the edge, never drawn into its neighbour's
		hold.clip_contents = true
		hold.position = Vector2(k % cols, k / cols) * ICON_CELL
		hold.size = Vector2.ONE * ICON_CELL
		hold.add_child(view)
		vp.add_child(hold)
	await get_tree().process_frame   # the views draw themselves (a deferred call) before the render
	await BakeClock.render(vp)
	var img := vp.get_texture().get_image()
	for k in list.size():
		var cell := img.get_region(Rect2i(Vector2i(k % cols, k / cols) * ICON_CELL, Vector2i.ONE * ICON_CELL))
		_icon_cache[_icon_key(list[k][1].recipe, list[k][0])] = ImageTexture.create_from_image(frame_icon(cell))
	vp.queue_free()


const ICON_THIN := 5        # a row or column with fewer opaque pixels than this is a pole, a lance or a tail
const ICON_MARGIN := 0.12   # the body's share of room left round it in a portrait (each side)
const ICON_MIN := 54        # the least portrait side in render pixels: a small unit isn't blown up past readability
const ICON_WIDE := 0.65     # a long body (a newt, a ram) is framed on this share of its length: its ends are cut, not the whole shrunk

## A unit's portrait cut from its render: a square framed on its body (Dominic: "why size
## difference?": a lance, a banner pole or a long tail made the whole box, so cavalry and
## standard bearers came out tiny next to a spearman). The body is what's left when rows and
## columns with only a thin pole, lance or tail in them are trimmed off the edges; the square is
## that, with a consistent margin, feet near the bottom; what sticks out past it is cut, as a
## portrait crops (and a long body is framed on ICON_WIDE of its length, round its weight). Never
## smaller than ICON_MIN, so a worker reads at about a spearman's size.
static func frame_icon(cell: Image) -> Image:
	var used := cell.get_used_rect()
	if used.size.x == 0:
		return Image.create(4, 4, false, Image.FORMAT_RGBA8)
	var rows := PackedInt32Array()
	rows.resize(cell.get_height())
	var colsn := PackedInt32Array()
	colsn.resize(cell.get_width())
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			if cell.get_pixel(x, y).a > 0.1:
				rows[y] += 1
				colsn[x] += 1
	var y0 := used.position.y
	var y1 := used.end.y - 1
	var x0 := used.position.x
	var x1 := used.end.x - 1
	while y0 < y1 and rows[y0] < ICON_THIN:
		y0 += 1
	while y1 > y0 and rows[y1] < ICON_THIN:
		y1 -= 1
	while x0 < x1 and colsn[x0] < ICON_THIN:
		x0 += 1
	while x1 > x0 and colsn[x1] < ICON_THIN:
		x1 -= 1
	var body := Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
	var side := maxi(roundi(maxf(body.size.y, body.size.x * ICON_WIDE) * (1.0 + 2.0 * ICON_MARGIN)), ICON_MIN)
	# Across, centred on the body's weight (a rider on a long mount, not the middle of mount and
	# tail); lowered if need be so its feet (the used rect's foot) stay in.
	var sum := 0
	var mass := 0
	for x in range(body.position.x, body.end.x):
		sum += x * colsn[x]
		mass += colsn[x]
	var mid: int = sum / maxi(mass, 1)
	mid = clampi(mid, body.position.x + side / 2, body.end.x - side / 2) if side < body.size.x else body.position.x + body.size.x / 2
	var src := Rect2i(mid - side / 2, body.position.y - (side - body.size.y) / 2, side, side)
	src.position.y = maxi(src.position.y, mini(used.end.y + 2 - side, body.position.y))
	var sq := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var clip := src.intersection(Rect2i(Vector2i.ZERO, cell.get_size()))
	sq.blit_rect(cell, clip, clip.position - src.position)
	return sq


## The model function for a building type in an architecture (farms are the same everywhere).
static func _model(arch: String, type: String) -> String:
	match type:
		"town_center":
			return TOWN[arch]
		"house":
			return HOUSE[arch]
		"farm":
			return "farm_plot"
	return "%s_%s" % [type, arch]   # barracks_thatch, stable_stone, watchtower_tent...


## A building's model spec (town centres, houses and farms by name, the rest by type and culture).
func _spec(models, arch: String, type: String, model := "") -> Dictionary:
	if model != "":
		return models.call(model, PartShape.TEAM_KEY)
	if type in ["town_center", "house", "farm"]:
		return models.call(_model(arch, type), PartShape.TEAM_KEY)
	return models.building(type, arch, PartShape.TEAM_KEY)


## A building's model at its size and turn: houses a little smaller than halls, a culture's
## own scale for a type (data: buildings.json "scale", e.g. the rats' house and barracks), and
## a variant's turn or mirror and nudge in size (data: "variants"), so a street of houses varies.
func _placed(models, arch: String, type: String, model: String, suffix: String) -> Dictionary:
	var diagonal: bool = suffix in ALONG.slice(2)
	models.gate_span = 3.0 * (sqrt(2.0) if diagonal else 1.0)   # a diagonal gate runs corner to corner across its square
	var spec: Dictionary = _spec(models, arch, type, model)
	models.gate_span = 3.0
	var d: Dictionary = _buildings_data()
	var s: float = (HOUSE_SCALE if type == "house" else 1.0) * float(d.get("scale", {}).get(arch, {}).get(type, 1.0))
	var look := Basis.IDENTITY
	var v := int(suffix.get_slice("#", 1)) if "#" in suffix else 0
	if v > 0:
		look = _variant_look(spec, "%s:%s" % [arch, type], v)
		s *= [1.0, 0.94, 1.05, 0.9][v % 4]
	if suffix == ALONG_Z:
		look = Basis(Vector3.UP, deg_to_rad(90.0))   # a gate in a line running along sim y
	elif diagonal:   # model x is sim x, z sim y: an eighth turn lays it along (1, 1) or (1, -1)
		look = Basis(Vector3.UP, deg_to_rad(-45.0 if suffix == ALONG[2] else 45.0))
	if s == 1.0 and look == Basis.IDENTITY:
		return spec
	var basis := look.scaled(Vector3.ONE * s)
	for key in ["body", "banner", "vane", "open"]:
		if spec.has(key):
			var holder := Node3D.new()
			holder.add_child(spec[key])
			holder.transform.basis = basis
			spec[key] = holder
	for key in ["smoke", "lantern", "banner_pivot", "vane_pivot"]:
		if spec.has(key):
			spec[key] = basis * spec[key]
	spec.lights = spec.get("lights", []).map(func(p): return basis * p)
	if spec.has("doorway"):
		spec.doorway = spec.doorway.map(func(p): return basis * p)
	return spec


## data/buildings.json, read once (a building's model is placed several times per bake).
func _buildings_data() -> Dictionary:
	if _bdata.is_empty():
		_bdata = DataLib.load_json("res://data/buildings.json")
	return _bdata


## The bake camera looks from +x +z (baker.gd: yaw 45), so a face whose outward direction
## leans this way is one of the two walls we see.
const SEEN := Vector3(1, 0, 1)


## The turn (and maybe mirror) of a building's variant v: only ones that keep the door the model
## declares (spec "door", its outward direction) on a seen wall, those that also keep its
## "window" in view first, so no variant shows only blank walls (Dominic: "sometimes we see
## nothing"). Mirrored across the x = z diagonal, a building swaps its two seen walls.
func _variant_look(spec: Dictionary, name: String, v: int) -> Basis:
	assert(spec.has("door"), "%s has variants but its model declares no door" % name)
	var door: Vector3 = spec.door
	var window: Vector3 = spec.get("window", door)
	assert(door.dot(SEEN) > 0.0, "%s: its door faces away from the camera unturned" % name)
	var mirror := Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(1, 0, 0))
	var both := []
	var door_only := []
	for flip in [Basis.IDENTITY, mirror]:
		for q in 4:
			var b: Basis = Basis(Vector3.UP, q * PI / 2.0) * flip
			if b == Basis.IDENTITY or (b * door).dot(SEEN) <= 0.0:
				continue
			(both if (b * window).dot(SEEN) > 0.0 else door_only).append(b)
	var looks: Array = [Basis.IDENTITY] + both + door_only
	return looks[v % looks.size()]


## The look of a building for a player in an age: its latest age look that's baked (data:
## buildings.json "age_looks"), else the one it starts with.
func building_key(arch: String, type: String, age: int, pick := 0) -> String:
	for a in range(age, 1, -1):
		var key := "%s:%s@%d" % [arch, type, a]
		if buildings.has(key):
			return key
	var variant := "%s:%s#%d" % [arch, type, pick]   # a variant (houses), if this building drew one
	return variant if pick > 0 and buildings.has(variant) else "%s:%s" % [arch, type]


## A building's picture for a button: its finished bake, from the atlas.
## Cached: the command panel rebuilds its buttons when its content changes, and a new texture
## every frame made it rebuild every frame, so clicks never landed.
## Baked since the atlas was last built (the lobby's tech tree doesn't rebuild it): its own texture.
func building_icon(arch: String, type: String) -> Texture2D:
	var key := "%s:%s" % [arch, type]
	var name: String = buildings[key].get("icon", buildings[key].body)
	var tex: Texture2D = _building_icons.get(key)
	if not regions.has(name) or PartShape.atlas == null:
		if not tex is ImageTexture:
			tex = ImageTexture.create_from_image(bakes[name].img)
			_building_icons[key] = tex
		return tex
	var at := tex as AtlasTexture
	if at == null or at.atlas != PartShape.atlas:
		at = AtlasTexture.new()
		at.atlas = PartShape.atlas
		at.region = regions[name]
		_building_icons[key] = at
	return at


## A wall tile's look with arms to the neighbours in `links` (bit k: Models.LINKS[k]), made
## from the baked post and arms on first use and kept: {tex, origin}. Arms going up the screen
## lie under the post, those coming down over it; every piece's ground shadow goes down first,
## the darkest wins where they overlap (so they never double up), and no shadow covers the wall.
func wall_look(name: String, links: int) -> Dictionary:
	var key := "%s|%d" % [name, links]
	if _wall_looks.has(key):
		return _wall_looks[key]
	var info: Dictionary = buildings[name]
	var under := []
	var over := []
	var front := []   # the near merlons of the same pieces, in the same order: drawn over units on the walkway
	for k in Models.LINKS.size():
		if links & (1 << k):
			var d: Vector2i = Models.LINKS[k]
			(under if d.x + d.y <= 0 else over).append(k)
	for k in under + [-1] + over:
		var f: String = info.get("front", "") if k < 0 else info.get("arms_front", [])[k] if info.has("arms_front") else ""
		if f != "":
			front.append(f)
	var look := _compose(under.map(func(k): return info.arms[k]) + [info.body] + over.map(func(k): return info.arms[k]))
	if not front.is_empty():
		var f := _compose(front)
		look.front_tex = f.tex
		look.front_origin = f.origin
	_wall_looks[key] = look
	return look


## Lay baked pieces (names, bottom first) on one image, all anchored on the same point: every
## piece's ground shadow first, the darkest wins where they overlap, then the art. {tex, origin}.
func _compose(pieces: Array) -> Dictionary:
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := -lo
	for p in pieces:
		var o: Vector2i = Vector2i((bakes[p].origin as Vector2).round())
		var sz: Vector2i = (bakes[p].img as Image).get_size()
		lo = Vector2i(mini(lo.x, -o.x), mini(lo.y, -o.y))
		hi = Vector2i(maxi(hi.x, sz.x - o.x), maxi(hi.y, sz.y - o.y))
	var w := hi.x - lo.x
	var h := hi.y - lo.y
	var out := PackedByteArray()
	out.resize(w * h * 4)
	for pass_art in [false, true]:
		for p in pieces:
			var img: Image = bakes[p].img
			if img.get_format() != Image.FORMAT_RGBA8:
				img = img.duplicate()
				img.convert(Image.FORMAT_RGBA8)
			var src := img.get_data()
			var iw := img.get_width()
			var at: Vector2i = -Vector2i((bakes[p].origin as Vector2).round()) - lo
			for y in img.get_height():
				var row := ((at.y + y) * w + at.x) * 4
				for x in iw:
					var s := (y * iw + x) * 4
					var a := src[s + 3]
					if a == 0 or (a == 255) != pass_art:
						continue
					var o := row + x * 4
					if not pass_art and out[o + 3] >= a:
						continue   # a shadow already as dark (or darker) here
					out[o] = src[s]
					out[o + 1] = src[s + 1]
					out[o + 2] = src[s + 2]
					out[o + 3] = a
	return {"tex": ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)), "origin": Vector2(-lo)}


## Canvas px a model unit of height rises on screen: the bake camera looks down 30 degrees.
const WALK_PX_PER_UNIT := Baker.PX_PER_UNIT * 0.8660254

## A walkway's near merlons (Models.merlon) on `root`: hide them (front_only false: the body's bake)
## or show only them (true: the front layer's bake). A merlon is near when it stands on the camera's
## side of its wall's line (or of the piece's middle, for a post or tower): sim x + y larger. Returns
## how many there are.
static func front_split(root: Node3D, front_only: bool) -> int:
	var n := 0
	var stack := [[root, root.transform]]
	while not stack.is_empty():
		var top: Array = stack.pop_back()
		var node: Node3D = top[0]
		var t: Transform3D = top[1]
		for c in node.get_children():
			if c is Node3D:
				stack.append([c, t * (c as Node3D).transform])
		if not node is MeshInstance3D:
			continue
		var front := false
		if node.has_meta("parapet"):
			var p := Vector3(t.origin.x, 0, t.origin.z)
			if node.has_meta("about"):   # measured from a point of its own (a gatehouse tower's middle), not the piece's
				var o: Vector3 = (t * node.transform.affine_inverse()) * (node.get_meta("about") as Vector3)
				p -= Vector3(o.x, 0, o.z)
			var along: Vector3 = t.basis * (node.get_meta("parapet") as Vector3)
			along.y = 0
			if along.length() > 0.001:
				along = along.normalized()
				p -= along * p.dot(along)   # off the wall's line through the piece's middle
			front = p.x + p.z > 0.04
		if front:
			n += 1
		node.visible = front if front_only else not front
	return n


## The front layer of a walkway piece: only its near merlons, baked without a shadow. {img, origin}.
func _bake_front(baker, node: Node3D) -> Dictionary:
	front_split(node, true)
	var f: Dictionary = await baker.bake(node, [Vector3.ZERO])
	return {"img": (f.tex as Texture2D).get_image(), "origin": f.points[0]}


## A gatehouse's flanking towers (Models: nodes tagged "gate_part") that stand lower on screen than its
## middle (the right one along x, the lower one along y, the near one on the down-screen diagonal) get
## a layer of their own, sorted on the tower's middle: the tower again (its body, lit and shadowed as in
## the whole: the rest of the gate casts shadows only) and its near parts (hoarding, posts, roof) alone.
## They draw over units up on the rest of the gate that they hide (a tower straight down the screen
## hides the walk behind it), and units on the tower stand between the two (BuildingArt.perch_sort_at).
## info.parts: [{body, front, at}], at: the tower's middle from the gate's (sim tiles).
func _bake_gate_parts(baker, models, arch: String, type: String, model: String, suffix: String, name: String, made: Dictionary, info: Dictionary) -> void:
	var probe: Dictionary = _placed(models, arch, type, model, suffix)
	var tags := []
	for part in probe.body.find_children("*", "Node3D", true, false):
		if part.has_meta("gate_part"):
			var c: Vector3 = _to_root(part, probe.body) * (part.get_meta("gate_centre") as Vector3)
			if c.x + c.z > 0.3:
				tags.append([int(part.get_meta("gate_part")), Vector2(c.x, c.z)])
	probe.body.free()
	probe.open.free()
	info.parts = []
	for tg in tags:
		var key := "%s:tower%d" % [name, tg[0]]
		var whole: Dictionary = _placed(models, arch, type, model, suffix)
		front_split(whole.body, false)
		for mi in whole.body.find_children("*", "MeshInstance3D", true, false):
			if _part_of(mi) != tg[0]:
				(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		var b: Dictionary = await baker.bake(whole.body, [Vector3.ZERO])
		whole.open.free()
		made[key] = {"img": (b.tex as Texture2D).get_image(), "origin": b.points[0]}
		var fr: Dictionary = _placed(models, arch, type, model, suffix)
		front_split(fr.body, true)
		for mi in fr.body.find_children("*", "MeshInstance3D", true, false):
			if _part_of(mi) != tg[0]:
				mi.visible = false
		var f: Dictionary = await baker.bake(fr.body, [Vector3.ZERO])
		fr.open.free()
		made[key + ":front"] = {"img": (f.tex as Texture2D).get_image(), "origin": f.points[0]}
		var sc := float(_buildings_data().get("scale", {}).get(arch, {}).get(type, 1.0))
		info.parts.append({"body": key, "front": key + ":front", "at": tg[1] * sc})


## The gate part (Models "gate_part": a tower's side) a mesh belongs to, 0 for none.
static func _part_of(node: Node) -> int:
	var n := node
	while n != null:
		if n.has_meta("gate_part"):
			return int(n.get_meta("gate_part"))
		n = n.get_parent()
	return 0


## Node's transform into root's space.
static func _to_root(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return (root.transform if n == root else Transform3D.IDENTITY) * t


## The animals (data/animals.json) as one more "race" to bake: their recipes, never a player's.
const ANIMAL_TEAM := Color("#8a7a5a")   # nobody's: a wild animal shows no team

static func animal_race() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals.json"))
	var units := []
	var ids: Array = d.animals.keys()
	ids.sort()
	for id in ids:
		units.append({"recipe": d.animals[id].recipe, "eval": {"speed": int(d.animals[id].speed)}})
	return {"units": units}


## Only the units (the Race Lab bakes per generated race), then the atlas.
func prepare_units(races: Array, teams: Array) -> void:
	await bake_units(races, teams)
	rebuild_atlas()


func rebuild_atlas() -> void:
	var extras := {}
	for name in bakes:
		extras[name] = bakes[name].img
	regions = PartShape.build_atlas(extras)
	_dirty = false
	atlas_rebuilt.emit()


## Every part of every unit of these races (skips what's baked; loads what's on disk).
## Parts bake in the team key, so the teams don't matter here.
func bake_units(races: Array, _teams := []) -> void:
	var ids := _unit_jobs(races)
	_ask(ids, true)
	await _await_jobs(ids)
	PartShape.bake_flat("unit_shadow", UnitView.SHADOW_SHAPES, UnitView.SHADOW_COLOURS, ART_SCALE * UNIT_SCALE)


## Resource props and ground doodads (once per run).
func bake_props() -> void:
	var ids := _props_jobs()
	_ask(ids, true)
	await _await_jobs(ids)


## Each culture's buildings for these races (skips what's baked).
func bake_buildings(races: Array) -> void:
	var ids := _building_jobs(races)
	_ask(ids, true)
	await _await_jobs(ids)


## Every variant (and cut-down stage) of every prop, as [[name, make model], ...] for the
## shadowed ones and for those flat on the ground.
func _doodad_specs() -> Array:
	var props := PropModels.new()
	var models: Models = _models
	var shadowed := []
	for v in DOODADS.reeds:
		for st in STAGES:
			shadowed.append([staged("reeds", v, st), func(): return props.reed_clump(300 + v, 1.0, st)])
	for v in DOODADS.bush:
		for st in STAGES:
			shadowed.append([staged("bush", v, st), func(): return props.bug_bush(400 + v, st)])
	for v in DOODADS.rock:
		shadowed.append(["rock%d" % v, func(): return props.boulders(1000 + v)])
	for v in DOODADS.quarry:
		for st in STAGES:
			shadowed.append([staged("quarry", v, st), func(): return props.quarry(1300 + v, st)])
			shadowed.append([staged("gold", v, st), func(): return props.quarry(1300 + v, st, "gold")])   # the same deposits, gold showing
	var trees := []         # tall: baked two to a row, with room for their long shadows
	var tm := TreeModels.new()
	for kind in TREES:
		var species: String = kind.trim_prefix("tree_")
		for v in DOODADS[kind]:
			for st in STAGES:
				trees.append([staged(kind, v, st), func(): return tm.tree(1500 + v, species, TREE_STYLE[species], st)])
	for v in DOODADS.carcass:
		for st in STAGES:
			shadowed.append([staged("carcass", v, st), func(): return props.carcass(1400 + v, st)])
	shadowed.append(["rally_flag", func(): return models.rally_flag(Color(PartShape.TEAM_KEY))])
	shadowed.append(["waypoint_flag", func(): return models.waypoint_flag(Color(PartShape.TEAM_KEY))])
	var flat := []
	for v in DOODADS.stones:
		flat.append(["stones%d" % v, func(): return props.field_stones(500 + v)])
	for v in DOODADS.tuft:
		flat.append(["tuft%d" % v, func(): return props.grass_tuft(600 + v)])
	for v in DOODADS.flowers:
		flat.append(["flowers%d" % v, func(): return models.flowers(800 + v)])
	for v in DOODADS.shore:
		flat.append(["shore%d" % v, func(): return props.reed_clump(700 + v, 0.55)])
	for v in DOODADS.lily:
		flat.append(["lily%d" % v, func(): return props.lily_pads(900 + v)])
	for v in DOODADS.crops:
		flat.append(["crops%d" % v, func(): return props.crops(1100 + v)])
	for v in DOODADS.paddy:
		flat.append(["paddy%d" % v, func(): return props.paddy(1200 + v)])
	var bridges := []       # map bridges: every size a map uses, both ways, standing and broken
	var bm := BridgeModels.new()
	for size in bridge_sizes():
		for broken in 2:
			for along in 2:
				bridges.append([bridge_name(size.x, along, broken, size.y), func():
					var m: Node3D = bm.bridge(1700 + size.x, size.x, BRIDGE_STYLE, broken, size.y)
					if along == 1:
						m.basis = Basis(Vector3.UP, deg_to_rad(90.0))   # running along sim y
					return m])
	# Town life props (milestone 17): drop-off piles by resource in three stages ("pile.food.2"),
	# a house's yard and garden as they grow ("yard2", "garden3"), the stable's tether post.
	var tp := TownProps.new()
	tp.models = models
	for kind in TownProps.PILE_KINDS:
		for st in range(1, TownProps.STAGES + 1):
			shadowed.append(["pile.%s.%d" % [kind, st], func(): return tp.pile(kind, st, PILE_STYLE[kind])])
	for st in range(1, TownProps.STAGES + 1):
		shadowed.append(["yard%d" % st, func(): return tp.yard(st)])
		flat.append(["garden%d" % st, func(): return tp.garden(st)])
	shadowed.append(["tether_post", func(): return tp.tether_post()])
	return [shadowed, flat, trees, bridges]


## Bake a few props in one render (bake_many: up to nine to a frame): name -> {img, origin}.
## Trees bake two to a row with room for long shadows (cols 2, reach 2).
func _bake_set(baker, todo: Array, shadow: bool, cols := 3, reach := 1.0) -> Dictionary:
	baker.set_ground_shadow(shadow)
	baker.shadow_reach = reach
	var out: Array = await baker.bake_many(todo.map(func(t): return t[1].call()), cols)
	baker.shadow_reach = 1.0
	baker.set_ground_shadow(false)
	var made := {}
	for i in todo.size():
		made[todo[i][0]] = {"img": (out[i].tex as Texture2D).get_image(), "origin": out[i].points[0]}
	return made


## How used-up a resource looks: its stage from what's left of what it started with.
## Whole until first used, then visibly started at once, then further down, then gone:
## reeds thin and leave stubble, bug bushes lose berries and colour, quarry stone loses blocks.
static func resource_stage(kind: String, left: int, full: int) -> int:
	if not kind in ["reeds", "bush", "quarry", "gold", "carcass"] and not kind in TREES:
		return 0   # only reeds, bug bushes and quarry stone have used-up stages
	if left <= 0:
		return STAGES - 1   # a tree's stump
	if left >= full:
		return 0   # whole until the first bite; started shows straight away (Dominic); a tree stands till its first chop
	var f := float(left) / float(full)
	if kind == "bush":
		return 1 if f > 0.5 else 2
	return 1 if f > 0.45 else 2


## The bake name of a map bridge: its length and width in tiles, along sim x (0) or y (1), broken or not.
static func bridge_name(length: int, along: int, broken: int, wide := 1) -> String:
	return "bridge%dx%d%s%s" % [length, wide, ALONG_Z if along == 1 else "", ".1" if broken == 1 else ""]


## Every bridge size the maps use, as (length, width) in tiles: a bridge runs along its longer
## side (along y when square), reading data/maps (data first: a new map's bridges just bake).
static func bridge_sizes() -> Array:
	var out := []
	for id in DataLib.Mods.map_ids():   # (the mods' maps too)
		var d: Dictionary = DataLib.load_json(DataLib.Mods.data_path("maps/%s.json" % id))
		for r in d.get("bridges", []):
			var sx := int(r[2]) - int(r[0]) + 1
			var sy := int(r[3]) - int(r[1]) + 1
			var size := Vector2i(maxi(sx, sy), mini(sx, sy))
			if not size in out:
				out.append(size)
	return out


## The bake name of a prop variant at a stage (stage 0 is the plain name).
static func staged(kind: String, variant: int, stage: int) -> String:
	return "%s%d" % [kind, variant] if stage == 0 else "%s%d.%d" % [kind, variant, stage]


## One look of a building, with its stages and extra parts: {bakes: name -> {img, origin}, info}.
func _bake_building(baker, models, arch: String, type: String, model := "", suffix := "") -> Dictionary:
	var name := "%s:%s%s" % [arch, type, suffix]
	var made := {}
	var spec: Dictionary = _placed(models, arch, type, model, suffix)
	var pts: Array = [Vector3.ZERO, spec.get("smoke", Vector3.ZERO), spec.get("lantern", Vector3.ZERO)]
	pts.append_array(spec.lights)
	var door: Array = spec.get("doorway", []).slice(0, 3)
	pts.append_array(door)
	var fronts := front_split(spec.body, false)   # a walkway's near merlons go in a layer of their own
	baker.set_ground_shadow(true)
	var body: Dictionary = await baker.bake(spec.body, pts)
	baker.set_ground_shadow(false)
	made[name] = {"img": (body.tex as Texture2D).get_image(), "origin": body.points[0]}
	var local := func(p: Vector2) -> Vector2: return (p - body.points[0]) / ART_SCALE
	var info := {"body": name, "lights": []}
	if Models.WALK_H.has(type):   # units on its walkway stand this high (canvas px), on the stone
		var sc := float(_buildings_data().get("scale", {}).get(arch, {}).get(type, 1.0))
		info.walk_px = Models.WALK_H[type] * sc * WALK_PX_PER_UNIT
		if spec.has("open") and type == "stone_gate":   # its flanking towers: units past this far along it from its middle stand on them
			info.walk_tower_px = Models.WALK_H.wall_tower * sc * WALK_PX_PER_UNIT
			info.walk_tower_from = Models.gate_tower_from(3.0 * (sqrt(2.0) if suffix in ALONG.slice(2) else 1.0)) * sc
	if fronts > 0:
		made[name + ":front"] = await _bake_front(baker, _placed(models, arch, type, model, suffix).body)
		info.front = name + ":front"
	if spec.has("smoke"):
		info.smoke = local.call(body.points[1])
	if spec.has("lantern"):
		info.lantern = local.call(body.points[2])
	for k in spec.lights.size():
		info.lights.append(local.call(body.points[3 + k]))
	if not door.is_empty():   # the doorway's three corners on screen, and whether it's round
		var at: int = 3 + spec.lights.size()
		info.doorway = {"corners": [local.call(body.points[at]), local.call(body.points[at + 1]), local.call(body.points[at + 2])],
			"round": spec.doorway.size() > 3}
	if spec.has("banner"):
		var ban: Dictionary = await baker.bake(spec.banner, [Vector3.ZERO])
		info.banner = {"tex": ban.tex, "origin": ban.points[0]}   # its own wave shader, so outside the atlas
	if spec.has("open"):   # a gate: its open look, shown while a friend goes through (shadowed like the shut one)
		var open_fronts := front_split(spec.open, false)
		baker.set_ground_shadow(true)
		var op: Dictionary = await baker.bake(spec.open, [Vector3.ZERO])
		baker.set_ground_shadow(false)
		made[name + ":open"] = {"img": (op.tex as Texture2D).get_image(), "origin": op.points[0]}
		info.open = name + ":open"
		if open_fronts > 0:
			made[name + ":open:front"] = await _bake_front(baker, _placed(models, arch, type, model, suffix).open)
			info.open_front = name + ":open:front"
		await _bake_gate_parts(baker, models, arch, type, model, suffix, name, made, info)
	if spec.has("arms"):   # a wall: an arm towards each of the eight neighbours (Models.LINKS), and a run for its picture
		baker.set_ground_shadow(true)
		info.arms = []
		info.arms_front = []
		var with_front := []
		for k in spec.arms.size():
			if front_split(spec.arms[k], false) > 0:
				with_front.append(k)
		var out: Array = await baker.bake_many(spec.arms + [spec.icon], 2)   # four to a render (a render is most of a bake): the tall curtain overflows a third of the frame
		for k in spec.arms.size():
			made["%s:arm%d" % [name, k]] = {"img": (out[k].tex as Texture2D).get_image(), "origin": out[k].points[0]}
			info.arms.append("%s:arm%d" % [name, k])
			info.arms_front.append("")
		made[name + ":icon"] = {"img": (out[-1].tex as Texture2D).get_image(), "origin": out[-1].points[0]}
		info.icon = name + ":icon"
		baker.set_ground_shadow(false)
		if not with_front.is_empty():   # the arms' near merlons, alone (no shadow: the arm's bake has it)
			var again: Dictionary = _placed(models, arch, type, model, suffix)
			var alone := []
			for k in with_front:
				front_split(again.arms[k], true)
				alone.append(again.arms[k])
			var fo: Array = await baker.bake_many(alone, 2)
			for n in with_front.size():
				var k: int = with_front[n]
				made["%s:arm%d:front" % [name, k]] = {"img": (fo[n].tex as Texture2D).get_image(), "origin": fo[n].points[0]}
				info.arms_front[k] = "%s:arm%d:front" % [name, k]
			for n in again.arms.size():
				if not n in with_front:
					again.arms[n].free()
			again.body.free()
			again.icon.free()
	if spec.has("vane"):
		var vane: Dictionary = await baker.bake(spec.vane, [Vector3.ZERO, spec.vane_pivot])
		made[name + ":vane"] = {"img": (vane.tex as Texture2D).get_image(), "origin": vane.points[1]}
		info.vane = name + ":vane"
		info.vane_at = (vane.points[1] - vane.points[0]) / ART_SCALE
	info.stages = []
	baker.set_ground_shadow(true)
	for st in BUILD_STAGES.size():
		var part: Dictionary = _placed(models, arch, type, model, suffix)
		_hold_back(part.body, st, models)
		for live in ["banner", "vane", "open"]:   # the live parts only go up when it's finished
			if part.has(live):
				part[live].free()
		for n in part.get("arms", []) + ([part.icon] if part.has("icon") else []):   # a wall goes up post first
			n.free()
		var sb: Dictionary = await baker.bake(part.body, [Vector3.ZERO])
		var sname := "%s:stage%d" % [name, st]
		made[sname] = {"img": (sb.tex as Texture2D).get_image(), "origin": sb.points[0]}
		info.stages.append(sname)
	baker.set_ground_shadow(false)
	return {"bakes": made, "info": info}


## A building under construction, from its own model with parts held back (see
## BUILD_STAGES), and a scaffold of poles and rails around the footprint up to just
## above what's built. Works on any architecture: foundations come first, walls rise,
## the roof goes on last.
func _hold_back(body: Node3D, stage: int, models) -> void:
	var cut: float = BUILD_STAGES[stage]
	var boxes := {}
	var all := AABB()
	var first := true
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D()
		var p: Node = mi
		while p != body:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		var b: AABB = t * (mi as MeshInstance3D).get_aabb()
		boxes[mi] = b
		all = b if first else all.merge(b)
		first = false
	var h := all.size.y
	var top := 0.0
	for mi in boxes:
		var b: AABB = boxes[mi]
		var at := (b.end.y if stage < 2 else b.get_center().y) - all.position.y
		if at > cut * h:
			mi.visible = false
		else:
			top = maxf(top, b.end.y)
	# The scaffold: poles at the corners and along the sides of the footprint, rails between.
	var wood: StandardMaterial3D = models.mats.get_mat("wood")
	var lo := Vector3(all.position.x - 0.04, 0.0, all.position.z - 0.04)
	var hi := Vector3(all.end.x + 0.04, 0.0, all.end.z + 0.04)
	var pole_h := maxf(top + 0.08, 0.22)
	var posts := []
	for fx in [0.0, 0.5, 1.0]:
		for fz in [0.0, 0.5, 1.0]:
			if fx == 0.5 and fz == 0.5:
				continue
			posts.append(Vector3(lerpf(lo.x, hi.x, fx), 0.0, lerpf(lo.z, hi.z, fz)))
	for q in posts:
		body.add_child(models.beam(q, q + Vector3(0, pole_h, 0), 0.016, wood))
	var ring := [posts[0], posts[1], posts[2], posts[4], posts[7], posts[6], posts[5], posts[3]]   # around the edge
	var levels := [pole_h * 0.5, pole_h - 0.03] if pole_h > 0.3 else [pole_h - 0.03]
	for y in levels:
		for k in ring.size():
			var a: Vector3 = ring[k]
			var c: Vector3 = ring[(k + 1) % ring.size()]
			body.add_child(models.beam(a + Vector3(0, y, 0), c + Vector3(0, y, 0), 0.011, wood))


## A sprite of a bake, anchored on its origin, drawn 1:1 in art pixels; team colour
## (for buildings) goes in self_modulate, as on units.
func sprite(name: String) -> Sprite2D:
	var b: Dictionary = bakes[name]
	var s := Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = PartShape.atlas
	at.region = regions[name]
	s.texture = at
	s.centered = false
	s.offset = -b.origin
	s.scale = Vector2.ONE / ART_SCALE
	s.material = PartShape.team_material
	return s


## A doodad sprite of a kind, varied by a cosmetic pick (and for resources, a stage).
func doodad(kind: String, pick: int, stage := 0) -> Sprite2D:
	return sprite(staged(kind, posmod(pick, DOODADS[kind]), stage))


## One palette for the whole frame: the terrain ramps, the building materials, and
## four shades of every skin, cloth, material and team colour in the data, merged
## down to 256 colours. Returned as a 1-pixel-high image.
static func palette(p_lib) -> Image:
	var cols: Array = [Color("#2b2620"), Color("#24180f"), Color("#0f0c08"), Color("#f4f0e0"), Color("#ffffff")]
	for hex in ["#3d5c24", "#4d6e2b", "#5c8033", "#6e8f3d", "#85a14a", "#30471c",
			"#4f4f26", "#5c5e2e", "#6b6b36", "#78753d",
			"#263d33", "#2e4a38", "#38543b", "#455c38", "#4d7a38",
			"#54452b", "#614f30", "#6e5c38", "#7a6942", "#3d3324",
			"#386b70", "#2b5560", "#1f4659", "#1a3852", "#8cb3a8", "#d9f2eb",
			"#4a2f1c", "#6e4a2c", "#8a6038", "#a67a48", "#c8a06a",
			"#6b5326", "#a8883e", "#c9a652", "#e0c070",
			"#6a5236", "#8c7048", "#b0915e",
			"#4a4842", "#5c5a52", "#86827a", "#a29e94", "#c0bcb0",
			"#3e2616", "#ffcf6a", "#f2d78a", "#ffe9b0", "#c8c8c0", "#a0a09a", "#7fb6c8", "#e0607f",
			"#a4492a", "#c0623a", "#e2d8c2", "#d4c6a8"]:
		cols.append(Color(hex))
	var bases: Array = []
	for k in p_lib.palettes.skins:
		for c in p_lib.palettes.skins[k]:
			bases.append(Color(c))
	for k in p_lib.palettes.materials:
		bases.append(Color(p_lib.palettes.materials[k]))
	for k in p_lib.families:
		for c in p_lib.families[k].cloth:
			bases.append(Color(c))
	for c in p_lib.palettes.teams:
		bases.append(Color(c))
	for c in bases:
		for shade in [c.darkened(0.5), c.darkened(0.25), c, c.lightened(0.25)]:
			cols.append(shade)
	var uniq := {}
	var list := []
	for c in cols:
		var key: String = c.to_html(false)
		if not uniq.has(key):
			uniq[key] = true
			list.append(c)
	list = _limit(list, 256)
	var img := Image.create(list.size(), 1, false, Image.FORMAT_RGBA8)
	for i in list.size():
		img.set_pixel(i, 0, list[i])
	return img


## At most n colours: repeatedly merge the two nearest (perceptually weighted) into
## their average. The first five (background, outlines, white) are kept exact.
static func _limit(list: Array, n: int) -> Array:
	var cols := list.duplicate()
	while cols.size() > n:
		var best := INF
		var bi := 0
		var bj := 0
		for i in range(5, cols.size()):
			for j in range(i + 1, cols.size()):
				var a: Color = cols[i]
				var b: Color = cols[j]
				var d := 0.3 * (a.r - b.r) ** 2 + 0.59 * (a.g - b.g) ** 2 + 0.11 * (a.b - b.b) ** 2
				if d < best:
					best = d
					bi = i
					bj = j
		cols[bi] = (cols[bi] as Color).lerp(cols[bj], 0.5)
		cols.remove_at(bj)
	return cols
