extends RefCounted
## Turns a supersampled render into a pixel-art sprite: shrink by `factor`, hard
## alpha (soft dark ground shadows become one flat translucent shadow colour),
## and a selective inner outline: edge pixels take a darker shade of themselves
## (units and buildings; realistic props go without). Works on raw bytes: it runs
## for every bake at match start.

const SHADOW := Color(0.06, 0.05, 0.03, 0.42)
const CONTACT := Color(0.06, 0.05, 0.03, 0.24)   # ambient occlusion where things meet the ground
const EDGE_INK := Color("#24180f")


static func run(img: Image, factor: int, outline := true) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	img.fix_alpha_edges()
	var w := maxi(1, img.get_width() / factor)
	var h := maxi(1, img.get_height() / factor)
	img.resize(w, h, Image.INTERPOLATE_CUBIC)
	var src := img.get_data()
	var out := PackedByteArray()
	out.resize(w * h * 4)
	var shadow := [SHADOW.r8, SHADOW.g8, SHADOW.b8, SHADOW.a8]
	var contact := [CONTACT.r8, CONTACT.g8, CONTACT.b8, CONTACT.a8]
	for i in range(0, w * h * 4, 4):
		var a := src[i + 3]
		if a >= 153:   # 0.6
			out[i] = src[i]
			out[i + 1] = src[i + 1]
			out[i + 2] = src[i + 2]
			out[i + 3] = 255
			continue
		var lum := (src[i] * 0.2126 + src[i + 1] * 0.7152 + src[i + 2] * 0.0722) / 255.0
		var c: Array = []
		if a >= 84 and lum < 0.12:      # 0.33
			c = shadow
		elif a >= 13 and lum < 0.12:    # 0.05
			c = contact
		else:
			continue
		out[i] = c[0]
		out[i + 1] = c[1]
		out[i + 2] = c[2]
		out[i + 3] = c[3]
	if outline:
		var edged := out.duplicate()
		var ink := EDGE_INK
		for y in h:
			for x in w:
				var i := (y * w + x) * 4
				if out[i + 3] != 255:
					continue
				var edge := x == 0 or y == 0 or x == w - 1 or y == h - 1 \
					or out[i - 1] != 255 or out[i + 7] != 255 or out[i - w * 4 + 3] != 255 or out[i + w * 4 + 3] != 255
				if edge:
					var c := Color8(out[i], out[i + 1], out[i + 2]).darkened(0.55).lerp(ink, 0.25)
					edged[i] = c.r8
					edged[i + 1] = c.g8
					edged[i + 2] = c.b8
		out = edged
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)
