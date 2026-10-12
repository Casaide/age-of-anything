extends RefCounted
## The AI opponent. It plays the economy through EcoBot, then adds what a player does with it:
## - a build order from data (data/ai.json: which building, in which age, at how many workers);
## - soldiers from every finished military building, picked to counter what the enemy fields
##   (our bonus classes against their tags, minus theirs against ours);
## - defence: soldiers at home go for enemies near the Town Center; a blow on any of our
##   buildings or workers, anywhere, gets soldiers sent there (enough to win, nearest first) and
##   the workers near the attackers pulled back to the Town Center for a while;
## - reach (src/ai/reach.gd, through EcoBot): it only sends units where they can get to. A
##   target cut off (a walled ford) is passed over for another; an enemy out of reach is
##   attacked through the wall that shuts the way (or from the nearest bank, with none);
## - attack waves at set times when the army is big enough, then more every couple of minutes;
##   units that run out of things to fight go on to the next enemy building;
## - a couple of healers from the Town Center in ages 2-3 (data: military.healers), kept a few
##   tiles behind the army, on the side towards home; they heal whoever is hurt near them;
## - a Wonder when it's rich in age 3 (data: wonder); and an enemy Wonder it knows of is the
##   first target of every attack, a finished one (its countdown running) attacked at once.
## Like EcoBot it only reads sim state and issues commands, so it's deterministic.

