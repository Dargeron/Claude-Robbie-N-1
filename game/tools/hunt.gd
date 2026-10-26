extends SceneTree
## Exploit hunt: tries every one-rule program, and every two-rule program whose
## second rule is unconditional (and whose first rule can let the reading continue:
## a condition, a setting, or an order that only sometimes applies), within the room's CPU budget. Reports anything
## that passes on most of the seeds tried. Slow by design; run it in the background.
##   godot --headless --path game --script res://tools/hunt.gd -- <room> [seeds=3] [progress_file] [only]
## `only` (comma-separated action prefixes, e.g. "move ,follow_wall") limits a quick sweep to decks
## whose every order starts with one of them; pass "" as the progress file to skip resuming.
## With a progress file the hunt is resumable: it records how far it got and what passed,
## and a restarted hunt skips what is already done.

const HEADINGS := ["0", "45", "90", "135", "180", "225", "270", "315"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var room := RoomLibrary.load_room(args[0])
	var seeds := int(args[1]) if args.size() > 1 else 3
	progress_path = args[2] if args.size() > 2 else ""
	var only: PackedStringArray = args[3].split(",") if args.size() > 3 else PackedStringArray()
	_load_progress()
	var actions := _actions()
	var conds := _conditions()
	var tried := 0
	var found: Array[String] = []
	var singles: Array[String] = []
	for a in actions:
		for c in conds:
			singles.append(a + c)
	var candidates: Array[String] = []
	for r in singles:
		candidates.append(r)
	for r1 in singles:
		if r1.find(" if ") < 0:
			continue  # an unconditional first rule hides the second...
		for a2 in actions:
			candidates.append(r1 + "\n" + a2)
	# ...unless its order can fall through: a setting (lamp), or an order that only
	# applies sometimes (shoot, keep_distance, move_towards light). Appended last so
	# older progress files stay valid (block 8: these were missed before).
	for r1 in singles:
		if r1.find(" if ") >= 0 or not _falls_through(r1):
			continue
		for a2 in actions:
			candidates.append(r1 + "\n" + a2)
	# Re-check what earlier runs found: the rooms and the sim change, and a finding
	# that no longer passes shouldn't linger in the report.
	for f in done_found:
		var prog_text := f.substr(0, f.find("  (")).replace(" / ", "\n")
		var still: Array[String] = []
		_try(room, prog_text, seeds, still)
		found.append_array(still)
	for idx in range(done_index, candidates.size()):
		if not only.is_empty() and not _only(candidates[idx], only):
			continue
		tried += _try(room, candidates[idx], seeds, found)
		if progress_path != "" and idx % 50 == 0:
			_save_progress(idx + 1, found, false)
	if progress_path != "":
		_save_progress(candidates.size(), found, true)
	print(JSON.stringify({"room": room.id, "budget": room.cpu_budget, "tried": tried, "passing": found}, "  "))
	quit(0)


var progress_path := ""
var done_index := 0
var done_found: Array[String] = []


func _load_progress() -> void:
	if progress_path == "" or not FileAccess.file_exists(progress_path):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(progress_path))
	if typeof(d) == TYPE_DICTIONARY:
		done_index = int(d.get("next", 0))
		for f in d.get("passing", []):
			done_found.append(str(f))


func _save_progress(next_index: int, found: Array[String], finished: bool) -> void:
	var f := FileAccess.open(progress_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"next": next_index, "finished": finished, "passing": found}, "  "))


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


func _only(text: String, prefixes: PackedStringArray) -> bool:
	for rule in text.split("\n"):
		var ok := false
		for pre in prefixes:
			ok = ok or rule.begins_with(pre)
		if not ok:
			return false
	return true


func _falls_through(rule: String) -> bool:
	return rule.begins_with("lamp ") or rule == "shoot" or rule.begins_with("keep_distance ") or rule == "move_towards light"


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
