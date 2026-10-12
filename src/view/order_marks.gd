extends RefCounted
## A selected unit's orders, shown in the world: what it's doing now, then each shift-queued
## order in turn, joined by a dashed route from the unit. Move points get a baked waypoint
## pennant (the rally flag's little sibling); a build shows its foundation's outline, a gather
## its tile, an attack its target ringed in red. Later legs fade, so the order reads at a glance.
## Shown for your own selected units, and for a few seconds for units just given a shift-order.
## View side only: it reads the sim, never writes it.

const Iso := preload("res://src/view/iso.gd")
const Commands := preload("res://src/sim/commands.gd")
const Economy := preload("res://src/sim/economy.gd")
const Combat := preload("res://src/sim/combat.gd")
const SimMap := preload("res://src/sim/sim_map.gd")

const RING := Color("#f2e9c9")
const FOE := Color("#e2654a")
const EDGE := Color(0, 0, 0, 0.5)
const FLASH_MS := 3000      # how long a unit's route stays up after a shift-order, unselected
const FADE_STEP := 0.16     # each later leg a little fainter...
const FADE_MIN := 0.4       # ...down to this
const GROUP_LEGS := 3       # more units than this heading for one spot share one first leg

var d                       # the sim debug view (world, views, kit, layer, camera, ...)
var pool: Array = []        # waypoint pennants (Sprite2D in the y-sorted layer), reused
var legs: Array = []        # [from, to, order, foe] canvas points, deduplicated
var spots: Array = []       # [{kind, at, order, id, cx, cy, size}] deduplicated
var flashed := {}           # unit id -> msec until its route stops showing unselected


func _init(view) -> void:
	d = view


## Show these units' routes for a few seconds even if they're not selected (a shift-order).
func flash(ids: Array) -> void:
	for id in ids:
		flashed[id] = Time.get_ticks_msec() + FLASH_MS


## Rebuild the routes from the sim and place the pennants (every frame, before drawing).
func update() -> void:
	legs.clear()
	spots.clear()
	var now := Time.get_ticks_msec()
	for id in flashed.keys():
		if flashed[id] < now:
			flashed.erase(id)
	var w = d.world
	var ids: Array = d.selected.keys()
	for id in flashed:
		if not d.selected.has(id):
			ids.append(id)
	var seen_leg := {}
	var seen_spot := {}
	var firsts := {}   # first spot key -> [spot, foe, unit positions]: a group's first legs
	for id in ids:
		var i: int = w.units.index_of(id)
		var view: Node2D = d.views.get(id)
		if i < 0 or view == null or w.units.owner[i] != d.active:
			continue
		var from := view.position
		var prev := {}   # the spot the leg starts from (none: the unit itself)
		var k := 0
		for s in route(w, i):
			var at: Variant = _anchor(s)
			if at == null:
				continue
			s.at = at
			s.order = k
			var foe: bool = s.kind == "attack" or s.kind == "amove"
			var lk := "%d,%d>%d,%d" % [roundi(from.x), roundi(from.y), roundi(at.x), roundi(at.y)]
			var sk := "%s@%d,%d" % [s.kind, roundi(at.x), roundi(at.y)]
			if k == 0:
				if not firsts.has(sk):
					firsts[sk] = [s, foe, []]
				firsts[sk][2].append(from)
			elif not seen_leg.has(lk):
				seen_leg[lk] = true
				legs.append([_edge(prev, from, at), _edge(s, at, from), k, foe])
			if not seen_spot.has(sk):
				seen_spot[sk] = spots.size()
				spots.append(s)
			else:
				var o: Dictionary = spots[seen_spot[sk]]
				o.order = mini(o.order, k)
			from = at
			prev = s
			k += 1
	for sk in firsts:   # a few units: a leg each; a crowd: one leg from its middle, not a sheaf
		var f: Array = firsts[sk]
		var starts: Array = f[2]
		if starts.size() > GROUP_LEGS:
			var mid := Vector2.ZERO
			for p in starts:
				mid += p / starts.size()
			starts = [mid]
		for p in starts:
			legs.append([p, _edge(f[0], f[0].at, p), 0, f[1]])
	_place_pennants()


## A unit's orders, now and queued, as spots: {kind: move / amove / build / gather / drop /
## attack, x, y (milli) or id (a unit or building) or cell}. Read-only.
static func route(w, i: int) -> Array:
	var u = w.units
	var out := []
	if u.stance[i] == Combat.ATTACK_MOVE:
		if u.foe[i] != 0:
			out.append({"kind": "attack", "id": u.foe[i]})
		out.append({"kind": "amove", "x": u.amx[i], "y": u.amy[i]})
	elif u.foe[i] != 0 and u.stance[i] == Combat.ORDERED:
		out.append({"kind": "attack", "id": u.foe[i]})
	elif u.task[i] == Economy.BUILD:
		out.append({"kind": "build", "id": u.target[i]})
	elif u.task[i] == Economy.GATHER:
		out.append({"kind": "gather", "cell": u.target[i]})
	elif u.task[i] == Economy.GARRISON:   # going inside: marked like a drop-off at the building
		out.append({"kind": "drop", "id": u.target[i]})
	elif u.task[i] == Economy.RETURN:
		out.append({"kind": "drop", "id": u.target[i]})
		if u.home[i] >= 0:
			out.append({"kind": "gather", "cell": u.home[i]})
	elif u.moving[i] == 1:
		out.append({"kind": "move", "x": u.tx[i], "y": u.ty[i]})
	for o in u.orders[i]:
		var a: Dictionary = o.args
		match o.type:
			Commands.MOVE:
				out.append({"kind": "move", "x": a.x, "y": a.y})
			Commands.ATTACK_MOVE:
				out.append({"kind": "amove", "x": a.x, "y": a.y})
			Commands.GATHER:
				out.append({"kind": "gather", "cell": a.cell})
			Commands.HELP_BUILD:
				out.append({"kind": "build", "id": a.target})
			Commands.BUILD:
				out.append({"kind": "plan", "cx": a.cx, "cy": a.cy, "size": w.btypes[Economy.btype_of(w, a.building)].size})
			Commands.ATTACK:
				out.append({"kind": "attack", "id": a.target})
			Commands.DROP_OFF, Commands.GARRISON:
				out.append({"kind": "drop", "id": a.building})
	return out


