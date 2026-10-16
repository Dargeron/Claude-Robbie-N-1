extends Control
## The orbital station: write Robbie's program, launch it, watch its transmission,
## understand what happened, try again. P0b, first playable.

const ROOM_NAMES := {"dark": "The Dark", "jellyfish": "The Jellyfish", "valve": "The Valve"}

var state := GameState.new()
var room_id := "dark"
var program: Program
var current_dive: Dive
var current_entry: Dictionary = {}
var _last_why_tick := -1

# UI
var replay: ReplayPlayer
var monitor_hint: Label
var room_buttons := {}
var serial_label: Label
var timeline: Timeline
var play_btn: IconButton
var speed_btn: Button
var rewind_btn: IconButton
var why: RichTextLabel
var title_label: Label
var cpu_label: Label
var cpu_bar: ProgressBar
var editor: ProgramEditor
var launch_btn: Button
var status_label: RichTextLabel
var survey_btn: Button
var archive: ItemList
var restore_btn: Button
var archive_entries: Array = []


func _ready() -> void:
	theme = UiTheme.build()
	RenderingServer.set_default_clear_color(UiTheme.BG)
	state.load_save()
	_build()
	_select_room(GameState.ROOMS[0])
	for id in GameState.ROOMS:
		if not state.room_state(id).certified:
			_select_room(id)
			break


# ---------------------------------------------------------------- layout

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "JUPITER ORBITAL STATION  ·  ROBBIE PROGRAMME"
	title.position = Vector2(16, 12)
	title.add_theme_color_override("font_color", UiTheme.AMBER)
	add_child(title)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(470, 8)
	add_child(tabs)
	var group := ButtonGroup.new()
	for i in GameState.ROOMS.size():
		var id: String = GameState.ROOMS[i]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(150, 0)
		b.pressed.connect(func() -> void: _select_room(id))
		tabs.add_child(b)
		room_buttons[id] = b
	serial_label = Label.new()
	serial_label.position = Vector2(1060, 12)
	serial_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	add_child(serial_label)

	# Monitor: the dive is drawn at 640x360 and shown 1:1.
	var frame := Panel.new()
	frame.position = Vector2(12, 44)
	frame.size = Vector2(648, 368)
	add_child(frame)
	var svc := SubViewportContainer.new()
	svc.position = Vector2(16, 48)
	svc.size = Vector2(640, 360)
	svc.stretch = true
	svc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(svc)
	var sv := SubViewport.new()
	sv.size = Vector2i(640, 360)
	sv.handle_input_locally = false
	svc.add_child(sv)
	replay = ReplayPlayer.new()
	sv.add_child(replay)
	replay.reached_end.connect(_on_replay_end)
	monitor_hint = Label.new()
	monitor_hint.position = Vector2(16, 200)
	monitor_hint.size = Vector2(640, 40)
	monitor_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	monitor_hint.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	add_child(monitor_hint)

	# Transport and timeline.
	var transport := HBoxContainer.new()
	transport.position = Vector2(16, 418)
	add_child(transport)
	var restart := IconButton.make("restart", "Back to the start", func() -> void: replay.seek(0.0))
	transport.add_child(restart)
	rewind_btn = IconButton.make("rewind", "Rewind", func() -> void:
		replay.rewinding = not replay.rewinding
		replay.playing = true)
	transport.add_child(rewind_btn)
	play_btn = IconButton.make("pause", "Play / pause", func() -> void:
		if replay.has_dive() and replay.tick() >= replay.view.last_tick() and not replay.playing:
			replay.seek(0.0)
		replay.playing = not replay.playing
		replay.rewinding = false)
	transport.add_child(play_btn)
	speed_btn = _button("×1", "Playback speed", func() -> void: replay.cycle_speed())
	speed_btn.custom_minimum_size = Vector2(44, 0)
	transport.add_child(speed_btn)
	timeline = Timeline.new()
	timeline.position = Vector2(200, 418)
	timeline.size = Vector2(456, 30)
	timeline.tooltip_text = "Click or drag to jump. Red: hits. Pink: the lurker wakes. Colours: which rule was driving."
	timeline.seek_requested.connect(func(t: float) -> void:
		replay.seek(t)
		replay.playing = false)
	add_child(timeline)

	var why_panel := PanelContainer.new()
	why_panel.position = Vector2(12, 456)
	why_panel.size = Vector2(648, 252)
	add_child(why_panel)
	why = RichTextLabel.new()
	why.bbcode_enabled = true
	why.scroll_active = false
	why.add_theme_font_size_override("normal_font_size", 13)
	why.add_theme_font_size_override("bold_font_size", 13)
	why_panel.add_child(why)

	# Program side.
	var right := PanelContainer.new()
	right.position = Vector2(672, 44)
	right.size = Vector2(596, 664)
	add_child(right)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	right.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	title_label = Label.new()
	title_label.add_theme_color_override("font_color", UiTheme.AMBER)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	cpu_label = Label.new()
	head.add_child(cpu_label)
	cpu_bar = ProgressBar.new()
	cpu_bar.show_percentage = false
	cpu_bar.custom_minimum_size = Vector2(0, 6)
	col.add_child(cpu_bar)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	editor = ProgramEditor.new()
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.add_theme_constant_override("separation", 6)
	editor.changed.connect(_on_program_changed)
	scroll.add_child(editor)
	var actions := HBoxContainer.new()
	col.add_child(actions)
	actions.add_child(_button("+ New rule", "Add a rule at the bottom of the list", func() -> void: editor.add_rule()))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(sp)
	launch_btn = _button("LAUNCH", "Send the next Robbie with this program", _launch)
	launch_btn.custom_minimum_size = Vector2(220, 40)
	launch_btn.add_theme_color_override("font_color", UiTheme.AMBER)
	launch_btn.add_theme_font_size_override("font_size", 16)
	actions.add_child(launch_btn)
	status_label = RichTextLabel.new()
	status_label.bbcode_enabled = true
	status_label.fit_content = true
	status_label.scroll_active = false
	col.add_child(status_label)
	survey_btn = _button("SEND THE SURVEY FLEET", "Ten Robbies dive with this program under new conditions. Eight must make it.", _survey)
	col.add_child(survey_btn)
	var arch_head := Label.new()
	arch_head.text = "TRANSMISSIONS RECEIVED"
	arch_head.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	arch_head.add_theme_font_size_override("font_size", 12)
	col.add_child(arch_head)
	archive = ItemList.new()
	archive.custom_minimum_size = Vector2(0, 150)
	archive.add_theme_font_size_override("font_size", 13)
	archive.item_selected.connect(_on_archive_selected)
	col.add_child(archive)
	restore_btn = _button("Use this Robbie's program", "Copy the selected Robbie's program into the editor", _restore_program)
	restore_btn.disabled = true
	col.add_child(restore_btn)


