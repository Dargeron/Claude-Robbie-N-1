extends SceneTree
## Gauntlet: run a list of decks against one room in a single start, for quick map iteration.
##   godot --headless --path game --script res://tools/gauntlet.gd -- <room id or path> <decks.txt> [seeds=5]
## decks.txt: one deck per line, rules separated by " / "; blank lines and "#" comments are skipped.
## Prints the pass count for each deck, the least charge any passing dive had left, and what ended the
## dives that failed.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: gauntlet.gd <room> <decks.txt> [seeds=5]")
		quit(2)
		return
	var room := RoomLibrary.load_room(args[0])
	if room.error != "":
		printerr(room.error)
		quit(2)
		return
	var seeds := int(args[2]) if args.size() > 2 else 5
	for line in FileAccess.get_file_as_string(args[1]).split("\n"):
		var deck := line.strip_edges()
		if deck == "" or deck.begins_with("#"):
			continue
		var p := Program.parse(deck.replace(" / ", "\n"))
		if not p.is_valid():
			print("  bad   %s  %s" % [deck, p.errors])
			continue
		var passed := 0
		var causes := {}
		var least := -1
		for s in range(1, seeds + 1):
			var r: Dictionary = Dive.new(room, p, s).run()
			if r["result"] == "exit":
				passed += 1
				least = int(r["energy"]) if least < 0 else mini(least, int(r["energy"]))
			else:
				var c := str(r.get("cause", r["result"]))
				causes[c] = int(causes.get(c, 0)) + 1
		var left := ("left %5d" % least) if least >= 0 else "          "
		print("%3d/%d  %-60s %s  %s" % [passed, seeds, deck, left, causes if not causes.is_empty() else ""])
	quit(0)
