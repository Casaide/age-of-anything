extends RefCounted
## Unit slots bucketed by tile, rebuilt every tick with a counting sort.
## Within a bucket, slots are in ascending order, so queries are deterministic.
## Cells are one tile; unit radii are capped at half a tile, so any overlap
## between two units is found by looking at the 3x3 cells around one of them.

const TILE := 1000

var width: int
var height: int
var start := PackedInt32Array()   # bucket c holds items[start[c] .. start[c + 1] - 1]
var items := PackedInt32Array()   # unit slots
var cell := PackedInt32Array()    # unit slot -> cell


func _init(w: int, h: int) -> void:
	width = w
	height = h
	start.resize(w * h + 1)


func cell_at(x: int, y: int) -> int:
	return clampi(y / TILE, 0, height - 1) * width + clampi(x / TILE, 0, width - 1)


func build(xs: PackedInt32Array, ys: PackedInt32Array) -> void:
	var n := xs.size()
	cell.resize(n)
	items.resize(n)
	start.fill(0)
	for i in n:
		var c := cell_at(xs[i], ys[i])
		cell[i] = c
		start[c + 1] += 1
	for c in width * height:
		start[c + 1] += start[c]
	var fill := start.duplicate()
	for i in n:
		var c := cell[i]
		items[fill[c]] = i
		fill[c] += 1
