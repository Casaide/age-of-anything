// A banner baked as one sprite, waving: the cloth ripples more away from the pole.
shader_type canvas_item;

uniform float amp = 0.035;

void fragment() {
	float wave = sin(UV.x * 9.0 - TIME * 4.0);
	vec2 uv = UV + vec2(0.0, wave * amp * UV.x);
	vec4 c = texture(TEXTURE, uv);
	COLOR = vec4(c.rgb * (0.9 + 0.12 * sin(UV.x * 9.0 - TIME * 4.0 + 1.4)), c.a);
}
