extends RefCounted
## The AI opponent. It plays the economy through EcoBot, then adds what a player does with it:
## - a build order from data (data/ai.json: which building, in which age, at how many workers);
## - soldiers from every finished military building, picked to counter what the enemy fields
##   (our bonus classes against their tags, minus theirs against ours);
## - defence: soldiers at home go for enemies near the Town Center;
## - attack waves at set times when the army is big enough, then more every couple of minutes;
##   units that run out of things to fight go on to the next enemy building.
## Like EcoBot it only reads sim state and issues commands, so it's deterministic.

const EcoBot := preload("res://src/ai/eco_bot.gd")
const Economy := preload("res://src/sim/economy.gd")
const Commands := preload("res://src/sim/commands.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const Tech := preload("res://src/sim/tech.gd")

const THINK_EVERY := 20     # ticks (1 s), offset from EcoBot's think by half a second
const BUILD_COOLDOWN := 200
const AGE3_WORKERS := 24

var player: int
var eco
var cfg: Dictionary
var wave := 0               # the next wave in cfg.military.waves (past the list: repeats)
var next_wave_tick := 0
var assault := false        # a wave has gone out: units away from home keep pushing
var _next_build := 0


## config: data/ai.json as ints (see load_config), or {} to load it.
func _init(p_player: int, config := {}) -> void:
	player = p_player
	cfg = config if not config.is_empty() else load_config()
	eco = EcoBot.new(p_player)
	eco.FOOD_PCT = int(cfg.economy.food_pct)
	eco.MAX_WORKERS = int(cfg.economy.max_workers)
	eco.AGE_WORKERS = int(cfg.economy.age_workers)
	next_wave_tick = int(cfg.military.waves[0].at) * 20


static func load_config() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/ai.json"))
	assert(d != null, "Bad or missing data/ai.json")
	return _ints(d)


static func _ints(v):
	if typeof(v) == TYPE_DICTIONARY:
		var out := {}
		for k in v:
			out[k] = _ints(v[k])
		return out
	if typeof(v) == TYPE_ARRAY:
		return v.map(_ints)
	if typeof(v) == TYPE_STRING or typeof(v) == TYPE_BOOL:
		return v
	return int(v)


func think(w) -> void:
	if w.defeated[player] != 0 or w.winner >= 0:
		return
	eco.think(w)
	if w.tick % THINK_EVERY != THINK_EVERY / 2:
		return
	var tc: int = eco._town_center(w)
	if tc < 0:
		return
	var workers := []
	var army := []
	for i in w.units.count():
		if w.units.owner[i] != player:
			continue
		if w.types[w.units.kind[i]].worker:
			workers.append(i)
		else:
			army.append(i)
	_build_order(w, tc, workers)
	_age_three(w, tc, workers)
	_train(w, workers)
	var home_x: int = w.buildings.cx[tc] * 1000 + 1500
	var home_y: int = w.buildings.cy[tc] * 1000 + 1500
	_defend(w, army, home_x, home_y)
	_waves(w, army, home_x, home_y)


# ------------------------------------------------------------------ buildings

func _build_order(w, tc: int, workers: Array) -> void:
	if w.tick < _next_build or eco._building_underway(w):
		return
	var have := {}
	for b in w.buildings.count():
		if w.buildings.owner[b] == player:
			var id: String = w.btypes[w.buildings.kind[b]].id
			have[id] = have.get(id, 0) + 1
	var wanted := {}
	for step in cfg.build_order:
		var id: String = step.building
		wanted[id] = wanted.get(id, 0) + 1
		if have.get(id, 0) >= wanted[id]:
			continue
		if w.ages[player] < int(step.get("age", 1)) or workers.size() < int(step.workers):
			return   # the order is an order: wait for this step before the next
		var k: int = Economy.btype_of(w, id)
		if not w.can_afford(player, w.btypes[k].cost):
			return
		var spot: Vector2i = eco._house_spot(w, w.buildings.cx[tc] + 1, w.buildings.cy[tc] + 1, w.btypes[k].size)
		if spot.x < 0:
			return
		var builders := workers.slice(0, 2).map(func(i): return w.units.id[i])
		w.issue(player, Commands.BUILD, {"ids": builders, "building": id, "cx": spot.x, "cy": spot.y})
		_next_build = w.tick + BUILD_COOLDOWN
		return


## EcoBot takes us to age 2; past that, the bot ages up again once the economy is big.
func _age_three(w, tc: int, workers: Array) -> void:
	if w.ages[player] != 2 or workers.size() < AGE3_WORKERS:
		return
	if Tech.why_not(w, player, tc, "") == "":
		w.issue(player, Commands.AGE_UP, {"building": w.buildings.id[tc]})


# ------------------------------------------------------------------ soldiers

func _train(w, workers: Array) -> void:
	var reserve := PackedInt32Array()
	reserve.resize(w.resources.size())
	if w.ages[player] == 1 and workers.size() >= int(cfg.economy.age_workers):
		var next: Dictionary = Tech.next_age(w, player)
		if not next.is_empty():
			reserve = next.cost   # saving for the age: soldiers only from what's over
	var foes := _enemy_tags(w)
	for b in w.buildings.count():
		if w.buildings.owner[b] != player or w.buildings.done[b] == 0 or w.buildings.research[b] != -1:
			continue
		var bt: Dictionary = w.btypes[w.buildings.kind[b]]
		if bt.trains.is_empty() or "worker" in bt.trains or w.buildings.queue[b].size() >= int(cfg.military.queue):
			continue
		var best := ""
		var best_score := -(1 << 30)
		for slot in bt.trains:
			var k: int = w.type_of(player, slot)
			if k < 0 or w.ages[player] < int(w.types[k].line[0].age):
				continue
			var s := _score(w.types[k], foes)
			if s > best_score:
				best_score = s
				best = slot
		if best == "":
			continue
		var cost: PackedInt32Array = w.types[w.type_of(player, best)].cost
		var ok := true
		for r in cost.size():
			if w.stock[r][player] < cost[r] + reserve[r]:
				ok = false
		if ok:
			w.issue(player, Commands.TRAIN, {"building": w.buildings.id[b], "slot": best})


## How many enemy units carry each tag (their army, not workers).
func _enemy_tags(w) -> Dictionary:
	var tags := {}
	for i in w.units.count():
		if not w.is_enemy(player, w.units.owner[i]):
			continue
		var t: Dictionary = w.types[w.units.kind[i]]
		if t.worker:
			continue
		for tag in t.eval.tags:
			tags[tag] = tags.get(tag, 0) + 1
		for c in t.eval.bonus:   # remember what they're good against, keyed apart
			tags["bonus:" + c] = tags.get("bonus:" + c, 0) + int(t.eval.bonus[c])
	return tags


## Counter value of one of our types against what the enemy fields: our bonuses that hit their
## tags, minus their bonuses that hit ours; a little for raw attack and hp so ties go to the
## sturdier unit when there's nothing to read yet.
func _score(t: Dictionary, foes: Dictionary) -> int:
	var e: Dictionary = t.eval
	var s := int(e.attack) + int(e.hp) / 10
	for c in e.bonus:
		s += int(e.bonus[c]) * int(foes.get(c, 0))
	for tag in e.tags:
		s -= int(foes.get("bonus:" + tag, 0))
	return s


# ------------------------------------------------------------------ the army

func _defend(w, army: Array, hx: int, hy: int) -> void:
	var r := int(cfg.military.defend_tiles) * 1000
	var intruder := -1
	var best_d2 := r * r
	for i in w.units.count():
		if not w.is_enemy(player, w.units.owner[i]):
			continue
		var d2 := Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i])
		if d2 < best_d2:
			best_d2 = d2
			intruder = i
	if intruder < 0:
		return
	var ids := []
	for i in army:
		if w.units.foe[i] == 0 and Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i]) < 4 * r * r:
			ids.append(w.units.id[i])
	if not ids.is_empty():
		w.issue(player, Commands.ATTACK_MOVE, {"ids": ids, "x": w.units.x[intruder], "y": w.units.y[intruder]})


