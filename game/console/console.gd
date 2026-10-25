extends Control
## The operator's console: the whole game on one dark desk (docs/design/station-ui.md).
## The sonar receiver, the wire recorder and the teleprinter on the left; the card rack,
## the keypunch, the reader's load gauge, the sea trials and the dispatch lever on the
## right; the Company tube, the sector selector, the shift counter, Bathy's porthole and
## the hangar window along the top. Nothing floats over it except paper.
## Prototype: the first three sectors, three shifts.

const SAVE := "user://console_save.json"
const SECTORS := ["dark", "jellyfish", "nursery"]
const TICKS := World.TICKS_PER_SECOND

var state := GameState.new()
var story: Dictionary = {}
var room_id := "dark"
var program: Program
var current_dive: Dive
var current_entry: Dictionary = {}
var survey_run: Survey.Run = null
var magnified := false

var plate: TextureRect
var scope: Scope
var recorder: WireRecorder
var teleprinter: Teleprinter
var rack: CardRack
var keypunch: Keypunch
var gauge: LoadGauge
var trials: SeaTrials
var dispatch: DispatchLever
var tube: Topside.Tube
var dial: Topside.SectorDial
var nixies: Topside.Nixies
var porthole: MoodPorthole
var hangar: Topside.HangarWindow
var light: Lights
var notes_layer: Control
var memo: MemoView
var wall: WallView
var stamp: Stamp
var deck_tab: Hotspot
var _notes := {}                 # note id -> OpNote on the console
var _transient := {}             # note id -> time it should peel
var _scrubbed := false
var _scope_rect := Rect2()
var _unread_seen := -1


func _ready() -> void:
	theme = UiTheme.build()
	RenderingServer.set_default_clear_color(Color(0.02, 0.025, 0.024))
	story = JSON.parse_string(FileAccess.get_file_as_string("res://content/story/console.json"))
	if state.save_path == GameState.SAVE_PATH:
		state.save_path = SAVE   # tools set their own before the console starts
	state.load_save()
	_build()
	var start := SECTORS[0]
	for id: String in SECTORS:
		if state.room_unlocked(id):
			start = id
		if not state.room_state(id).certified:
			break
	_select_sector(start)
	_refresh_plates(false)
	_unread_seen = _unread().size()
	tube.pending = _unread_seen


# ---------------------------------------------------------------- building the desk

