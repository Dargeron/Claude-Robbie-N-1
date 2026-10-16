extends TestCase
## Every golden replay must replay exactly.


func test_golden_replays() -> void:
	var files := DirAccess.get_files_at(Golden.DIR)
	check(files.size() > 0, "no golden replays found; run tools/bless.sh")
	for f in files:
		if not f.ends_with(".json"):
			continue
		var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Golden.DIR + "/" + f))
		var path: String = Golden.PROGRAM_DIR + "/" + str(g["program"])
		if not FileAccess.file_exists(path):
			failures.append("%s: program %s no longer exists (re-bless)" % [f, path])
			continue
		var now := Golden.record(str(g["room"]), path, int(g["seed"]))
		if now["result"] != g["result"] or int(now["ticks"]) != int(g["ticks"]) or int(now["final_hash"]) != int(g["final_hash"]):
			var old_h: Array = g["hashes"]
			var new_h: Array = now["hashes"]
			var at := -1
			for k in mini(old_h.size(), new_h.size()):
				if int(old_h[k]) != int(new_h[k]):
					at = k
					break
			failures.append("%s: was %s at %d ticks, now %s at %d ticks; first divergence near %s" % [
				f, g["result"], int(g["ticks"]), now["result"], now["ticks"],
				("tick %d" % (at * World.HASH_EVERY)) if at >= 0 else "the end"])
