extends RefCounted
## Trade carts (milestone 13 step 6): the Market trains them; sent to another market, of yours or
## an ally's, a cart walks there and back for good, bringing gold home each round trip. The gold
## grows faster than the distance (rules economy.trade: d * d / sq_div + d * lin_pct / 100, d the
## tiles between the markets' middles), so far markets pay best, as in the genre. A cart picks the
## goods up at the far market (it carries them, `carry` in gold) and is paid on reaching home; one
## killed on the way loses its load. Carts never fight (World._make_type: harmless).
## Static functions over the World `w`, like economy.gd. Integers only, slot order.
##
## State: units.task TRADE, units.target the far market's id, units.route the home market's id,
## units.work 0 on the way out, 1 on the way home; carry_kind gold while loaded.

const SimMap := preload("res://src/sim/sim_map.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const Economy := preload("res://src/sim/economy.gd")

const OUT := 0
const HOME := 1


## {ids, building: the far market}: every cart of the player's among ids takes the route from its
## nearest own finished market (not the far one) there and back. A far market that can't be traded
## with (unfinished, an enemy's, too near) sends the carts walking up to it, nothing more.
static func cmd_route(w, player: int, a: Dictionary) -> void:
	var far: int = w.buildings.index_of(int(a.building))
	if far < 0:
		return
	for uid in a.ids:
		var i: int = w.units.index_of(uid)
		if i < 0 or w.units.owner[i] != player or not w.types[w.units.kind[i]].get("trader", false):
			continue
		var home := nearest_market(w, i, far)
		Economy.clear_task(w, i)
		if home < 0 or why_not(w, player, home, far) != "":
			Economy._approach_building(w, i, far)
			continue
		start(w, i, home, far)


## Put cart i on the route home -> far (building slots), heading out.
static func start(w, i: int, home: int, far: int) -> void:
	var u = w.units
	u.task[i] = Economy.TRADE
	u.route[i] = w.buildings.id[home]
	u.target[i] = w.buildings.id[far]
	u.work[i] = OUT
	Economy._approach_building(w, i, far)


## The reason the player's carts can't trade between these two markets (slots), or "".
static func why_not(w, player: int, home: int, far: int) -> String:
	var bs = w.buildings
	if not _market(w, home) or bs.owner[home] != player:
		return "needs a finished market of yours to start from"
	if not _market(w, far) or w.is_enemy(bs.owner[far], player):
		return "trades only with a finished market of yours or an ally's"
	if home == far or tiles(w, home, far) < int(w.econ.trade.min_tiles):
		return "the markets are too close (%d tiles apart at least)" % int(w.econ.trade.min_tiles)
	return ""


## Tiles between two buildings' middles.
static func tiles(w, a: int, b: int) -> int:
	return Fixed.isqrt(Fixed.dist2(_mid_x(w, a), _mid_y(w, a), _mid_x(w, b), _mid_y(w, b))) / SimMap.TILE


## Gold a round trip between two markets (slots) brings home.
static func trip_gold(w, a: int, b: int) -> int:
	var t: Dictionary = w.econ.trade
	var d := tiles(w, a, b)
	return d * d / int(t.sq_div) + d * int(t.lin_pct) / 100


## The player's finished market nearest cart i, other than `except` (a slot), or -1.
static func nearest_market(w, i: int, except: int) -> int:
	var bs = w.buildings
	var u = w.units
	var best := -1
	var best_d := 0
	for b in bs.count():
		if b == except or bs.owner[b] != u.owner[i] or not _market(w, b):
			continue
		var d := Fixed.dist2(u.x[i], u.y[i], _mid_x(w, b), _mid_y(w, b))
		if best < 0 or d < best_d:
			best = b
			best_d = d
	return best


## One tick of every cart on a route. Runs with the worker jobs (World.step).
static func tick(w) -> void:
	var u = w.units
	for i in u.count():
		if u.task[i] == Economy.TRADE:
			_step(w, i)


static func _step(w, i: int) -> void:
	var u = w.units
	var bs = w.buildings
	var home: int = bs.index_of(u.route[i])
	var far: int = bs.index_of(u.target[i])
	if home < 0 or not _market(w, home) or bs.owner[home] != u.owner[i]:
		Economy.clear_task(w, i)   # nothing to come home to: it stops where it is (its load with it)
		u.route[i] = 0
		u.moving[i] = 0
		return
	if far < 0 or not _market(w, far) or w.is_enemy(bs.owner[far], u.owner[i]):
		u.work[i] = HOME   # the far market fell (or changed hands): home with whatever it has
	var to: int = far if u.work[i] == OUT else home
	if Economy._in_reach(w, i, Economy._building_rect(w, to)):
		u.moving[i] = 0
		u.stuck[i] = 0
		if u.work[i] == OUT:
			u.carry_kind[i] = Economy.kind_of(w, "gold")
			u.carry[i] = trip_gold(w, home, far)
			u.work[i] = HOME
			w.events.append({"type": "trade", "id": u.id[i], "at": bs.id[far], "load": u.carry[i]})
			Economy._approach_building(w, i, home)
		else:
			if u.carry[i] > 0:
				w.stock[u.carry_kind[i] - 1][u.owner[i]] += u.carry[i]
				w.events.append({"type": "trade", "id": u.id[i], "at": bs.id[home], "paid": u.carry[i]})
			u.carry[i] = 0
			u.carry_kind[i] = 0
			if far < 0 or why_not(w, u.owner[i], home, far) != "":
				Economy.clear_task(w, i)   # no far end left: it waits at home
				u.route[i] = 0
				return
			u.work[i] = OUT
			Economy._approach_building(w, i, far)
	elif u.moving[i] == 0:
		Economy._approach_building(w, i, to)   # pushed off its way or given up: on it goes


static func _market(w, b: int) -> bool:
	return w.buildings.done[b] == 1 and w.btypes[w.buildings.kind[b]].id == "market"


static func _mid_x(w, b: int) -> int:
	return w.buildings.cx[b] * SimMap.TILE + w.buildings.sx[b] * SimMap.TILE / 2


static func _mid_y(w, b: int) -> int:
	return w.buildings.cy[b] * SimMap.TILE + w.buildings.sy[b] * SimMap.TILE / 2
