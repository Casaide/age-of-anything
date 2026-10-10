// Continuous pixel-art ground for a tile map: no grid. Terrain comes from blurred
// masks (R water, G swamp, B reed-bed ground) perturbed by noise, so borders are
// round and organic. Water gets a mud bank, a wet edge, depth and sparkles.
shader_type canvas_item;

uniform sampler2D masks : filter_linear, repeat_disable;
uniform sampler2D paths : filter_linear, repeat_disable;   // R trail, G boardwalk, B cobble, A road
uniform vec2 map_size;          // tiles
varying vec2 world;             // canvas units at scale 1 (64 x 32 per tile)

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

vec3 ramp4(vec3 a, vec3 b, vec3 c, vec3 d, float v) {
	float q = floor(clamp(v, 0.0, 0.999) * 4.0);
	return q < 1.0 ? a : q < 2.0 ? b : q < 3.0 ? c : d;
}

void vertex() {
	world = VERTEX;
}

void fragment() {
	float a = world.x / 32.0;
	float b = world.y / 16.0;
	vec2 t = vec2((a + b) * 0.5, (b - a) * 0.5);   // tile coordinates
	if (t.x < 0.0 || t.y < 0.0 || t.x > map_size.x || t.y > map_size.y) {
		discard;
	}
	vec4 m = texture(masks, t / map_size);
	float n = vnoise(t * 2.3) * 0.6 + vnoise(t * 6.1) * 0.4;
	float grain = vnoise(t * 9.0) * 0.55 + vnoise(t * 23.0) * 0.45;
	vec2 cell = floor(t * 22.0);              // pixel-cluster grid in tile space

	// Grass: four greens by noise, with light flecks and dark tufts.
	vec3 col = ramp4(vec3(0.24, 0.36, 0.14), vec3(0.30, 0.43, 0.17), vec3(0.36, 0.50, 0.20), vec3(0.43, 0.56, 0.24), grain);
	float h = hash(cell);
	if (h > 0.965) col = vec3(0.52, 0.63, 0.29);
	else if (h < 0.03) col = vec3(0.19, 0.29, 0.11);

	float reed = m.b + (n - 0.5) * 0.35;
	if (reed > 0.5) {
		col = ramp4(vec3(0.30, 0.31, 0.15), vec3(0.36, 0.37, 0.18), vec3(0.42, 0.42, 0.21), vec3(0.47, 0.46, 0.24), grain);
	}
	float swamp = m.g + (n - 0.5) * 0.4;
	if (swamp > 0.5) {
		col = ramp4(vec3(0.15, 0.24, 0.20), vec3(0.18, 0.29, 0.22), vec3(0.22, 0.33, 0.23), vec3(0.27, 0.36, 0.22), grain);
		if (hash(cell + 7.0) > 0.975) col = vec3(0.30, 0.48, 0.22);   // a little lily pad
	} else if (swamp > 0.44) {
		col = mix(col, vec3(0.20, 0.27, 0.16), 0.6);
	}

	vec4 pth = texture(paths, t / map_size);
	// Trail: packed earth with pebbles, ragged at the edges.
	float dirt = pth.r + (n - 0.5) * 0.45;
	if (dirt > 0.5) {
		col = ramp4(vec3(0.38, 0.30, 0.19), vec3(0.44, 0.35, 0.22), vec3(0.50, 0.40, 0.26), vec3(0.55, 0.45, 0.30), grain);
		if (hash(cell + 3.0) > 0.95) col = vec3(0.62, 0.58, 0.50);
		else if (hash(cell + 5.0) < 0.04) col = vec3(0.30, 0.24, 0.15);
	} else if (dirt > 0.42) {
		col = mix(col, vec3(0.42, 0.38, 0.22), 0.55);
	}
	// Boardwalk: planks across the walk with dark gaps and nail heads, on beams.
	float board = pth.g + (n - 0.5) * 0.12;
	if (board > 0.5) {
		float u = (t.x - t.y) * 3.2;
		float plank = floor(u);
		float tone = hash(vec2(plank, 7.0));
		col = mix(vec3(0.42, 0.29, 0.16), vec3(0.56, 0.40, 0.23), tone);
		if (fract(u) < 0.12) col = vec3(0.20, 0.13, 0.07);
		if (board < 0.6) col = vec3(0.30, 0.20, 0.11);
		if (hash(cell + plank) > 0.985) col = vec3(0.70, 0.66, 0.58);
	} else if (board > 0.44) {
		col = mix(col, vec3(0.18, 0.15, 0.10), 0.5);
	}
	// Cobbles: rounded stones with dark grout, a touch grimy.
	float cob = pth.b + (n - 0.5) * 0.25;
	if (cob > 0.5) {
		vec2 p = t * 7.0;
		vec2 ip = floor(p);
		float d1 = 9.0;
		float d2 = 9.0;
		vec2 id = vec2(0.0);
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 o = ip + vec2(float(i), float(j));
				vec2 q = o + vec2(hash(o), hash(o + 3.1)) * 0.8 + 0.1;
				float d = length(p - q);
				if (d < d1) { d2 = d1; d1 = d; id = o; } else if (d < d2) { d2 = d; }
			}
		}
		float s = hash(id + 9.0);
		col = mix(vec3(0.40, 0.39, 0.34), vec3(0.58, 0.56, 0.50), s);
		if (d2 - d1 < 0.16) col = vec3(0.22, 0.21, 0.17);
		else if (p.y - floor(p.y) < 0.25 && s > 0.5) col += vec3(0.06);
	} else if (cob > 0.44) {
		col = mix(col, vec3(0.28, 0.27, 0.22), 0.5);
	}
	// Road: dressed stone slabs in staggered courses, with kerbstones along the edges.
	float road = pth.a + (n - 0.5) * 0.08;
	if (road > 0.5) {
		vec2 p = t * vec2(3.0, 4.0);
		p.x += mod(floor(p.y), 2.0) * 0.5;
		vec2 f = fract(p);
		float s = hash(floor(p));
		col = mix(vec3(0.62, 0.59, 0.52), vec3(0.74, 0.71, 0.63), s);
		if (f.x < 0.06 || f.y < 0.08) col = vec3(0.36, 0.34, 0.30);
		if (road < 0.6) col = (fract(t.x * 5.0 + t.y * 5.0) < 0.12) ? vec3(0.30, 0.29, 0.26) : vec3(0.50, 0.48, 0.43);
	} else if (road > 0.45) {
		col = mix(col, vec3(0.30, 0.28, 0.24), 0.45);
	}
	float water = m.r + (n - 0.5) * 0.3;
	if (water > 0.40) {
		col = ramp4(vec3(0.33, 0.27, 0.17), vec3(0.38, 0.31, 0.19), vec3(0.43, 0.36, 0.22), vec3(0.48, 0.41, 0.26), grain);   // mud bank
	}
	if (water > 0.47) {
		col = vec3(0.24, 0.20, 0.14);                                    // wet edge
	}
	if (water > 0.5) {
		float depth = smoothstep(0.5, 0.95, m.r);
		vec3 shallow = vec3(0.22, 0.42, 0.44);
		vec3 deep = vec3(0.10, 0.22, 0.32);
		col = mix(shallow, deep, floor(depth * 4.0) / 3.0);
		if (water < 0.53) col = vec3(0.55, 0.70, 0.66);                  // foam line
		float ripple = vnoise(vec2(t.x * 5.0 + TIME * 0.25, t.y * 9.0));
		if (ripple > 0.78) col += vec3(0.06, 0.08, 0.08);
		if (hash(cell + floor(TIME * 1.5)) > 0.992) col = vec3(0.85, 0.95, 0.92);   // sparkle
	}
	COLOR = vec4(col, 1.0);
}