const EcoBot := preload("res://src/ai/eco_bot.gd")
const Economy := preload("res://src/sim/economy.gd")
const Commands := preload("res://src/sim/commands.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const Tech := preload("res://src/sim/tech.gd")
const Fog := preload("res://src/sim/fog.gd")

const THINK_EVERY := 20     # ticks (1 s), offset from EcoBot's think by half a second
const BUILD_COOLDOWN := 200
const REINFORCE := 4         # soldiers idle at home that go forward as a group during an attack
const THREAT_TICKS := 200    # a blow on our buildings or workers is answered for 10 s after
const RESEND := 100          # ticks before a soldier already sent to trouble is sent again
const TROUBLE_TILES := 8     # attackers this close to the latest blow count as one raid
const FLEE_TILES := 7        # our workers this close to a raider get out of the way
const RESPOND_TILES := 30    # soldiers away from home further than this from the raid keep to their own fight

var player: int
var eco
var cfg: Dictionary
var wave := 0               # the next wave in cfg.military.waves (past the list: repeats)
var next_wave_tick := 0
var assault := false        # a wave has gone out: units away from home keep pushing
var _next_build := 0
var _threats := {}           # enemy unit or building id -> the tick it last hit our buildings or workers
var _sent := {}              # our soldier id -> the tick it was sent to trouble
var _aln := 0                # our soldiers' lane (Reach)
var _harea := 0              # the area round our Town Center in that lane
var _rushed := -(1 << 30)    # the tick we last sent everyone at a finished enemy Wonder
var _blocked := PackedInt32Array()   # the cost of the build step waiting on resources (what it saves for)
var _tower_at := Vector2i(-1, -1)    # where a raid was: a Watchtower goes up there once it's quiet
var _sheltering := false     # our workers were called to arms
var _saving_age := false     # the goal is the next age (the economy leans on it hard)


## config: data/ai.json as ints (see load_config), or {} to load it. level: a key of
## its "levels" (easy, normal, hard): how it plays (see "levels" there).
var army_ratio := 0   # soldiers kept per age as a percent of workers (0: no limit); grows with the ages
var wave_pct := 100   # the share of the army each wave sends; the rest defend
var build_up := false # economy and upgrades come before soldiers
var age3_workers := 26   # workers before it saves for age 3
var towers := 0       # Watchtowers it raises where it was raided
var shelter_pop := 0  # a raid this big (enemy population) by the Town Center calls the workers to arms (0: never)


func _init(p_player: int, config := {}, level := "normal") -> void:
	player = p_player
	cfg = config if not config.is_empty() else load_config()
	age3_workers = int(cfg.economy.get("age3_workers", age3_workers))
	if cfg.has("levels") and cfg.levels.has(level):
		var l: Dictionary = cfg.levels[level]
		cfg = cfg.duplicate(true)
		for w in cfg.military.waves:
			w.at = int(w.at) + int(l.get("delay", 0))
			w.min_army = maxi(1, int(w.min_army) * int(l.get("army_pct", 100)) / 100)
		var rm = cfg.military.repeat_min_army
		if typeof(rm) == TYPE_DICTIONARY:
			for a in rm:
				rm[a] = maxi(1, int(rm[a]) * int(l.get("army_pct", 100)) / 100)
		else:
			cfg.military.repeat_min_army = maxi(1, int(rm) * int(l.get("army_pct", 100)) / 100)
		cfg.economy.max_workers = l.get("max_workers", cfg.economy.max_workers)
		army_ratio = int(l.get("army_ratio", 0))
		wave_pct = int(l.get("wave_pct", 100))
		build_up = int(l.get("build_up", 0)) == 1
		age3_workers = int(l.get("age3_workers", age3_workers))
		towers = int(l.get("towers", 0))
		shelter_pop = int(l.get("shelter_pop", 0))
	eco = EcoBot.new(p_player)
	eco.MIX = {}
	for age in cfg.economy.mix:
		eco.MIX[int(age)] = cfg.economy.mix[age]
	eco.MAX_WORKERS = _max_workers(1)
	eco.AGE_WORKERS = int(cfg.economy.age_workers)
	eco.REBALANCE = int(cfg.economy.get("rebalance_every", 0)) * 20
	next_wave_tick = int(cfg.military.waves[0].at) * 20


## The army (population) a repeat wave needs in this age (military.repeat_min_army: one number,
## or one per age: a Town Center full of workers and a tower or two want a bigger wave in age 3).
func _repeat_min(w) -> int:
	var m = cfg.military.repeat_min_army
	if typeof(m) != TYPE_DICTIONARY:
		return int(m)
	var best := 1
	for a in m:
		if int(a) <= w.ages[player]:
			best = maxi(best, int(m[a]))
	return best


## The most workers it trains in an age (economy.max_workers: one number, or one per age).
func _max_workers(age: int) -> int:
	var m = cfg.economy.max_workers
	if typeof(m) != TYPE_DICTIONARY:
		return int(m)
	var best := 0
	for a in m:
		if int(a) <= age:
			best = maxi(best, int(m[a]))
	return best


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
	_note_hits(w)
	eco.MAX_WORKERS = _max_workers(w.ages[player])
	eco.think(w)
	if w.tick % THINK_EVERY != THINK_EVERY / 2:
		return
	var tc: int = eco._town_center(w)
	if tc < 0:
		return
	var workers := []
	var army := []
	var healers := []
	for i in w.units.count():
		if w.units.owner[i] != player:
			continue
		var t: Dictionary = w.types[w.units.kind[i]]
		if t.worker:
			workers.append(i)
		elif t.healer:
			healers.append(i)
		elif not t.has("animal"):   # our sheep aren't soldiers
			army.append(i)
	var count: int = workers.size() + eco.sheltered(w)
	_build_order(w, tc, workers, count)
	eco.goal = _goal(w, count)
	eco.push = 100 if _saving_age else int(cfg.economy.get("build_push", 30))   # (a building leans gently)
	_age_three(w, tc, count)
	_wonder(w, tc, workers)
	_upgrade_lines(w, army)
	_train(w, workers, count)
	_train_healers(w, tc, army, healers)
	var home_x: int = w.buildings.cx[tc] * 1000 + 1500
	var home_y: int = w.buildings.cy[tc] * 1000 + 1500
	_aln = w.lane(army[0]) if not army.is_empty() else w.lane_base[player]
	_harea = eco.reach.area_at(w, _aln, home_x, home_y)
	_defend(w, army, home_x, home_y)
	_respond(w, tc, army, workers, home_x, home_y)
	_tower(w, workers)
	_waves(w, army, home_x, home_y)
	_escort(w, army, healers, home_x, home_y)


# ------------------------------------------------------------------ buildings

func _build_order(w, tc: int, workers: Array, count: int) -> void:
	if w.tick < _next_build or eco._building_underway(w):
		return
	_blocked = PackedInt32Array()
	var have := {}
	for b in w.buildings.count():
		if w.buildings.owner[b] == player and (w.buildings.done[b] == 1 or eco.reach.reaches_building(w, eco.wln, eco.home, b)):
			var id: String = w.btypes[w.buildings.kind[b]].id   # (a foundation cut off counts for nothing: another goes up)
			have[id] = have.get(id, 0) + 1
			var was := _upgrade_of(w, id)
			if was != "":
				have[was] = have.get(was, 0) + 1   # a Bastion is the Watchtower it was
	var wanted := {}
	for step in cfg.build_order:
		var id: String = step.building
		wanted[id] = int(step.get("count", wanted.get(id, 0) + 1))
		if have.get(id, 0) >= wanted[id]:
			continue
		if w.ages[player] < int(step.get("age", 1)):
			continue   # a later age's step (the University, the Castle) doesn't hold up this age's
		if count < int(step.workers) or workers.is_empty():
			return   # the order is an order: wait for this step before the next
		var k: int = Economy.btype_of(w, id)
		if not w.can_afford(player, w.btypes[k].cost):
			_blocked = w.btypes[k].cost   # what we save for (economy shares, and soldiers leave it alone)
			return
		var at := Vector2i(w.buildings.cx[tc] + 1, w.buildings.cy[tc] + 1)
		if step.has("near"):   # a drop-off camp goes by the nearest patch of its resource
			var cell: int = _patch(w, at, w.resources.find(step.near) + 1, int(step.get("away", 0)))
			if cell >= 0:
				at = Vector2i(cell % w.map.width, cell / w.map.width)
		var spot: Vector2i = eco._house_spot(w, at.x, at.y, w.btypes[k].size)
		if spot.x < 0:
			return
		var builders := _nearest_workers(w, workers, spot.x * 1000, spot.y * 1000, int(step.get("builders", 2)))
		w.issue(player, Commands.BUILD, {"ids": builders, "building": id, "cx": spot.x, "cy": spot.y})
		_next_build = w.tick + BUILD_COOLDOWN
		return


## The building type a research turns into this one (tech.json `becomes`: a Watchtower for a
## Bastion), or "".
static func _upgrade_of(w, id: String) -> String:
	for r in w.tech.research:
		for fx in r.effects:
			if fx.get("becomes", "") == id:
				return fx.building
	return ""


## Do we have one of these, built or going up?
func _has_any(w, id: String) -> bool:
	var k: int = Economy.btype_of(w, id)
	for b in w.buildings.count():
		if w.buildings.owner[b] == player and w.buildings.kind[b] == k:
			return true
	return false


## Our Watchtowers (Bastions too), built or going up.
func _towers_up(w) -> int:
	var n := 0
	for b in w.buildings.count():
		var id: String = w.btypes[w.buildings.kind[b]].id
		if w.buildings.owner[b] == player and (id == "watchtower" or _upgrade_of(w, id) == "watchtower"):
			n += 1
	return n


## The nearest cell of that resource (1-based kind) our workers can get to, at least `away`
## tiles from `at` (a second Town Center goes out by the resources further off), or -1.
func _patch(w, at: Vector2i, kind: int, away: int) -> int:
	if away <= 0:
		return eco._nearest_resource(w, at.x * 1000, at.y * 1000, kind)
	var best := -1
	var best_d2 := 1 << 62
	for c in w.map.resource_cells:
		if w.map.amount[c] <= 0 or Economy.kind_of(w, w.map.resource_at(c)) != kind:
			continue
		var d2 := Fixed.dist2(at.x, at.y, c % w.map.width, c / w.map.width)
		if d2 >= away * away and d2 < best_d2 and eco.reach.reaches_cell(w, eco.wln, eco.home, c):
			best_d2 = d2
			best = c
	return best


## Up to `n` of our workers' ids, nearest a point (ties: lower id), not counting ones kept from work.
func _nearest_workers(w, workers: Array, x: int, y: int, n: int) -> Array:
	var pool := []
	for i in workers:
		if int(eco.held.get(w.units.id[i], 0)) <= w.tick:
			pool.append([Fixed.dist2(x, y, w.units.x[i], w.units.y[i]), w.units.id[i]])
	pool.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return pool.slice(0, n).map(func(e): return e[1])


## What we save for (eco.goal: the economy leans towards what it lacks, soldiers and research
## leave it alone): the next age once we have the workers for it, else the build step waiting
## on resources, else a Watchtower where we were raided.
func _goal(w, count: int) -> PackedInt32Array:
	_saving_age = false
	var next: Dictionary = Tech.next_age(w, player)
	var at: int = int(cfg.economy.age_workers) if w.ages[player] == 1 else age3_workers
	if not next.is_empty() and count >= at and not Tech.queued(w, player, Tech.AGE_UP):
		var cost: PackedInt32Array = next.cost.duplicate()
		for need in next.requires:   # and the building the age needs, if it isn't up or going up
			if not _has_any(w, need):
				var bc: PackedInt32Array = w.btypes[Economy.btype_of(w, need)].cost
				for r in cost.size():
					cost[r] += bc[r]
		_saving_age = true
		return cost
	if not _blocked.is_empty():
		return _blocked
	if _tower_at.x >= 0 and _towers_up(w) < towers:
		return w.btypes[Economy.btype_of(w, "watchtower")].cost
	return PackedInt32Array()


## A Wonder, when we're rich: from the age in data, with none of ours up or going up, once
## every stock is spare_pct percent of its cost. Laid by the Town Center, `builders` workers on it.
func _wonder(w, tc: int, workers: Array) -> void:
	var c: Dictionary = cfg.get("wonder", {})
	var k: int = Economy.btype_of(w, "wonder")
	if c.is_empty() or k < 0 or w.ages[player] < int(c.age) or w.tick < _next_build:
		return
	for b in w.buildings.count():
		if w.buildings.owner[b] == player and w.buildings.kind[b] == k:
			return
	var cost: PackedInt32Array = w.btypes[k].cost
	for r in cost.size():
		if w.stock[r][player] < cost[r] * int(c.spare_pct) / 100:
			return
	var spot: Vector2i = eco._house_spot(w, w.buildings.cx[tc] + 1, w.buildings.cy[tc] + 1, w.btypes[k].size)
	if spot.x < 0 or workers.is_empty():
		return
	var builders := workers.slice(0, int(c.builders)).map(func(i): return w.units.id[i])
	w.issue(player, Commands.BUILD, {"ids": builders, "building": "wonder", "cx": spot.x, "cy": spot.y})
	_next_build = w.tick + BUILD_COOLDOWN


## EcoBot takes us to age 2; past that, the bot ages up again once it has age3_workers (it
## saves for it from then: _goal, _train).
func _age_three(w, tc: int, count: int) -> void:
	if w.ages[player] != 2 or count < age3_workers:
		return
	if Tech.why_not(w, player, tc, "") == "":
		w.issue(player, Commands.AGE_UP, {"building": w.buildings.id[tc]})


# ------------------------------------------------------------------ soldiers

## Line upgrades, as a player would: each building upgrades the lines it trains once the
## age allows and there's enough to spare for a few soldiers too (twice the cost in stock).
## A building-up bot also researches gathering, and spends on it first (cost in stock is enough).
## Then the rest of the economy research (data: research.economy) and the soldiers' research
## (armoury tracks, drums, hay ...) for what it fields: research reaching at least
## research.army_min of its soldiers. Those two keep back what it saves for (_goal: the next
## age once the bot is big enough to age up, a build step), so they never hold those back.
func _upgrade_lines(w, army: Array) -> void:
	var fielded := {}   # unit type -> how many of our soldiers
	for i in army:
		fielded[w.units.kind[i]] = int(fielded.get(w.units.kind[i], 0)) + 1
	var keep := PackedInt32Array()
	keep.resize(w.resources.size())
	for r in eco.goal.size():
		keep[r] = eco.goal[r]
	for b in w.buildings.count():
		if w.buildings.owner[b] != player or w.buildings.queue[b].any(func(e): return e < 0):
			continue   # one research at a time per building, as before queues held research
		for r in w.tech.research:
			var gather: bool = r.effects.any(func(fx): return fx.has("gather"))
			var old: bool = r.has("line") or (build_up and gather)
			if not (old or r.id in cfg.research.economy or r.id in cfg.research.get("buildings", []) or _reach(w, r, fielded) >= int(cfg.research.army_min)) \
					or Tech.why_not(w, player, b, r.id) != "":
				continue
			var wait: String = cfg.research.get("wait_for", {}).get(r.id, "")
			if wait != "" and not Tech.has_building(w, player, wait):
				continue   # (the Bastion's stone waits for the Castle's)
			var spare := true
			for k in r.cost.size():
				if w.stock[k][player] < r.cost[k] * (1 if build_up else 2) + (0 if old else keep[k]):
					spare = false
			if spare:
				w.issue(player, Commands.RESEARCH, {"building": w.buildings.id[b], "id": r.id})
				break


## How many of our soldiers (unit type -> count) a research's unit effects reach.
func _reach(w, r: Dictionary, fielded: Dictionary) -> int:
	var n := 0
	for k in fielded:
		if r.effects.any(func(fx): return Tech.reaches(fx, w.types[k].eval.tags)):
			n += int(fielded[k])
	return n

func _train(w, workers: Array, count: int) -> void:
	var reserve := PackedInt32Array()
	reserve.resize(w.resources.size())
	var guard := 0   # keep a small guard even while saving for an age, like a sensible player
	for i in w.units.count():
		if w.units.owner[i] == player and not w.types[w.units.kind[i]].worker and not w.types[w.units.kind[i]].healer \
				and not w.types[w.units.kind[i]].has("animal"):
			guard += int(w.types[w.units.kind[i]].pop)
	# An easier bot keeps its army in proportion to its economy, growing with each age: it
	# builds up more and fights less, but never stops growing (Dominic: not caps).
	if army_ratio > 0 and guard * 100 >= count * army_ratio * w.ages[player]:
		return
	# Saving for something (the next age, a building): soldiers only from what's over, while
	# nobody is raiding us (an army first, then the age) and, from age 2, once there's a guard
	# (D-077: an age-up with nobody home invites a raid; age 1's guard trains while the age-up runs).
	if (guard >= int(cfg.military.guard) or w.ages[player] == 1) and _threats.is_empty():
		for r in eco.goal.size():
			reserve[r] = eco.goal[r]
	var foes := _enemy_tags(w)
	for b in w.buildings.count():
		if w.buildings.owner[b] != player or w.buildings.done[b] == 0 or Tech.head(w, b) != -1:
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


## Healers from the Town Center once the age allows: one for every `per_army` soldiers, up to
## the age's cap (data: military.healers), one at a time, when there's enough to spare beyond a worker.
func _train_healers(w, tc: int, army: Array, healers: Array) -> void:
	var h: Dictionary = cfg.military.get("healers", {})
	var k: int = w.type_of(player, "healer")
	if h.is_empty() or k < 0 or w.ages[player] < int(w.types[k].line[0].age):
		return
	var queued: int = w.buildings.queue[tc].count(k)
	var want: int = mini(int(h["max"].get(str(w.ages[player]), 0)), army.size() / maxi(1, int(h.per_army)))
	if queued > 0 or healers.size() >= want:
		return
	var worker: int = w.type_of(player, "worker")
	for r in w.resources.size():
		if w.stock[r][player] < w.types[k].cost[r] + w.types[worker].cost[r]:
			return
	w.issue(player, Commands.TRAIN, {"building": w.buildings.id[tc], "slot": "healer"})


## Healers follow the army, `behind` tiles back from its middle on the side towards home. Only
## idle ones (healing no one) more than `follow` tiles from that spot are sent: a healer at work
## stays with its patient, and one near the spot picks the wounded up on its own.
func _escort(w, army: Array, healers: Array, hx: int, hy: int) -> void:
	var h: Dictionary = cfg.military.get("healers", {})
	if healers.is_empty() or army.is_empty() or w.tick % (int(h.get("every", 3)) * 20) != THINK_EVERY / 2:
		return
	# The army that's out (beyond the home guard's reach); with none out, the healers stay home,
	# where the hurt come back to (and the workers are).
	var home_r := int(cfg.military.defend_tiles) * 1000
	var out := army.filter(func(i): return Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i]) > home_r * home_r)
	var mx := hx
	var my := hy
	if out.size() >= 2:
		var sx := 0
		var sy := 0
		for i in out:
			sx += w.units.x[i]
			sy += w.units.y[i]
		mx = sx / out.size()
		my = sy / out.size()
	var d := Fixed.isqrt(Fixed.dist2(mx, my, hx, hy))
	var back: int = mini(int(h.behind) * 1000, d)
	var tx: int = mx + (hx - mx) * back / maxi(1, d)
	var ty: int = my + (hy - my) * back / maxi(1, d)
	var follow: int = int(h.follow) * 1000
	var ids := []
	for i in healers:
		if w.units.patient[i] == 0 and Fixed.dist2(w.units.x[i], w.units.y[i], tx, ty) > follow * follow:
			ids.append(w.units.id[i])
	if not ids.is_empty():
		w.issue(player, Commands.ATTACK_MOVE, {"ids": ids, "x": tx, "y": ty})   # an attack-move: they stop for the wounded on the way


