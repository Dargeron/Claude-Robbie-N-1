extends TestCase


func _dive(room_id: String, text: String, seed_v := 1) -> Dive:
	var d := Dive.new(RoomLibrary.load_room(room_id), Program.parse(text), seed_v)
	d.run()
	return d


func test_lines_load_and_fill_placeholders() -> void:
	check(Voice.lines().has("launch"), "lines.json loads")
	var line := Voice.pick("same_death", 7, {"prev_serial": 6, "prev_cause": "lurker"})
	check(line.find("{") < 0, "placeholders filled: %s" % line)


func test_last_words_match_the_ending() -> void:
	var won := _dive("dark", "follow_wall left")
	check(Voice.lines()["exit"].has(Voice.final_line(won, 3, {})), "an exit gets an exit line")
	var lost := _dive("dark", "move_towards beacon")
	var pool: Array = Voice.lines()["last_wall"]
	var f := Voice.final_line(lost, 3, {})
	check(pool.has(f), "a wall death gets a wall line, got: %s" % f)


func test_captions_end_with_last_words() -> void:
	var d := _dive("dark", "follow_wall left")
	var caps := Voice.captions(d, 2, {})
	eq(caps.back()[1], Voice.last_words(d, 2, {}), "the last caption is the last transmission")
	check(caps.front()[0] == 0, "the launch line opens the dive")


func test_same_robbie_same_words() -> void:
	var d := _dive("valve", "move_towards beacon")
	eq(Voice.captions(d, 5, {}), Voice.captions(d, 5, {}), "deterministic")
