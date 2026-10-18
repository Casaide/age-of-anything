extends Node2D
## The ground for a sim map in the pixel-art style: one polygon drawn by the terrain
## shader from blurred masks (R water, G swamp, B reed beds, A rock), plus each
## culture's generated paths, and the cosmetic doodads (stones, flowers, tufts,
## lilies, shore reeds, rock outcrops). No grid. View side only.

const Iso := preload("res://src/view/iso.gd")
const Paths := preload("res://scenes/art_pixel/paths.gd")

const K := 4   # mask samples per tile
const CHANNEL := {"water": 0, "swamp": 1, "reeds": 2, "rock": 3, "shallows": 0, "river": 0, "deep_river": 0, "ford": 0, "tree": 2, "stump": 2}
const WEIGHT := {"shallows": 0.62, "ford": 0.56, "river": 0.8, "tree": 0.75, "stump": 0.35}   # shallows draw as the water's edge band; a ford as wadeable shallows; a river's swimmable band lighter than its deep middle; a forest floor darker, like reed beds' ground

var map
var masks_img: Image
var paths_img: Image
var mat: ShaderMaterial
var cliff_mat: ShaderMaterial   # the cliff faces (high ground), or null on a flat map
var occluders: Array = []       # copies of raised ground in the y-sorted layer (build_relief)
## The cliff look for a concept sheet (AOW_CLIFF_STYLE in the environment), else CLIFF_STYLE.
static func cliff_style() -> int:
	var e := OS.get_environment("AOW_CLIFF_STYLE")
	return int(e) if e != "" else CLIFF_STYLE


func build(p_map) -> void:
	map = p_map
	var w: int = map.width
	var h: int = map.height
	var raw := PackedFloat32Array()
	raw.resize(w * K * h * K * 4)
	for y in h * K:
		for x in w * K:
			var name: String = map.terrain_ids[map.terrain[(y / K) * w + x / K]]
			if CHANNEL.has(name):
				raw[(y * w * K + x) * 4 + CHANNEL[name]] = WEIGHT.get(name, 1.0)
	masks_img = _to_image(_blur(raw, w * K, h * K, 5), w * K, h * K)
	paths_img = Image.create(w * K, h * K, false, Image.FORMAT_RGBA8)
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Iso.to_screen(0, 0), Iso.to_screen(w * 1000, 0), Iso.to_screen(w * 1000, h * 1000), Iso.to_screen(0, h * 1000)])
	poly.uv = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])   # flat: no lift (terrain.gdshader)
	mat = ShaderMaterial.new()
	mat.shader = load("res://scenes/art_pixel/terrain.gdshader")
	mat.set_shader_parameter("masks", ImageTexture.create_from_image(masks_img))
	mat.set_shader_parameter("paths", ImageTexture.create_from_image(paths_img))
	mat.set_shader_parameter("path_arc", ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RF)))
	mat.set_shader_parameter("map_size", Vector2(w, h))
	poly.material = mat
	add_child(poly)


## Screen pixels per art pixel, so the shader dithers on art pixels.
func set_art_px(px: float) -> void:
	mat.set_shader_parameter("art_px", px)
	if cliff_mat != null:
		cliff_mat.set_shader_parameter("art_px", px)


## owners: [{style, width, hub: Vector2, targets: [Vector2]}] in tile coordinates.
## Plan and paint the paths. On a worker thread, from a snapshot of the walkable grid, so a
## finished building doesn't stall the frame (it did: Dominic saw a hitch every time); the
## textures swap in when it's done. A request while one runs is kept and run after it.
var _paths_task := -1
var _paths_next = null     # owners waiting for their turn
var _paths_out := []       # [paths image, arc image] from the worker
var _paths_memo := {}      # the paths laid so far (Paths.plan memo): they stay put, new buildings add branches


func set_paths(owners: Array) -> void:
	if _paths_task >= 0:
		_paths_next = owners
		return
	var walk: PackedByteArray = map.walk.duplicate()
	var w: int = map.width
	var h: int = map.height
	_paths_task = WorkerThreadPool.add_task(func(): _paths_job(owners, walk, w, h))


