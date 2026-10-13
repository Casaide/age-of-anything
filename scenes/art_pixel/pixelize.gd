extends RefCounted
## Turns a supersampled render into a pixel-art sprite: shrink by `factor`, hard
## alpha (soft dark ground shadows become one flat translucent shadow colour),
## and a selective inner outline: edge pixels take a darker shade of themselves
## (units and buildings; realistic props go without). Works on raw bytes: it runs
## for every bake at match start.

const SHADOW := Color(0.06, 0.05, 0.03, 0.42)
const CONTACT := Color(0.06, 0.05, 0.03, 0.24)   # ambient occlusion where things meet the ground
const EDGE_INK := Color("#24180f")


## bands > 0: the paint-over look for units: each opaque pixel's brightness snaps to one of
## `bands` steps (hue and saturation kept), so shading reads as painted bands, not a gradient.
## seam: where another part of the same unit lies against this one (white; the same size as img):
## no outline along it, so a head cut by its neck joins it without a line (the bear mount, B3).
static func run(img: Image, factor: int, outline := true, bands := 0, seam: Image = null) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	img.premultiply_alpha()   # shrink with premultiplied alpha, so edges don't darken (and it's cheap)
	var w := maxi(1, img.get_width() / factor)
	var h := maxi(1, img.get_height() / factor)
	img.resize(w, h, Image.INTERPOLATE_CUBIC)
	var src := img.get_data()
	var out := PackedByteArray()
	out.resize(w * h * 4)
	var shadow := [SHADOW.r8, SHADOW.g8, SHADOW.b8, SHADOW.a8]
	var contact := [CONTACT.r8, CONTACT.g8, CONTACT.b8, CONTACT.a8]
	var joined := PackedByteArray()
	if seam != null:
		var sm := seam.duplicate()
		sm.convert(Image.FORMAT_L8)
		sm.resize(w, h, Image.INTERPOLATE_BILINEAR)
		joined = sm.get_data()
	for i in range(0, w * h * 4, 4):
		var a := src[i + 3]
		if a >= 153 or (a >= 8 and not joined.is_empty() and joined[i / 4] >= 64):   # 0.6 (along a seam, any cover: no gap between the parts)
			out[i] = mini(255, src[i] * 255 / a)
			out[i + 1] = mini(255, src[i + 1] * 255 / a)
			out[i + 2] = mini(255, src[i + 2] * 255 / a)
			out[i + 3] = 255
			continue
		if a == 0:
			continue
		var lum := (src[i] * 0.2126 + src[i + 1] * 0.7152 + src[i + 2] * 0.0722) / float(a)
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
	if bands > 0:
		for i in range(0, w * h * 4, 4):
			if out[i + 3] != 255:
				continue
			var c := Color8(out[i], out[i + 1], out[i + 2])
			var v := clampf(roundf(c.v * bands) / bands, 0.08, 1.0)
			var q := Color.from_hsv(c.h, c.s, v)
			out[i] = q.r8
			out[i + 1] = q.g8
			out[i + 2] = q.b8
	if not joined.is_empty():
		# Grow a pixel into the seam (the two parts' bakes sit on slightly different pixel grids, so
		# without it the ground shows through a line between them).
		var grown := out.duplicate()
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var p := y * w + x
				if out[p * 4 + 3] == 255 or joined[p] < 64:
					continue
				for q in [p - 1, p + 1, p - w, p + w]:
					if out[q * 4 + 3] == 255:
						for c in 4:
							grown[p * 4 + c] = out[q * 4 + c]
						break
		out = grown
	if outline:
		var edged := out.duplicate()
		var ink := EDGE_INK
		for y in h:
			for x in w:
				var i := (y * w + x) * 4
				if out[i + 3] != 255:
					continue
				var edge := x == 0 or y == 0 or x == w - 1 or y == h - 1
				if joined.is_empty():
					edge = edge or out[i - 1] != 255 or out[i + 7] != 255 or out[i - w * 4 + 3] != 255 or out[i + w * 4 + 3] != 255
				elif not edge:
					var p := y * w + x
					for q in [p - 1, p + 1, p - w, p + w]:
						if out[q * 4 + 3] != 255 and joined[q] < 128:
							edge = true
							break
				if edge:
					var c := Color8(out[i], out[i + 1], out[i + 2]).darkened(0.55).lerp(ink, 0.25)
					edged[i] = c.r8
					edged[i + 1] = c.g8
					edged[i + 2] = c.b8
		out = edged
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)
