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
##   first target of every attack, a finished one (its countdown running) attacked at once;
## - a plan for the ages (milestone 12 phase 8): what it saves for (_goal: the next age with the
##   building it needs, else the build step waiting on resources) steers the economy's shares
##   (EcoBot.shares, a gatherer moved at a time) and holds back soldiers and research;
## - a Watchtower where it was raided, a call to arms for a big raid on the Town Center (for a
##   while, then back to work), and per level (data: levels) how hard it builds up and fights;
## - the land (milestone 15 phase 7): a scout early and now and then, and a memory of the enemy
##   army it saw (src/ai/scout.gd); routes, crossings, roads through thin woods, bridges mended
##   and broken, hills held, amphibious flanks (src/ai/land.gd); camps that follow the workers,
##   escorts for far gatherers and an earlier second Town Center on big maps (src/ai/expand.gd);
##   a level that raids (data: levels.raids) goes for the economy outside tower range first,
##   in several groups.
## Like EcoBot it only reads sim state and issues commands, so it's deterministic.

const EcoBot := preload("res://src/ai/eco_bot.gd")
const Economy := preload("res://src/sim/economy.gd")
const Commands := preload("res://src/sim/commands.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const Tech := preload("res://src/sim/tech.gd")
const Fog := preload("res://src/sim/fog.gd")
const Scout := preload("res://src/ai/scout.gd")
const Land := preload("res://src/ai/land.gd")
const Expand := preload("res://src/ai/expand.gd")
const Trade := preload("res://src/sim/trade.gd")
const AbilityAi := preload("res://src/ai/ability_ai.gd")
const WallsAi := preload("res://src/ai/walls_ai.gd")

const THINK_EVERY := 20     # ticks (1 s), offset from EcoBot's think by half a second (and per player: _phase)
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
var _blocked_save := 0       # ... a step's `save`: 1 (the University, the Castle) a building-up bot's soldiers wait for it; 2 (the market) everyone's
var _blocked_push := 0       # ... and how hard the economy leans to it (a step's `push`, else economy.build_push)
var _tower_at := Vector2i(-1, -1)    # where a raid was: a Watchtower goes up there once it's quiet
var _sheltering := false     # our workers were called to arms
var _shelter_until := 0      # ... and come out by this tick
var _shelter_next := 0       # no call to arms again before this tick
var _saving_age := false     # the goal is the next age (the economy leans on it hard)
var _aim := 0                # the enemy building the army goes straight for when it knows no Town Center to: the one it marches on, or the wall piece shutting the way (_blocker); 0 for a start spot
var scout                    # Scout: tours and the memory of the enemy army
var land                     # Land: routes, crossings, roads, bridges, hills
var expand                   # Expand: camps, escorts, the second Town Center
var _target := Vector2i(-1, -1)   # where the waves go (worked out every think)
var _on_back_foot := false   # the enemy army we remember outnumbers ours (Land._defending): defend the crossing


## config: data/ai.json as ints (see load_config), or {} to load it. level: a key of
## its "levels" (easy, normal, hard): how it plays (see "levels" there).
var army_ratio := 0   # soldiers kept per age as a percent of workers (0: no limit); grows with the ages
var wave_pct := 100   # the share of the army each wave sends; the rest defend
var build_up := false # economy and upgrades come before soldiers
var age3_workers := 26   # workers before it saves for age 3
var towers := 0       # Watchtowers it raises where it was raided
var all_in := 0       # an army this big (population) goes out whole, home guard and all (0: never)
var shelter_pop := 0  # a raid this big (enemy population) by the Town Center calls the workers to arms (0: never)
var guard_crossing := false   # a Watchtower on the key crossing (Land.guard_spot) from age 2
var raids := 0        # attack in this many groups, at the enemy's economy outside tower range first (0: the old way)
var raid_from := 0    # ... from this tick on


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
		all_in = int(l.get("all_in", 0))
		guard_crossing = int(l.get("guard_crossing", 0)) == 1
		raids = int(l.get("raids", 0))
		raid_from = int(l.get("raid_from", 0)) * 20
	eco = EcoBot.new(p_player)
	scout = Scout.new(cfg.scout)
	land = Land.new(cfg.land)
	expand = Expand.new(cfg.expand)
	eco.MIX = {}
	for age in cfg.economy.mix:
		eco.MIX[int(age)] = cfg.economy.mix[age]
	eco.MAX_WORKERS = _max_workers(1)
	eco.AGE_WORKERS = int(cfg.economy.age_workers)
	eco.REBALANCE = int(cfg.economy.get("rebalance_every", 0)) * 20
	eco.PLENTY = int(cfg.economy.get("plenty", eco.PLENTY))
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


## The tick of each second this bot thinks on: half a second after its economy, players one after
## another (EcoBot.STAGGER), so four bots don't all think on one tick.
func _phase() -> int:
	return (THINK_EVERY / 2 + eco.phase()) % THINK_EVERY


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
	scout.forget_dead(w)
	eco.MAX_WORKERS = _max_workers(w.ages[player])
	eco.think(w)
	if w.tick % THINK_EVERY != _phase():
		return
	var tc: int = eco._town_center(w)
	if tc < 0:
		WallsAi.besiege(w, self)   # no town (the Siege mode's attackers): all on the attack
		return
	var workers := []
	var army := []
	var healers := []
	var carts := []
	var scouts := 0   # scout-line units we have: the bot keeps military.scouts.keep (Scout tours with one)
	for i in w.units.count():
		if w.units.owner[i] != player:
			continue
		var t: Dictionary = w.types[w.units.kind[i]]
		if t.worker:
			workers.append(i)
		elif t.healer:
			healers.append(i)
		elif t.get("trader", false):
			carts.append(i)   # trade carts aren't soldiers (_trade_carts)
		elif not t.has("animal"):   # our sheep aren't soldiers
			army.append(i)
			if t.slot == "scout":
				scouts += 1
	var count: int = workers.size() + eco.sheltered(w)
	_build_order(w, tc, workers, count)
	eco.goal = _goal(w, count)
	eco.push = 100 if _saving_age else (_blocked_push if not _blocked.is_empty() else int(cfg.economy.get("build_push", 30)))   # (a building leans gently, unless its step says otherwise)
	_age_three(w, tc, count)
	_wonder(w, tc, workers)
	_upgrade_lines(w, army)
	_train_scout(w, scouts)
	_train(w, workers, count)
	_train_healers(w, tc, army, healers)
	var home_x: int = w.buildings.cx[tc] * 1000 + 1500
	var home_y: int = w.buildings.cy[tc] * 1000 + 1500
	_aln = w.lane(army[0]) if not army.is_empty() else w.lane_base[player] + _army_class(w)
	_harea = eco.reach.area_at(w, _aln, home_x, home_y)
	# The field army: not the scout out on its tour, not the escorts posted with far gatherers.
	var field := army.filter(func(i): return w.units.id[i] != scout.id and not expand.escorts.has(w.units.id[i]) and not land.breaking(w, i))
	var at_work := workers.filter(func(i): return w.units.id[i] != scout.id)
	scout.remember(w, player)
	_on_back_foot = _on_back_foot or land._defending(w, self, field)   # (once guarded, the step stays wanted)
	scout.think(w, self, at_work, field, home_x, home_y)
	_target = _wave_target(w, home_x, home_y)
	land.target = _target
	land.think(w, self, at_work, field, home_x, home_y)
	expand.think(w, self, tc, at_work, field, home_x, home_y)
	_defend(w, field, home_x, home_y)
	WallsAi.man(w, self, field, home_x, home_y)
	_respond(w, tc, army.filter(func(i): return w.units.id[i] != scout.id), at_work, home_x, home_y)
	_tower(w, at_work)
	_trade(w)
	_trade_carts(w, carts, at_work)
	_waves(w, field, home_x, home_y)
	_off_walls(w, field, home_x, home_y)
	_siege(w, field, home_x, home_y)
	WallsAi.storm(w, self, field, _target)
	_escort(w, field, healers, home_x, home_y)
	AbilityAi.think(w, player, army)   # the race's ability (spiders' webs), milestone 14


## Our soldiers' movement class (the spear's), for routes before there's an army.
func _army_class(w) -> int:
	var k: int = w.type_of(player, "spear")
	return w.types[k].mclass if k >= 0 else 0


# ------------------------------------------------------------------ buildings

func _build_order(w, tc: int, workers: Array, count: int) -> void:
	if w.tick < _next_build or eco._building_underway(w, false):
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
		if Economy.lacks(w, player, id):
			continue   # not in our race's tree (spiders have no Stable): the order goes on without it
		wanted[id] = int(step.get("count", wanted.get(id, 0) + 1))
		if have.get(id, 0) >= wanted[id]:
			continue
		if w.ages[player] < int(step.get("age", 1)):
			continue   # a later age's step (the University, the Castle) doesn't hold up this age's
		if int(step.get("guard", 0)) == 1 and not (guard_crossing and _on_back_foot):
			continue   # (a step for the levels that guard their crossing, when they're on the back foot)
		var need := int(step.workers)
		if step.has("expand_workers") and expand.wants_town(w, w.buildings.cx[tc] * 1000 + 1500, w.buildings.cy[tc] * 1000 + 1500):
			need = int(step.expand_workers)   # (a big map, or home running thin: reach out sooner)
		if count < need or workers.is_empty():
			return   # the order is an order: wait for this step before the next
		var k: int = Economy.btype_of(w, id)
		if not w.can_afford(player, Economy.bcost(w, player, k)):
			_blocked = Economy.bcost(w, player, k)   # what we save for (economy shares; soldiers leave it alone if the step says `save`)
			_blocked_save = int(step.get("save", 0))
			_blocked_push = int(step.get("push", cfg.economy.get("build_push", 30)))
			return
		var at := Vector2i(w.buildings.cx[tc] + 1, w.buildings.cy[tc] + 1)
		if step.has("near"):   # a drop-off camp goes by the nearest patch of its resource
			var cell: int = _patch(w, at, w.resources.find(step.near) + 1, int(step.get("away", 0)), int(step.get("own_side", 0)) == 1)
			if cell >= 0:
				at = Vector2i(cell % w.map.width, cell / w.map.width)
		var spot: Vector2i = eco._house_spot(w, at.x, at.y, w.btypes[k].size)
		var guard: Vector2i = land.guard_spot(w, self) if guard_crossing and int(step.get("guard", 0)) == 1 else Vector2i(-1, -1)
		if guard.x >= 0:   # a guarding level puts this tower on the key crossing (Land), if there's room
			var by: Vector2i = _spot_near(w, guard, w.btypes[k].size, int(cfg.land.guard_tiles) - 1)
			if by.x >= 0:
				spot = by
				land.count("guard")
		if spot.x < 0:
			return
		var builders := _nearest_workers(w, workers, spot.x * 1000, spot.y * 1000, int(step.get("builders", 2)))
		w.issue(player, Commands.BUILD, {"ids": builders, "building": id, "cx": spot.x, "cy": spot.y})
		_next_build = w.tick + BUILD_COOLDOWN
		return


## The nearest free spot for a size x size building within r tiles of `at` (rings out from it) that
## our workers can get to and that seals nothing in (a tower by a ford in the woods: the house
## spot's margins off resources find nothing there), two tiles off the cells of `avoid`; or (-1, -1).
func _spot_near(w, at: Vector2i, size: int, r: int, avoid := PackedInt32Array()) -> Vector2i:
	for d in r + 1:
		for dy in range(-d, d + 1):
			for dx in range(-d, d + 1):
				if maxi(absi(dx), absi(dy)) != d:
					continue
				var x: int = at.x + dx
				var y: int = at.y + dy
				if Array(avoid).any(func(c): return c % w.map.width >= x - 2 and c % w.map.width <= x + size + 1 and c / w.map.width >= y - 2 and c / w.map.width <= y + size + 1):
					continue   # (keep two tiles off these: a camp by a road mustn't shut the road)
				if w.map.can_build(x, y, size) and eco.reach.touches(w, eco.wln, eco.home, x, y, size, size) and not eco._seals(w, x, y, size):
					return Vector2i(x, y)
	return Vector2i(-1, -1)


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
## `own_side`: only patches nearer us than any enemy start (by a fifth): ground we can hold.
func _patch(w, at: Vector2i, kind: int, away: int, own_side := false) -> int:
	if away <= 0:
		return eco._nearest_resource(w, at.x * 1000, at.y * 1000, kind)
	var best := -1
	var best_d2 := 1 << 62
	for c in w.map.resource_cells:
		if w.map.amount[c] <= 0 or Economy.kind_of(w, w.map.resource_at(c)) != kind:
			continue
		var d2 := Fixed.dist2(at.x, at.y, c % w.map.width, c / w.map.width)
		if own_side and not _ours(w, at, c):
			continue
		if d2 >= away * away and d2 < best_d2 and eco.reach.reaches_cell(w, eco.wln, eco.home, c):
			best_d2 = d2
			best = c
	return best


## Is this cell on our side: nearer `at` (our Town Center, in tiles) than any live enemy's start, by a fifth?
func _ours(w, at: Vector2i, c: int) -> bool:
	var x: int = c % w.map.width
	var y: int = c / w.map.width
	var mine := Fixed.dist2(at.x, at.y, x, y)
	for p in w.races.size():
		if w.is_enemy(player, p) and w.defeated[p] == 0 and p < w.map.starts.size():
			var theirs := Fixed.dist2(int(w.map.starts[p][0]) / 1000, int(w.map.starts[p][1]) / 1000, x, y)
			if mine * 144 > theirs * 100:   # (distances squared: 1.2 squared)
				return false
	return true


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
		for need in Tech.requires(w, player, next):   # and the building the age needs, if it isn't up or going up
			if not _has_any(w, need):
				var bc: PackedInt32Array = Economy.bcost(w, player, Economy.btype_of(w, need))
				for r in cost.size():
					cost[r] += bc[r]
		_saving_age = true
		return cost
	if not _blocked.is_empty():
		return _blocked
	if _tower_at.x >= 0 and _towers_up(w) < towers:
		return Economy.bcost(w, player, Economy.btype_of(w, "watchtower"))
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
	var cost: PackedInt32Array = Economy.bcost(w, player, k)
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
## age allows (its cost in stock: a better kit beats more of the old one).
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
	var wanted := []   # [research, old]: what we'd research, in data order (worked out once, not per building)
	for r in w.tech.research:
		var gather: bool = r.effects.any(func(fx): return fx.has("gather"))
		var old: bool = r.has("line") or (build_up and gather)
		var wait: String = cfg.research.get("wait_for", {}).get(r.id, "")
		if wait != "" and not Tech.has_building(w, player, wait):
			continue   # (the Bastion's stone waits for the Castle's)
		if old or r.id in cfg.research.economy or r.id in cfg.research.get("buildings", []) or _reach(w, r, fielded) >= int(cfg.research.army_min):
			wanted.append([r, old])
	for b in w.buildings.count():
		if w.buildings.owner[b] != player or w.buildings.queue[b].any(func(e): return e < 0):
			continue   # one research at a time per building, as before queues held research
		var bt: String = w.btypes[w.buildings.kind[b]].id
		for e in wanted:
			var r: Dictionary = e[0]
			var old: bool = e[1]
			if r.building != bt or Tech.why_not(w, player, b, r.id) != "":
				continue   # (researched elsewhere: why_not would say "not here")
			var spare := true
			for k in r.cost.size():
				if w.stock[k][player] < r.cost[k] * (1 if build_up or r.has("line") else 2) + (0 if old else keep[k]):
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
				and not w.types[w.units.kind[i]].has("animal") and not w.types[w.units.kind[i]].get("trader", false):
			guard += int(w.types[w.units.kind[i]].pop)
	# An easier bot keeps its army in proportion to its economy, growing with each age: it
	# builds up more and fights less, but never stops growing (Dominic: not caps).
	if army_ratio > 0 and guard * 100 >= count * army_ratio * w.ages[player]:
		return
	# Saving for the next age (and, building up, for a University or Castle: steps marked `save`): soldiers only from
	# what's over, while nobody is raiding us (an army first, then the age) and, from age 2, once
	# there's a guard (D-077: an age-up with nobody home invites a raid; age 1's guard trains while
	# the age-up runs).
	if (_saving_age or (((build_up and _blocked_save >= 1) or _blocked_save >= 2) and eco.goal == _blocked)) and (guard >= int(cfg.military.guard) or w.ages[player] == 1) and _threats.is_empty():
		for r in eco.goal.size():
			reserve[r] = eco.goal[r]
	for r in expand.want.size():   # a camp the far gatherers need comes before another soldier
		reserve[r] += expand.want[r]
	for r in land.want.size():     # ... and the road's
		reserve[r] += land.want[r]
	var foes := _enemy_tags(w)
	for b in w.buildings.count():
		if w.buildings.owner[b] != player or w.buildings.done[b] == 0 or Tech.head(w, b) != -1:
			continue
		var bt: Dictionary = w.btypes[w.buildings.kind[b]]
		if bt.trains.is_empty() or "worker" in bt.trains or w.buildings.queue[b].size() >= int(cfg.military.queue):
			continue
		var best := pick(w, bt.trains, foes, reserve)   # (the best counter we can pay for now)
		if best != "":
			w.issue(player, Commands.TRAIN, {"building": w.buildings.id[b], "slot": best})


## A line the bot keeps only a few of (data: military.siege.max: a few engines) and has them all,
## out or queued.
func _enough(w, slot: String, k: int) -> bool:
	var most: Dictionary = cfg.military.get("siege", {}).get("max", {})
	return most.has(slot) and _fielded(w, k) >= int(most[slot])


## How many of unit type k we have, out and queued.
func _fielded(w, k: int) -> int:
	var n := 0
	for i in w.units.count():
		if w.units.owner[i] == player and w.units.kind[i] == k:
			n += 1
	for b in w.buildings.count():
		if w.buildings.owner[b] == player:
			n += w.buildings.queue[b].count(k)
	return n


## Engines go round: the one we have fewest of next, ties in military.siege.max's order (a ram
## first: it's what opens a walled town). Below its max an engine comes before a soldier trained in
## the same building (the Castle's sapper and great sling before more unique units).
func _siege_score(w, slot: String, k: int) -> int:
	return 1000 - _fielded(w, k) * 100 - cfg.military.siege.max.keys().find(slot)


## Engines on the regroup beat, while attacking: rams go for the nearest enemy gate, wall or tower
## they can see (any building if none), catapults for a tower within reach of a short walk
## (military.siege.towers_within), else they keep with the army's attack-move. Only engines not
## already hitting a building are told; idle rams with nothing in sight march on the army's target.
func _siege(w, army: Array, hx: int, hy: int) -> void:
	var s: Dictionary = cfg.military.get("siege", {})
	if s.is_empty() or not assault or w.tick % (int(cfg.military.regroup_every) * 20) != _phase():
		return
	var orders := {}   # target id -> engine ids
	var march := []    # rams with nothing to hit in sight
	for i in army:
		var t: Dictionary = w.types[w.units.kind[i]]
		var ram: bool = t.get("buildings_only", false)
		var thrower: bool = t.get("splash", 0) > 0
		if not (ram or thrower) or (w.units.foe[i] != 0 and w.buildings.index_of(w.units.foe[i]) >= 0):
			continue
		var best := 0
		var best_d := (int(s.towers_within) * 1000) * (int(s.towers_within) * 1000) if thrower else 1 << 60
		var best_rank := 2
		for b in w.buildings.count():
			if not w.is_enemy(player, w.buildings.owner[b]) or not Fog.sees_area(w, player, w.buildings.cx[b], w.buildings.cy[b], w.buildings.sx[b], w.buildings.sy[b]):
				continue
			var bt: Dictionary = w.btypes[w.buildings.kind[b]]
			var defence: bool = not bt.attack.is_empty() or bt.gate or bt.line
			if thrower and bt.attack.is_empty():
				continue   # catapults: towers and castles only
			var rank := 0 if defence else 1
			var d := Fixed.dist2(w.units.x[i], w.units.y[i], w.buildings.cx[b] * 1000 + w.buildings.sx[b] * 500, w.buildings.cy[b] * 1000 + w.buildings.sy[b] * 500)
			if rank < best_rank or (rank == best_rank and d < best_d):
				best = w.buildings.id[b]
				best_d = d
				best_rank = rank
		if best != 0:
			orders[best] = orders.get(best, []) + [w.units.id[i]]
		elif ram and w.units.foe[i] == 0 and w.units.moving[i] == 0:
			march.append(w.units.id[i])   # nothing of theirs in sight: off to where the army is going
	var targets := orders.keys()
	targets.sort()
	for b in targets:
		w.issue(player, Commands.ATTACK, {"ids": orders[b], "target": b})
	var to := _enemy_target(w, hx, hy)
	if not march.is_empty() and to.x >= 0:
		to = _reachable(w, to)
		w.issue(player, Commands.ATTACK_MOVE, {"ids": march, "x": to.x, "y": to.y})


## Which of a building's lines to train against these foes (_enemy_tags): the best _score plus the
## slot's military.pick_bias (engines go round instead, _siege_score); "" if none is open yet.
func pick(w, trains: Array, foes: Dictionary, reserve := PackedInt32Array()) -> String:
	var best := ""
	var best_score := -(1 << 30)
	for slot in trains:
		var k: int = w.type_of(player, slot)
		if k < 0 or w.ages[player] < int(w.types[k].line[0].age) or _enough(w, slot, k) or w.types[k].get("trader", false) \
				or Economy.lacks(w, player, slot):
			continue   # (trade carts aren't picked as soldiers: _trade_carts; nor what the race lacks: milestone 14)
		if not reserve.is_empty() and not _affords(w, w.types[k].cost, reserve):
			continue   # (one short of wood shouldn't stop a building whose other line uses the gold piled up)
		var s := _siege_score(w, slot, k) if cfg.military.get("siege", {}).get("max", {}).has(slot) \
			else _score(w.types[k], foes) + int(cfg.military.pick_bias.get(slot, 0))
		if s > best_score:
			best_score = s
			best = slot
	return best


## Do we have this cost to spare beyond `reserve`?
func _affords(w, cost: PackedInt32Array, reserve: PackedInt32Array) -> bool:
	for r in cost.size():
		if w.stock[r][player] < cost[r] + reserve[r]:
			return false
	return true


## A scout from the Stable as soon as there is one and we have none (military.scouts.keep), ahead of
## the counter-pick: Scout's soldier tours take it before any other soldier, and what it sees is what
## the counter-pick reads.
func _train_scout(w, scouts: int) -> void:
	var k: int = w.type_of(player, "scout")
	if k < 0 or scouts >= int(cfg.military.scouts.keep) or w.ages[player] < int(w.types[k].line[0].age) or not w.can_afford(player, w.types[k].cost):
		return
	for b in w.buildings.count():
		if w.buildings.owner[b] == player and k in w.buildings.queue[b]:
			return   # one on the way
	for b in w.buildings.count():
		if w.buildings.owner[b] == player and w.buildings.done[b] == 1 and "scout" in w.btypes[w.buildings.kind[b]].trains \
				and w.buildings.queue[b].size() < int(cfg.military.queue):
			w.issue(player, Commands.TRAIN, {"building": w.buildings.id[b], "slot": "scout"})
			return


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


## Healers follow the army, `behind` tiles back from the middle of its rear half, on the side
## towards home. Only idle ones (healing no one) more than `follow` tiles from that spot are sent: a healer at work
## stays with its patient, and one near the spot picks the wounded up on its own.
func _escort(w, army: Array, healers: Array, hx: int, hy: int) -> void:
	var h: Dictionary = cfg.military.get("healers", {})
	if healers.is_empty() or army.is_empty() or w.tick % (int(h.get("every", 3)) * 20) != _phase():
		return
	# The army that's out (beyond the home guard's reach); with none out, the healers stay home,
	# where the hurt come back to (and the workers are).
	var home_r := int(cfg.military.defend_tiles) * 1000
	var out := army.filter(func(i): return Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i]) > home_r * home_r)
	var mx := hx
	var my := hy
	if out.size() >= 2:   # the middle of its rear half (a wave split by a flank, or strung along a forest path, is followed from behind)
		var by := out.map(func(i): return [Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i]), w.units.id[i], i])
		by.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		var rear := by.slice(0, (by.size() + 1) / 2)
		var sx := 0
		var sy := 0
		for e in rear:
			sx += w.units.x[e[2]]
			sy += w.units.y[e[2]]
		mx = sx / rear.size()
		my = sy / rear.size()
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