func _paths_job(owners: Array, walk: PackedByteArray, w: int, h: int) -> void:
	var blocked_at := func(t: Vector2) -> bool:
		if t.x < 0.2 or t.y < 0.2 or t.x > w - 0.2 or t.y > h - 0.2:
			return true
		if walk[int(t.y) * w + int(t.x)] == 0:
			return true
		return mask(t).r > 0.3
	var planned: Array = Paths.plan(w, h, blocked_at, owners, _paths_memo)
	var m: Array = Paths.mask(w, h, K, planned)
	var img: Image = m[0]
	img.convert(Image.FORMAT_RGBAF)
	var raw: PackedFloat32Array = img.get_data().to_float32_array()
	_paths_out = [_to_image(_blur(raw, img.get_width(), img.get_height(), 2), img.get_width(), img.get_height()), m[1]]


## Wait for the paths being planned (at setup, where doodads must keep off them).
func finish_paths() -> void:
	if _paths_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_paths_task)
		_apply_paths()


func _process(_delta: float) -> void:
	if _paths_task >= 0 and WorkerThreadPool.is_task_completed(_paths_task):
		WorkerThreadPool.wait_for_task_completion(_paths_task)
		_apply_paths()


func _apply_paths() -> void:
	_paths_task = -1
	paths_img = _paths_out[0]
	mat.set_shader_parameter("paths", ImageTexture.create_from_image(paths_img))
	mat.set_shader_parameter("path_arc", ImageTexture.create_from_image(_paths_out[1]))
	if _paths_next != null:
		var next: Array = _paths_next
		_paths_next = null
		set_paths(next)


## Where paths can't go: off the map, blocked cells (terrain or buildings), near water.
func blocked(t: Vector2) -> bool:
	if t.x < 0.2 or t.y < 0.2 or t.x > map.width - 0.2 or t.y > map.height - 0.2:
		return true
	if map.walk[int(t.y) * map.width + int(t.x)] == 0:
		return true
	return mask(t).r > 0.3


## A blurred mask (0..1 per channel) at a point in tile coordinates.
func mask(t: Vector2) -> Color:
	return masks_img.get_pixel(clampi(int(t.x * K), 0, masks_img.get_width() - 1), clampi(int(t.y * K), 0, masks_img.get_height() - 1))


func on_path(t: Vector2) -> bool:
	var c := paths_img.get_pixel(clampi(int(t.x * K), 0, paths_img.get_width() - 1), clampi(int(t.y * K), 0, paths_img.get_height() - 1))
	return maxf(maxf(c.r, c.g), maxf(c.b, c.a)) > 0.25


## Scatter cosmetic doodads into the y-sorted layer: rock outcrops on rock cells,
## stones, flowers and tufts on open grass, lilies on water, reeds along the shore.
## Seeded, so the same map always looks the same. Returns the nodes made.
func scatter(kit, layer: Node2D, keep_clear: Callable) -> Array:
	var made := []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(map.id)
	var rock: int = map.terrain_ids.find("rock")
	var grass: int = map.terrain_ids.find("grass")
	for c in map.width * map.height:
		if map.terrain[c] == rock:
			# An outcrop, not a grid: stones deep inside it are big, ones at its edge small, each
			# nudged off its tile's centre (cosmetic; the sim only knows the tile blocks).
			var x: int = c % map.width
			var y: int = c / map.width
			var inner := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < map.width and ny < map.height and map.terrain[ny * map.width + nx] == rock:
					inner += 1
			var size := lerpf(0.75, 1.6, inner / 4.0) * rng.randf_range(0.85, 1.15)   # every rock tile keeps a stone: a gap would look walkable
			var at := Vector2(x + 0.5 + rng.randf_range(-0.22, 0.22), y + 0.5 + rng.randf_range(-0.22, 0.22))
			var h := _place(kit.doodad("rock", rng.randi()), at, layer)
			h.scale = Vector2(size, size)
			made.append(h)
	var area: int = map.width * map.height
	var want := {"stones": area / 40, "flowers": area / 22, "tuft": area / 12}
	for kind in ["stones", "flowers", "tuft"]:
		var placed := 0
		for i in want[kind] * 8:
			if placed >= want[kind]:
				break
			var t := Vector2(rng.randf_range(0.3, map.width - 0.3), rng.randf_range(0.3, map.height - 0.3))
			var c: int = int(t.y) * map.width + int(t.x)
			if map.terrain[c] != grass or map.cliff[c] == 1 or mask(t).r > 0.3 or mask(t).a > 0.3 or on_path(t) or keep_clear.call(t):
				continue
			made.append(_place(kit.doodad(kind, rng.randi()), t, layer))
			placed += 1
	for i in area * 2:
		var t := Vector2(rng.randf_range(0.3, map.width - 0.3), rng.randf_range(0.3, map.height - 0.3))
		var m := mask(t)
		if m.r > 0.7 and rng.randf() < 0.08:
			made.append(_place(kit.doodad("lily", rng.randi()), t, layer))
		elif m.r > 0.4 and m.r < 0.5 and rng.randf() < 0.25 and not keep_clear.call(t):
			made.append(_place(kit.doodad("shore", rng.randi()), t, layer))
	return made


