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
