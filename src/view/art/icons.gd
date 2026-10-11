extends RefCounted
## Command icons drawn as SVG (assets/art/icons/): the age-up and each research, by name
## (a research's `icon` in data/tech.json, else its id). An unknown name gets the generic
## research scroll. Rasterised once at twice their size, so they stay crisp on the buttons.

const DIR := "res://assets/art/icons/"
const FALLBACK := "research"

static var _cache := {}


static func texture(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := DIR + name + ".svg"
	if not FileAccess.file_exists(path):
		return texture(FALLBACK) if name != FALLBACK else null
	var img := Image.new()
	img.load_svg_from_string(FileAccess.get_file_as_string(path), 2.0)
	var tex := ImageTexture.create_from_image(img)
	_cache[name] = tex
	return tex