## How many enemy soldiers we see or remember (the scout's memory) carry each tag.
func _enemy_tags(w) -> Dictionary:
	var tags := {}
	for s in scout.soldiers():   # (in sight now, or seen in the last scout.memory seconds)
		var t: Dictionary = w.types[s[0]]
		for tag in t.eval.tags:
			tags[tag] = tags.get(tag, 0) + 1
		for c in t.eval.bonus:   # remember what they're good against, keyed apart
			tags["bonus:" + c] = tags.get("bonus:" + c, 0) + int(t.eval.bonus[c])
	if _aim != 0:   # the army is going for a building (a wall shutting the way): wall-breakers count (military.building_foes)
		tags["building"] = int(cfg.military.building_foes)
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
		if w.units.foe[i] == 0 and Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i]) < 4 * r * r and not land.is_climbing(w, i) and w.units.perch[i] == 0:
			ids.append(w.units.id[i])   # (shooters on their way up a hill hold it instead)
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
	# Their friends in sight round it are the same raid, blows struck yet or not (the ones held in
	# duels with our workers hadn't, so a raid of six read as three and the call came late).
	var trouble := TROUBLE_TILES * TROUBLE_TILES * 1000000
	for i in w.units.count():
		if w.is_foe(player, w.units.owner[i]) and not w.types[w.units.kind[i]].worker and not _threats.has(w.units.id[i]) \
				and Fixed.dist2(w.units.x[i], w.units.y[i], f.x, f.y) <= trouble and Fog.visible(w, player, w.units.x[i], w.units.y[i]):
			raiders.append(Vector2i(w.units.x[i], w.units.y[i]))
			strength += int(w.types[w.units.kind[i]].pop)
	var d := Fixed.isqrt(Fixed.dist2(f.x, f.y, hx, hy))
	# A raid on the outskirts (a camp, workers at a far patch): a tower goes up there once it's quiet.
	var tw: Dictionary = cfg.military.get("towers", {})
	if not tw.is_empty() and w.ages[player] >= int(tw.age) and d > (FLEE_TILES + 2) * 1000 and d <= int(tw.within) * 1000:
		_tower_at = f
	# A big raid by the Town Center that the soldiers at home can't answer: call to arms, for a
	# while (shelter.seconds: a Town Center full of workers can't hold out for ever, and the
	# economy stands still meanwhile), then not again for shelter.every seconds.
	var sh: Dictionary = cfg.military.shelter
	if _sheltering and w.tick >= _shelter_until:
		w.issue(player, Commands.BACK_TO_WORK, {})
		_sheltering = false
	if shelter_pop > 0 and not _sheltering and w.tick >= _shelter_next and strength >= shelter_pop and d <= int(sh.tiles) * 1000:
		var home_pop := 0
		var home_r := 2 * int(cfg.military.defend_tiles) * 1000
		for i in army:
			if Fixed.dist2(w.units.x[i], w.units.y[i], hx, hy) <= home_r * home_r:
				home_pop += int(w.types[w.units.kind[i]].pop)
		if home_pop < strength:
			w.issue(player, Commands.CALL_TO_ARMS, {"building": w.buildings.id[tc]})
			_sheltering = true
			_shelter_until = w.tick + int(sh.seconds) * 20
			_shelter_next = w.tick + int(sh.every) * 20
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
		if (w.units.foe[i] != 0 and w.units.index_of(w.units.foe[i]) >= 0) or land.is_climbing(w, i) or w.units.perch[i] != 0:
			continue   # fighting someone already (or taking a hill, or up on our wall: it shoots from there)
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
	if eco._building_underway(w) or not w.can_afford(player, Economy.bcost(w, player, k)) or workers.is_empty():
		return
	var spot: Vector2i = eco._house_spot(w, _tower_at.x / 1000, _tower_at.y / 1000, w.btypes[k].size)
	_tower_at = Vector2i(-1, -1)
	if spot.x < 0:
		return
	var builders := _nearest_workers(w, workers, spot.x * 1000, spot.y * 1000, 2)
	w.issue(player, Commands.BUILD, {"ids": builders, "building": "watchtower", "cx": spot.x, "cy": spot.y})
	_next_build = w.tick + BUILD_COOLDOWN


