extends SceneTree
## Writes every synthesised sound effect to a WAV file, to listen to outside the game.
## Run: godot --headless --path . --script res://tests/sfx_export.gd -- out_dir

const Sfx := preload("res://src/view/sfx.gd")


func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var sfx := Sfx.new()
	root.add_child(sfx)
	await process_frame
	var names: Array = sfx.streams.keys()
	names.sort()
	for n in names:
		(sfx.streams[n] as AudioStreamWAV).save_to_wav(out.path_join(n + ".wav"))
	print("saved ", names.size(), " sounds to ", out)
	quit()
