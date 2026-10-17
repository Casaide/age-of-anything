extends ColorRect
## Play on the network (the networking milestone, phase 1: the home network over ENet). Over the
## lobby's title menu: host a game (the usual battle setup, then this page waits for a player),
## or join one: the games heard on the network (src/net/lan.gd: no address to type on the Deck),
## or an address. The joiner names their own race; the host's setup and the joiner's race make
## the match. Emits `start(link, me, setup)` when both are ready. A pad walks it by focus.
##
## The handshake (before the lockstep): the joiner sends hello {prompt, version}; the host answers
## setup {prompts, rerolls, map, mode, teams} or refuse {why} (another version of the game).

const UiTheme := preload("res://src/view/ui/theme.gd")
const PadMode := preload("res://src/view/pad_mode.gd")
const Enet := preload("res://src/net/enet.gd")
const Lan := preload("res://src/net/lan.gd")

signal host_chosen              # Host a game: the lobby opens its battle setup
signal host_save_chosen         # Host a saved game: the lobby opens its saves; one picked comes back to choose_seat
signal start(link, me: int, setup: Dictionary)
signal closed

var closed_frame := -1
var box: VBoxContainer
var list: VBoxContainer
var race_field: LineEdit
var address_field: LineEdit
var note: Label
var finder = null
var _link = null
var _beacon = null
var _host_setup := {}
var _mode := ""      # "": choosing; "join": joining an address; "host": waiting for a player
var _next_list := 0.0


func _init() -> void:
	color = Color(0, 0, 0, 0.5)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var card := PanelContainer.new()
	card.name = "card"
	card.theme_type_variation = "CrestFrame"
	card.custom_minimum_size = Vector2(700, 0)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(card)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)


