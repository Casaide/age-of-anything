extends SceneTree
## Every research's effects in words as Godot's tech tree writes them (TechTreeModel.effect_text), one
## "id<TAB>text" a line, for effect_words_check.lobster.
##   godot --headless --path . --script res://tests/lobster_spike/effect_words_dump.gd > /tmp/effects.tsv

const TechTreeModel := preload("res://src/view/tech_tree_model.gd")
const DataLib := preload("res://src/data_lib.gd")


func _init() -> void:
	var tdata: Dictionary = DataLib.load_json("res://data/tech.json")
	for r in tdata.research:
		print("%s\t%s" % [r.id, r.get("effect", TechTreeModel.effect_text(r.get("effects", [])))])
	quit()
