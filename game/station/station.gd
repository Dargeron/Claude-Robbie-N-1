extends Control
## The orbital station: write Robbie's program, launch it, watch its transmission,
## understand what happened, try again. P0b, first playable.


var state := GameState.new()
var room_id := "dark"
var program: Program
var current_dive: Dive
var current_entry: Dictionary = {}
var _last_why_tick := -1

# UI
var replay: ReplayPlayer
var monitor: SubViewportContainer
var watch_large := false
var mute_btn: IconButton
var watch_hint: Label
var monitor_hint: Label
var room_buttons := {}
var serial_label: Button
var wall: RobbieWall
var log_btn: Button
var station_log: StationLog
var manual: RobbieManual
var coach: Coach
var _coach_scrubbed := false      # the player has dragged along a transmission's timeline
var _coach_edited := false        # ...and changed the program since the first loss
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
var survey_run: Survey.Run = null   # a survey fleet that is out right now
var survey_strip: SurveyStrip
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
	if OS.get_cmdline_user_args().has("perf"):
		_benchmark.call_deferred()


## Timing of the heavy parts, printed to the console (run with the user argument "perf";
## the web test page passes it so we can measure the browser build).
func _benchmark() -> void:
	for id: String in GameState.ROOMS:
		var rs := state.room_state(id)
		var dir: String = "res://content/programs/" + id
		var files := Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool: return f.begins_with("intended") and f.ends_with(".rbt"))
		files.sort()
		var prog := ProgramFiles.load_program(dir + "/" + str(files[0]))
		var t0 := Time.get_ticks_usec()
		var d := Dive.new(rs.room, prog, 1)
		d.vm.record_senses = true
		d.run()
		var t1 := Time.get_ticks_usec()
		var v := DiveView.new()
		v.setup(d)
		var caps := Voice.captions(d, 5, {})
		var t2 := Time.get_ticks_usec()
		v.free()
		print("[perf] %-10s dive %5.1f s of water: sim %4d ms, replay setup %4d ms, %d captions" % [
			id, d.rec.ticks / 30.0, (t1 - t0) / 1000, (t2 - t1) / 1000, caps.size()])
	var t3 := Time.get_ticks_usec()
	var nursery := state.room_state("nursery")
	Survey.run(nursery.room, Program.parse("shoot\nfollow_wall left"))
	print("[perf] nursery survey of %d: %d ms" % [Survey.FLEET, (Time.get_ticks_usec() - t3) / 1000])
	print("[perf] done")


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
	tabs.position = Vector2(372, 8)
	tabs.add_theme_constant_override("separation", 4)
	add_child(tabs)
	var group := ButtonGroup.new()
	for i in GameState.ROOMS.size():
		var id: String = GameState.ROOMS[i]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(118, 0)
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func() -> void: _select_room(id))
		tabs.add_child(b)
		room_buttons[id] = b
	serial_label = _button("", "The Wall of Robbies: every Robbie sent, and its last words (W)", _open_wall)
	serial_label.position = Vector2(992, 8)
	serial_label.custom_minimum_size = Vector2(192, 0)
	serial_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	add_child(serial_label)
	log_btn = _button("Log", "The station log (L)", _open_log)
	log_btn.position = Vector2(1190, 8)
	log_btn.custom_minimum_size = Vector2(78, 0)
	add_child(log_btn)

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
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	svc.gui_input.connect(func(e: InputEvent) -> void:
		if watch_large and e is InputEventMouseButton and e.pressed:
			_toggle_watch())
	add_child(svc)
	monitor = svc
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
	speed_btn = _button("AUTO", "Playback speed. AUTO skims quiet water and slows down when something happens.", func() -> void: replay.cycle_speed())
	speed_btn.custom_minimum_size = Vector2(50, 0)
	speed_btn.add_theme_font_size_override("font_size", 12)
	transport.add_child(speed_btn)
	transport.add_child(IconButton.make("expand", "Watch large (F)", _toggle_watch))
	mute_btn = IconButton.make("sound", "Sound on/off (M)", _toggle_mute)
	transport.add_child(mute_btn)
	timeline = Timeline.new()
	timeline.position = Vector2(244, 418)
	timeline.size = Vector2(412, 30)
	timeline.tooltip_text = "Click or drag to jump. Red: hits. Pink: the lurker wakes. Colours: which rule was driving."
	timeline.seek_requested.connect(func(t: float) -> void:
		_coach_scrubbed = true
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
	actions.add_child(_button("Manual", "Every order and condition, explained (H)", _open_manual))
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
	# Room for three lines whatever it says, so LAUNCH doesn't jump up and down as the text changes.
	status_label.custom_minimum_size = Vector2(0, 64)
	col.add_child(status_label)
	survey_btn = _button("SEND THE SURVEY FLEET", "%d Robbies dive with this program under new conditions. %d must make it." % [Survey.FLEET, Survey.needed_for(Survey.FLEET)], _survey)
	col.add_child(survey_btn)
	survey_strip = SurveyStrip.new()
	col.add_child(survey_strip)
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

	coach = Coach.new()
	add_child(coach)

	wall = RobbieWall.new()
	wall.visible = false
	wall.closed.connect(_close_wall)
	wall.entry_chosen.connect(_open_from_wall)
	add_child(wall)

	station_log = StationLog.new()
	station_log.visible = false
	station_log.closed.connect(func() -> void:
		station_log.visible = false
		_refresh())
	add_child(station_log)

	manual = RobbieManual.new()
	manual.visible = false
	manual.closed.connect(func() -> void: manual.visible = false)
	add_child(manual)


## Room tabs: number and name; certified rooms turn green.
func _label_room_tab(b: Button, rid: String) -> void:
	var done := state.room_state(rid).certified
	var i := GameState.ROOMS.find(rid)
	var open := state.room_unlocked(rid)
	b.text = "%d · %s" % [i + 1, _room_name(rid)]
	b.disabled = not open
	b.add_theme_color_override("font_color", UiTheme.GREEN if done else UiTheme.TEXT)
	if not open:
		b.tooltip_text = "Locked: certify %s to open it" % _room_name(GameState.ROOMS[i - 1])
	else:
		b.tooltip_text = "Certified by the survey fleet" if done else "Not certified yet"


func _room_name(id: String) -> String:
	return state.room_state(id).room.title


func _button(text: String, tip: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(on_press)
	return b


func _input(event: InputEvent) -> void:
	# Browsers allow sound only after the player touches something.
	if event is InputEventMouseButton and event.pressed:
		Sfx.start_ambience()
		if get_viewport().gui_get_hovered_control() is BaseButton:
			Sfx.play("ui_click", -10.0)


# ---------------------------------------------------------------- rooms and program

func _select_room(id: String) -> void:
	room_id = id
	var rs := state.room_state(id)
	program = Program.parse(rs.program_text)
	editor.set_program(program)
	for rid in room_buttons:
		var b: Button = room_buttons[rid]
		_label_room_tab(b, rid)
		b.button_pressed = rid == id
	current_dive = null
	current_entry = {}
	if survey_run == null or survey_run.room.id != id:
		survey_strip.show_report(rs.survey)
	else:
		survey_strip.start(survey_run)
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
	monitor_hint.text = "NO TRANSMISSIONS FROM %s YET\nWrite a program and launch a Robbie." % _room_name(room_id).to_upper()
	monitor_hint.visible = true
	why.text = _intro_text()


func _intro_text() -> String:
	var rs := state.room_state(room_id)
	return ("[color=#ffc35a][b]%s[/b][/color]\n\nNobody has seen this place. Robbie will only know what its lamp and sensors reach.\n\n" +
		"Robbie reads its rules from the top, several times a second, and follows the first one that applies.\n" +
		"CPU budget here: [b]%d[/b]. Energy: [b]%d[/b].\n\n" +
		"When a Robbie is lost, its transmission arrives here. Scrub through it, see which rule was running, and fix the program.") % [
		_room_name(room_id), rs.room.cpu_budget, rs.room.energy]


func _on_program_changed() -> void:
	_last_why_tick = -1   # the Why? panel notes when the replayed Robbie's program differs: refresh it
	if state.next_serial > 1:
		_coach_edited = true
	state.room_state(room_id).program_text = program.to_text()
	_refresh()


func _refresh() -> void:
	var rs := state.room_state(room_id)
	var budget := rs.room.cpu_budget
	var used := program.cpu()
	title_label.text = "PROGRAM  ·  %s" % _room_name(room_id).to_upper()
	cpu_label.text = "CPU %d / %d" % [used, budget]
	cpu_label.add_theme_color_override("font_color", UiTheme.RED if used > budget else UiTheme.CYAN)
	cpu_bar.max_value = budget
	cpu_bar.value = mini(used, budget)
	var over := used > budget
	launch_btn.disabled = over or program.rules.is_empty()
	launch_btn.text = "LAUNCH ROBBIE %03d" % state.next_serial
	serial_label.text = "Robbies sent: %d  ·  Wall" % (state.next_serial - 1)
	var unread := StationLog.unread(state)
	log_btn.text = "Log  +%d" % unread if unread > 0 else "Log"
	log_btn.add_theme_color_override("font_color", UiTheme.AMBER if unread > 0 else UiTheme.TEXT_DIM)
	survey_btn.disabled = not state.program_made_it(room_id, program.to_text()) or over or survey_run != null
	survey_btn.visible = not rs.certified or not rs.survey.is_empty()
	_refresh_status()


func _refresh_status() -> void:
	var rs := state.room_state(room_id)
	var lines: Array[String] = []
	if not rs.certified:
		var hint := Voice.mission_control(room_id, state.own_dives(room_id).size(), state.loss_streak(room_id),
			state.losses_since_success(room_id), state.next_serial)
		if hint != "":
			lines.append("[color=#7fd8ff]%s[/color]" % hint)
	if program.cpu() > rs.room.cpu_budget:
		lines.append("[color=#ff6a5a]Over the CPU budget: Robbie can't hold this program. Remove or simplify a rule.[/color]")
	if rs.certified:
		# At most three lines, so LAUNCH stays put: the verdict (and news), the CPU record.
		var head := "[color=#7dffa0]Certified: the survey fleet made it %d/%d.[/color]" % [rs.survey.get("passed", 0), rs.survey.get("fleet", 10)]
		var nxt := GameState.ROOMS.find(room_id) + 1
		if nxt < GameState.ROOMS.size() and state.room_state(GameState.ROOMS[nxt]).dives.is_empty():
			head += " [color=#7dffa0]%s is open.[/color]" % _room_name(GameState.ROOMS[nxt])
		if StationLog.unread(state) > 0:
			head += " [color=#ffc35a]New in the station log (L).[/color]"
		lines.append(head)
		var rec := GameState.record_cpu(room_id)
		var mine := "Your cheapest certified program: [b]%d CPU[/b]." % rs.best_cpu
		if rec > 0 and rec < rs.best_cpu:
			lines.append(mine + " The station's simulator has certified one with [b]%d[/b]. Try again with less CPU, or move on." % rec)
		elif rec > 0:
			lines.append(mine + " [color=#7dffa0]That matches the cheapest the station's simulator has found.[/color]")
		else:
			lines.append(mine + " Try again with less CPU, or move on.")
	elif not rs.survey.is_empty():
		lines.append("Last survey: [color=#ff6a5a]%d/%d made it[/color] (%d needed). The failures are in the list below." % [rs.survey["passed"], rs.survey["fleet"], rs.survey["needed"]])
	elif state.program_made_it(room_id, program.to_text()):
		lines.append("[color=#7dffa0]This program reached the exit.[/color] Send the survey fleet to prove it wasn't luck.")
	status_label.text = "\n".join(lines)


# ---------------------------------------------------------------- launching and watching

func _launch() -> void:
	if program.rules.is_empty() or program.cpu() > state.room_state(room_id).room.cpu_budget:
		return
	Sfx.play("ui_launch", -4.0)
	var res := state.launch(room_id, program)
	_refresh_archive()
	_show(res["dive"], res["entry"], res["history"])
	_refresh()


## The survey fleet goes out a few Robbies per frame (see _process), so the station
## stays responsive and the results come back one by one.
func _survey() -> void:
	if survey_run != null:
		return
	survey_run = Survey.Run.new(state.room_state(room_id).room, Program.parse(program.to_text()))
	survey_btn.disabled = true
	survey_strip.start(survey_run)


func _step_survey() -> void:
	var t0 := Time.get_ticks_msec()
	while not survey_run.done() and Time.get_ticks_msec() - t0 < 12:
		survey_run.step()
	survey_strip.queue_redraw()
	if not survey_run.done():
		survey_btn.text = "SURVEY FLEET: %d OF %d BACK" % [survey_run.dives.size(), survey_run.fleet]
		return
	var run := survey_run
	survey_run = null
	survey_btn.text = "SEND THE SURVEY FLEET"
	_finish_survey(run)


func _finish_survey(run: Survey.Run) -> void:
	var report := state.finish_survey(run.room.id, run.program, run.report())
	if run.room.id != room_id:
		return   # the player moved to another room meanwhile; the result is saved there
	Sfx.play("exit" if report["certified"] else "burst", -6.0)
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
		_label_room_tab(b, rid)


func _show(dive: Dive, entry: Dictionary, history: Dictionary) -> void:
	current_dive = dive
	current_entry = entry
	monitor_hint.visible = false
	var serial: int = entry["serial"]
	replay.play(dive, maxi(serial, 0), Voice.captions(dive, maxi(serial, 1), history) if serial > 0 else [])
	replay.view.station_memory = state.memory_before(room_id, entry)
	replay.view.ghost = state.ghost_for(room_id, entry)
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
		var who := "ROBBIE %03d" % e["serial"] if not e.get("survey", false) else "Survey, conditions %d" % ((int(e["seed"]) - 1) % 100 + 1)
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

## First visit: point at the one thing to do next, until Robbie 002 has been sent.
func _update_coach() -> void:
	if state.coach_done or wall.visible or station_log.visible or manual.visible or watch_large:
		coach.point_at(null, "")
		return
	if state.next_serial >= 3 or (state.next_serial == 2 and _any_exit()):
		state.coach_done = true
		state.save()
		coach.point_at(null, "")
	elif state.next_serial == 1:
		coach.point_at(launch_btn, "Press LAUNCH to send Robbie down")
	elif not _coach_scrubbed:
		coach.point_at(timeline, "Robbie is lost. Drag along here to see why")
	elif not _coach_edited:
		coach.point_at(editor, "Change a rule, or add one with + New rule")
	else:
		coach.point_at(launch_btn, "Send the next Robbie")


func _any_exit() -> bool:
	for id in GameState.ROOMS:
		if state.program_made_it(id, state.room_state(id).program_text):
			return true
	return false


func _process(_delta: float) -> void:
	_update_coach()
	if survey_run != null:
		_step_survey()
	if not replay.has_dive():
		play_btn.set_icon("play")
		return
	play_btn.set_icon("pause" if replay.playing and not replay.rewinding else "play")
	rewind_btn.modulate = UiTheme.AMBER if replay.rewinding else Color.WHITE
	speed_btn.text = replay.speed_label()
	var k := replay.tick()
	timeline.set_playhead(replay.view.t)
	# Light up the rule Robbie is following, but only when the editor holds that Robbie's program.
	var same: bool = current_dive != null and current_entry.get("text", "") == program.to_text()
	editor.set_highlight(current_dive.rec.rrule[k] if same else -1)
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
	out += "[color=#8b8f94]%s · why it did what it did[/color]\n" % who
	if current_entry.get("text", "") != program.to_text():
		out += "[color=#8b8f94][i]This Robbie ran a different program from the one in the editor. \"Use this Robbie's program\" loads it.[/i][/color]\n"
	out += "\n"
	if found >= 0:
		for line in DiveText.explain(current_dive.program, trace[found]):
			var l: String = line
			if l.find("chosen") >= 0:
				out += "[color=#7dffa0]> %s[/color]\n" % l
			elif l.find("applied") >= 0:
				out += "[color=#7fd8ff]+ %s[/color]\n" % l
			else:
				out += "[color=#8b8f94]· %s[/color]\n" % l
	if found >= 0:
		var parts := PackedStringArray()
		for sn in DiveText.senses(current_dive.room, trace[found]):
			var col := "#7fd8ff" if sn[2] else "#ddd6c6"
			parts.append("%s: [color=%s]%s[/color]" % [sn[0], col, sn[1]])
		if not parts.is_empty():
			out += "\n[color=#8b8f94]Robbie sensed:[/color] " + "  ·  ".join(parts) + "\n"
	var recent := PackedStringArray()
	var counts := {}
	for e in current_dive.world.events:
		var t: int = e["t"]
		if t <= k and k - t <= 60:
			var txt := _event_text(e)
			if counts.has(txt):
				counts[txt] += 1
			else:
				counts[txt] = 1
				recent.append(txt)
	for i in recent.size():
		if counts[recent[i]] > 1:
			recent[i] = "%s (x%d)" % [recent[i], counts[recent[i]]]
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
		"eel_hears":
			return "an eel heard Robbie moving"
		"lurker_strikes":
			return "the lurker struck" + (" and hit" if e["hit"] else " and missed")
		"laser":
			if e.get("bounced", false):
				if e["kind"] == "eel":
					return "the eel slipped out of the beam"
				return "the laser glanced off the %s" % e["kind"]
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


# ---------------------------------------------------------------- the Wall of Robbies

func _open_wall() -> void:
	if watch_large:
		_toggle_watch()
	replay.playing = false
	wall.refresh(state)
	move_child(wall, get_child_count() - 1)
	wall.visible = true


func _open_manual() -> void:
	if watch_large:
		_toggle_watch()
	move_child(manual, get_child_count() - 1)
	manual.visible = true


func _open_log() -> void:
	if watch_large:
		_toggle_watch()
	wall.visible = false
	replay.playing = false
	station_log.refresh(state)
	move_child(station_log, get_child_count() - 1)
	station_log.visible = true


func _close_wall() -> void:
	wall.visible = false


func _open_from_wall(id: String, entry: Dictionary) -> void:
	_close_wall()
	if id != room_id:
		_select_room(id)
	for i in archive_entries.size():
		if archive_entries[i] == entry:
			archive.select(i)
			archive.ensure_current_is_visible()
			_on_archive_selected(i)
			return


func _toggle_mute() -> void:
	Sfx.set_muted(not Sfx.muted)
	mute_btn.set_icon("muted" if Sfx.muted else "sound")


func _toggle_watch() -> void:
	watch_large = not watch_large
	if watch_large:
		monitor.stretch_shrink = 2
		monitor.position = Vector2.ZERO
		monitor.size = Vector2(1280, 720)
		move_child(monitor, get_child_count() - 1)
		if watch_hint == null:
			watch_hint = Label.new()
			watch_hint.text = "Click the picture or press F to go back to the station  ·  Space pauses  ·  arrow keys step 1 s"
			watch_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
			watch_hint.add_theme_font_size_override("font_size", 12)
			watch_hint.position = Vector2(16, 34)
			add_child(watch_hint)
		watch_hint.visible = true
		watch_hint.modulate.a = 1.0
		move_child(watch_hint, get_child_count() - 1)
		create_tween().tween_property(watch_hint, "modulate:a", 0.0, 1.5).set_delay(3.0)
	else:
		monitor.stretch_shrink = 1
		monitor.position = Vector2(16, 48)
		monitor.size = Vector2(640, 360)
		if watch_hint != null:
			watch_hint.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if wall.visible or station_log.visible or manual.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W:
				_open_wall()
				accept_event()
			KEY_L:
				_open_log()
				accept_event()
			KEY_H:
				_open_manual()
				accept_event()
			KEY_U:
				if event.ctrl_pressed and event.shift_pressed:   # testers: open every room
					state.unlock_all = true
					_select_room_buttons_only()
					accept_event()
			KEY_F:
				_toggle_watch()
				accept_event()
			KEY_M:
				_toggle_mute()
				accept_event()
			KEY_SPACE:
				replay.playing = not replay.playing
				accept_event()
			KEY_LEFT:
				replay.seek(replay.view.t - World.TICKS_PER_SECOND if replay.has_dive() else 0.0)
			KEY_RIGHT:
				replay.seek(replay.view.t + World.TICKS_PER_SECOND if replay.has_dive() else 0.0)