## How many enemy units we can see carry each tag (their army, not workers).
func _enemy_tags(w) -> Dictionary:
	var tags := {}
	for i in w.units.count():
		if not w.is_foe(player, w.units.owner[i]) or not Fog.visible(w, player, w.units.x[i], w.units.y[i]):
			continue
		var t: Dictionary = w.types[w.units.kind[i]]
		if t.worker or t.has("animal"):
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
		if not w.is_foe(player, w.units.owner[i]) or w.types[w.units.kind[i]].has("animal") or not Fog.visible(w, player, w.units.x[i], w.units.y[i]):
			continue   # (a rival's sheep wandering by is no intruder)
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
		var to := _reachable(w, Vector2i(w.units.x[intruder], w.units.y[intruder]))
		w.issue(player, Commands.ATTACK_MOVE, {"ids": ids, "x": to.x, "y": to.y})


## Remember every enemy blow on our buildings and workers, wherever they are (a player hears
## the alarm; the bot reads the hits). Soldiers hit in a fight fight back on their own.
func _note_hits(w) -> void:
	for e in w.events:
		if e.type != "hit":
			continue
		var vi: int = w.units.index_of(e.to)
		if vi >= 0:
			if w.units.owner[vi] != player or not w.types[w.units.kind[vi]].worker:
				continue
		else:
			var vb: int = w.buildings.index_of(e.to)
			if vb < 0 or w.buildings.owner[vb] != player:
				continue
		var ai: int = w.units.index_of(e.by)
		var ab: int = w.buildings.index_of(e.by) if ai < 0 else -1
		var by: int = w.units.owner[ai] if ai >= 0 else (w.buildings.owner[ab] if ab >= 0 else -1)
		if by >= 0 and w.is_foe(player, by):
			_threats[e.by] = w.tick


