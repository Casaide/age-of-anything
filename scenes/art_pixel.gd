extends Control
## Art direction candidate: high-fidelity pixel art. Our original units, part for
## part, baked from simple lit 3D into pixel sprites; detailed buildings baked the
## same way with ground shadows and a little life; continuous terrain with round
## shorelines and no grid; the whole frame through one shared palette at art
## resolution, scaled up with nearest. Keys: Z zoom (1x/2x/3x), P palette on/off,
## arrows/WASD pan.

const HOUSE_SCALE := 1.3   # houses read about 2.5x a footman, as in the genre
const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const Iso := preload("res://src/view/iso.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const Baker := preload("res://src/view/art/bake/baker.gd")
const Models := preload("res://src/view/art/bake/models.gd")
const Paths := preload("res://scenes/art_pixel/paths.gd")
const PropModels := preload("res://scenes/art_pixel/prop_models.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")

const ART_SCALE := 1.5     # art pixels per canvas unit (a tile is 96 x 48 art pixels)
const SS := 4
const UNIT_SCALE := 0.85   # units at about a third of a building's height, as the genre does it
const PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers"]
const ROWS := [
	"\"\"\"\".............",
	"\"\"\"\".....\"\"......",
	"\"\"\"......\"\".~~~~.",
	"..........~~~~~.",
	"...bb.TTT.~~~~~.",
	"...bb.TTT\".~~~.\"\"",
	"...b..TTT.\"...\"\"",
	"................",
	"..hh............",
	"..hh.......hh...",
	"...........hh...",
	",,,,............",
	",,,,,...........",
	",,,,,...........",
]
## Buildings in the scene: top-left cell, size, owner (side).
const BUILDINGS := [[6, 4, 3, 0], [2, 8, 2, 0], [11, 9, 2, 1]]
const W := 16
const H := 14
const BG := Color("#2b2620")
const HELP := "High-fidelity pixel art    Z zoom   P palette   F stepped animation   B +200 units   WASD/arrows pan"

var lib
var box: SubViewportContainer
var vp: SubViewport
var world: Node2D
var layer: Node2D
var cam: Camera2D
var label: Label
var palette_mat: ShaderMaterial
var shrink := 2
var stepped := true       # F toggles stepped pixel animation
var units: Array = []
var unit_picks: Array = []
var pending: Array = []   # scene sprites waiting to move into the atlas
var bench_rng := RandomNumberGenerator.new()
var prompts: Array = []   # set before adding to the tree, else from the command line, else PROMPTS
var masks_img: Image      # blurred terrain masks (R water, G swamp, B reed bed)
var paths_img: Image      # blurred path masks, one channel per style (see paths.gd)
var races: Array = []
var glows: Array = []
var vanes: Array = []
var time := 0.0
var built := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	lib = DataLib.new()
	box = SubViewportContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.stretch = true
	box.stretch_shrink = shrink
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(box)
	vp = SubViewport.new()
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	box.add_child(vp)
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-4000, -4000)
	vp.add_child(bg)
	world = Node2D.new()
	world.scale = Vector2(ART_SCALE, ART_SCALE)
	vp.add_child(world)
	cam = Camera2D.new()
	vp.add_child(cam)
	label = Label.new()
	label.position = Vector2(12, 8)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 5)
	label.text = "Baking..."
	add_child(label)
	_build()


