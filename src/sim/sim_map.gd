extends RefCounted
## The sim's map: terrain per cell, what's walkable, resources left, start positions.
## Positions in the sim are milli-tiles; tile (tx, ty) covers [tx*1000, tx*1000+999].
## Maps are data (data/maps/*.json, ASCII rows + a legend into data/terrain.json);
## the view builds its TileMapLayer from the same file.
##
## The map changes during a match: resources run out (the tile becomes its
## `depleted` terrain) and buildings occupy tiles. Every change bumps `version`
## and is listed in `fresh` (for the World) and `changed` (for the view).

const Rng := preload("res://src/rng.gd")

const TILE := 1000
const CHUNK := 8
const SCHEMA := "aow.map/2"

var id: String
var width: int
var height: int
var terrain_ids: Array = []        # sorted terrain ids; terrain[] holds indexes into this
## Movement classes: each has its own walkability (flyers cross water, rock and buildings;
## amphibians wade shallows). Terrains list the classes that cross them (`move`).
const CLASSES := ["ground", "amphibious", "flying"]
const FLYING := 2

var terrain_walk: Array = []       # terrain index -> bool (ground: where you can build)
var terrain_move: Array = []       # terrain index -> bitmask of the classes that can cross it
var terrain_resource: Array = []   # terrain index -> "food" / "wood" / ""
var terrain_amount: Array = []     # terrain index -> starting amount per tile
var terrain_depleted: Array = []   # terrain index -> terrain index it turns into, or -1
var terrain_reseed: Array = []     # terrain index -> what reseeding turns it back into (fallow -> field), or -1
var terrain_cleared: Array = []    # terrain index -> what it becomes when its farm is torn down, or -1
var terrain_opaque: Array = []     # terrain index -> bool: blocks sight (trees: fog.gd)
var terrain := PackedByteArray()   # index ty * width + tx
var walk := PackedByteArray()      # ground: 1 walkable, 0 blocked (terrain or a building)
var walks: Array = []              # per lane, the same grid (walks[0] matches walk); see lanes below
## Lanes: one walk grid per movement class, for everyone (lanes 0-2), and once a team has a
## gate, another three for that team, where its own gates are open (lane = group * 3 + class).
## Gates are closed in the shared lanes, so maps without gates keep just the three.
var gate := PackedInt32Array()     # per cell: the team a gate standing there opens for, + 1; 0 if none
var lane_teams: Array = [-2]       # per lane group: the team its gates open for (group 0: nobody's)
var occupied := PackedInt32Array() # building id standing on the cell, or 0
var amount := PackedInt32Array()   # resource left on the cell (for a pooled cell: on its anchor)
var pool := PackedInt32Array()     # pooled cells (a farm's): the anchor cell holding the shared amount, or -1
var walk_over := PackedByteArray() # 1 where a building may be walked across (farms)
var deck := PackedByteArray()      # 1 where a standing bridge spans the water: ground and amphibians walk it (bridges.gd)
var opaque := PackedByteArray()    # 1 where the cell blocks sight (a tree), for fog.gd
var opaque_chunks := PackedInt32Array()   # opaque cells per CHUNK x CHUNK block, so sight skips open country
var bridge_rects: Array = []       # the map's bridges: [x0, y0, x1, y1] cells, inclusive (World makes them, bridges.gd)
var resource_cells := PackedInt32Array()   # every cell that started with a resource, ascending
var starts: Array = []             # [[x, y]] in milli-tiles, tile centres
var animals := {}                  # the map's own animal spawn (data/animals.json "spawn" shape), or {} for the default
var symmetry := ""                 # "rotate": the map is the same turned half a turn (animals are placed to match)
var map_hash: int                  # content hash of the file, for replays
var version := 0
var fresh := PackedInt32Array()    # cells changed this tick (the World reads and clears it)
var changed := PackedInt32Array()  # cells changed since the view last looked (view clears it)
var changed_overflow := false      # too many to list: the view should redraw everything


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
	for t in m.terrain_ids:
		var td: Dictionary = types[t]
		m.terrain_walk.append(bool(td.walkable))
		var move: Array = td.get("move", CLASSES if bool(td.walkable) else ["flying"])
		var mask := 0
		for c in move:
			assert(c in CLASSES, "Terrain %s: unknown movement class %s" % [t, c])
			mask |= 1 << CLASSES.find(c)
		m.terrain_move.append(mask)
		m.terrain_resource.append(td.get("resource", ""))
		m.terrain_amount.append(int(td.get("amount", 0)))
		m.terrain_opaque.append(bool(td.get("opaque", false)))
	for t in m.terrain_ids:
		var dep: String = types[t].get("depleted", "")
		assert(dep == "" or types.has(dep), "Terrain %s depletes into unknown %s" % [t, dep])
		m.terrain_depleted.append(m.terrain_ids.find(dep) if dep != "" else -1)
		for field in ["reseed", "cleared"]:
			var to: String = types[t].get(field, "")
			assert(to == "" or types.has(to), "Terrain %s: unknown %s terrain %s" % [t, field, to])
			m.get("terrain_" + field).append(m.terrain_ids.find(to) if to != "" else -1)
	var index := {}   # legend char -> terrain index
	var legend_keys: Array = d.legend.keys()
	legend_keys.sort()
	var legend_text := ""
	for ch in legend_keys:
		var t: String = d.legend[ch]
		assert(types.has(t), "Map %s: unknown terrain %s" % [map_id, t])
		index[ch] = m.terrain_ids.find(t)
		legend_text += "%s=%s;%d;%s;" % [ch, t, 1 if types[t].walkable else 0, ",".join(types[t].get("move", []))]
	assert(d.rows.size() == m.height, "Map %s has %d rows, expected %d" % [map_id, d.rows.size(), m.height])
	var n: int = m.width * m.height
	m.terrain.resize(n)
	m.walk.resize(n)
	for k in CLASSES.size():
		var g := PackedByteArray()
		g.resize(n)
		m.walks.append(g)
	m.occupied.resize(n)
	m.gate.resize(n)
	m.amount.resize(n)
	m.pool.resize(n)
	m.pool.fill(-1)
	m.walk_over.resize(n)
	m.deck.resize(n)
	m.opaque.resize(n)
	m.opaque_chunks.resize(((m.width + CHUNK - 1) / CHUNK) * ((m.height + CHUNK - 1) / CHUNK))
	for y in m.height:
		var row: String = d.rows[y]
		assert(row.length() == m.width, "Map %s row %d is %d wide" % [map_id, y, row.length()])
		for x in m.width:
			assert(index.has(row[x]), "Map %s: '%s' at %d,%d isn't in the legend" % [map_id, row[x], x, y])
			var k: int = index[row[x]]
			var c: int = y * m.width + x
			m.terrain[c] = k
			m.walk[c] = 1 if m.terrain_walk[k] else 0
			for mc in CLASSES.size():
				m.walks[mc][c] = 1 if m.terrain_move[k] & (1 << mc) else 0
			m.walks[0][c] = m.walk[c]
			m.amount[c] = m.terrain_amount[k]
			if m.terrain_amount[k] > 0:
				m.resource_cells.append(c)
			if m.terrain_opaque[k]:
				m.opaque[c] = 1
				m.opaque_chunks[m.chunk_of(c)] += 1
	for s in d.starts:
		m.starts.append([int(s[0]) * TILE + TILE / 2, int(s[1]) * TILE + TILE / 2])
		assert(m.walkable(m.starts[-1][0], m.starts[-1][1]), "Map %s: start on blocked ground" % map_id)
	for r in d.get("bridges", []):
		assert(r.size() == 4 and r[0] <= r[2] and r[1] <= r[3], "Map %s: a bridge is [x0, y0, x1, y1]" % map_id)
		m.bridge_rects.append([int(r[0]), int(r[1]), int(r[2]), int(r[3])])
	m.animals = d.get("animals", {})
	m.symmetry = d.get("symmetry", "")
	assert(m.symmetry in ["", "rotate"], "Map %s: unknown symmetry %s" % [map_id, m.symmetry])
	# Hash the content (rows + what each char means, and the map's own animals), not the file bytes.
	var content := "%s|%d|%d|%s|%s" % [map_id, m.width, m.height, legend_text, "\n".join(d.rows)]
	if not m.animals.is_empty():
		content += "|%s|%s" % [m.symmetry, JSON.stringify(m.animals, "", true)]
	if not m.bridge_rects.is_empty():
		content += "|bridges|%s" % JSON.stringify(m.bridge_rects)
	m.map_hash = Rng.hash_string(content)
	return m


