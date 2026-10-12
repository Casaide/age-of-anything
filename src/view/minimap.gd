extends Control
## The minimap: the map as a diamond (like the game view), terrain coloured from
## data/terrain.json, dimmed by your fog, with buildings as squares and units as dots in team
## colours (enemies only where you can see them), and the camera's view as a frame. The ground
## and enemy buildings are as you last saw them (fog.gd remembers them): nothing of an enemy's
## shows where you haven't looked.
## Click or drag on it to move the camera. View side only.

const Iso := preload("res://src/view/iso.gd")
const Fog := preload("res://src/sim/fog.gd")

const Mat := preload("res://src/view/ui/ui_materials.gd")

const SIZE := 300.0   # width in screen pixels; the diamond is half as tall (Fable: 220 was too small)
const RIM := 12.0     # the frame round the diamond
const EVERY := 0.2    # seconds between redraws of the terrain picture

var world
var look := {}        # the HUD's look (src/view/ui/theme.gd): the frame's material and metal
var player := 0
var reveal := false   # the fog lifted (debug): the truth everywhere
var teams: Array = []           # team colour per player
var terrain_colours: Array = [] # per terrain index
var camera
var _tex: ImageTexture
var _img: Image
var _relief := PackedByteArray()   # per cell: its relief code (see _relief_and_table)
var _lut := PackedByteArray()      # RGB per (terrain, relief code, fog state)
var _t := 0.0
var pings: Array = []   # [{at: Vector2 (tiles), t: seconds left}]: where you're under attack


## A red ping at a place on the map (tiles), for a few seconds.
func ping(tiles: Vector2) -> void:
	pings.append({"at": tiles, "t": 4.0})


func setup(p_world, p_teams: Array, terrain_data: Dictionary, p_camera) -> void:
	world = p_world
	teams = p_teams
	camera = p_camera
	terrain_colours = []
	for id in world.map.terrain_ids:
		terrain_colours.append(Color(terrain_data[id].colour))
	custom_minimum_size = Vector2(SIZE, SIZE * 0.5)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # the frame tiles its material
	size = custom_minimum_size
	_img = null
	_t = EVERY


func _process(delta: float) -> void:
	if world == null:
		return
	_t += delta
	for p in pings:
		p.t -= delta
	pings = pings.filter(func(p): return p.t > 0.0)
	if _t >= EVERY:
		_t = 0.0
		_paint()
	queue_redraw()


## The terrain picture, one pixel per tile, dimmed by the fog. Each pixel's colour comes from a
## table by (ground, the cell's relief, its fog) worked out once per match: the loop only looks up
## and copies three bytes.
func _paint() -> void:
	var m = world.map
	var g: PackedByteArray = world.fog[player]
	var ground: PackedByteArray = m.terrain if reveal else world.fog_ground[player]
	if _img == null:
		_img = Image.create(m.width, m.height, false, Image.FORMAT_RGB8)
		_relief_and_table(m)
	var n: int = m.width * m.height
	var px := PackedByteArray()
	px.resize(n * 3)
	var lut := _lut
	var rel := _relief
	for c in n:
		var k: int = ((ground[c] * RELIEF + rel[c]) * 4 + (3 if reveal else g[c])) * 3
		px[c * 3] = lut[k]
		px[c * 3 + 1] = lut[k + 1]
		px[c * 3 + 2] = lut[k + 2]
	_img.set_data(m.width, m.height, false, Image.FORMAT_RGB8, px)
	if _tex == null:
		_tex = ImageTexture.create_from_image(_img)
	else:
		_tex.update(_img)


const RELIEF := 16   # relief codes: level (0-3) * 4 + ramp * 2 + cliff


## Per cell its relief code, and the colour table: per terrain, relief code and fog state
## (unseen, explored, visible, the fog lifted), as RGB bytes.
func _relief_and_table(m) -> void:
	_relief = PackedByteArray()
	_relief.resize(m.width * m.height)
	if m.has_heights:
		for c in _relief.size():
			_relief[c] = m.level[c] * 4 + m.ramp[c] * 2 + m.cliff[c]
	_lut = PackedByteArray()
	for t in terrain_colours.size():
		for code in RELIEF:
			var col: Color = terrain_colours[t]
			col = col.lightened(0.11 * (code / 4) + 0.055 * ((code / 2) % 2))   # high ground reads lighter, a level at a time
			if code % 2 == 1:
				col = col.darkened(0.4)   # cliffs as dark lines
			for fog in 4:
				var f: Color = col
				if fog == Fog.UNSEEN:
					f = Color("#1a1510")   # dark earth, not a black hole
				elif fog == Fog.EXPLORED:
					f = col.darkened(0.3)
				_lut.append(f.r8)
				_lut.append(f.g8)
				_lut.append(f.b8)


## Tile coordinates (fractional) to a point on the minimap.
func _to_mini(tx: float, ty: float) -> Vector2:
	var s: float = SIZE / world.map.width
	return Vector2(SIZE * 0.5 + (tx - ty) * s * 0.5, (tx + ty) * s * 0.25)


