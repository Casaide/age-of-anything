// Cliff faces for high ground (milestone 15): the drop down a raised cell's edge, painted in
// face space (along the edge, down from the rim) in the terrain's pixel-art manner: banded
// colour ramps, an ordered dither on art pixels, light from the upper left (faces turned to
// the screen's left catch it, faces turned right are in shade), a ragged grass lip over the
// rim and a dark foot where the face meets the ground below.
//
// Three looks for a meadow (concept round, D-080), picked by `style`:
//   0  earth bank: a grass lip over packed brown earth in strata, roots, pebbles
//   1  layered rock: courses of grey-brown stone blocks with dark joints, cracks, moss
//   2  mossy boulders: big rounded stones piled up, moss on their tops, earth between
shader_type canvas_item;

uniform int style = 1;
uniform float art_px = 1.0;     // screen pixels per art pixel
uniform float level_px = 20.0;  // screen height of one level (Iso.LEVEL_PX)

varying vec2 face;      // x: along the edge (tiles); y: the height at this point (levels)
varying float rim;      // the height of the rim above (levels)
varying float foot;     // the height of the ground below (levels)
varying float side;     // 0: faces down-right (+x), 1: faces down-left (+y)

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

vec3 ramp4(vec3 a, vec3 b, vec3 c, vec3 d, float v) {
	float q = floor(clamp(v, 0.0, 0.999) * 4.0);
	return q < 1.0 ? a : q < 2.0 ? b : q < 3.0 ? c : d;
}

void vertex() {
	face = UV;
	rim = COLOR.r * 3.0;
	side = COLOR.g;
	foot = COLOR.b * 3.0;
}

