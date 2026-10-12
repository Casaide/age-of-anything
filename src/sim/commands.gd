extends RefCounted
## The command stream: the only way anything changes the sim.
## A command is {turn, player, seq, type, args}. It is stamped with the turn it
## was issued in and runs at the start of turn + DELAY, after every command of
## that turn is sorted by (turn, player, seq). Player UI and AI both use issue().
## Args hold only ints, Strings and Arrays of those (no floats, no nesting deeper).

const TICKS_PER_TURN := 4    # 200 ms turns at 20 Hz
const DELAY := 2             # turns between issuing and running

const MOVE := "move"               # {ids: [unit ids], x, y}  milli-tiles
const SPAWN := "spawn"             # {slot: roster slot, count, x, y}  debug and test setups
const GATHER := "gather"           # {ids, cell}  workers gather; others walk there
const BUILD := "build"             # {ids, building: type id, cx, cy, along?}  place a foundation (top-left cell; along: a gate runs along y if 1)
const HELP_BUILD := "help_build"   # {ids, target: building id}
const TRAIN := "train"             # {building: id, slot}
const CANCEL := "cancel"           # {building: id, index}  refunds
const RALLY := "rally"             # {building: id, x, y}
const ATTACK := "attack"           # {ids, target: unit or building id}
const ATTACK_MOVE := "attack_move" # {ids, x, y}  walk there, fighting whatever comes into sight
const AGE_UP := "age_up"           # {building}  advance to the next age (tech.json)
const RESEARCH := "research"       # {building, id}
const SURRENDER := "surrender"     # {}  the player concedes (match.gd)
const RESEED := "reseed"           # {ids, building}  replant a worked-out farm (costs wood); the workers farm it
const TRADE := "trade"             # {building: a market, resource: id, buy: 1 or 0}  a lot of goods for gold (market.gd)
const STOP := "stop"               # {ids}  drop everything: no move, no job, no fight, no queued orders
const STANCE := "stance"           # {ids, stance: "aggressive" / "defensive" / "stand" / "passive"}  (combat.gd POSTURES)
const DROP_OFF := "drop_off"       # {ids, building}  workers take what they carry there, then go back to gathering
const AUTO_RESEED := "auto_reseed" # {on: 1 or 0}  the player's setting: farms worked out reseed themselves (economy.gd)
const TYPES := [MOVE, SPAWN, GATHER, BUILD, HELP_BUILD, TRAIN, CANCEL, RALLY, ATTACK, ATTACK_MOVE, AGE_UP, RESEARCH, SURRENDER, RESEED, TRADE, STOP, STANCE, DROP_OFF, AUTO_RESEED]
## Unit orders that can be queued: with args.queue = 1, a busy unit keeps the order for
## when it's done (shift-queuing); without it, the order replaces the unit's queue.
const QUEUEABLE := [MOVE, GATHER, BUILD, HELP_BUILD, ATTACK, ATTACK_MOVE, DROP_OFF]

var pending := {}            # run turn -> [commands]; looked up by key, never iterated
var next_seq := {}           # player -> next seq; looked up by key, never iterated
var last_run_turn := -1


static func turn_of(tick: int) -> int:
	return tick / TICKS_PER_TURN


## Stamp a new command for a player in the current turn and queue it.
func issue(turn: int, player: int, type: String, args: Dictionary) -> Dictionary:
	var seq: int = next_seq.get(player, 0)
	next_seq[player] = seq + 1
	var cmd := {"turn": turn, "player": player, "seq": seq, "type": type, "args": args}
	add(cmd)
	return cmd


## Queue a command that already has its stamp (from a replay or, later, a peer).
func add(cmd: Dictionary) -> void:
	check(cmd)
	var run: int = cmd.turn + DELAY
	assert(run > last_run_turn, "Command for turn %d arrived after it ran" % cmd.turn)
	if not pending.has(run):
		pending[run] = []
	pending[run].append(cmd)
	if cmd.seq >= next_seq.get(cmd.player, 0):
		next_seq[cmd.player] = cmd.seq + 1


## Commands that run at this turn, in (turn, player, seq) order.
func take(turn: int) -> Array:
	last_run_turn = turn
	var batch: Array = pending.get(turn, [])
	pending.erase(turn)
	batch.sort_custom(_before)
	for i in range(1, batch.size()):
		assert(batch[i].player != batch[i - 1].player or batch[i].seq != batch[i - 1].seq,
			"Duplicate seq %d for player %d" % [batch[i].seq, batch[i].player])
	return batch


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if a.turn != b.turn:
		return a.turn < b.turn
	if a.player != b.player:
		return a.player < b.player
	return a.seq < b.seq


static func check(cmd: Dictionary) -> void:
	var why := problem(cmd)
	assert(why == "", why)


## Why a command is malformed, or "" if it's fine.
static func problem(cmd: Dictionary) -> String:
	for k in ["turn", "player", "seq"]:
		if typeof(cmd[k]) != TYPE_INT:
			return "Command %s must be an int, got %s" % [k, type_string(typeof(cmd[k]))]
	if not cmd.type in TYPES:
		return "Unknown command type: %s" % cmd.type
	for k in cmd.args:
		var v = cmd.args[k]
		var vals: Array = v if typeof(v) == TYPE_ARRAY else [v]
		for e in vals:
			if typeof(e) != TYPE_INT and typeof(e) != TYPE_STRING:
				return "Command arg %s holds a %s" % [k, type_string(typeof(e))]
	return ""