## A variant pick (0..count-1) per cell, seeded per map, chosen so no cell repeats its
## already-picked neighbours (left, and the three above), so neighbours always differ.
static func variant_picks(cells: PackedInt32Array, width: int, count: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var picks := {}
	for c in cells:
		var taken := []
		for n in [c - 1, c - width - 1, c - width, c - width + 1]:
			if picks.has(n):
				taken.append(picks[n])
		var free := []
		for k in count:
			if not k in taken:
				free.append(k)
		picks[c] = free[rng.randi() % free.size()]
	return picks


func _place(s: Sprite2D, t: Vector2, layer: Node2D) -> Node2D:
	var holder := Node2D.new()
	holder.position = Iso.to_screen(t.x * 1000, t.y * 1000)
	s.position.y -= Iso.lift(t.x * 1000, t.y * 1000)   # on a hill: raised, sorted on the base plane
	holder.add_child(s)
	layer.add_child(holder)
	return holder


## Separable box blur over RGBA floats, edge-clamped: soft masks make round shores.
static func _blur(src: PackedFloat32Array, w: int, h: int, passes: int) -> PackedFloat32Array:
	var a := src
	var b := PackedFloat32Array()
	b.resize(a.size())
	for p in passes:
		for y in h:
			for x in w:
				var x0 := maxi(x - 1, 0)
				var x1 := mini(x + 1, w - 1)
				for ch in 4:
					b[(y * w + x) * 4 + ch] = (a[(y * w + x0) * 4 + ch] + a[(y * w + x) * 4 + ch] + a[(y * w + x1) * 4 + ch]) / 3.0
		for y in h:
			var y0 := maxi(y - 1, 0)
			var y1 := mini(y + 1, h - 1)
			for x in w:
				for ch in 4:
					a[(y * w + x) * 4 + ch] = (b[(y0 * w + x) * 4 + ch] + b[(y * w + x) * 4 + ch] + b[(y1 * w + x) * 4 + ch]) / 3.0
	return a


static func _to_image(raw: PackedFloat32Array, w: int, h: int) -> Image:
	var bytes := PackedByteArray()
	bytes.resize(w * h * 4)
	for i in raw.size():
		bytes[i] = clampi(int(raw[i] * 255.0 + 0.5), 0, 255)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes)


# ---------------------------------------------------------------- high ground (milestone 15)

## Cliff looks (concept round, D-080): 0 earth bank, 1 layered rock, 2 mossy boulders.
const CLIFF_STYLE := 1
## A raised cell this many steps in front of lower ground is also drawn in the y-sort (see
## build_relief), so a hill hides the units behind it.
const OCCLUDE_BACK := 2
## Occluders sort this far above their top corner, so a unit standing at the back edge of a
## raised cell (its shadow just over the next cell) isn't clipped by that cell's copy.
const OCCLUDE_SORT := 6.0