## Can a unit in lane `k` (its movement class, in its team's lane group: World.lane) stand at
## (x, y) milli-tiles?
func walkable(x: int, y: int, k := 0) -> bool:
	if x < 0 or y < 0:
		return false
	var tx := x / TILE
	var ty := y / TILE
	if tx >= width or ty >= height:
		return false
	return walks[k][ty * width + tx] == 1


func cell_walkable(cx: int, cy: int, k := 0) -> bool:
	return cx >= 0 and cy >= 0 and cx < width and cy < height and walks[k][cy * width + cx] == 1


## The sight chunk a cell is in (opaque_chunks).
func chunk_of(cell: int) -> int:
	return (cell / width / CHUNK) * ((width + CHUNK - 1) / CHUNK) + (cell % width) / CHUNK


## Lay or lift a bridge's deck over these cells (bridges.gd).
func set_deck(cells: PackedInt32Array, on: bool) -> void:
	for c in cells:
		deck[c] = 1 if on else 0
		_refresh(c)


func cell_of(x: int, y: int) -> int:
	return clampi(y / TILE, 0, height - 1) * width + clampi(x / TILE, 0, width - 1)


func terrain_at(cell: int) -> String:
	return terrain_ids[terrain[cell]]


## "food", "wood" or "" for a cell that has (or had) none left.
func resource_at(cell: int) -> String:
	if amount[_anchor(cell)] <= 0:
		return ""
	return terrain_resource[terrain[cell]]


func _anchor(cell: int) -> int:
	return pool[cell] if pool[cell] >= 0 else cell


