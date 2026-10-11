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
const Fog := preload("res://src/sim/fog.gd")

const THINK_EVERY := 20     # ticks (1 s), offset from EcoBot's think by half a second
const BUILD_COOLDOWN := 200
const AGE3_WORKERS := 24
const REINFORCE := 4         # soldiers idle at home that go forward as a group during an attack

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
	eco.MIX = {}
	for age in cfg.economy.mix:
		eco.MIX[int(age)] = cfg.economy.mix[age]
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
		var at := Vector2i(w.buildings.cx[tc] + 1, w.buildings.cy[tc] + 1)
		if step.has("near"):   # a drop-off camp goes by the nearest patch of its resource
			var cell: int = eco._nearest_resource(w, at.x * 1000, at.y * 1000, w.resources.find(step.near) + 1)
			if cell >= 0:
				at = Vector2i(cell % w.map.width, cell / w.map.width)
		var spot: Vector2i = eco._house_spot(w, at.x, at.y, w.btypes[k].size)
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
	var guard := 0   # keep a small guard even while saving for an age, like a sensible player
	for i in w.units.count():
		if w.units.owner[i] == player and not w.types[w.units.kind[i]].worker:
			guard += int(w.types[w.units.kind[i]].pop)
	if w.ages[player] == 1 and workers.size() >= int(cfg.economy.age_workers) and guard >= int(cfg.military.guard):
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


## How many enemy units we can see carry each tag (their army, not workers).
func _enemy_tags(w) -> Dictionary:
	var tags := {}
	for i in w.units.count():
		if not w.is_enemy(player, w.units.owner[i]) or not Fog.visible(w, player, w.units.x[i], w.units.y[i]):
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
		if not w.is_enemy(player, w.units.owner[i]) or not Fog.visible(w, player, w.units.x[i], w.units.y[i]):
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
	var strength := 0   # army size in population, so big units count for what they cost
	for i in army:
		strength += int(w.types[w.units.kind[i]].pop)
	if w.tick >= next_wave_tick and strength >= need:
		w.issue(player, Commands.ATTACK_MOVE, {"ids": army.map(func(i): return w.units.id[i]), "x": target.x, "y": target.y})
		assault = true
		wave += 1
		next_wave_tick = int(waves[wave].at) * 20 if wave < waves.size() else w.tick + int(m.repeat_every) * 20
		return
	if not assault or w.tick % (int(m.regroup_every) * 20) != THINK_EVERY / 2:
		return
	# Soldiers out in the field with no enemy soldier to fight (idle, or hacking at a house)
	# push on to the next target.
	var home_r := int(m.defend_tiles) * 1000
	var ids := []
	# Reinforcements: once we're attacking, fresh soldiers idling at home go forward in groups.
	var home := army.filter(func(i): return w.units.foe[i] == 0 and w.units.moving[i] == 0 \
			and Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i]) <= 4 * home_r * home_r)
	if home.size() >= REINFORCE:
		ids.append_array(home.map(func(i): return w.units.id[i]))
	for i in army:
		var on_building: bool = w.units.foe[i] != 0 and w.buildings.index_of(w.units.foe[i]) >= 0
		var free: bool = (w.units.foe[i] == 0 and w.units.moving[i] == 0) or on_building
		if free and Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i]) > 4 * home_r * home_r:
			ids.append(w.units.id[i])
	if ids.is_empty():
		return
	# With the field clear, go for the Town Center itself (that ends the match) rather than
	# chewing through every house on the way.
	var tc_id := _known_enemy_town(w, hx, hy)
	if tc_id <= 0:
		w.issue(player, Commands.ATTACK_MOVE, {"ids": ids, "x": target.x, "y": target.y})
		return
	# Enough to fight the defenders (two each) attack-move; the rest go straight for the Town Center.
	var fighters := mini(ids.size(), 2 * _defenders(w, w.buildings.index_of(tc_id)))
	if fighters > 0:
		w.issue(player, Commands.ATTACK_MOVE, {"ids": ids.slice(0, fighters), "x": target.x, "y": target.y})
	if fighters < ids.size():
		w.issue(player, Commands.ATTACK, {"ids": ids.slice(fighters), "target": tc_id})


## How many enemy soldiers we can see near this building (they need fighting: a unit told to
## hit a building doesn't hit back).
func _defenders(w, b: int) -> int:
	var bs = w.buildings
	var x: int = bs.cx[b] * 1000 + bs.size[b] * 500
	var y: int = bs.cy[b] * 1000 + bs.size[b] * 500
	var r := int(cfg.military.defend_tiles) * 1000
	var n := 0
	for i in w.units.count():
		if w.is_enemy(player, w.units.owner[i]) and not w.types[w.units.kind[i]].worker \
				and Fog.visible(w, player, w.units.x[i], w.units.y[i]) and Fixed.dist2(x, y, w.units.x[i], w.units.y[i]) < r * r:
			n += 1
	return n


## The id of the nearest enemy Town Center we've seen, or 0.
func _known_enemy_town(w, hx: int, hy: int) -> int:
	var tc_kind: int = Economy.btype_of(w, "town_center")
	var bs = w.buildings
	var best := 0
	var best_d2 := 1 << 62
	for b in bs.count():
		if bs.kind[b] != tc_kind or not w.is_enemy(player, bs.owner[b]) or not Fog.explored(w, player, bs.cx[b], bs.cy[b]):
			continue
		var d2 := Fixed.dist2(hx, hy, bs.cx[b] * 1000, bs.cy[b] * 1000)
		if d2 < best_d2:
			best_d2 = d2
			best = bs.id[b]
	return best


## Where to attack: the nearest enemy Town Center we've seen, else the nearest enemy building
## we've seen, else an enemy's starting spot (every player knows where the others start).
func _enemy_target(w, hx: int, hy: int) -> Vector2i:
	var tc_kind: int = Economy.btype_of(w, "town_center")
	var best := Vector2i(-1, -1)
	var best_d2 := 1 << 62
	var best_tc := false
	for b in w.buildings.count():
		var bs = w.buildings
		if not w.is_enemy(player, bs.owner[b]) or not Fog.explored(w, player, bs.cx[b], bs.cy[b]):
			continue
		var x: int = bs.cx[b] * 1000 + bs.size[b] * 500
		var y: int = bs.cy[b] * 1000 + bs.size[b] * 500
		var is_tc: bool = bs.kind[b] == tc_kind
		var d2 := Fixed.dist2(hx, hy, x, y)
		if (is_tc and not best_tc) or (is_tc == best_tc and d2 < best_d2):
			best = Vector2i(x, y)
			best_d2 = d2
			best_tc = is_tc
	if best.x < 0:
		for p in w.races.size():
			if w.is_enemy(player, p) and w.defeated[p] == 0 and p < w.map.starts.size():
				return Vector2i(int(w.map.starts[p][0]), int(w.map.starts[p][1]))
	return best