## The choice: host, or join a game heard on the network (or an address).
func open() -> void:
	_reset()
	_mode = ""
	_clear()
	_title("Play on the network", "Both machines on the same home network (Wi-Fi or cable).")
	var host := _button("Host a game", true)
	host.pressed.connect(func():
		visible = false
		host_chosen.emit())
	box.add_child(host)
	var saved := _button("Host a saved game: the other player takes over an AI")
	saved.pressed.connect(func():
		visible = false
		host_save_chosen.emit())
	box.add_child(saved)
	box.add_child(UiTheme.Rule.new(UiTheme.look("").metal))
	box.add_child(UiTheme.label("Your race, if you join", "Dim"))
	race_field = LineEdit.new()
	race_field.text = "sewer rats with cheese hammers"
	race_field.custom_minimum_size = Vector2(660, 48)
	box.add_child(race_field)
	box.add_child(UiTheme.label("Games on this network", "Dim"))
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	box.add_child(list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	address_field = LineEdit.new()
	address_field.placeholder_text = "or an address: 192.168.1.20"
	address_field.custom_minimum_size = Vector2(500, 48)
	row.add_child(address_field)
	var join := UiTheme.button("Join")
	join.custom_minimum_size = Vector2(150, 48)
	join.pressed.connect(func(): if address_field.text.strip_edges() != "": _join(address_field.text.strip_edges(), Enet.PORT))
	row.add_child(join)
	box.add_child(row)
	note = UiTheme.label("", "Dim", true)
	note.custom_minimum_size.x = 660
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	_back("Back")
	finder = Lan.Finder.new()
	if finder.error != "":
		note.text = finder.error
	_show(host)


## A saved match to host: which AI seat the other player takes (the save's bot seats, by name).
func choose_seat(rep: Dictionary) -> void:
	_reset()
	_mode = "seat"
	_clear()
	_title("Open a seat", "The other player takes over this side from its AI; the other AIs play on.")
	var v: Dictionary = rep.get("view", {})
	var names: Array = v.get("names", [])
	var teams: Array = v.get("player_teams", [])
	var first: Control = null
	for s in rep.get("bots", []):
		var p := int(s.player)
		var b := _button("%s  (side %d, team %d, %s AI now)" % [names[p] if p < names.size() else "?", p + 1, int(teams[p]) + 1 if p < teams.size() else p + 1, str(s.get("level", "?"))])
		b.pressed.connect(func():
			var me := int(v.get("active", 0))
			wait_for_player({"save": rep, "seat": p, "humans": [me, p]}, "%s, a saved match" % (names[me] if me < names.size() else "?")))
		box.add_child(b)
		if first == null:
			first = b
	if first == null:
		box.add_child(UiTheme.label("This save has no AI seat to take over.", "Dim", true))
	_back("Back")
	_show(first)


## The host's wait: listen, broadcast, and on a hello answer with the setup (the joiner's race as
## side 1's). `setup`: {prompts, rerolls, map, mode, teams}, side 0 the host's; or a saved match:
## {save, seat (the joiner's), humans}.
func wait_for_player(setup: Dictionary, name: String) -> void:
	_reset()
	_mode = "host"
	_host_setup = setup
	_clear()
	_title("Waiting for a player", "")
	_link = Enet.host()
	if _link.error != "":
		note = UiTheme.label(_link.error, "Dim", true)
		box.add_child(note)
		_back("Back")
		_show(null)
		return
	_beacon = Lan.Beacon.new(name, Enet.PORT)
	var addrs := Lan.addresses()
	var where := UiTheme.label("On the other machine: Play on the network, then this game (%s).\nThis machine: %s" % [name, ", ".join(addrs) if not addrs.is_empty() else "(no network address)"], "", true)
	where.custom_minimum_size.x = 660
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(where)
	note = UiTheme.label("", "Dim", true)
	note.custom_minimum_size.x = 660
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	_back("Cancel")
	_show(null)


func _process(_delta: float) -> void:
	if not visible:
		return
	if _beacon != null:
		_beacon.poll()
	if finder != null and _mode == "":
		finder.poll()
		var now := Time.get_ticks_msec() / 1000.0
		if now >= _next_list:
			_next_list = now + 1.0
			_list_hosts()
	if _link == null:
		return
	var batch: Array = _link.poll()
	for i in batch.size():
		var msg: Dictionary = batch[i]
		match String(msg.get("t", "")):
			"hello":   # (the host) a player wants in
				if str(msg.get("version", "")) != Lan.version():
					_link.send({"t": "refuse", "why": "a different version of the game (%s here, %s there)" % [Lan.version(), msg.get("version", "?")]})
					note.text = "A player tried to join with a different version of the game."
					continue
				var setup := _host_setup.duplicate(true)
				if not setup.has("save"):
					setup.prompts[1] = str(msg.get("prompt", setup.prompts[1]))
				_link.send({"t": "setup", "setup": setup})
				_link.put_back(batch.slice(i + 1))
				_go(int(setup.humans[0]) if setup.has("save") else 0, setup)
				return
			"setup":   # (the joiner) in: side 1, or a saved match's open seat
				_link.put_back(batch.slice(i + 1))   # (the host's first turns may be right behind it: the match reads them)
				_go(int(msg.setup.seat) if msg.setup.has("save") else 1, msg.setup)
				return
			"refuse":
				note.text = "The host refused: %s." % str(msg.get("why", "?"))
				_link.close()
				_link = null
				return
	if _link != null and _mode == "join":
		if _link.connected and not _link.has_meta("said_hello"):
			_link.set_meta("said_hello", true)
			_link.send({"t": "hello", "prompt": race_field.text.strip_edges() if race_field.text.strip_edges() != "" else "sewer rats", "version": Lan.version()})
			note.text = "Connected: waiting for the host's setup..."
		elif _link.closed:
			note.text = "Couldn't join: %s." % (_link.error if _link.error != "" else "the host isn't answering")
			_link = null
			_mode = ""


func _join(address: String, port: int) -> void:
	if _link != null:
		_link.close()
	_mode = "join"
	_link = Enet.join(address, port)
	note.text = "Joining %s..." % address if _link.error == "" else "Couldn't join: %s." % _link.error


func _go(me: int, setup: Dictionary) -> void:
	var link = _link
	_link = null   # (the match keeps it: closing the page mustn't close it)
	_reset()
	visible = false
	start.emit(link, me, setup)


func _list_hosts() -> void:
	for c in list.get_children():
		c.queue_free()
	var hosts: Array = finder.hosts()
	for h in hosts:
		var same: bool = h[3]
		var b := _button("Join: %s  (%s)%s" % [h[1], h[0], "" if same else "  - a different version"])
		b.disabled = not same
		b.pressed.connect(_join.bind(String(h[0]), int(h[2])))
		list.add_child(b)
	if hosts.is_empty():
		var l := UiTheme.label("None yet: on the other machine, Play on the network, Host a game.", "Dim", true)
		l.custom_minimum_size.x = 660
		list.add_child(l)


func close() -> void:
	_reset()
	if _link != null:
		_link.close()
		_link = null
	visible = false
	closed_frame = Engine.get_process_frames()
	closed.emit()


func _reset() -> void:
	if finder != null:
		finder.close()
		finder = null
	if _beacon != null:
		_beacon.close()
		_beacon = null


func _clear() -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _title(text: String, sub: String) -> void:
	var title := UiTheme.label(text, "Title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	box.add_child(title)
	if sub != "":
		var s := UiTheme.label(sub, "Dim", true)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.custom_minimum_size.x = 660
		box.add_child(s)


func _button(text: String, primary := false) -> Button:
	var b := UiTheme.button(text, primary)
	b.custom_minimum_size = Vector2(660, 64 if primary else 52)
	b.add_theme_font_size_override("font_size", 24 if primary else 17)
	return b


func _back(text: String) -> void:
	var back := _button(text)
	back.pressed.connect(close)
	box.add_child(back)
	set_meta("pad_first", back)


func _show(first: Control) -> void:
	if first != null:
		set_meta("pad_first", first)
	visible = true
	var pad = PadMode.of(get_tree()) if is_inside_tree() else null
	if pad != null and pad.on:
		(get_meta("pad_first") as Control).grab_focus.call_deferred()
	UiTheme.arrive(get_node("card"), 10.0)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
