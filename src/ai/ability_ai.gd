extends RefCounted
## The bot's use of its race's ability (milestone 14, src/sim/abilities.gd), like a player would,
## once a second, through the ABILITY command. Deterministic: units in slot order, ties by id.
##   web: thrown on the enemy soldier nearest one of our ready users, within its range, that we
##        can see; melee foes first (a web stops a charge; shooters stand off anyway).

const Commands := preload("res://src/sim/commands.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const Fog := preload("res://src/sim/fog.gd")
const Abilities := preload("res://src/sim/abilities.gd")


static func think(w, player: int, army: Array) -> void:
	var ab: Dictionary = Abilities.of(w, player)
	if ab.is_empty():
		return
	match ab.kind:
		"web":
			_web(w, player, army, ab)


static func _web(w, player: int, army: Array, ab: Dictionary) -> void:
	var u = w.units
	var reach: int = int(ab.range)
	var best := -1
	var best_score := 1 << 62
	var by := -1
	for i in army:
		if not Abilities.can_use(w, u.kind[i]) or Abilities.wait(w, i) > 0:
			continue
		for j in u.count():
			var t: Dictionary = w.types[u.kind[j]]
			if not w.is_foe(player, u.owner[j]) or t.worker or t.has("animal") or not Fog.visible(w, player, u.x[j], u.y[j]):
				continue
			var d := Fixed.dist2(u.x[i], u.y[i], u.x[j], u.y[j])
			if d > reach * reach:
				continue
			var score: int = d + (0 if not t.ranged else reach * reach)   # melee first
			if score < best_score:
				best_score = score
				best = j
				by = i
	if best >= 0:
		w.issue(player, Commands.ABILITY, {"ids": [u.id[by]], "x": u.x[best], "y": u.y[best]})
