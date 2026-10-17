extends Node
## The battle setup shared over the network (networking milestone): the host's setup screen is the
## lobby. The host listens and broadcasts from the moment it opens; every side but the host's starts
## as an AI, and a player who joins takes one (any open side, so they pick their team, and can move
## while another is open). Each player edits their own side's race; the host the map, the mode and the
## AI sides. The host holds the lobby and sends the whole of it to everyone whenever it changes; a
## change un-readies everyone. When every player is ready (two at least) the host sends go with the
## setup and every machine starts loading at once; the AI sides play on every machine alike.
##
## Players are known by their ENet id (the host is 1). Messages, after a joiner's hello {version}:
## joiner -> host: take {i}, side {i, text, rolled, reroll} (its own), ready {on};
## host -> joiner: lobby {map, mode, sides: [{text, rolled, reroll, owner, level}], ready, names, you},
## refuse {why}, go {setup}. A child of the lobby (scenes/match_setup.gd), which it reads and drives.

const Enet := preload("res://src/net/enet.gd")
const Lan := preload("res://src/net/lan.gd")
const HOST := 1        # the host's ENet id
const MAX_PLAYERS := 4

signal host_left   # (a joiner) the host closed the lobby or went away

var lobby          # scenes/match_setup.gd
var is_host := false
var my_id := 0     # this machine's ENet id (the host's is 1; a joiner learns its own from the lobby)
var link = null
var beacon = null
var owners: Array = []     # per side: the player's id, 0 for an AI
var readies := {}          # id -> ready
var names := {}            # id -> what the panels call them ("Host", "Player 2", ...)
var joined := false        # (a joiner) the host's lobby has come
var _sent := {}            # (the host) the lobby as last sent, readies aside: a difference un-readies
var _last := {}            # (the host) and with the readies
var _applying := false     # applying the host's lobby: nothing goes back
var _next_name := 2


func _init(p_lobby, host: bool) -> void:
	lobby = p_lobby
	is_host = host
	if host:
		my_id = HOST
		names = {HOST: "Host"}


## The host: listen for players and broadcast the game; this machine takes the first side.
func host() -> void:
	link = Enet.host(Enet.PORT, MAX_PLAYERS - 1)
	if link.error != "":
		_say("Can't host: %s." % link.error)
		link = null
		_show()
		return
	link.keep_open = true
	_fit_owners()
	beacon = Lan.Beacon.new(_name(), Enet.PORT)
	var addrs := Lan.addresses()
	_say("Waiting for players: on the other machine, Play on the network, then this game. This machine: %s" % (", ".join(addrs) if not addrs.is_empty() else "(no network address)"))
	_show()


## A joiner: in, with the host's lobby as it stands.
func join(p_link, state: Dictionary) -> void:
	link = p_link
	joined = true
	_apply(state)


func _process(_delta: float) -> void:
	if link == null:
		return
	if beacon != null:
		beacon.name = _name()
		beacon.poll()
	var batch: Array = link.poll()
	for k in batch.size():
		var msg: Dictionary = batch[k]
		var from := int(msg.get("from", 0))
		match String(msg.get("t", "")):
			"hello":
				if str(msg.get("version", "")) != Lan.version():
					link.send_to(from, {"t": "refuse", "why": "a different version of the game (%s here, %s there)" % [Lan.version(), msg.get("version", "?")]})
				elif not 0 in owners:
					link.send_to(from, {"t": "refuse", "why": "every side is taken"})
				else:
					names[from] = "Player %d" % _next_name
					_next_name += 1
					owners[owners.find(0)] = from
			"take":
				_take(from, int(msg.i))
			"side":
				var i := int(msg.i)
				if i < owners.size() and int(owners[i]) == from:
					_set_side(i, msg)
			"ready":
				readies[from] = bool(msg.on)
			"lobby":
				_apply(msg)
			"go":
				link.put_back(batch.slice(k + 1))   # (the host's first turns may be right behind it)
				_start(msg.setup)
				return
	if is_host:
		for id in link.left:   # a player went: their side is an AI again
			if id in owners:
				owners[owners.find(id)] = 0
			readies.erase(id)
			names.erase(id)
		link.left.clear()
		_send_lobby()
		_go_if_ready()
	elif link.closed:
		link = null
		host_left.emit()


