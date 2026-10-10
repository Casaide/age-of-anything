extends RefCounted
## The sim's view of a map: a walkable tile grid and start positions.
## Positions in the sim are milli-tiles; tile (tx, ty) covers [tx*1000, tx*1000+999].
## Milestone 2 bakes this from a TileMapLayer; for now it's ASCII rows in data/maps/.

const Rng := preload("res://src/rng.gd")

const TILE := 1000

var id: String
var width: int
var height: int
var walk := PackedByteArray()   # 1 walkable, 0 blocked; index ty * width + tx
var starts: Array = []          # [[x, y]] in milli-tiles, tile centres
var map_hash: int


static func load_id(map_id: String) -> RefCounted:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % map_id))
	assert(d != null, "Bad or missing map: %s" % map_id)
	assert(d.id == map_id, "Map file id mismatch: %s" % map_id)
	var m = new()
	m.id = map_id
	m.width = int(d.width)
	m.height = int(d.height)
	assert(d.rows.size() == m.height, "Map %s has %d rows, expected %d" % [map_id, d.rows.size(), m.height])
	m.walk.resize(m.width * m.height)
	for y in m.height:
		var row: String = d.rows[y]
		assert(row.length() == m.width, "Map %s row %d is %d wide" % [map_id, y, row.length()])
		for x in m.width:
			m.walk[y * m.width + x] = 1 if row[x] == "." else 0
	for s in d.starts:
		m.starts.append([int(s[0]) * TILE + TILE / 2, int(s[1]) * TILE + TILE / 2])
	# Hash the content, not the file bytes, so line endings and indentation don't matter.
	m.map_hash = Rng.hash_string("%s|%d|%d|%s" % [map_id, m.width, m.height, "\n".join(d.rows)])
	return m


func walkable(x: int, y: int) -> bool:
	if x < 0 or y < 0:
		return false
	var tx := x / TILE
	var ty := y / TILE
	if tx >= width or ty >= height:
		return false
	return walk[ty * width + tx] == 1
