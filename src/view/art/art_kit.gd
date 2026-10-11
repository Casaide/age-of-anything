extends Node
## Everything the pixel-art look needs for one match, baked once: every part of both
## races' units, each culture's buildings, resource props (reeds, bug bushes, rock)
## and ground doodads, all packed into the shared atlas (PartShape.atlas). Sprites
## made here share one material, so the whole y-sorted layer batches.
## View side only; the sim never sees any of this.

const PartShape := preload("res://src/part_shape.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const Baker := preload("res://scenes/style_sampler/hifi/baker.gd")
const Models := preload("res://scenes/style_sampler/hifi/models.gd")
const PropModels := preload("res://scenes/art_pixel/prop_models.gd")

const ART_SCALE := 1.5     # art pixels per canvas unit (a tile is 96 x 48 art pixels)
const UNIT_SCALE := 0.85   # units at about a third of a building's height
const SS := 4              # supersampling for the building and prop bakes
const HOUSE_SCALE := 1.3   # houses read about 2.5x a footman
const TOWN := {"thatch": "town_center", "junk": "junk_town_center", "stone": "stone_town_center", "tent": "tent_town_center"}
const HOUSE := {"thatch": "stilt_house", "junk": "tin_can_house", "stone": "villa_house", "tent": "tent_house"}
const MATERIALS := ["wood", "thatch", "mud", "stone", "tin", "brick", "plaster", "terracotta", "terracotta_dark", "felt", "weave"]
## Doodad kinds and how many bakes of each.
const DOODADS := {"reeds": 4, "bush": 3, "rock": 3, "stones": 4, "tuft": 4, "flowers": 6, "shore": 4, "lily": 4}

var lib
var bakes := {}       # name -> {img: Image, origin: Vector2 (baked px of the anchor)}
var regions := {}     # name -> Rect2 in the atlas
var buildings := {}   # "arch:type" -> {body, smoke, lantern, lights, banner, vane, vane_at} (canvas units from the centre)


## Bake what these races need (anything already baked is kept), then rebuild the atlas.
func prepare(races: Array, teams: Array) -> void:
	var pb := PartBaker.new()
	pb.art_scale = ART_SCALE * UNIT_SCALE   # baked at the size they're drawn: crisp pixels
	add_child(pb)
	for side in races.size():
		for u in races[side].units:
			var probe := UnitView.new()
			probe.build(u.recipe, lib, teams[side], u.eval.speed)
			for ps in probe.find_children("*", "Node2D", true, false):
				if ps is PartShape and ps.part_id != "":
					await pb.bake(ps.part_id, ps.shapes, ps.colours)
			probe.free()
	pb.queue_free()
	PartShape.bake_flat("unit_shadow", UnitView.SHADOW_SHAPES, UnitView.SHADOW_COLOURS, ART_SCALE * UNIT_SCALE)

	var models := Models.new()
	models.mats.matte = true
	var baker := Baker.new()
	add_child(baker)
	baker.set_pixel_mode(ART_SCALE, SS)
	for name in MATERIALS:
		var m: StandardMaterial3D = models.mats.get_mat(name)
		for t in [m.albedo_texture, m.normal_texture]:
			while t != null and t.get_image() == null:   # noise textures build in a thread
				await get_tree().process_frame
	await _bake_doodads(baker, models)
	var archs := []
	for r in races:
		var a: String = lib.families[r.family].get("architecture", "thatch")
		if not a in archs:
			archs.append(a)
	archs.sort()
	for arch in archs:
		for type in ["town_center", "house"]:
			await _bake_building(baker, models, arch, type)
	baker.queue_free()

	var extras := {}
	for name in bakes:
		extras[name] = bakes[name].img
	regions = PartShape.build_atlas(extras)


func _bake_doodads(baker, models) -> void:
	if bakes.has("reeds0"):
		return
	var props := PropModels.new()
	baker.set_ground_shadow(true)
	for k in DOODADS.reeds:
		await _bake(baker, "reeds%d" % k, props.reed_clump(300 + k))
	for k in DOODADS.bush:
		await _bake(baker, "bush%d" % k, props.bug_bush(400 + k))
	for k in DOODADS.rock:
		await _bake(baker, "rock%d" % k, props.boulders(1000 + k))
	baker.set_ground_shadow(false)
	for k in DOODADS.stones:
		await _bake(baker, "stones%d" % k, models.stones(500 + k))
		await _bake(baker, "tuft%d" % k, models.tuft(600 + k))
		await _bake(baker, "shore%d" % k, props.reed_clump(700 + k, 0.55))
		await _bake(baker, "lily%d" % k, props.lily_pads(900 + k))
	for k in DOODADS.flowers:
		await _bake(baker, "flowers%d" % k, models.flowers(800 + k))


func _bake(baker, name: String, model: Node3D) -> void:
	var b: Dictionary = await baker.bake(model, [Vector3.ZERO])
	bakes[name] = {"img": (b.tex as Texture2D).get_image(), "origin": b.points[0]}


func _bake_building(baker, models, arch: String, type: String) -> void:
	var name := "%s:%s" % [arch, type]
	if buildings.has(name):
		return
	var spec: Dictionary = models.call(TOWN[arch] if type == "town_center" else HOUSE[arch], PartShape.TEAM_KEY)
	if type != "town_center":
		spec.body.scale = Vector3.ONE * HOUSE_SCALE
		spec.smoke *= HOUSE_SCALE
		spec.lantern *= HOUSE_SCALE
		spec.lights = spec.lights.map(func(p): return p * HOUSE_SCALE)
	var pts: Array = [Vector3.ZERO, spec.smoke, spec.lantern]
	pts.append_array(spec.lights)
	baker.set_ground_shadow(true)
	var body: Dictionary = await baker.bake(spec.body, pts)
	baker.set_ground_shadow(false)
	bakes[name] = {"img": (body.tex as Texture2D).get_image(), "origin": body.points[0]}
	var local := func(p: Vector2) -> Vector2: return (p - body.points[0]) / ART_SCALE
	var info := {"body": name, "smoke": local.call(body.points[1]), "lantern": local.call(body.points[2]), "lights": []}
	for k in spec.lights.size():
		info.lights.append(local.call(body.points[3 + k]))
	if spec.has("banner"):
		var ban: Dictionary = await baker.bake(spec.banner, [Vector3.ZERO])
		info.banner = {"tex": ban.tex, "origin": ban.points[0]}   # its own wave shader, so outside the atlas
		var vane: Dictionary = await baker.bake(spec.vane, [Vector3.ZERO, spec.vane_pivot])
		bakes[name + ":vane"] = {"img": (vane.tex as Texture2D).get_image(), "origin": vane.points[1]}
		info.vane = name + ":vane"
		info.vane_at = (vane.points[1] - vane.points[0]) / ART_SCALE
	buildings[name] = info


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


## A doodad sprite of a kind, varied by a cosmetic pick.
func doodad(kind: String, pick: int) -> Sprite2D:
	return sprite("%s%d" % [kind, posmod(pick, DOODADS[kind])])


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