## The raised ground: Iso's corner heights drawn as lifted tops (the terrain shader again,
## told how far each vertex was lifted so it paints the ground of the cell, not of the screen
## point), cliff faces down every edge that drops towards the camera, ramps as slopes.
##
## Drawn in two parts. Under everything (children here, after the flat ground), level by
## level: faces then tops, so a higher step covers a lower one behind it. And, so that a hill
## hides what stands behind it, copies of the tops near a back edge go into the y-sorted
## `sorted` layer, one node per screen row (diagonal x + y), keyed at the row's top corner:
## units, buildings and props are keyed on the base plane (their art raised by Iso.lift), so
## a unit behind the hill sorts before the copy and one standing on it after.
func build_relief(sorted: Node2D, style := cliff_style()) -> void:
	if not map.has_heights:
		return
	Iso.set_relief(map)
	cliff_mat = ShaderMaterial.new()
	cliff_mat.shader = load("res://scenes/art_pixel/cliff.gdshader")
	cliff_mat.set_shader_parameter("style", style)
	cliff_mat.set_shader_parameter("level_px", Iso.LEVEL_PX)
	var w: int = map.width
	var h: int = map.height
	var hs := Iso.relief
	var faces := []   # per level group 1..3: [verts, uvs, cols]
	var rims := []    # the back edges' outline (a raised edge seen against the ground behind)
	var tops := []
	for k in 4:
		faces.append([PackedVector2Array(), PackedVector2Array(), PackedColorArray()])
		tops.append([PackedVector2Array(), PackedVector2Array(), PackedColorArray()])
		rims.append([PackedVector2Array(), PackedVector2Array(), PackedColorArray()])
	var rows := {}    # diagonal -> [verts, uvs, cols] of occluding tops
	var row_rims := {}   # diagonal -> their back rims
	for y in h:
		for x in w:
			var c := y * w + x
			var top := maxf(maxf(hs[c * 4], hs[c * 4 + 1]), maxf(hs[c * 4 + 2], hs[c * 4 + 3]))
			if top <= 0.0:
				continue
			var g := ceili(top)
			_top_quad(tops[g], x, y, c, Vector2.ZERO)
			_rims(rims[g], x, y, c, Vector2.ZERO)
			# Faces on the two edges that face the camera (+x: down-right, +y: down-left).
			if x + 1 < w:
				var n := c + 1
				_face(faces[g], Vector2(x + 1, y), Vector2(x + 1, y + 1), hs[c * 4 + 1], hs[c * 4 + 2], hs[n * 4], hs[n * 4 + 3], 0.0)
			if y + 1 < h:
				var n := c + w
				_face(faces[g], Vector2(x, y + 1), Vector2(x + 1, y + 1), hs[c * 4 + 3], hs[c * 4 + 2], hs[n * 4], hs[n * 4 + 1], 1.0)
			if _near_back_edge(x, y, top):
				var d := x + y
				if not rows.has(d):
					rows[d] = [PackedVector2Array(), PackedVector2Array(), PackedColorArray()]
				_top_quad(rows[d], x, y, c, Vector2(0, d * Iso.TILE_H * 0.5 - OCCLUDE_SORT))
				if not row_rims.has(d):
					row_rims[d] = [PackedVector2Array(), PackedVector2Array(), PackedColorArray()]
				_rims(row_rims[d], x, y, c, Vector2(0, d * Iso.TILE_H * 0.5 - OCCLUDE_SORT))
	for g in range(1, 4):
		add_child(_mesh(faces[g], cliff_mat))
		add_child(_mesh(tops[g], mat))
		add_child(_mesh(rims[g], null))
	var ds: Array = rows.keys()
	ds.sort()
	for d in ds:
		var node := _mesh(rows[d], mat)
		if row_rims.has(d):
			node.add_child(_mesh(row_rims[d], null))
		node.position = Vector2(0, d * Iso.TILE_H * 0.5 - OCCLUDE_SORT)
		sorted.add_child(node)
		occluders.append(node)


func _exit_tree() -> void:
	for n in occluders:   # they live in the y-sorted layer; they go with the ground
		if is_instance_valid(n):
			n.queue_free()


## Is there lower ground within OCCLUDE_BACK steps behind this raised cell (towards -x, -y)?
func _near_back_edge(x: int, y: int, top: float) -> bool:
	for dy in range(-OCCLUDE_BACK, 1):
		for dx in range(-OCCLUDE_BACK, 1):
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or ny < 0 or (dx == 0 and dy == 0):
				continue
			if map.level[ny * map.width + nx] + map.ramp[ny * map.width + nx] < top:
				return true
	return false


## A cell's top as two triangles: corners lifted by their heights; UV.x tells the shader the
## lift (so it paints the ground under the vertex), UV.y a shade for slopes (ramps facing away
## from the light are darker) and height (plateaus a touch lighter).
func _top_quad(out: Array, x: int, y: int, c: int, origin: Vector2) -> void:
	var hs := Iso.relief
	var corners := [Vector2(x, y), Vector2(x + 1, y), Vector2(x + 1, y + 1), Vector2(x, y + 1)]
	var hk := [hs[c * 4], hs[c * 4 + 1], hs[c * 4 + 2], hs[c * 4 + 3]]
	var gx: float = (hk[1] + hk[2] - hk[0] - hk[3]) * 0.5   # rise per tile along x and y
	var gy: float = (hk[2] + hk[3] - hk[0] - hk[1]) * 0.5
	var shade: float = 0.05 * (hk[0] + hk[1] + hk[2] + hk[3]) * 0.25 + clampf(gx * 0.8 + gy * 0.3, -1.0, 1.0) * 0.16
	for k in [0, 1, 2, 0, 2, 3]:
		var lift: float = hk[k] * Iso.LEVEL_PX
		out[0].append(Iso.to_screen(corners[k].x * 1000, corners[k].y * 1000) - Vector2(0, lift) - origin)
		out[1].append(Vector2(lift + origin.y, shade))   # the shader adds this to the (node-local) vertex: the canvas point it paints
		out[2].append(Color.WHITE)


