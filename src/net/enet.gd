extends "res://src/net/transport.gd"
## The link over Godot's ENet (UDP, reliable and ordered on one channel): the host listens on a
## port, the other players connect to its address. A star: the host hears everyone, and in a match
## (`relay`) passes each player's messages on to the others, so every machine hears every turn. For the home network (phase 1 of the
## networking milestone: no NAT traversal; across the internet comes the HyperDHT sidecar).
## Packets only: no scene RPCs, nothing replicated.

const PORT := 47870
const TIMEOUT_MS := [15000, 60000]   # how long a silent peer is waited for (ENet's 5-30 s is shorter than a load's hitch)

var peer := ENetMultiplayerPeer.new()
var is_host := false
var error := ""          # why it didn't connect, in words
var peers: Array = []    # (the host) the players connected, by ENet id
var left: Array = []     # (the host) ids that went since the caller last took them
var keep_open := false   # (the host) a player leaving doesn't close the link (a lobby: their seat opens again)
var relay := false       # (the host) pass each player's messages on to the others (a match of more than two)


## Listen for players (up to `players` of them). `error` says why not (the port in use).
static func host(port := PORT, players := 1):
	var t = load("res://src/net/enet.gd").new()
	t.is_host = true
	var err: int = t.peer.create_server(port, players)
	if err != OK:
		t.error = "can't listen on port %d (%s)" % [port, error_string(err)]
		t.closed = true
	else:
		t._wire()
	return t


## Connect to a host at this address.
static func join(address: String, port := PORT):
	var t = load("res://src/net/enet.gd").new()
	var err: int = t.peer.create_client(address, port)
	if err != OK:
		t.error = "can't reach %s:%d (%s)" % [address, port, error_string(err)]
		t.closed = true
	else:
		t._wire()
	return t


func _wire() -> void:
	peer.peer_connected.connect(func(id):
		peer.get_peer(id).set_timeout(32, TIMEOUT_MS[0], TIMEOUT_MS[1])
		peers.append(id)
		connected = true)
	peer.peer_disconnected.connect(func(id):
		peers.erase(id)
		left.append(id)
		if not (is_host and keep_open):
			connected = false
			closed = true)


func send(msg: Dictionary) -> void:
	send_to(MultiplayerPeer.TARGET_PEER_BROADCAST, msg)


## (The host) to one player (an ENet id), or to all but one (minus its id).
func send_to(id: int, msg: Dictionary) -> void:
	if closed:
		return
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.transfer_channel = 0
	peer.set_target_peer(id)
	peer.put_packet(var_to_bytes(msg))
	peer.host.flush()   # out now: a packet only leaves when ENet is serviced, and the next service may be a load away


## Keep the link alive without reading it (the match is loading): ENet answers the other end and
## sends what's queued; what arrives waits for the next poll.
func pump() -> void:
	if not closed:
		peer.poll()


func poll() -> Array:
	var out := _take_back()
	if closed and peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return out
	peer.poll()
	if not is_host and peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED and not closed:
		closed = true   # the host wasn't there, or went away
		if error == "":
			error = "the host isn't answering"
	while peer.get_available_packet_count() > 0:
		var from := peer.get_packet_peer()
		var bytes := peer.get_packet()
		var msg: Dictionary = bytes_to_var(bytes)
		if is_host:
			if relay and peers.size() > 1:
				peer.set_target_peer(-from)
				peer.put_packet(bytes)
			msg["from"] = from   # (who sent it: the lobby's seats)
		out.append(msg)
	if relay:
		peer.host.flush()
	return out


func close() -> void:
	super.close()
	peer.close()
