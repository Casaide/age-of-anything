extends Node2D
## A building in the pixel-art style, from the art kit's bakes: the body in the team
## colour, chimney smoke, flickering lights, a waving banner and a turning vane.
## While it's being built it shows its construction stages (foundations, scaffold,
## walls, roof) with a progress bar; the live parts start once it's done.

const Iso := preload("res://src/view/iso.gd")
const Models := preload("res://src/view/art/bake/models.gd")

var body: Sprite2D
var open_body: Sprite2D   # a gate's open look (null for other buildings)
var open := false
var live: Array = []      # nodes that only run once the building is done
var glows: Array = []
var vane: Node2D
var stages: Array = []    # construction stage sprites, shown while it's being built
var team := Color.WHITE
var progress := 1.0
var done := true
var time := 0.0
var bar_at := Vector2.ZERO
var links := 0            # a wall tile: which neighbours its arms reach (bit k: Models.LINKS[k])
## A walkway's near merlons (ArtKit front layer): a node of its own beside this one in the y-sorted
## layer, sorted FRONT_SORT_PX lower, so units up on the walkway (sorted between: PERCH_SORT_PX) draw
## over the wall and under the merlons in front of them. Null for buildings without a walkway.
var front: Node2D
var front_body: Sprite2D
var front_open: Sprite2D
var walk_px := 0.0        # how high units on its walkway are drawn (canvas px over its base), 0: none
var walk_tower_px := 0.0  # a gatehouse: how high on its flanking towers (0: none)...
var walk_tower_from := 0.0   # ...past this far (tiles) from its middle along it
var walk_axis := Vector2.RIGHT   # the way it runs (sim tiles, unit length)
var walk_centre := Vector2.ZERO  # its footprint's middle (sim tiles)
## A gatehouse's towers lower on screen than its middle (ArtKit _bake_gate_parts): [{node, front, at}],
## each a pair of nodes of their own beside this one in the y-sorted layer, sorted on the tower's middle.
var parts: Array = []
const PERCH_SORT_PX := 1.0
## A gate's way along, by its bake suffix (ArtKit.ALONG: none, ^z, ^d, ^a), in sim tiles.
const WALK_AXES := [Vector2(1, 0), Vector2(0, 1), Vector2(0.70710678, 0.70710678), Vector2(0.70710678, -0.70710678)]
const FRONT_SORT_PX := 2.0
var _kit
var _name := ""
var smoke: CPUParticles2D   # the chimney (null if it has none)
var working := true       # smoke rises while it's at work (training, research); houses always
var damage := 0.0         # 0 whole .. 1 nearly down: cracks from DAMAGE_CRACKS, fire from DAMAGE_FIRE
var _wear: Node2D         # over the body: cracks drawn, fires and their smoke
var _cracks: Array = []   # [PackedVector2Array] canvas units from the centre, worst first
var _fires: Array = []    # [CPUParticles2D, CPUParticles2D] flame and smoke per fire

var _door: Node2D         # over the body: the doorway, lit while someone goes in or out
var _door_shape := PackedVector2Array()
var door_open := 0.0      # 0 shut .. 1 open (eased)
var garrison := 0         # people sheltering inside (garrison.gd): a small count over the roof
var _badge: Node2D        # draws that count
var _door_until := 0.0    # time it stays open to

const DOOR_OPEN_S := 1.6  # a door stays open this long after someone passes
const DAMAGE_CRACKS := 0.3   # milestone 17: cracks show once it has lost this much
const DAMAGE_FIRE := 0.6     # ...and it burns past this