## The market (data: economy.trade): while food or wood is under `below`, gold piled past `above`
## buys a lot of the lower of them; with less gold than that, the biggest other pile past `above`
## sells for gold (food or stone piled up while wood ran dry). One trade every `every` seconds. (A pile nobody spends was holding armies small and
## matches long: soldiers want food and wood.) What we save for (eco.goal) isn't a pile nobody
## spends: it's kept back on top of `above` (selling the stone saved for a Castle held its stone
## under 500 all game, and the Castle never came).
var _next_trade := 0

func _trade(w) -> void:
	var t: Dictionary = cfg.economy.get("trade", {})
	if t.is_empty() or w.tick < _next_trade or Economy.lacks(w, player, "trade"):
		return
	var mk := -1
	for b in w.buildings.count():
		if w.buildings.owner[b] == player and w.buildings.done[b] == 1 and w.btypes[w.buildings.kind[b]].id == "market":
			mk = b
			break
	if mk < 0:
		return
	_next_trade = w.tick + int(t.every) * 20
	var g: int = w.resources.find("gold")
	var low := -1
	for res in ["food", "wood"]:
		var r: int = w.resources.find(res)
		if w.stock[r][player] < int(t.below) and (low < 0 or w.stock[r][player] < w.stock[low][player]):
			low = r
	if low >= 0 and w.stock[g][player] >= int(t.above) + _saving(g):
		w.issue(player, Commands.TRADE, {"building": w.buildings.id[mk], "resource": w.resources[low], "buy": 1})
		return
	if low < 0:
		return
	var most := -1   # food or wood short and not gold enough to buy it: sell the biggest pile (over `above`) for gold
	for r in w.resources.size():
		if r != g and w.stock[r][player] >= int(t.above) + _saving(r) and (most < 0 or w.stock[r][player] > w.stock[most][player]):
			most = r
	if most >= 0:
		w.issue(player, Commands.TRADE, {"building": w.buildings.id[mk], "resource": w.resources[most], "buy": 0})


