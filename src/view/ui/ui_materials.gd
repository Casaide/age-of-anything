extends RefCounted
## The UI's materials, painted once in code: carved wood, hammered bronze, iron, marble, stone,
## parchment, felt, woven reed, leather, lacquer. Each is a seamless tile (so a panel of any size
## repeats it without a seam), painted at twice the UI's pixel size so it stays crisp on a Retina
## screen, in a material's own colours (data/ui.json and each culture's `ui` block pick the
## colour). Cosmetic only: the noise is seeded, so a material looks the same every run.

const TILE := 256      # texture pixels; drawn at half size, so a tile covers 128 UI pixels

static var _cache := {}


## The tile for a material in a colour (cached).
static func texture(material: String, colour: Color) -> Texture2D:
	var key := "%s:%s" % [material, colour.to_html()]
	if not _cache.has(key):
		var img: Image = _paint(material, colour)
		img.generate_mipmaps()
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


static func _paint(material: String, c: Color) -> Image:
	match material:
		"wood": return _wood(c)
		"bronze": return _bronze(c)
		"gold": return _gold(c)
		"iron": return _iron(c)
		"marble": return _marble(c)
		"stone": return _stone(c)
		"sandstone": return _sandstone(c)
		"parchment": return _parchment(c)
		"felt": return _felt(c)
		"leather": return _leather(c)
		"reed": return _reed(c)
		"lacquer": return _lacquer(c)
		"bone": return _bone(c)
	assert(false, "unknown UI material " + material)
	return null


## A seamless noise field, 0..1 per pixel, read with wrap-around.
static func _field(seed: int, freq: float, octaves := 3, kind := FastNoiseLite.TYPE_SIMPLEX_SMOOTH, w := TILE, h := TILE) -> PackedFloat32Array:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.noise_type = kind
	n.frequency = freq
	n.fractal_octaves = octaves
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	var img := n.get_seamless_image(w, h, false, false, 0.1, true)
	var out := PackedFloat32Array()
	out.resize(w * h)
	for y in h:
		for x in w:
			out[y * w + x] = img.get_pixel(x, y).r
	return out


## A squashed field read back at full width: linear between its columns, wrapping.
static func _at(f: PackedFloat32Array, w: int, fx: float, y: int) -> float:
	var i := int(fx)
	var t := fx - i
	return lerpf(f[y * w + i % w], f[y * w + (i + 1) % w], t)


static func _img() -> Image:
	return Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)


## Wood: long grain along x (the field is squashed 6:1), planks with dark seams, a few knots.
static func _wood(c: Color) -> Image:
	var img := _img()
	var grain := _field(11, 0.03, 4, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 48, TILE)
	var fine := _field(12, 0.25, 2)
	var plank := 64
	for y in TILE:
		for x in TILE:
			var g := _at(grain, 48, x * 48.0 / TILE, y)
			var rings := 0.5 + 0.5 * sin(g * 38.0)
			var v := 0.62 + 0.22 * rings + 0.16 * (fine[y * TILE + x] - 0.5)
			var py := y % plank
			if py < 2:
				v *= 0.42   # the seam between planks
			elif py == 2:
				v *= 1.18   # its lit lip
			var shade := 0.92 + 0.08 * sin(float(y / plank) * 2.1)   # each plank a touch different
			img.set_pixel(x, y, _tone(c, v * shade))
	return img


## Hammered metal: soft dimples from cellular noise, each lit from the top left, fine scratches.
static func _metal(c: Color, seed: int, rough: float) -> Image:
	var img := _img()
	var n := FastNoiseLite.new()
	n.seed = seed
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 0.045
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	var dimple := n.get_seamless_image(TILE, TILE, false, false, 0.1, true)
	var scratch := _field(seed + 1, 0.4, 1, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 16, TILE)
	var blot := _field(seed + 2, 0.012, 3)
	for y in TILE:
		for x in TILE:
			var d := dimple.get_pixel(x, y).r
			var dl := dimple.get_pixel((x + TILE - 2) % TILE, (y + TILE - 2) % TILE).r
			var light := (d - dl) * 3.0   # the slope towards the light
			var v := 0.78 + light * 0.5 + 0.12 * (blot[y * TILE + x] - 0.5) + rough * 0.25 * (_at(scratch, 16, x * 16.0 / TILE, y) - 0.5)
			img.set_pixel(x, y, _tone(c, v))
	return img


static func _bronze(c: Color) -> Image:
	return _metal(c, 21, 0.4)


static func _gold(c: Color) -> Image:
	return _metal(c, 23, 0.2)


## Iron: hammered and darker, with rust blooming in patches.
static func _iron(c: Color) -> Image:
	var img := _metal(c, 25, 0.9)
	var rust := _field(26, 0.02, 4)
	var rc := Color("#7a3e1c")
	for y in TILE:
		for x in TILE:
			var r := clampf((rust[y * TILE + x] - 0.6) * 2.5, 0.0, 0.35)
			if r > 0.0:
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(rc, r))
	return img


## Marble: pale, soft clouds, thin dark veins wandering on a warped sine.
static func _marble(c: Color) -> Image:
	var img := _img()
	var warp := _field(31, 0.008, 5)
	var cloud := _field(32, 0.02, 3)
	for y in TILE:
		for x in TILE:
			var w := warp[y * TILE + x]
			var vein := absf(sin((x + y) * TAU / TILE + w * 14.0))
			var v := 0.8 + 0.08 * (cloud[y * TILE + x] - 0.5) - 0.22 * pow(1.0 - vein, 10.0)
			img.set_pixel(x, y, _tone(c, v))
	return img