## A building of sx x sy tiles (a gate is longer than deep) with its top-left on cell (cx, cy).
func setup(kit, name: String, cx: int, cy: int, sx: int, sy: int, p_team: Color) -> void:
	team = p_team
	_kit = kit
	_name = name
	var info: Dictionary = kit.buildings[name]
	var centre := Iso.to_screen((cx + sx * 0.5) * 1000, (cy + sy * 0.5) * 1000)
	# Y-sorts by its footprint's centre, not its front corner: a unit beside either lower
	# face is lower on screen than the centre and draws in front; beside an upper face
	# it's higher and goes behind. (Sorting by the front corner hid units standing beside
	# the lower faces.) Art spilling past the footprint doesn't move the sort point.
	position = centre
	# On high ground the art stands raised (Iso.lift) while the sort point stays on the base plane.
	var at := centre - position - Vector2(0, Iso.lift((cx + sx * 0.5) * 1000, (cy + sy * 0.5) * 1000))
	body = kit.sprite(info.body)
	body.position = at
	body.self_modulate = Color(team.r, team.g, team.b, 1.0)
	add_child(body)
	if info.has("open"):
		open_body = kit.sprite(info.open)
		open_body.position = at
		open_body.self_modulate = body.self_modulate
		open_body.visible = false
		add_child(open_body)
	for stage_name in info.stages:
		var st: Sprite2D = kit.sprite(stage_name)
		st.position = at
		st.self_modulate = body.self_modulate
		st.visible = false
		add_child(st)
		stages.append(st)
	bar_at = at + Vector2(0, 6)
	walk_px = float(info.get("walk_px", 0.0))
	walk_tower_px = float(info.get("walk_tower_px", 0.0))
	walk_tower_from = float(info.get("walk_tower_from", 0.0))
	walk_centre = Vector2(cx + sx * 0.5, cy + sy * 0.5)
	walk_axis = WALK_AXES[["z", "d", "a"].find(name.get_slice("^", 1)) + 1] if "^" in name else Vector2.RIGHT
	if info.has("front") or info.has("open_front") or info.has("arms_front"):
		front = Node2D.new()
		front.position = centre + Vector2(0, FRONT_SORT_PX)
		if info.has("front") or info.has("arms_front"):
			front_body = kit.sprite(info.front) if info.has("front") else Sprite2D.new()
			front_body.position = at - Vector2(0, FRONT_SORT_PX)
			front_body.self_modulate = body.self_modulate
			front.add_child(front_body)
		if info.has("open_front"):
			front_open = kit.sprite(info.open_front)
			front_open.position = at - Vector2(0, FRONT_SORT_PX)
			front_open.self_modulate = body.self_modulate
			front_open.visible = false
			front.add_child(front_open)
		visibility_changed.connect(func(): front.visible = visible)
		tree_entered.connect(func(): get_parent().add_child.call_deferred(front))
	for pt in info.get("parts", []):
		var dy: float = Iso.to_screen(pt.at.x * 1000.0, pt.at.y * 1000.0).y
		var pair := []
		for k in 2:
			var n := Node2D.new()
			n.position = centre + Vector2(0, dy + (FRONT_SORT_PX if k == 1 else 0.0))
			var s: Sprite2D = kit.sprite(pt.front if k == 1 else pt.body)
			s.position = at - Vector2(0, dy + (FRONT_SORT_PX if k == 1 else 0.0))
			s.self_modulate = body.self_modulate
			n.add_child(s)
			pair.append(n)
		parts.append({"node": pair[0], "front": pair[1], "at": pt.at})
		visibility_changed.connect(func(): _show_front())
		tree_entered.connect(func(): for n in pair: get_parent().add_child.call_deferred(n))
	if info.has("smoke"):
		smoke = _smoke(at + info.smoke)
		live.append(smoke)
	if info.has("lantern"):
		_glow(at + info.lantern, 14.0, Color(1.0, 0.75, 0.35))
	for p in info.lights:
		_glow(at + p, 9.0, Color(1.0, 0.8, 0.45))
	if info.has("banner"):
		var bs := Sprite2D.new()
		bs.texture = info.banner.tex
		bs.centered = false
		bs.offset = -info.banner.origin
		bs.scale = Vector2.ONE / kit.ART_SCALE
		bs.position = at
		bs.self_modulate = Color(team.r, team.g, team.b, 1.0)
		var m := ShaderMaterial.new()
		m.shader = load("res://src/view/art/bake/banner.gdshader")
		bs.material = m
		add_child(bs)
		live.append(bs)
	if info.has("doorway"):
		var c: Array = info.doorway.corners
		var u: Vector2 = (c[1] - c[0]) * 0.5
		var v: Vector2 = (c[2] - c[0]) * 0.5
		var mid: Vector2 = at + c[0] + u + v
		if info.doorway.round:
			for k in 14:
				var a := TAU * k / 14.0
				_door_shape.append(mid + u * cos(a) - v * sin(a))
		else:   # square below, an arch on top
			_door_shape.append(mid - u - v)
			_door_shape.append(mid + u - v)
			for k in 7:
				var a := PI * k / 6.0
				_door_shape.append(mid + v * 0.5 + u * cos(a) + v * 0.5 * sin(a))
		_door = Node2D.new()
		_door.draw.connect(_draw_door)
		_door.visible = false
		add_child(_door)
	if info.has("vane"):
		vane = Node2D.new()
		vane.position = at + info.vane_at
		var vs: Sprite2D = kit.sprite(info.vane)
		vs.self_modulate = body.self_modulate
		vane.add_child(vs)
		add_child(vane)


