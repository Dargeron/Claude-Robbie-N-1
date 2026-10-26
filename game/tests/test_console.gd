extends TestCase
## The operator's console: the parts that are logic rather than pictures.


func test_every_order_on_the_drum_is_a_valid_card() -> void:
	for o: Array in PressOrders.ORDERS:
		var r := {"action": o[0], "param": o[1], "cond": "", "cond_param": "", "negate": false}
		var p := Program.parse(Program.new().rule_text(r))
		check(p.is_valid() and p.rules.size() == 1, "drum order %s %s parses: %s" % [o[0], o[1], str(p.errors)])
		check(CardArt.order_label(o[0], o[1]) != "", "drum order %s has a label" % o[0])


func test_every_condition_value_is_valid() -> void:
	for c: String in PressOrders.CONDS:
		var vals: Array = PressOrders.COND_VALUES.get(c, [""])
		for v: String in vals:
			if c == "executing" and int(v) > 1:
				continue   # needs a deck that long
			var text := "stop" + ("" if c == "" else " if %s %s" % [c, v])
			var p := Program.parse(text.strip_edges())
			check(p.is_valid(), "condition %s %s parses: %s" % [c, v, str(p.errors)])


func test_the_shifts_issue_every_plate_once() -> void:
	var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/story/console.json"))
	var seen := {}
	for sh: Dictionary in story["shifts"]:
		for p: String in sh["plates"]:
			check(not seen.has(p), "plate %s issued once" % p)
			seen[p] = true
	# Every order a shift's reference program needs is on the drum by that shift.
	var needs := {"dark": ["follow_wall"], "jellyfish": ["lamp", "towards_beacon", "shoot"], "listeners": ["stop", "hostile_near"],
		"gallery": ["keep_distance"], "lights": ["towards_light"]}
	var have: Array = []
	for i in story["shifts"].size():
		var sh: Dictionary = story["shifts"][i]
		have.append_array(sh["plates"])
		for p: String in needs[sh["sector"]]:
			check(have.has(p), "%s has plate %s" % [sh["sector"], p])


func test_cards_stamp_why_they_were_skipped() -> void:
	var r := Program.parse("keep_distance 2 if not wall_behind").rules[0]
	eq(CardArt.reason(r, "cond_false"), "WALL", "negated wall stamp")
	var s := Program.parse("shoot").rules[0]
	eq(CardArt.reason(s, "not_applicable"), "NO TARGET", "nothing to shoot")
	eq(CardArt.lines(Program.parse("move 90 if energy_below 25").rules[0]), ["SWIM 090° E", "IF CHARGE BELOW 25%"], "card text")


func test_the_tape_reports_a_dive_in_order() -> void:
	var room := RoomLibrary.load_room("jellyfish")
	var d := Dive.new(room, Program.parse("move_towards beacon"), 101)
	d.vm.record_senses = true
	d.run()
	var v := SonarView.new()
	v.setup(d)
	var lines := Tape.lines(d, v, 7, "SECTOR 2", [], "Goodbye.")
	v.free()
	check(lines.size() >= 3, "several lines")
	eq(lines[0]["kind"], "info", "it starts with the dispatch")
	var last := -1
	var contacts := 0
	for l: Dictionary in lines:
		check(int(l["t"]) >= last, "lines in time order")
		last = int(l["t"])
		if str(l["text"]).begins_with("CONTACT"):
			contacts += 1
	check(contacts > 0, "the jellyfish are reported as contacts")
	var ends := lines.filter(func(l: Dictionary) -> bool: return l["kind"] == "end")
	eq(ends.size(), 1, "one end line")


func test_the_console_save_is_its_own() -> void:
	var s := GameState.new()
	s.save_path = "user://test_console_save.json"
	s.extra = {"memos_read": ["open0"]}
	s.save()
	var t := GameState.new()
	t.save_path = "user://test_console_save.json"
	t.load_save()
	eq(t.extra.get("memos_read", []), ["open0"], "console records round-trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_console_save.json"))


func test_each_sector_can_be_certified_within_its_slots() -> void:
	for id: String in ["dark", "jellyfish", "listeners", "gallery", "lights", "nursery", "valve", "lock"]:
		var room := RoomLibrary.load_room(id)
		var fits := false
		for f: String in DirAccess.get_files_at("res://content/programs/" + id):
			if not f.ends_with(".rbt"):
				continue
			var text := FileAccess.get_file_as_string("res://content/programs/%s/%s" % [id, f])
			if text.find("# certify: yes") >= 0 and Program.parse(text).rules.size() <= room.slots:
				fits = true
		check(fits, "%s has a certifying program within its %d slots" % [id, room.slots])
