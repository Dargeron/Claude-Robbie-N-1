class_name RobbieWall
extends Control
## The Wall of Robbies: one plaque for every Robbie the station has sent, newest
## first, with where it went, how it ended and its last words. It doubles as the
## score: each room's line says how many Robbies it has cost so far.
## Click a plaque to watch that Robbie's transmission again.

signal entry_chosen(room_id: String, entry: Dictionary)
signal closed

const COLUMNS := 3
const PLAQUE_W := 396.0
const THUMB_W := 110.0

var state: GameState
var _grid: GridContainer
var _summary: RichTextLabel
var _scroll: ScrollContainer
var _empty: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "THE WALL OF ROBBIES"
	title.position = Vector2(24, 16)
	title.add_theme_color_override("font_color", UiTheme.AMBER)
	title.add_theme_font_size_override("font_size", 20)
	add_child(title)
	var sub := Label.new()
	sub.text = "Every Robbie the station has sent, newest first. Click one to watch its transmission."
	sub.position = Vector2(24, 46)
	sub.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	sub.add_theme_font_size_override("font_size", 13)
	add_child(sub)
	var close := IconButton.make("close", "Back to the station (W or Esc)", func() -> void: closed.emit())
	close.position = Vector2(1222, 14)
	close.custom_minimum_size = Vector2(34, 32)
	add_child(close)

	_summary = RichTextLabel.new()
	_summary.bbcode_enabled = true
	_summary.scroll_active = false
	_summary.position = Vector2(24, 74)
	_summary.size = Vector2(1180, 44)
	_summary.add_theme_font_size_override("normal_font_size", 13)
	_summary.add_theme_font_size_override("bold_font_size", 13)
	add_child(_summary)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(24, 122)
	_scroll.size = Vector2(1240, 586)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_scroll.add_child(_grid)

	_empty = Label.new()
	_empty.text = "No Robbies yet. The wall fills up as you send them."
	_empty.position = Vector2(24, 300)
	_empty.size = Vector2(1232, 40)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	add_child(_empty)


## Rebuild the wall from the station's records.
func refresh(s: GameState) -> void:
	state = s
	for c in _grid.get_children():
		c.queue_free()
	var items := plaques(s)
	_empty.visible = items.is_empty()
	for it in items:
		_grid.add_child(_plaque(it))
	_scroll.scroll_vertical = 0
	_summary.text = "   ·   ".join(PackedStringArray(_room_lines(s)))


## Every plaque, newest first: {room, entry, order}. Own Robbies are ordered by
## serial; survey losses sit just after the Robbie whose program they tested.
static func plaques(s: GameState) -> Array:
	var out: Array = []
	for id in GameState.ROOMS:
		var last_serial := 0
		var n := 0
		for e in s.room_state(id).dives:
			n += 1
			if not e.get("survey", false):
				last_serial = int(e["serial"])
				out.append({"room": id, "entry": e, "order": last_serial * 1000})
			else:
				out.append({"room": id, "entry": e, "order": last_serial * 1000 + n})
	out.sort_custom(func(a, b) -> bool: return a["order"] > b["order"])
	return out


static func room_summary(s: GameState, id: String) -> Dictionary:
	var rs := s.room_state(id)
	var sent := 0
	var lost := 0
	var first_exit := -1
	for e in rs.dives:
		sent += 1
		if e["result"] != "exit":
			lost += 1
		elif not e.get("survey", false) and first_exit < 0:
			first_exit = int(e["serial"])
	return {"sent": sent, "lost": lost, "first_exit": first_exit, "certified": rs.certified}


func _room_lines(s: GameState) -> Array:
	var lines: Array = []
	for i in GameState.ROOMS.size():
		var id: String = GameState.ROOMS[i]
		var sm := room_summary(s, id)
		var title := s.room_state(id).room.title
		var txt := "[color=#ffc35a]%d · %s[/color]  " % [i + 1, title]
		if sm["sent"] == 0:
			txt += "[color=#8b8f94]no Robbies yet[/color]"
		else:
			txt += "%d lost" % sm["lost"]
			if sm["certified"]:
				txt += "  [color=#7dffa0]certified at %d CPU[/color]" % s.room_state(id).best_cpu
			elif sm["first_exit"] > 0:
				txt += "  [color=#7dffa0]through with Robbie\u00a0%03d[/color]" % sm["first_exit"]
		lines.append(txt)
	return lines


func _plaque(it: Dictionary) -> Control:
	var e: Dictionary = it["entry"]
	var room_id: String = it["room"]
	var made_it: bool = e["result"] == "exit"
	var survey: bool = e.get("survey", false)
	var normal := UiTheme.box(Color("0d131a"), Color("1e2835"), 4, 10)
	var hover := UiTheme.box(Color("131c27"), UiTheme.AMBER.darkened(0.35), 4, 10)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(PLAQUE_W, 100)
	p.add_theme_stylebox_override("panel", normal)
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.tooltip_text = "Watch this transmission"
	p.mouse_entered.connect(func() -> void: p.add_theme_stylebox_override("panel", hover))
	p.mouse_exited.connect(func() -> void: p.add_theme_stylebox_override("panel", normal))
	p.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			entry_chosen.emit(room_id, e))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(col)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var who := Label.new()
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if survey:
		who.text = "SURVEY ROBBIE"
		who.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	else:
		who.text = "ROBBIE %03d" % int(e["serial"])
		who.add_theme_color_override("font_color", UiTheme.GREEN if made_it else UiTheme.AMBER)
	who.add_theme_font_size_override("font_size", 16)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(who)
	var where := Label.new()
	where.mouse_filter = Control.MOUSE_FILTER_IGNORE
	where.text = state.room_state(room_id).room.title.to_upper()
	where.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	where.add_theme_font_size_override("font_size", 11)
	head.add_child(where)

	# The route on a small map, with the words beside it.
	var body := HBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 10)
	col.add_child(body)
	var rm := state.room_state(room_id).room
	body.add_child(RouteThumb.make(rm, e, Vector2(THUMB_W, THUMB_W * rm.h / rm.w)))
	var words_col := VBoxContainer.new()
	words_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words_col.add_theme_constant_override("separation", 3)
	words_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(words_col)

	var how := Label.new()
	how.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var what := "reached the exit" if made_it else "lost: %s" % Voice.cause_label(e["cause"])
	var extra := "  ·  conditions %d" % ((int(e["seed"]) - 1) % 100 + 1) if survey else ""
	how.text = "%s\n%s s  ·  %d CPU%s" % [what, e["seconds"], int(e["cpu"]), extra]
	how.add_theme_color_override("font_color", UiTheme.GREEN if made_it else UiTheme.RED.lerp(UiTheme.TEXT, 0.35))
	how.add_theme_font_size_override("font_size", 11)
	words_col.add_child(how)

	var words: String = e.get("last_words", "")
	var epitaph := Label.new()
	epitaph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	epitaph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	epitaph.custom_minimum_size = Vector2(PLAQUE_W - 34 - THUMB_W, 0)
	if words != "":
		epitaph.text = "\"%s\"" % words
		epitaph.add_theme_color_override("font_color", Color("ffe9b8"))
	else:
		epitaph.text = "Survey Robbies don't send last words." if survey else ""
		epitaph.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	epitaph.add_theme_font_size_override("font_size", 12)
	words_col.add_child(epitaph)
	return p


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_W]:
		closed.emit()
		get_viewport().set_input_as_handled()
