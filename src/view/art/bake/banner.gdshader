// A banner baked as one sprite, waving: the cloth ripples more away from the pole.
// Pixels in the magenta team key take the team colour from self_modulate (COLOR),
// as in src/team_mask.gdshader; other banners pass COLOR as white and are untouched.
shader_type canvas_item;

uniform float amp = 0.035;

varying vec4 tint;   // self_modulate, read before the texture is multiplied in

void vertex() {
	tint = COLOR;
}

void fragment() {
	float wave = sin(UV.x * 9.0 - TIME * 4.0);
	vec2 uv = UV + vec2(0.0, wave * amp * UV.x);
	vec4 c = texture(TEXTURE, uv);
	vec3 rgb = c.rgb;
	if (min(rgb.r, rgb.b) - rgb.g > 0.22 && abs(rgb.r - rgb.b) < 0.3) {
		rgb = tint.rgb * max(rgb.r, rgb.b) * 1.08;
	}
	COLOR = vec4(rgb * (0.9 + 0.12 * sin(UV.x * 9.0 - TIME * 4.0 + 1.4)), c.a);
}
