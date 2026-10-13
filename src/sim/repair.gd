extends RefCounted
## Repair (milestone 16): workers mend their side's damaged buildings (walls and gates above all)
## and siege engines (machines aren't healed: combat heal_not). A worker given REPAIR walks up to
## it and puts back hp at buildings.json repair.speed_pct of the pace it was built (a building:
## its build time; an engine: its training time), paying repair.cost_pct of the full price over a
## whole mend, a twentieth at a time (never more than it has: short of it, the worker stops).
## Static functions over the World `w`, integers only, slot order, no Nodes.

const SimMap := preload("res://src/sim/sim_map.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const Economy := preload("res://src/sim/economy.gd")

const CHUNKS := 20   # a mend is paid for in twentieths


static func setup(w) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/buildings.json"))
	var r: Dictionary = d.get("repair", {})
	w.repair_cfg = {"speed_pct": int(r.get("speed_pct", 50)), "cost_pct": int(r.get("cost_pct", 50))}


## Can `player`'s workers mend this (a building or unit id): theirs, finished, hurt, and (a unit)
## a machine?
static func can_mend(w, player: int, id: int) -> bool:
	var b: int = w.buildings.index_of(id)
	if b >= 0:
		var bs = w.buildings
		return bs.owner[b] == player and bs.done[b] == 1 and bs.hp[b] < w.bmods[player][bs.kind[b]].hp
	var j: int = w.units.index_of(id)
	if j < 0 or w.units.owner[j] != player:
		return false
	var t: Dictionary = w.types[w.units.kind[j]]
	return t.get("no_heal", false) and not t.has("animal") and w.units.hp[j] < t.hp


## Commands.REPAIR {ids, target}: the player's workers go and mend it.
static func cmd_repair(w, player: int, a: Dictionary) -> void:
	if not can_mend(w, player, a.target):
		return
	for uid in a.ids:
		var i: int = w.units.index_of(uid)
		if i < 0 or w.units.owner[i] != player or not w.types[w.units.kind[i]].worker or w.units.perch[i] != 0:
			continue
		Economy.clear_task(w, i)
		w.units.task[i] = Economy.REPAIR
		w.units.target[i] = a.target
		w.units.work[i] = 0
		_approach(w, i, a.target)


static func _approach(w, i: int, id: int) -> void:
	var b: int = w.buildings.index_of(id)
	if b >= 0:
		Economy._approach_building(w, i, b)
	else:
		var j: int = w.units.index_of(id)
		w.order_move(i, w.units.x[j], w.units.y[j], w.units.radius[j] + Economy.REACH, 0)


static func _in_reach(w, i: int, id: int) -> bool:
	var b: int = w.buildings.index_of(id)
	if b >= 0:
		return Economy._in_reach(w, i, Economy._building_rect(w, b))
	var j: int = w.units.index_of(id)
	var r: int = w.units.radius[i] + w.units.radius[j] + Economy.REACH
	return Fixed.dist2(w.units.x[i], w.units.y[i], w.units.x[j], w.units.y[j]) <= r * r


## One tick of every mender. `work` counts the milli-hp put back since the last payment.
static func tick(w) -> void:
	var u = w.units
	for i in u.count():
		if u.task[i] != Economy.REPAIR:
			continue
		var id: int = u.target[i]
		var p: int = u.owner[i]
		if not can_mend(w, p, id):
			Economy.clear_task(w, i)
			u.moving[i] = 0
			continue
		if not _in_reach(w, i, id):
			if u.moving[i] == 0:
				if u.stuck[i] >= Economy.GIVE_UP:
					Economy.clear_task(w, i)
				else:
					_approach(w, i, id)
			continue
		u.moving[i] = 0
		var b: int = w.buildings.index_of(id)
		var max_hp: int
		var ticks: int
		var cost: PackedInt32Array
		if b >= 0:
			max_hp = w.bmods[p][w.buildings.kind[b]].hp
			ticks = w.btypes[w.buildings.kind[b]].build_ticks
			cost = w.btypes[w.buildings.kind[b]].cost
		else:
			var t: Dictionary = w.types[u.kind[u.index_of(id)]]
			max_hp = t.hp
			ticks = t.train_ticks
			cost = t.cost
		# milli-hp a tick: the whole of max_hp over the build (or training) time, at speed_pct
		var step: int = maxi(1, max_hp * 1000 * int(w.repair_cfg.speed_pct) / 100 / maxi(1, ticks))
		var chunk: int = maxi(1, max_hp * 1000 / CHUNKS)
		if u.work[i] == 0:   # the next twentieth paid for up front
			var part := _part(w, cost)
			if not w.can_afford(p, part):
				Economy.clear_task(w, i)
				continue
			w.pay(p, part)
		var whole: int = (u.work[i] + step) / 1000 - u.work[i] / 1000
		u.work[i] += step
		if whole > 0:
			_mend(w, id, whole, max_hp)
		if u.work[i] >= chunk:   # a twentieth mended: the next one is paid for on the next tick
			u.work[i] = 0


## A twentieth of repair.cost_pct of a price.
static func _part(w, cost: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for v in cost:
		out.append(v * int(w.repair_cfg.cost_pct) / 100 / CHUNKS)
	return out


static func _mend(w, id: int, hp: int, max_hp: int) -> void:
	var b: int = w.buildings.index_of(id)
	if b >= 0:
		w.buildings.hp[b] = mini(max_hp, w.buildings.hp[b] + hp)
	else:
		var j: int = w.units.index_of(id)
		w.units.hp[j] = mini(max_hp, w.units.hp[j] + hp)
