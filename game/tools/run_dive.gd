extends SceneTree
## Headless dive runner.
##   godot --headless --path game --script res://tools/run_dive.gd -- \
##       <room> <program.rbt> [seed] [--calm] [--png out.png] [--trace]
## Prints the outcome as JSON. With --png, draws Robbie's path over the map.
## With --trace, prints every think (which rule ran and why the others didn't).


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var positional: Array[String] = []
	var calm := false
	var png := ""
	var want_trace := false
	var dump := ""
	var i := 0
	while i < args.size():
		var a := args[i]
		if a == "--calm":
			calm = true
		elif a == "--trace":
			want_trace = true
		elif a == "--dump" and i + 1 < args.size():
			i += 1
			dump = args[i]
		elif a == "--png" and i + 1 < args.size():
			i += 1
			png = args[i]
		else:
			positional.append(a)
		i += 1
	if positional.size() < 2:
		printerr("usage: run_dive.gd <room> <program.rbt> [seed] [--calm] [--png out.png] [--trace] [--dump from:to]")
		quit(2)
		return
	var room := RoomLibrary.load_room(positional[0])
	if room.error != "":
		printerr("room: ", room.error)
		quit(2)
		return
	var program := ProgramFiles.load_program(positional[1])
	if not program.is_valid():
		for e in program.errors:
			printerr("program: ", e)
		quit(2)
		return
	var seed_v := int(positional[2]) if positional.size() > 2 else 1
	var dive := Dive.new(room, program, seed_v, calm)
	var out := dive.run()
	print(JSON.stringify(out, "  "))
	if want_trace:
		print(DiveText.trace_text(dive))
	if dump != "":
		var ab := dump.split(":")
		var r := dive.rec
		for k in range(int(ab[0]), mini(int(ab[1]), r.ticks)):
			var line := "t=%d robbie=(%d.%d, %d.%d) facing=%d hp=%d rule=%d flags=%d" % [k, r.rx[k] / 256, (r.rx[k] % 256) * 10 / 256, r.ry[k] / 256, (r.ry[k] % 256) * 10 / 256, Fx.to_deg(r.ra[k]), r.rhp[k], r.rrule[k] + 1, r.rflags[k]]
			for b in r.bx.size():
				line += " b%d=(%d,%d s%d)" % [b, r.bx[b][k] / 256, r.by[b][k] / 256, r.bstate[b][k]]
			print(line)
	if png != "":
		var err := PathImage.render(dive).save_png(png)
		if err != OK:
			printerr("could not write ", png)
	quit(0)
