extends SceneTree
## The races the GDScript generator makes, one line of sorted JSON each (compared with races.lobster).
## Run: godot --headless --path . --script res://tests/lobster_spike/race_dump.gd -- out.txt rules "prompt" ...

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_rules(args[1])
	var out := FileAccess.open(args[0], FileAccess.WRITE)
	for p in args.slice(2):
		out.store_line(JSON.stringify(gen.generate(p, rules), "", true))
	quit()
