// The shared palette as a whole-frame pass over the game world (under the UI):
// every pixel takes its nearest palette colour, with a light ordered dither on art
// pixels. The same look as the pixel-art scene's palette, at screen resolution.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D palette : filter_nearest;
uniform int count = 64;
uniform float dither = 0.035;
uniform float art_px = 2.0;     // screen pixels per art pixel

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 c = texture(screen, SCREEN_UV);
	ivec2 p = ivec2(FRAGCOORD.xy / art_px) % 4;
	float d = (BAYER[p.y * 4 + p.x] / 16.0 - 0.5) * dither;
	vec3 want = c.rgb + vec3(d);
	vec3 best = vec3(0.0);
	float best_d = 1e9;
	for (int i = 0; i < count; i++) {
		vec3 q = texelFetch(palette, ivec2(i, 0), 0).rgb;
		vec3 e = (want - q) * vec3(0.30, 0.59, 0.11);
		float dd = dot(e, e) + dot(want - q, want - q) * 0.2;
		if (dd < best_d) { best_d = dd; best = q; }
	}
	COLOR = vec4(best, 1.0);
}
