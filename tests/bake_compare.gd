extends SceneTree
## Compares two dumps of everything baked (tests/bake_frames.gd ... dump:<file>): the bakes render
## on the GPU, and two runs of the same code differ by a little noise (shadows, ambient occlusion,
## antialiasing), so this says how far apart they are, not just whether they're equal: per image,
## the share of pixels off by more than a step, and the most any channel is off.
##   godot --headless --path . --script res://tests/bake_compare.gd -- a.bin b.bin [c.bin]
## With c: a against b (the noise between two runs of one version) beside a against c.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var a := _load(args[0])
	var b := _load(args[1])
	var c := _load(args[2]) if args.size() > 2 else {}
	for kind in ["part", "bake", "icon", "building", "rig"]:   # each kind of bake on its own
		var ka := _only(a, kind)
		print(_report("%s, a vs b" % kind, ka, _only(b, kind)))
		if not c.is_empty():
			print(_report("%s, a vs c" % kind, ka, _only(c, kind)))
	quit()


static func _only(d: Dictionary, kind: String) -> Dictionary:
	var out := {}
	for k in d:
		if k.begins_with(kind + " "):
			out[k] = d[k]
	return out


static func _load(path: String) -> Dictionary:
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	return f.get_var()


static func _report(title: String, a: Dictionary, b: Dictionary) -> String:
	var keys := a.keys()
	keys.sort()
	var missing := keys.filter(func(k): return not b.has(k)).size() + b.keys().filter(func(k): return not a.has(k)).size()
	var same := 0
	var resized := 0
	var data_off := 0   # origins, rigs, building info that differ
	var worst := []     # [share of pixels off, max diff, key]
	for k in keys:
		if not b.has(k):
			continue
		if var_to_str(a[k][1]) != var_to_str(b[k][1]):
			data_off += 1
		var ia = a[k][0]
		var ib = b[k][0]
		if ia == null:
			continue
		if ia[0] != ib[0] or ia[1] != ib[1]:
			resized += 1
			worst.append([1.0, 255, k])
			continue
		var da: PackedByteArray = ia[2]
		var db: PackedByteArray = ib[2]
		if da == db:
			same += 1
			continue
		var off := 0
		var most := 0
		for i in range(0, da.size(), 4):
			var m := maxi(maxi(absi(da[i] - db[i]), absi(da[i + 1] - db[i + 1])), maxi(absi(da[i + 2] - db[i + 2]), absi(da[i + 3] - db[i + 3])))
			most = maxi(most, m)
			if m > 8:
				off += 1
		worst.append([off / float(da.size() / 4), most, k])
	worst.sort_custom(func(x, y): return x[0] > y[0])
	var lines := ["%s: %d things, %d missing on one side, %d images identical, %d differ (%d resized), %d with other data (origin, rig, info) differing" % [
		title, keys.size(), missing, same, worst.size(), resized, data_off]]
	var shares := worst.map(func(w): return w[0])
	if not shares.is_empty():
		lines.append("  pixels off by more than 8: mean %.4f%%, worst %.3f%%" % [shares.reduce(func(s, x): return s + x, 0.0) / shares.size() * 100.0, shares[0] * 100.0])
	for w in worst.slice(0, 6):
		lines.append("  %.3f%% off, max %d: %s" % [w[0] * 100.0, w[1], w[2]])
	return "\n".join(lines)
