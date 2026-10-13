extends RefCounted
## The bake cache on disk (user://bake_cache): every bake ArtKit makes (a unit part in its
## eight facings, a building with its stages, the prop set) saved as raw pixels, so a race or
## culture seen before loads in milliseconds instead of rendering again.
##
## Entries live under a version folder: a hash of the files the look comes from (the bake code,
## the models, their textures, the art data). Change any of them and a new folder starts, so
## the cache never shows stale art; old folders beyond the last few used are dropped. View side only.

## Bump to throw every cache away by hand (e.g. after an engine upgrade that renders differently).
const FORMAT := 1
const ROOT := "user://bake_cache"
const KEEP := 12      # versions kept on disk (a few MB each; several checkouts and worktrees share user://, so few would evict each other)
## What the baked look comes from. Folders are hashed file by file (sorted).
const SOURCES := ["res://src/view/art/art_kit.gd", "res://src/view/art/bake/", "res://scenes/art_pixel/part_baker.gd",
	"res://scenes/art_pixel/pixelize.gd", "res://scenes/art_pixel/prop_models.gd", "res://scenes/art_pixel/unit_models.gd", "res://scenes/art_pixel/siege_models.gd", "res://scenes/art_pixel/tree_models.gd", "res://scenes/art_pixel/bridge_models.gd", "res://scenes/art_pixel/town_props.gd",
	"res://scenes/art_pixel/creature_kit.gd", "res://scenes/art_pixel/bear_concepts.gd", "res://scenes/art_pixel/cart_concepts.gd", "res://scenes/art_pixel/m13_concepts.gd", "res://scenes/art_pixel/hero_concepts.gd", "res://data/creature_kit.json", "res://data/later/",
	"res://src/part_shape.gd", "res://data/parts.json", "res://data/buildings.json",
	"res://data/animals.json", "res://data/palettes.json", "res://data/families.json", "res://data/creatures.json",
	"res://assets/models/", "res://assets/art/textures/"]

static var enabled := true    # tests switch it off to time a cold bake
static var cold_parts := false   # tests: unit parts never load (they render, as for a race never seen); the rest still does
static var _version := ""
static var _mods := []        # the mods in use when _version was made (their files are in it too)
const Mods := preload("res://src/mods.gd")


## The version folder for this build of the look (computed once, old folders dropped).
static func folder() -> String:
	if _version == "" or _mods != Mods.signature():
		_mods = Mods.signature()
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_MD5)
		ctx.update(("%d|%s" % [FORMAT, Engine.get_version_info().string]).to_utf8_buffer())
		for src in SOURCES:
			for path in _files(src):
				ctx.update((path + FileAccess.get_md5(path)).to_utf8_buffer())
		for path in Mods.files():   # a mod's models, textures and data (src/mods.gd)
			ctx.update((path + FileAccess.get_md5(path)).to_utf8_buffer())
		_version = ctx.finish().hex_encode().substr(0, 16)
		DirAccess.make_dir_recursive_absolute(ROOT + "/" + _version)
		var stamp := FileAccess.open(ROOT + "/" + _version + "/used", FileAccess.WRITE)   # when this version was last used
		stamp.store_string(str(Time.get_unix_time_from_system()))
		stamp.close()
		# Keep the few most recently used versions (other checkouts of the game share user://), drop the rest.
		var dirs := Array(DirAccess.get_directories_at(ROOT))
		dirs.sort_custom(func(a, b): return FileAccess.get_modified_time("%s/%s/used" % [ROOT, a]) > FileAccess.get_modified_time("%s/%s/used" % [ROOT, b]))
		for old in dirs.slice(KEEP):
			_remove(ROOT + "/" + old)
	return ROOT + "/" + _version


static func _files(src: String) -> Array:
	if not src.ends_with("/"):
		return [src]
	var out := []
	for f in DirAccess.get_files_at(src):
		if not f.ends_with(".import") and not f.ends_with(".uid"):
			out.append(src + f)
	out.sort()
	return out


static func _remove(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		_remove(dir + "/" + d)
	DirAccess.remove_absolute(dir)


## Where an entry with this key lives.
static func path(key: String) -> String:
	return "%s/%s.bin" % [folder(), key.md5_text()]


static func has(key: String) -> bool:
	return enabled and not (cold_parts and key.begins_with("part|")) and FileAccess.file_exists(path(key))


static func read(key: String) -> Dictionary:
	var f := FileAccess.open_compressed(path(key), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	var d = f.get_var()
	assert(d is Dictionary, "bake cache: unreadable entry for " + key)
	return d


static func write(key: String, entry: Dictionary) -> void:
	if not enabled:
		return
	var tmp := path(key) + ".tmp"   # written whole, then moved: a crash never leaves half an entry
	var f := FileAccess.open_compressed(tmp, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	f.store_var(entry)
	f.close()
	DirAccess.rename_absolute(tmp, path(key))


## Images go in as raw pixels (no PNG encode or decode: loading is a copy).
static func pack(img: Image) -> Dictionary:
	return {"w": img.get_width(), "h": img.get_height(), "f": img.get_format(), "d": img.get_data()}


static func unpack(d: Dictionary) -> Image:
	return Image.create_from_data(d.w, d.h, false, d.f, d.d)