## Where an enemy unit or building is (a building's middle), or (-1, -1) if it's gone.
func _where(w, id: int) -> Vector2i:
	var i: int = w.units.index_of(id)
	if i >= 0:
		return Vector2i(w.units.x[i], w.units.y[i])
	var b: int = w.buildings.index_of(id)
	if b >= 0:
		return Vector2i(w.buildings.cx[b] * 1000 + w.buildings.sx[b] * 500, w.buildings.cy[b] * 1000 + w.buildings.sy[b] * 500)
	return Vector2i(-1, -1)


## Answer raids anywhere: the latest one (its attackers within TROUBLE_TILES of the last blow)
## gets soldiers, nearest first, until they're twice the raiders' population (those already on
## their way count); soldiers fighting other soldiers stay in their fight, and ones far out on
## an attack keep to it. Workers near the raiders go to the Town Center (behind it, if the raid
## is there) and are kept from work until things are quiet. Once quiet, the soldiers sent go home.
func _respond(w, tc: int, army: Array, workers: Array, hx: int, hy: int) -> void:
	var ids: Array = _threats.keys()
	ids.sort()
	var live := []
	for id in ids:
		if w.tick - int(_threats[id]) > THREAT_TICKS or _where(w, id).x < 0:
			_threats.erase(id)
		else:
			live.append(id)
	if live.is_empty():
		_send_home(w, hx, hy)
		if _sheltering:   # quiet again: everyone out and back to what they were gathering
			w.issue(player, Commands.BACK_TO_WORK, {})
			_sheltering = false
		return
	var focus: int = live[0]
	for id in live:
		if int(_threats[id]) > int(_threats[focus]):
			focus = id
	var f := _where(w, focus)
	var raiders := []
	var strength := 0
	for id in live:
		var at := _where(w, id)
		if Fixed.dist2(at.x, at.y, f.x, f.y) > TROUBLE_TILES * TROUBLE_TILES * 1000000:
			continue
		raiders.append(at)
		var i: int = w.units.index_of(id)
		strength += int(w.types[w.units.kind[i]].pop) if i >= 0 else 4   # a tower counts like a few
	var d := Fixed.isqrt(Fixed.dist2(f.x, f.y, hx, hy))
	# A raid on the outskirts (a camp, workers at a far patch): a tower goes up there once it's quiet.
	var tw: Dictionary = cfg.military.get("towers", {})
	if not tw.is_empty() and w.ages[player] >= int(tw.age) and d > (FLEE_TILES + 2) * 1000 and d <= int(tw.within) * 1000:
		_tower_at = f
	# A big raid by the Town Center that the soldiers at home can't answer: call to arms.
	if shelter_pop > 0 and not _sheltering and strength >= shelter_pop and d <= int(cfg.military.shelter.tiles) * 1000:
		var home_pop := 0
		var home_r := 2 * int(cfg.military.defend_tiles) * 1000
		for i in army:
			if Fixed.dist2(w.units.x[i], w.units.y[i], hx, hy) <= home_r * home_r:
				home_pop += int(w.types[w.units.kind[i]].pop)
		if home_pop < strength:
			w.issue(player, Commands.CALL_TO_ARMS, {"building": w.buildings.id[tc]})
			_sheltering = true
	# Workers out of the way.
	var to := Vector2i(hx, hy)
	if d <= (FLEE_TILES + 2) * 1000:   # at the Town Center itself: behind it, away from them
		to = _reachable(w, Vector2i(clampi(hx + (hx - f.x) * 6000 / maxi(d, 1), 0, w.map.width * 1000 - 1),
			clampi(hy + (hy - f.y) * 6000 / maxi(d, 1), 0, w.map.height * 1000 - 1)))
	var flee := []
	var call: int = int(w.garrison_cfg.call_range) * 1000 - 1500   # (from the Town Center's middle, roughly)
	for i in workers:
		var uid: int = w.units.id[i]
		if not raiders.any(func(at): return Fixed.dist2(at.x, at.y, w.units.x[i], w.units.y[i]) <= FLEE_TILES * FLEE_TILES * 1000000):
			continue
		if _sheltering and (w.units.task[i] == Economy.GARRISON or Fixed.dist2(w.units.x[i], w.units.y[i], hx, hy) <= call * call):
			eco.held[uid] = w.tick + THREAT_TICKS
			continue   # on its way inside (or about to be)
		if int(eco.held.get(uid, 0)) <= w.tick or w.units.moving[i] == 0:
			flee.append(uid)
		eco.held[uid] = w.tick + THREAT_TICKS
	if not flee.is_empty():
		w.issue(player, Commands.MOVE, {"ids": flee, "x": to.x, "y": to.y})
	# Soldiers to the raid.
	var home_r := 2 * int(cfg.military.defend_tiles) * 1000
	var cands := []
	for i in army:
		if w.units.foe[i] != 0 and w.units.index_of(w.units.foe[i]) >= 0:
			continue   # fighting someone already
		var d2 := Fixed.dist2(w.units.x[i], w.units.y[i], f.x, f.y)
		if Fixed.dist2(w.units.x[i], w.units.y[i], hx, hy) > home_r * home_r and d2 > RESPOND_TILES * RESPOND_TILES * 1000000:
			continue
		cands.append([d2, w.units.id[i], int(w.types[w.units.kind[i]].pop)])
	cands.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var need := 2 * strength + 2
	var got := 0
	var go := []
	for c in cands:
		if got >= need:
			break
		got += c[2]
		if int(_sent.get(c[1], -RESEND)) + RESEND > w.tick:
			continue   # on its way already
		go.append(c[1])
		_sent[c[1]] = w.tick
	if not go.is_empty():
		var at := _reachable(w, f)
		w.issue(player, Commands.ATTACK_MOVE, {"ids": go, "x": at.x, "y": at.y})


