extends RefCounted
## Unit slots bucketed by tile, rebuilt every tick: slots sorted by (tile, slot), so within a
## bucket slots are in ascending order and queries are deterministic. Only the tiles that held
## someone are touched (a sort and two passes over the units, not over the map).
## Cells are one tile; unit radii are capped at half a tile, so any overlap
## between two units is found by looking at the 3x3 cells around one of them.

const TILE := 1000
const SLOT_BITS := 20   # slots per sort key (a million units is plenty)

var width: int
var height: int
var start := PackedInt32Array()   # bucket c holds items[start[c] .. end[c] - 1] (empty: start == end)
var end := PackedInt32Array()
var items := PackedInt32Array()   # unit slots
var cell := PackedInt32Array()    # unit slot -> cell
var _used := PackedInt32Array()   # cells with someone in them at the last build
var _keys := PackedInt64Array()


func _init(w: int, h: int) -> void:
	width = w
	height = h
	start.resize(w * h)
	end.resize(w * h)


func cell_at(x: int, y: int) -> int:
	return clampi(y / TILE, 0, height - 1) * width + clampi(x / TILE, 0, width - 1)


func build(xs: PackedInt32Array, ys: PackedInt32Array) -> void:
	var n := xs.size()
	for c in _used:
		start[c] = 0
		end[c] = 0
	cell.resize(n)
	items.resize(n)
	_keys.resize(n)
	var w := width
	var h1 := height - 1
	var w1 := width - 1
	for i in n:
		var c := clampi(ys[i] / TILE, 0, h1) * w + clampi(xs[i] / TILE, 0, w1)
		cell[i] = c
		_keys[i] = (c << SLOT_BITS) | i
	_keys.sort()
	_used.resize(0)
	var prev := -1
	var mask := (1 << SLOT_BITS) - 1
	for k in n:
		var key := _keys[k]
		var c := key >> SLOT_BITS
		items[k] = key & mask
		if c != prev:
			start[c] = k
			_used.append(c)
			prev = c
		end[c] = k + 1
