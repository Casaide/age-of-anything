extends RefCounted
## Turns a supersampled render into a pixel-art sprite: shrink by `factor`, hard
## alpha (soft dark ground shadows become one flat translucent shadow colour),
## and a selective inner outline: edge pixels take a darker shade of themselves.

const SHADOW := Color(0.06, 0.05, 0.03, 0.42)


static func run(img: Image, factor: int) -> Image:
	img.fix_alpha_edges()
	var w := maxi(1, img.get_width() / factor)
	var h := maxi(1, img.get_height() / factor)
	img.resize(w, h, Image.INTERPOLATE_CUBIC)
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a >= 0.6:
				out.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
			elif c.a >= 0.05 and c.get_luminance() < 0.12:
				out.set_pixel(x, y, SHADOW)
			else:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
	var edged := out.duplicate()
	for y in h:
		for x in w:
			var c := out.get_pixel(x, y)
			if c.a < 1.0:
				continue
			var edge := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or out.get_pixelv(q).a < 1.0:
					edge = true
					break
			if edge:
				edged.set_pixel(x, y, c.darkened(0.55).lerp(Color("#24180f"), 0.25))
	return edged
