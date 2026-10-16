extends SceneTree
## Survey fleet: run one program on several seeds and report the pass rate.
##   godot --headless --path game --script res://tools/certify.gd -- <room> <program.rbt> [fleet=10] [first_seed=1]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: certify.gd <room> <program.rbt> [fleet=10] [first_seed=1]")
		quit(2)
		return
	var room := RoomLibrary.load_room(args[0])
	var program := ProgramFiles.load_program(args[1])
	if room.error != "" or not program.is_valid():
		printerr(room.error, program.errors)
		quit(2)
		return
	var fleet := int(args[2]) if args.size() > 2 else 10
	var first := int(args[3]) if args.size() > 3 else 1
	var report := Survey.run(room, program, fleet, first)
	print(JSON.stringify(report, "  "))
	quit(0)
