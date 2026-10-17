extends "res://src/net/transport.gd"
## The link over Godot's ENet (UDP, reliable and ordered on one channel): the host listens on a
## port, the other player connects to its address. For the home network (phase 1 of the
## networking milestone: no NAT traversal; across the internet comes the HyperDHT sidecar).
## Packets only: no scene RPCs, nothing replicated.

const PORT := 47870

var peer := ENetMultiplayerPeer.new()
var is_host := false
var error := ""          # why it didn't connect, in words


## Listen for the other player. `error` says why not (the port in use).
static func host(port := PORT):
	var t = load("res://src/net/enet.gd").new()
	t.is_host = true
	var err: int = t.peer.create_server(port, 1)
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
	peer.peer_connected.connect(func(_id): connected = true)
	peer.peer_disconnected.connect(func(_id):
		connected = false
		closed = true)


func send(msg: Dictionary) -> void:
	if closed:
		return
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.transfer_channel = 0
	peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	peer.put_packet(var_to_bytes(msg))


func poll() -> Array:
	var out := []
	if closed and peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return out
	peer.poll()
	if not is_host and peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED and not closed:
		closed = true   # the host wasn't there, or went away
		if error == "":
			error = "the host isn't answering"
	while peer.get_available_packet_count() > 0:
		out.append(bytes_to_var(peer.get_packet()))
	return out


func close() -> void:
	super.close()
	peer.close()
