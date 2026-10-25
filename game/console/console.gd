extends Control
## The operator's console: the whole game on one dark desk (docs/design/station-ui.md).
## The sonar receiver, the wire recorder and the teleprinter on the left; the card reader
## with its slots, the pulp chute, the Company's counter, the sea trials, the dispatch
## lever and the card press on the right; the Company tube, the sector selector, the shift counter, Bathy's porthole and
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
var table: CardTable
var press: CardPress
var counter: DebtCounter
var ambience: Ambience
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
	recorder._apply_speed()
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

	counter = DebtCounter.new()
	_place(counter, Desk.r("counter"))
	add_child(counter)
	trials = SeaTrials.new()
	_place(trials, Desk.r("trials"))
	trials.cranked.connect(_start_trials)
	trials.lamp_tapped.connect(_on_trial_lamp)
	trials.locked_tapped.connect(func() -> void: _flash_note("trials_locked", "No beacon on record for this deck. Get one hull to the beacon first.", Vector3(1128, 309, 64)))
	add_child(trials)
	dispatch = DispatchLever.new()
	_place(dispatch, Desk.r("dispatch"))
	dispatch.dispatched.connect(_dispatch)
	dispatch.refused.connect(_on_refused)
	add_child(dispatch)
	press = CardPress.new()
	_place(press, Desk.r("press"))
	add_child(press)
	press.setup()
	press.printed.connect(_on_printed)
	press.refused.connect(_on_plate_missing)

	# The cards lie over the reader and the press; the lid and the chute are part of them.
	table = CardTable.new()
	table.changed.connect(_on_deck_changed)
	table.refused.connect(_on_plate_missing)
	table.pulped.connect(func() -> void:
		_mark("pulped")
		_save_deck())
	add_child(table)
	deck_tab = Hotspot.new()
	_place(deck_tab, Rect2(790, 456, 176, 16))
	deck_tab.tapped.connect(_load_his_deck)
	deck_tab.painter = _paint_deck_tab
	add_child(deck_tab)

	ambience = Ambience.new()
	ambience.press = press
	add_child(ambience)

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
	press.set_plates(_plates(), story["shifts"][s]["plates"] if fresh and s > 0 else [])
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


func _lost_total() -> int:
	var lost := 0
	for id: String in SECTORS:
		for e in state.own_dives(id):
			if e["result"] != "exit":
				lost += 1
	return lost


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
		"hull_cost": _fmt(int(story["hull_cost"])), "credit": _fmt(int(story["certify_credit"])), "cards": _deck_size(rid),
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
		for o: Array in PressOrders.ORDERS:
			if o[0] == a and plates.has(o[2]):
				have = true
		if have:
			orders += "[b]%s[/b]\n%s\n\n" % [str(Catalogue.ACTIONS[a]["label"]).to_upper(), _no_cpu(Catalogue.HELP.get(a, ""))]
	conds += "[b]ALWAYS[/b]\n%s\n\n" % Catalogue.HELP["always"]
	for c: String in Catalogue.CONDITIONS:
		if plates.has(c):
			conds += "[b]IF %s[/b]\n%s\n\n" % [str(Catalogue.CONDITIONS[c]["label"]).to_upper(), _no_cpu(Catalogue.HELP.get(c, ""))]
	if plates.has("not"):
		conds += "[b]NOT[/b]\nRun the card when its condition is NOT true.\n\n"
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
	_load_deck(id)
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


## The deck lives in the reader's slots and the tray. Saved per sector as card texts
## ("" for an empty slot); the slots in order are the program.
func _load_deck(id: String) -> void:
	var rs := state.room_state(id)
	var decks: Dictionary = state.extra.get("decks", {})
	var slot_rules: Array = []
	var tray_rules: Array = []
	if decks.has(id):
		for t: String in decks[id].get("slots", []):
			slot_rules.append(_rule_of(t))
		for t: String in decks[id].get("tray", []):
			var r := _rule_of(t)
			if not r.is_empty():
				tray_rules.append(r)
	else:
		for r: Dictionary in Program.parse(rs.program_text).rules:
			slot_rules.append(r)
	table.setup(rs.room.slots, slot_rules, tray_rules)
	press.slots = rs.room.slots
	program = _program_from_table()


static func _rule_of(text: String) -> Dictionary:
	if text.strip_edges() == "":
		return {}
	var p := Program.parse(text)
	return p.rules[0] if p.rules.size() == 1 else {}


func _program_from_table() -> Program:
	var p := Program.new()
	for r: Dictionary in table.deck():
		p.rules.append(r)
	return p


func _deck_size(id: String) -> int:
	var decks: Dictionary = state.extra.get("decks", {})
	if id == room_id:
		return program.rules.size()
	var n := 0
	for t: String in decks.get(id, {}).get("slots", []):
		if t != "":
			n += 1
	return n