func _build() -> void:
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	if prompts.is_empty():
		var args := OS.get_cmdline_user_args()
		prompts = [args[0], args[1]] if args.size() > 1 and not args[0].ends_with(".png") and not args[0].begins_with("/") else PROMPTS.duplicate()
	races = [gen.generate(prompts[0], rules), gen.generate(prompts[1], rules)]

	_terrain()
	layer = Node2D.new()
	layer.y_sort_enabled = true
	world.add_child(layer)

	# Units: our parts, baked per colour set, then drawn by the usual UnitView.
	var part_baker := PartBaker.new()
	part_baker.art_scale = ART_SCALE * UNIT_SCALE   # baked at the size they're drawn: crisp pixels
	add_child(part_baker)
	var picks := [   # [side, roster index, count, area centre (tiles), radius]
		[0, 0, 3, Vector2(5.2, 7.6), 1.0], [0, 1, 2, Vector2(7.0, 9.6), 1.2], [0, 4, 1, Vector2(9.2, 8.2), 0.6],
		[1, 0, 2, Vector2(12.6, 7.6), 0.8], [1, 1, 2, Vector2(9.0, 11.8), 1.0], [1, 4, 1, Vector2(13.6, 12.0), 0.6],
	]
	for p in picks:
		var u: Dictionary = races[p[0]].units[p[1]]
		var team := Color(lib.palettes.teams[p[0]])
		var probe := UnitView.new()
		probe.build(u.recipe, lib, team, u.eval.speed)
		for ps in probe.find_children("*", "Node2D", true, false):
			if ps is PartShape and ps.part_id != "":
				await part_baker.bake(ps.part_id, ps.shapes, ps.colours)
		probe.free()
	part_baker.queue_free()
	PartShape.bake_flat("unit_shadow", UnitView.SHADOW_SHAPES, UnitView.SHADOW_COLOURS, ART_SCALE * UNIT_SCALE)
	unit_picks = picks

	# Buildings and props: detailed models, matte, baked to pixels with ground shadows.
	var models := Models.new()
	models.mats.matte = true
	var baker := Baker.new()
	add_child(baker)
	baker.set_pixel_mode(ART_SCALE, SS)
	await _wait_for_textures(models)
	var props := PropModels.new()
	baker.set_ground_shadow(true)
	var reed_bakes := []
	for k in 4:
		reed_bakes.append(await baker.bake(props.reed_clump(300 + k), [Vector3.ZERO]))
	var bush_bakes := []
	for k in 3:
		bush_bakes.append(await baker.bake(props.bug_bush(400 + k), [Vector3.ZERO]))
	baker.set_ground_shadow(false)
	for y in H:
		for x in W:
			var ch := _at(x, y)
			if ch == "\"" or ch == "b":
				var holder := Node2D.new()
				holder.position = Iso.to_screen(x * 1000 + 500, y * 1000 + 500)
				holder.add_child(_sprite(reed_bakes[(x * 3 + y) % 4] if ch == "\"" else bush_bakes[(x + y * 2) % 3], Vector2.ZERO))
				layer.add_child(holder)
	await _scatter(baker, models)
	# Each side builds in its own culture's architecture (families.json "architecture").
	for b in BUILDINGS:
		var side: int = b[3]
		var team := Color(lib.palettes.teams[side])
		var arch: String = lib.families[races[side].family].get("architecture", "thatch")
		# Baked in the team key, coloured per side by the team shader (like units).
		var key := PartShape.TEAM_KEY
		var town := {"thatch": "town_center", "junk": "junk_town_center", "stone": "stone_town_center", "tent": "tent_town_center"}
		var house := {"thatch": "stilt_house", "junk": "tin_can_house", "stone": "villa_house", "tent": "tent_house"}
		var spec: Dictionary = models.call(town[arch] if b[2] == 3 else house[arch], key)
		if b[2] != 3:
			_grow(spec, HOUSE_SCALE)
		await _building(baker, spec, b[0], b[1], b[2], team)
	baker.queue_free()
	# One atlas for every unit part and every scene sprite, with one shared material,
	# so the whole y-sorted layer can batch.
	var extras := {}
	for i in pending.size():
		extras[str(i)] = pending[i].get_meta("img")
	var regions := PartShape.build_atlas(extras)
	for i in pending.size():
		var at := AtlasTexture.new()
		at.atlas = PartShape.atlas
		at.region = regions[str(i)]
		pending[i].texture = at
		pending[i].material = PartShape.team_material

	for p in picks:
		var u: Dictionary = races[p[0]].units[p[1]]
		for n in p[2]:
			var view := UnitView.new()
			view.build(u.recipe, lib, Color(lib.palettes.teams[p[0]]), u.eval.speed)
			view.scale = Vector2(UNIT_SCALE, UNIT_SCALE)
			view.pose_steps = 8 if stepped else 0
			view.art_px = 1.0
			units.append(view)
			var c: Vector2 = p[3]
			var r: float = p[4]
			var area := Rect2(Iso.to_screen(c.x * 1000, c.y * 1000) - Vector2(r * 40, r * 16), Vector2(r * 80, r * 32))
			view.position = area.position + area.size * Vector2(randf(), randf())
			view.face(1.0 if p[0] == 0 else -1.0)
			view.wander_in(area)
			layer.add_child(view)

	_palette()
	cam.position = Iso.to_screen(7500, 6500) * ART_SCALE
	label.text = HELP
	built = true


