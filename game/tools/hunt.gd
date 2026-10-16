extends SceneTree
## Exploit hunt: tries every one-rule program, and every two-rule program whose
## second rule is unconditional, within the room's CPU budget. Reports anything
## that passes on most of the seeds tried. Slow by design; run it in the background.
##   godot --headless --path game --script res://tools/hunt.gd -- <room> [seeds=3]

const HEADINGS := ["0", "45", "90", "135", "180", "225", "270", "315"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var room := RoomLibrary.load_room(args[0])
	var seeds := int(args[1]) if args.size() > 1 else 3
	var actions := _actions()
	var conds := _conditions()
	var tried := 0
	var found: Array[String] = []
	var singles: Array[String] = []
	for a in actions:
		for c in conds:
			singles.append(a + c)
	for r in singles:
		tried += _try(room, r, seeds, found)
	for r1 in singles:
		if r1.find(" if ") < 0:
			continue  # an unconditional first rule hides the second
		for a2 in actions:
			tried += _try(room, r1 + "\n" + a2, seeds, found)
	print(JSON.stringify({"room": room.id, "budget": room.cpu_budget, "tried": tried, "passing": found}, "  "))
	quit(0)


func _try(room: Room, text: String, seeds: int, found: Array[String]) -> int:
	var p := Program.parse(text)
	if not p.is_valid() or p.cpu() > room.cpu_budget:
		return 0
	var passed := 0
	for s in range(1, seeds + 1):
		if Dive.new(room, p, s).run()["result"] == "exit":
			passed += 1
		elif s == 1:
			break  # failed the first seed: not an exploit worth reporting
	if passed * 3 >= seeds * 2:
		found.append("%s  (cpu %d, %d/%d)" % [text.replace("\n", " / "), p.cpu(), passed, seeds])
	return 1


func _actions() -> Array[String]:
	var out: Array[String] = []
	for h in HEADINGS:
		out.append("move " + h)
	for id in Catalogue.ACTIONS:
		if id == "move":
			continue
		var def: Dictionary = Catalogue.ACTIONS[id]
		if def.has("param") and def["param"] is Array:
			for p in def["param"]:
				out.append("%s %s" % [id, p])
		else:
			out.append(id)
	return out


func _conditions() -> Array[String]:
	var out: Array[String] = [""]
	for id in Catalogue.CONDITIONS:
		var def: Dictionary = Catalogue.CONDITIONS[id]
		var variants: Array[String] = []
		if def.has("param") and def["param"] is Array:
			for p in def["param"]:
				variants.append("%s %s" % [id, p])
		elif def.has("param"):
			variants.append("%s 1" % id)
		else:
			variants.append(id)
		for v in variants:
			out.append(" if " + v)
			out.append(" if not " + v)
	return out