func _build() -> void:
	plate = TextureRect.new()
	plate.texture = Desk.tex("plate")
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.size = Vector2(1280, 720)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)

	scope = Scope.new()
	_scope_rect = Desk.r("screen")
	_place(scope, _scope_rect)
	scope.tapped.connect(_toggle_magnify)
	add_child(scope)

	recorder = WireRecorder.new()
	_place(recorder, Desk.r("recorder"))
	recorder.replay = scope.replay
	recorder.scrubbed.connect(func() -> void: _scrubbed = true)
	add_child(recorder)

	teleprinter = Teleprinter.new()
	var tp := Desk.r("teleprinter")
	_place(teleprinter, Rect2(tp.position, Vector2(Desk.r("binder").position.x - tp.position.x - 8, tp.size.y)))
	teleprinter.replay = scope.replay
	teleprinter.line_tapped.connect(_on_tape_line)
	teleprinter.torn.connect(_on_torn)
	add_child(teleprinter)

	var binder := Hotspot.new()
	_place(binder, Desk.r("binder"))
	binder.tapped.connect(_open_binder)
	binder.label = "BINDER"
	add_child(binder)
	var wall_spot := Hotspot.new()
	_place(wall_spot, Desk.r("wall"))
	wall_spot.tapped.connect(_open_wall)
	wall_spot.painter = _paint_wall_count
	add_child(wall_spot)
	var mag := Hotspot.new()
	_place(mag, Desk.r("magnify"))
	mag.tapped.connect(_toggle_magnify)
	mag.label = "MAGNIFY"
	mag.label_size = 13
	mag.stencil = true
	add_child(mag)
	var gain := Hotspot.new()
	_place(gain, Rect2(552, 380, 30, 20))
	gain.tapped.connect(_toggle_mute)
	gain.painter = _paint_gain
	add_child(gain)

	tube = Topside.Tube.new()
	_place(tube, Desk.r("tube"))
	tube.opened.connect(_open_next_memo)
	add_child(tube)
	dial = Topside.SectorDial.new()
	_place(dial, Desk.r("sector"))
	dial.chosen.connect(func(i: int) -> void: _select_sector(SECTORS[i]))
	add_child(dial)
	nixies = Topside.Nixies.new()
	_place(nixies, Desk.r("shift"))
	add_child(nixies)
	porthole = MoodPorthole.new()
	_place(porthole, Desk.r("porthole"))
	add_child(porthole)
	hangar = Topside.HangarWindow.new()
	_place(hangar, Desk.r("hangar"))
	hangar.tapped.connect(func() -> void: _show_memo(_memo_from(story["hangar"], "memo")))
	add_child(hangar)

	rack = CardRack.new()
	_place(rack, Desk.r("rack"))
	rack.drop_zone = _drop_zone
	rack.changed.connect(_on_program_changed)
	rack.card_tapped.connect(_on_card_tapped)
	rack.card_dropped.connect(_on_card_dropped)
	add_child(rack)
	deck_tab = Hotspot.new()
	_place(deck_tab, Rect2(860, 452, 170, 16))
	deck_tab.tapped.connect(_load_his_deck)
	deck_tab.painter = _paint_deck_tab
	add_child(deck_tab)
	gauge = LoadGauge.new()
	_place(gauge, Desk.r("gauge"))
	add_child(gauge)
	trials = SeaTrials.new()
	_place(trials, Desk.r("trials"))
	trials.cranked.connect(_start_trials)
	trials.lamp_tapped.connect(_on_trial_lamp)
	trials.locked_tapped.connect(func() -> void: _flash_note("trials_locked", "No beacon on record for this deck. Get one hull to the beacon first.", Vector2(1040, 360), Desk.r("trials").get_center()))
	add_child(trials)
	dispatch = DispatchLever.new()
	_place(dispatch, Desk.r("dispatch"))
	dispatch.dispatched.connect(_dispatch)
	dispatch.refused.connect(_on_refused)
	add_child(dispatch)
	keypunch = Keypunch.new()
	_place(keypunch, Desk.r("keypunch"))
	add_child(keypunch)
	keypunch.setup()
	keypunch.punched.connect(_on_punched)
	keypunch.plate_missing.connect(_on_plate_missing)

	light = Lights.new()
	light.console = self
	light.size = Vector2(1280, 720)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(light)

	notes_layer = Control.new()
	notes_layer.size = Vector2(1280, 720)
	notes_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notes_layer)

	stamp = Stamp.new()
	stamp.size = Vector2(1280, 720)
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stamp)

	memo = MemoView.new()
	memo.visible = false
	memo.closed.connect(_on_memo_closed)
	memo.start_over.connect(_start_over)
	add_child(memo)

	wall = WallView.new()
	wall.visible = false
	wall.closed.connect(func() -> void: wall.visible = false)
	wall.entry_chosen.connect(_open_from_wall)
	add_child(wall)