## Little things that make ground feel lived in: stones, wildflowers, grass tufts,
## and reeds along the shoreline. Placed by a seeded scatter (cosmetic only),
## away from buildings, paths, water and resource tiles.
func _scatter(baker, models) -> void:
	var props := PropModels.new()
	var kinds := {"stones": [], "flowers": [], "tuft": [], "shore": [], "lily": []}
	for k in 4:
		kinds.stones.append(await baker.bake(models.stones(500 + k), [Vector3.ZERO]))
		kinds.tuft.append(await baker.bake(models.tuft(600 + k), [Vector3.ZERO]))
		kinds.shore.append(await baker.bake(props.reed_clump(700 + k, 0.55), [Vector3.ZERO]))
		kinds.lily.append(await baker.bake(props.lily_pads(900 + k), [Vector3.ZERO]))
	for k in 6:
		kinds.flowers.append(await baker.bake(models.flowers(800 + k), [Vector3.ZERO]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var want := {"stones": 26, "flowers": 46, "tuft": 70}
	for kind in ["stones", "flowers", "tuft"]:
		var placed := 0
		var tries := 0
		while placed < want[kind] and tries < 4000:
			tries += 1
			var t := Vector2(rng.randf_range(0.3, W - 0.3), rng.randf_range(0.3, H - 0.3))
			var ch := _at(int(t.x), int(t.y))
			var m := _mask(t)
			if ch != "." or m.r > 0.3 or _on_path(t) or _near_building(t):
				continue
			_doodad(kinds[kind][rng.randi() % kinds[kind].size()], t)
			placed += 1
	var lilies := 0
	for i in 3000:
		var t := Vector2(rng.randf_range(0.3, W - 0.3), rng.randf_range(0.3, H - 0.3))
		if _mask(t).r > 0.68:
			_doodad(kinds.lily[rng.randi() % kinds.lily.size()], t)
			lilies += 1
			if lilies >= 7:
				break
	var shore := 0
	for i in 3000:
		var t := Vector2(rng.randf_range(0.3, W - 0.3), rng.randf_range(0.3, H - 0.3))
		var m := _mask(t)
		if m.r > 0.4 and m.r < 0.5 and not _near_building(t):
			_doodad(kinds.shore[rng.randi() % kinds.shore.size()], t)
			shore += 1
			if shore >= 22:
				break


func _on_path(t: Vector2) -> bool:
	var k := paths_img.get_width() / W
	var c := paths_img.get_pixel(clampi(int(t.x * k), 0, paths_img.get_width() - 1), clampi(int(t.y * k), 0, paths_img.get_height() - 1))
	return maxf(maxf(c.r, c.g), maxf(c.b, c.a)) > 0.25


func _near_building(t: Vector2) -> bool:
	for y in range(int(t.y) - 1, int(t.y) + 2):
		for x in range(int(t.x) - 1, int(t.x) + 2):
			if x >= 0 and y >= 0 and x < W and y < H and _at(x, y) in ["T", "h", "b", "\""]:
				return true
	return false


func _doodad(b: Dictionary, t: Vector2) -> void:
	var holder := Node2D.new()
	holder.position = Iso.to_screen(t.x * 1000, t.y * 1000)
	holder.add_child(_sprite(b, Vector2.ZERO))
	layer.add_child(holder)


## Scale a building model and its live points (houses are built small; units need them bigger).
func _grow(spec: Dictionary, k: float) -> void:
	spec.body.scale = Vector3.ONE * k
	spec.smoke *= k
	spec.lantern *= k
	spec.lights = spec.lights.map(func(p): return p * k)


func _at(x: int, y: int) -> String:
	var row: String = ROWS[y]
	return row[x] if x < row.length() else "."


func _wait_for_textures(models) -> void:
	for name in ["wood", "thatch", "mud", "stone", "grass", "tin", "brick", "plaster", "terracotta", "terracotta_dark", "felt", "weave"]:
		var m: StandardMaterial3D = models.mats.get_mat(name)
		for t in [m.albedo_texture, m.normal_texture]:
			while t != null and t.get_image() == null:   # noise textures build in a thread
				await get_tree().process_frame


## A baked sprite drawn 1:1 in art pixels inside the scaled world.
func _sprite(b: Dictionary, at: Vector2, into_atlas := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = b.tex
	s.centered = false
	s.offset = -b.points[0]
	s.scale = Vector2.ONE / ART_SCALE
	s.position = at
	if into_atlas:
		s.set_meta("img", (b.tex as Texture2D).get_image())
		pending.append(s)
	return s


# ------------------------------------------------------------------ terrain

func _terrain() -> void:
	var k := 4   # mask samples per tile
	var img := Image.create(W * k, H * k, false, Image.FORMAT_RGBA8)
	for y in H * k:
		for x in W * k:
			var ch := _at(x / k, y / k)
			img.set_pixel(x, y, Color(1.0 if ch == "~" else 0.0, 1.0 if ch == "," else 0.0, 1.0 if ch == "\"" else 0.0, 0.0))
	var blurred := _blur(img, 5)
	masks_img = blurred
	var planned: Array = Paths.mask(W, H, k, _plan_paths())
	paths_img = _blur(planned[0], 2)
	var path_arc: Image = planned[1]
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Iso.to_screen(0, 0), Iso.to_screen(W * 1000, 0), Iso.to_screen(W * 1000, H * 1000), Iso.to_screen(0, H * 1000)])
	var m := ShaderMaterial.new()
	m.shader = load("res://scenes/art_pixel/terrain.gdshader")
	m.set_shader_parameter("masks", ImageTexture.create_from_image(blurred))
	m.set_shader_parameter("paths", ImageTexture.create_from_image(paths_img))
	m.set_shader_parameter("path_arc", ImageTexture.create_from_image(path_arc))
	m.set_shader_parameter("map_size", Vector2(W, H))
	poly.material = m
	world.add_child(poly)


## Each side's paths in its culture's style: from its main building's door to its
## other buildings, the nearest bug-bush and reed clusters and the shoreline.
func _plan_paths() -> Array:
	var owners := []
	for side in races.size():
		var mine := BUILDINGS.filter(func(b): return b[3] == side)
		if mine.is_empty():
			continue
		mine.sort_custom(func(a, b): return a[2] > b[2])   # the biggest is the hub
		var style: Dictionary = lib.families[races[side].family].get("paths", {"style": "trail", "width": 0.36})
		var hub := _door(mine[0])
		var targets := []
		for b in mine.slice(1):
			targets.append(_door(b))
		for kind in ["b", "\""]:
			var t := _nearest_cluster_edge(kind, hub)
			if t.x >= 0:
				targets.append(t)
		var shore := _nearest_shore(hub)
		if shore.x >= 0:
			targets.append(shore)
		owners.append({"style": style.style, "width": float(style.width), "hub": hub, "targets": targets})
	return Paths.plan(W, H, _blocked, owners)


## The spot in front of a building's door (doors face +y, the viewer's lower left).
func _door(b: Array) -> Vector2:
	return Vector2(b[0] + b[2] * 0.5, b[1] + b[2] + 0.45)


func _blocked(t: Vector2) -> bool:
	if t.x < 0.2 or t.y < 0.2 or t.x > W - 0.2 or t.y > H - 0.2:
		return true
	if _at(int(t.x), int(t.y)) in ["T", "h", "b", "\"", "~"]:
		return true
	return _mask(t).r > 0.3


## The free tile beside a cluster of this resource that's nearest the hub.
func _nearest_cluster_edge(kind: String, hub: Vector2) -> Vector2:
	var best := Vector2(-1, -1)
	var best_d := INF
	for y in H:
		for x in W:
			if _at(x, y) != kind:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var t := Vector2(x + d.x, y + d.y) + Vector2(0.5, 0.5)
				if not _blocked(t) and t.distance_to(hub) < best_d:
					best_d = t.distance_to(hub)
					best = t
	return best


func _nearest_shore(hub: Vector2) -> Vector2:
	var best := Vector2(-1, -1)
	var best_d := INF
	for y in H * 2:
		for x in W * 2:
			var t := Vector2(x + 0.5, y + 0.5) / 2.0
			var r := _mask(t).r
			if r > 0.12 and r < 0.28 and not _blocked(t) and t.distance_to(hub) < best_d:
				best_d = t.distance_to(hub)
				best = t
	return best


## A blurred mask channel (0..1) at a point in tile coordinates.
func _mask(t: Vector2) -> Color:
	var k := masks_img.get_width() / W
	var x := clampi(int(t.x * k), 0, masks_img.get_width() - 1)
	var y := clampi(int(t.y * k), 0, masks_img.get_height() - 1)
	return masks_img.get_pixel(x, y)


## Box blur, a few passes, edge-clamped: soft masks make round shorelines.
static func _blur(img: Image, passes: int) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var cur := img
	for p in passes:
		var nxt := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var acc := Color(0, 0, 0, 0)
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						acc += cur.get_pixel(clampi(x + dx, 0, w - 1), clampi(y + dy, 0, h - 1))
				nxt.set_pixel(x, y, acc / 9.0)
		cur = nxt
	return cur


# ------------------------------------------------------------------ buildings

func _building(baker, spec: Dictionary, cx: int, cy: int, size: int, team: Color) -> void:
	var tint := Color(team.r, team.g, team.b, 1.0)   # team colour for the shader, as on units
	var centre_px := Iso.to_screen((cx + size * 0.5) * 1000, (cy + size * 0.5) * 1000)
	var front := Iso.to_screen((cx + size) * 1000, (cy + size) * 1000)
	var holder := Node2D.new()
	holder.position = front
	layer.add_child(holder)
	var pts: Array = [Vector3.ZERO, spec.smoke, spec.lantern]
	pts.append_array(spec.lights)
	baker.set_ground_shadow(true)
	var body: Dictionary = await baker.bake(spec.body, pts)
	baker.set_ground_shadow(false)
	var body_sprite := _sprite(body, centre_px - front)
	body_sprite.self_modulate = tint
	holder.add_child(body_sprite)
	var to_local := func(p: Vector2) -> Vector2: return centre_px - front + (p - body.points[0]) / ART_SCALE
	_smoke(holder, to_local.call(body.points[1]))
	_glow(holder, to_local.call(body.points[2]), 14.0, Color(1.0, 0.75, 0.35))
	for k in spec.lights.size():
		_glow(holder, to_local.call(body.points[3 + k]), 9.0, Color(1.0, 0.8, 0.45))
	if spec.has("banner"):
		var ban: Dictionary = await baker.bake(spec.banner, [Vector3.ZERO, spec.banner_pivot])
		var bs := _sprite(ban, centre_px - front, false)   # has its own wave shader
		bs.self_modulate = tint
		var mat := ShaderMaterial.new()
		mat.shader = load("res://src/view/art/bake/banner.gdshader")
		bs.material = mat
		holder.add_child(bs)
		var vane: Dictionary = await baker.bake(spec.vane, [Vector3.ZERO, spec.vane_pivot])
		var pivot := Node2D.new()
		pivot.position = centre_px - front + (vane.points[1] - vane.points[0]) / ART_SCALE
		var vs := _sprite(vane, Vector2.ZERO)
		vs.self_modulate = tint
		vs.offset = -vane.points[1]
		pivot.add_child(vs)
		holder.add_child(pivot)
		vanes.append(pivot)


func _smoke(parent: Node2D, at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.amount = 10
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.direction = Vector2(0.2, -1)
	p.spread = 12.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector2(2.0, -1.0)
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.2
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.5))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(0.8, 0.8, 0.78, 0.0), Color(0.78, 0.78, 0.76, 0.55), Color(0.7, 0.7, 0.7, 0.0)])
	fade.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	p.color_ramp = fade
	p.texture = _dot(32)
	parent.add_child(p)


