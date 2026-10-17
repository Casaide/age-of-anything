extends RefCounted
## Lockstep for a network match: every player runs the same World and only commands travel.
## A command is stamped with the turn it was issued in and runs two turns later
## (src/sim/commands.gd), so at the end of each turn this sends the turn's local commands, with a
## mark that the turn is done and the state hashes taken since; and a turn may only start once
## every player's turn two before it is in (may_run). A late player holds everyone's world
## still; a hash that differs is a desync: the match can't go on. View side (a Node never
## enters the sim; the transport is a socket).

const Commands := preload("res://src/sim/commands.gd")

var world
var me := 0              # the player this machine commands
var players: Array = []  # every player that sends commands (people; a bot seat needs none: it's deterministic)
var transport
var desync := ""         # what differed, once a hash did ("" while in step)
var peer_left := false   # the other end closed the link
var others: Array = []   # messages that aren't turns (chat, the match's end): the caller takes them
var _done := {}          # player -> the last turn whose commands are all in
var _hashes_sent := 0    # how many of world.hashes went out
var _their_hashes := {}  # tick -> hash, from the others, waiting on our own


func _init(p_world, p_me: int, p_players: Array, p_transport) -> void:
	world = p_world
	me = p_me
	players = p_players
	transport = p_transport
	for p in players:
		_done[p] = -1


## Take what arrived: the others' commands into the world's queue, their hashes checked.
func receive() -> void:
	for msg in transport.poll():
		match String(msg.get("t", "")):
			"turn":
				for cmd in msg.cmds:
					world.commands.add(cmd)
				_done[int(msg.player)] = int(msg.turn)
				for h in msg.hashes:
					_their_hashes[int(h[0])] = int(h[1])
			_:
				others.append(msg)
	if transport.closed and not peer_left:
		peer_left = true
	_check_hashes()


## Can the world start this turn? (Only at a turn's first tick; between them, always.)
func may_run(turn: int) -> bool:
	if desync != "" or peer_left:
		return false
	for p in players:
		if int(_done[p]) < turn - Commands.DELAY:
			return false
	return true


## Who the world is waiting on (players whose turns haven't come), for a "waiting" note.
func waiting_on(turn: int) -> Array:
	return players.filter(func(p): return int(_done[p]) < turn - Commands.DELAY)


## The turn just ended: send its local commands (they run two turns on), the mark, new hashes.
func end_turn(turn: int) -> void:
	var cmds: Array = world.commands.pending.get(turn + Commands.DELAY, []).filter(
		func(c): return int(c.player) == me and int(c.turn) == turn)
	var hashes: Array = world.hashes.slice(_hashes_sent)
	_hashes_sent = world.hashes.size()
	transport.send({"t": "turn", "player": me, "turn": turn, "cmds": cmds, "hashes": hashes})
	_done[me] = turn


## One tick if the world may take it: bots think, the world steps, a finished turn goes out.
## False while it waits (on a player, or for good: a desync, a player gone).
func step(bots: Array) -> bool:
	receive()
	if world.tick % Commands.TICKS_PER_TURN == 0 and not may_run(world.turn()):
		return false
	for bot in bots:
		bot.think(world)
	world.step()
	if world.tick % Commands.TICKS_PER_TURN == 0:
		end_turn(world.turn() - 1)
	return true


func _check_hashes() -> void:
	if desync != "" or _their_hashes.is_empty():
		return
	for h in world.hashes:
		var tick := int(h[0])
		if _their_hashes.has(tick):
			if int(_their_hashes[tick]) != int(h[1]):
				desync = "state differs at tick %d" % tick
				return
			_their_hashes.erase(tick)
