extends SceneTree
## Prints the last words a run of Robbies would send for a few typical dives, with the
## station's memory of what was already said (Voice.final_line), to read them in context.
##   godot --headless --path game --script res://tools/voice_sample.gd


func _init() -> void:
	var cases := [["dark", "move_towards beacon", 1], ["dark", "lamp off\nmove_towards beacon", 1],
		["jellyfish", "move_towards beacon", 3], ["valve", "move_towards beacon", 1],
		["listeners", "move_towards beacon", 2], ["nursery", "lamp off\nfollow_wall left", 1],
		["valve", "keep_distance 4\nstop if valve_shut\nmove_towards beacon", 1]]
	var used: Array = []
	var serial := 1
	for c in cases:
		var d := Dive.new(RoomLibrary.load_room(c[0]), Program.parse(c[1]), c[2])
		d.run()
		print("== %s  %s  (%s, %ss)  tags %s" % [c[0], c[1].replace("\n", " / "), d.world.cause, d.outcome()["seconds"],
			Voice.circumstances(d, {"prev_serial": 1})])
		for i in 4:
			var h := {"prev_serial": serial - 1, "prev_cause": d.world.cause, "losses": i + 1, "used": used}
			if i == 0:
				h = {"used": used}
			var f := Voice.final_line(d, serial, h)
			used.append(f)
			print("   %03d  %s" % [serial, f])
			serial += 1
	quit(0)