## Take side i (it must be an AI's): from where this player was.
func take(i: int) -> void:
	if is_host:
		_take(HOST, i)
	elif joined:
		link.send({"t": "take", "i": i})


func _take(id: int, i: int) -> void:
	if i >= owners.size() or int(owners[i]) != 0:
		return
	var was := owners.find(id)
	if was >= 0:
		owners[was] = 0
	owners[i] = id


## The lobby changed side i (typed, rolled): a joiner tells the host about its own side; the host's
## changes go out with its next lobby.
func side_changed(i: int) -> void:
	if _applying or is_host or not joined or link == null or i >= owners.size() or int(owners[i]) != my_id:
		return
	link.send({"t": "side", "i": i, "text": lobby.sides[i].field.text, "rolled": lobby.sides[i].rolled, "reroll": int(lobby.sides[i].reroll)})


## Start, pressed: ready, or not any more.
func toggle_ready() -> void:
	if link == null or (not is_host and not joined):
		return
	var on := not bool(readies.get(my_id, false))
	readies[my_id] = on   # (a joiner's shows at once; the host's lobby confirms it)
	if not is_host:
		link.send({"t": "ready", "on": on})
	_show()


## Leaving the lobby (Menu): the others hear the link close.
func leave() -> void:
	if beacon != null:
		beacon.close()
		beacon = null
	if link != null:
		link.close()
		link = null


## May the host pick this map? Enough sides for everyone in.
func map_ok(m: Dictionary) -> bool:
	return _applying or m.starts.size() >= maxi(2, names.size())


## The players' sides, in order.
func humans() -> Array:
	return range(owners.size()).filter(func(i): return int(owners[i]) != 0)


func _go_if_ready() -> void:
	var people := humans()
	if people.size() < 2 or not people.all(func(i): return bool(readies.get(int(owners[i]), false))):
		return
	var seats := {}
	for i in people:
		seats[int(owners[i])] = i
	var setup := {"prompts": range(lobby.sides.size()).map(func(i): return lobby._prompt(i)), "rerolls": lobby.sides.map(func(s): return int(s.reroll)),
		"map": lobby.MAPS[lobby.map_index], "mode": lobby.MODES[lobby.mode_index][0] if lobby.MODES[lobby.mode_index][0] != "standard" else "",
		"teams": lobby.sides.map(func(s): return s.side_team), "humans": people, "seats": seats,
		"levels": range(lobby.sides.size()).map(func(i): return "" if int(owners[i]) != 0 else String(lobby.LEVELS[lobby.sides[i].level]).to_lower())}
	link.send({"t": "go", "setup": setup})   # (sent at once: everyone starts loading as the host does)
	link.keep_open = false   # (in the match a player leaving ends it)
	link.relay = true        # every player's turns to every other
	_start(setup)


func _start(setup: Dictionary) -> void:
	var l = link
	link = null   # (the match keeps it)
	if beacon != null:
		beacon.close()
		beacon = null
	set_process(false)
	lobby._play_network(l, int(setup.seats[my_id]), setup)


## (The host) every side has an owner, the host one; a map with fewer sides moves the players off
## the lost ones.
func _fit_owners() -> void:
	var n: int = lobby.sides.size()
	var out := []
	for i in n:
		out.append(int(owners[i]) if i < owners.size() else 0)
	for i in range(n, owners.size()):
		if int(owners[i]) != 0 and out.find(0) >= 0:
			out[out.find(0)] = int(owners[i])
	if not HOST in out:
		out[out.find(0) if out.find(0) >= 0 else 0] = HOST
	owners = out


