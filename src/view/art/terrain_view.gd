extends Node2D
## The ground for a sim map in the pixel-art style: one polygon drawn by the terrain
## shader from blurred masks (R water, G swamp, B reed beds, A rock), plus each
## culture's generated paths, and the cosmetic doodads (stones, flowers, tufts,
## lilies, shore reeds, rock outcrops). No grid. View side only.

const Iso := preload("res://src/view/iso.gd")
const Paths := preload("res://scenes/art_pixel/paths.gd")

const K := 4   # mask samples per tile
const CHANNEL := {"water": 0, "swamp": 1, "reeds": 2, "rock": 3, "shallows": 0}
const WEIGHT := {"shallows": 0.62}   # shallows draw as the water's edge band

var map
var masks_img: Image
var paths_img: Image
var mat: ShaderMaterial


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


## owners: [{style, width, hub: Vector2, targets: [Vector2]}] in tile coordinates.
func set_paths(owners: Array) -> void:
	var planned: Array = Paths.plan(map.width, map.height, blocked, owners)
	var m: Array = Paths.mask(map.width, map.height, K, planned)
	var img: Image = m[0]
	var raw := PackedFloat32Array()
	raw.resize(img.get_width() * img.get_height() * 4)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var i := (y * img.get_width() + x) * 4
			raw[i] = c.r
			raw[i + 1] = c.g
			raw[i + 2] = c.b
			raw[i + 3] = c.a
	paths_img = _to_image(_blur(raw, img.get_width(), img.get_height(), 2), img.get_width(), img.get_height())
	mat.set_shader_parameter("paths", ImageTexture.create_from_image(paths_img))
	mat.set_shader_parameter("path_arc", ImageTexture.create_from_image(m[1]))


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
			made.append(_place(kit.doodad("rock", rng.randi()), Vector2(c % map.width + 0.5, c / map.width + 0.5), layer))
	var area: int = map.width * map.height
	var want := {"stones": area / 40, "flowers": area / 22, "tuft": area / 12}
	for kind in ["stones", "flowers", "tuft"]:
		var placed := 0
		for i in want[kind] * 8:
			if placed >= want[kind]:
				break
			var t := Vector2(rng.randf_range(0.3, map.width - 0.3), rng.randf_range(0.3, map.height - 0.3))
			var c: int = int(t.y) * map.width + int(t.x)
			if map.terrain[c] != grass or mask(t).r > 0.3 or mask(t).a > 0.3 or on_path(t) or keep_clear.call(t):
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
