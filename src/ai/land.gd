extends RefCounted
## The land as a bot reads it (milestone 15 phase 7): the crossings, the ways between the bases,
## roads through thin woods, bridges to mend or break, hills to hold. A player looks at the map
## and thinks about routes; the bot does the same with whole-map searches (routes.gd), a few
## "studies" it keeps fresh, one search at a time on its own think (so no tick searches much):
## - our way: our army's route from home to what it attacks, and from it
##   - a detour round enemy archers standing on a hill over that route (when another way
##     isn't much longer), and for amphibians a flank: a second route kept off the first
##     (through the channels), for part of each wave;
##   - bridges: one down that would shorten our way a lot (or is the only way) gets rebuilt
##     by two workers;
## - their way: the enemy army's route to us. Its crossing is the key crossing (a Watchtower
##   guards it when the level defends); a standing bridge whose loss makes their way much
##   longer, and ours not (amphibians swim), gets broken by a few melee soldiers;
## - a road: where felling a few trees makes the walk to the enemy, the middle or far
##   resources much shorter, workers fell exactly those trees (wood for the stock too).
## Hills: ranged soldiers meeting an army step up onto higher ground nearby.
## Data: data/ai.json "land". Read-only over the sim; it acts by commands only.

const Routes := preload("res://src/ai/routes.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const Commands := preload("res://src/sim/commands.gd")
const Economy := preload("res://src/sim/economy.gd")
const Fog := preload("res://src/sim/fog.gd")

var cfg: Dictionary
var _crossings := []           # [kind ("ford"/"bridge"), centre cell, cells, bridge slot or -1]
var _made := false
var _done := {}                # study -> the tick it was last made
var _next_study := 0
var target := Vector2i(-1, -1) # what our army goes for (the bot sets it): routes lead there
var our_cost := Routes.INF     # our way's price, all as it stands
var our_path := PackedInt32Array()
var our_start_cost := Routes.INF   # our way to the enemy's start (bridges are judged by it)
var their_cost := Routes.INF   # their way's price to us
var key := -1                  # the crossing on their way (index into crossings), -1: none
var key_side := -1             # the cell on our side where their way comes off it
var detour := Vector2i(-1, -1) # a waypoint round archers on a hill, or (-1, -1)
var flank := Vector2i(-1, -1)  # amphibians: a waypoint off the main route, or (-1, -1)
var mend := {}                 # bridge slot -> true: worth rebuilding (studied)
var cut := {}                  # bridge slot -> true: worth breaking (studied)
var _broke := {}               # bridge slot -> true: we broke it on purpose (never mended for a shortcut)
var road := PackedInt32Array() # trees to fell for the road being cut
var roads := 0
var fellers := []              # worker ids felling it
var _hill_next := {}           # unit id -> no hill order before this tick
var climbing := {}             # unit id -> tick: on its way up a hill till then (defence leaves it be)
var _breakers := []            # soldier ids sent at a bridge
var _bridge_next := 0
var want := PackedInt32Array() # the road's camp, wanted but not yet affordable
var _camp_laid := false
var _camp_next := 0        # the road being felled has its camp (or needs none)
var _road_walk := []           # the road study's first search (walking), until its second
var _job = null                # the search under way (Routes.Search), a slice a think
var _job_key := ""             # ... for which study
var stats := {}                # what it did, for tests and reports: name -> count


func _init(p_cfg: Dictionary) -> void:
	cfg = p_cfg


## The map's crossings: fords in clumps (8-neighbour), and the bridges. Made once.
func crossings(w) -> Array:
	if _made:
		return _crossings
	_made = true
	var m = w.map
	var ford: int = m.terrain_ids.find("ford")
	var seen := PackedByteArray()
	seen.resize(m.width * m.height)
	for c in m.width * m.height:
		if ford < 0 or m.terrain[c] != ford or seen[c] == 1:
			continue
		var cells := PackedInt32Array([c])
		seen[c] = 1
		var head := 0
		while head < cells.size():
			var at: int = cells[head]
			head += 1
			for d in 8:
				var x: int = at % m.width + Routes.DX[d]
				var y: int = at / m.width + Routes.DY[d]
				if x >= 0 and y >= 0 and x < m.width and y < m.height and m.terrain[y * m.width + x] == ford and seen[y * m.width + x] == 0:
					seen[y * m.width + x] = 1
					cells.append(y * m.width + x)
		_crossings.append(["ford", _centre(m, cells), cells, -1])
	for k in w.bridge_id.size():
		_crossings.append(["bridge", _centre(m, w.bridge_cells[k]), w.bridge_cells[k], k])
	return _crossings


static func _centre(m, cells: PackedInt32Array) -> int:
	var sx := 0
	var sy := 0
	for c in cells:
		sx += c % m.width
		sy += c / m.width
	var x: int = sx / cells.size()
	var y: int = sy / cells.size()
	var best: int = cells[0]
	for c in cells:
		if absi(c % m.width - x) + absi(c / m.width - y) < absi(best % m.width - x) + absi(best / m.width - y):
			best = c
	return best


## Once a second, from the bot's think.
func think(w, bot, workers: Array, army: Array, hx: int, hy: int) -> void:
	crossings(w)
	_fell(w, bot, workers)
	if _job != null or w.tick >= _next_study:   # (a search under way goes on every think)
		if _job == null:
			_next_study = w.tick + int(cfg.study_every) * 20
		_study(w, bot, workers, army, hx, hy)
	_bridges(w, bot, workers, army, hx, hy)
	_hills(w, bot, army)


# ------------------------------------------------------------------ studies

func _due(w, name: String, every: int) -> bool:
	return not _done.has(name) or w.tick - int(_done[name]) >= every * 20


## The finished search for study `key` ([dist, prev]), or [] while it runs: the first call starts
## it (its prices from `price_fn`), every call settles another search_cells cells. One at a time.
func _search(w, key: String, open: PackedByteArray, from: int, price_fn: Callable) -> Array:
	if _job_key != key:
		_job = Routes.Search.new(w.map, price_fn.call(), open, from)
		_job_key = key
	if not _job.step(int(cfg.search_cells)):
		return []
	var found: Array = _job.result()
	_job = null
	_job_key = ""
	return found


## One study a time, the first that's due.
func _study(w, bot, workers: Array, army: Array, hx: int, hy: int) -> void:
	var m = w.map
	var ln: int = bot._aln
	var from := _open_near(m, ln, m.cell_of(hx, hy))
	if from < 0 or target.x < 0:
		return
	var goal := Routes.ring_round(m, m.walks[ln], target.x / 1000, target.y / 1000, 3)
	if _due(w, "ours", int(cfg.our_every)):
		var found := _search(w, "ours", m.walks[ln], from, func(): return Routes.prices(w, ln))
		if found.is_empty():
			return
		_done["ours"] = w.tick
		var g := Routes.cheapest(found, goal)
		our_cost = found[0][g] if g >= 0 else Routes.INF
		our_path = Routes.path(found, g) if g >= 0 else PackedInt32Array()
		var es := _enemy_start(w, bot, hx, hy)
		var gs := Routes.cheapest(found, Routes.ring_round(m, m.walks[ln], es.x / 1000, es.y / 1000, 3)) if es.x >= 0 else -1
		our_start_cost = found[0][gs] if gs >= 0 else Routes.INF
		return
	var eln := _enemy_lane(w, bot)
	if eln >= 0 and _due(w, "theirs", int(cfg.their_every)):
		var efrom := _open_near(m, eln, m.cell_of(hx, hy))
		var es := _enemy_start(w, bot, hx, hy)
		if efrom < 0 or es.x < 0:
			_done["theirs"] = w.tick
			return
		var found := _search(w, "theirs", m.walks[eln], efrom, func(): return Routes.prices(w, eln))
		if found.is_empty():
			return
		_done["theirs"] = w.tick
		var g := Routes.cheapest(found, Routes.ring_round(m, m.walks[eln], es.x / 1000, es.y / 1000, 3))
		their_cost = found[0][g] if g >= 0 else Routes.INF
		_key_from(w, Routes.path(found, g) if g >= 0 else PackedInt32Array())
		return
	# Bridges: one what-if each (a standing one gone, for them; a broken one back, for us).
	for k in w.bridge_id.size():
		var name := "bridge%d" % k
		if not _due(w, name, int(cfg.bridge_every)):
			continue
		if w.bridge_up[k] == 1:
			var why := _may_cut(w, bot, army)
			if eln < 0 or their_cost >= Routes.INF or why == 0:
				cut.erase(k)
				_done[name] = w.tick
				continue
			var es := _enemy_start(w, bot, hx, hy)
			var efrom := _open_near(m, eln, m.cell_of(hx, hy))
			var cells: PackedInt32Array = w.bridge_cells[k]
			var found := _search(w, name, m.walks[eln], efrom, func():
				var price := Routes.prices(w, eln)
				for c in cells:
					price[c] = 0
				return price)
			if found.is_empty():
				return
			_done[name] = w.tick
			cut.erase(k)
			var g := Routes.cheapest(found, Routes.ring_round(m, m.walks[eln], es.x / 1000, es.y / 1000, 3))
			var without: int = found[0][g] if g >= 0 else Routes.INF
			if without >= Routes.INF or without * 100 >= their_cost * (100 + int(cfg.cut_pct)):
				cut[k] = true
		else:
			var es := _enemy_start(w, bot, hx, hy)
			if (_broke.has(k) and our_start_cost < Routes.INF) or es.x < 0:
				mend.erase(k)   # (we broke it to cut their way: it stays down while we can get round)
				_done[name] = w.tick
				continue
			var cells: PackedInt32Array = w.bridge_cells[k]
			var found := _search(w, name, m.walks[ln], from, func():
				var price := Routes.prices(w, ln)
				for c in cells:
					price[c] = Routes.STEP   # (as if it stood again)
				return price)
			if found.is_empty():
				return
			_done[name] = w.tick
			mend.erase(k)
			var g := Routes.cheapest(found, Routes.ring_round(m, m.walks[ln], es.x / 1000, es.y / 1000, 3))
			var with: int = found[0][g] if g >= 0 else Routes.INF
			if with < Routes.INF and (our_start_cost >= Routes.INF or with * 100 <= our_start_cost * (100 - int(cfg.mend_pct))):
				mend[k] = true
		return
	if _due(w, "detour", int(cfg.detour_every)) and not our_path.is_empty():
		var d := _detour(w, bot, ln, from, goal)
		if d.y == -2:
			return   # (still searching)
		_done["detour"] = w.tick
		detour = d
		return
	if bot._aln % 3 == 1 and _due(w, "flank", int(cfg.flank_every)) and not our_path.is_empty():
		var f := _off_route(w, ln, from, goal, our_path, int(cfg.flank_apart), int(cfg.flank_pct))   # (amphibious: lane class 1)
		if f.y == -2:
			return
		_done["flank"] = w.tick
		flank = f
		return
	if roads < int(cfg.road.max) and road.is_empty() and workers.size() >= int(cfg.road.workers) and _due(w, "road", int(cfg.road.every)):
		_plan_road(w, bot, hx, hy)


## The enemy army's lane (their spear's movement class in their team's lane), or -1.
func _enemy_lane(w, bot) -> int:
	var es := -1
	for p in w.races.size():
		if w.is_enemy(bot.player, p) and w.defeated[p] == 0:
			es = p
			break
	if es < 0:
		return -1
	var k: int = w.type_of(es, "spear")
	return w.lane_base[es] + (w.types[k].mclass if k >= 0 else 0)


## The nearest live enemy's start, in milli-tiles, or (-1, -1).
func _enemy_start(w, bot, hx: int, hy: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	for p in w.races.size():
		if w.is_enemy(bot.player, p) and w.defeated[p] == 0 and p < w.map.starts.size():
			var s := Vector2i(int(w.map.starts[p][0]), int(w.map.starts[p][1]))
			if best.x < 0 or Fixed.dist2(hx, hy, s.x, s.y) < Fixed.dist2(hx, hy, best.x, best.y):
				best = s
	return best


## The open cell of lane ln within 3 of `cell` nearest (tx, ty) in cells (the side of home that
## faces there: where workers set out from), or -1.
static func _open_toward(m, ln: int, cell: int, tx: int, ty: int) -> int:
	var walk: PackedByteArray = m.walks[ln]
	var best := -1
	var best_d := 1 << 30
	for y in range(maxi(0, cell / m.width - 3), mini(m.height, cell / m.width + 4)):
		for x in range(maxi(0, cell % m.width - 3), mini(m.width, cell % m.width + 4)):
			var d: int = (x - tx) * (x - tx) + (y - ty) * (y - ty)
			if walk[y * m.width + x] == 1 and d < best_d:
				best_d = d
				best = y * m.width + x
	return best if best >= 0 else _open_near(m, ln, cell)


## An open cell of lane ln at or near `cell` (rings out to 4), or -1.
static func _open_near(m, ln: int, cell: int) -> int:
	var walk: PackedByteArray = m.walks[ln]
	var cx: int = cell % m.width
	var cy: int = cell / m.width
	for r in 5:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var x := cx + dx
				var y := cy + dy
				if x >= 0 and y >= 0 and x < m.width and y < m.height and walk[y * m.width + x] == 1:
					return y * m.width + x
	return -1


## The crossing their way uses nearest us (the path runs from our home out): the key crossing,
## and the cell on our side where it comes off it.
func _key_from(w, p: PackedInt32Array) -> void:
	key = -1
	key_side = -1
	var on := {}
	for k in _crossings.size():
		for c in _crossings[k][2]:
			on[c] = k
	for n in p.size():
		if on.has(p[n]):
			key = on[p[n]]
			key_side = p[maxi(0, n - 1)]
			return


## Why we may cut their way, once they have an army that would use it (cut_enemy population or
## more remembered): 2, we swim (our way doesn't need bridges); 1, they outnumber us
## (defend_pct); 0, no reason (a bridge isn't broken against a side with no army).
func _may_cut(w, bot, army: Array) -> int:
	var theirs := 0
	for s in bot.scout.soldiers():
		theirs += int(w.types[s[0]].pop)
	if theirs < int(cfg.cut_enemy):
		return 0
	if bot._aln % 3 == 1:
		return 2
	return 1 if _defending(w, bot, army) else 0


## Are we on the back foot: the enemy soldiers we remember outnumber ours by defend_pct?
func _defending(w, bot, army: Array) -> bool:
	var ours := 0
	for i in army:
		ours += int(w.types[w.units.kind[i]].pop)
	var theirs := 0
	for s in bot.scout.soldiers():
		theirs += int(w.types[s[0]].pop)
	return theirs * 100 > ours * int(cfg.defend_pct)


## Round enemy fire over our way: cells under remembered enemy shooters standing above them (archers
## on a hill, within their reach) and under the enemy's towers we remember (fog memory; not the
## ones by the target: those are what the wave is for) cost under_fire more. If our path crosses
## any, a route that keeps out from under them, if it's no more than detour_pct longer: the
## waypoint where it strays furthest from our path. (-1, -1): none needed; (-1, -2): still searching.
func _detour(w, bot, ln: int, from: int, goal: PackedInt32Array) -> Vector2i:
	var m = w.map
	var extra := PackedInt32Array()
	extra.resize(m.width * m.height)
	var any := false
	if m.has_heights:
		for s in bot.scout.soldiers():
			var t: Dictionary = w.types[s[0]]
			if not t.ranged:
				continue
			var c: int = m.cell_of(s[2], s[3])
			var lv: int = m.level[c] + (1 if m.ramp[c] == 1 else 0)
			if lv <= 0:
				continue
			var r: int = int(t.reach) / 1000 + 2
			for y in range(maxi(0, c / m.width - r), mini(m.height, c / m.width + r + 1)):
				for x in range(maxi(0, c % m.width - r), mini(m.width, c % m.width + r + 1)):
					var q: int = y * m.width + x
					if m.level[q] < lv:
						extra[q] = int(cfg.under_fire)
	var seen: Dictionary = w.fog_seen[bot.player]
	var ids: Array = seen.keys()
	ids.sort()
	var keep: int = int(cfg.target_tiles)
	for id in ids:
		var s: PackedInt32Array = seen[id]
		var t: Dictionary = w.btypes[s[0]]
		if not w.is_enemy(bot.player, s[1]) or t.attack.is_empty() or s[5] == 0:
			continue
		var cx: int = s[2] + s[4] / 2
		var cy: int = s[3] + s[8] / 2
		if absi(cx * 1000 + 500 - target.x) <= keep * 1000 and absi(cy * 1000 + 500 - target.y) <= keep * 1000:
			continue   # (by the target: that's what the wave is for)
		var r: int = int(t.attack.range) + 1 + maxi(s[4], s[8]) / 2
		for y in range(maxi(0, cy - r), mini(m.height, cy + r + 1)):
			for x in range(maxi(0, cx - r), mini(m.width, cx + r + 1)):
				if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
					extra[y * m.width + x] = int(cfg.under_fire)
	for c in our_path:
		if extra[c] > 0:
			any = true
			break
	if not any:
		return Vector2i(-1, -1)
	var found := _search(w, "detour", m.walks[ln], from, func():
		var price := Routes.prices(w, ln)
		for c in price.size():
			if price[c] > 0:
				price[c] += extra[c]
		return price)
	if found.is_empty():
		return Vector2i(-1, -2)
	var g := Routes.cheapest(found, goal)
	if g < 0:
		return Vector2i(-1, -1)
	var p := Routes.path(found, g)
	var plain := 0   # the new way's length without the danger price
	for n in range(1, p.size()):
		plain += Routes.STEP if p[n] % m.width == p[n - 1] % m.width or p[n] / m.width == p[n - 1] / m.width else Routes.STEP * 14 / 10
	if plain * 100 > our_cost * (100 + int(cfg.detour_pct)):
		return Vector2i(-1, -1)
	return _furthest(m, p, our_path, 3)


## A second way to the goal kept `apart` cells off `path` (a flank), no more than pct longer:
## its waypoint furthest from the path, or (-1, -1); (-1, -2) while its search runs.
func _off_route(w, ln: int, from: int, goal: PackedInt32Array, path: PackedInt32Array, apart: int, pct: int) -> Vector2i:
	var m = w.map
	var found := _search(w, "flank", m.walks[ln], from, func():
		var price := Routes.prices(w, ln)
		var near := PackedByteArray()
		near.resize(m.width * m.height)
		for c in path.slice(path.size() / 5, path.size() * 4 / 5):   # (both ends are shared: home and the target)
			for y in range(maxi(0, c / m.width - apart), mini(m.height, c / m.width + apart + 1)):
				for x in range(maxi(0, c % m.width - apart), mini(m.width, c % m.width + apart + 1)):
					near[y * m.width + x] = 1
		for c in price.size():
			if near[c] == 1 and price[c] > 0:
				price[c] += Routes.STEP * 4
		return price)
	if found.is_empty():
		return Vector2i(-1, -2)
	var g := Routes.cheapest(found, goal)
	if g < 0:
		return Vector2i(-1, -1)
	var p := Routes.path(found, g)
	if p.size() * 100 > path.size() * (100 + pct):
		return Vector2i(-1, -1)
	return _furthest(m, p, path, apart)


## The cell of p furthest (Chebyshev) from every cell of `from`, as a point, if at least `min_d`.
static func _furthest(m, p: PackedInt32Array, from: PackedInt32Array, min_d: int) -> Vector2i:
	var best := -1
	var best_d := -1
	for c in p:
		var d := 1 << 20
		for q in from:
			d = mini(d, maxi(absi(c % m.width - q % m.width), absi(c / m.width - q / m.width)))
		if d > best_d:
			best_d = d
			best = c
	if best < 0 or best_d < min_d:
		return Vector2i(-1, -1)
	return Vector2i(best % m.width * 1000 + 500, best / m.width * 1000 + 500)


# ------------------------------------------------------------------ roads

## Where a few trees stand between us and a much shorter way out across the map (the walk to
## somewhere beyond road.far tiles winds round a wood a road would cut straight through), the
## trees on our side (nearer home than the enemy's start, by road.side_pct). Two searches for our
## workers from the side of home facing the middle (walking, and with trees at a price; on two
## thinks, one each); the cell with the biggest saving (at least road.save tiles and
## road.pct percent, one to road.trees trees) gives the road: the trees on its way.
func _plan_road(w, bot, hx: int, hy: int) -> void:
	var m = w.map
	var ln: int = bot.eco.wln
	var from := _open_toward(m, ln, m.cell_of(hx, hy), m.width / 2, m.height / 2)
	if from < 0:
		return
	var rc: Dictionary = cfg.road
	if _road_walk.is_empty():
		_road_walk = _search(w, "road_walk", m.walks[ln], from, func(): return Routes.prices(w, ln))
		return   # (the second search on the next studies)
	var es := _enemy_start(w, bot, hx, hy)
	var cut_ := _search(w, "road_cut", m.walks[ln], from, func():
		var price := Routes.prices(w, ln, int(rc.tree))
		for c in price.size():   # only trees on our side of the map: workers don't cut roads by the enemy's door
			if price[c] == int(rc.tree) and m.walks[ln][c] == 0 and es.x >= 0:
				var x: int = c % m.width * 1000 + 500
				var y: int = c / m.width * 1000 + 500
				if Fixed.dist2(x, y, hx, hy) * 100 > Fixed.dist2(x, y, es.x, es.y) * int(rc.side_pct):
					price[c] = 0
		return price)
	if cut_.is_empty():
		return
	_done["road"] = w.tick
	var walk := _road_walk
	_road_walk = []
	var goals := PackedInt32Array()   # every open cell of ours beyond `far` tiles (a winding way anywhere out there)
	var far: int = int(rc.far)
	for c in m.width * m.height:
		if m.walks[ln][c] == 1 and absi(c % m.width - hx / 1000) + absi(c / m.width - hy / 1000) >= far:
			goals.append(c)
	var best := -1
	var best_save := 0
	for g in goals:
		var a: int = walk[0][g]
		var b: int = cut_[0][g]
		if b >= Routes.INF or a >= Routes.INF or a <= b:
			continue   # (ground only trees lead to isn't a shortcut, it's new land: not ours to clear)
		var save: int = a - b
		if save >= int(rc.save) * Routes.STEP and save * 100 >= a * int(rc.pct) and save > best_save:
			var trees := 0
			for c in Routes.path(cut_, g):
				if m.walks[ln][c] == 0:
					trees += 1
			if trees >= 1 and trees <= int(rc.trees):
				best_save = save
				best = g
	if best < 0:
		return
	road = PackedInt32Array()
	for c in Routes.path(cut_, best):
		if m.walks[ln][c] == 0:
			road.append(c)
	roads += 1
	_camp_laid = false
	stats["road_trees"] = int(stats.get("road_trees", 0)) + road.size()
	stats["road_save"] = int(stats.get("road_save", 0)) + best_save / Routes.STEP


## Fell the road: up to road.fellers wood gatherers, each on the nearest standing road tree it
## can get to, kept from other work till the road is open.
func _fell(w, bot, workers: Array) -> void:
	if road.is_empty():
		return
	var m = w.map
	var left := PackedInt32Array()
	for c in road:
		if m.amount[c] > 0:
			left.append(c)
	road = left
	var u = w.units
	fellers = fellers.filter(func(id): return u.index_of(id) >= 0)
	if road.is_empty():
		for id in fellers:
			bot.eco.held.erase(id)
		fellers.clear()
		want = PackedInt32Array()
		return
	var want: int = int(cfg.road.fellers)
	if fellers.size() < want:
		var pool := []
		for i in workers:
			if u.carry_kind[i] == Economy.kind_of(w, "wood") and u.task[i] == Economy.GATHER and not fellers.has(u.id[i]) \
					and int(bot.eco.held.get(u.id[i], 0)) <= w.tick:
				pool.append([Fixed.dist2(u.x[i], u.y[i], road[0] % m.width * 1000, road[0] / m.width * 1000), u.id[i]])
		pool.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		for e in pool.slice(0, want - fellers.size()):
			fellers.append(e[1])
	_road_camp(w, bot)
	for id in fellers:
		var i: int = u.index_of(id)
		bot.eco.held[id] = w.tick + 60
		if (u.task[i] == Economy.GATHER or u.task[i] == Economy.RETURN) and road.has(u.target[i] if u.task[i] == Economy.GATHER else u.home[i]):
			continue
		if u.task[i] == Economy.RETURN or u.task[i] == Economy.BUILD:
			continue   # (taking the last tree's wood home first, or laying the road's camp)
		var area: int = bot.eco.reach.area_of_unit(w, i)
		var best := -1
		var best_d2 := 1 << 62
		var taken := {}   # (each feller on a tree of its own: two sent to one tree are spread to its neighbours)
		for other in fellers:
			var j: int = u.index_of(other)
			if other != id and j >= 0 and u.task[j] == Economy.GATHER:
				taken[u.target[j]] = true
		for c in road:
			var d2 := Fixed.dist2(u.x[i], u.y[i], c % m.width * 1000 + 500, c / m.width * 1000 + 500)
			if d2 < best_d2 and not (taken.has(c) and road.size() > 1) and bot.eco.reach.reaches_cell(w, bot.eco.wln, area, c):
				best_d2 = d2
				best = c
		if best >= 0:
			w.issue(bot.player, Commands.GATHER, {"ids": [id], "cell": best})


## A lumber camp by the road, once, if nothing of ours that takes wood stands within road.camp
## tiles of its first tree (a road out in the woods is felled from a camp, not by walking home):
## the first feller lays it.
func _road_camp(w, bot) -> void:
	if _camp_laid or fellers.is_empty() or road.is_empty():
		return
	var m = w.map
	var x: int = road[0] % m.width
	var y: int = road[0] / m.width
	var r: int = int(cfg.road.camp)
	var bs = w.buildings
	var wood: int = Economy.kind_of(w, "wood")
	for b in bs.count():
		if bs.owner[b] == bot.player and w.btypes[bs.kind[b]].drop[wood - 1] == 1 \
				and absi(bs.cx[b] - x) <= r + 1 and absi(bs.cy[b] - y) <= r + 1:
			_camp_laid = true   # (one stands there, or its foundation)
			want = PackedInt32Array()
			return
	var k: int = Economy.btype_of(w, "lumber_camp")
	if not w.can_afford(bot.player, Economy.bcost(w, bot.player, k)):
		want = Economy.bcost(w, bot.player, k)   # (soldiers leave it alone till it's laid: Bot._train)
		return
	if w.tick < _camp_next:
		return
	_camp_next = w.tick + 200   # (the order lands two turns on: the wood may be gone by then; then again)
	var spot: Vector2i = bot._spot_near(w, Vector2i(x, y), w.btypes[k].size, r, road)
	if spot.x < 0:
		_camp_laid = true   # no room by it: walk home with it
		want = PackedInt32Array()
		return
	w.issue(bot.player, Commands.BUILD, {"ids": [fellers[0]], "building": "lumber_camp", "cx": spot.x, "cy": spot.y})
	count("road_camp")


# ------------------------------------------------------------------ bridges

## Mend a bridge worth mending (two workers, if it's quiet there and we can pay), break one worth
## breaking (melee soldiers idle at home; arrows barely scratch a bridge). Every few seconds.
func _bridges(w, bot, workers: Array, army: Array, hx: int, hy: int) -> void:
	if w.bridge_id.is_empty() or w.tick < _bridge_next:
		return
	_bridge_next = w.tick + 100
	var u = w.units
	for k in w.bridge_id.size():
		var r: Rect2i = w.bridge_rect[k]
		var at := r.get_center()
		if w.bridge_up[k] == 0 and mend.has(k) and (w.bridge_payer[k] < 0 or w.bridge_payer[k] == bot.player) \
				and not _enemies_near(w, bot.player, at, 8000) and (w.bridge_payer[k] == bot.player or w.can_afford(bot.player, w.bridge_cfg.cost)):
			var on := 0
			for i in workers:
				if u.task[i] == Economy.BUILD and u.target[i] == w.bridge_id[k]:
					on += 1
			if on < 2:
				var ids: Array = bot._nearest_workers(w, workers, at.x, at.y, 2 - on)
				if not ids.is_empty():
					w.issue(bot.player, Commands.HELP_BUILD, {"ids": ids, "target": w.bridge_id[k]})
					count("mend")
		if w.bridge_up[k] == 1 and cut.has(k):
			_breakers = _breakers.filter(func(id): return u.index_of(id) >= 0 and u.foe[u.index_of(id)] == w.bridge_id[k])
			if _breakers.size() >= int(cfg.breakers) or bot.assault:
				continue
			var pool := []
			for i in army:
				var t: Dictionary = w.types[u.kind[i]]
				if t.ranged or u.foe[i] != 0 or bot.expand.escorts.has(u.id[i]) or Fixed.dist2(hx, hy, u.x[i], u.y[i]) > 400 * 1000000:
					continue
				pool.append([Fixed.dist2(u.x[i], u.y[i], at.x, at.y), u.id[i]])
			pool.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
			var ids: Array = pool.slice(0, int(cfg.breakers) - _breakers.size()).map(func(e): return e[1])
			if ids.size() + _breakers.size() >= int(cfg.breakers) / 2 and not ids.is_empty():
				w.issue(bot.player, Commands.ATTACK, {"ids": ids, "target": w.bridge_id[k]})
				_breakers.append_array(ids)
				_broke[k] = true
				count("break")


static func _enemies_near(w, player: int, at: Vector2i, r: int) -> bool:
	for i in w.units.count():
		if w.is_foe(player, w.units.owner[i]) and not w.types[w.units.kind[i]].worker and Fog.visible(w, player, w.units.x[i], w.units.y[i]) \
				and Fixed.dist2(at.x, at.y, w.units.x[i], w.units.y[i]) <= r * r:
			return true
	return false


# ------------------------------------------------------------------ hills

## Ranged soldiers meeting an army (hills.army enemy soldiers within hills.near tiles) step up onto
## the nearest higher ground within hills.tiles that they can get to (back a step or two onto a
## hill is the point: they shoot further down and the foe climbs into them), no lower than the
## enemy stands (a plain move: an attack-move would stop to shoot at the foot), and shoot from
## there. Each at most every hills.every seconds.
func _hills(w, bot, army: Array) -> void:
	var m = w.map
	var h: Dictionary = cfg.hills
	if not m.has_heights or w.tick % (int(h.every_check) * 20) != bot._phase():
		return
	for id in climbing.keys():
		if int(climbing[id]) <= w.tick:
			climbing.erase(id)
	var u = w.units
	var foes := []
	for i in u.count():
		if w.is_foe(bot.player, u.owner[i]) and not w.types[u.kind[i]].worker and not w.types[u.kind[i]].has("animal") \
				and Fog.visible(w, bot.player, u.x[i], u.y[i]):
			foes.append(i)
	if foes.size() < int(h.army):
		return
	var near: int = int(h.near) * 1000
	var orders := {}   # cell -> ids
	for i in army:
		var t: Dictionary = w.types[u.kind[i]]
		if not t.ranged or int(_hill_next.get(u.id[i], 0)) > w.tick or bot.expand.escorts.has(u.id[i]):
			continue
		var close := 0
		var top := 0
		for j in foes:
			if Fixed.dist2(u.x[i], u.y[i], u.x[j], u.y[j]) <= near * near:
				close += 1
				top = maxi(top, m.level_at(u.x[j], u.y[j]))
		if close < int(h.army):
			continue
		var here: int = m.level_at(u.x[i], u.y[i])
		if here > top:
			continue   # above them already
		var best := _climb(m, m.walks[w.lane(i)], m.cell_of(u.x[i], u.y[i]), here, top, int(h.tiles))
		_hill_next[u.id[i]] = w.tick + int(h.every) * 20
		if best >= 0:
			climbing[u.id[i]] = w.tick + int(h.every) * 20
			if not orders.has(best):
				orders[best] = []
			orders[best].append(u.id[i])
	var cells: Array = orders.keys()
	cells.sort()
	for c in cells:
		w.issue(bot.player, Commands.MOVE, {"ids": orders[c], "x": c % m.width * 1000 + 500, "y": c / m.width * 1000 + 500})
		count("hill")


## The nearest cell (by steps walked, 4-neighbour, at most 2 * r steps within r + 2 cells) of open
## ground above `here` and no lower than `top`, off the ramps: where to climb to. -1: none.
static func _climb(m, walk: PackedByteArray, from: int, here: int, top: int, r: int) -> int:
	var x0: int = maxi(0, from % m.width - r - 2)
	var y0: int = maxi(0, from / m.width - r - 2)
	var x1: int = mini(m.width - 1, from % m.width + r + 2)
	var y1: int = mini(m.height - 1, from / m.width + r + 2)
	var steps := {from: 0}
	var queue := [from]
	var head := 0
	while head < queue.size():
		var c: int = queue[head]
		head += 1
		if m.level[c] > here and m.level[c] >= top and m.ramp[c] == 0 and walk[c] == 1:
			return c
		if int(steps[c]) >= 2 * r:
			continue
		for d in 4:
			var x: int = c % m.width + Routes.DX[d]
			var y: int = c / m.width + Routes.DY[d]
			var n: int = y * m.width + x
			if x < x0 or y < y0 or x > x1 or y > y1 or walk[n] == 0 or steps.has(n):
				continue
			steps[n] = int(steps[c]) + 1
			queue.append(n)
	return -1


# ------------------------------------------------------------------ guarding the crossing

## The spot for a Watchtower guarding the key crossing on our side (by where their way comes off
## it), or (-1, -1) when there's none, it's over guard_range tiles from home, or one of ours already
## stands within guard_tiles of it.
func guard_spot(w, bot) -> Vector2i:
	if key < 0 or key_side < 0:
		return Vector2i(-1, -1)
	var m = w.map
	var x: int = key_side % m.width
	var y: int = key_side / m.width
	var tc: int = bot.eco._town_center(w)
	var far: int = int(cfg.guard_range)
	if tc >= 0 and maxi(absi(w.buildings.cx[tc] + 1 - x), absi(w.buildings.cy[tc] + 1 - y)) > far:
		return Vector2i(-1, -1)   # (a crossing out by the enemy's side isn't ours to hold)
	var r: int = int(cfg.guard_tiles)
	for b in w.buildings.count():
		var id: String = w.btypes[w.buildings.kind[b]].id
		if w.buildings.owner[b] == bot.player and (id == "watchtower" or id == "bastion" or id == "castle") \
				and absi(w.buildings.cx[b] - x) <= r and absi(w.buildings.cy[b] - y) <= r:
			return Vector2i(-1, -1)
	return Vector2i(x, y)


## Is unit i one of ours at work breaking a bridge (kept out of the waves meanwhile)?
func breaking(w, i: int) -> bool:
	return _breakers.has(w.units.id[i]) and w.units.foe[i] != 0 and w.bridge_id.has(w.units.foe[i])


## Count something done (stats).
func count(what: String) -> void:
	stats[what] = int(stats.get(what, 0)) + 1


## Is unit i on its way up a hill (a hill order in the last hills.every seconds)?
func is_climbing(w, i: int) -> bool:
	return int(climbing.get(w.units.id[i], 0)) > w.tick
