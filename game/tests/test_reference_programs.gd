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
		var first := Dive.new(room, prog, 1).run()
		match meta.get("expect", ""):
			"exit":
				eq(first["result"], "exit", "%s seed 1" % label)
				check(prog.cpu() <= room.cpu_budget, "%s fits the CPU budget (%d > %d)" % [label, prog.cpu(), room.cpu_budget])
			"fail":
				check(first["result"] != "exit", "%s should fail on seed 1" % label)
		match meta.get("certify", ""):
			"yes":
				var s := Survey.run(room, prog)
				check(s["certified"], "%s should pass the survey fleet, got %d/%d" % [label, s["passed"], s["fleet"]])
			"no":
				var s := Survey.run(room, prog)
				check(not s["certified"], "%s should fail the survey fleet, got %d/%d" % [label, s["passed"], s["fleet"]])
