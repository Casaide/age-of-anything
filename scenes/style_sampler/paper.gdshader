// Paper grain and fibres over the whole panel, for the style sampler.
shader_type canvas_item;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 q = UV / TEXTURE_PIXEL_SIZE;
	float fine = hash(floor(q)) * 0.07;
	float fibre = hash(floor(vec2(q.x * 0.15, q.y * 0.6))) * 0.05;
	COLOR = vec4(c.rgb * (0.93 + fine + fibre), c.a);
}
