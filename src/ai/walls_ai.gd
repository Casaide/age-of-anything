extends RefCounted
## The bot and walls you stand on (milestone 16; data/ai.json military.walls). Cheap, every few
## seconds on the bot's own beat, commands only, like a player:
##  - man: with walkway walls of its own, it keeps up to man_pct of its shooters at home up on the
##    wall nearest the nearest enemy it sees (else the wall facing the enemy's start), never more
##    than a cell holds; shooters already up stay (bot.gd's defence leaves them there).
##  - storm: attacking, a docked siege tower of its own (walls.gd) takes the foot soldiers within
##    climb_tiles of it up onto the enemy's wall, and once up they go down the enemy's own stairs
##    at the target (a queued move); an undocked tower is pushed to the enemy walkway cell nearest it.
## Deterministic: ascending slots and ids, ties to the lower cell.

const Walls := preload("res://src/sim/walls.gd")
const Commands := preload("res://src/sim/commands.gd")
const Economy := preload("res://src/sim/economy.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const Fog := preload("res://src/sim/fog.gd")


## Shooters onto our walls. `army`: the field army's slots; (hx, hy): home.
static func man(w, bot, army: Array, hx: int, hy: int) -> void:
	var c: Dictionary = bot.cfg.military.get("walls", {})
	if c.is_empty() or w.tick % (int(c.every) * 20) != bot._phase() or bot.assault:
		return
	var ours := _walkway_cells(w, bot.player, true)
	if ours.is_empty():
		return
	var shooters := []
	var up := 0
	var r := int(bot.cfg.military.defend_tiles) * 2000
	for i in army:
		var t: Dictionary = w.types[w.units.kind[i]]
		if not t.ranged or t.get("splash", 0) > 0 or t.get("pass_len", 0) > 0 or not Walls.can_climb(w, i):
			continue
		if w.units.perch[i] != 0 or (w.units.task[i] == Economy.CLIMB):
			up += 1
		elif w.units.foe[i] == 0 and w.units.moving[i] == 0 and w.units.task[i] == Economy.NONE and Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i]) < r * r:
			shooters.append(i)
	var want: int = (up + shooters.size()) * int(c.man_pct) / 100 - up
	if want <= 0 or shooters.is_empty():
		return
	var threat := _threat(w, bot, hx, hy)
	var best := -1
	var best_d := 1 << 62
	for cell in ours:
		var p := Vector2i((cell % w.map.width) * 1000 + 500, (cell / w.map.width) * 1000 + 500)
		var d := Fixed.dist2(p.x, p.y, threat.x, threat.y)
		if d < best_d:
			best_d = d
			best = cell
	var ids := []
	for k in mini(want, shooters.size()):
		ids.append(w.units.id[shooters[k]])
	w.issue(bot.player, Commands.MOVE, {"ids": ids, "x": (best % w.map.width) * 1000 + 500, "y": (best / w.map.width) * 1000 + 500})


## Over the enemy's wall by our siege towers, while attacking towards `target`.
static func storm(w, bot, army: Array, target: Vector2i) -> void:
	var c: Dictionary = bot.cfg.military.get("walls", {})
	if c.is_empty() or not bot.assault or target.x < 0 or w.tick % (int(c.every) * 20) != bot._phase():
		return
	var theirs := _walkway_cells(w, bot.player, false)
	if theirs.is_empty():
		return
	var near: int = int(c.climb_tiles) * 1000
	for j in army:
		if not w.types[w.units.kind[j]].get("docks", false):
			continue
		var top := Walls.docked_at(w, j)
		if top < 0:
			if w.units.moving[j] == 0:   # push it up to the enemy wall nearest it
				var best := -1
				var best_d := 1 << 62
				for cell in theirs:
					var d := Fixed.dist2(w.units.x[j], w.units.y[j], (cell % w.map.width) * 1000 + 500, (cell / w.map.width) * 1000 + 500)
					if d < best_d:
						best_d = d
						best = cell
				if best >= 0:
					w.issue(bot.player, Commands.MOVE, {"ids": [w.units.id[j]], "x": (best % w.map.width) * 1000 + 500, "y": (best / w.map.width) * 1000 + 500})
			continue
		var ids := []
		for i in army:
			var t: Dictionary = w.types[w.units.kind[i]]
			if t.ranged or not Walls.can_climb(w, i) or w.units.perch[i] != 0 or w.units.task[i] == Economy.CLIMB:
				continue
			var ln: int = w.lane(i)
			if bot.eco.reach.area_at(w, ln, w.units.x[i], w.units.y[i]) == bot.eco.reach.area_at(w, ln, target.x, target.y):
				continue   # already through (or never shut out): no need to climb
			if Fixed.dist2(w.units.x[i], w.units.y[i], w.units.x[j], w.units.y[j]) <= near * near:
				ids.append(w.units.id[i])
		if ids.is_empty():
			continue
		var tx: int = (top % w.map.width) * 1000 + 500
		var ty: int = (top / w.map.width) * 1000 + 500
		w.issue(bot.player, Commands.MOVE, {"ids": ids, "x": tx, "y": ty})
		w.issue(bot.player, Commands.ATTACK_MOVE, {"ids": ids, "x": target.x, "y": target.y, "queue": 1})   # once up: down their stairs and on


## Finished walkway cells of the player's (mine) or of its enemies' that it can see, ascending.
static func _walkway_cells(w, player: int, mine: bool) -> Array:
	var out := []
	var bs = w.buildings
	for b in bs.count():
		if bs.done[b] == 0 or w.btypes[bs.kind[b]].walkway <= 0:
			continue
		var own: bool = bs.owner[b] == player
		if own != mine or (not mine and not w.is_enemy(player, bs.owner[b])):
			continue
		if not mine and not Fog.sees_area(w, player, bs.cx[b], bs.cy[b], bs.sx[b], bs.sy[b], bs.diag[b]):
			continue
		for c in bs.footprint(b, w.map.width):
			out.append(c)
	out.sort()
	return out


## Where trouble is: the nearest enemy (not an animal) we see within defend_tiles x 3 of home, else
## the nearest enemy start.
static func _threat(w, bot, hx: int, hy: int) -> Vector2i:
	var r := int(bot.cfg.military.defend_tiles) * 3000
	var best := Vector2i(-1, -1)
	var best_d := r * r
	for i in w.units.count():
		if not w.is_foe(bot.player, w.units.owner[i]) or w.types[w.units.kind[i]].has("animal") or not Fog.visible(w, bot.player, w.units.x[i], w.units.y[i]):
			continue
		var d := Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i])
		if d < best_d:
			best_d = d
			best = Vector2i(w.units.x[i], w.units.y[i])
	if best.x >= 0:
		return best
	best_d = 1 << 62
	for p in w.races.size():
		if p < w.map.starts.size() and w.is_enemy(bot.player, p):
			var s: Array = w.map.starts[p]
			var d := Fixed.dist2(hx, hy, s[0], s[1])
			if d < best_d:
				best_d = d
				best = Vector2i(s[0], s[1])
	return best
