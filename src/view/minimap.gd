extends Control
## The minimap: the map as a diamond (like the game view), terrain coloured from
## data/terrain.json, dimmed by your fog, with buildings as squares and units as dots in team
## colours (enemies only where you can see them), and the camera's view as a frame.
## Click or drag on it to move the camera. View side only.

const Iso := preload("res://src/view/iso.gd")
const Fog := preload("res://src/sim/fog.gd")

const SIZE := 220.0   # width in screen pixels; the diamond is half as tall
const EVERY := 0.2    # seconds between redraws of the terrain picture

var world
var player := 0
var teams: Array = []           # team colour per player
var terrain_colours: Array = [] # per terrain index
var camera
var _tex: ImageTexture
var _img: Image
var _t := 0.0


func setup(p_world, p_teams: Array, terrain_data: Dictionary, p_camera) -> void:
	world = p_world
	teams = p_teams
	camera = p_camera
	terrain_colours = []
	for id in world.map.terrain_ids:
		terrain_colours.append(Color(terrain_data[id].colour))
	custom_minimum_size = Vector2(SIZE, SIZE * 0.5)
	size = custom_minimum_size
	_img = null
	_t = EVERY


func _process(delta: float) -> void:
	if world == null:
		return
	_t += delta
	if _t >= EVERY:
		_t = 0.0
		_paint()
	queue_redraw()


## The terrain picture, one pixel per tile, dimmed by the fog.
func _paint() -> void:
	var m = world.map
	var g: PackedByteArray = world.fog[player]
	if _img == null:
		_img = Image.create(m.width, m.height, false, Image.FORMAT_RGB8)
	for y in m.height:
		for x in m.width:
			var c: int = y * m.width + x
			var col: Color = terrain_colours[m.terrain[c]]
			match g[c]:
				Fog.UNSEEN:
					col = Color(0.04, 0.04, 0.06)
				Fog.EXPLORED:
					col = col.darkened(0.45)
			_img.set_pixel(x, y, col)
	if _tex == null:
		_tex = ImageTexture.create_from_image(_img)
	else:
		_tex.update(_img)


## Tile coordinates (fractional) to a point on the minimap.
func _to_mini(tx: float, ty: float) -> Vector2:
	var s: float = SIZE / world.map.width
	return Vector2(SIZE * 0.5 + (tx - ty) * s * 0.5, (tx + ty) * s * 0.25)


func _draw() -> void:
	if world == null or _tex == null:
		return
	draw_colored_polygon(PackedVector2Array([Vector2(SIZE * 0.5, -3), Vector2(SIZE + 4, SIZE * 0.25),
		Vector2(SIZE * 0.5, SIZE * 0.5 + 3), Vector2(-4, SIZE * 0.25)]), Color(0.1, 0.08, 0.06, 0.9))
	var s: float = SIZE / world.map.width
	draw_set_transform_matrix(Transform2D(Vector2(s * 0.5, s * 0.25), Vector2(-s * 0.5, s * 0.25), Vector2(SIZE * 0.5, 0)))
	draw_texture(_tex, Vector2.ZERO)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var bs = world.buildings
	for b in bs.count():
		var o: int = bs.owner[b]
		if world.is_enemy(player, o) and not Fog.explored(world, player, bs.cx[b], bs.cy[b]):
			continue
		var c := _to_mini(bs.cx[b] + bs.size[b] * 0.5, bs.cy[b] + bs.size[b] * 0.5)
		var r: float = maxf(2.0, bs.size[b] * s * 0.4)
		draw_rect(Rect2(c - Vector2(r, r * 0.6), Vector2(r * 2, r * 1.2)), teams[o])
	var u = world.units
	for i in u.count():
		var o: int = u.owner[i]
		if world.is_enemy(player, o) and not Fog.visible(world, player, u.x[i], u.y[i]):
			continue
		draw_rect(Rect2(_to_mini(u.x[i] / 1000.0, u.y[i] / 1000.0) - Vector2.ONE, Vector2(2, 2)), teams[o].lightened(0.2))
	# The camera's view: its screen corners, back onto the map.
	var vp: Vector2 = get_viewport_rect().size / camera.zoom
	var corners := []
	for k in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
		var m: Vector2i = Iso.to_milli(camera.get_screen_center_position() + k * vp)
		corners.append(_to_mini(m.x / 1000.0, m.y / 1000.0))
	corners.append(corners[0])
	draw_polyline(PackedVector2Array(corners), Color(1, 1, 1, 0.85), 1.0)


func _gui_input(event: InputEvent) -> void:
	var press: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var drag: bool = event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if not (press or drag) or world == null:
		return
	# Back from the minimap to tiles, then to the canvas.
	var s: float = SIZE / world.map.width
	var p: Vector2 = event.position - Vector2(SIZE * 0.5, 0)
	var a: float = p.x / (s * 0.5)
	var b: float = p.y / (s * 0.25)
	var tx: float = (a + b) * 0.5
	var ty: float = (b - a) * 0.5
	camera.look_at_point(Iso.to_screen(tx * 1000.0, ty * 1000.0))
	accept_event()
