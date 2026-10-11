// Continuous pixel-art ground for a tile map: no grid. Terrain comes from blurred
// masks (R water, G swamp, B reed-bed ground) perturbed by noise, so borders are
// round and organic. Water gets a mud bank, a wet edge, depth and sparkles.
shader_type canvas_item;

uniform sampler2D masks : filter_linear, repeat_disable;
uniform sampler2D paths : filter_linear, repeat_disable;   // R trail, G boardwalk, B cobble, A road
uniform sampler2D path_arc : filter_linear, repeat_disable;   // R: distance along the nearest path (tiles)
uniform vec2 map_size;          // tiles
varying vec2 world;             // canvas units at scale 1 (64 x 32 per tile)

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

// Gentle rolling ground, in tiles: a few octaves of smooth noise.
float height(vec2 t) {
	return vnoise(t * 0.35) * 0.55 + vnoise(t * 0.8 + 3.0) * 0.3 + vnoise(t * 1.9 + 7.0) * 0.15;
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

	// Ordered dither for pixel-art banding (art pixels: this canvas is at art resolution).
	float bay = BAYER[(int(FRAGCOORD.y) % 4) * 4 + (int(FRAGCOORD.x) % 4)] / 16.0 - 0.5;

	// Rolling ground, lit by the sun from the screen's upper left (-x in tiles),
	// in five dithered light bands rather than a smooth gradient.
	vec2 e = vec2(0.06, 0.0);
	vec2 grad = vec2(height(t + e.xy) - height(t - e.xy), height(t + e.yx) - height(t - e.yx)) / (2.0 * e.x);
	float lit = clamp(0.5 + dot(grad, vec2(-0.8, -0.25)) * 1.1, 0.0, 1.0);
	float light = mix(0.8, 1.16, floor(clamp(lit + bay * 0.3, 0.0, 0.999) * 5.0) / 4.0);

	// Grass: lush and darker near water, drier and yellower in open patches, with
	// clover clumps, light flecks and dark tufts.
	float lush = smoothstep(0.04, 0.35, m.r);
	float dry = smoothstep(0.5, 0.78, vnoise(t * 0.45 + 17.0)) * (1.0 - lush);
	float g = clamp(grain + bay * 0.22, 0.0, 0.999);
	vec3 col = ramp4(vec3(0.24, 0.36, 0.14), vec3(0.30, 0.43, 0.17), vec3(0.36, 0.50, 0.20), vec3(0.43, 0.56, 0.24), g);
	vec3 dry_col = ramp4(vec3(0.36, 0.38, 0.16), vec3(0.44, 0.45, 0.19), vec3(0.52, 0.51, 0.24), vec3(0.60, 0.57, 0.30), g);
	vec3 lush_col = ramp4(vec3(0.16, 0.30, 0.13), vec3(0.20, 0.36, 0.15), vec3(0.24, 0.42, 0.18), vec3(0.30, 0.48, 0.20), g);
	if (dry + bay * 0.3 > 0.45) col = dry_col;
	if (lush + bay * 0.3 > 0.5) col = lush_col;
	float h = hash(cell);
	if (h > 0.965) col = col * 1.25 + vec3(0.04, 0.05, 0.0);
	else if (h < 0.03) col *= 0.7;
	if (vnoise(t * 3.1 + 40.0) > 0.78 && hash(cell + 21.0) > 0.4) col = mix(col, vec3(0.28, 0.48, 0.20), 0.6);   // clover

	// Reed beds: damp ground, a little darker and more olive, fading out with no edge.
	float reed = clamp(m.b * 1.3 + (n - 0.5) * 0.5, 0.0, 1.0);
	col = mix(col, col * vec3(0.8, 0.86, 0.72), floor(reed * 3.0) / 3.0 * 0.8);
	float swamp = m.g + (n - 0.5) * 0.4;
	if (swamp > 0.5) {
		col = ramp4(vec3(0.15, 0.24, 0.20), vec3(0.18, 0.29, 0.22), vec3(0.22, 0.33, 0.23), vec3(0.27, 0.36, 0.22), grain);
		if (hash(cell + 7.0) > 0.975) col = vec3(0.30, 0.48, 0.22);   // a little lily pad
	} else if (swamp > 0.44) {
		col = mix(col, vec3(0.20, 0.27, 0.16), 0.6);
	}

	vec4 pth = texture(paths, t / map_size);
	// Where path styles meet, the locally strongest surface wins, so seams are ragged.
	float st_trail = pth.r + (n - 0.5) * 0.45;
	float st_board = pth.g + (n - 0.5) * 0.12;
	float st_cob = pth.b + (n - 0.5) * 0.25;
	float st_road = pth.a + (n - 0.5) * 0.08;
	float jag = (hash(floor(t * 11.0)) - 0.5) * 0.12;
	float top = max(max(st_trail, st_board + jag), max(st_cob - jag, st_road + jag * 0.5));
	if (top > 0.5) {
		if (top == st_trail) {
			// Trail: packed earth with pebbles.
			col = ramp4(vec3(0.38, 0.30, 0.19), vec3(0.44, 0.35, 0.22), vec3(0.50, 0.40, 0.26), vec3(0.55, 0.45, 0.30), grain);
			if (hash(cell + 3.0) > 0.95) col = vec3(0.62, 0.58, 0.50);
			else if (hash(cell + 5.0) < 0.04) col = vec3(0.30, 0.24, 0.15);
		} else if (top == st_board + jag) {
			// Boardwalk: planks laid across the walk, dark gaps, nail heads; beams at the edges.
			float u = texture(path_arc, t / map_size).r * 3.4;
			float plank = floor(u);
			col = mix(vec3(0.42, 0.29, 0.16), vec3(0.56, 0.40, 0.23), hash(vec2(plank, 7.0)));
			if (fract(u) < 0.13) col = vec3(0.20, 0.13, 0.07);
			if (st_board < 0.6) col = vec3(0.30, 0.20, 0.11);
			if (hash(cell + plank) > 0.985) col = vec3(0.70, 0.66, 0.58);
		} else if (top == st_cob - jag) {
			// Cobbles: rounded stones with dark grout, a touch grimy.
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
		} else {
			// Road: dressed slabs in staggered courses, kerbstones along the edges.
			vec2 p = t * vec2(3.0, 4.0);
			p.x += mod(floor(p.y), 2.0) * 0.5;
			vec2 f = fract(p);
			col = mix(vec3(0.62, 0.59, 0.52), vec3(0.74, 0.71, 0.63), hash(floor(p)));
			if (f.x < 0.06 || f.y < 0.08) col = vec3(0.36, 0.34, 0.30);
			if (st_road < 0.6) col = (fract(t.x * 5.0 + t.y * 5.0) < 0.12) ? vec3(0.30, 0.29, 0.26) : vec3(0.50, 0.48, 0.43);
		}
	} else if (top > 0.43) {
		col = mix(col, vec3(0.30, 0.26, 0.18), 0.45);   // worn verge
	}
	// The ground (everything that isn't water) takes the rolling light.
	float water = m.r + (n - 0.5) * 0.3;
	col *= light;
	if (water > 0.38) {
		col = ramp4(vec3(0.42, 0.36, 0.24), vec3(0.48, 0.41, 0.27), vec3(0.54, 0.47, 0.31), vec3(0.60, 0.53, 0.36), g) * light;   // sandy bank
	}
	if (water > 0.45) {
		col = mix(vec3(0.30, 0.25, 0.17), vec3(0.24, 0.20, 0.14), step(0.0, bay));                // wet edge
	}
	if (water > 0.5) {
		// Depth in five dithered bands, from sandy shallows to deep blue.
		float depth = smoothstep(0.5, 1.0, m.r + (n - 0.5) * 0.12);
		float dq = floor(clamp(depth + bay * 0.2, 0.0, 0.999) * 5.0);
		col = dq < 1.0 ? vec3(0.34, 0.52, 0.44) : dq < 2.0 ? vec3(0.22, 0.45, 0.48) : dq < 3.0 ? vec3(0.15, 0.36, 0.45)
			: dq < 4.0 ? vec3(0.11, 0.27, 0.39) : vec3(0.08, 0.19, 0.31);
		if (depth < 0.22 && hash(cell + 11.0) > 0.78) col = mix(col, vec3(0.56, 0.52, 0.36), 0.35);   // pebbles in the shallows
		// Wavelets: short broken dashes (screen space, iso-flat) that drift and flicker,
		// each with a darker trough just below it.
		float row = floor(world.y / 4.0);
		float seg = floor((world.x + TIME * 3.0 + row * 13.0) / 5.0);
		float life = sin(TIME * 1.6 + hash(vec2(seg, row)) * 6.283);
		bool dash = hash(vec2(seg, row + 0.5)) > 0.89 && life > 0.2;
		float fy = fract(world.y / 4.0);
		if (dash && fy < 0.25) col = mix(col, vec3(0.62, 0.80, 0.84), 0.55 * (1.0 - depth * 0.3));
		else if (dash && fy < 0.5) col *= 0.86;
		// Foam at the shore, breathing in and out.
		float foam = 0.53 + 0.015 * sin(TIME * 1.3 + n * 9.0);
		if (water < foam && hash(cell + floor(TIME * 2.0)) > 0.3) col = vec3(0.72, 0.86, 0.84);
		if (hash(cell + floor(TIME * 1.5)) > 0.995) col = vec3(0.9, 0.97, 0.95);   // a glint
	}
	// The map's edge fades into darkness, like unexplored ground.
	float edge = min(min(t.x, t.y), min(map_size.x - t.x, map_size.y - t.y));
	col *= mix(0.25, 1.0, floor(clamp(edge / 0.9 + bay * 0.25, 0.0, 1.0) * 4.0) / 4.0);
	COLOR = vec4(col, 1.0);
}