## Trade carts (milestone 13 step 8; data: economy.carts): with two markets far enough apart to trade
## (ours, or one of ours and an ally's: the farthest such pair, Trade.why_not), idle carts go on the
## route from our end, and more are trained there one at a time, up to `max`, from what's over beyond
## what we save for. With no such pair, a second Town Center far enough from our only market gets a
## market beside it (`second_market`). Every `every` seconds, from age `age`.
func _trade_carts(w, carts: Array, workers: Array) -> void:
	var c: Dictionary = cfg.economy.get("carts", {})
	if c.is_empty() or w.ages[player] < int(c.age) or w.tick % (int(c.every) * 20) != _phase():
		return
	var k: int = w.type_of(player, "trader")
	if k < 0:
		return
	var pair := _trade_pair(w)
	if pair.is_empty():
		if int(c.get("second_market", 0)) == 1:
			_second_market(w, workers)
		return
	var idle := []
	for i in carts:
		if w.units.task[i] != Economy.TRADE:
			idle.append(w.units.id[i])
	if not idle.is_empty():
		w.issue(player, Commands.ROUTE, {"ids": idle, "building": w.buildings.id[pair[1]]})
	var home: int = pair[0]
	if _fielded(w, k) >= int(c.max) or not w.buildings.queue[home].is_empty() or _saving_age or not _threats.is_empty():
		return
	var reserve := PackedInt32Array()
	reserve.resize(w.resources.size())
	for r in reserve.size():
		reserve[r] = _saving(r)
	if _affords(w, w.types[k].cost, reserve):
		w.issue(player, Commands.TRAIN, {"building": w.buildings.id[home], "slot": "trader"})