## A Watchtower where we were raided (data: military.towers), once it's quiet, up to the level's
## `towers` (the build order's one counts), with the two workers nearest.
func _tower(w, workers: Array) -> void:
	if _tower_at.x < 0 or not _threats.is_empty() or w.tick < _next_build:
		return
	if _towers_up(w) >= towers:
		_tower_at = Vector2i(-1, -1)
		return
	var k: int = Economy.btype_of(w, "watchtower")
	if eco._building_underway(w) or not w.can_afford(player, w.btypes[k].cost) or workers.is_empty():
		return
	var spot: Vector2i = eco._house_spot(w, _tower_at.x / 1000, _tower_at.y / 1000, w.btypes[k].size)
	_tower_at = Vector2i(-1, -1)
	if spot.x < 0:
		return
	var builders := _nearest_workers(w, workers, spot.x * 1000, spot.y * 1000, 2)
	w.issue(player, Commands.BUILD, {"ids": builders, "building": "watchtower", "cx": spot.x, "cy": spot.y})
	_next_build = w.tick + BUILD_COOLDOWN


## Quiet again: soldiers sent to a raid, standing about far from home with nothing to fight, walk
## back (attack-moving) unless an attack wave is out (that pushes them on instead).
func _send_home(w, hx: int, hy: int) -> void:
	if _sent.is_empty():
		return
	var ids: Array = _sent.keys()
	ids.sort()
	_sent.clear()
	if assault:
		return
	var home_r := 2 * int(cfg.military.defend_tiles) * 1000
	var back := []
	for id in ids:
		var i: int = w.units.index_of(id)
		if i >= 0 and w.units.foe[i] == 0 and w.units.moving[i] == 0 and Fixed.dist2(w.units.x[i], w.units.y[i], hx, hy) > home_r * home_r:
			back.append(id)
	if not back.is_empty():
		w.issue(player, Commands.ATTACK_MOVE, {"ids": back, "x": hx, "y": hy})