func _button(text: String, tip: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(on_press)
	return b


# ---------------------------------------------------------------- rooms and program

func _select_room(id: String) -> void:
	room_id = id
	var rs := state.room_state(id)
	program = Program.parse(rs.program_text)
	editor.set_program(program)
	for rid in room_buttons:
		var b: Button = room_buttons[rid]
		var done := state.room_state(rid).certified
		b.text = "%d · %s%s" % [GameState.ROOMS.find(rid) + 1, ROOM_NAMES[rid], "  (done)" if done else ""]
		b.button_pressed = rid == id
	current_dive = null
	current_entry = {}
	_refresh_archive()
	var own := state.own_dives(id)
	if not own.is_empty():
		_play_entry(own.back())
	else:
		_clear_monitor()
	_refresh()


func _clear_monitor() -> void:
	if replay.view != null:
		replay.view.queue_free()
		replay.hud.queue_free()
		replay.view = null
	timeline.set_dive(null)
	monitor_hint.text = "NO TRANSMISSIONS FROM %s YET\nWrite a program and launch a Robbie." % ROOM_NAMES[room_id].to_upper()
	monitor_hint.visible = true
	why.text = _intro_text()


func _intro_text() -> String:
	var rs := state.room_state(room_id)
	return ("[color=#ffc35a][b]%s[/b][/color]\n\nNobody has seen this place. Robbie will only know what its lamp and sensors reach.\n\n" +
		"Robbie reads its rules from the top, several times a second, and follows the first one that applies.\n" +
		"CPU budget here: [b]%d[/b]. Energy: [b]%d[/b].\n\n" +
		"When a Robbie is lost, its transmission arrives here. Scrub through it, see which rule was running, and fix the program.") % [
		ROOM_NAMES[room_id], rs.room.cpu_budget, rs.room.energy]


func _on_program_changed() -> void:
	state.room_state(room_id).program_text = program.to_text()
	_refresh()


func _refresh() -> void:
	var rs := state.room_state(room_id)
	var budget := rs.room.cpu_budget
	var used := program.cpu()
	title_label.text = "PROGRAM  ·  %s" % ROOM_NAMES[room_id].to_upper()
	cpu_label.text = "CPU %d / %d" % [used, budget]
	cpu_label.add_theme_color_override("font_color", UiTheme.RED if used > budget else UiTheme.CYAN)
	cpu_bar.max_value = budget
	cpu_bar.value = mini(used, budget)
	var over := used > budget
	launch_btn.disabled = over or program.rules.is_empty()
	launch_btn.text = "LAUNCH ROBBIE %03d" % state.next_serial
	serial_label.text = "Robbies sent: %d" % (state.next_serial - 1)
	survey_btn.disabled = not state.program_made_it(room_id, program.to_text()) or over
	survey_btn.visible = not rs.certified or not rs.survey.is_empty()
	_refresh_status()


func _refresh_status() -> void:
	var rs := state.room_state(room_id)
	var lines: Array[String] = []
	if program.cpu() > rs.room.cpu_budget:
		lines.append("[color=#ff6a5a]Over the CPU budget: Robbie can't hold this program. Remove or simplify a rule.[/color]")
	if rs.certified:
		lines.append("[color=#7dffa0]Certified: the survey fleet made it %d/%d.[/color] Try again with less CPU, or move on." % [rs.survey.get("passed", 0), rs.survey.get("fleet", 10)])
	elif not rs.survey.is_empty():
		lines.append("Last survey: [color=#ff6a5a]%d/%d made it[/color] (%d needed). The failures are in the list below." % [rs.survey["passed"], rs.survey["fleet"], rs.survey["needed"]])
	elif state.program_made_it(room_id, program.to_text()):
		lines.append("[color=#7dffa0]This program reached the exit.[/color] Send the survey fleet to prove it wasn't luck.")
	status_label.text = "\n".join(lines)


# ---------------------------------------------------------------- launching and watching

func _launch() -> void:
	if program.rules.is_empty() or program.cpu() > state.room_state(room_id).room.cpu_budget:
		return
	var res := state.launch(room_id, program)
	_refresh_archive()
	_show(res["dive"], res["entry"], res["history"])
	_refresh()


func _survey() -> void:
	var report := state.survey(room_id, program)
	_refresh_archive()
	_select_room_buttons_only()
	_refresh()
	if not report["certified"]:
		for i in archive_entries.size():
			if archive_entries[i].get("survey", false):
				archive.select(i)
				_on_archive_selected(i)
				break


func _select_room_buttons_only() -> void:
	for rid in room_buttons:
		var b: Button = room_buttons[rid]
		b.text = "%d · %s%s" % [GameState.ROOMS.find(rid) + 1, ROOM_NAMES[rid], "  (done)" if state.room_state(rid).certified else ""]


func _show(dive: Dive, entry: Dictionary, history: Dictionary) -> void:
	current_dive = dive
	current_entry = entry
	monitor_hint.visible = false
	var serial: int = entry["serial"]
	replay.play(dive, maxi(serial, 0), Voice.captions(dive, maxi(serial, 1), history) if serial > 0 else [])
	timeline.set_dive(dive)
	_last_why_tick = -1


func _play_entry(entry: Dictionary) -> void:
	var dive := state.redive(room_id, entry)
	var history := {}
	var own := state.own_dives(room_id)
	var at := own.find(entry)
	if at > 0:
		history = {"prev_serial": own[at - 1]["serial"], "prev_cause": own[at - 1]["cause"]}
	_show(dive, entry, history)
	replay.seek(float(dive.rec.ticks - 1))
	replay.playing = false


func _on_replay_end() -> void:
	pass


func _refresh_archive() -> void:
	archive.clear()
	archive_entries = []
	var dives: Array = state.room_state(room_id).dives.duplicate()
	dives.reverse()
	for e in dives:
		var who := "ROBBIE %03d" % e["serial"] if not e.get("survey", false) else "Survey, conditions %d" % (int(e["seed"]) - GameState.SURVEY_FIRST_SEED + 1)
		var what := "reached the exit" if e["result"] == "exit" else "lost: %s" % Voice.cause_label(e["cause"])
		var idx := archive.add_item("%s  ·  %s  ·  %s s  ·  %d CPU" % [who, what, e["seconds"], e["cpu"]])
		archive.set_item_custom_fg_color(idx, UiTheme.GREEN if e["result"] == "exit" else (UiTheme.TEXT_DIM if e.get("survey", false) else UiTheme.TEXT))
		var words: String = e.get("last_words", "")
		if words != "":
			archive.set_item_tooltip(idx, "\"%s\"" % words)
		archive_entries.append(e)
	restore_btn.disabled = true


func _on_archive_selected(i: int) -> void:
	if i < 0 or i >= archive_entries.size():
		return
	var e: Dictionary = archive_entries[i]
	_play_entry(e)
	replay.seek(0.0)
	replay.playing = true
	restore_btn.disabled = false


func _restore_program() -> void:
	var sel := archive.get_selected_items()
	if sel.is_empty():
		return
	program = Program.parse(archive_entries[sel[0]]["text"])
	editor.set_program(program)
	_on_program_changed()


# ---------------------------------------------------------------- per frame

func _process(_delta: float) -> void:
	if not replay.has_dive():
		play_btn.set_icon("play")
		return
	play_btn.set_icon("pause" if replay.playing and not replay.rewinding else "play")
	rewind_btn.modulate = UiTheme.AMBER if replay.rewinding else Color.WHITE
	speed_btn.text = "×%s" % str(replay.speed()).trim_suffix(".0")
	var k := replay.tick()
	timeline.set_playhead(replay.view.t)
	editor.set_highlight(current_dive.rec.rrule[k] if current_dive != null else -1)
	if k != _last_why_tick:
		_last_why_tick = k
		why.text = _why_text(k)


## The Why? panel: what Robbie checked at its last think before this moment.
func _why_text(k: int) -> String:
	if current_dive == null:
		return ""
	var trace := current_dive.vm.trace
	var lo := 0
	var hi := trace.size() - 1
	var found := -1
	while lo <= hi:
		var mid := (lo + hi) / 2
		if int(trace[mid]["t"]) <= k:
			found = mid
			lo = mid + 1
		else:
			hi = mid - 1
	var out := "[color=#ffc35a][b]T+%s[/b][/color]   " % DiveText.time_of(k)
	var who := "Robbie %03d" % current_entry.get("serial", 0) if current_entry.get("serial", -1) > 0 else "Survey Robbie"
	out += "[color=#8b8f94]%s · why it did what it did[/color]\n\n" % who
	if found >= 0:
		for line in DiveText.explain(current_dive.program, trace[found]):
			var l: String = line
			if l.find("chosen") >= 0:
				out += "[color=#7dffa0]> %s[/color]\n" % l
			elif l.find("applied") >= 0:
				out += "[color=#7fd8ff]+ %s[/color]\n" % l
			else:
				out += "[color=#8b8f94]· %s[/color]\n" % l
	var recent := PackedStringArray()
	for e in current_dive.world.events:
		var t: int = e["t"]
		if t <= k and k - t <= 60:
			recent.append(_event_text(e))
	if not recent.is_empty():
		out += "\n[color=#ffc35a]Just happened:[/color] " + "  ·  ".join(recent)
	if k >= current_dive.rec.ticks - 1:
		var words: String = current_entry.get("last_words", "")
		if words != "":
			out += "\n\n[color=#ffe9b8][i]Last transmission: \"%s\"[/i][/color]" % words
	return out


func _event_text(e: Dictionary) -> String:
	match e["type"]:
		"damage":
			return "hit by %s (hull %d)" % [Voice.cause_label(e["cause"]), e["hp"]]
		"crash":
			return "scraped rock"
		"lurker_wakes":
			return "the lurker woke"
		"lurker_strikes":
			return "the lurker struck" + (" and hit" if e["hit"] else " and missed")
		"laser":
			return "laser fired at a %s" % e["kind"]
		"valve":
			return "valve %s" % e["state"]
		"valve_sting":
			return "the valve stung"
		"exit":
			return "reached the exit"
		"energy_out":
			return "energy ran out"
	return e["type"]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				replay.playing = not replay.playing
				accept_event()
			KEY_LEFT:
				replay.seek(replay.view.t - World.TICKS_PER_SECOND if replay.has_dive() else 0.0)
			KEY_RIGHT:
				replay.seek(replay.view.t + World.TICKS_PER_SECOND if replay.has_dive() else 0.0)