func set_state(p_done: bool, p_progress: float) -> void:
	if p_done == done and absf(p_progress - progress) < 0.01:
		return
	done = p_done
	progress = p_progress
	var shown := -1 if done else mini(int(progress * stages.size()), stages.size() - 1)
	body.visible = done and not (open and open_body != null)
	if open_body:
		open_body.visible = done and open
	_show_front()
	for k in stages.size():
		stages[k].visible = k == shown
	for n in live:
		n.visible = done
	for g in glows:
		g.node.visible = done
	queue_redraw()


## Someone went in or came out: the door opens and the warm inside shows, then it shuts.
func door_pulse() -> void:
	if _door != null and done:
		_door_until = time + DOOR_OPEN_S


func _draw_door() -> void:
	var lo := 1e9
	var hi := -1e9
	for p in _door_shape:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var cols := PackedColorArray()
	for p in _door_shape:   # firelight low inside, dark above
		var f := clampf((p.y - lo) / maxf(hi - lo, 0.001), 0.0, 1.0)
		cols.append(Color(0.08, 0.05, 0.03).lerp(Color(0.95, 0.6, 0.25), f * 0.8) * Color(1, 1, 1, door_open))
	_door.draw_polygon(_door_shape, cols)


## Smoke from the chimney only while the building works (milestone 17: you see the town at
## work). It thins out rather than stopping dead: particles in the air finish rising.
func set_working(on: bool) -> void:
	if on == working:
		return
	working = on
	if smoke != null:
		smoke.emitting = on


## Wear from damage (0 whole .. 1 nearly gone): dark cracks across the walls once it's been hit
## hard, more as it gets worse, then fire and black smoke at a few places on it.
func set_damage(f: float) -> void:
	f = clampf(f, 0.0, 1.0)
	if absf(f - damage) < 0.02 or not done:
		return
	damage = f
	if _wear == null:
		_wear = Node2D.new()
		_wear.draw.connect(_draw_wear)
		add_child(_wear)
		_cracks = _make_cracks(6)
		for p in _spots(3, 0.1, 0.45):   # on the roof, where it catches
			_fires.append([_flames(p), _black_smoke(p)])
	var burning := damage >= DAMAGE_FIRE
	for k in _fires.size():
		var on := burning and k < 1 + int((damage - DAMAGE_FIRE) / (1.0 - DAMAGE_FIRE) * 3.0)
		_fires[k][0].emitting = on
		_fires[k][1].emitting = on
	_wear.queue_redraw()


func _draw_wear() -> void:
	if damage < DAMAGE_CRACKS:
		return
	var n := mini(_cracks.size(), 1 + int((damage - DAMAGE_CRACKS) / (1.0 - DAMAGE_CRACKS) * _cracks.size()))
	var px: float = 1.0 / _kit.ART_SCALE
	for k in n:
		var lit := PackedVector2Array()   # a pixel of light along one side: the crack has depth
		for p in _cracks[k]:
			lit.append(p + Vector2(px, px * 0.5))
		_wear.draw_polyline(lit, Color(1, 0.95, 0.85, 0.22), px)
		_wear.draw_polyline(_cracks[k], Color(0.16, 0.11, 0.07, 0.8), px)


