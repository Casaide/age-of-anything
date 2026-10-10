extends TileMapLayer
## Builds an isometric TileMapLayer from a sim map. The map JSON is the source
## of truth; this is only its picture. Placeholder tiles are flat diamonds in
## each terrain's two colours (checkered), generated here until the art pass.

const Iso := preload("res://src/view/iso.gd")
const SimMap := preload("res://src/sim/sim_map.gd")


func build(map: SimMap) -> void:
	var types := SimMap.load_terrain()
	var tw := int(Iso.TILE_W)
	var th := int(Iso.TILE_H)
	var img := Image.create(tw * map.terrain_ids.size() * 2, th, false, Image.FORMAT_RGBA8)
	for k in map.terrain_ids.size():
		var t: Dictionary = types[map.terrain_ids[k]]
		_diamond(img, (k * 2) * tw, Color(t.colour))
		_diamond(img, (k * 2 + 1) * tw, Color(t.colour2))
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(tw, th)
	for col in map.terrain_ids.size() * 2:
		src.create_tile(Vector2i(col, 0))
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(tw, th)
	ts.add_source(src, 0)
	tile_set = ts
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clear()
	for c in map.width * map.height:
		_paint(map, c)
	map.changed.clear()
	map.changed_overflow = false
	# Line tile centres up with the projection of sim cell centres.
	position = Iso.to_screen(500, 500) - map_to_local(Vector2i(0, 0))


## Repaint the tiles the sim changed since last time (cut reeds become grass).
func refresh(map: SimMap) -> void:
	if map.changed_overflow:
		for c in map.width * map.height:
			_paint(map, c)
	else:
		for c in map.changed:
			_paint(map, c)
	map.changed.clear()
	map.changed_overflow = false


func _paint(map: SimMap, c: int) -> void:
	var cx := c % map.width
	var cy := c / map.width
	set_cell(Vector2i(cx, cy), 0, Vector2i(map.terrain[c] * 2 + ((cx + cy) & 1), 0))


func _diamond(img: Image, x0: int, colour: Color) -> void:
	var tw := int(Iso.TILE_W)
	var th := int(Iso.TILE_H)
	for py in th:
		var dy := absf(py + 0.5 - th * 0.5) / (th * 0.5)
		var half := int(ceil(tw * 0.5 * (1.0 - dy))) + 1   # bleed a pixel so neighbours meet
		for px in range(maxi(tw / 2 - half, 0), mini(tw / 2 + half, tw)):
			img.set_pixel(x0 + px, py, colour)
