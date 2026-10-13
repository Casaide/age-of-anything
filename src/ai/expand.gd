extends RefCounted
## Reaching out for resources (milestone 15 phase 7). As the near patches are worked out the
## economy sends workers further (EcoBot takes the nearest it can reach), and the walk home grows:
## - camps follow the workers: when a few gatherers of a resource work further than camp_tiles
##   from anything that takes it, a camp (or a mill, for food) goes up by them;
## - escorts: a knot of our gatherers out beyond guard_tiles from the Town Center (contested
##   ground, a far wood) gets a few soldiers posted with them (from age 2, an army big enough to
##   spare them), who stay out of the attack waves;
## - a second Town Center (the build order's step, laid on our side of the map) comes earlier
##   on a big map, or once home runs thin (town: workers then).
## Data: data/ai.json "expand". Commands only; integers; deterministic.

const Fixed := preload("res://src/sim/fixed.gd")
const Commands := preload("res://src/sim/commands.gd")
const Economy := preload("res://src/sim/economy.gd")

var cfg: Dictionary
var escorts := {}            # soldier id -> post (Vector2i, milli-tiles)
var _next_camp := 0
var want := PackedInt32Array()   # the cost of a camp wanted but not yet affordable (soldiers leave it alone)
var _next_post := 0
var stats := {}              # what it did (tests, reports): name -> count


func _init(p_cfg: Dictionary) -> void:
	cfg = p_cfg


func think(w, bot, tc: int, workers: Array, army: Array, hx: int, hy: int) -> void:
	_camps(w, bot, workers)
	_escort(w, bot, workers, army, hx, hy)


## Our finished (or going up) buildings that take resource `kind` (1-based).
static func _drops(w, player: int, kind: int) -> Array:
	var out := []
	var bs = w.buildings
	for b in bs.count():
		if bs.owner[b] == player and w.btypes[bs.kind[b]].drop[kind - 1] == 1:
			out.append(b)
	return out


## How far (tiles, the larger axis) a cell is from the nearest of `drops`.
static func _walk(w, drops: Array, cell: int) -> int:
	var bs = w.buildings
	var x: int = cell % w.map.width
	var y: int = cell / w.map.width
	var best := 1 << 20
	for b in drops:
		var dx: int = maxi(maxi(bs.cx[b] - x, 0), x - (bs.cx[b] + bs.sx[b] - 1))
		var dy: int = maxi(maxi(bs.cy[b] - y, 0), y - (bs.cy[b] + bs.sy[b] - 1))
		best = mini(best, maxi(dx, dy))
	return best