## The enemy is out of reach: the middle of the enemy building on the edge of our area (a wall
## across a ford, a gate) that's least out of the way from home to `target`, or `target` if
## there's none. The bot knows the map's crossings as a player knows the map: it goes to knock
## on the wall that shuts one, even before it has seen it.
func _blocker(w, hx: int, hy: int, target: Vector2i) -> Vector2i:
	var bs = w.buildings
	var best := target
	var best_d := 1 << 62
	for b in bs.count():
		if not w.is_enemy(player, bs.owner[b]) or not eco.reach.reaches_building(w, _aln, _harea, b):
			continue
		var x: int = bs.cx[b] * 1000 + bs.sx[b] * 500
		var y: int = bs.cy[b] * 1000 + bs.sy[b] * 500
		var d: int = Fixed.isqrt(Fixed.dist2(hx, hy, x, y)) + Fixed.isqrt(Fixed.dist2(x, y, target.x, target.y))
		if d < best_d:
			best_d = d
			best = Vector2i(x, y)
	return best


## A point our soldiers can get to: the point itself if it's in our area, else the nearest
## spot of our area to it (the near bank of a river whose fords are walled off).
func _reachable(w, at: Vector2i) -> Vector2i:
	if _harea == 0 or eco.reach.labels(w, _aln)[w.map.cell_of(at.x, at.y)] == _harea:
		return at   # (on its own cell: a point on a wall would snap to whichever side is nearer)
	var near: Vector2i = eco.reach.nearest_in(w, _aln, _harea, at.x, at.y)
	return near if near.x >= 0 else at