## Dressed stone: blocks in staggered courses, each a little different, speckled and pitted.
static func _stone(c: Color) -> Image:
	var img := _img()
	var mottle := _field(41, 0.02, 4)
	var grit := _field(42, 0.5, 1)
	var bw := 128
	var bh := 64
	for y in TILE:
		for x in TILE:
			var row := y / bh
			var bx := (x + (bw / 2 if row % 2 == 1 else 0)) % bw
			var by := y % bh
			var v := 0.78 + 0.18 * (mottle[y * TILE + x] - 0.5) + 0.12 * (grit[y * TILE + x] - 0.5)
			v *= 0.94 + 0.06 * sin(float(row * 3 + (x + (bw / 2 if row % 2 == 1 else 0)) / bw) * 1.7)
			if bx < 2 or by < 2:
				v *= 0.45   # the joint
			elif bx == 2 or by == 2:
				v *= 1.12
			img.set_pixel(x, y, _tone(c, v))
	return img


## Sandstone: stone's courses, softer and warmer, with fine layered bands.
static func _sandstone(c: Color) -> Image:
	var img := _stone(c)
	var bands := _field(43, 0.05, 2, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 16, TILE)
	for y in TILE:
		for x in TILE:
			var b := 0.96 + 0.08 * _at(bands, 16, x * 16.0 / TILE, y)
			var p := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(p.r * b, p.g * b, p.b * b))
	return img


## Parchment: warm, mottled, faint fibres, darker towards blotches.
static func _parchment(c: Color) -> Image:
	var img := _img()
	var mottle := _field(51, 0.015, 5)
	var fibre := _field(52, 0.3, 2, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, TILE, 32)
	for y in TILE:
		for x in TILE:
			var m := mottle[y * TILE + x]
			var v := 0.94 + 0.12 * (m - 0.5) - 0.18 * clampf((m - 0.68) * 3.0, 0.0, 1.0) + 0.05 * (fibre[(y * 32 / TILE) * TILE + x] - 0.5)
			img.set_pixel(x, y, _tone(c, v))
	return img


## Felt: dense, soft fuzz with gentle lumps.
static func _felt(c: Color) -> Image:
	var img := _img()
	var fuzz := _field(61, 0.6, 1)
	var lump := _field(62, 0.03, 3)
	for y in TILE:
		for x in TILE:
			var v := 0.84 + 0.1 * (fuzz[y * TILE + x] - 0.5) + 0.14 * (lump[y * TILE + x] - 0.5)
			img.set_pixel(x, y, _tone(c, v))
	return img


## Leather: fine pebbled grain, darker creases.
static func _leather(c: Color) -> Image:
	var img := _img()
	var n := FastNoiseLite.new()
	n.seed = 71
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 0.12
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var pebble := n.get_seamless_image(TILE, TILE, false, false, 0.1, true)
	var mottle := _field(72, 0.02, 3)
	for y in TILE:
		for x in TILE:
			var v := 0.8 + 0.12 * (mottle[y * TILE + x] - 0.5) - 0.16 * (1.0 - clampf(pebble.get_pixel(x, y).r * 4.0, 0.0, 1.0))
			img.set_pixel(x, y, _tone(c, v))
	return img


## Woven reed: upright stalks, each rounded by its own light, bound across every so often.
static func _reed(c: Color) -> Image:
	var img := _img()
	var streak := _field(81, 0.05, 2, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 32, TILE)
	var stalk := 16
	for y in TILE:
		for x in TILE:
			var sx := float(x % stalk) / stalk
			var round_ := sin(sx * PI)
			var k := x / stalk
			var v := 0.5 + 0.42 * round_ + 0.1 * (_at(streak, 32, x * 32.0 / TILE, y) - 0.5) + 0.04 * sin(k * 2.3)
			var by := (y + (k % 2) * 6) % 128
			if by < 10:   # a binding across the stalks
				v = 0.45 + 0.4 * sin(float(by) / 10.0 * PI)
			if (y + k * 37) % 96 == 0:
				v *= 0.6   # a node on the stalk
			img.set_pixel(x, y, _tone(c, v))
	return img


## Lacquer: deep, smooth, with a slow gloss and the faintest brush lines.
static func _lacquer(c: Color) -> Image:
	var img := _img()
	var gloss := _field(91, 0.01, 2)
	var brush := _field(92, 0.2, 1, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, TILE, 16)
	for y in TILE:
		for x in TILE:
			var v := 0.86 + 0.16 * (gloss[y * TILE + x] - 0.5) + 0.04 * (brush[(y * 16 / TILE) * TILE + x] - 0.5)
			img.set_pixel(x, y, _tone(c, v))
	return img


## Bone: pale, porous, with faint long fibres.
static func _bone(c: Color) -> Image:
	var img := _parchment(c)
	var pore := _field(95, 0.45, 1)
	for y in TILE:
		for x in TILE:
			if pore[y * TILE + x] > 0.78:
				var p := img.get_pixel(x, y)
				img.set_pixel(x, y, p.darkened(0.25))
	return img


## v around 0.8 is the colour itself; lower darkens towards a deep shade, higher lightens.
static func _tone(c: Color, v: float) -> Color:
	var k := v / 0.8
	if k <= 1.0:
		return Color(c.r * k, c.g * k, c.b * k)
	return c.lerp(Color(1, 0.97, 0.9), clampf((k - 1.0) * 0.9, 0.0, 1.0))
