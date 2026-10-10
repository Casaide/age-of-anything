extends Control
## Art-direction sampler: the same little scene in five styles, side by side.
## Keys 1-5 show one style full-window, 0 shows them all. A tool for picking a
## direction, made from our placeholder parts: judge the direction, not the finish.

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const Diorama2D := preload("res://scenes/style_sampler/diorama_2d.gd")
const Diorama3D := preload("res://scenes/style_sampler/diorama_3d.gd")
const DioramaHifi := preload("res://scenes/style_sampler/hifi/diorama_hifi.gd")

const BG := Color("#2b2620")
const CARD := Color("#3a332b")
const TEXT_DIM := Color("#b8ad94")
const PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers"]
const GRID_ZOOM := 1.0          # real in-game scale: the whole patch fits
const CLOSE_ZOOM := 4.0         # one style full-window: close on the units
const CLOSE_AT := Vector2(3.2, 4.2)   # tile point the close-up centres on

const STYLES := [
	{"key": "storybook", "title": "1  Storybook vector",
		"note": "Our parts as they are, with cel shading, ink lines and eye glints. No art pipeline, and parametric parts stay free. Risk: can look flat or app-like."},
	{"key": "paper", "title": "2  Paper puppets",
		"note": "Cut paper on brass pins: rigid-part animation becomes the look. Parts are cheap (a shape plus a shared paper treatment). Risk: furthest from the classic RTS look."},
	{"key": "soft", "title": "3  Painterly (faked)",
		"note": "A painterly filter over unlined shapes, standing in for hand-painting. Real painted parts would be far richer, and far more work per part."},
	{"key": "toy", "title": "4  Toy diorama (real 3D)",
		"note": "Actually rendered: primitives, light, shadow, plastic. In production each part is rendered once and baked into the 2D atlas. Needs a Blender pipeline; materials swap for free."},
	{"key": "pixel", "title": "5  Pixel art",
		"note": "Rendered at 1/3 size, fewer colours. Readable and nostalgic, but watch the rotating parts shimmer: it fights our procedural animation."},
	{"key": "hifi", "title": "6  Pre-rendered, high fidelity",
		"note": "Detailed 3D models (procedural wood, thatch, mud, stone) baked at 4x into sprites with mipmaps; frog parts baked separately and animated in 2D. Buildings stay alive: banner, smoke, glowing windows, weathervane."},
]

var grid: GridContainer
var cells: Array = []
var close := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	margin.add_child(grid)

	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races := [gen.generate(PROMPTS[0], rules), gen.generate(PROMPTS[1], rules)]
	for st in STYLES:
		var cell := _cell(st.title, st.note)
		cells.append(cell)
		grid.add_child(cell)
		var box: SubViewportContainer = cell.get_meta("box")
		var vp: SubViewport = box.get_child(0)
		if st.key == "hifi":
			var dh := DioramaHifi.new()
			vp.add_child(dh)
			dh.build(lib)
			var cam_h := Camera2D.new()
			vp.add_child(cam_h)
			cell.set_meta("cam", cam_h)
		elif st.key == "toy":
			vp.own_world_3d = true
			var d3 := Diorama3D.new()
			vp.add_child(d3)
			d3.build(lib)
			cell.set_meta("d3", d3)
		else:
			var d2 := Diorama2D.new()
			vp.add_child(d2)
			d2.build(lib, races, st.key)
			var cam := Camera2D.new()
			vp.add_child(cam)
			cell.set_meta("cam", cam)
			cell.set_meta("d2", d2)
		match st.key:
			"paper":
				box.material = _shader("paper")
			"soft":
				box.material = _shader("painterly")
			"pixel":
				box.stretch_shrink = 3
				box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				box.material = _shader("posterize")
		cell.set_meta("shrink", 3.0 if st.key == "pixel" else 1.0)
	if STYLES.size() < 6:
		grid.add_child(_notes())


func _shader(name: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://scenes/style_sampler/%s.gdshader" % name)
	return m


func _cell(title: String, note: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.set_content_margin_all(8)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 16)
	v.add_child(t)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(500, 300)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vp := SubViewport.new()
	vp.msaa_2d = Viewport.MSAA_4X
	box.add_child(vp)
	v.add_child(box)
	var n := Label.new()
	n.text = note
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size = Vector2(500, 0)
	n.add_theme_font_size_override("font_size", 12)
	n.add_theme_color_override("font_color", TEXT_DIM)
	v.add_child(n)
	panel.set_meta("box", box)
	return panel


func _notes() -> PanelContainer:
	var panel := _cell("Same scene, five directions", "")
	var box: Control = panel.get_meta("box")
	box.queue_free()
	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(500, 0)
	text.add_theme_color_override("font_color", TEXT_DIM)
	text.text = ("Frog worker, frog spear, rat spear and a rat on a pony, a Town Center and a house, " +
		"reeds and bug bushes. All five are made from today's placeholder parts in a few hours, so judge " +
		"the direction, not the finish.\n\nKeys: 1-5 one style full-window, 0 all styles.\n\n" +
		"Mixes are possible too, e.g. storybook units on painterly ground, or toy-rendered parts with ink outlines.")
	panel.get_child(0).add_child(text)
	return panel


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode - KEY_0
		if k == 0:
			show_all()
		elif k >= 1 and k <= STYLES.size():
			show_one(k - 1)


func show_all() -> void:
	grid.columns = 3
	for c in grid.get_children():
		c.visible = true
	close = false


func show_one(i: int) -> void:
	grid.columns = 1
	for c in grid.get_children():
		c.visible = c == cells[i]
	close = true


func _process(_delta: float) -> void:
	_frame_all(close)


## Every panel at the same scale: the whole patch, or close on the units.
func _frame_all(near: bool) -> void:
	var zoom := CLOSE_ZOOM if near else GRID_ZOOM
	var at := CLOSE_AT if near else Vector2(4.0, 4.0)
	for cell in cells:
		if cell.has_meta("d3"):
			var vp_h: float = maxf(cell.get_meta("box").size.y, 300.0)
			cell.get_meta("d3").frame(at.x, at.y, zoom, vp_h)
		else:
			var box: SubViewportContainer = cell.get_meta("box")
			if box.material and box.material.shader.resource_path.ends_with("painterly.gdshader"):
				box.material.set_shader_parameter("radius", 6 if near else 3)   # brush size follows zoom
			var cam: Camera2D = cell.get_meta("cam")
			var k: float = cell.get_meta("shrink")
			cam.position = Diorama2D.Iso.to_screen(at.x * 1000, at.y * 1000)
			cam.zoom = Vector2(zoom, zoom) / k
