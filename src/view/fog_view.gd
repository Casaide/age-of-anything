extends Sprite2D
## Draws one player's fog of war (World.fog) over the map: never seen is near-black, explored
## is dimmed, visible is clear. The grid is a tiny texture, one pixel per tile, laid onto the
## isometric map by this node's transform; linear filtering softens the edges. Refreshed at the
## sim's fog rate. View side only.

const Iso := preload("res://src/view/iso.gd")
const SHADER := """
shader_type canvas_item;
void fragment() {
	float seen = texture(TEXTURE, UV).r;   // 0 unseen, 0.5 explored, 1 visible
	COLOR = vec4(0.03, 0.03, 0.06, clamp(1.0 - seen * 1.08, 0.0, 0.94));
}
"""

var image: Image
var shown := -1   # the fog version on screen (World tick it was taken at)
var shown_for: Array = [null, -1]   # [world, player] it shows


func _init() -> void:
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = SHADER
	material = m
	# Texture pixel (x, y) is tile (x, y): its axes are the iso projections of one tile along x and y.
	transform = Transform2D(Iso.to_screen(1000, 0), Iso.to_screen(0, 1000), Vector2.ZERO)


func refresh(w, player: int) -> void:
	if shown_for[0] == w and shown_for[1] == player and w.tick - shown < int(w.fog_cfg.every) and w.tick >= shown:
		return
	shown = w.tick
	shown_for = [w, player]
	var g: PackedByteArray = w.fog[player]
	var bytes := PackedByteArray()
	bytes.resize(g.size())
	for c in g.size():
		bytes[c] = g[c] * 127
	if image == null or image.get_width() != w.map.width:
		image = Image.create_from_data(w.map.width, w.map.height, false, Image.FORMAT_L8, bytes)
		texture = ImageTexture.create_from_image(image)
	else:
		image.set_data(w.map.width, w.map.height, false, Image.FORMAT_L8, bytes)
		(texture as ImageTexture).update(image)