## Points on the body's bake that are solid (opaque) in a band of its height (0 top .. 1 bottom),
## in canvas units from the building's centre. Seeded by the body's name: the same cracks always.
func _spots(n: int, top: float, bottom: float) -> Array:
	var b: Dictionary = _kit.bakes[_kit.buildings[_name].body]
	var img: Image = b.img
	var used := img.get_used_rect()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_name) + int(position.x * 7.0 + position.y * 13.0)
	var out := []
	var tries := 0
	while out.size() < n and tries < 400:
		tries += 1
		var p := Vector2i(rng.randi_range(used.position.x + used.size.x / 6, used.end.x - used.size.x / 6),
			rng.randi_range(used.position.y + int(used.size.y * top), used.position.y + int(used.size.y * bottom)))
		if img.get_pixelv(p).a > 0.9:
			out.append((Vector2(p) - b.origin) / _kit.ART_SCALE + body.position)
	return out


## Cracks: short jagged lines starting at solid points of the walls, each step kept on the body.
func _make_cracks(n: int) -> Array:
	var b: Dictionary = _kit.bakes[_kit.buildings[_name].body]
	var img: Image = b.img
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_name) + 17
	var out := []
	for start in _spots(n, 0.35, 0.85):
		var line := PackedVector2Array([start])
		var p: Vector2 = start
		var dir := Vector2(rng.randf_range(-0.6, 0.6), 1.0).normalized()
		for step in rng.randi_range(4, 7):
			p += (dir + Vector2(rng.randf_range(-0.9, 0.9), 0)).normalized() * rng.randf_range(2.5, 4.5)
			var q := Vector2i(((p - body.position) * _kit.ART_SCALE + b.origin).round())
			if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height() or img.get_pixelv(q).a < 0.9:
				break
			line.append(p)
		if line.size() >= 3:
			out.append(line)
	return out


func _flames(at: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = at
	p.amount = 16
	p.lifetime = 0.8
	p.direction = Vector2(0, -1)
	p.spread = 14.0
	p.initial_velocity_min = 7.0
	p.initial_velocity_max = 13.0
	p.gravity = Vector2(0, -8.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 3.0
	p.scale_amount_min = 0.14
	p.scale_amount_max = 0.24
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1.0))
	shrink.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = shrink
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1.0, 0.92, 0.5, 1.0), Color(1.0, 0.5, 0.1, 1.0), Color(0.75, 0.15, 0.05, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	p.color_ramp = ramp
	p.texture = _flame_dot()
	p.emitting = false
	_wear.add_child(p)
	return p


func _black_smoke(at: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = at + Vector2(0, -5)
	p.amount = 14
	p.lifetime = 3.5
	p.preprocess = 2.0
	p.direction = Vector2(0.15, -1)
	p.spread = 14.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 10.0
	p.gravity = Vector2(2.5, -1.5)
	p.scale_amount_min = 0.16
	p.scale_amount_max = 0.26
	var grow := Curve.new()
	grow.max_value = 3.0   # (a curve stops at 1 unless told otherwise)
	grow.add_point(Vector2(0, 0.6))
	grow.add_point(Vector2(1, 2.4))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(0.1, 0.08, 0.07, 0.0), Color(0.12, 0.1, 0.09, 0.75), Color(0.25, 0.24, 0.23, 0.35), Color(0.35, 0.34, 0.33, 0.0)])
	fade.offsets = PackedFloat32Array([0.0, 0.1, 0.6, 1.0])
	p.color_ramp = fade
	p.texture = _flame_dot()
	p.emitting = false
	_wear.add_child(p)
	return p


## Where a shooting building's shots leave from (canvas): a little below the top of its art.
func loose_at() -> Vector2:
	var r := body.get_rect()
	return position + body.position + Vector2(0, (r.position.y + r.size.y * 0.2) * body.scale.y)

## A wall tile joins up with its wall neighbours: its post with an arm out to each one in
## `p_links` (bit k: Models.LINKS[k]), the kit's composed look for that set. Others ignore it.
func set_links(p_links: int) -> void:
	if p_links == links or not _kit.buildings[_name].has("arms"):
		return
	links = p_links
	var look: Dictionary = _kit.wall_look(_name, links)
	body.texture = look.tex
	body.offset = -look.origin
	if front_body != null:
		front_body.texture = look.get("front_tex")
		front_body.offset = -look.get("front_origin", Vector2.ZERO)
		front_body.scale = body.scale
		front_body.material = body.material