void fragment() {
	ivec2 ap = ivec2(FRAGCOORD.xy / art_px);
	float bay = BAYER[(ap.y % 4) * 4 + (ap.x % 4)] / 16.0 - 0.5;
	// Face space in canvas pixels, snapped to art-sized cells: x along the edge (an edge is
	// ~36 px on screen), y down from the rim; h the height above level 0 (for strata that
	// line up all round a hill).
	vec2 p = floor(vec2(face.x * 35.8 + side * 300.0, (rim - face.y) * level_px) / 1.5) * 1.5;
	float hpx = face.y * level_px;
	float depth = max((rim - foot) * level_px, 1.0);
	float k = clamp(p.y / depth, 0.0, 1.0);            // 0 at the rim, 1 at the foot
	float g = clamp(vnoise(p * 0.21) * 0.6 + vnoise(p * 0.6) * 0.4 + bay * 0.25, 0.0, 0.999);
	vec3 col;

	if (style == 0) {
		// Earth bank: packed earth in strata (by height, so they run round the hill), darker
		// and redder lower down, roots hanging from the turf, pebbles.
		float band = fract(hpx / 6.5 + vnoise(vec2(p.x * 0.05, hpx * 0.1)) * 0.6);
		col = ramp4(vec3(0.30, 0.22, 0.14), vec3(0.37, 0.27, 0.17), vec3(0.44, 0.33, 0.21), vec3(0.51, 0.39, 0.25), g);
		if (band < 0.22) col *= vec3(0.86, 0.84, 0.82);
		else if (band > 0.82) col = mix(col, vec3(0.55, 0.45, 0.30), 0.35);   // a sandy layer
		float root = vnoise(vec2(p.x * 0.9, p.y * 0.12));
		if (root > 0.82 && p.y < 9.0 + 6.0 * hash(vec2(floor(p.x / 3.0), 1.0))) col = vec3(0.20, 0.14, 0.09);
		float peb = hash(floor(p / 1.5));
		if (peb > 0.975) col = mix(vec3(0.50, 0.48, 0.42), vec3(0.62, 0.60, 0.52), hash(floor(p / 1.5) + 2.0));
	} else if (style == 1) {
		// Layered rock: sloping, uneven courses of weathered stone (by height, wobbling along the
		// face so they never read as a laid wall), broken into slabs of mixed length, a lit top
		// on each, deep shadow under the overhangs, cracks, lichen and moss.
		float hw = hpx + (vnoise(vec2(p.x * 0.045, 3.0)) - 0.5) * 7.0 + p.x * 0.06;
		float course = floor(hw / 6.5);
		float cy = fract(hw / 6.5);
		float off = hash(vec2(course, 7.0)) * 23.0;
		float bw = 11.0 + 14.0 * hash(vec2(course, 3.0));
		float bx = floor((p.x + off) / bw);
		float fx = fract((p.x + off) / bw);
		float tone = hash(vec2(bx, course));
		col = mix(vec3(0.33, 0.31, 0.27), vec3(0.50, 0.47, 0.40), tone);
		col *= mix(vec3(1.0), vec3(1.08, 1.0, 0.88), hash(vec2(bx + 5.0, course)));   // warmer and cooler stone
		col *= 0.86 + 0.26 * g;
		float lip_c = 0.72 + 0.12 * hash(vec2(bx, course + 1.0));
		if (cy > lip_c) col *= 1.16;                                  // the slab's top catches the light
		else if (cy < 0.2) col *= 0.62;                               // shadow under the slab above
		if (fx < 0.05 && hash(vec2(bx, course + 9.0)) > 0.35) col *= 0.55;   // a joint (some slabs run on)
		if (vnoise(vec2(p.x * 0.4, p.y * 0.07) + course) > 0.84 && fx > 0.45 && fx < 0.52) col *= 0.62;   // a crack
		if (vnoise(p * 0.12 + 40.0) > 0.68 && cy > 0.45 && hash(floor(p / 1.5)) > 0.3) col = mix(col, vec3(0.36, 0.45, 0.20), 0.6);   // moss and lichen on the ledges
	} else {
		// Mossy boulders: rounded stones piled up the face, shaded as balls lit from the upper
		// left, moss on their tops, dark earth in the gaps.
		vec2 q = p / vec2(9.0, 7.5);
		vec2 ip = floor(q);
		float d1 = 9.0;
		float d2 = 9.0;
		vec2 id = ip;
		vec2 offv = vec2(0.0);
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 o = ip + vec2(float(i), float(j));
				vec2 c = o + 0.5 + (vec2(hash(o), hash(o + 3.1)) - 0.5) * 0.7;
				float d = length(q - c);
				if (d < d1) { d2 = d1; d1 = d; id = o; offv = q - c; } else if (d < d2) { d2 = d; }
			}
		}
		float edge = d2 - d1;
		col = mix(vec3(0.38, 0.37, 0.33), vec3(0.54, 0.52, 0.46), hash(id + 9.0));
		float ball = dot(normalize(offv + vec2(1e-4)), normalize(vec2(-0.7, -0.7)));
		col *= ball > 0.3 ? 1.15 : (ball < -0.35 ? 0.72 : 0.95);
		if (offv.y < -0.12 && hash(id + 4.0) > 0.25 && vnoise(p * 0.4) > 0.35) col = mix(col, vec3(0.32, 0.45, 0.18), 0.75);   // moss on top
		if (edge < 0.12) col = vec3(0.19, 0.15, 0.10);   // earth between the stones
	}

	// The grass lip: turf hanging over the rim, ragged, with tufts poking down.
	float lip = 2.0 + 2.5 * vnoise(vec2(p.x * 0.3, 2.0)) + (hash(vec2(floor(p.x / 1.5), 5.0)) > 0.8 ? 2.0 : 0.0);
	if (p.y < lip) {
		col = ramp4(vec3(0.22, 0.34, 0.13), vec3(0.28, 0.41, 0.16), vec3(0.34, 0.48, 0.19), vec3(0.41, 0.54, 0.23), g);
		if (p.y < 1.5) col *= 1.15;                   // the rim's edge in the sun
	} else if (p.y < lip + 1.5) {
		col *= 0.55;                                  // the turf's shadow on the face
	}
	// Light: faces turned left catch the sun; deeper down a little darker; a dark foot line.
	col *= side > 0.5 ? 1.0 : 0.74;
	col *= mix(1.0, 0.8, floor(clamp(k + bay * 0.2, 0.0, 0.999) * 3.0) / 2.0);
	float scree = 2.0 + 3.0 * vnoise(vec2(p.x * 0.25, 9.0));
	if (depth - p.y < scree && hash(floor(p / 1.5) + 31.0) > 0.45) col = mix(col, vec3(0.30, 0.26, 0.19), 0.6);   // scree and soil at the foot
	if (depth - p.y < 1.6) col *= 0.55;
	COLOR = vec4(col, 1.0);
}