func _draw() -> void:
	if world == null or _tex == null:
		return
	_draw_frame()
	var s: float = SIZE / world.map.width
	draw_set_transform_matrix(Transform2D(Vector2(s * 0.5, s * 0.25), Vector2(-s * 0.5, s * 0.25), Vector2(SIZE * 0.5, 0)))
	draw_texture(_tex, Vector2.ZERO)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var bs = world.buildings
	for b in bs.count():
		var o: int = bs.owner[b]
		if reveal or not world.is_enemy(player, o):
			_building(bs.cx[b], bs.cy[b], bs.sx[b], bs.sy[b], teams[o])
	if not reveal:
		var seen: Dictionary = world.fog_seen[player]
		for id in seen:   # enemies' as last seen (some may be gone since)
			var k: PackedInt32Array = seen[id]
			if world.is_enemy(player, k[1]):
				_building(k[2], k[3], k[4], k[8], teams[k[1]])
	var u = world.units
	for i in u.count():
		var o: int = u.owner[i]
		if not reveal and world.is_enemy(player, o) and not Fog.visible(world, player, u.x[i], u.y[i]):
			continue
		var dot: Color = Color("#d8d0b8") if o >= teams.size() or o == world.gaia else teams[o].lightened(0.2)   # animals: pale
		draw_rect(Rect2(_to_mini(u.x[i] / 1000.0, u.y[i] / 1000.0) - Vector2.ONE, Vector2(2, 2)), dot)
	# The camera's view: its screen corners, back onto the map.
	var vp: Vector2 = get_viewport_rect().size / camera.zoom
	var corners := []
	for k in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
		var m: Vector2i = Iso.to_milli(camera.get_screen_center_position() + k * vp)
		corners.append(_to_mini(m.x / 1000.0, m.y / 1000.0))
	corners.append(corners[0])
	draw_polyline(PackedVector2Array(corners), Color(1, 1, 1, 0.9), 2.0)
	for p in pings:   # under attack here: a red ring that pulses
		var k: float = fmod(p.t, 1.0)
		draw_arc(_to_mini(p.at.x, p.at.y), 4.0 + 10.0 * (1.0 - k), 0.0, TAU, 20, Color(1.0, 0.25, 0.2, k), 2.0)


## The diamond's frame, in the HUD's frame material: lit on its upper edges, in shade below, a
## dark well inside, a stud at each point.
func _draw_frame() -> void:
	var c := Vector2(SIZE * 0.5, SIZE * 0.25)
	var o := PackedVector2Array([Vector2(c.x, -RIM * 0.6), Vector2(SIZE + RIM, c.y), Vector2(c.x, SIZE * 0.5 + RIM * 0.6), Vector2(-RIM, c.y)])
	var i := PackedVector2Array([Vector2(c.x, -1), Vector2(SIZE + 1.5, c.y), Vector2(c.x, SIZE * 0.5 + 1), Vector2(-1.5, c.y)])
	var shadow := PackedVector2Array()
	for p in o:
		shadow.append(p + Vector2(3, 6))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.4))
	var mat: String = look.get("frame", "bronze")
	var tex := Mat.texture(mat, look.get("frame_colour", Color("#9a7438")))
	var uvs := PackedVector2Array()
	for p in o:
		uvs.append(p / 128.0)
	draw_colored_polygon(o, Color.WHITE, uvs, tex)
	var light := [Color(1, 0.95, 0.85, 0.3), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.5), Color(1, 0.95, 0.85, 0.15)]   # edges from the top point, clockwise
	for k in 4:
		var a := o[k]
		var b := o[(k + 1) % 4]
		draw_polygon(PackedVector2Array([a, b, i[(k + 1) % 4], i[k]]), PackedColorArray([light[k], light[k], Color(light[k], 0.0), Color(light[k], 0.0)]))
	draw_colored_polygon(i, Color("#120d08"))
	var edge := o.duplicate()
	edge.append(o[0])
	draw_polyline(edge, Color(0, 0, 0, 0.75), 1.5, true)
	var inner := i.duplicate()
	inner.append(i[0])
	draw_polyline(inner, Color(0, 0, 0, 0.7), 1.5, true)
	var metal: Color = look.get("metal", Color("#c09048"))
	for p in o:
		draw_circle(p + Vector2(0.6, 1.2), 5.5, Color(0, 0, 0, 0.5))
		draw_circle(p, 4.8, metal.darkened(0.3))
		draw_circle(p - Vector2(0.6, 0.6), 3.6, metal)
		draw_circle(p - Vector2(1.5, 1.5), 1.6, metal.lightened(0.45))


func _building(cx: int, cy: int, sx: int, sy: int, colour: Color) -> void:
	var s: float = SIZE / world.map.width
	var c := _to_mini(cx + sx * 0.5, cy + sy * 0.5)
	var r: float = maxf(3.0, maxi(sx, sy) * s * 0.45)
	draw_rect(Rect2(c - Vector2(r, r * 0.6), Vector2(r * 2, r * 1.2)), colour)


## Only the diamond takes the mouse (Dominic: the corners of its box caught clicks meant for the
## map); a click in a corner goes through to the game view.
func _has_point(point: Vector2) -> bool:
	var d := absf(point.x - SIZE * 0.5) / (SIZE * 0.5) + absf(point.y - SIZE * 0.25) / (SIZE * 0.25)
	return d <= 1.0


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
