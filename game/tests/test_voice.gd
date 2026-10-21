extends TestCase


func _dive(room_id: String, text: String, seed_v := 1) -> Dive:
	var d := Dive.new(RoomLibrary.load_room(room_id), Program.parse(text), seed_v)
	d.run()
	return d


func test_lines_load_and_fill_placeholders() -> void:
	check(Voice.lines().has("launch"), "lines.json loads")
	var line := Voice.pick("same_death", 7, {"prev_serial": 6, "prev_cause": "lurker"})
	check(line.find("{") < 0, "placeholders filled: %s" % line)


## Every line in pools whose key starts with one of these prefixes, filled in for Robbie 003.
func _pool(prefixes: Array) -> Array:
	var out: Array = []
	var lib := Voice.lines()
	for key: String in lib:
		for p: String in prefixes:
			if key == p or key.begins_with(p + "/"):
				for l in lib[key]:
					out.append(str(l).format({"n": "003", "next": "Robbie 004", "prev": "Robbie 002", "cause": ""}))
	return out


func test_last_words_match_the_ending() -> void:
	var won := _dive("dark", "follow_wall left")
	check(_pool(["exit"]).has(Voice.final_line(won, 3, {})), "an exit gets an exit line")
	var lost := _dive("dark", "move_towards beacon")
	var f := Voice.final_line(lost, 3, {})
	check(_pool(["last_wall", "last_any"]).has(f), "a wall death gets a wall line or a circumstance line, got: %s" % f)
	check(not _pool(["last_jellyfish", "last_eel", "last_valve", "last_lurker", "last_energy"]).has(f), "never another cause's line")


## Albert's #10: hundreds of last words, each fitting a caption, with known placeholders.
func test_last_words_are_well_formed() -> void:
	var tags := ["first", "persistent", "near_exit", "early", "late", "lamp_off", "still", "low_energy", "laser", "bruised"]
	var heads := ["exit", "same_death", "last_wall", "last_jellyfish", "last_lurker", "last_valve", "last_eel",
		"last_energy", "last_timeout", "last_any"]
	var count := 0
	var lib := Voice.lines()
	for key: String in lib:
		if key.begins_with("_") or not (key.begins_with("last_") or key.begins_with("exit") or key == "same_death"):
			continue
		var parts := key.split("/")
		check(heads.has(parts[0]), "known head: %s" % key)
		if parts.size() > 1:
			check(tags.has(parts[1]), "known circumstance: %s" % key)
		for l in lib[key]:
			count += 1
			var line := str(l)
			var filled := line.format({"n": "003", "next": "Robbie 004", "prev": "Robbie 002", "cause": "the eel"})
			check(filled.find("{") < 0, "only known placeholders: %s" % line)
			check(filled.length() <= 80, "fits a caption (80 characters): %s" % line)
			if line.find("{prev}") >= 0 or line.find("{cause}") >= 0:
				check(key == "same_death" or key == "last_any/persistent", "{prev}/{cause} only where there was a previous Robbie: %s" % key)
	check(count >= 300, "hundreds of last words (%d)" % count)


func test_last_words_rarely_repeat() -> void:
	var lost := _dive("dark", "move_towards beacon")
	var used: Array = []
	for serial in range(2, 32):
		var f := Voice.final_line(lost, serial, {"prev_serial": serial - 1, "prev_cause": "wall", "losses": 1, "used": used})
		check(not used.has(f), "Robbie %d repeats: %s" % [serial, f])
		used.append(f)
	eq(used.size(), 30, "thirty wall losses, thirty different last words")


func test_circumstances() -> void:
	var dark := _dive("dark", "lamp off\nmove_towards beacon")
	var t := Voice.circumstances(dark, {})
	check(t.has("first"), "no previous Robbie: first (%s)" % [t])
	check(t.has("lamp_off"), "lamp off at the end (%s)" % [t])
	check(Voice.circumstances(dark, {"prev_serial": 1, "losses": 5}).has("persistent"), "five losses in a row: persistent")
	var jelly := _dive("jellyfish", "move_towards beacon", 3)
	check(Voice.circumstances(jelly, {"prev_serial": 1}).has("early"), "lost within seven seconds: early")
	var won := _dive("dark", "follow_wall left")
	check(not Voice.circumstances(won, {"prev_serial": 1}).has("early"), "an exit is never early")


func test_captions_end_with_last_words() -> void:
	var d := _dive("dark", "follow_wall left")
	var caps := Voice.captions(d, 2, {})
	eq(caps.back()[1], Voice.last_words(d, 2, {}), "the last caption is the last transmission")
	check(caps.front()[0] == 0, "the launch line opens the dive")


func test_same_robbie_same_words() -> void:
	var d := _dive("valve", "move_towards beacon")
	eq(Voice.captions(d, 5, {}), Voice.captions(d, 5, {}), "deterministic")
