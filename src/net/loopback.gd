extends "res://src/net/transport.gd"
## Two ends of a link in one process, for tests: a message reaches the other end after `delay`
## polls of it, plus up to `jitter` more (from src/rng.gd, so a test run is the same every time),
## never out of order. Messages are copied through bytes, as a socket would.

const Rng := preload("res://src/rng.gd")

var other
var delay := 0
var jitter := 0
var _rng: Rng
var _inbox: Array = []   # [polls left, bytes]


## A connected pair: [end a, end b].
static func pair(p_delay := 0, p_jitter := 0, seed_value := 1) -> Array:
	var Me = load("res://src/net/loopback.gd")
	var a = Me.new()
	var b = Me.new()
	a.other = b
	b.other = a
	for e in [a, b]:
		e.delay = p_delay
		e.jitter = p_jitter
		e.connected = true
	a._rng = Rng.new(seed_value)
	b._rng = Rng.new(seed_value + 1)
	return [a, b]


func send(msg: Dictionary) -> void:
	assert(connected, "loopback: send on a closed link")
	var wait := delay + (_rng.range_int(0, jitter) if jitter > 0 else 0)
	if not other._inbox.is_empty():
		wait = maxi(wait, int(other._inbox[-1][0]))   # in order: never before the one sent earlier
	other._inbox.append([wait, var_to_bytes(msg)])


func poll() -> Array:
	var out := _take_back()
	for m in _inbox:
		m[0] -= 1
	while not _inbox.is_empty() and int(_inbox[0][0]) <= 0:
		out.append(bytes_to_var(_inbox.pop_front()[1]))
	return out


func close() -> void:
	super.close()
	if other != null and other.connected:
		other.connected = false
		other.closed = true