func _waves(w, army: Array, hx: int, hy: int) -> void:
	var m: Dictionary = cfg.military
	var target := _enemy_target(w, hx, hy)
	if target.x < 0:
		return
	var waves: Array = m.waves
	var need: int = int(waves[wave].min_army) if wave < waves.size() else int(m.repeat_min_army)
	if w.tick >= next_wave_tick and army.size() >= need:
		w.issue(player, Commands.ATTACK_MOVE, {"ids": army.map(func(i): return w.units.id[i]), "x": target.x, "y": target.y})
		assault = true
		wave += 1
		next_wave_tick = int(waves[wave].at) * 20 if wave < waves.size() else w.tick + int(m.repeat_every) * 20
		return
	if not assault or w.tick % (int(m.regroup_every) * 20) != THINK_EVERY / 2:
		return
	# Soldiers out in the field with nothing left to fight push on to the next target.
	var home_r := int(m.defend_tiles) * 1000
	var ids := []
	for i in army:
		if w.units.foe[i] == 0 and w.units.moving[i] == 0 and Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i]) > 4 * home_r * home_r:
			ids.append(w.units.id[i])
	if not ids.is_empty():
		w.issue(player, Commands.ATTACK_MOVE, {"ids": ids, "x": target.x, "y": target.y})


## Where to attack: the nearest enemy Town Center, else the nearest enemy building (milli-tiles).
func _enemy_target(w, hx: int, hy: int) -> Vector2i:
	var tc_kind: int = Economy.btype_of(w, "town_center")
	var best := Vector2i(-1, -1)
	var best_d2 := 1 << 62
	var best_tc := false
	for b in w.buildings.count():
		if not w.is_enemy(player, w.buildings.owner[b]):
			continue
		var bs = w.buildings
		var x: int = bs.cx[b] * 1000 + bs.size[b] * 500
		var y: int = bs.cy[b] * 1000 + bs.size[b] * 500
		var is_tc: bool = bs.kind[b] == tc_kind
		var d2 := Fixed.dist2(hx, hy, x, y)
		if (is_tc and not best_tc) or (is_tc == best_tc and d2 < best_d2):
			best = Vector2i(x, y)
			best_d2 = d2
			best_tc = is_tc
	return best