## Which wall neighbours a wall tile's arms reach (bit k: Models.LINKS[k]), `on(d)` telling whether
## the tile at offset d is a finished wall, gate or wall tower: every one beside it, and corner to
## corner only where no wall beside both closes the corner already (an L turns at its corner tile
## rather than cutting across it). The game (sim_debug) and the walls' join check share it.
static func links_of(on: Callable) -> int:
	var out := 0
	for k in Models.LINKS.size():
		var d: Vector2i = Models.LINKS[k]
		if not on.call(d):
			continue
		if d.x != 0 and d.y != 0 and (on.call(Vector2i(d.x, 0)) or on.call(Vector2i(0, d.y))):
			continue
		out |= 1 << k
	return out


## The sort y of a unit up on a walkway piece sorted at `piece_y`, the unit at screen y `unit_y`: just
## after the piece and before its near merlons (front), units on one piece kept in their order.
## How high a unit up on this piece at sim (x, y) (tiles) stands: on a gatehouse's towers or its
## walk over the passage, elsewhere the piece's walkway.
func walk_at(at: Vector2) -> float:
	if walk_tower_px > 0.0 and absf((at - walk_centre).dot(walk_axis)) >= walk_tower_from:
		return walk_tower_px
	return walk_px


## The sort y of a unit up on this piece at sim (x, y) (tiles), at screen y `unit_y` (perch_sort_y): on a
## gatehouse tower with a layer of its own, after that tower and before its near parts.
func perch_sort_at(at: Vector2, unit_y: float) -> float:
	if walk_tower_px > 0.0 and absf((at - walk_centre).dot(walk_axis)) >= walk_tower_from:
		for pt in parts:
			if (at - walk_centre).dot(pt.at) > 0.0:
				return perch_sort_y(pt.node.position.y, unit_y)
	return perch_sort_y(position.y, unit_y)


static func perch_sort_y(piece_y: float, unit_y: float) -> float:
	return piece_y + PERCH_SORT_PX + clampf((unit_y - piece_y) / 64.0, -0.45, 0.45)


## Should gate b show open? While one of its owner's team (not an animal, not an enemy) is at it,
## and no enemy is near: an enemy at the gate never opens it, nor sees it open (the sim keeps it
## shut to them whatever it shows: SimMap lanes).
static func gate_open(world, b: int) -> bool:
	var bs = world.buildings
	var u = world.units
	var friend := false
	var x0: int = bs.cx[b] * 1000 - GATE_ENEMY_NEAR
	var y0: int = bs.cy[b] * 1000 - GATE_ENEMY_NEAR
	var x1: int = (bs.cx[b] + bs.sx[b]) * 1000 + GATE_ENEMY_NEAR
	var y1: int = (bs.cy[b] + bs.sy[b]) * 1000 + GATE_ENEMY_NEAR
	for j in u.count():
		if u.owner[j] == world.gaia or u.x[j] < x0 or u.x[j] > x1 or u.y[j] < y0 or u.y[j] > y1:
			continue   # (far off: no need to measure)
		var d: int = bs.gap(b, u.x[j], u.y[j])   # to the gate's cells (a diagonal gate's square has open corners)
		if world.is_enemy(u.owner[j], bs.owner[b]):
			if d < GATE_ENEMY_NEAR:
				return false
		elif d < GATE_FRIEND_AT:
			friend = true
	return friend


const GATE_FRIEND_AT := 800    # milli-tiles from the gate's footprint: a friend this close opens it
const GATE_ENEMY_NEAR := 1500  # an enemy this close keeps it shut


## A gate opens while a friendly unit is at it and shuts behind it (view only: the sim lets
## its team through either way).
func set_open(p_open: bool) -> void:
	if p_open == open or open_body == null:
		return
	open = p_open
	body.visible = done and not open
	open_body.visible = done and open
	_show_front()


## The front layer shows with the look it belongs to (shut or open), once the building is done; a
## gatehouse's tower layers once it's done.
func _show_front() -> void:
	for pt in parts:
		pt.node.visible = done and visible
		pt.front.visible = done and visible
	if front_body != null:
		front_body.visible = body.visible
	if front_open != null:
		front_open.visible = open_body.visible


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and front != null and is_instance_valid(front):
		front.queue_free()
	if what == NOTIFICATION_PREDELETE:
		for pt in parts:
			for key in ["node", "front"]:
				if is_instance_valid(pt[key]):
					pt[key].queue_free()


