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
const ROOM_CHUNK := 2              # cells a side of a block counted in `tight` (Flow.clear_path's quickest answer)
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
var roomy: Array = []              # per lane (made when first asked for: roomy_grid), 1 where the cell and its 8 neighbours are on the map and walkable
var tight: Array = []              # per lane, alongside roomy: cells not roomy per ROOM_CHUNK x ROOM_CHUNK block (PackedInt32Array)
var room_cw := 0                   # blocks across (tight)
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
var opaque_version := 0            # bumped whenever a cell starts or stops blocking sight (fog.gd's kept sight circles)
## High ground (milestone 15): a level per cell, 0-3, from the map's optional `heights` rows
## (digits; a ramp is a letter: `a` climbs from 0 to 1, `b` from 1 to 2, `c` from 2 to 3). A
## cell lower than a neighbour it has no ramp to is a cliff: the foot of the step, where the
## face stands, blocked for everyone but flyers. So walkers only change level on a ramp, and
## the walk grids (flow fields, movement, separation) need nothing else.
const RAMPS := "abc"
var has_heights := false
var level := PackedByteArray()     # 0-3 per cell (a ramp: the level at its foot)
var ramp := PackedByteArray()      # 1 on a ramp (a slope from `level` up to level + 1)
var cliff := PackedByteArray()     # 1 at the foot of a step without a ramp: blocked but for flyers
var level_chunks := PackedByteArray()   # the highest level per CHUNK x CHUNK block (fog skips flat country)
var bridge_rects: Array = []       # the map's bridges: [x0, y0, x1, y1] cells, inclusive (World makes them, bridges.gd)
var resource_cells := PackedInt32Array()   # every cell that started with a resource, ascending
var starts: Array = []             # [[x, y]] in milli-tiles, tile centres
var start_teams: Array = []        # the team each start is for (a 2v2: [0, 1, 0, 1]), or [] (everyone for themselves)
var animals := {}                  # the map's own animal spawn (data/animals.json "spawn" shape), or {} for the default
var symmetry := ""                 # "rotate": the map is the same turned half a turn (animals are placed to match)
var map_hash: int                  # content hash of the file, for replays
var version := 0
var fresh := PackedInt32Array()    # cells changed this tick (the World reads and clears it)
var fresh_closed := PackedByteArray()   # per fresh entry: 1 if some lane lost a walkable cell there (else it only opened)
var fresh_was := {}                # fresh cell -> PackedByteArray: its walk value per lane before this tick's first change
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
	m.level.resize(n)
	m.ramp.resize(n)
	m.cliff.resize(n)
	m.level_chunks.resize(m.opaque_chunks.size())
	var heights: Array = d.get("heights", [])
	m.has_heights = not heights.is_empty()
	if m.has_heights:
		m._load_heights(heights)
	for s in d.starts:
		m.starts.append([int(s[0]) * TILE + TILE / 2, int(s[1]) * TILE + TILE / 2])
		assert(m.walkable(m.starts[-1][0], m.starts[-1][1]), "Map %s: start on blocked ground" % map_id)
	for r in d.get("bridges", []):
		assert(r.size() == 4 and r[0] <= r[2] and r[1] <= r[3], "Map %s: a bridge is [x0, y0, x1, y1]" % map_id)
		m.bridge_rects.append([int(r[0]), int(r[1]), int(r[2]), int(r[3])])
	m.start_teams = d.get("teams", []).map(func(t): return int(t))
	assert(m.start_teams.is_empty() or m.start_teams.size() == m.starts.size(), "Map %s: a team per start" % map_id)
	m.animals = d.get("animals", {})
	m.symmetry = d.get("symmetry", "")
	assert(m.symmetry in ["", "rotate"], "Map %s: unknown symmetry %s" % [map_id, m.symmetry])
	# Hash the content (rows + what each char means, and the map's own animals), not the file bytes.
	var content := "%s|%d|%d|%s|%s" % [map_id, m.width, m.height, legend_text, "\n".join(d.rows)]
	if not m.animals.is_empty():
		content += "|%s|%s" % [m.symmetry, JSON.stringify(m.animals, "", true)]
	if not m.bridge_rects.is_empty():
		content += "|bridges|%s" % JSON.stringify(m.bridge_rects)
	if m.has_heights:
		content += "|heights|%s" % "\n".join(heights)
	m.map_hash = Rng.hash_string(content)
	return m


## Levels and ramps from the map's `heights` rows, then the cliffs they make (blocked to walkers).
func _load_heights(rows: Array) -> void:
	assert(rows.size() == height, "Map %s: %d heights rows, expected %d" % [id, rows.size(), height])
	for y in height:
		var row: String = rows[y]
		assert(row.length() == width, "Map %s heights row %d is %d wide" % [id, y, row.length()])
		for x in width:
			var c := y * width + x
			var ch := row[x]
			if RAMPS.contains(ch):
				level[c] = RAMPS.find(ch)
				ramp[c] = 1
			else:
				assert(ch >= "0" and ch <= "3", "Map %s: height '%s' at %d,%d (0-3, or a ramp a-c)" % [id, ch, x, y])
				level[c] = ch.unicode_at(0) - 48
			var k := chunk_of(c)
			level_chunks[k] = maxi(level_chunks[k], level[c] + ramp[c])
	for y in height:
		for x in width:
			var c := y * width + x
			var top: int = level[c] + ramp[c]   # the highest ground this cell reaches
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and ny >= 0 and nx < width and ny < height and level[ny * width + nx] > top:
						cliff[c] = 1
			if cliff[c] == 1:
				walk[c] = 0
				for k in CLASSES.size():
					if k != FLYING:
						walks[k][c] = 0


