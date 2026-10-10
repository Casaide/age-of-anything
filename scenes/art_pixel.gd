extends Control
## Art direction candidate: high-fidelity pixel art. Our original units, part for
## part, baked from simple lit 3D into pixel sprites; detailed buildings baked the
## same way with ground shadows and a little life; continuous terrain with round
## shorelines and no grid; the whole frame through one shared palette at art
## resolution, scaled up with nearest. Keys: Z zoom (1x/2x/3x), P palette on/off,
## arrows/WASD pan.

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const Iso := preload("res://src/view/iso.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const Baker := preload("res://scenes/style_sampler/hifi/baker.gd")
const Models := preload("res://scenes/style_sampler/hifi/models.gd")

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
const W := 16
const H := 14
const BG := Color("#2b2620")

var lib
var box: SubViewportContainer
var vp: SubViewport
var world: Node2D
var layer: Node2D
var cam: Camera2D
var label: Label
var palette_mat: ShaderMaterial
var shrink := 2
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
	var races := [gen.generate(PROMPTS[0], rules), gen.generate(PROMPTS[1], rules)]

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

	# Buildings and props: detailed models, matte, baked to pixels with ground shadows.
	var models := Models.new()
	models.mats.matte = true
	var baker := Baker.new()
	add_child(baker)
	baker.set_pixel_mode(ART_SCALE, SS)
	await _wait_for_textures(models)
	var reed_bakes := []
	for k in 3:
		reed_bakes.append(await baker.bake(models.reeds(300 + k), [Vector3.ZERO]))
	var bush_bake := await baker.bake(models.bug_bush(400), [Vector3.ZERO])
	for y in H:
		for x in W:
			var ch := _at(x, y)
			if ch == "\"" or ch == "b":
				var holder := Node2D.new()
				holder.position = Iso.to_screen(x * 1000 + 500, y * 1000 + 500)
				holder.add_child(_sprite(reed_bakes[(x * 3 + y) % 3] if ch == "\"" else bush_bake, Vector2.ZERO))
				layer.add_child(holder)
	var team0 := Color(lib.palettes.teams[0])
	await _building(baker, models.town_center(team0), 6, 4, 3)
	await _building(baker, models.stilt_house(team0), 2, 8, 2)
	await _building(baker, models.stilt_house(Color(lib.palettes.teams[1])), 11, 9, 2)
	baker.queue_free()

	for p in picks:
		var u: Dictionary = races[p[0]].units[p[1]]
		for n in p[2]:
			var view := UnitView.new()
			view.style = "baked"
			view.build(u.recipe, lib, Color(lib.palettes.teams[p[0]]), u.eval.speed)
			view.scale = Vector2(UNIT_SCALE, UNIT_SCALE)
			var c: Vector2 = p[3]
			var r: float = p[4]
			var area := Rect2(Iso.to_screen(c.x * 1000, c.y * 1000) - Vector2(r * 40, r * 16), Vector2(r * 80, r * 32))
			view.position = area.position + area.size * Vector2(randf(), randf())
			view.face(1.0 if p[0] == 0 else -1.0)
			view.wander_in(area)
			layer.add_child(view)

	_palette()
	cam.position = Iso.to_screen(7500, 6500) * ART_SCALE
	label.text = "High-fidelity pixel art    Z zoom   P palette on/off   WASD/arrows pan"
	built = true


func _at(x: int, y: int) -> String:
	var row: String = ROWS[y]
	return row[x] if x < row.length() else "."


func _wait_for_textures(models) -> void:
	for name in ["wood", "thatch", "mud", "stone", "grass"]:
		var m: StandardMaterial3D = models.mats.get_mat(name)
		for t in [m.albedo_texture, m.normal_texture]:
			while t.get_image() == null:
				await get_tree().process_frame


## A baked sprite drawn 1:1 in art pixels inside the scaled world.
func _sprite(b: Dictionary, at: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = b.tex
	s.centered = false
	s.offset = -b.points[0]
	s.scale = Vector2.ONE / ART_SCALE
	s.position = at
	return s


# ------------------------------------------------------------------ terrain

func _terrain() -> void:
	var k := 4   # mask samples per tile
	var img := Image.create(W * k, H * k, false, Image.FORMAT_RGBA8)
	for y in H * k:
		for x in W * k:
			var ch := _at(x / k, y / k)
			img.set_pixel(x, y, Color(1.0 if ch == "~" else 0.0, 1.0 if ch == "," else 0.0, 1.0 if ch == "\"" else 0.0, 1.0))
	var blurred := _blur(img, 5)
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Iso.to_screen(0, 0), Iso.to_screen(W * 1000, 0), Iso.to_screen(W * 1000, H * 1000), Iso.to_screen(0, H * 1000)])
	var m := ShaderMaterial.new()
	m.shader = load("res://scenes/art_pixel/terrain.gdshader")
	m.set_shader_parameter("masks", ImageTexture.create_from_image(blurred))
	m.set_shader_parameter("map_size", Vector2(W, H))
	poly.material = m
	world.add_child(poly)


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