func _glow(parent: Node2D, at: Vector2, radius: float, c: Color) -> void:
	var s := Sprite2D.new()
	s.texture = _dot(32)
	s.position = at
	s.scale = Vector2.ONE * radius / 16.0
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	parent.add_child(s)
	glows.append({"node": s, "base": c, "phase": randf() * 10.0})


func _dot(size: int) -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t


# ------------------------------------------------------------------ palette

func _palette() -> void:
	var img: Image = ArtKit.palette(lib)
	palette_mat = ShaderMaterial.new()
	palette_mat.shader = load("res://scenes/art_pixel/palette.gdshader")
	palette_mat.set_shader_parameter("palette", ImageTexture.create_from_image(img))
	palette_mat.set_shader_parameter("count", img.get_width())
	box.material = palette_mat


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	if not built:
		return
	time += delta
	if Engine.get_frames_drawn() % 15 == 0:
		label.text = "%s\n%d units   %d draw calls   %.1f ms/frame   %d fps   atlas %s" % [HELP, units.size(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			1000.0 / maxf(Engine.get_frames_per_second(), 1.0), Engine.get_frames_per_second(), "on" if PartShape.use_atlas else "off"]
	for g in glows:
		var f := 0.8 + 0.2 * sin(time * 7.0 + g.phase) * sin(time * 2.3 + g.phase * 2.0)
		g.node.modulate = Color(g.base.r * f, g.base.g * f, g.base.b * f, 1.0)
	for v in vanes:
		v.scale.x = cos(time * 1.3)
	var pan := Vector2(float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	cam.position += pan * 300.0 * delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Z:
				set_zoom(1 + shrink % 3)
			KEY_B:
				spawn_bench(200)
			KEY_F:
				stepped = not stepped
				for v in units:
					v.pose_steps = 8 if stepped else 0
			KEY_P:
				if palette_mat:
					palette_mat.set_shader_parameter("enabled", not palette_mat.get_shader_parameter("enabled"))


## Benchmark: add n more units (the scene's unit types, cycled) wandering on open ground.
func spawn_bench(n: int) -> void:
	bench_rng.seed = 99 + units.size()
	for i in n:
		var p: Array = unit_picks[i % unit_picks.size()]
		var u: Dictionary = races[p[0]].units[p[1]]
		var view := UnitView.new()
		view.build(u.recipe, lib, Color(lib.palettes.teams[p[0]]), u.eval.speed)
		view.scale = Vector2(UNIT_SCALE, UNIT_SCALE)
		view.pose_steps = 8 if stepped else 0
		view.art_px = 1.0
		var t := Vector2(bench_rng.randf_range(1, W - 1), bench_rng.randf_range(1, H - 1))
		var area := Rect2(Iso.to_screen(t.x * 1000, t.y * 1000) - Vector2(40, 16), Vector2(80, 32))
		view.position = area.get_center()
		view.wander_in(area)
		layer.add_child(view)
		units.append(view)


func set_zoom(z: int) -> void:
	shrink = z
	box.stretch_shrink = z