## [our market, the far market] (building slots): the farthest pair our carts may trade between,
## or [] if there's none.
func _trade_pair(w) -> Array:
	var bs = w.buildings
	var best := []
	var best_d := -1
	for a in bs.count():
		if bs.owner[a] != player or bs.done[a] == 0 or w.btypes[bs.kind[a]].id != "market":
			continue
		for b in bs.count():
			if b == a or bs.done[b] == 0 or w.btypes[bs.kind[b]].id != "market" or Trade.why_not(w, player, a, b) != "":
				continue
			var d: int = Trade.tiles(w, a, b)
			if d > best_d:
				best_d = d
				best = [a, b]
	return best


## One market of ours, two Town Centers: a second market by the Town Center farthest from it, if
## that's far enough to trade (rules economy.trade.min_tiles, a few tiles more for the spot).
func _second_market(w, workers: Array) -> void:
	var bs = w.buildings
	var mk := Economy.btype_of(w, "market")
	var ours := []
	for b in bs.count():
		if bs.owner[b] == player and bs.kind[b] == mk:
			ours.append(b)
	if ours.size() != 1 or bs.done[ours[0]] == 0 or w.tick < _next_build or not w.can_afford(player, w.btypes[mk].cost) or _saving_age:
		return
	var far := -1
	var far_d := int(w.econ.trade.min_tiles) + 4
	for b in bs.count():
		if bs.owner[b] == player and bs.done[b] == 1 and w.btypes[bs.kind[b]].id == "town_center":
			var d: int = Trade.tiles(w, ours[0], b)
			if d >= far_d:
				far = b
				far_d = d
	if far < 0:
		return
	var spot: Vector2i = eco._house_spot(w, bs.cx[far] + 1, bs.cy[far] + 1, w.btypes[mk].size)
	if spot.x < 0:
		return
	var builders := _nearest_workers(w, workers, spot.x * 1000, spot.y * 1000, 2)
	if builders.is_empty():
		return
	w.issue(player, Commands.BUILD, {"ids": builders, "building": "market", "cx": spot.x, "cy": spot.y})
	_next_build = w.tick + BUILD_COOLDOWN


