extends RefCounted
## Winning and losing. A player who started with a Town Center is out once they have none
## left (finished or not), or when they surrender. When only one team has players left,
## that team wins. Checked once a second; part of the sim state, so it's deterministic.
##
## Wonder victory (host rule `wonder`: {victory, hold_seconds}): a finished Wonder starts a
## countdown; when one has stood for hold_seconds and its owner is still in, the owner's team
## wins. A Wonder that falls (or whose owner is out) stops its countdown; one built again
## starts from the top. Every player hears of a Wonder finished and of one fallen (events
## "wonder"), so the countdown is no secret: the view shows it to all, and the bots go for it.

const Modes := preload("res://src/sim/modes.gd")
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
	w.wonder_ids = PackedInt32Array()
	w.wonder_since = PackedInt32Array()
	w.wonder_owners = PackedInt32Array()


static func cmd_surrender(w, player: int) -> void:
	if w.defeated[player] == 0:
		w.defeated[player] = w.tick + 1
		w.events.append({"type": "defeated", "player": player})


static func tick(w) -> void:
	if w.winner >= 0 or w.tick % CHECK_EVERY != 0:
		return
	if not w.mode_cfg.is_empty():
		Modes.tick(w)   # the game mode's own win rules (modes.gd)
	var tc := Economy.btype_of(w, "town_center")
	for p in w.races.size():
		if w.defeated[p] == 0 and w.started_with_town[p] == 1 and _towns(w, p, tc) == 0:
			w.defeated[p] = w.tick + 1
			w.events.append({"type": "defeated", "player": p})
	if _wonders(w):
		return
	var teams_left := []
	for p in w.races.size():
		if w.defeated[p] == 0 and not w.teams[p] in teams_left:
			teams_left.append(w.teams[p])
	var any_started: bool = w.started_with_town.has(1)
	if any_started and teams_left.size() == 1:
		w.winner = teams_left[0]
		w.events.append({"type": "won", "team": w.winner})


## The host rule's hold time in ticks, or 0 with Wonder victory off.
static func hold_ticks(w) -> int:
	var r: Dictionary = w.rules.get("wonder", {})
	if not bool(r.get("victory", false)):
		return 0
	return int(r.hold_seconds) * 20


## Ticks left on the countdown of the k-th standing Wonder (w.wonder_ids order).
static func ticks_left(w, k: int) -> int:
	return maxi(0, w.wonder_since[k] + hold_ticks(w) - w.tick)


## Keep the list of standing finished Wonders (in id order) and their finish ticks; a Wonder
## that has stood long enough wins. True when the match was won here.
static func _wonders(w) -> bool:
	var hold := hold_ticks(w)
	var wk := Economy.btype_of(w, "wonder")
	if hold == 0 or wk < 0:
		return false
	var bs = w.buildings
	var ids := PackedInt32Array()
	var since := PackedInt32Array()
	for b in bs.count():   # (buildings are in id order)
		if bs.kind[b] != wk or bs.done[b] == 0 or w.defeated[bs.owner[b]] != 0:
			continue
		var k: int = w.wonder_ids.find(bs.id[b])
		ids.append(bs.id[b])
		since.append(w.wonder_since[k] if k >= 0 else w.tick)
		if k < 0:
			w.events.append({"type": "wonder", "what": "built", "id": bs.id[b], "player": bs.owner[b],
				"x": bs.cx[b] * 1000 + bs.sx[b] * 500, "y": bs.cy[b] * 1000 + bs.sy[b] * 500})
	for k in w.wonder_ids.size():
		if not w.wonder_ids[k] in ids:
			var b: int = bs.index_of(w.wonder_ids[k])
			w.events.append({"type": "wonder", "what": "fell", "id": w.wonder_ids[k], "player": w.wonder_owners[k],
				"x": bs.cx[b] * 1000 + bs.sx[b] * 500 if b >= 0 else -1, "y": bs.cy[b] * 1000 + bs.sy[b] * 500 if b >= 0 else -1})
	var owners := PackedInt32Array()
	for id in ids:
		owners.append(bs.owner[bs.index_of(id)])
	w.wonder_ids = ids
	w.wonder_since = since
	w.wonder_owners = owners
	# The one that has stood longest wins (lowest id on a tie).
	var best := -1
	for k in ids.size():
		if w.tick - since[k] >= hold and (best < 0 or since[k] < since[best]):
			best = k
	if best < 0:
		return false
	w.winner = w.teams[owners[best]]
	w.events.append({"type": "won", "team": w.winner, "wonder": ids[best]})
	return true


static func _towns(w, player: int, tc: int) -> int:
	var n := 0
	for b in w.buildings.count():
		if w.buildings.owner[b] == player and w.buildings.kind[b] == tc:
			n += 1
	return n
