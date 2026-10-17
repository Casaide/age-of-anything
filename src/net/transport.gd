extends RefCounted
## A link to the other player in a network match: messages (Dictionaries of ints, Strings and
## Arrays of those) sent reliably and in order. `loopback.gd` (tests: two ends in one process)
## and `enet.gd` (Godot's ENet, the LAN) carry them; the HyperDHT sidecar will be another
## (networking milestone, phase 2). View side: the sim never sees one.

var connected := false   # the other end is there
var closed := false      # the link went down (or was never made)


## Send a message to the other end.
func send(_msg: Dictionary) -> void:
	assert(false, "transport.send: not implemented")


## The messages that arrived since the last poll, in order.
func poll() -> Array:
	return []


func close() -> void:
	closed = true
	connected = false