func _save_deck() -> void:
	var tmp := Program.new()
	var decks: Dictionary = state.extra.get("decks", {})
	decks[room_id] = {
		"slots": table.slot_rules().map(func(r: Dictionary) -> String: return "" if r.is_empty() else tmp.rule_text(r)),
		"tray": table.tray_rules().map(func(r: Dictionary) -> String: return tmp.rule_text(r)),
	}
	state.extra["decks"] = decks
	state.room_state(room_id).program_text = program.to_text()
	state.save()


func _on_deck_changed() -> void:
	program = _program_from_table()
	_mark("inserted")
	_save_deck()
	_refresh()


static func _no_cpu(text: String) -> String:
	var re := RegEx.create_from_string(" ?\\(\\d CPU\\)")
	return re.sub(text, "", true)


func _refresh() -> void:
	var rs := state.room_state(room_id)
	press.tray_full = table.tray_full()
	dispatch.serial = state.next_serial
	if program.rules.is_empty():
		dispatch.refuse_reason = "NO CARDS"
	else:
		dispatch.refuse_reason = ""
	trials.enabled = state.program_made_it(room_id, program.to_text())
	trials.certified = rs.certified
	trials.needed = Survey.needed_for(Survey.FLEET)
	dial.certified[SECTORS.find(room_id)] = rs.certified
	_check_tube()


func _on_printed(r: Dictionary) -> void:
	table.add_printed(r)
	_mark("printed")
	_save_deck()
	_refresh()


## The deck of the Robbie being watched, put back in the slots (the cards in the slots now go
## to the tray, as far as it has room; the rest are pulped).
func _load_his_deck() -> void:
	if current_entry.is_empty() or str(current_entry.get("text", "")) == program.to_text():
		return
	var his := Program.parse(str(current_entry["text"]))
	var tray: Array = table.tray_rules()
	for r: Dictionary in table.deck():
		if tray.size() < CardTable.TRAY_MAX:
			tray.append(r)
	table.setup(state.room_state(room_id).room.slots, his.rules, tray)
	Sfx.play("paper", -4.0)
	_on_deck_changed()


func _on_plate_missing(what: String) -> void:
	var N: Dictionary = story["notes"]
	match what:
		"not":
			_flash_note("not_locked", "NOT switch is locked till they issue the plate. Next shift.", _ring("not_switch", 26))
		"tray_full":
			_flash_note("tray_full", N["tray_full"], _ring("chute_mouth", 50))


func _on_refused(why: String) -> void:
	var N: Dictionary = story["notes"]
	match why:
		"cover":
			_flash_note("cover", N["cover"], _ring("cover", 40))
		"NO CARDS":
			_flash_note("empty", N["empty"], null)


# ---------------------------------------------------------------- dispatching and watching

func _dispatch() -> void:
	if program.rules.is_empty():
		return
	Sfx.play("ui_launch", -6.0)
	_scrubbed = false
	var res := state.launch(room_id, program)
	_show(res["dive"], res["entry"], res["history"])
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
	var where := table.deck_slots()
	if r >= 0 and r < where.size():
		table.flash(where[r])
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
	Desk.centred(h, Rect2(Vector2(0, h.size.y - 20), Vector2(h.size.x, 16)), "THE WALL", Desk.font("plate"), 12, Color(0.9, 0.8, 0.6, 0.85))


func _paint_gain(h: Hotspot) -> void:
	if Sfx.muted:
		h.draw_line(Vector2(4, 4), Vector2(h.size.x - 4, h.size.y - 4), Color(Desk.RED_LAMP, 0.8), 2.0)


## A brass pull with its name stamped on it, always there; its lamp is lit when the deck in the
## slots isn't the one the Robbie on the scope swam with, so pulling it would put his back.
func _paint_deck_tab(h: Hotspot) -> void:
	var differs := not current_entry.is_empty() and str(current_entry.get("text", "")) != program.to_text()
	h.draw_rect(Rect2(Vector2(14, 1), h.size - Vector2(14, 2)), Color(0.42, 0.32, 0.15))
	h.draw_rect(Rect2(Vector2(14, 1), h.size - Vector2(14, 2)), Color(0.12, 0.08, 0.03), false, 1.0)
	Desk.centred(h, Rect2(Vector2(14, 0), h.size - Vector2(14, 0)), "PUT BACK HIS DECK", Desk.font("plate"), 11, Color(0.1, 0.07, 0.03))
	Desk.draw_lamp(h, Vector2(6, h.size.y * 0.5), "", Desk.AMBER, 1.0 if differs else 0.0, 3.5)


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
				recorder.step_speed(-1)
			KEY_RIGHT:
				recorder.step_speed(1)
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
	press.tray_full = table.tray_full()
	counter.set_values(_debt(), _lost_total())
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
	# Lamps belong to slots; the program skips empty ones.
	var by_slot: Array = []
	for i in table.slot_count:
		by_slot.append({"state": "off", "reason": ""})
	var where := table.deck_slots()
	for i in mini(lamps.size(), where.size()):
		by_slot[where[i]] = lamps[i]
	table.lamps = by_slot


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