## Where a spot sits on the canvas (filling in its footprint), or null if it's gone or hidden.
func _anchor(s: Dictionary) -> Variant:
	var w = d.world
	if s.has("x"):
		return Iso.to_screen(s.x, s.y)
	if s.has("cell"):
		s.cx = s.cell % w.map.width
		s.cy = s.cell / w.map.width
		s.size = 1
	elif s.has("id"):
		var b: int = w.buildings.index_of(s.id)
		if b >= 0:
			if s.kind == "attack" and not (d.bviews.has(s.id) and d.bviews[s.id].visible):
				return null
			s.cx = w.buildings.cx[b]
			s.cy = w.buildings.cy[b]
			s.size = maxi(w.buildings.sx[b], w.buildings.sy[b])   # a gate's long side
		else:
			var v: Node2D = d.views.get(s.id)
			if v == null or not v.visible:
				return null   # dead, or in the fog
			s.unit = w.units.index_of(s.id)
			return v.position
	var half: int = s.size * SimMap.TILE / 2
	return Iso.to_screen(s.cx * SimMap.TILE + half, s.cy * SimMap.TILE + half)


## A leg's end at a footprint stops at its edge (not across the foundation or the reeds).
func _edge(s: Dictionary, at: Vector2, toward: Vector2) -> Vector2:
	if not s.has("size") or s.has("unit"):
		return at
	var v := toward - at
	var half: Vector2 = Vector2(Iso.TILE_W, Iso.TILE_H) * 0.5 * float(s.size)
	var k: float = absf(v.x) / half.x + absf(v.y) / half.y
	return at + v / k if k > 1.0 else toward


func _fade(order: int) -> float:
	return maxf(FADE_MIN, 1.0 - FADE_STEP * order)


func _place_pennants() -> void:
	var n := 0
	var team := Color(d.lib.palettes.teams[d.active])
	for s in spots:
		if s.kind != "move" and s.kind != "amove":
			continue
		if n == pool.size():
			var f: Sprite2D = d.kit.sprite("waypoint_flag")
			d.layer.add_child(f)
			pool.append(f)
		var f: Sprite2D = pool[n]
		f.visible = true
		f.position = s.at
		f.self_modulate = team
		f.modulate = Color(1, 1, 1, _fade(s.order))
		n += 1
	for k in range(n, pool.size()):
		pool[k].visible = false


## Draw the dashed routes and the outlines under the units (from the marks layer's draw).
func draw(c: Node2D) -> void:
	var px: float = 1.0 / d.camera.zoom.x   # one screen pixel in canvas units
	for l in legs:
		var col: Color = FOE if l[3] else RING
		var a := _fade(l[2]) * (0.8 if l[2] == 0 else 0.95)
		c.draw_dashed_line(l[0], l[1], Color(EDGE, EDGE.a * a), 6.0 * px, 12.0 * px)
		c.draw_dashed_line(l[0], l[1], Color(col, a), 3.0 * px, 12.0 * px)
	for s in spots:
		var a := _fade(s.order)
		match s.kind:
			"move", "amove":   # a ground ring at the pennant's foot
				_ellipse(c, s.at, 6.0, FOE if s.kind == "amove" else RING, a, px)
			"attack":
				if s.has("unit"):
					_ellipse(c, s.at, d.world.units.radius[s.unit] * Iso.RADIUS_PX + 2.0, FOE, a, px)
				else:
					_diamond(c, s, FOE, a, px, false)
			"gather":
				_diamond(c, s, RING, a * 0.8, px, true)
			"build", "plan", "drop":
				_diamond(c, s, RING, a, px, false)


func _ellipse(c: Node2D, at: Vector2, r: float, col: Color, a: float, px: float) -> void:
	c.draw_set_transform(at, 0.0, Vector2(1.0, 0.5))
	c.draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(EDGE, 0.6 * a), 3.5 * px)
	c.draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(col, a), 2.0 * px)
	c.draw_set_transform(Vector2.ZERO)


## A footprint's outline (a resource tile's also softly filled), a dark edge under a bright line.
func _diamond(c: Node2D, s: Dictionary, col: Color, a: float, px: float, fill: bool) -> void:
	var x0: int = s.cx * SimMap.TILE
	var y0: int = s.cy * SimMap.TILE
	var e: int = s.size * SimMap.TILE
	var pts := PackedVector2Array([Iso.to_screen(x0, y0), Iso.to_screen(x0 + e, y0), Iso.to_screen(x0 + e, y0 + e),
		Iso.to_screen(x0, y0 + e), Iso.to_screen(x0, y0)])
	if fill:
		c.draw_colored_polygon(pts.slice(0, 4), Color(col, 0.14 * a))
	c.draw_polyline(pts, Color(EDGE, 0.6 * a), 3.5 * px)
	c.draw_polyline(pts, Color(col, a), 2.0 * px)


## Let go of the pennants (a new match: the atlas they cut from is baked again).
func clear() -> void:
	for f in pool:
		f.queue_free()
	pool.clear()
	flashed.clear()
