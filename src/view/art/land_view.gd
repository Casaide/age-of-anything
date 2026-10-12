extends Node2D
## The land's live parts in a match (milestone 15), view side only: map bridges (standing or
## broken, as the sim has them) and which tree species stands on a cell. The sim knows one
## "tree" terrain; the look comes from the ground round it: by water and swamp the swamp
## tree, elsewhere broadleaf and pine in groves (a smooth noise, so a forest is mostly one).

const Iso := preload("res://src/view/iso.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")

const WET := ["swamp", "shallows", "water", "river", "ford", "paddy", "fallow_paddy"]

var world
var kit
var bridges := []          # per sim bridge: [holder, shown up-state]
var _species := {}         # cell -> tree prop kind (cached; the ground round a tree doesn't change)
var _noise := FastNoiseLite.new()


func setup(p_world, p_kit, flat: Node2D) -> void:
	world = p_world
	kit = p_kit
	_noise.seed = hash(world.map.id)
	_noise.frequency = 0.09
	for k in world.bridge_id.size():
		var h := Node2D.new()
		var r: Rect2i = world.bridge_rect[k]
		h.position = Iso.to_screen(r.position.x + (r.size.x + 1) / 2, r.position.y + (r.size.y + 1) / 2)
		flat.add_child(h)   # walked across: under the units
		bridges.append([h, -1])
	sync()


## Follow the sim: a bridge that fell or was rebuilt swaps its bake.
func sync() -> void:
	for k in bridges.size():
		var up: int = world.bridge_up[k]
		if bridges[k][1] == up:
			continue
		bridges[k][1] = up
		var h: Node2D = bridges[k][0]
		for c in h.get_children():
			c.queue_free()
		var r: Rect2i = world.bridge_rect[k]
		var along := 1 if r.size.y > r.size.x else 0
		var length := clampi((maxi(r.size.x, r.size.y) + 1) / 1000, ArtKit.BRIDGE_LENGTHS[0], ArtKit.BRIDGE_LENGTHS[-1])
		h.add_child(kit.sprite(ArtKit.bridge_name(length, along, 0 if up == 1 else 1)))


## The bridge whose deck covers this cell, or -1.
func bridge_at(cell: int) -> int:
	for k in world.bridge_id.size():
		if cell in world.bridge_cells[k]:
			return k
	return -1


## Where a blow on bridge `id` lands on screen, or Vector2.INF if it isn't one.
func target_pos(id: int) -> Vector2:
	for k in world.bridge_id.size():
		if world.bridge_id[k] == id:
			return bridges[k][0].position if k < bridges.size() else Vector2.INF
	return Vector2.INF


## The tree prop kind for a tree on this cell (ArtKit.TREES).
func species_at(cell: int) -> String:
	if _species.has(cell):
		return _species[cell]
	var m = world.map
	var cx: int = cell % m.width
	var cy: int = cell / m.width
	var kind := ""
	for y in range(maxi(cy - 2, 0), mini(cy + 3, m.height)):
		for x in range(maxi(cx - 2, 0), mini(cx + 3, m.width)):
			if m.terrain_ids[m.terrain[y * m.width + x]] in WET:
				kind = "tree_swamp"
	if kind == "":
		kind = "tree_pine" if _noise.get_noise_2d(cx, cy) > 0.08 else "tree_broadleaf"
	_species[cell] = kind
	return kind
