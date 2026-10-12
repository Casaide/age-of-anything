extends Sprite2D
## Draws one player's fog of war (World.fog) over the map: never seen is near-black, explored
## is dimmed, visible is clear. The grid is a tiny texture, one pixel per tile, laid onto the
## isometric map by this node's transform; linear filtering softens the edges. Refreshed at the
## sim's fog rate. View side only.

const Iso := preload("res://src/view/iso.gd")
## On a map with high ground the fog lies on the raised ground as drawn: each pixel walks down
## the screen to the frontmost ground drawn there (a hill's top or its cliff face) and takes
## that cell's fog, so a plateau's fog sits on the plateau, not on the ground behind it.
const SHADER := """
shader_type canvas_item;
uniform sampler2D heights : filter_nearest, repeat_disable;   // R: a cell's height in levels / 3 (a ramp half way)
uniform vec2 map_size = vec2(1.0);
uniform float level_px = 0.0;   // 0: a flat map
void fragment() {
	vec2 uv = UV;
	if (level_px > 0.0) {
		vec2 t = UV * map_size;
		// Down the screen by j pixels is (j / 32) tiles along both axes (Iso: 64 x 32 tiles).
		for (float j = 3.0 * level_px; j >= 0.0; j -= 2.0) {
			vec2 q = t + vec2(j / 32.0);
			float h = texture(heights, q / map_size).r * 3.0;
			if (h * level_px >= j - 1.0) {
				vec2 top = t + vec2(h * level_px / 32.0);   // the point whose lift brings it here
				uv = (floor(top) == floor(q) ? top : q) / map_size;   // its top, or the face it hangs from
				break;
			}
		}
	}
	float seen = texture(TEXTURE, uv).r;   // 0 unseen, 0.5 explored, 1 visible
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
	if shown_for[0] != w:
		_set_relief(w.map)   # a new match
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


## The map's heights for the shader (none on a flat map).
func _set_relief(m) -> void:
	var mat: ShaderMaterial = material
	if not m.has_heights:
		mat.set_shader_parameter("level_px", 0.0)
		return
	var hb := PackedByteArray()
	hb.resize(m.width * m.height)
	for c in hb.size():
		hb[c] = int((m.level[c] + 0.5 * m.ramp[c]) / 3.0 * 255.0 + 0.5)
	mat.set_shader_parameter("heights", ImageTexture.create_from_image(Image.create_from_data(m.width, m.height, false, Image.FORMAT_L8, hb)))
	mat.set_shader_parameter("map_size", Vector2(m.width, m.height))
	mat.set_shader_parameter("level_px", Iso.LEVEL_PX)
