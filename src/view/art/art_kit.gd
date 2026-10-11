extends Node
## Everything the pixel-art look needs for one match, baked once: every part of both
## races' units, each culture's buildings, resource props (reeds, bug bushes, rock)
## and ground doodads, all packed into the shared atlas (PartShape.atlas). Sprites
## made here share one material, so the whole y-sorted layer batches.
## View side only; the sim never sees any of this.

const PartShape := preload("res://src/part_shape.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const Baker := preload("res://src/view/art/bake/baker.gd")
const Models := preload("res://src/view/art/bake/models.gd")
const PropModels := preload("res://scenes/art_pixel/prop_models.gd")

const ART_SCALE := 1.5     # art pixels per canvas unit (a tile is 96 x 48 art pixels)
const UNIT_SCALE := 0.85   # units at about a third of a building's height
const SS := 4              # supersampling for the building and prop bakes
const HOUSE_SCALE := 1.3
## Parts a worker swaps in by job (see UnitView.set_tool and sim_debug's _tool_for).
const JOB_PARTS := ["tool.axe", "tool.basket", "tool.hammer", "tool.pick", "load.reeds", "load.stone"]
const ICON_CELL := 160     # screen pixels per unit when rendering portraits   # houses read about 2.5x a footman
const TOWN := {"thatch": "town_center", "junk": "junk_town_center", "stone": "stone_town_center", "tent": "tent_town_center",
	"reed": "reed_town_center", "mound": "mound_town_center"}
const HOUSE := {"thatch": "stilt_house", "junk": "tin_can_house", "stone": "villa_house", "tent": "tent_house",
	"reed": "reed_house", "mound": "mound_house"}
const MATERIALS := ["wood", "thatch", "mud", "stone", "tin", "brick", "plaster", "terracotta", "terracotta_dark", "felt", "weave"]
## Prop and doodad kinds and how many variants of each (each a different shape, size
## and turn; picked per tile so neighbours differ).
const DOODADS := {"reeds": 6, "bush": 6, "rock": 6, "stones": 6, "tuft": 6, "flowers": 6, "shore": 4, "lily": 4, "crops": 4, "paddy": 4}
## Resources show how much is left: reeds and bug bushes each have this many stages
## (0 whole ... 3 nearly gone: stubble for reeds, a bare brown bush).
const STAGES := 4
## A building under construction shows four stages: foundations; the scaffold with what
## stands low; the walls; the roof going on. Each keeps the parts whose top (first two)
## or middle (last two) is below this fraction of the building's height.
const BUILD_STAGES := [0.15, 0.4, 0.45, 0.72]

var lib
var bakes := {}       # name -> {img: Image, origin: Vector2 (baked px of the anchor)}
var regions := {}     # name -> Rect2 in the atlas
var buildings := {}   # "arch:type" -> {body, smoke, lantern, lights, banner, vane, vane_at, stages} (canvas units from the centre)
var icons := {}       # "side:slot" -> Texture2D: a portrait of that unit, rendered from its baked art


## Bake what these races need (anything already baked is kept), then rebuild the atlas.
## Prints how long each part took (bake time at match start is a budget we watch).
func prepare(races: Array, teams: Array) -> void:
	var t0 := Time.get_ticks_msec()
	await bake_units(races, teams)
	var t1 := Time.get_ticks_msec()
	await bake_props()
	var t2 := Time.get_ticks_msec()
	await bake_buildings(races)
	var t3 := Time.get_ticks_msec()
	rebuild_atlas()
	var t4 := Time.get_ticks_msec()
	await bake_icons(races, teams)
	print("Art kit: units %d ms, props %d ms, buildings %d ms, atlas %d ms, icons %d ms" % [t1 - t0, t2 - t1, t3 - t2, t4 - t3, Time.get_ticks_msec() - t4])


## A portrait of every unit of these races, for the command panel: each unit's own
## UnitView (its baked parts, in its team colour) rendered in one SubViewport at two
## screen pixels per art pixel, cropped square. Needs the atlas built.
func bake_icons(races: Array, teams: Array) -> void:
	var list := []
	for side in races.size():
		for u in races[side].units:
			list.append([side, u])
	var cols := 6
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
		view.build(u.recipe, lib, teams[list[k][0]], u.eval.speed)
		view.scale = Vector2.ONE * UNIT_SCALE * zoom
		view.position = Vector2(k % cols + 0.5, k / cols + 0.8) * ICON_CELL
		view.set_process(false)       # a still pose
		view.get_child(0).visible = false   # no ground shadow
		vp.add_child(view)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	for k in list.size():
		var cell := img.get_region(Rect2i(Vector2i(k % cols, k / cols) * ICON_CELL, Vector2i.ONE * ICON_CELL))
		var used := cell.get_used_rect()
		var side := maxi(used.size.x, used.size.y) + 4
		var sq := Image.create(side, side, false, Image.FORMAT_RGBA8)
		sq.blit_rect(cell, used, Vector2i((side - used.size.x) / 2, side - used.size.y - 2))
		icons["%d:%s" % [list[k][0], list[k][1].recipe.slot]] = ImageTexture.create_from_image(sq)
	vp.queue_free()


## The model function for a building type in an architecture (farms are the same everywhere).
func _model(arch: String, type: String) -> String:
	match type:
		"town_center":
			return TOWN[arch]
		"house":
			return HOUSE[arch]
		"farm":
			return "farm_plot"
	return "%s_%s" % [type, arch]   # barracks_thatch, stable_stone, watchtower_tent...


## A building's picture for a button: its finished bake, from the atlas.
func building_icon(arch: String, type: String) -> Texture2D:
	var at := AtlasTexture.new()
	at.atlas = PartShape.atlas
	at.region = regions[buildings["%s:%s" % [arch, type]].body]
	return at


## Only the units (the Race Lab bakes per generated race), then the atlas.
func prepare_units(races: Array, teams: Array) -> void:
	await bake_units(races, teams)
	rebuild_atlas()


func rebuild_atlas() -> void:
	var extras := {}
	for name in bakes:
		extras[name] = bakes[name].img
	regions = PartShape.build_atlas(extras)


## Every part of every unit of these races, in each side's team key (skips what's baked).
func bake_units(races: Array, teams: Array) -> void:
	var pb := PartBaker.new()
	pb.art_scale = ART_SCALE * UNIT_SCALE   # baked at the size they're drawn: crisp pixels
	add_child(pb)
	for side in races.size():
		var steps := []
		for u in races[side].units:   # every age of every unit line: ageing up never waits on a bake
			for l in u.get("line", [{"recipe": u.recipe, "eval": u.eval}]):
				steps.append(l)
		for u in steps:
			var probe := UnitView.new()
			probe.build(u.recipe, lib, teams[side], u.eval.speed)
			for ps in probe.find_children("*", "Node2D", true, false):
				if ps is PartShape and ps.part_id != "":
					await pb.bake(ps.part_id, ps.shapes, ps.colours)
			probe.free()
			if u.recipe.slot == "worker":
				# Workers change tools for the job and carry their load home in their hands.
				var colours := UnitView.colours_for(lib, u.recipe.skin, u.recipe.family, teams[side])
				for id in JOB_PARTS:
					await pb.bake(id, lib.part(id).shapes, colours)
	pb.queue_free()
	PartShape.bake_flat("unit_shadow", UnitView.SHADOW_SHAPES, UnitView.SHADOW_COLOURS, ART_SCALE * UNIT_SCALE)


func _hifi() -> Array:
	var models := Models.new()
	models.mats.matte = true
	var baker := Baker.new()
	add_child(baker)
	baker.set_pixel_mode(ART_SCALE, SS)
	baker.outline = false   # props and buildings are drawn realistically, without the units' outline
	for name in MATERIALS:
		var m: StandardMaterial3D = models.mats.get_mat(name)
		for t in [m.albedo_texture, m.normal_texture]:
			while t != null and t.get_image() == null:   # noise textures build in a thread
				await get_tree().process_frame
	return [baker, models]


## Resource props and ground doodads (once per run).
func bake_props() -> void:
	if bakes.has("reeds0"):
		return
	var h: Array = await _hifi()
	await _bake_doodads(h[0], h[1])
	h[0].queue_free()


## Each culture's buildings for these races (skips what's baked).
func bake_buildings(races: Array) -> void:
	var archs := []
	for r in races:
		var a: String = lib.architecture(r)
		if not a in archs and not buildings.has(a + ":house"):
			archs.append(a)
	if archs.is_empty():
		return
	archs.sort()
	var h: Array = await _hifi()
	for arch in archs:
		for type in ["town_center", "house", "farm", "barracks", "stable", "watchtower"]:
			await _bake_building(h[0], h[1], arch, type)
	h[0].queue_free()


## Every variant (and cut-down stage) of every prop, several to a render.
func _bake_doodads(baker, models) -> void:
	var props := PropModels.new()
	var shadowed := {}      # name -> model
	for v in DOODADS.reeds:
		for st in STAGES:
			shadowed[staged("reeds", v, st)] = props.reed_clump(300 + v, 1.0, st)
	for v in DOODADS.bush:
		for st in STAGES:
			shadowed[staged("bush", v, st)] = props.bug_bush(400 + v, st)
	for v in DOODADS.rock:
		shadowed["rock%d" % v] = props.boulders(1000 + v)
	var flat := {}
	for v in DOODADS.stones:
		flat["stones%d" % v] = props.field_stones(500 + v)
	for v in DOODADS.tuft:
		flat["tuft%d" % v] = props.grass_tuft(600 + v)
	for v in DOODADS.flowers:
		flat["flowers%d" % v] = models.flowers(800 + v)
	for v in DOODADS.shore:
		flat["shore%d" % v] = props.reed_clump(700 + v, 0.55)
	for v in DOODADS.lily:
		flat["lily%d" % v] = props.lily_pads(900 + v)
	for v in DOODADS.crops:
		flat["crops%d" % v] = props.crops(1100 + v)
	for v in DOODADS.paddy:
		flat["paddy%d" % v] = props.paddy(1200 + v)
	baker.set_ground_shadow(true)
	await _bake_set(baker, shadowed)
	baker.set_ground_shadow(false)
	await _bake_set(baker, flat)


func _bake_set(baker, todo: Dictionary) -> void:
	var names := todo.keys()
	var out: Array = await baker.bake_many(names.map(func(k): return todo[k]))
	for i in names.size():
		bakes[names[i]] = {"img": (out[i].tex as Texture2D).get_image(), "origin": out[i].points[0]}


## How used-up a resource looks: its stage from what's left of what it started with.
## Reeds thin out, then are mostly cut, and leave stubble when used up; bug bushes
## lose berries and colour in four steps.
static func resource_stage(kind: String, left: int, full: int) -> int:
	if kind != "reeds" and kind != "bush":
		return 0   # only reeds and bug bushes have used-up stages
	if left <= 0:
		return STAGES - 1
	var f := float(left) / float(full)
	if kind == "reeds":
		return 0 if f > 0.7 else (1 if f > 0.35 else 2)
	return 0 if f > 0.75 else (1 if f > 0.5 else (2 if f > 0.25 else 3))


## The bake name of a prop variant at a stage (stage 0 is the plain name).
static func staged(kind: String, variant: int, stage: int) -> String:
	return "%s%d" % [kind, variant] if stage == 0 else "%s%d.%d" % [kind, variant, stage]


func _bake(baker, name: String, model: Node3D) -> void:
	var b: Dictionary = await baker.bake(model, [Vector3.ZERO])
	bakes[name] = {"img": (b.tex as Texture2D).get_image(), "origin": b.points[0]}


func _bake_building(baker, models, arch: String, type: String) -> void:
	var name := "%s:%s" % [arch, type]
	if buildings.has(name):
		return
	var spec: Dictionary = models.call(_model(arch, type), PartShape.TEAM_KEY)
	if type == "house":
		spec.body.scale = Vector3.ONE * HOUSE_SCALE
		if spec.has("smoke"):
			spec.smoke *= HOUSE_SCALE
		spec.lantern *= HOUSE_SCALE
		spec.lights = spec.lights.map(func(p): return p * HOUSE_SCALE)
	var pts: Array = [Vector3.ZERO, spec.get("smoke", Vector3.ZERO), spec.get("lantern", Vector3.ZERO)]
	pts.append_array(spec.lights)
	baker.set_ground_shadow(true)
	var body: Dictionary = await baker.bake(spec.body, pts)
	baker.set_ground_shadow(false)
	bakes[name] = {"img": (body.tex as Texture2D).get_image(), "origin": body.points[0]}
	var local := func(p: Vector2) -> Vector2: return (p - body.points[0]) / ART_SCALE
	var info := {"body": name, "lights": []}
	if spec.has("smoke"):
		info.smoke = local.call(body.points[1])
	if spec.has("lantern"):
		info.lantern = local.call(body.points[2])
	for k in spec.lights.size():
		info.lights.append(local.call(body.points[3 + k]))
	if spec.has("banner"):
		var ban: Dictionary = await baker.bake(spec.banner, [Vector3.ZERO])
		info.banner = {"tex": ban.tex, "origin": ban.points[0]}   # its own wave shader, so outside the atlas
	if spec.has("vane"):
		var vane: Dictionary = await baker.bake(spec.vane, [Vector3.ZERO, spec.vane_pivot])
		bakes[name + ":vane"] = {"img": (vane.tex as Texture2D).get_image(), "origin": vane.points[1]}
		info.vane = name + ":vane"
		info.vane_at = (vane.points[1] - vane.points[0]) / ART_SCALE
	info.stages = []
	baker.set_ground_shadow(true)
	for st in BUILD_STAGES.size():
		var part: Dictionary = models.call(_model(arch, type), PartShape.TEAM_KEY)
		if type == "house":
			part.body.scale = Vector3.ONE * HOUSE_SCALE
		_hold_back(part.body, st, models)
		for live in ["banner", "vane"]:   # the live parts only go up when it's finished
			if part.has(live):
				part[live].free()
		var sb: Dictionary = await baker.bake(part.body, [Vector3.ZERO])
		var sname := "%s:stage%d" % [name, st]
		bakes[sname] = {"img": (sb.tex as Texture2D).get_image(), "origin": sb.points[0]}
		info.stages.append(sname)
	baker.set_ground_shadow(false)
	buildings[name] = info


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
