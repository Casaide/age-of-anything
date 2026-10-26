extends "res://scenes/art_pixel/unit_models.gd"
## Fidelity study: the game's unit models plus whole concept figures from .glb files
## (tools/blender/concept_soldier.py), "concept.figure<k>" -> files[id], with the game's materials.

var files := {}


func has(id: String) -> bool:
	return files.has(id.get_slice("@", 0)) or super(id)


func build(id: String, colours: Dictionary) -> Dictionary:
	var base := id.get_slice("@", 0)
	if not files.has(base):
		return super(id, colours)
	var c := colours
	var mats := {
		"skin": surf("skin", c.skin, 8.0), "hair": surf("mane", c.skin2.darkened(0.45), 3.0),
		"cloth": surf("cloth", Color("#8a2a22"), 4.0), "team": surf("cloth", c.team, 4.0),
		"iron": surf("iron", Color("#b8bcc4"), 6.0), "bronze": surf("bronze", Color.WHITE, 4.0),
		"leather": surf("leather", Color("#7a5236"), 4.0), "wood": surf("wood_grain", Color("#8a6040"), 4.0)}
	return {"node": glb_file(files[base], mats)}