func _waves(w, army: Array, hx: int, hy: int) -> void:
	var m: Dictionary = cfg.military
	var wonder := _known_enemy_wonder(w, hx, hy)
	var target := _enemy_target(w, hx, hy)
	if target.x < 0:
		return
	if _harea != 0 and eco.reach.area_at(w, _aln, target.x, target.y) != _harea:
		target = _blocker(w, hx, hy, target)
	target = _reachable(w, target)
	var waves: Array = m.waves
	var need: int = int(waves[wave].min_army) if wave < waves.size() else _repeat_min(w)
	var strength := 0   # army size in population, so big units count for what they cost
	for i in army:
		strength += int(w.types[w.units.kind[i]].pop)
	# A finished enemy Wonder can't wait for the next wave: everyone goes now (again every
	# regroup while it stands), however few.
	var urgent: bool = wonder > 0 and w.wonder_ids.has(wonder) and w.tick - _rushed >= int(m.regroup_every) * 20 and strength > 0
	if urgent:
		_rushed = w.tick
	if (w.tick >= next_wave_tick and strength >= need) or urgent:
		# An easier bot sends part, the rest defend: those already out go on, and from home all
		# but a guard of the rest of the army (newest stay).
		var near := int(m.defend_tiles) * 2000
		var away := army.filter(func(i): return Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i]) > near * near)
		var at_home := army.filter(func(i): return Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i]) <= near * near)
		var keep: int = army.size() - maxi(1, army.size() * wave_pct / 100)
		var sent: Array = away + at_home.slice(0, maxi(0, at_home.size() - keep))
		if not sent.is_empty():
			w.issue(player, Commands.ATTACK_MOVE, {"ids": sent.map(func(i): return w.units.id[i]), "x": target.x, "y": target.y})
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
	if home.size() >= REINFORCE and wave_pct >= 100:   # (a partial wave's home guard stays home)
		ids.append_array(home.map(func(i): return w.units.id[i]))
	for i in army:
		var on_building: bool = w.units.foe[i] != 0 and w.buildings.index_of(w.units.foe[i]) >= 0
		var free: bool = (w.units.foe[i] == 0 and w.units.moving[i] == 0) or on_building
		if free and Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i]) > 4 * home_r * home_r:
			ids.append(w.units.id[i])
	if ids.is_empty():
		return
	# What's left out there is a trickle (under half a wave): it comes home to join the next wave
	# instead of walking into the Town Center's arrows one by one.
	var out_pop := 0
	for i in army:
		if Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i]) > 4 * home_r * home_r:
			out_pop += int(w.types[w.units.kind[i]].pop)
	if out_pop * 2 < need and wonder <= 0:
		var back := ids.filter(func(id): return Fixed.dist2(hx, hy, w.units.x[w.units.index_of(id)], w.units.y[w.units.index_of(id)]) > 4 * home_r * home_r)
		if not back.is_empty():
			w.issue(player, Commands.ATTACK_MOVE, {"ids": back, "x": hx, "y": hy})
		return
	# With the field clear, go for the Town Center itself (that ends the match) rather than
	# chewing through every house on the way.
	var tc_id := wonder if wonder > 0 else _known_enemy_town(w, hx, hy)   # (a Wonder first)
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
	var x: int = bs.cx[b] * 1000 + bs.sx[b] * 500
	var y: int = bs.cy[b] * 1000 + bs.sy[b] * 500
	var r := int(cfg.military.defend_tiles) * 1000
	var n := 0
	for i in w.units.count():
		if w.is_foe(player, w.units.owner[i]) and not w.types[w.units.kind[i]].worker and not w.types[w.units.kind[i]].has("animal") \
				and not w.types[w.units.kind[i]].healer and Fog.visible(w, player, w.units.x[i], w.units.y[i]) and Fixed.dist2(x, y, w.units.x[i], w.units.y[i]) < r * r:
			n += 1
	return n


