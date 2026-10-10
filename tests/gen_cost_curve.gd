extends SceneTree
## Dev tool: writes data/cost_curves.json, the fixed-point cost curves pricing uses.
## Floats are fine here; this runs offline and its output is checked in, so every
## machine reads the same integers.
## Run: godot --headless --path . --script res://tests/gen_cost_curve.gd

const OUT := "res://data/cost_curves.json"
const MAX_POINTS := 96

## id -> (points / ref_points) ^ exponent, stored as per-mille for points 0..MAX_POINTS.
const CURVES := {
	"pow1.4_ref12": {"exponent": 1.4, "ref_points": 12},
	"pow1.2_ref12": {"exponent": 1.2, "ref_points": 12},
}


func _init() -> void:
	var ids := CURVES.keys()
	ids.sort()
	var lines := []
	for id in ids:
		var c: Dictionary = CURVES[id]
		var vals := []
		for p in MAX_POINTS + 1:
			vals.append(str(int(round(1000.0 * pow(float(p) / float(c.ref_points), c.exponent)))))
		lines.append(' "%s": {"exponent": "%s", "ref_points": %d, "permille": [%s]}' % [id, c.exponent, c.ref_points, ", ".join(vals)])
	var text := "{\n" + ",\n".join(lines) + "\n}\n"
	FileAccess.open(OUT, FileAccess.WRITE).store_string(text)
	print("wrote ", OUT)
	quit()
