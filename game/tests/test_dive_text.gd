extends TestCase
## The Why? panel's words (DiveText): what Robbie checked at a think and why it chose
## what it did, in plain language, from real dives.


func _first_think(room_id: String, text: String) -> Array:
	var p := Program.parse(text)
	var d := Dive.new(RoomLibrary.load_room(room_id), p, 1)
	d.vm.record_senses = true
	d.run()
	return [p, d.vm.trace[0], d]


func test_units() -> void:
	eq(DiveText.tenths(Fx.TILE), "1.0 m", "one tile is one metre")
	eq(DiveText.tenths(Fx.TILE * 3 / 2), "1.5 m", "half metres")
	eq(DiveText.time_of(World.TICKS_PER_SECOND * 3 / 2), "1.5s", "seconds and tenths")


func test_settings_and_choices() -> void:
	var r := _first_think("dark", "lamp off\nmove_towards beacon")
	var lines := DiveText.explain(r[0], r[1])
	eq(lines.size(), 2, "one line per rule read: %s" % [lines])
	eq(lines[0], "Rule 1 applied (setting): Lamp off", "a setting is applied and Robbie reads on")
	eq(lines[1], "Rule 2 chosen: Move towards beacon", "the first rule that applies is chosen")


func test_skipped_rules_say_why() -> void:
	var r := _first_think("valve", "stop if valve_shut\nkeep_distance 4\nmove_towards beacon")
	var lines := DiveText.explain(r[0], r[1])
	check(lines[0].begins_with("Rule 1 skipped: valve is shut = false"), "condition false: %s" % lines[0])
	eq(lines[1], "Rule 2 skipped: no hostile sensed to keep away from", "order that can't be carried out")
	eq(lines[2], "Rule 3 chosen: Move towards beacon", "then the beacon")
	var near := _first_think("valve", "stop if hostile_near 4\nmove_towards beacon")
	check(DiveText.explain(near[0], near[1])[0].ends_with("(no hostile sensed)"), "hostile near says nothing was sensed")


func test_drifting() -> void:
	var r := _first_think("dark", "stop if wall_ahead")
	var lines := DiveText.explain(r[0], r[1])
	eq(lines[lines.size() - 1], "No rule applied, so Robbie drifted.", "no rule applies: drift")


func test_senses_read_like_the_room() -> void:
	var dark := _first_think("dark", "move_towards beacon")
	var labels := []
	for s in DiveText.senses(dark[2].room, dark[1]):
		labels.append(s[0])
	eq(labels, ["wall ahead", "energy"], "The Dark has no creatures or valve to mention")
	var valve := _first_think("valve", "move_towards beacon")
	labels = []
	for s in DiveText.senses(valve[2].room, valve[1]):
		labels.append(s[0])
	eq(labels, ["wall ahead", "nearest hostile", "valve ahead", "energy"], "The Valve mentions all four")


func test_trace_text_reads_as_a_story() -> void:
	var r := _first_think("dark", "move_towards beacon")
	var t := DiveText.trace_text(r[2])
	check(t.begins_with("[0.0s] Rule 1 chosen: Move towards beacon"), "starts with the first choice: %s" % t.substr(0, 60))
	check(t.find("event:") >= 0, "events are listed")
