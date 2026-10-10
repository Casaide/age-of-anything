// Team colour for baked art. Sprites are baked with a magenta team key; this swaps
// key pixels for the team colour, keeping the baked shading. The colour comes in
// through self_modulate, and its alpha carries extra shade (1 normal, < 1 for the
// far leg), so everything can share one material and one atlas and batch together.
// The modulate colour is read in vertex(): in fragment() COLOR already includes the texture.
shader_type canvas_item;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 c = t.rgb;
	if (min(c.r, c.b) - c.g > 0.22 && abs(c.r - c.b) < 0.3) {
		c = tint.rgb * max(c.r, c.b) * 1.08;
	}
	COLOR = vec4(c * tint.a, t.a);
}
