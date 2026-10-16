extends ColorRect
## The saved matches, newest first, over a darkened screen (the lobby's title menu and the pause
## menu open it): pick one to play on from there (src/save_game.gd, D-140). A save this version
## can't rebuild says why and stays put. A pad walks it by focus; B (or Esc) goes back.

const UiTheme := preload("res://src/view/ui/theme.gd")
const SaveGame := preload("res://src/save_game.gd")
const PadMode := preload("res://src/view/pad_mode.gd")

const SHOWN := 8   # the newest this many

signal chosen(rep: Dictionary)
signal closed

var lib
var closed_frame := -1   # the frame it closed on (B closed it: the screen under it mustn't take that B too)
var list: VBoxContainer
var note: Label


func _init(p_lib, metal := Color("#c09048")) -> void:
	lib = p_lib
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
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var title := UiTheme.label("Load a game", "Title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	box.add_child(title)
	box.add_child(UiTheme.Rule.new(metal))
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	box.add_child(list)
	note = UiTheme.label("", "Dim", true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.custom_minimum_size.x = 660
	box.add_child(note)
	var back := UiTheme.button("Back")
	back.custom_minimum_size = Vector2(660, 50)
	back.add_theme_font_size_override("font_size", 19)
	back.pressed.connect(close)
	box.add_child(back)
	set_meta("pad_first", back)


func open() -> void:
	for c in list.get_children():
		list.remove_child(c)   # (gone at once: the first button must be a new one)
		c.queue_free()
	note.text = ""
	var saves := SaveGame.list()
	for s in saves.slice(0, SHOWN):
		var b := UiTheme.button(_line(s))
		b.custom_minimum_size = Vector2(660, 56)   # (room at its right end for a pad's A badge)
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(_pick.bind(s.path, b))
		list.add_child(b)
	if saves.is_empty():
		note.text = "No saved games yet. Save one from the pause menu (Esc, or Menu on a pad)."
	elif saves.size() > SHOWN:
		note.text = "The newest %d of %d saves." % [SHOWN, saves.size()]
	visible = true
	if list.get_child_count() > 0:
		set_meta("pad_first", list.get_child(0))
	else:
		set_meta("pad_first", get_node("card").get_child(0).get_child(-1))
	if PadMode.of(get_tree()).on:
		(get_meta("pad_first") as Control).grab_focus.call_deferred()
	UiTheme.arrive(get_node("card"), 10.0)


func close() -> void:
	visible = false
	closed_frame = Engine.get_process_frames()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## "Bog Frogs vs Scurry Pack  ·  Reed Meadow  ·  12:34  ·  16 Oct 14:02"
func _line(s: Dictionary) -> String:
	var v: Dictionary = s.view
	var secs: int = s.ticks / 20
	var d: String = s.saved_at   # YYYY-MM-DDTHH:MM:SS
	var when := "%d %s %s" % [int(d.substr(8, 2)), MONTHS[int(d.substr(5, 2)) - 1], d.substr(11, 5)]
	return "%s  ·  %s  ·  %d:%02d  ·  %s" % [" vs ".join(v.get("names", [])), String(v.get("map_id", "")).capitalize(), secs / 60, secs % 60, when]


const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


func _pick(path: String, b: Button) -> void:
	var rep := SaveGame.load_file(path)
	var why := SaveGame.problem(rep, lib)
	if why != "":
		note.text = "That save can't be loaded in this version. " + why
		b.disabled = true
		return
	chosen.emit(rep)
