class_name StationLog
extends Control
## The station log: short entries that unlock as rooms are certified
## (res://content/story/log.json). The story develops slowly; this is where.

signal closed

const LOG_PATH := "res://content/story/log.json"
static var _entries: Array = []

var _list: VBoxContainer
var _scroll: ScrollContainer


static func entries() -> Array:
	if _entries.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOG_PATH))
		if typeof(d) == TYPE_DICTIONARY:
			_entries = d.get("entries", [])
	return _entries


## The entries this station has written so far: the opening one, and one for each certified room.
static func unlocked(s: GameState) -> Array:
	var out: Array = []
	for e in entries():
		var after: String = e.get("after", "")
		if after == "" or (GameState.ROOMS.has(after) and s.room_state(after).certified):
			out.append(e)
	return out


static func unread(s: GameState) -> int:
	var n := 0
	for e in unlocked(s):
		if not s.log_read.has(e["id"]):
			n += 1
	return n


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Label.new()
	title.text = "STATION LOG"
	title.position = Vector2(200, 16)
	title.add_theme_color_override("font_color", UiTheme.AMBER)
	title.add_theme_font_size_override("font_size", 20)
	add_child(title)
	var sub := Label.new()
	sub.text = "Jupiter orbital station, Robbie programme. Entries are added as rooms are surveyed."
	sub.position = Vector2(200, 46)
	sub.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	sub.add_theme_font_size_override("font_size", 13)
	add_child(sub)
	var close := IconButton.make("close", "Back to the station (L or Esc)", func() -> void: closed.emit())
	close.position = Vector2(1222, 14)
	close.custom_minimum_size = Vector2(34, 32)
	add_child(close)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(200, 84)
	_scroll.size = Vector2(880, 620)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 14)
	_list.custom_minimum_size = Vector2(860, 0)
	_scroll.add_child(_list)


func refresh(s: GameState) -> void:
	for c in _list.get_children():
		c.queue_free()
	var shown := unlocked(s)
	for e in shown:
		var fresh := not s.log_read.has(e["id"])
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiTheme.box(Color("0d131a"), UiTheme.AMBER.darkened(0.3) if fresh else Color("1e2835"), 4, 14))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		p.add_child(col)
		var head := Label.new()
		var after: String = e.get("after", "")
		head.text = str(e["title"]).to_upper() + ("" if after == "" else "   ·   after %s" % s.room_state(after).room.title)
		head.add_theme_color_override("font_color", UiTheme.AMBER)
		head.add_theme_font_size_override("font_size", 14)
		col.add_child(head)
		var body := Label.new()
		body.text = str(e["text"])
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(830, 0)
		body.add_theme_font_size_override("font_size", 15)
		col.add_child(body)
		_list.add_child(p)
		if fresh:
			s.log_read.append(e["id"])
	var remaining := entries().size() - shown.size()
	if remaining > 0:
		var more := Label.new()
		more.text = "The log continues as more rooms are surveyed."
		more.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
		more.add_theme_font_size_override("font_size", 13)
		_list.add_child(more)
	s.save()
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_L]:
		closed.emit()
		get_viewport().set_input_as_handled()
