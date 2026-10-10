// Team colour for baked unit parts. Parts are baked with a magenta team key; this
// swaps key pixels for the team colour, keeping the baked shading. The colour
// comes in through self_modulate (COLOR.rgb), and COLOR.a carries extra shade
// (1 normal, < 1 for the far leg), so every unit can share one material and one
// atlas and batch together.
shader_type canvas_item;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 c = t.rgb;
	float key = min(c.r, c.b) - c.g;
	if (key > 0.22 && abs(c.r - c.b) < 0.3) {
		c = COLOR.rgb * max(c.r, c.b) * 1.08;
	}
	COLOR = vec4(c * COLOR.a, t.a);
}