## Whether we know of this enemy Wonder: seen, or finished (everyone hears of that).
func _knows_wonder(w, b: int) -> bool:
	var bs = w.buildings
	return w.wonder_ids.has(bs.id[b]) or Fog.explored(w, player, bs.cx[b], bs.cy[b])


## The id of the nearest enemy Wonder we know of and can get to, finished ones first, or 0.
func _known_enemy_wonder(w, hx: int, hy: int) -> int:
	var wk: int = Economy.btype_of(w, "wonder")
	var bs = w.buildings
	var best := 0
	var best_key := 1 << 62
	for b in bs.count():
		if wk < 0 or bs.kind[b] != wk or not w.is_enemy(player, bs.owner[b]) or not _knows_wonder(w, b) \
				or not eco.reach.reaches_building(w, _aln, _harea, b):
			continue
		var key: int = Fixed.dist2(hx, hy, bs.cx[b] * 1000, bs.cy[b] * 1000) / 1000 + (0 if bs.done[b] == 1 else (1 << 40))
		if key < best_key:
			best_key = key
			best = bs.id[b]
	return best


## The id of the nearest enemy Town Center we've seen, or 0.
func _known_enemy_town(w, hx: int, hy: int) -> int:
	var tc_kind: int = Economy.btype_of(w, "town_center")
	var bs = w.buildings
	var best := 0
	var best_d2 := 1 << 62
	for b in bs.count():
		if bs.kind[b] != tc_kind or not w.is_enemy(player, bs.owner[b]) or not Fog.explored(w, player, bs.cx[b], bs.cy[b]) \
				or not eco.reach.reaches_building(w, _aln, _harea, b):
			continue   # (one across a walled ford isn't marched on directly)
		var d2 := Fixed.dist2(hx, hy, bs.cx[b] * 1000, bs.cy[b] * 1000)
		if d2 < best_d2:
			best_d2 = d2
			best = bs.id[b]
	return best


## Where to attack: the nearest enemy Town Center we've seen, else the nearest enemy building
## we've seen, else an enemy's starting spot (every player knows where the others start). Ones
## our soldiers can get to come first: with the Town Center behind a walled ford, the wall we've
## seen there is the target (it comes down, then the way is open). With nothing in reach, the
## caller marches to the nearest bank (_reachable).
func _enemy_target(w, hx: int, hy: int) -> Vector2i:
	var tc_kind: int = Economy.btype_of(w, "town_center")
	var wk: int = Economy.btype_of(w, "wonder")
	var best := Vector2i(-1, -1)
	var best_d2 := 1 << 62
	var best_rank := -1   # 2: a Wonder, 1: a Town Center, 0: anything else
	var best_ok := false
	for b in w.buildings.count():
		var bs = w.buildings
		var wonder: bool = bs.kind[b] == wk
		if not w.is_enemy(player, bs.owner[b]) or not (Fog.explored(w, player, bs.cx[b], bs.cy[b]) or (wonder and _knows_wonder(w, b))):
			continue
		var x: int = bs.cx[b] * 1000 + bs.sx[b] * 500
		var y: int = bs.cy[b] * 1000 + bs.sy[b] * 500
		var rank: int = 2 if wonder else (1 if bs.kind[b] == tc_kind else 0)
		var ok: bool = eco.reach.reaches_building(w, _aln, _harea, b)
		var d2 := Fixed.dist2(hx, hy, x, y)
		if (ok and not best_ok) or (ok == best_ok and (rank > best_rank or (rank == best_rank and d2 < best_d2))):
			best = Vector2i(x, y)
			best_d2 = d2
			best_rank = rank
			best_ok = ok
	if best.x < 0:
		for p in w.races.size():
			if w.is_enemy(player, p) and w.defeated[p] == 0 and p < w.map.starts.size():
				return Vector2i(int(w.map.starts[p][0]), int(w.map.starts[p][1]))
	return best