## How much of resource r we're saving for (eco.goal), or 0.
func _saving(r: int) -> int:
	return eco.goal[r] if r < eco.goal.size() else 0


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
## Its id is kept in _aim: the army breaks that one piece rather than every one it walks up to.
## Pieces that open the way when they fall (side by side with our area and the target's) come
## first: a ring's corner touches the inside only across a corner, so breaking it opens nothing.
## Then the quickest to break: hit points over the sides our soldiers can hit it from (a long gate
## takes three times the hitters of a wall tile), which outweighs a walk round the wall.
func _blocker(w, hx: int, hy: int, target: Vector2i) -> Vector2i:
	var bs = w.buildings
	var best := target
	var best_d := 1 << 62
	var tarea: int = eco.reach.area_at(w, _aln, target.x, target.y)
	_aim = 0
	for b in bs.count():
		if not w.is_enemy(player, bs.owner[b]) or not eco.reach.reaches_building(w, _aln, _harea, b):
			continue
		var x: int = bs.cx[b] * 1000 + bs.sx[b] * 500
		var y: int = bs.cy[b] * 1000 + bs.sy[b] * 500
		var d: int = Fixed.isqrt(Fixed.dist2(hx, hy, x, y)) + Fixed.isqrt(Fixed.dist2(x, y, target.x, target.y))
		var sides := _sides(w, b, _harea)
		if tarea == 0 or sides == 0 or _sides(w, b, tarea) == 0:
			d += 1 << 40
		d += bs.hp[b] * 1000 / maxi(sides, 1)
		if d < best_d:
			best_d = d
			best = Vector2i(x, y)
			_aim = bs.id[b]
	return best


## How many cells of `area` share a side (not just a corner) with building b's footprint (a
## diagonal gate's too: the cells of its stair on either side).
func _sides(w, b: int, area: int) -> int:
	var lab: PackedInt32Array = eco.reach.labels(w, _aln)
	var m = w.map
	var cells: PackedInt32Array = w.buildings.footprint(b, m.width)
	var counted := {}
	for c in cells:
		for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var x: int = c % m.width + d.x
			var y: int = c / m.width + d.y
			var o: int = y * m.width + x
			if x >= 0 and y >= 0 and x < m.width and y < m.height and lab[o] == area and not cells.has(o):
				counted[o] = true
	return counted.size()


## A point our soldiers can get to: the point itself if it's in our area, else the nearest
## spot of our area to it (the near bank of a river whose fords are walled off).
func _reachable(w, at: Vector2i) -> Vector2i:
	if _harea == 0 or eco.reach.labels(w, _aln)[w.map.cell_of(at.x, at.y)] == _harea:
		return at   # (on its own cell: a point on a wall would snap to whichever side is nearer)
	var near: Vector2i = eco.reach.nearest_in(w, _aln, _harea, at.x, at.y)
	return near if near.x >= 0 else at


## Where the waves go: the enemy target (_enemy_target), the wall that shuts the way to it if
## it's out of reach, a point we can get to; (-1, -1) if there's nothing.
func _wave_target(w, hx: int, hy: int) -> Vector2i:
	var target := _enemy_target(w, hx, hy)
	if target.x < 0:
		return target
	if _harea != 0 and eco.reach.area_at(w, _aln, target.x, target.y) != _harea:
		target = _blocker(w, hx, hy, target)
	return _reachable(w, target)


func _waves(w, army: Array, hx: int, hy: int) -> void:
	var m: Dictionary = cfg.military
	var wonder := _known_enemy_wonder(w, hx, hy)
	var target := _target
	if target.x < 0:
		return
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
		if all_in > 0 and strength >= all_in:
			keep = 0   # a big army goes all in: a guard at home only spreads it thin against castles and towers
		var sent: Array = away + at_home.slice(0, maxi(0, at_home.size() - keep))
		if not sent.is_empty():
			_send(w, sent.map(func(i): return w.units.id[i]), target, wonder <= 0, hx, hy)
		assault = true
		wave += 1
		next_wave_tick = int(waves[wave].at) * 20 if wave < waves.size() else w.tick + int(m.repeat_every) * 20
		return
	if not assault or w.tick % (int(m.regroup_every) * 20) != _phase():
		return
	# Soldiers out in the field with no enemy soldier to fight (idle, or hacking at a house)
	# push on to the next target.
	var home_r := int(m.defend_tiles) * 1000
	var ids := []
	# Reinforcements: once we're attacking, fresh soldiers idling at home go forward in groups.
	var home := army.filter(func(i): return w.units.foe[i] == 0 and w.units.moving[i] == 0 \
			and Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i]) <= 4 * home_r * home_r)
	if home.size() >= maxi(REINFORCE, need / 2) and wave_pct >= 100:   # (a partial wave's home guard stays home; fresh ones go in groups of half a wave, not a trickle)
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
	# A raiding level goes for the economy outside tower range first, in groups.
	var strong := _dominant(w, army)   # (far stronger than what they field: straight for the Town Center)
	if raids > 0 and w.tick >= raid_from and wonder <= 0 and not strong and _raid(w, ids, hx, hy):
		return
	# Too few to storm a Town Center under towers and a Castle: wait out of their reach on the way
	# in (contain), and storm it once the army is big enough.
	var hold := _contain_point(w, target)
	if wonder <= 0 and hold.x >= 0 and _pop(w, army) < int(m.contain_pop) and not _has_siege(w, army):
		w.issue(player, Commands.ATTACK_MOVE, {"ids": ids, "x": hold.x, "y": hold.y})
		return
	# With the field clear, go for the Town Center itself (that ends the match) rather than
	# chewing through every house on the way.
	var tc_id := wonder if wonder > 0 else _known_enemy_town(w, hx, hy)   # (a Wonder first)
	if tc_id <= 0:
		tc_id = _aim   # the target itself, all together: attack-moving at it, soldiers set on whatever building is nearest
		# (the enemy's stone wall beside a farm, a dozen wall pieces at once) and chew on that for minutes
	if tc_id <= 0:
		w.issue(player, Commands.ATTACK_MOVE, {"ids": ids, "x": target.x, "y": target.y})
		return
	if strong:   # everyone out there not fighting a soldier, not just the idle: no more chewing through houses
		for i in army:
			var id: int = w.units.id[i]
			if not ids.has(id) and w.units.index_of(w.units.foe[i]) < 0 and Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i]) > 4 * home_r * home_r:
				ids.append(id)
	# Enough to fight the defenders (two each) attack-move; the rest go straight for the Town Center.
	var fighters := mini(ids.size(), 2 * _defenders(w, w.buildings.index_of(tc_id)))
	if fighters > 0:
		w.issue(player, Commands.ATTACK_MOVE, {"ids": ids.slice(0, fighters), "x": target.x, "y": target.y})
	if fighters < ids.size():
		w.issue(player, Commands.ATTACK, {"ids": ids.slice(fighters), "target": tc_id})