func _process(delta: float) -> void:
	time += delta
	if _door != null:
		var want := 1.0 if time < _door_until else 0.0
		if door_open != want:
			door_open = move_toward(door_open, want, delta * 5.0)
			_door.visible = door_open > 0.0
			_door.queue_redraw()
	for g in glows:
		var f := 0.8 + 0.2 * sin(time * 7.0 + g.phase) * sin(time * 2.3 + g.phase * 2.0)
		g.node.modulate = Color(g.base.r * f, g.base.g * f, g.base.b * f, 1.0)
	if vane and done:
		vane.scale.x = cos(time * 1.3)


## How many shelter inside (0: no badge). Shown for your own side's buildings.
func set_garrison(n: int) -> void:
	if n == garrison:
		return
	garrison = n
	if _badge == null:
		_badge = Node2D.new()   # over the body (a node's own drawing goes under its children)
		_badge.draw.connect(_draw_garrison)
		add_child(_badge)
	_badge.visible = garrison > 0
	_badge.queue_redraw()


func _draw() -> void:
	if done:
		return
	var w := 40.0
	draw_rect(Rect2(bar_at - Vector2(w * 0.5, 0), Vector2(w, 4)), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bar_at - Vector2(w * 0.5, 0) + Vector2(1, 1), Vector2((w - 2) * progress, 2)), Color("#f2c94c"))


## The count of people inside: a dark pill by the roof with a little figure and the number.
func _draw_garrison() -> void:
	if not done:
		return
	var r := body.get_rect()
	var at := body.position + Vector2(r.position.x + r.size.x * 0.72, r.position.y + r.size.y * 0.22) * body.scale
	var font := ThemeDB.fallback_font
	var txt := str(garrison)
	var fs := 8
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var box := Rect2(at - Vector2(5, 5), Vector2(tw + 13, 10))
	_badge.draw_rect(box, Color(0.08, 0.06, 0.04, 0.8))
	_badge.draw_rect(box, Color(team.r, team.g, team.b, 0.9), false, 1.0)
	_badge.draw_circle(at + Vector2(-1, -2), 1.4, Color("#f2e6cc"))   # a head
	_badge.draw_rect(Rect2(at + Vector2(-2.5, -0.5), Vector2(3, 3.5)), Color("#f2e6cc"))   # shoulders
	_badge.draw_string(font, at + Vector2(3, 3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#f2e6cc"))


func _smoke(at: Vector2) -> CPUParticles2D:
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
	p.texture = _dot()
	add_child(p)
	return p


func _glow(at: Vector2, radius: float, c: Color) -> void:
	var s := Sprite2D.new()
	s.texture = _dot()
	s.position = at
	s.scale = Vector2.ONE * radius / 16.0
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	add_child(s)
	glows.append({"node": s, "base": c, "phase": randf() * 10.0})


static var _dot_tex: GradientTexture2D
static var _flame_tex: GradientTexture2D


## A flame's dot: solid in the middle with a short soft edge (the smoke's dot is all haze).
static func _flame_dot() -> GradientTexture2D:
	if _flame_tex == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		_flame_tex = GradientTexture2D.new()
		_flame_tex.gradient = g
		_flame_tex.fill = GradientTexture2D.FILL_RADIAL
		_flame_tex.fill_from = Vector2(0.5, 0.5)
		_flame_tex.fill_to = Vector2(1.0, 0.5)
		_flame_tex.width = 32
		_flame_tex.height = 32
	return _flame_tex


static func _dot() -> GradientTexture2D:
	if _dot_tex == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.0)])
		_dot_tex = GradientTexture2D.new()
		_dot_tex.gradient = g
		_dot_tex.fill = GradientTexture2D.FILL_RADIAL
		_dot_tex.fill_from = Vector2(0.5, 0.5)
		_dot_tex.fill_to = Vector2(1.0, 0.5)
		_dot_tex.width = 32
		_dot_tex.height = 32
	return _dot_tex