func _building(baker, spec: Dictionary, cx: int, cy: int, size: int) -> void:
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
	holder.add_child(_sprite(body, centre_px - front))
	var to_local := func(p: Vector2) -> Vector2: return centre_px - front + (p - body.points[0]) / ART_SCALE
	_smoke(holder, to_local.call(body.points[1]))
	_glow(holder, to_local.call(body.points[2]), 14.0, Color(1.0, 0.75, 0.35))
	for k in spec.lights.size():
		_glow(holder, to_local.call(body.points[3 + k]), 9.0, Color(1.0, 0.8, 0.45))
	if spec.has("banner"):
		var ban: Dictionary = await baker.bake(spec.banner, [Vector3.ZERO, spec.banner_pivot])
		var bs := _sprite(ban, centre_px - front)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://scenes/style_sampler/hifi/banner.gdshader")
		bs.material = mat
		holder.add_child(bs)
		var vane: Dictionary = await baker.bake(spec.vane, [Vector3.ZERO, spec.vane_pivot])
		var pivot := Node2D.new()
		pivot.position = centre_px - front + (vane.points[1] - vane.points[0]) / ART_SCALE
		var vs := _sprite(vane, Vector2.ZERO)
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

## One palette for the whole frame: the terrain ramps, the building materials, and
## four shades of every skin, cloth, material and team colour in the data.
func _palette() -> void:
	var cols: Array = [BG, Color("#24180f"), Color("#0f0c08"), Color("#f4f0e0"), Color("#ffffff")]
	for hex in ["#3d5c24", "#4d6e2b", "#5c8033", "#6e8f3d", "#85a14a", "#30471c",
			"#4f4f26", "#5c5e2e", "#6b6b36", "#78753d",
			"#263d33", "#2e4a38", "#38543b", "#455c38", "#4d7a38",
			"#54452b", "#614f30", "#6e5c38", "#7a6942", "#3d3324",
			"#386b70", "#2b5560", "#1f4659", "#1a3852", "#8cb3a8", "#d9f2eb",
			"#4a2f1c", "#6e4a2c", "#8a6038", "#a67a48", "#c8a06a",
			"#6b5326", "#a8883e", "#c9a652", "#e0c070",
			"#6a5236", "#8c7048", "#b0915e",
			"#4a4842", "#5c5a52", "#86827a", "#a29e94", "#c0bcb0",
			"#3e2616", "#ffcf6a", "#f2d78a", "#ffe9b0", "#c8c8c0", "#a0a09a", "#7fb6c8", "#e0607f"]:
		cols.append(Color(hex))
	var bases: Array = []
	for k in lib.palettes.skins:
		for c in lib.palettes.skins[k]:
			bases.append(Color(c))
	for k in lib.palettes.materials:
		bases.append(Color(lib.palettes.materials[k]))
	for k in lib.families:
		for c in lib.families[k].cloth:
			bases.append(Color(c))
	for c in lib.palettes.teams:
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
	var img := Image.create(list.size(), 1, false, Image.FORMAT_RGBA8)
	for i in list.size():
		img.set_pixel(i, 0, list[i])
	palette_mat = ShaderMaterial.new()
	palette_mat.shader = load("res://scenes/art_pixel/palette.gdshader")
	palette_mat.set_shader_parameter("palette", ImageTexture.create_from_image(img))
	palette_mat.set_shader_parameter("count", list.size())
	box.material = palette_mat
	print("palette: %d colours" % list.size())


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	if not built:
		return
	time += delta
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
			KEY_P:
				if palette_mat:
					palette_mat.set_shader_parameter("enabled", not palette_mat.get_shader_parameter("enabled"))


func set_zoom(z: int) -> void:
	shrink = z
	box.stretch_shrink = z
