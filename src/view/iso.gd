extends RefCounted
## Isometric projection between sim milli-tiles and canvas pixels.
## The sim grid is square; the view draws each tile as a 2:1 diamond, so
## sim +x goes down-right on screen and sim +y goes down-left.

const TILE_W := 64.0
const TILE_H := 32.0
const MILLI := 1000.0
## A circle of radius r milli-tiles is drawn as an ellipse r * this wide (and half as tall).
const RADIUS_PX := TILE_W * 0.5 * 1.41421356 / MILLI


static func to_screen(x: float, y: float) -> Vector2:
	return Vector2((x - y) * TILE_W * 0.5 / MILLI, (x + y) * TILE_H * 0.5 / MILLI)


static func to_milli(p: Vector2) -> Vector2i:
	var a := p.x / (TILE_W * 0.5)
	var b := p.y / (TILE_H * 0.5)
	return Vector2i(roundi((a + b) * 0.5 * MILLI), roundi((b - a) * 0.5 * MILLI))


## Canvas rect enclosing a width x height tile map.
static func map_rect(width: int, height: int) -> Rect2:
	var w := width * MILLI
	var h := height * MILLI
	var r := Rect2(to_screen(0, 0), Vector2.ZERO)
	for c in [to_screen(w, 0), to_screen(0, h), to_screen(w, h)]:
		r = r.expand(c)
	return r


## High ground (milestone 15). The map's levels lift the ground on screen: LEVEL_PX per level.
## `relief` holds four corner heights (in levels) per cell, so a ramp slopes from its foot to
## the plateau. Set once per match (set_relief); empty on a flat map, where lift() is 0.
const LEVEL_PX := 20.0
static var relief := PackedFloat32Array()   # per cell: corners top (x0 y0), right (x1 y0), bottom (x1 y1), left (x0 y1)
static var relief_w := 0
static var relief_h := 0


## Corner heights for a map with levels (SimMap.has_heights), or none.
static func set_relief(map) -> void:
	relief = corner_heights(map) if map != null and map.has_heights else PackedFloat32Array()
	relief_w = map.width if map != null else 0
	relief_h = map.height if map != null else 0


## Per cell its four corners' heights in levels: a plain cell is flat at its level; a ramp's
## corners rise to the level above where they touch ground of that level (or a ramp up from it).
static func corner_heights(map) -> PackedFloat32Array:
	var w: int = map.width
	var h: int = map.height
	var out := PackedFloat32Array()
	out.resize(w * h * 4)
	const CORNERS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]
	for y in h:
		for x in w:
			var c := y * w + x
			var lv: int = map.level[c]
			for k in 4:
				var v := float(lv)
				if map.ramp[c] == 1:
					# The four cells round this corner: is any of them up a level?
					var cx: int = x + CORNERS[k].x
					var cy: int = y + CORNERS[k].y
					for n in [Vector2i(cx - 1, cy - 1), Vector2i(cx, cy - 1), Vector2i(cx - 1, cy), Vector2i(cx, cy)]:
						if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
							continue
						var o: int = n.y * w + n.x
						if map.level[o] > lv:
							v = lv + 1.0
				out[c * 4 + k] = v
	return out


## How far the ground at (x, y) milli-tiles is raised on screen, in pixels (0 on a flat map).
static func lift(x: float, y: float) -> float:
	if relief.is_empty():
		return 0.0
	var tx := clampi(int(x / MILLI), 0, relief_w - 1)
	var ty := clampi(int(y / MILLI), 0, relief_h - 1)
	var c := (ty * relief_w + tx) * 4
	var fx := clampf(x / MILLI - tx, 0.0, 1.0)
	var fy := clampf(y / MILLI - ty, 0.0, 1.0)
	var top := lerpf(relief[c], relief[c + 1], fx)
	var bottom := lerpf(relief[c + 3], relief[c + 2], fx)
	return lerpf(top, bottom, fy) * LEVEL_PX


## The ground point on screen: to_screen raised by the ground's height.
static func to_ground(x: float, y: float) -> Vector2:
	return to_screen(x, y) - Vector2(0, lift(x, y))


## The sim point under a screen point, on raised ground: the highest ground drawn there wins
## (a hill hides what's behind it). On a flat map, to_milli.
static func pick(p: Vector2) -> Vector2i:
	if relief.is_empty():
		return to_milli(p)
	for lv in range(3, 0, -1):
		var m := to_milli(p + Vector2(0, lv * LEVEL_PX))
		var l := lift(m.x, m.y)
		if absf(l - lv * LEVEL_PX) < LEVEL_PX * 0.5 and m.x >= 0 and m.y >= 0:
			for k in 3:   # on a slope: settle on the point whose raised place is p
				m = to_milli(p + Vector2(0, lift(m.x, m.y)))
			return m
	var m0 := to_milli(p)
	for k in 3:
		m0 = to_milli(p + Vector2(0, lift(m0.x, m0.y)))
	return m0