## A camp by the gatherers walking furthest: per resource (cfg.camps: resource -> building), the
## gatherers whose patch is over camp_tiles from any drop-off; with camp_workers or more, a camp
## by the one in the middle of them (the patch with the least walk to the others), one at a time.
## One it can't pay for yet is `want`ed: the soldiers leave its cost alone till it's laid.
func _camps(w, bot, workers: Array) -> void:
	if bot._saving_age:
		want = PackedInt32Array()
		return   # (not while every bit goes to the next age)
	if w.tick < _next_camp or bot.eco._building_underway(w):
		return
	_next_camp = w.tick + int(cfg.camp_every) * 20
	want = PackedInt32Array()
	var u = w.units
	var camps: Dictionary = cfg.camps
	var names: Array = camps.keys()
	names.sort()
	for res in names:
		var kind: int = Economy.kind_of(w, res)
		var k: int = Economy.btype_of(w, camps[res])
		if kind <= 0 or k < 0 or Economy.why_not_build(w, bot.player, k) != "":
			continue
		var drops := _drops(w, bot.player, kind)
		var far := []   # [patch cell, worker index]
		for i in workers:
			if (u.task[i] == Economy.GATHER or u.task[i] == Economy.RETURN) and u.carry_kind[i] == kind and u.home[i] >= 0 \
					and w.map.pool[u.home[i]] < 0 and _walk(w, drops, u.home[i]) > int(cfg.camp_tiles):
				far.append([u.home[i], i])
		if far.size() < int(cfg.camp_workers):
			continue
		var mid: int = far[0][0]
		var least := 1 << 62
		for a in far:
			var sum := 0
			for b in far:
				sum += Fixed.dist2(a[0] % w.map.width, a[0] / w.map.width, b[0] % w.map.width, b[0] / w.map.width)
			if sum < least or (sum == least and a[0] < mid):
				least = sum
				mid = a[0]
		var spot: Vector2i = bot.eco._house_spot(w, mid % w.map.width, mid / w.map.width, w.btypes[k].size)
		if spot.x < 0 or _walk(w, drops, spot.y * w.map.width + spot.x) <= int(cfg.camp_tiles) / 2:
			continue   # (no room, or it'd stand by a drop-off we have)
		if not w.can_afford(bot.player, Economy.bcost(w, bot.player, k)):
			want = Economy.bcost(w, bot.player, k)   # soldiers leave its cost alone till it's laid (Bot._train)
			_next_camp = w.tick + 100
			return
		far.sort_custom(func(a, b): return Fixed.dist2(a[0] % w.map.width, a[0] / w.map.width, spot.x, spot.y) < Fixed.dist2(b[0] % w.map.width, b[0] / w.map.width, spot.x, spot.y) \
				or (Fixed.dist2(a[0] % w.map.width, a[0] / w.map.width, spot.x, spot.y) == Fixed.dist2(b[0] % w.map.width, b[0] / w.map.width, spot.x, spot.y) and a[1] < b[1]))
		var ids := far.slice(0, int(cfg.camp_builders)).map(func(e): return u.id[e[1]])
		w.issue(bot.player, Commands.BUILD, {"ids": ids, "building": camps[res], "cx": spot.x, "cy": spot.y})
		stats[camps[res]] = int(stats.get(camps[res], 0)) + 1
		return


