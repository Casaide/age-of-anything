extends RefCounted
## Winning and losing. A player who started with a Town Center is out once they have none
## left (finished or not), or when they surrender. When only one team has players left,
## that team wins. Checked once a second; part of the sim state, so it's deterministic.

const Economy := preload("res://src/sim/economy.gd")

const CHECK_EVERY := 20   # ticks


## Who has a Town Center at the start (so test setups without one never "lose").
static func setup(w) -> void:
	var tc := Economy.btype_of(w, "town_center")
	w.defeated = PackedInt32Array()
	w.started_with_town = PackedByteArray()
	for p in w.races.size():
		w.defeated.append(0)
		w.started_with_town.append(1 if _towns(w, p, tc) > 0 else 0)


static func cmd_surrender(w, player: int) -> void:
	if w.defeated[player] == 0:
		w.defeated[player] = w.tick + 1
		w.events.append({"type": "defeated", "player": player})


static func tick(w) -> void:
	if w.winner >= 0 or w.tick % CHECK_EVERY != 0:
		return
	var tc := Economy.btype_of(w, "town_center")
	for p in w.races.size():
		if w.defeated[p] == 0 and w.started_with_town[p] == 1 and _towns(w, p, tc) == 0:
			w.defeated[p] = w.tick + 1
			w.events.append({"type": "defeated", "player": p})
	var teams_left := []
	for p in w.races.size():
		if w.defeated[p] == 0 and not w.teams[p] in teams_left:
			teams_left.append(w.teams[p])
	var any_started: bool = w.started_with_town.has(1)
	if any_started and teams_left.size() == 1:
		w.winner = teams_left[0]
		w.events.append({"type": "won", "team": w.winner})


static func _towns(w, player: int, tc: int) -> int:
	var n := 0
	for b in w.buildings.count():
		if w.buildings.owner[b] == player and w.buildings.kind[b] == tc:
			n += 1
	return n