## Soldiers out on an attack caught on an enemy wall or gate piece that isn't what they go for
## (attack-moving past a wall, or waiting out of tower reach beside one, they take up the piece
## next to them) are put on the target at once, every think rather than at the next regroup: the
## Town Center we can get to, else _aim (the one piece we break, or the building we march on). The
## blows go on one piece, not nicks on a dozen. Engines are left alone (_siege sends rams at walls).
func _off_walls(w, army: Array, hx: int, hy: int) -> void:
	if not assault:
		return
	var to := _known_enemy_town(w, hx, hy)
	if to <= 0:
		to = _aim
	if to <= 0:
		return
	var ids := []
	for i in army:
		var t: Dictionary = w.types[w.units.kind[i]]
		if t.get("buildings_only", false) or t.get("splash", 0) > 0:
			continue
		var b: int = w.buildings.index_of(w.units.foe[i])
		if b >= 0 and w.units.foe[i] != to and (w.btypes[w.buildings.kind[b]].line or w.btypes[w.buildings.kind[b]].gate):
			ids.append(w.units.id[i])
	if not ids.is_empty():
		w.issue(player, Commands.ATTACK, {"ids": ids, "target": to})


## A wave goes out: a raiding level at the enemy's economy (_raid), else to the target: part of
## an amphibious army by the flank Land found (through the channels), the rest by the detour round
## archers on a hill if there's one, then on to the target (queued attack-moves).
func _send(w, ids: Array, target: Vector2i, may_raid: bool, hx: int, hy: int) -> void:
	var idx := ids.map(func(id): return w.units.index_of(id))
	var strong := _dominant(w, idx)
	if raids > 0 and w.tick >= raid_from and may_raid and not strong and _raid(w, ids, hx, hy):
		return
	var hold := _contain_point(w, target)
	if may_raid and hold.x >= 0 and _pop(w, idx) < int(cfg.military.contain_pop) and not _has_siege(w, idx):
		target = hold   # (too few to storm it: wait out of reach)
	var lc: Dictionary = cfg.land
	var main := ids.duplicate()
	if land.flank.x >= 0 and ids.size() >= int(lc.flank_min):
		var n: int = ids.size() * int(lc.flank_share) / 100
		var flankers := ids.slice(ids.size() - n)
		main = ids.slice(0, ids.size() - n)
		_via(w, flankers, land.flank, target)
		land.count("flank")
	_via(w, main, land.detour, target)
	if land.detour.x >= 0:
		land.count("detour")


## Are these soldiers of ours (indexes) a wave (the age's repeat wave), and with our allies' armies
## military.dominant_pct percent of the enemy army we remember, or more? Then raids and waiting are over: the Town
## Centers end the match (still waiting out of reach of towers and a Castle till it's contain_pop).
func _dominant(w, idx: Array) -> bool:
	var theirs := 0
	for e in scout.soldiers():
		theirs += int(w.types[e[0]].pop)
	var ours := _pop(w, idx)
	var with := ours   # (and our allies' armies: two of us against one finish it together)
	for i in w.units.count():
		var t: Dictionary = w.types[w.units.kind[i]]
		if w.units.owner[i] != player and w.units.owner[i] != w.gaia and not w.is_enemy(player, w.units.owner[i]) \
				and not t.worker and not t.healer and not t.has("animal") and not t.get("trader", false):
			with += int(t.pop)
	return ours >= _repeat_min(w) and with * 100 >= maxi(1, theirs) * int(cfg.military.dominant_pct)


## Do these soldiers of ours (indexes) bring a siege engine (a ram, a thrower)? Then towers and a
## Castle are theirs to break: no waiting out of reach.
func _has_siege(w, idx: Array) -> bool:
	for i in idx:
		if i >= 0:
			var t: Dictionary = w.types[w.units.kind[i]]
			if t.get("buildings_only", false) or t.get("splash", 0) > 0:
				return true
	return false


## Our soldiers' population (indexes into the units arrays).
func _pop(w, idx: Array) -> int:
	var n := 0
	for i in idx:
		if i >= 0:
			n += int(w.types[w.units.kind[i]].pop)
	return n


## Where to wait for a bigger army when `target` stands under the enemy's shooting buildings we
## remember (fog memory: towers, a Castle, the Town Center): the last cell of our way in (Land's
## path) out of their reach by military.contain_gap tiles. (-1, -1) when nothing shoots over the
## target or we have no way in.
func _contain_point(w, target: Vector2i) -> Vector2i:
	var path: PackedInt32Array = land.our_path
	if path.is_empty() or target.x < 0:
		return Vector2i(-1, -1)
	var seen: Dictionary = w.fog_seen[player]
	var ids: Array = seen.keys()
	ids.sort()
	var gap: int = int(cfg.military.contain_gap)
	var shooters := []   # [x, y, reach] in tiles, the ones over the target
	for id in ids:
		var s: PackedInt32Array = seen[id]
		var t: Dictionary = w.btypes[s[0]]
		if not w.is_enemy(player, s[1]) or t.attack.is_empty() or s[5] == 0:
			continue
		var x: int = s[2] + s[4] / 2
		var y: int = s[3] + s[8] / 2
		var r: int = int(t.attack.range) + maxi(s[4], s[8]) / 2 + gap
		if (x - target.x / 1000) * (x - target.x / 1000) + (y - target.y / 1000) * (y - target.y / 1000) <= r * r:
			shooters.append([x, y, r])
	if shooters.is_empty():
		return Vector2i(-1, -1)
	var m = w.map
	for n in range(path.size() - 1, -1, -1):
		var cx: int = path[n] % m.width
		var cy: int = path[n] / m.width
		if not shooters.any(func(e): return (cx - e[0]) * (cx - e[0]) + (cy - e[1]) * (cy - e[1]) <= e[2] * e[2]):
			return Vector2i(cx * 1000 + 500, cy * 1000 + 500)
	return Vector2i(-1, -1)


