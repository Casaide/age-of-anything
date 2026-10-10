// A Kuwahara filter (four-sector, flat brush strokes) plus canvas grain:
// a cheap stand-in for hand-painted art, for the style sampler only.
shader_type canvas_item;

uniform int radius = 3;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec3 mean[4];
	vec3 sq[4];
	for (int k = 0; k < 4; k++) { mean[k] = vec3(0.0); sq[k] = vec3(0.0); }
	for (int j = -radius; j <= radius; j++) {
		for (int i = -radius; i <= radius; i++) {
			vec3 c = texture(TEXTURE, UV + vec2(float(i), float(j)) * px).rgb;
			if (i <= 0 && j <= 0) { mean[0] += c; sq[0] += c * c; }
			if (i >= 0 && j <= 0) { mean[1] += c; sq[1] += c * c; }
			if (i <= 0 && j >= 0) { mean[2] += c; sq[2] += c * c; }
			if (i >= 0 && j >= 0) { mean[3] += c; sq[3] += c * c; }
		}
	}
	float n = float((radius + 1) * (radius + 1));
	float best = 1e9;
	vec3 col = vec3(0.0);
	for (int k = 0; k < 4; k++) {
		vec3 m = mean[k] / n;
		vec3 v = abs(sq[k] / n - m * m);
		float s = v.r + v.g + v.b;
		if (s < best) { best = s; col = m; }
	}
	vec2 q = UV / px;
	float canvas = grain(floor(q)) * 0.05 + grain(floor(q * 0.33)) * 0.04;
	col = mix(vec3(dot(col, vec3(0.3, 0.59, 0.11))), col, 1.12);   // a touch more colour
	COLOR = vec4(col * (0.96 + canvas), 1.0);
}