func _state() -> Dictionary:
	var sides := []
	for i in lobby.sides.size():
		var s: Dictionary = lobby.sides[i]
		sides.append({"text": s.field.text, "rolled": s.rolled, "reroll": int(s.reroll), "owner": int(owners[i]), "level": int(s.level)})
	return {"t": "lobby", "map": lobby.MAPS[lobby.map_index], "mode": lobby.mode_index, "sides": sides, "names": names.duplicate()}


## (The host) the lobby to everyone, if it changed; a change other than a ready un-readies all.
func _send_lobby() -> void:
	_fit_owners()
	var state := _state()
	if state != _sent:
		_sent = state
		readies.clear()
	var with_ready := state.duplicate()
	with_ready.ready = readies.duplicate()
	if with_ready == _last:
		return
	_last = with_ready
	for id in link.peers:
		var to: Dictionary = with_ready.duplicate()
		to.you = id
		link.send_to(id, to)
	_show()


## (A joiner) the host's lobby: the map, every side but its own (typed here), who's where.
func _apply(state: Dictionary) -> void:
	_applying = true
	my_id = int(state.you)
	var k: int = lobby.MAPS.find(str(state.map))
	assert(k >= 0, "net lobby: the host's map %s isn't here" % state.map)   # (the version check covers data/maps)
	if k != lobby.map_index:
		lobby._set_map(k)
	if int(state.mode) != lobby.mode_index:
		lobby._set_mode(int(state.mode))
	owners = state.sides.map(func(s): return int(s.owner))
	for i in state.sides.size():
		if int(owners[i]) != my_id or lobby.sides[i].race.is_empty():
			_set_side(i, state.sides[i])
		lobby.sides[i].level = int(state.sides[i].level)
	names = state.names
	readies = state.ready
	_applying = false
	_show()


func _set_side(i: int, msg: Dictionary) -> void:
	var s: Dictionary = lobby.sides[i]
	if s.field.text == str(msg.text) and s.rolled == str(msg.rolled) and int(s.reroll) == int(msg.reroll):
		return
	s.field.text = str(msg.text)
	s.rolled = str(msg.rolled)
	s.reroll = int(msg.reroll)
	lobby._regenerate(i)


## The game's name in the joiners' list: the host's race on the map, and how full it is.
func _name() -> String:
	var i := owners.find(HOST)
	return "%s on %s (%d of %d)" % [lobby.sides[maxi(i, 0)].race.get("name", "?"), str(lobby.map_data.get("name", "?")), names.size(), lobby.sides.size()]


## The screen as it stands: who's on which side, what can be changed here, Start's words.
func _show() -> void:
	for i in mini(owners.size(), lobby.sides.size()):
		var s: Dictionary = lobby.sides[i]
		var owner := int(owners[i])
		var mine := owner == my_id
		var ai := owner == 0
		s.field.editable = mine or (ai and is_host)
		s.dice.disabled = not s.field.editable
		for b in s.levels:
			b.disabled = not (ai and is_host)
		s.take.visible = ai and (is_host or joined)
		var who: String = "You" if mine else ("AI (%s)" % lobby.LEVELS[s.level] if ai else str(names.get(owner, "A player")))
		if not ai and bool(readies.get(owner, false)):
			who += "  ·  ready"
		s.who.text = who.to_upper()
	for b in lobby.map_buttons:
		b.disabled = not is_host
	lobby.level_card.visible = is_host and lobby.sides.size() == 2 and owners.size() == 2 and int(owners[1]) == 0
	var start: Button = lobby.start_button
	var people := humans()
	if people.size() < 2:
		start.text = "Waiting for players"
		start.disabled = true
		return
	var waiting := people.filter(func(i): return not bool(readies.get(int(owners[i]), false))).size()
	start.disabled = false
	start.text = ("Ready: waiting for %d" % waiting) if bool(readies.get(my_id, false)) else "Ready"


func _say(text: String) -> void:
	lobby.net_hint.text = text
	lobby.net_hint.visible = text != ""
