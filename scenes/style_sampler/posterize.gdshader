// Fewer colours for the pixel-art sample (the panel itself renders at 1/3 size).
shader_type canvas_item;

uniform float levels = 8.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(floor(c.rgb * levels + 0.5) / levels, c.a);
}
