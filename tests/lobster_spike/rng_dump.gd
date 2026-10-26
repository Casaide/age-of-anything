extends SceneTree
## Godot's RandomNumberGenerator as numbers (model/grng.lobster's check: rng_check.lobster).
##   godot --headless --path . --script res://tests/lobster_spike/rng_dump.gd -- <out.txt>


func _init() -> void:
	var out := PackedStringArray()
	for s in [31, 0, 12345, 987654321]:
		var r := RandomNumberGenerator.new()
		r.seed = s
		var line := []
		for k in 6:
			line.append("%d" % r.randi())
			line.append("%.9f" % r.randf())
			line.append("%.9f" % r.randf_range(-7.0, 6.0))
			line.append("%d" % r.randi_range(-3, 11))
			line.append("%.9f" % r.randfn(1.5, 0.4))
		out.append("seed %d %s" % [s, " ".join(line)])
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	quit()
