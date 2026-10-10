extends RefCounted
## Procedural PBR materials for the high-fidelity pre-render: noise textures
## shaped into wood grain, reed thatch, mud daub, stone, grass and frog skin,
## each with a matching normal map. Built once and shared.

var cache := {}
var matte := false   # pixel-art bakes: no gloss, no clearcoat


func get_mat(name: String) -> StandardMaterial3D:
	if not cache.has(name):
		cache[name] = _make(name)
	return cache[name]


## A plain coloured material (eyes, cloth, team colour).
static func flat(c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _noise(kind: int, freq: float, seed_value: int, octaves := 4) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = kind
	n.frequency = freq
	n.seed = seed_value
	n.fractal_octaves = octaves
	return n


func _tex(noise: FastNoiseLite, ramp: Array, size := Vector2i(512, 512), normal := false, bump := 6.0) -> NoiseTexture2D:
	var t := NoiseTexture2D.new()
	t.width = size.x
	t.height = size.y
	t.seamless = true
	t.noise = noise
	if normal:
		t.as_normal_map = true
		t.bump_strength = bump
	else:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array(ramp.map(func(r): return r[0]))
		g.colors = PackedColorArray(ramp.map(func(r): return Color(r[1])))
		t.color_ramp = g
	return t


func _make(name: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var n: FastNoiseLite
	var ramp: Array
	var uv := Vector3.ONE
	match name:
		"wood":   # long grain: noise stretched along the board
			n = _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, 3)
			ramp = [[0.0, "#4a2f1c"], [0.45, "#6e4a2c"], [0.7, "#8a6038"], [1.0, "#a67a48"]]
			uv = Vector3(1, 6, 1)
			m.roughness = 0.8
		"thatch":
			n = _noise(FastNoiseLite.TYPE_SIMPLEX, 0.05, 7)
			ramp = [[0.0, "#6b5326"], [0.4, "#a8883e"], [0.75, "#c9a652"], [1.0, "#e0c070"]]
			uv = Vector3(10, 1.5, 1)
			m.roughness = 0.95
		"mud":
			n = _noise(FastNoiseLite.TYPE_SIMPLEX, 0.03, 11, 5)
			ramp = [[0.0, "#6a5236"], [0.5, "#8c7048"], [1.0, "#b0915e"]]
			m.roughness = 0.95
		"stone":
			n = _noise(FastNoiseLite.TYPE_CELLULAR, 0.03, 5)
			n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
			ramp = [[0.0, "#5c5a52"], [0.5, "#86827a"], [0.8, "#a29e94"], [1.0, "#c0bcb0"]]
			uv = Vector3(2, 2, 1)
			m.roughness = 0.85
		"grass":
			n = _noise(FastNoiseLite.TYPE_SIMPLEX, 0.04, 13, 5)
			ramp = [[0.0, "#36521e"], [0.5, "#4c6e28"], [0.8, "#628634"], [1.0, "#7a9840"]]
			m.roughness = 0.95
		"swamp":
			n = _noise(FastNoiseLite.TYPE_SIMPLEX, 0.012, 17, 3)
			ramp = [[0.0, "#1e3430"], [0.5, "#2a4438"], [0.8, "#3a5440"], [1.0, "#4a6044"]]
			m.roughness = 0.2
			m.metallic_specular = 0.7
		"frog":   # skin with darker blotches
			n = _noise(FastNoiseLite.TYPE_CELLULAR, 0.05, 19)
			n.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
			ramp = [[0.0, "#4f8a3a"], [0.55, "#5e9c44"], [0.56, "#3f6e30"], [0.7, "#3f6e30"], [0.71, "#64a64a"], [1.0, "#6cb052"]]
			m.roughness = 0.35
			m.clearcoat_enabled = true
			m.clearcoat = 0.5
		"tin":    # corrugated sheet: tight ridges, a little rust
			n = _noise(FastNoiseLite.TYPE_SIMPLEX, 0.03, 29, 2)
			ramp = [[0.0, "#7a5a40"], [0.2, "#8a8a84"], [0.6, "#a8aaa4"], [1.0, "#c4c6c0"]]
			uv = Vector3(14, 1, 1)
			m.roughness = 0.6
		"brick":
			n = _noise(FastNoiseLite.TYPE_CELLULAR, 0.06, 31)
			n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
			ramp = [[0.0, "#3a2a22"], [0.4, "#6a3e2e"], [0.8, "#80503a"], [1.0, "#94604a"]]
			uv = Vector3(3, 1.5, 1)
			m.roughness = 0.95
		"weave":  # basket
			n = _noise(FastNoiseLite.TYPE_CELLULAR, 0.08, 23, 1)
			ramp = [[0.0, "#6e5226"], [0.5, "#a6844a"], [1.0, "#c8a462"]]
			uv = Vector3(3, 1, 1)
			m.roughness = 0.9
		_:
			assert(false, "Unknown material %s" % name)
	m.albedo_texture = _tex(n, ramp)
	m.normal_enabled = true
	var bump := 8.0
	match name:
		"frog":
			bump = 4.0
		"swamp":
			bump = 1.0
		"grass":
			bump = 4.0
	m.normal_texture = _tex(n, ramp, Vector2i(512, 512), true, bump)
	m.uv1_scale = uv
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if matte:
		m.roughness = 1.0
		m.metallic_specular = 0.2
		m.clearcoat_enabled = false
	return m