func _place(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size


func _drop_zone(p: Vector2) -> String:
	if Desk.r("bin").grow(6).has_point(p):
		return "bin"
	if Desk.r("punch_bed").grow(4).has_point(p) or Desk.r("order_drum").has_point(p) or Desk.r("cond_drum").has_point(p):
		return "keypunch"
	return ""


# ---------------------------------------------------------------- shifts, plates, memos

func _certified(i: int) -> bool:
	return state.room_state(SECTORS[i]).certified


## The shift the operator is on: one per sector, the next once the last is certified.
func _shift() -> int:
	var s := 0
	for i in SECTORS.size():
		if _certified(i):
			s = i + 1
	return mini(s, SECTORS.size() - 1)


func _plates() -> Array:
	var p: Array = []
	for i in _shift() + 1:
		p.append_array(story["shifts"][i]["plates"])
	return p


func _refresh_plates(fresh: bool) -> void:
	var s := _shift()
	keypunch.set_plates(_plates(), story["shifts"][s]["plates"] if fresh and s > 0 else [])
	nixies.value = s + 1


func _memo_ids() -> Array:
	var ids: Array = []
	for i in SECTORS.size():
		if i == 0 or _certified(i - 1):
			ids.append("open%d" % i)
		if _certified(i):
			ids.append("tally%d" % i)
			ids.append("letter%d" % i)
	if _certified(SECTORS.size() - 1):
		ids.append("end")
	return ids


func _read() -> Array:
	return state.extra.get("memos_read", [])


func _unread() -> Array:
	var read := _read()
	return _memo_ids().filter(func(id: String) -> bool: return not read.has(id))


func _debt() -> int:
	var lost := 0
	var certs := 0
	for i in SECTORS.size():
		for e in state.own_dives(SECTORS[i]):
			if e["result"] != "exit":
				lost += 1
		if _certified(i):
			certs += 1
	return int(story["debt_start"]) + lost * int(story["hull_cost"]) - certs * int(story["certify_credit"])


func _memo_from(m: Dictionary, kind: String) -> Dictionary:
	var out := m.duplicate()
	out["kind"] = kind
	out["body"] = str(m.get("body", "")).format({"debt": _fmt(_debt())})
	return out


static func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _memo_for(id: String) -> Dictionary:
	if id == "end":
		return _memo_from(story["end"], "memo")
	var i := int(id.substr(id.length() - 1))
	var sh: Dictionary = story["shifts"][i]
	if id.begins_with("open"):
		return _memo_from(sh["open"], "memo")
	if id.begins_with("letter"):
		return {"kind": "letter", "body": sh["letter"]}
	# The tally.
	var rid: String = SECTORS[i]
	var rs := state.room_state(rid)
	var sent := 0
	var lost := 0
	for e in state.own_dives(rid):
		sent += 1
		if e["result"] != "exit":
			lost += 1
	var body := str(story["tally"]).format({
		"sector": story["sectors"][rid]["short"], "passed": rs.survey.get("passed", 0), "sent": sent, "lost": lost,
		"hull_cost": _fmt(int(story["hull_cost"])), "credit": _fmt(int(story["certify_credit"])), "cpu": rs.best_cpu,
		"debt": _fmt(_debt()), "notice": sh["notice"]})
	return {"kind": "tally", "ref": "DA-9/T%02d  ·  END OF SHIFT %d" % [i + 1, i + 1], "subject": "SHIFT TALLY", "body": body, "stamp": "CERTIFIED"}


func _open_next_memo() -> void:
	var u := _unread()
	if u.is_empty():
		return
	var id: String = u[0]
	var read := _read()
	read.append(id)
	state.extra["memos_read"] = read
	state.save()
	tube.pending = u.size() - 1
	_unread_seen = tube.pending
	_show_memo(_memo_for(id))
	if id.begins_with("open") and id != "open0":
		_refresh_plates(true)


func _show_memo(m: Dictionary) -> void:
	if magnified:
		_toggle_magnify()
	memo.show_memo(m)


func _on_memo_closed() -> void:
	pass


## The contract torn up: a new operator, Shift 1, nothing on the Wall.
func _start_over() -> void:
	if survey_run != null:
		survey_run = null
		trials.running = false
		dispatch.busy = false
	state.reset()
	for id: String in _notes.keys():
		(_notes[id] as OpNote).queue_free()
	_notes.clear()
	_transient.clear()
	dispatch.armed = false
	_select_sector(SECTORS[0])
	_refresh_plates(false)
	_unread_seen = 0
	tube.pending = 0
	_check_tube()


## New memos arrive by tube with a thump.
func _check_tube() -> void:
	var n := _unread().size()
	if n > _unread_seen:
		tube.deliver()
		tube.pending = n
	_unread_seen = n


func _open_binder() -> void:
	var orders := ""
	var conds := ""
	var plates := _plates()
	for a: String in Catalogue.ACTIONS:
		var have := false
		for o: Array in Keypunch.ORDERS:
			if o[0] == a and plates.has(o[2]):
				have = true
		if have:
			orders += "[b]%s[/b]  ·  %d CPU\n%s\n\n" % [str(Catalogue.ACTIONS[a]["label"]).to_upper(), Catalogue.action_cpu(a, ""), Catalogue.HELP.get(a, "")]
	conds += "[b]ALWAYS[/b]  ·  0 CPU\n%s\n\n" % Catalogue.HELP["always"]
	for c: String in Catalogue.CONDITIONS:
		if plates.has(c):
			conds += "[b]IF %s[/b]  ·  %d CPU (+1 for IF)\n%s\n\n" % [str(Catalogue.CONDITIONS[c]["label"]).to_upper(), Catalogue.condition_cpu(c), Catalogue.HELP.get(c, "")]
	if plates.has("not"):
		conds += "[b]NOT[/b]  ·  1 CPU\n%s\n\n" % Catalogue.HELP["not"]
	var op5 := ""
	for i in SECTORS.size():
		if _read().has("letter%d" % i):
			op5 += "[i]%s[/i]\n\n— 5\n\n\n" % story["shifts"][i]["letter"]
	if op5 == "":
		op5 = "[i]nothing here yet.[/i]"
	if magnified:
		_toggle_magnify()
	var contract := "[b]CONTRACT OF SERVICE  ·  OPERATOR 6[/b]\n\nThe operator agrees to serve the Company at Station 9 until the balance of passage, berth, oxygen and equipment is repaid in full, or until reassignment.\n\nBalance owing: [b]%s scrip[/b].\n\n[i]For playtesting: tearing this up starts again from Shift 1 with an empty Wall. Everything you sent is forgotten.[/i]" % _fmt(_debt())
	memo.show_binder([["ORDERS", orders], ["CONDITIONS", conds], ["REGULATIONS", story["regulations"]], ["OP. 5", op5], ["CONTRACT", contract]])


# ---------------------------------------------------------------- sectors and the deck

func _select_sector(id: String) -> void:
	room_id = id
	var rs := state.room_state(id)
	program = Program.parse(rs.program_text)
	rack.setup(program)
	keypunch.new_card_mode()
	current_dive = null
	current_entry = {}
	var names: Array[String] = []
	var open: Array[bool] = []
	var certs: Array[bool] = []
	for i in 6:
		if i < SECTORS.size():
			names.append(story["sectors"][SECTORS[i]]["short"])
			open.append(state.room_unlocked(SECTORS[i]))
			certs.append(_certified(i))
		else:
			names.append("SEALED")
			open.append(false)
			certs.append(false)
	dial.names = names
	dial.open = open
	dial.certified = certs
	dial.index = SECTORS.find(id)
	trials.results = []
	if not rs.survey.is_empty():
		for d: Dictionary in rs.survey.get("dives", []):
			trials.results.append(d["result"])
	var own := state.own_dives(id)
	if not own.is_empty():
		_play_entry(own.back())
	else:
		_show_chart()
	_refresh()
	scope.warm_up()


func _sector_label() -> String:
	return story["sectors"][room_id]["label"]


func _losses(before_serial: int) -> Array:
	var out: Array = []
	for e in state.own_dives(room_id):
		if int(e["serial"]) >= before_serial:
			break
		if e["result"] != "exit":
			var path := GameState.decode_path(str(e.get("path", "")))
			if path.size() > 0:
				out.append({"pos": path[path.size() - 1], "serial": int(e["serial"])})
	return out


func _show_chart() -> void:
	scope.show_chart(state.room_state(room_id).room, state.room_state(room_id).memory, _losses(1 << 30), _sector_label())
	teleprinter.set_lines([])
	teleprinter.header = "SECTOR %d READY  ·  NO HULL OUT" % (SECTORS.find(room_id) + 1)
	recorder.marks = []
	porthole.serial = 0


func _on_program_changed() -> void:
	state.room_state(room_id).program_text = program.to_text()
	state.save()
	_refresh()


func _refresh() -> void:
	var rs := state.room_state(room_id)
	var used := program.cpu()
	gauge.set_load(used, rs.room.cpu_budget)
	keypunch.rack_size = program.rules.size()
	keypunch.rack_full = program.rules.size() >= CardRack.SLOTS
	keypunch._refresh_wheel()
	dispatch.serial = state.next_serial
	dispatch.refuse_reason = "EMPTY RACK" if program.rules.is_empty() else ("TOO HEAVY" if used > rs.room.cpu_budget else "")
	trials.enabled = state.program_made_it(room_id, program.to_text())
	trials.certified = rs.certified
	trials.needed = Survey.needed_for(Survey.FLEET)
	dial.certified[SECTORS.find(room_id)] = rs.certified
	_check_tube()


func _on_punched(r: Dictionary, replace: int) -> void:
	if replace >= 0 and replace < program.rules.size():
		program.rules[replace] = r
		rack.refresh()
		rack.flash(replace)
	else:
		program.rules.append(r)
		rack.refresh(program.rules.size() - 1)
	_mark("punched")
	_on_program_changed()


func _on_card_tapped(i: int) -> void:
	keypunch.load_rule(program.rules[i], i)
	rack.flash(i)


func _on_card_dropped(i: int, where: String) -> void:
	if where == "bin":
		program.rules.remove_at(i)
		Sfx.play("tear", -6.0, 1.3)
		rack.setup(program)
		if keypunch.replace == i:
			keypunch.new_card_mode()
		_mark("punched")
		_on_program_changed()
	else:
		keypunch.load_rule(program.rules[i], i)
		rack.setup(program)


func _load_his_deck() -> void:
	if current_entry.is_empty() or str(current_entry.get("text", "")) == program.to_text():
		return
	program = Program.parse(str(current_entry["text"]))
	rack.setup(program)
	Sfx.play("paper", -4.0)
	_on_program_changed()


func _on_plate_missing(what: String) -> void:
	match what:
		"not":
			_flash_note("not_locked", "NOT switch is locked till they issue the plate. Next shift.", Vector2(980, 560), Desk.r("not_switch").get_center())
		"rack_full":
			_flash_note("rack_full", story["notes"]["rack_full"], Vector2(890, 380), Desk.r("bin").get_center())


func _on_refused(why: String) -> void:
	match why:
		"cover":
			_flash_note("cover", story["notes"]["cover"], Vector2(1046, 486), Vector2(1212, 392))
		"TOO HEAVY":
			_flash_note("over", story["notes"]["over"], Vector2(1046, 486), Desk.r("gauge").get_center())
		"EMPTY RACK":
			_flash_note("empty", "Empty rack. He needs at least one card.", Vector2(1046, 486), Desk.r("rack").get_center())


# ---------------------------------------------------------------- dispatching and watching

func _dispatch() -> void:
	if program.rules.is_empty() or program.cpu() > state.room_state(room_id).room.cpu_budget:
		return
	Sfx.play("ui_launch", -6.0)
	_scrubbed = false
	var res := state.launch(room_id, program)
	_show(res["dive"], res["entry"], res["history"])
	var g: Dictionary = scope.sonar().ghost
	if g.get("lost", false):
		var path: PackedVector2Array = g["path"]
		scope.replay.skip_until = maxi(0, (path.size() - 1) * GameState.PATH_STEP - 3 * TICKS)
	scope.warm_up()
	_mark("dispatched")
	_refresh()


func _show(dive: Dive, entry: Dictionary, history: Dictionary) -> void:
	current_dive = dive
	current_entry = entry
	var serial := int(entry.get("serial", -1))
	var memory := state.memory_before(room_id, entry)
	var ghost := state.ghost_for(room_id, entry)
	scope.play(dive, entry, history, memory, ghost, _losses(serial if serial > 0 else 1 << 30), _sector_label())
	var lines := Tape.lines(dive, scope.sonar(), serial, _sector_label(), scope.replay.captions, str(entry.get("last_words", "")))
	teleprinter.set_lines(lines)
	recorder.marks = lines
	porthole.serial = maxi(serial, 0)


func _play_entry(entry: Dictionary) -> void:
	var dive := state.redive(room_id, entry)
	var history := {}
	var own := state.own_dives(room_id)
	var at := own.find(entry)
	if at > 0:
		history = {"prev_serial": own[at - 1]["serial"], "prev_cause": own[at - 1]["cause"]}
	_show(dive, entry, history)
	scope.replay.seek(float(dive.rec.ticks - 1))
	scope.replay.playing = false


func _on_tape_line(t: int, r: int) -> void:
	if not scope.has_dive():
		return
	scope.replay.seek(float(t))
	scope.replay.playing = false
	_scrubbed = true
	if r >= 0:
		rack.flash(r)
	Sfx.play("switch", -12.0, 1.4)


func _on_torn() -> void:
	if current_entry.is_empty():
		return
	current_entry["torn"] = true
	state.save()


# ---------------------------------------------------------------- sea trials

func _start_trials() -> void:
	if survey_run != null:
		return
	survey_run = Survey.Run.new(state.room_state(room_id).room, Program.parse(program.to_text()))
	trials.results = []
	trials.running = true
	dispatch.busy = true
	_mark("cranked")


func _step_trials() -> void:
	var t0 := Time.get_ticks_msec()
	var before := survey_run.dives.size()
	while not survey_run.done() and Time.get_ticks_msec() - t0 < 12:
		survey_run.step()
	for i in range(before, survey_run.dives.size()):
		trials.results.append(survey_run.dives[i]["result"])
		Sfx.play("relay", -10.0, 1.2 if survey_run.dives[i]["result"] == "exit" else 0.7)
	if not survey_run.done():
		return
	var run := survey_run
	survey_run = null
	trials.running = false
	dispatch.busy = false
	var was := state.room_state(run.room.id).certified
	var report := state.finish_survey(run.room.id, run.program, run.report())
	if run.room.id != room_id:
		return
	if report["certified"] and not was:
		stamp.slam("CERTIFIED", _scope_rect)
		Sfx.play("stamp", 0.0)
		_select_sector(room_id)
		_refresh_plates(false)
	elif report["certified"]:
		Sfx.play("exit", -6.0)
	else:
		Sfx.play("burst", -8.0)
	_refresh()


func _on_trial_lamp(i: int) -> void:
	var rs := state.room_state(room_id)
	var dives: Array = rs.survey.get("dives", [])
	if i >= dives.size():
		return
	var seed_v := int(dives[i]["seed"])
	var e := {"serial": -1, "seed": seed_v, "text": program.to_text(), "result": dives[i]["result"], "cause": dives[i]["cause"],
		"last_words": "", "survey": true}
	for d in rs.dives:
		if d.get("survey", false) and int(d["seed"]) == seed_v:
			e = d
	_show(state.redive(room_id, e), e, {})
	scope.replay.seek(0.0)
	scope.replay.playing = true
	_mark("trial_lamp")


# ---------------------------------------------------------------- the Wall, magnify, sound

func _open_wall() -> void:
	if magnified:
		_toggle_magnify()
	scope.replay.playing = false
	var short := {}
	for id: String in SECTORS:
		short[id] = story["sectors"][id]["short"]
	wall.refresh(state, SECTORS, short)
	wall.move_to_front()
	wall.visible = true


func _open_from_wall(id: String, entry: Dictionary) -> void:
	wall.visible = false
	if not SECTORS.has(id):
		return
	if id != room_id:
		_select_sector(id)
	_show(state.redive(room_id, entry), entry, {})
	scope.replay.seek(0.0)
	scope.replay.playing = true


func _paint_wall_count(h: Hotspot) -> void:
	var n := state.next_serial - 1
	Desk.centred(h, Rect2(Vector2(0, h.size.y - 20), Vector2(h.size.x, 16)), "THE WALL  ·  %d" % n, Desk.font("plate"), 12, Color(0.9, 0.8, 0.6, 0.85))


func _paint_gain(h: Hotspot) -> void:
	if Sfx.muted:
		h.draw_line(Vector2(4, 4), Vector2(h.size.x - 4, h.size.y - 4), Color(Desk.RED_LAMP, 0.8), 2.0)


func _paint_deck_tab(h: Hotspot) -> void:
	if current_entry.is_empty() or str(current_entry.get("text", "")) == program.to_text():
		return
	h.draw_rect(Rect2(Vector2.ZERO, h.size), Color(0.55, 0.42, 0.2, 0.9))
	Desk.centred(h, Rect2(Vector2.ZERO, h.size), "DECK CHANGED  ·  LOAD HIS DECK", Desk.font("plate"), 11, Color(0.08, 0.05, 0.02))


func _toggle_mute() -> void:
	Sfx.set_muted(not Sfx.muted)


func _toggle_magnify() -> void:
	magnified = not magnified
	var target := Rect2(0, 0, 1280, 720) if magnified else _scope_rect
	if magnified:
		scope.move_to_front()
		stamp.move_to_front()
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(scope, "position", target.position, 0.25)
	tw.tween_property(scope, "size", target.size, 0.25)
	if not magnified:
		tw.chain().tween_callback(func() -> void: move_child(scope, plate.get_index() + 1))
	Sfx.play("cover", -10.0, 0.8)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Sfx.start_ambience()


func _unhandled_input(event: InputEvent) -> void:
	if memo.visible or wall.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var rp := scope.replay
		match event.keycode:
			KEY_SPACE:
				rp.playing = not rp.playing
			KEY_F:
				_toggle_magnify()
			KEY_M:
				_toggle_mute()
			KEY_W:
				_open_wall()
			KEY_H:
				_open_binder()
			KEY_LEFT:
				rp.skip_until = -1
				rp.step_speed(-1)
			KEY_RIGHT:
				rp.skip_until = -1
				rp.step_speed(1)
			KEY_COMMA:
				if rp.has_dive():
					rp.seek(rp.view.t - TICKS)
			KEY_PERIOD:
				if rp.has_dive():
					rp.seek(rp.view.t + TICKS)
			KEY_U:
				if event.ctrl_pressed and event.shift_pressed:
					state.unlock_all = true
					_select_sector(room_id)
			_:
				return
		accept_event()


# ---------------------------------------------------------------- per frame

func _process(_delta: float) -> void:
	if survey_run != null:
		_step_trials()
	_update_lamps()
	_update_mood()
	keypunch.bin_hot = rack.highlight_drop == "bin"
	keypunch.bed_hot = rack.highlight_drop == "keypunch"
	_update_notes()


## Pilot lamps: at the moment the recorder is on, what the reader did with each card.
func _update_lamps() -> void:
	var lamps: Array = []
	for i in program.rules.size():
		lamps.append({"state": "off", "reason": ""})
	if current_dive != null and scope.has_dive() and str(current_entry.get("text", "")) == program.to_text():
		var entry := _trace_at(scope.replay.tick())
		if not entry.is_empty():
			for c: Array in entry["checks"]:
				var i: int = c[0]
				if i >= lamps.size():
					continue
				match str(c[1]):
					"chosen":
						lamps[i] = {"state": "run", "reason": ""}
					"instant":
						lamps[i] = {"state": "set", "reason": ""}
					_:
						lamps[i] = {"state": "skip", "reason": CardArt.reason(program.rules[i], str(c[1]))}
	rack.lamps = lamps


func _trace_at(k: int) -> Dictionary:
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
	return trace[found] if found >= 0 else {}


func _update_mood() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if current_dive == null or not scope.has_dive():
		porthole.mood = "idle"
		porthole.look = Vector2(sin(now * 0.4), cos(now * 0.27) * 0.4)
		return
	var d := current_dive
	var rec := d.rec
	var k := scope.replay.tick()
	var last := rec.ticks - 1
	var ang := rec.ra[k] * TAU / 4096.0
	porthole.look = Vector2(sin(ang), -cos(ang) * 0.5)
	if d.world.result != World.Result.EXIT and k >= last:
		porthole.mood = "lost"
		return
	if d.world.result == World.Result.EXIT and k >= last - 40:
		porthole.mood = "happy"
		return
	for e in d.world.events:
		if e["type"] == "damage" and k >= int(e["t"]) and k - int(e["t"]) < 30:
			porthole.mood = "hurt"
			return
	var entry := _trace_at(k)
	var s: PackedInt32Array = entry.get("senses", PackedInt32Array())
	if s.size() >= 2 and s[1] >= 0:
		if s[1] <= 3 * Fx.TILE:
			porthole.mood = "scared"
			return
		if s[1] <= 6 * Fx.TILE:
			porthole.mood = "worried"
			return
	if (rec.rflags[k] & 1) == 0:
		porthole.mood = "dark"
	elif (rec.rflags[k] & 2) != 0:
		porthole.mood = "curious"
	else:
		porthole.mood = "idle"


# ---------------------------------------------------------------- Op. 5's notes (the tutorial)

func _done(id: String) -> bool:
	return state.extra.get("notes_done", []).has(id)


func _finish(id: String) -> void:
	var d: Array = state.extra.get("notes_done", [])
	if not d.has(id):
		d.append(id)
		state.extra["notes_done"] = d
		state.save()


## Things the operator did, for the notes to notice.
func _mark(what: String) -> void:
	var m: Array = state.extra.get("marks", [])
	if not m.has(what):
		m.append(what)
		state.extra["marks"] = m
		state.save()


func _did(what: String) -> bool:
	return state.extra.get("marks", []).has(what)


## Which notes should be on the console now: [id, position, width, arrow target].
func _wanted_notes() -> Array:
	var out: Array = []
	var N: Dictionary = story["notes"]
	var dark := state.room_state("dark")
	var any_dive := state.next_serial > 1
	var own := state.own_dives(room_id)
	var last_lost: bool = not own.is_empty() and own.back()["result"] != "exit"
	var made_it := state.program_made_it(room_id, program.to_text())
	var rs := state.room_state(room_id)
	# Notes on the rack go in the empty space under the cards.
	var rack_y := clampf(172.0 + 51.0 * program.rules.size(), 214.0, 340.0)
	if not _read().has("open0"):
		out.append(["welcome", Vector2(330, 120), 210.0, Desk.r("tube_window").get_center()])
		return out
	if not any_dive:
		out.append(["dispatch", Vector2(780, rack_y), 220.0, Vector2(1212, 392)])
		return out
	if room_id == "dark" and not dark.certified:
		if last_lost and not _scrubbed and not _did("rewound"):
			out.append(["rewind", Vector2(56, 214), 200.0, Desk.r("reel_a").get_center()])
			out.append(["tape", Vector2(300, 224), 190.0, Desk.r("paper").get_center() + Vector2(-40, 40)])
		elif last_lost and not _did("punched"):
			out.append(["deck", Vector2(760, rack_y), 240.0, Desk.r("order_drum").get_center()])
			out.append(["punch", Vector2(330, 200), 220.0, Desk.r("punch_lever").get_center()])
		elif made_it and rs.survey.is_empty():
			out.append(["trials", Vector2(820, rack_y), 190.0, Vector2(Desk.v("crank")[0], Desk.v("crank")[1])])
	if not rs.certified and not rs.survey.is_empty() and not rs.survey.get("certified", false) and not _did("trial_lamp"):
		out.append(["trial_fail", Vector2(820, rack_y), 190.0, Desk.r("trials").get_center()])
	if room_id == "dark" and dark.certified and _unread().size() > 0:
		out.append(["certified", Vector2(330, 120), 210.0, Desk.r("tube_window").get_center()])
	var next := SECTORS.find(room_id) + 1
	if rs.certified and next < SECTORS.size() and state.own_dives(SECTORS[next]).is_empty() and _unread().is_empty():
		out.append(["next_sector", Vector2(780, rack_y), 190.0, Desk.r("sector_knob").get_center()])
	if any_dive and program.rules.size() >= 2 and current_dive != null and scope.replay.playing and not _did("lamps_seen"):
		out.append(["lamps", Vector2(760, rack_y), 210.0, Vector2(675, 181)])
	if room_id == "jellyfish" and not rs.certified and _read().has("open1"):
		out.append(["jelly", Vector2(712, rack_y), 180.0, Desk.r("order_drum").get_center()])
		if not _did("not"):
			out.append(["not", Vector2(902, rack_y + 10), 120.0, Desk.r("not_switch").get_center()])
	if room_id == "nursery" and not rs.certified and _read().has("open2"):
		out.append(["nursery", Vector2(760, rack_y), 220.0, Desk.r("order_drum").get_center()])
	return out


func _update_notes() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if keypunch.negate:
		_mark("not")
	if _scrubbed:
		_mark("rewound")
	if current_dive != null and scope.has_dive() and scope.replay.tick() >= current_dive.rec.ticks - 1 and _notes.has("lamps"):
		_mark("lamps_seen")
	var want := {}
	if not memo.visible and not wall.visible and not magnified:
		for w: Array in _wanted_notes():
			want[w[0]] = w
	for id: String in _notes.keys():
		if _transient.has(id):
			if now > float(_transient[id]):
				(_notes[id] as OpNote).peel()
				_notes.erase(id)
				_transient.erase(id)
			continue
		if not want.has(id):
			var n: OpNote = _notes[id]
			if is_instance_valid(n):
				n.peel()
			_notes.erase(id)
	for id: String in want:
		var w: Array = want[id]
		if not _notes.has(id):
			var n := OpNote.make(story["notes"][id], w[1], w[2], w[3])
			notes_layer.add_child(n)
			_notes[id] = n
		(_notes[id] as OpNote).home = w[1]


## A note for a moment: Op. 5 grumbling at something you just tried.
func _flash_note(id: String, text: String, at: Vector2, arrow: Vector2) -> void:
	if _notes.has(id):
		_transient[id] = Time.get_ticks_msec() / 1000.0 + 5.0
		return
	var n := OpNote.make(text, at, 200.0, arrow)
	notes_layer.add_child(n)
	_notes[id] = n
	_transient[id] = Time.get_ticks_msec() / 1000.0 + 5.0


# ---------------------------------------------------------------- small pieces

## A tappable place on the desk (the binder, the Wall, the magnify switch).
class Hotspot:
	extends Control
	signal tapped
	var label := ""
	var label_size := 14
	var stencil := false
	var painter: Callable

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Sfx.play("switch", -10.0)
			tapped.emit()
			accept_event()

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if label != "":
			Desk.engraved(self, Rect2(Vector2.ZERO, size), label, label_size, Color(0.15, 0.1, 0.05) if not stencil else Color(Desk.STENCIL, 0.8))
		if painter.is_valid():
			painter.call(self)


## The light on the desk: what the instruments throw on the steel around them, and the dark
## at the edges. Drawn over the machines, never catching a touch.
class Lights:
	extends Control
	var console

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var now := Time.get_ticks_msec() / 1000.0
		var sc: Rect2 = Desk.r("screen")
		# Green spill from the scope onto its bezel.
		var flick := 0.9 + 0.1 * sin(now * 13.0)
		for i in 6:
			var g := sc.grow(4.0 + i * 5.0)
			draw_rect(g, Color(0.25, 1.0, 0.55, 0.018 * flick), false, 5.0)
		# Vignette: the desk falls into dark at its edges.
		for i in 18:
			var a := 0.035
			draw_rect(Rect2(Vector2(i * 3, i * 3), Vector2(1280 - i * 6, 720 - i * 6)), Color(0, 0, 0, a), false, 3.0)
		draw_rect(Rect2(0, 0, 1280, 6), Color(0, 0, 0, 0.35))
		# Plaques that belong to no machine.
		Desk.engraved(self, Desk.plaque_rect("scope"), Desk.plaque("scope")[4], 12)
		# The scope's LIVE lamp: lit while a dive plays.
		var playing: bool = console.scope.has_dive() and console.scope.replay.playing
		var lp := Vector2(44, 390)
		if playing:
			Desk.draw_glow(self, lp, 12.0, Color(Desk.RED_LAMP, 0.7))
		draw_circle(lp, 3.5, Desk.RED_LAMP if playing else Color(0.2, 0.05, 0.03))
		draw_string(Desk.font("plate"), lp + Vector2(9, 5), "LIVE" if playing else "HELD", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Desk.STENCIL, 0.7))
		draw_string(Desk.font("plate"), Vector2(523, 395), "GAIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Desk.STENCIL, 0.7))
		Desk.engraved(self, Desk.plaque_rect("rack"), Desk.plaque("rack")[4], 13)


## The Company's rubber stamp, slammed across the scope when a sector is certified.
class Stamp:
	extends Control
	var text := ""
	var at := Rect2()
	var t0 := -10.0

	func slam(t: String, r: Rect2) -> void:
		text = t
		at = r
		t0 = Time.get_ticks_msec() / 1000.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var age := Time.get_ticks_msec() / 1000.0 - t0
		if age > 4.5 or text == "":
			return
		var sc := 1.0 + maxf(0.0, 0.18 - age) * 6.0
		var alpha := clampf(age * 8.0, 0.0, 1.0) * clampf((4.5 - age) * 1.5, 0.0, 1.0)
		var f := Desk.font("plate")
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x + 50.0
		draw_set_transform(at.get_center(), -0.16, Vector2(sc, sc))
		var col := Color(0.85, 0.15, 0.1, 0.85 * alpha)
		draw_rect(Rect2(-w * 0.5, -52, w, 104), col, false, 6.0)
		draw_rect(Rect2(-w * 0.5 + 9, -43, w - 18, 86), col, false, 2.0)
		Desk.centred(self, Rect2(-w * 0.5, -50, w, 100), text, f, 72, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
