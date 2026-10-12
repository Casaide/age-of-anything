extends RefCounted
## Map bridges (milestone 15): timber decks over a river, placed by the map, owned by nobody.
## A standing bridge lays a deck on the map (SimMap.deck): ground units walk its cells as if
## they were land. Anyone can break one by attacking it (Commands.ATTACK on its id): the deck
## falls into the river and the crossing is gone; anyone on it scrambles to the nearest bank.
## Any player's workers rebuild it (Commands.HELP_BUILD on its id); the first to start pays
## the cost (data/bridges.json). Amphibians don't care either way: they swim.
##
## Bridges live in parallel arrays on the World (w.bridge_*), ids from the shared id counter,
## so orders name them like units and buildings. Static functions over the World, like
## economy.gd. Integers only.

const SimMap := preload("res://src/sim/sim_map.gd")
const Fixed := preload("res://src/sim/fixed.gd")


static func setup(w) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/bridges.json"))
	assert(d != null and d.schema == "aow.bridges/1", "Bad or missing data/bridges.json")
	var cost := PackedInt32Array()
	for r in w.resources:
		cost.append(int(d.rebuild.cost.get(r, 0)))
	var arm := PackedInt32Array()
	arm.resize(w.classes.size())
	for k in d.armour:
		arm[w.classes.find(k)] = int(d.armour[k])
	var cls := PackedByteArray()
	cls.resize(w.classes.size())
	cls[0] = 1
	cls[1] = 1
	cls[2] = 1   # melee, pierce, building
	w.bridge_cfg = {"hp": int(d.hp), "arm": arm, "cls": cls, "cost": cost, "ticks": int(d.rebuild.time) * w.TICK_HZ}
	for r in w.map.bridge_rects:
		var cells := PackedInt32Array()
		for y in range(r[1], r[3] + 1):
			for x in range(r[0], r[2] + 1):
				cells.append(y * w.map.width + x)
		w.bridge_id.append(w.next_id)
		w.next_id += 1
		w.bridge_cells.append(cells)
		w.bridge_rect.append(Rect2i(r[0] * SimMap.TILE, r[1] * SimMap.TILE, (r[2] - r[0] + 1) * SimMap.TILE - 1, (r[3] - r[1] + 1) * SimMap.TILE - 1))
		w.bridge_hp.append(int(d.hp))
		w.bridge_up.append(1)
		w.bridge_work.append(0)
		w.bridge_payer.append(-1)
		w.map.set_deck(cells, true)


## The slot of bridge `id`, or -1.
static func index_of(w, id: int) -> int:
	for k in w.bridge_id.size():
		if w.bridge_id[k] == id:
			return k
	return -1


## A standing bridge anyone may attack.
static func is_target(w, id: int) -> bool:
	var k := index_of(w, id)
	return k >= 0 and w.bridge_up[k] == 1


## Damage from a hit on standing bridge k (combat.gd's formula, its armour from data).
static func damage_from(w, k: int, atk: PackedInt32Array, min_damage: int) -> int:
	var d := 0
	var arm: PackedInt32Array = w.bridge_cfg.arm
	var cls: PackedByteArray = w.bridge_cfg.cls
	for c in atk.size():
		if atk[c] > 0 and cls[c] == 1:
			d += maxi(0, atk[c] - arm[c])
	return maxi(min_damage, d)


## Land this tick's damage on bridge k: at 0 it falls.
static func hurt(w, k: int, d: int) -> void:
	if w.bridge_up[k] == 0:
		return
	w.bridge_hp[k] -= d
	if w.bridge_hp[k] > 0:
		return
	w.bridge_hp[k] = 0
	w.bridge_up[k] = 0
	w.bridge_work[k] = 0
	w.bridge_payer[k] = -1
	w.map.set_deck(w.bridge_cells[k], false)
	var r: Rect2i = w.bridge_rect[k]
	w.events.append({"type": "die", "id": w.bridge_id[k], "x": r.get_center().x, "y": r.get_center().y, "owner": -1, "kind": -1, "building": true, "bridge": true})


## HELP_BUILD on a bridge: the first of a broken bridge's rebuilders pays, then the player's
## workers go and work on it. Returns false if `target` isn't a bridge.
static func cmd_help(w, player: int, a: Dictionary, workers: Array) -> bool:
	var k := index_of(w, a.target)
	if k < 0:
		return false
	if w.bridge_up[k] == 1:
		return true
	if w.bridge_payer[k] < 0:
		var cost: PackedInt32Array = w.bridge_cfg.cost
		if not w.can_afford(player, cost):
			return true
		w.pay(player, cost)
		w.bridge_payer[k] = player
	for i in workers:
		var u = w.units
		u.task[i] = 3   # Economy.BUILD
		u.target[i] = w.bridge_id[k]
		u.home[i] = -1
		u.work[i] = 0
		approach(w, i, k)
	return true


static func approach(w, i: int, k: int) -> void:
	w.order_reach(i, w.bridge_rect[k], w.building_field(w.bridge_id[k], true, w.lane(i)))


## A worker at its BUILD job on bridge k: walk up to it, then put a tick's work in. Returns
## false when the job is over (the bridge stands again).
static func work(w, i: int, k: int, in_reach: bool) -> bool:
	if w.bridge_up[k] == 1 or w.bridge_payer[k] < 0:
		return false
	var u = w.units
	if not in_reach:
		if u.moving[i] == 0:
			if u.stuck[i] >= w.STUCK_LIMIT:
				return false
			approach(w, i, k)
		return true
	u.moving[i] = 0
	u.stuck[i] = 0
	var ticks: int = w.bridge_cfg.ticks
	w.bridge_work[k] = mini(ticks, w.bridge_work[k] + 1)
	w.bridge_hp[k] = maxi(1, int(w.bridge_cfg.hp) * w.bridge_work[k] / ticks)
	if w.bridge_work[k] >= ticks:
		w.bridge_up[k] = 1
		w.bridge_hp[k] = int(w.bridge_cfg.hp)
		w.bridge_payer[k] = -1
		w.map.set_deck(w.bridge_cells[k], true)
		return false
	return true


## The edge-to-edge gap from unit i to bridge k, in milli-tiles.
static func gap(w, i: int, k: int) -> int:
	var r: Rect2i = w.bridge_rect[k]
	var u = w.units
	var dx: int = maxi(maxi(r.position.x - u.x[i], 0), u.x[i] - r.end.x)
	var dy: int = maxi(maxi(r.position.y - u.y[i], 0), u.y[i] - r.end.y)
	return Fixed.isqrt(dx * dx + dy * dy) - u.radius[i]


static func hash_into(w, h: int) -> int:
	for k in w.bridge_id.size():
		for v in [w.bridge_id[k], w.bridge_hp[k], w.bridge_up[k], w.bridge_work[k], w.bridge_payer[k]]:
			h = Fixed.mix(h, v)
	return h
