extends RefCounted
## Finding a network match on the home network, and making sure both machines run the same game.
## The host's beacon broadcasts a small UDP packet once a second (the game, its version, a name,
## the ENet port); a joiner's finder lists the hosts it hears, so nobody types an address (the
## Deck). The version is a hash of the data the sim reads and the protocol: two builds that would
## part ways refuse to play.

const PROTOCOL := 1
const DISCOVERY_PORT := 47872
const GONE_AFTER := 4.0   # seconds without a beacon before a host leaves the list

static var _version := ""


## This build's network version: the protocol and every data file the sim reads (sorted).
static func version() -> String:
	if _version == "":
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_MD5)
		ctx.update(("aow-net-%d" % PROTOCOL).to_utf8_buffer())
		for dir in ["res://data/", "res://data/rules/", "res://data/maps/"]:
			var files := Array(DirAccess.get_files_at(dir)).filter(func(f): return f.ends_with(".json"))
			files.sort()
			for f in files:
				ctx.update((dir + f).to_utf8_buffer())
				ctx.update(FileAccess.get_file_as_bytes(dir + f))
		_version = ctx.finish().hex_encode().substr(0, 12)
	return _version


## The host: broadcasts its game once a second while it waits (poll it each frame).
class Beacon:
	var udp := PacketPeerUDP.new()
	var name := ""
	var port := 0
	var _next := 0.0

	var _to: Array = []   # where it broadcasts: each home network's broadcast address, and everyone's

	func _init(p_name: String, p_port: int) -> void:
		name = p_name
		port = p_port
		udp.set_broadcast_enabled(true)
		# macOS won't send to 255.255.255.255 (Linux will): the subnet's own broadcast address too,
		# taken as a /24 (home routers' usual network).
		for a in load("res://src/net/lan.gd").addresses():
			_to.append(a.substr(0, a.rfind(".")) + ".255")
		_to.append("255.255.255.255")

	func poll() -> void:
		var now := Time.get_ticks_msec() / 1000.0
		if now < _next:
			return
		_next = now + 1.0
		var packet := var_to_bytes({"aow": PROTOCOL, "version": load("res://src/net/lan.gd").version(), "name": name, "port": port})
		for to in _to:
			udp.set_dest_address(to, DISCOVERY_PORT)
			udp.put_packet(packet)

	func close() -> void:
		udp.close()


## A joiner: listens for beacons; hosts() is what it has heard lately.
class Finder:
	var udp := PacketPeerUDP.new()
	var found := {}   # address -> {name, port, version, seen}
	var error := ""

	func _init() -> void:
		var err := udp.bind(DISCOVERY_PORT)
		if err != OK:
			error = "can't listen for games (%s)" % error_string(err)

	func poll() -> void:
		var now := Time.get_ticks_msec() / 1000.0
		while udp.get_available_packet_count() > 0:
			var data = bytes_to_var(udp.get_packet())
			var from := udp.get_packet_ip()
			if data is Dictionary and int(data.get("aow", 0)) == PROTOCOL:
				found[from] = {"name": str(data.get("name", "?")), "port": int(data.get("port", 0)), "version": str(data.get("version", "")), "seen": now}
		for a in found.keys():
			if now - float(found[a].seen) > GONE_AFTER:
				found.erase(a)

	## [[address, name, port, same version?]], by address.
	func hosts() -> Array:
		var out := []
		var keys := found.keys()
		keys.sort()
		for a in keys:
			out.append([a, found[a].name, found[a].port, found[a].version == load("res://src/net/lan.gd").version()])
		return out

	func close() -> void:
		udp.close()


## This machine's addresses on the home network (for the host to show), IPv4, not loopback.
static func addresses() -> Array:
	return Array(IP.get_local_addresses()).filter(func(a): return a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."))
