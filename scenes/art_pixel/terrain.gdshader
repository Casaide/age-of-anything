// Continuous pixel-art ground for a tile map: no grid. Terrain comes from blurred
// masks (R water, G swamp, B reed-bed ground, A rock) perturbed by noise, so borders are
// round and organic. Water gets a mud bank, a wet edge, a painted depth fall, sky and ripples.
shader_type canvas_item;

uniform sampler2D masks : filter_linear, repeat_disable;
uniform sampler2D paths : filter_linear, repeat_disable;   // R trail, G boardwalk, B cobble, A road
uniform sampler2D path_arc : filter_linear, repeat_disable;   // R: distance along the nearest path (tiles)
uniform sampler2D wear : filter_linear, repeat_disable, hint_default_black;   // R: how worn the ground is by walkers, per tile (trails.gd)
uniform vec2 map_size;          // tiles
uniform float art_px = 1.0;     // screen pixels per art pixel (the dither works on art pixels)
varying vec2 world;             // canvas units at scale 1 (64 x 32 per tile), on the ground's base plane
varying float shade;            // high ground: slopes facing away from the light darker, plateaus a touch lighter

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

// Irregular stones: the nearest jittered cell to p. Returns (edge distance d2 - d1,
// the cell's hash, 0) and gives the cell id and p's offset from the stone's centre.
vec3 stones(vec2 p, float jitter, out vec2 id, out vec2 off) {
	vec2 ip = floor(p);
	float d1 = 9.0;
	float d2 = 9.0;
	id = ip;
	off = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 o = ip + vec2(float(i), float(j));
			vec2 q = o + 0.5 + (vec2(hash(o), hash(o + 3.1)) - 0.5) * jitter;
			float d = length(p - q);
			if (d < d1) { d2 = d1; d1 = d; id = o; off = p - q; } else if (d < d2) { d2 = d; }
		}
	}
	return vec3(d2 - d1, hash(id + 9.0), 0.0);
}

// A stone's face lit from the upper left like everything else: a bright rim on the
// side towards the light, a shaded rim away from it (a bevel, in two bands).
vec3 bevel(vec3 col, vec2 off, float edge, float width) {
	float rim = 1.0 - smoothstep(0.0, width, edge);
	float facing = dot(normalize(off + vec2(1e-4)), normalize(vec2(-0.6, -0.8)));
	if (rim > 0.35) {
		col *= facing > 0.2 ? 1.16 : (facing < -0.2 ? 0.74 : 1.0);
	}
	return col;
}

vec3 ramp4(vec3 a, vec3 b, vec3 c, vec3 d, float v) {
	float q = floor(clamp(v, 0.0, 0.999) * 4.0);
	return q < 1.0 ? a : q < 2.0 ? b : q < 3.0 ? c : d;
}

