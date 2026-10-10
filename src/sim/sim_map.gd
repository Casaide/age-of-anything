extends RefCounted
## The sim's view of a map: a terrain grid, what's walkable, and start positions.
## Positions in the sim are milli-tiles; tile (tx, ty) covers [tx*1000, tx*1000+999].
## Maps are data (data/maps/*.json, ASCII rows + a legend into data/terrain.json);
## the view builds its TileMapLayer from the same file.

const Rng := preload("res://src/rng.gd")

const TILE := 1000
const SCHEMA := "aow.map/2"

var id: String
var width: int
var height: int
var terrain_ids: Array = []      # sorted terrain ids; terrain[] holds indexes into this
var terrain := PackedByteArray() # index ty * width + tx
var walk := PackedByteArray()    # 1 walkable, 0 blocked
var starts: Array = []           # [[x, y]] in milli-tiles, tile centres
var map_hash: int


static func load_terrain() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"))
	assert(d != null, "Bad or missing data/terrain.json")
	return d.terrain


static func load_id(map_id: String) -> RefCounted:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % map_id))
	assert(d != null, "Bad or missing map: %s" % map_id)
	assert(d.schema == SCHEMA and d.id == map_id, "Map %s: wrong schema or id" % map_id)
	var types := load_terrain()
	var m = new()
	m.id = map_id
	m.width = int(d.width)
	m.height = int(d.height)
	m.terrain_ids = types.keys()
	m.terrain_ids.sort()
	var index := {}   # legend char -> terrain index
	var legend_keys: Array = d.legend.keys()
	legend_keys.sort()
	var legend_text := ""
	for ch in legend_keys:
		var t: String = d.legend[ch]
		assert(types.has(t), "Map %s: unknown terrain %s" % [map_id, t])
		index[ch] = m.terrain_ids.find(t)
		legend_text += "%s=%s;%d;" % [ch, t, 1 if types[t].walkable else 0]
	assert(d.rows.size() == m.height, "Map %s has %d rows, expected %d" % [map_id, d.rows.size(), m.height])
	m.terrain.resize(m.width * m.height)
	m.walk.resize(m.width * m.height)
	for y in m.height:
		var row: String = d.rows[y]
		assert(row.length() == m.width, "Map %s row %d is %d wide" % [map_id, y, row.length()])
		for x in m.width:
			assert(index.has(row[x]), "Map %s: '%s' at %d,%d isn't in the legend" % [map_id, row[x], x, y])
			var k: int = index[row[x]]
			m.terrain[y * m.width + x] = k
			m.walk[y * m.width + x] = 1 if types[m.terrain_ids[k]].walkable else 0
	for s in d.starts:
		m.starts.append([int(s[0]) * TILE + TILE / 2, int(s[1]) * TILE + TILE / 2])
		assert(m.walkable(m.starts[-1][0], m.starts[-1][1]), "Map %s: start on blocked ground" % map_id)
	# Hash the content (rows + what each char means), not the file bytes.
	m.map_hash = Rng.hash_string("%s|%d|%d|%s|%s" % [map_id, m.width, m.height, legend_text, "\n".join(d.rows)])
	return m


func walkable(x: int, y: int) -> bool:
	if x < 0 or y < 0:
		return false
	var tx := x / TILE
	var ty := y / TILE
	if tx >= width or ty >= height:
		return false
	return walk[ty * width + tx] == 1


func cell_walkable(cx: int, cy: int) -> bool:
	return cx >= 0 and cy >= 0 and cx < width and cy < height and walk[cy * width + cx] == 1


func terrain_at(cell: int) -> String:
	return terrain_ids[terrain[cell]]