## The level at (x, y) milli-tiles (a ramp counts as its foot).
func level_at(x: int, y: int) -> int:
	return level[cell_of(x, y)]


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


## Lane k's roomy grid (see `roomy`): a straight walk that only passes roomy cells is clear for any
## body up to half a tile wide, whatever its line (Flow.clear_path's quick answer).
func roomy_grid(k: int) -> PackedByteArray:
	while roomy.size() <= k:
		var g := PackedByteArray()
		g.resize(width * height)
		g.fill(2)   # (not yet worked out: _roomy_cell counts every cell's first answer into `tight`)
		roomy.append(g)
		room_cw = (width + ROOM_CHUNK - 1) / ROOM_CHUNK
		var t := PackedInt32Array()
		t.resize(room_cw * ((height + ROOM_CHUNK - 1) / ROOM_CHUNK))
		tight.append(t)
		for c in g.size():
			_roomy_cell(roomy.size() - 1, c)
	return roomy[k]


## Lane k's count of cells not roomy per block (`tight`); roomy_grid(k) first.
func tight_grid(k: int) -> PackedInt32Array:
	return tight[k]


func _roomy_round(k: int, cell: int) -> void:
	var cx := cell % width
	var cy := cell / width
	for y in range(maxi(cy - 1, 0), mini(cy + 2, height)):
		for x in range(maxi(cx - 1, 0), mini(cx + 2, width)):
			_roomy_cell(k, y * width + x)


func _roomy_cell(k: int, c: int) -> void:
	var g: PackedByteArray = walks[k]
	var cx := c % width
	var cy := c / width
	var ok := cx > 0 and cy > 0 and cx < width - 1 and cy < height - 1
	if ok:
		for y in range(cy - 1, cy + 2):
			for x in range(cx - 1, cx + 2):
				if g[y * width + x] == 0:
					ok = false
	var v := 1 if ok else 0
	var was: int = roomy[k][c]
	if was == v:
		return
	roomy[k][c] = v
	var b := (cy / ROOM_CHUNK) * room_cw + cx / ROOM_CHUNK
	if v == 0:
		tight[k][b] += 1
	elif was == 0:
		tight[k][b] -= 1


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


## Let these cells of a building be walked across (a pen: animals stand inside), or not.
func set_walk_over(cells: PackedInt32Array, on: bool) -> void:
	for c in cells:
		walk_over[c] = 1 if on else 0
		_refresh(c)


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
			if cliff[c] == 1 or ramp[c] == 1 or level[c] != level[cy * width + cx]:
				return false   # not on a cliff or a ramp, and all on one level
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
	var was := PackedByteArray()
	for g in walks:
		was.append(g[cell])
	if not fresh_was.has(cell):
		fresh_was[cell] = was
	var clear: bool = (occupied[cell] == 0 or walk_over[cell] == 1) and cliff[cell] == 0   # buildings and cliffs block, farms don't
	var ground: bool = terrain_walk[terrain[cell]] or deck[cell] == 1   # a bridge's deck is ground over the water
	walk[cell] = 1 if ground and clear else 0
	var mask: int = terrain_move[terrain[cell]] | (7 if deck[cell] == 1 else 0)
	var op := 1 if terrain_opaque[terrain[cell]] else 0
	if op != opaque[cell]:
		opaque_chunks[chunk_of(cell)] += op - opaque[cell]
		opaque[cell] = op
		opaque_version += 1
	for k in CLASSES.size():
		# Buildings block everyone but flyers.
		walks[k][cell] = 1 if mask & (1 << k) and (k == FLYING or clear) else 0
	walks[0][cell] = walk[cell]
	for g in range(1, lane_teams.size()):   # a team's own gates are open to it
		var open: bool = clear or gate[cell] == lane_teams[g] + 1
		for k in CLASSES.size():
			walks[g * CLASSES.size() + k][cell] = 1 if mask & (1 << k) and (k == FLYING or open) else 0
		walks[g * CLASSES.size()][cell] = 1 if ground and open else 0   # as walks[0] follows walk
	for k in roomy.size():   # keep the roomy grids made so far in step with this cell
		if was[k] != walks[k][cell]:
			_roomy_round(k, cell)
	version += 1
	var closed := 0
	for k in walks.size():
		if was[k] == 1 and walks[k][cell] == 0:
			closed = 1
	fresh.append(cell)
	fresh_closed.append(closed)
	if changed.size() < 4096:
		changed.append(cell)
	else:
		changed_overflow = true
