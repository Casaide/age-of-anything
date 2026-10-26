extends SceneTree
## Where each building look's chimney smoke, lantern and lit windows are (ArtKit._bake_building's
## info.smoke / lantern / lights), for the Lobster game: every look in a pack's index.txt is placed
## (its 3D model, not baked) and the points projected as the bake camera sees them (Baker: an
## orthographic camera turned 45 degrees and tipped 30 down, PX_PER_UNIT canvas px a world unit).
## Writes <pack>/fx.txt: "bfx <look> <smoke x y | - -> <lantern x y | - -> <lights x y ...>" in canvas
## units from the look's anchor.
##   godot --headless --path . --script res://tests/lobster_spike/building_fx.gd -- tests/lobster_spike/library

const ArtKit := preload("res://src/view/art/art_kit.gd")
const Models := preload("res://src/view/art/bake/models.gd")
const Baker := preload("res://src/view/art/bake/baker.gd")
const DataLib := preload("res://src/data_lib.gd")


func _project(p: Vector3) -> Vector2:
	var basis := Basis(Vector3.UP, deg_to_rad(45.0)) * Basis(Vector3.RIGHT, deg_to_rad(-30.0))
	return Vector2(p.dot(basis.x), -p.dot(basis.y)) * Baker.PX_PER_UNIT


func _init() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	var kit = ArtKit.new()
	var models = Models.new()
	var d: Dictionary = DataLib.load_json("res://data/buildings.json")
	var out := PackedStringArray()
	var keys := []
	for line in FileAccess.get_file_as_string(dir.path_join("index.txt")).split("\n"):
		if line.begins_with("look "):
			keys.append(line.split(" ")[1])
	for key in keys:
		var arch: String = key.get_slice(":", 0)
		var rest: String = key.get_slice(":", 1)
		var type := rest
		var suffix := ""
		for mark in ["@", "#", "^"]:
			if mark in rest and suffix == "":
				type = rest.get_slice(mark, 0)
				suffix = rest.substr(type.length())
		if not d.buildings.has(type):
			continue
		var model := ""
		if suffix.begins_with("@"):
			model = d.get("age_looks", {}).get(arch, {}).get(type, {}).get(suffix.substr(1), "")
		var spec: Dictionary = kit._placed(models, arch, type, model, suffix)
		var row := ["bfx", key]
		for k in ["smoke", "lantern"]:
			if spec.has(k):
				var p := _project(spec[k])
				row.append_array(["%.2f" % p.x, "%.2f" % p.y])
			else:
				row.append_array(["-", "-"])
		for l in spec.get("lights", []):
			var p := _project(l)
			row.append_array(["%.2f" % p.x, "%.2f" % p.y])
		out.append(" ".join(row))
		for n in [spec.get("body"), spec.get("banner"), spec.get("vane"), spec.get("open")]:
			if n != null:
				n.free()
	var f := FileAccess.open(dir.path_join("fx.txt"), FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	print("building fx: %d looks of %d" % [out.size(), keys.size()])
	quit()