// High ground (milestone 15): raised ground is drawn by meshes whose UV.x is how far the
// vertex was lifted on screen, so `world` is the point on the base plane this ground belongs
// to; UV.y is a shade. The flat ground has UV 0.
void vertex() {
	world = VERTEX + vec2(0.0, UV.x);
	shade = 1.0 + UV.y;
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
	ivec2 ap = ivec2(FRAGCOORD.xy / art_px);
	float bay = BAYER[(ap.y % 4) * 4 + (ap.x % 4)] / 16.0 - 0.5;

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
	// Natural variation: broad drifts of warmer and cooler green, darker clumps of
	// thicker grass with lit tips, and worn patches where soil shows through.
	float drift = vnoise(t * 0.17 + 61.0);
	col *= mix(vec3(1.06, 1.02, 0.84), vec3(0.9, 1.0, 1.06), drift);
	float clump = vnoise(t * 4.3 + 7.0) * 0.7 + vnoise(t * 11.0) * 0.3;
	if (clump > 0.66) col *= (hash(cell + 31.0) > 0.7 ? 1.12 : 0.8);
	float worn = vnoise(t * 0.7 + 33.0) * 0.8 + vnoise(t * 5.0 + 3.0) * 0.2;
	if (worn > 0.7 && hash(cell + 41.0) > 0.45) col = mix(col, vec3(0.42, 0.34, 0.22), 0.55 + 0.2 * hash(cell + 43.0));

	// Reed beds: damp ground, a little darker and more olive, fading out with no edge.
	float reed = clamp(m.b * 1.3 + (n - 0.5) * 0.5, 0.0, 1.0);
	col = mix(col, col * vec3(0.8, 0.86, 0.72), floor(reed * 3.0) / 3.0 * 0.8);
	float swamp = m.g + (n - 0.5) * 0.4;
	if (swamp > 0.5) {
		// Boggy ground: dark peaty mud and olive moss, sedge tufts, algae scum, and
		// standing puddles that catch the sky on their far edge.
		float bog = vnoise(t * 1.6 + 5.0) * 0.6 + vnoise(t * 4.5 + 9.0) * 0.4;
		col = ramp4(vec3(0.20, 0.24, 0.13), vec3(0.25, 0.30, 0.15), vec3(0.30, 0.35, 0.17), vec3(0.36, 0.40, 0.19), grain);
		if (bog < 0.36) col = ramp4(vec3(0.26, 0.21, 0.14), vec3(0.31, 0.25, 0.16), vec3(0.36, 0.29, 0.19), vec3(0.41, 0.34, 0.22), grain);   // mud, warm and light (dark read as oil)
		// A few broad pools, not many small ones (Fable: they read as oil puddles).
		float pool = vnoise(t * 0.55 + 13.0) * 0.75 + vnoise(t * 2.0 + 3.0) * 0.2 + (vnoise(t * 9.0) - 0.5) * 0.05;
		if (pool > 0.6) {
			col = mix(vec3(0.20, 0.31, 0.28), vec3(0.26, 0.38, 0.35), floor(clamp(grain + bay * 0.3, 0.0, 0.999) * 3.0) / 2.0);   // greenish standing water, like the pond's
			if (pool < 0.615) col = vec3(0.30, 0.25, 0.16);                     // its muddy lip
			else if (vnoise(t * 2.0 + vec2(0.0, 0.6)) - vnoise(t * 2.0) > 0.06) col = mix(col, vec3(0.42, 0.55, 0.56), 0.45);   // sky in it
			if (hash(cell + 17.0) > 0.97) col = vec3(0.45, 0.58, 0.2);          // duckweed
		} else {
			if (hash(cell + 7.0) > 0.93 && fract(t.y * 22.0) < 0.6) col = (hash(cell + 8.0) > 0.5) ? vec3(0.42, 0.50, 0.20) : vec3(0.14, 0.20, 0.10);   // sedge
			if (vnoise(t * 6.0 + 77.0) > 0.74) col = mix(col, vec3(0.44, 0.52, 0.18), 0.5);   // algae scum
		}
	} else if (swamp > 0.44) {
		col = mix(col, vec3(0.20, 0.27, 0.16), 0.6);
	}

	// Rock: stony, rubbly ground under the outcrops, with a scree edge.
	float rock = m.a + (n - 0.5) * 0.35;
	if (rock > 0.5) {
		col = ramp4(vec3(0.27, 0.25, 0.21), vec3(0.33, 0.31, 0.26), vec3(0.40, 0.37, 0.31), vec3(0.46, 0.43, 0.36), grain);
		if (hash(cell + 13.0) > 0.88) col *= 0.72;
	} else if (rock > 0.42) {
		col = mix(col, vec3(0.32, 0.29, 0.22), 0.5);
	}

	vec4 pth = texture(paths, t / map_size);
	// Worn trails: where units walk often the grass wears to earth (a trail once worn through).
	// The wear is per tile: soften it over a tile and a half (a ring of taps, wobbled by noise),
	// so a trail is a winding band, not a row of squares.
	vec2 wob = vec2(vnoise(t * 1.3 + 11.0), vnoise(t * 1.3 + 29.0)) - 0.5;
	float trod = 0.0;
	for (int k = 0; k < 8; k++) {
		float a = float(k) * 0.785398;
		trod += texture(wear, (t + wob * 0.8 + vec2(cos(a), sin(a)) * 0.75) / map_size).r;
	}
	trod = (trod / 8.0) * 0.6 + texture(wear, (t + wob * 0.5) / map_size).r * 0.4;
	pth.r = max(pth.r, smoothstep(0.12, 0.5, trod) * 0.7);
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
			float across = pth.r;   // high in the middle of the trail, falling off to its edges
			if (abs(across - 0.8) < 0.04) col *= 0.78;                                 // two worn ruts
			else if (across > 0.9 && vnoise(t * 7.0) > 0.55) col = mix(col, vec3(0.30, 0.40, 0.17), 0.7);   // grass down the middle
			if (hash(cell + 3.0) > 0.95) col = vec3(0.62, 0.58, 0.50);
			else if (hash(cell + 5.0) < 0.04) col = vec3(0.30, 0.24, 0.15);
		} else if (top == st_board + jag) {
			// Boardwalk: planks laid across the walk, dark gaps, nail heads; beams at the edges.
			float u = texture(path_arc, t / map_size).r * 3.4;
			float plank = floor(u);
			col = mix(vec3(0.42, 0.29, 0.16), vec3(0.56, 0.40, 0.23), hash(vec2(plank, 7.0)));
			col *= 0.88 + 0.24 * vnoise(vec2(plank * 5.0, (t.x - t.y) * 9.0));      // grain along the plank
			if (hash(vec2(plank, 3.0)) > 0.86) col = mix(col, vec3(0.46, 0.44, 0.38), 0.45);   // a weathered grey board
			if (fract(u) < 0.13) col = vec3(0.20, 0.13, 0.07);
			if (st_board < 0.6) {
				col = vec3(0.30, 0.20, 0.11);                                         // the edge beam
				if (mod(plank, 5.0) < 1.0) col = (fract(u) < 0.5) ? vec3(0.44, 0.31, 0.18) : vec3(0.17, 0.11, 0.06);   // a post top
			}
			if (hash(cell + plank) > 0.985) col = vec3(0.70, 0.66, 0.58);
		} else if (top == st_cob - jag) {
			// Cobbles: rounded stones with dark grout, a touch grimy.
			vec2 id;
			vec2 off;
			vec3 v = stones(t * 7.0, 0.85, id, off);
			col = mix(vec3(0.38, 0.37, 0.32), vec3(0.58, 0.55, 0.48), v.y);
			col *= mix(vec3(1.0), vec3(1.06, 0.98, 0.9), hash(id + 2.0));          // warmer and cooler stones
			col = bevel(col, off, v.x, 0.3);
			if (v.x < 0.15) col = (hash(cell + 19.0) > 0.8) ? vec3(0.24, 0.30, 0.14) : vec3(0.25, 0.20, 0.14);   // dirt and moss in the joints
			if (st_cob < 0.58 && v.y > 0.6) col = mix(col, vec3(0.32, 0.27, 0.18), 0.7);   // stones lost from the worn edge
		} else {
			// Road: dressed slabs in staggered courses, kerbstones along the edges.
			// Big dressed slabs, irregular and worn: no two the same size or shade, each
			// bevelled to the light, dirt in the joints, stains, and broken edges.
			vec2 id;
			vec2 off;
			vec3 v = stones(t * vec2(3.2, 3.6), 0.55, id, off);
			col = mix(vec3(0.58, 0.55, 0.48), vec3(0.74, 0.71, 0.62), v.y);
			col *= 0.92 + 0.12 * vnoise(t * 14.0 + id);                               // weathering on the face
			if (vnoise(t * 2.2 + id * 3.0) > 0.72) col *= vec3(0.86, 0.84, 0.76);      // a stain
			col = bevel(col, off, v.x, 0.22);
			if (v.x < 0.07) col = vec3(0.30, 0.26, 0.19);                              // dirt joint
			if (st_road < 0.62 && hash(id + 5.0) > 0.55) col = mix(vec3(0.34, 0.30, 0.21), col, 0.25);   // a slab missing at the edge
			else if (st_road < 0.56) col = vec3(0.46, 0.44, 0.39);                     // the kerb
		}
	} else if (top > 0.43) {
		col = mix(col, vec3(0.30, 0.26, 0.18), 0.45);   // worn verge
		if (top == st_board + jag) col = mix(col, vec3(0.10, 0.08, 0.05), 0.45);   // the boardwalk's shadow on the ground
		else if (hash(cell + 51.0) > 0.7) col = mix(col, vec3(0.30, 0.42, 0.18), 0.6);   // grass creeping in
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
		// Painted water (Dominic: the old banded blue with white dots read cartoony): a smooth
		// fall from olive shallows to deep green-blue, broad soft patches of colour, the sky
		// caught in long slow streaks, and fine ripple glints rather than dashes.
		float depth = smoothstep(0.5, 1.0, m.r + (n - 0.5) * 0.12);
		float dd = clamp(depth + bay * 0.05, 0.0, 1.0);
		vec3 shallow = vec3(0.33, 0.45, 0.36);
		vec3 mid = vec3(0.17, 0.34, 0.37);
		vec3 deep = vec3(0.09, 0.21, 0.28);
		col = dd < 0.45 ? mix(shallow, mid, dd / 0.45) : mix(mid, deep, (dd - 0.45) / 0.55);
		col *= 0.94 + 0.12 * vnoise(t * 0.9 + 12.0);                                   // broad soft patches
		if (depth < 0.22) col = mix(col, vec3(0.46, 0.43, 0.30), (0.22 - depth) * 1.6 * vnoise(t * 5.0 + 4.0));   // sandy bed showing in the shallows
		vec2 sp = vec2(world.x * 0.018, world.y * 0.16);                                // screen-flat, stretched sideways
		float sky = vnoise(sp + vec2(TIME * 0.03, 0.0)) * 0.6 + vnoise(sp * 2.3 + vec2(-TIME * 0.05, 3.0)) * 0.4;
		col = mix(col, vec3(0.50, 0.64, 0.66), smoothstep(0.58, 0.82, sky) * 0.35 * (0.4 + depth * 0.6));   // the sky in it
		float rip = vnoise(vec2(world.x * 0.09 + TIME * 0.4, world.y * 0.6 + TIME * 0.15));
		float rip2 = vnoise(vec2(world.x * 0.07 - TIME * 0.3, world.y * 0.55 + 5.0));
		if (rip > 0.8 && rip2 > 0.55) col = mix(col, vec3(0.70, 0.82, 0.82), 0.35);   // a ripple catching the light
		else if (rip > 0.74 && rip2 > 0.55) col *= 0.92;                               // its shadow side
		// Under the bank the water is darker; foam laps at the edge, breathing slowly.
		col *= mix(0.86, 1.0, smoothstep(0.5, 0.6, water));
		float foam = 0.53 + 0.012 * sin(TIME * 1.1 + n * 9.0);
		if (water < foam) col = mix(col, vec3(0.70, 0.80, 0.76), 0.6 * step(0.35, vnoise(t * 14.0 + TIME * 0.3)));
	}
	col *= shade;
	// The map's edge fades into darkness, like unexplored ground.
	float edge = min(min(t.x, t.y), min(map_size.x - t.x, map_size.y - t.y));
	col *= mix(0.25, 1.0, floor(clamp(edge / 0.9 + bay * 0.25, 0.0, 1.0) * 4.0) / 4.0);
	COLOR = vec4(col, 1.0);
}