## Attack-move `ids` to `target`, by way of `via` first unless it's (-1, -1).
func _via(w, ids: Array, via: Vector2i, target: Vector2i) -> void:
	if ids.is_empty():
		return
	if via.x < 0:
		w.issue(player, Commands.ATTACK_MOVE, {"ids": ids, "x": target.x, "y": target.y})
		return
	w.issue(player, Commands.ATTACK_MOVE, {"ids": ids, "x": via.x, "y": via.y})
	w.issue(player, Commands.ATTACK_MOVE, {"ids": ids, "x": target.x, "y": target.y, "queue": 1})


## Raid the economy: the enemy's camps, mills, farms and pens we remember (fog memory: as last
## seen) outside reach of their shooting buildings (raid_safe tiles more), that we can get to,
## nearest us first; `ids` split into up to `raids` groups of at least raid_min, one per target.
## False if there's nothing like that to raid (the caller goes for the Town Center).
func _raid(w, ids: Array, hx: int, hy: int) -> bool:
	var targets := _eco_targets(w, hx, hy)
	if targets.is_empty() or ids.is_empty():
		return false
	var groups: int = clampi(ids.size() / maxi(1, int(cfg.military.raid_min)), 1, mini(raids, targets.size()))
	var sorted := ids.duplicate()
	sorted.sort()
	for g in groups:
		var part := []
		for n in sorted.size():
			if n % groups == g:
				part.append(sorted[n])
		var at: Vector2i = targets[g]
		w.issue(player, Commands.ATTACK_MOVE, {"ids": part, "x": at.x, "y": at.y})
	land.count("raid")
	return true


## The enemy economy worth raiding, nearest us first: remembered buildings of the kinds in
## military.raid_targets, not within reach (+ raid_safe tiles) of a remembered shooting building,
## that our soldiers can get to. Their middles, in milli-tiles.
func _eco_targets(w, hx: int, hy: int) -> Array:
	var seen: Dictionary = w.fog_seen[player]
	var ids: Array = seen.keys()
	ids.sort()
	var kinds: Array = cfg.military.raid_targets
	var safe: int = int(cfg.military.raid_safe)
	var shooters := []   # [x, y, reach] in tiles
	for id in ids:
		var s: PackedInt32Array = seen[id]
		var t: Dictionary = w.btypes[s[0]]
		if w.is_enemy(player, s[1]) and not t.attack.is_empty():
			shooters.append([s[2] + s[4] / 2, s[3] + s[8] / 2, int(t.attack.range) + safe])
	var out := []
	for id in ids:
		var s: PackedInt32Array = seen[id]
		if not w.is_enemy(player, s[1]) or not w.btypes[s[0]].id in kinds:
			continue
		var x: int = s[2] + s[4] / 2
		var y: int = s[3] + s[8] / 2
		if shooters.any(func(e): return (e[0] - x) * (e[0] - x) + (e[1] - y) * (e[1] - y) <= e[2] * e[2]):
			continue
		if not eco.reach.touches(w, _aln, _harea, s[2], s[3], s[4], s[8]):
			continue
		out.append([Fixed.dist2(hx, hy, x * 1000 + 500, y * 1000 + 500), id, Vector2i(x * 1000 + 500, y * 1000 + 500)])
	out.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return out.map(func(e): return e[2])


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
				and not w.types[w.units.kind[i]].healer and not w.types[w.units.kind[i]].get("trader", false) and Fog.visible(w, player, w.units.x[i], w.units.y[i]) and Fixed.dist2(x, y, w.units.x[i], w.units.y[i]) < r * r:
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


## Do we know of enemy building b: its ground explored, or it's a Town Center on a start (every
## player knows where the others start, so a scout that saw only the outskirts doesn't turn the
## army from the Town Center to a camp it happened to see)?
func _known(w, b: int) -> bool:
	var bs = w.buildings
	if Fog.explored(w, player, bs.cx[b], bs.cy[b]):
		return true
	if bs.kind[b] != Economy.btype_of(w, "town_center"):
		return false
	for s in w.map.starts:
		if absi(int(s[0]) / 1000 - bs.cx[b] - 1) <= 2 and absi(int(s[1]) / 1000 - bs.cy[b] - 1) <= 2:
			return true
	return false


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
## we've seen but walls, else an enemy's starting spot (every player knows where the others start). Ones
## our soldiers can get to come first: with the Town Center behind a walled ford, the wall we've
## seen there is the target (it comes down, then the way is open). With nothing in reach, the
## caller marches to the nearest bank (_reachable).
func _enemy_target(w, hx: int, hy: int) -> Vector2i:
	var tc_kind: int = Economy.btype_of(w, "town_center")
	var wk: int = Economy.btype_of(w, "wonder")
	var best := Vector2i(-1, -1)
	var best_d2 := 1 << 62
	var best_rank := -2   # 2: a Wonder, 1: a Town Center, 0: anything else, -1: a wall piece or gate
	var best_ok := false
	for b in w.buildings.count():
		var bs = w.buildings
		var wonder: bool = bs.kind[b] == wk
		if not w.is_enemy(player, bs.owner[b]) or not (_known(w, b) or (wonder and _knows_wonder(w, b))):
			continue
		var x: int = bs.cx[b] * 1000 + bs.sx[b] * 500
		var y: int = bs.cy[b] * 1000 + bs.sy[b] * 500
		var rank: int = 2 if wonder else (1 if bs.kind[b] == tc_kind else (-1 if w.btypes[bs.kind[b]].line or w.btypes[bs.kind[b]].gate else 0))
		var ok: bool = eco.reach.reaches_building(w, _aln, _harea, b)
		var d2 := Fixed.dist2(hx, hy, x, y)
		if (ok and not best_ok) or (ok == best_ok and (rank > best_rank or (rank == best_rank and d2 < best_d2))):
			best = Vector2i(x, y)
			best_d2 = d2
			best_rank = rank
			best_ok = ok
			_aim = bs.id[b] if ok else 0
	if best_rank < 0:
		_aim = 0   # (walls seen aren't worth marching on: the way in is broken by _blocker, then on to the start)
		for p in w.races.size():
			if w.is_enemy(player, p) and w.defeated[p] == 0 and p < w.map.starts.size():
				return Vector2i(int(w.map.starts[p][0]), int(w.map.starts[p][1]))
	return best
