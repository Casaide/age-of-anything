extends SceneTree
## Every map's tree species per cell (LandView.species_at: swamp trees near wet ground, else pine or
## broadleaf by the map's own noise), one file a map, for the Lobster game on any map.
## Run: godot --headless --path . --script res://tests/lobster_spike/map_species.gd -- <out dir>

const SimMap := preload("res://src/sim/sim_map.gd")
const LandView := preload("res://src/view/art/land_view.gd")


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var dir := DirAccess.open("res://data/maps")
	var names := []
	for f in dir.get_files():
		if f.ends_with(".json"):
			names.append(f.trim_suffix(".json"))
	names.sort()
	for id in names:
		var m = SimMap.load_id(id)
		var noise := FastNoiseLite.new()
		noise.seed = hash(m.id)
		noise.frequency = 0.09
		var row := []
		for c in m.width * m.height:
			if m.terrain_ids[m.terrain[c]] != "tree" and m.terrain_ids[m.terrain[c]] != "stump":
				row.append("-")
				continue
			var cx: int = c % m.width
			var cy: int = c / m.width
			var kind := ""
			for y in range(maxi(cy - 2, 0), mini(cy + 3, m.height)):
				for x in range(maxi(cx - 2, 0), mini(cx + 3, m.width)):
					if m.terrain_ids[m.terrain[y * m.width + x]] in LandView.WET:
						kind = "tree_swamp"
			if kind == "":
				kind = "tree_pine" if noise.get_noise_2d(cx, cy) > 0.08 else "tree_broadleaf"
			row.append(kind)
		var f := FileAccess.open(out.path_join(id + ".txt"), FileAccess.WRITE)
		f.store_string(" ".join(row) + "\n")
		f.close()
		print(id)
	quit()
