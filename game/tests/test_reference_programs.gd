extends TestCase
## Each room's reference programs behave as designed: intended solutions pass
## the survey fleet; naive programs fail it (docs/design/rooms.md).


func test_reference_programs() -> void:
	var paths := Golden.program_paths()
	check(paths.size() >= 9, "reference programs exist")
	for path in paths:
		var room_id := path.get_base_dir().get_file()
		var room := RoomLibrary.load_room(room_id)
		var prog := ProgramFiles.load_program(path)
		var meta := ProgramFiles.metadata(path)
		var label := path.trim_prefix(Golden.PROGRAM_DIR + "/")
		if not prog.is_valid():
			failures.append("%s does not parse: %s" % [label, str(prog.errors)])
			continue
		var kit := Kit.from_text(str(meta.get("kit", "")))
		var first := Dive.new(room, prog, 1, false, kit).run()
		var expect: String = meta.get("expect", "")
		if expect.begins_with("bonus "):
			# On the sector's practice seed: the dive the player actually gets on the console.
			var want := int(expect.substr(6))
			var practice := 1 + GameState.ROOMS.find(room_id) * 100
			var got: Array = Dive.new(room, prog, practice, false, kit).run()["bonus"]
			check(want < room.bonuses.size(), "%s: the room has no lost beacon %d" % [label, want])
			check(got.has(want), "%s should recover lost beacon %d on the practice seed %d (got %s)" % [label, want, practice, str(got)])
		match expect:
			"exit":
				eq(first["result"], "exit", "%s seed 1" % label)
				check(prog.cpu() <= room.cpu_budget, "%s fits the CPU budget (%d > %d)" % [label, prog.cpu(), room.cpu_budget])
			"fail":
				check(first["result"] != "exit", "%s should fail on seed 1" % label)
		match meta.get("certify", ""):
			"yes":
				if not Survey.certifies(room, prog, kit):
					var s := Survey.run(room, prog, Survey.FLEET, Survey.FIRST_SEED, kit)
					failures.append("%s should pass the survey fleet, got %d/%d" % [label, s["passed"], s["fleet"]])
			"no":
				if Survey.certifies(room, prog, kit):
					var s := Survey.run(room, prog, Survey.FLEET, Survey.FIRST_SEED, kit)
					failures.append("%s should fail the survey fleet, got %d/%d" % [label, s["passed"], s["fleet"]])