## Which notes should be on the console now: [id, position, width, targets]. A target is a
## console position, or a Vector3 with the size of the loop round it in z.
## Most go on the reader's glass, one under another below the cards in use; the rest on the
## scope's glass.
func _wanted_notes() -> Array:
	var out: Array = []
	var N: Dictionary = story["notes"]
	var dark := state.room_state("dark")
	var any_dive := state.next_serial > 1
	var own := state.own_dives(room_id)
	var last_lost: bool = not own.is_empty() and own.back()["result"] != "exit"
	var made_it := state.program_made_it(room_id, program.to_text())
	var rs := state.room_state(room_id)
	var gy := [180.0 + 51.0 * rs.room.slots]
	var glass := func(id: String, w: float, targets: Array, x := 712.0, advance := true) -> void:
		out.append([id, Vector2(x, gy[0]), w, targets])
		if advance:
			gy[0] += OpNote.height_of(N[id], w) + 14.0
	var wv := Desk.v("order_wheel")
	var wheel := Vector3(float(wv[0]), float(wv[1]), float(wv[2]) + 12.0)
	var knob := Vector3(1229, 526, 22)
	var tube_c := Desk.r("tube_window").get_center()
	var tube_t := Vector3(tube_c.x, tube_c.y, 38)
	var cover := Desk.r("cover").get_center()
	if not _read().has("open0"):
		out.append(["welcome", Vector2(372, 92), 236.0, [tube_t]])
		return out
	if not any_dive:
		glass.call("dispatch", 236.0, [Vector3(cover.x, cover.y, 40)])
		return out
	if room_id == "dark" and not dark.certified:
		if last_lost and not _scrubbed and not _did("rewound"):
			var ra := Desk.r("reel_a").get_center()
			out.append(["rewind", Vector2(60, 232), 226.0, [Vector3(ra.x, ra.y, 46)]])
			out.append(["tape", Vector2(322, 232), 226.0, [Vector3(230, 640, 44)]])
		elif last_lost and not _did("printed"):
			glass.call("deck", 240.0, [])
			# How to print goes on the press itself, in the empty tray, if it is empty.
			if table.tray_rules().is_empty():
				out.append(["print", Vector2(674, 588), 236.0, [wheel, knob]])
			else:
				glass.call("print", 240.0, [wheel, knob])
		elif _did("printed") and not _did("inserted"):
			var s0 := table.slot_rect(0).get_center()
			glass.call("insert", 240.0, [Vector3(s0.x, s0.y, 40)])
		elif made_it and rs.survey.is_empty():
			glass.call("trials", 230.0, [Vector3(float(Desk.v("crank")[0]), float(Desk.v("crank")[1]), 28)])
	if not rs.certified and not rs.survey.is_empty() and not rs.survey.get("certified", false) and not _did("trial_lamp"):
		glass.call("trial_fail", 230.0, [Vector3(1128, 309, 64)])
	if room_id == "dark" and dark.certified and _unread().size() > 0:
		out.append(["certified", Vector2(372, 92), 236.0, [tube_t]])
	var next := SECTORS.find(room_id) + 1
	if rs.certified and next < SECTORS.size() and state.own_dives(SECTORS[next]).is_empty() and _unread().is_empty():
		var sk := Desk.r("sector_knob").get_center()
		glass.call("next_sector", 230.0, [Vector3(sk.x, sk.y, 40)])
	if any_dive and program.rules.size() >= 2 and current_dive != null and scope.replay.playing and not _did("lamps_seen"):
		var lr: Dictionary = Desk.layout()["lamps"]
		glass.call("lamps", 236.0, [Vector3(float(lr["rail_x"]), float(lr["first_y"]) + float(lr["pitch"]) * 0.5, 40)])
	if room_id == "jellyfish" and not rs.certified and _read().has("open1"):
		var ns := Desk.r("not_switch").get_center()
		if not _did("not"):
			glass.call("not", 92.0, [Vector3(ns.x, ns.y, 26)], 872.0, false)
		glass.call("jelly", 150.0, [wheel])
	if room_id == "nursery" and not rs.certified and _read().has("open2"):
		glass.call("nursery", 240.0, [wheel])
	return out


func _update_notes() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if press.negate:
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
## They go low on the reader's glass, under anything else he has written there.
func _flash_note(id: String, text: String, target: Variant) -> void:
	if _notes.has(id):
		_transient[id] = Time.get_ticks_msec() / 1000.0 + 5.0
		return
	var targets: Array = [] if target == null else [target]
	var n := OpNote.make(text, Vector2(712, 396), 236.0, targets)
	notes_layer.add_child(n)
	_notes[id] = n
	_transient[id] = Time.get_ticks_msec() / 1000.0 + 5.0


## A loop round a machine from the layout, for a note to point at.
func _ring(key: String, r: float) -> Vector3:
	var c := Desk.r(key).get_center()
	return Vector3(c.x, c.y, r)


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
		draw_string(Desk.font("plate"), lp + Vector2(9, 5), "LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Desk.STENCIL, 0.7))
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
