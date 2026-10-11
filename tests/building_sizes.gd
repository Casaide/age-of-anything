extends SceneTree
## Measures every building model per architecture (height and width in tiles, from its meshes)
## against the size envelope per type (docs/concepts/direction.md, D-080): one envelope for
## everyone; a culture may sit lower, never taller or bulkier. Prints a table, OVER where broken.
## Run: godot --headless --path . --script res://tests/building_sizes.gd

const Models := preload("res://src/view/art/bake/models.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")

# Max body height (tiles, without flags, crests or smoke) and max width, per type.
const ENVELOPE := {"town_center": [2.1, 2.9], "barracks": [1.6, 2.9], "stable": [1.5, 2.9],
	"house": [1.3, 1.9], "watchtower": [2.6, 1.1], "farm": [0.45, 2.0]}
const ARCHS := ["thatch", "junk", "stone", "tent", "reed", "mound"]


func _init() -> void:
	var models := Models.new()
	var over := 0
	print("%-12s %-12s %7s %7s" % ["arch", "type", "height", "width"])
	for arch in ARCHS:
		for type in ENVELOPE:
			var spec: Dictionary = models.call(ArtKit._model(arch, type), Color.MAGENTA)
			var body: Node3D = spec.body
			if type == "house":
				body.scale = Vector3.ONE * ArtKit.HOUSE_SCALE
			var box := _aabb(body, spec)
			var h := box.end.y
			var wd := maxf(box.size.x, box.size.z)
			var lim: Array = ENVELOPE[type]
			var flag := "  OVER" if h > lim[0] + 0.01 or wd > lim[1] + 0.01 else ""
			if flag != "":
				over += 1
			print("%-12s %-12s %7.2f %7.2f%s" % [arch, type, h, wd, flag])
			body.free()
	print("\n%d buildings over their envelope" % over)
	quit()


## The box around everything but the live parts (banner, vane) and thin poles (flags), which
## may poke above the envelope.
func _aabb(n: Node3D, spec: Dictionary) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else _local(n, mi) * mi.get_aabb()
		if b.size.x < 0.08 and b.size.z < 0.08:
			continue   # poles and pennant shafts
		if b.size.y < 0.03 and b.position.y > 1.5:
			continue   # flag cloth
		box = b if first else box.merge(b)
		first = false
	return box


func _local(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D()
	var p: Node = n
	while p != null and p != root.get_parent():
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t