## Soldiers posted with our far gatherers: knots of escort_workers or more gatherers out beyond
## guard_tiles get escort soldiers each (up to posts knots), nearest idle ones at home first; a
## post with fewer than half its gatherers left is given up (they rejoin the army).
func _escort(w, bot, workers: Array, army: Array, hx: int, hy: int) -> void:
	var u = w.units
	for id in escorts.keys():   # gone, or hacking at an enemy building (a wall by the far wood): back to the army
		var i: int = u.index_of(id)
		if i < 0 or (u.foe[i] != 0 and w.buildings.index_of(u.foe[i]) >= 0):
			escorts.erase(id)
	if w.tick < _next_post:
		return
	_next_post = w.tick + int(cfg.post_every) * 20
	var guard: int = int(cfg.guard_tiles) * 1000
	var out := []   # far gatherers' patches
	for i in workers:
		if (u.task[i] == Economy.GATHER or u.task[i] == Economy.RETURN) and u.home[i] >= 0:
			var c: int = u.home[i]
			if Fixed.dist2(hx, hy, c % w.map.width * 1000 + 500, c / w.map.width * 1000 + 500) > guard * guard:
				out.append(c)
	# Posts still worth keeping: enough gatherers within post_tiles of them.
	var r: int = int(cfg.post_tiles) * 1000
	var posts := {}
	for id in escorts:
		posts[escorts[id]] = true
	var keys: Array = posts.keys()
	keys.sort()
	for p in keys:
		var n := out.filter(func(c): return Fixed.dist2(p.x, p.y, c % w.map.width * 1000 + 500, c / w.map.width * 1000 + 500) <= r * r).size()
		if n * 2 < int(cfg.escort_workers):
			for id in escorts.keys():
				if escorts[id] == p:
					escorts.erase(id)
			posts.erase(p)
	# A new post by the biggest knot without one.
	var size := 0
	for i in army:
		size += int(w.types[u.kind[i]].pop)
	if w.ages[bot.player] >= int(cfg.escort_age) and size >= int(cfg.escort_army) and posts.size() < int(cfg.posts) and bot._threats.is_empty():
		var best := -1
		var most := 0
		for c in out:
			var at := Vector2i(c % w.map.width * 1000 + 500, c / w.map.width * 1000 + 500)
			if posts.keys().any(func(p): return Fixed.dist2(p.x, p.y, at.x, at.y) <= 4 * r * r) or _by_enemy(w, bot, at, r):
				continue
			var n := out.filter(func(d): return Fixed.dist2(at.x, at.y, d % w.map.width * 1000 + 500, d / w.map.width * 1000 + 500) <= r * r).size()
			if n > most or (n == most and c < best):
				most = n
				best = c
		if best >= 0 and most >= int(cfg.escort_workers):
			var at := Vector2i(best % w.map.width * 1000 + 500, best / w.map.width * 1000 + 500)
			var pool := []
			for i in army:
				var t: Dictionary = w.types[u.kind[i]]
				if u.foe[i] != 0 or escorts.has(u.id[i]) or Fixed.dist2(hx, hy, u.x[i], u.y[i]) > 400 * 1000000 \
						or t.get("buildings_only", false) or t.get("splash", 0) > 0:
					continue   # (an engine guards nobody)
				pool.append([Fixed.dist2(at.x, at.y, u.x[i], u.y[i]), u.id[i]])
			pool.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
			for e in pool.slice(0, int(cfg.escort)):
				escorts[e[1]] = at
			if not pool.is_empty():
				stats["posts"] = int(stats.get("posts", 0)) + 1
	# Escorts away from their post (sent, or chased something off) walk back to it.
	var back := {}
	var ids: Array = escorts.keys()
	ids.sort()
	for id in ids:
		var i: int = u.index_of(id)
		var p: Vector2i = escorts[id]
		if u.foe[i] == 0 and u.moving[i] == 0 and Fixed.dist2(p.x, p.y, u.x[i], u.y[i]) > 9 * 1000000:
			if not back.has(p):
				back[p] = []
			back[p].append(id)
	for p in back:
		w.issue(bot.player, Commands.ATTACK_MOVE, {"ids": back[p], "x": p.x, "y": p.y})


## Is an enemy building we remember (fog memory) within r of this spot? A post there would only
## chew on it (their wall beside the wood), not guard anyone.
static func _by_enemy(w, bot, at: Vector2i, r: int) -> bool:
	var seen: Dictionary = w.fog_seen[bot.player]
	for id in seen:   # (any one is enough: the order doesn't matter)
		var s: PackedInt32Array = seen[id]
		if w.is_enemy(bot.player, s[1]) and Fixed.dist2(at.x, at.y, s[2] * 1000 + s[4] * 500, s[3] * 1000 + s[8] * 500) <= r * r:
			return true
	return false


## Does the second Town Center come early: on a big map (big_map tiles wide or more), or once
## home is thin (under thin.<resource> left within thin.tiles of our Town Center, any of them)?
func wants_town(w, hx: int, hy: int) -> bool:
	if w.map.width >= int(cfg.town.big_map):
		return true
	var t: Dictionary = cfg.town.thin
	var r: int = int(t.tiles) * 1000
	var left := {}
	var m = w.map
	for c in m.resource_cells:
		var res: String = m.terrain_resource[m.terrain[c]]
		if m.amount[c] <= 0 or not t.has(res) or m.pool[c] >= 0:
			continue
		if Fixed.dist2(hx, hy, c % m.width * 1000 + 500, c / m.width * 1000 + 500) <= r * r:
			left[res] = int(left.get(res, 0)) + m.amount[c]
	for res in t:
		if res != "tiles" and int(left.get(res, 0)) < int(t[res]):
			return true
	return false