## The back edges of a raised cell (towards -x and -y) where the ground behind is lower: a
## dark line just behind the edge (the drop, seen from above) and a sunlit lip on it.
func _rims(out: Array, x: int, y: int, c: int, origin: Vector2) -> void:
	var hs := Iso.relief
	var w: int = map.width
	var edges := []   # [corner a, corner b, own heights at them, the neighbour's]
	if x > 0:
		var n := c - 1
		edges.append([Vector2(x, y), Vector2(x, y + 1), hs[c * 4], hs[c * 4 + 3], hs[n * 4 + 1], hs[n * 4 + 2]])
	if y > 0:
		var n := c - w
		edges.append([Vector2(x, y), Vector2(x + 1, y), hs[c * 4], hs[c * 4 + 1], hs[n * 4 + 3], hs[n * 4 + 2]])
	for e in edges:
		if e[2] - e[4] < 0.5 and e[3] - e[5] < 0.5:
			continue
		var a: Vector2 = Iso.to_screen(e[0].x * 1000, e[0].y * 1000) - Vector2(0, e[2] * Iso.LEVEL_PX) - origin
		var b: Vector2 = Iso.to_screen(e[1].x * 1000, e[1].y * 1000) - Vector2(0, e[3] * Iso.LEVEL_PX) - origin
		_band(out, a, b, -1.6, 0.0, Color(0.12, 0.10, 0.06, 0.5))
		_band(out, a, b, 0.0, 1.2, Color(0.55, 0.66, 0.30, 0.9))


func _band(out: Array, a: Vector2, b: Vector2, y0: float, y1: float, col: Color) -> void:
	var q := [a + Vector2(0, y0), b + Vector2(0, y0), b + Vector2(0, y1), a + Vector2(0, y1)]
	for k in [0, 1, 2, 0, 2, 3]:
		out[0].append(q[k])
		out[1].append(Vector2.ZERO)
		out[2].append(col)


## A cliff face down one edge (corners a and b, in tiles), from the cell's heights at them
## (ha, hb) to its neighbour's (na, nb), if it drops. UV: x along the edge (tiles), y the
## height at that point (levels); colour: r the rim's height / 3, g which way it faces, b the
## foot's height / 3.
func _face(out: Array, a: Vector2, b: Vector2, ha: float, hb: float, na: float, nb: float, side: float) -> void:
	na = minf(na, ha)
	nb = minf(nb, hb)
	if ha - na < 0.01 and hb - nb < 0.01:
		return
	var pa := Iso.to_screen(a.x * 1000, a.y * 1000)
	var pb := Iso.to_screen(b.x * 1000, b.y * 1000)
	var along_a: float = a.y if side == 0.0 else a.x
	var along_b: float = b.y if side == 0.0 else b.x
	var quad := [[pa, ha, along_a, ha, na], [pb, hb, along_b, hb, nb], [pb, nb, along_b, hb, nb], [pa, na, along_a, ha, na]]
	for k in [0, 1, 2, 0, 2, 3]:
		var q: Array = quad[k]
		out[0].append(q[0] - Vector2(0, q[1] * Iso.LEVEL_PX))
		out[1].append(Vector2(q[2], q[1]))
		out[2].append(Color(q[3] / 3.0, side, q[4] / 3.0, 1.0))


func _mesh(arrays: Array, material: Material) -> MeshInstance2D:
	var node := MeshInstance2D.new()
	node.material = material
	if arrays[0].is_empty():
		return node
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = arrays[0]
	a[Mesh.ARRAY_TEX_UV] = arrays[1]
	a[Mesh.ARRAY_COLOR] = arrays[2]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	node.mesh = m
	return node