## How much is left at a cell (a pooled cell answers for its whole pool).
func left_at(cell: int) -> int:
	return amount[_anchor(cell)]


## Take one unit of resource. When the last one goes, the tile turns into its depleted terrain.
func take(cell: int) -> void:
	var a := _anchor(cell)
	assert(amount[a] > 0, "Nothing left to take at cell %d" % cell)
	amount[a] -= 1
	if amount[a] > 0:
		return
	var cells := PackedInt32Array([cell]) if pool[cell] < 0 else pool_cells(a)
	for c in cells:
		var dep: int = terrain_depleted[terrain[c]]
		if dep >= 0:
			terrain[c] = dep
		_refresh(c)


## Pool some cells into one resource (a farm: one thing, one amount), held on the first cell.
## Their terrain becomes `k`; the anchor joins resource_cells, the rest point at it.
func make_pool(cells: PackedInt32Array, k: int, total: int) -> void:
	var a: int = cells[0]
	for c in cells:
		terrain[c] = k
		amount[c] = 0
		pool[c] = a
		walk_over[c] = 1   # a farm: walk straight across it
		_refresh(c)
	amount[a] = total
	var at := resource_cells.bsearch(a)
	if at >= resource_cells.size() or resource_cells[at] != a:
		resource_cells.insert(at, a)


## Every cell pooled on this anchor, ascending.
func pool_cells(a: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in pool.size():
		if pool[c] == a:
			out.append(c)
	return out


## Unpool cells and turn them into terrain `k` (a farm torn down).
func clear_pool(cells: PackedInt32Array, k: int) -> void:
	for c in cells:
		pool[c] = -1
		amount[c] = 0
		walk_over[c] = 0
		terrain[c] = k
		_refresh(c)


## Mark a building's footprint (id) or clear it (0). A gate (`gate_team` >= 0) blocks like any
## building, except in that team's own lanes (made here, the first time the team has a gate).
func occupy(cells: PackedInt32Array, building_id: int, gate_team := -1) -> void:
	if gate_team >= 0 and lane_group(gate_team) == 0:
		lane_teams.append(gate_team)
		for k in CLASSES.size():
			walks.append(walks[k].duplicate())   # the shared grids as they stand; _refresh opens the gates
	for c in cells:
		occupied[c] = building_id
		gate[c] = gate_team + 1 if building_id != 0 else 0
		_refresh(c)


## The lane group a team walks in: its own if it has ever had a gate, else 0 (everyone's).
func lane_group(team: int) -> int:
	for g in range(1, lane_teams.size()):
		if lane_teams[g] == team:
			return g
	return 0


## Can a building of this size go here? On ground anyone could build on, or, if the
## building allows water (`water_ok`) and the builders' movement class `mc` can wade it,
## in the shallows (amphibians build on the water).
func can_build(cx: int, cy: int, size: int, mc := 0, water_ok := false) -> bool:
	for y in range(cy, cy + size):
		for x in range(cx, cx + size):
			if x < 0 or y < 0 or x >= width or y >= height:
				return false
			var c := y * width + x
			if occupied[c] != 0 or amount[c] > 0 or deck[c] == 1:
				return false
			var t: int = terrain[c]
			if not terrain_walk[t] and not (water_ok and mc != FLYING and terrain_move[t] & (1 << mc)):
				return false
	return true


## Change a cell's terrain (a farm becoming a field): its amount and walkability follow.
func set_terrain(cell: int, k: int) -> void:
	terrain[cell] = k
	amount[cell] = terrain_amount[k]
	if amount[cell] > 0:
		var at := resource_cells.bsearch(cell)
		if at >= resource_cells.size() or resource_cells[at] != cell:
			resource_cells.insert(at, cell)
	_refresh(cell)


func _refresh(cell: int) -> void:
	var clear: bool = occupied[cell] == 0 or walk_over[cell] == 1   # buildings block, farms don't
	var ground: bool = terrain_walk[terrain[cell]] or deck[cell] == 1   # a bridge's deck is ground over the water
	walk[cell] = 1 if ground and clear else 0
	var mask: int = terrain_move[terrain[cell]] | (7 if deck[cell] == 1 else 0)
	var op := 1 if terrain_opaque[terrain[cell]] else 0
	if op != opaque[cell]:
		opaque_chunks[chunk_of(cell)] += op - opaque[cell]
		opaque[cell] = op
	for k in CLASSES.size():
		# Buildings block everyone but flyers.
		walks[k][cell] = 1 if mask & (1 << k) and (k == FLYING or clear) else 0
	walks[0][cell] = walk[cell]
	for g in range(1, lane_teams.size()):   # a team's own gates are open to it
		var open: bool = clear or gate[cell] == lane_teams[g] + 1
		for k in CLASSES.size():
			walks[g * CLASSES.size() + k][cell] = 1 if mask & (1 << k) and (k == FLYING or open) else 0
		walks[g * CLASSES.size()][cell] = 1 if ground and open else 0   # as walks[0] follows walk
	version += 1
	fresh.append(cell)
	if changed.size() < 4096:
		changed.append(cell)
	else:
		changed_overflow = true
