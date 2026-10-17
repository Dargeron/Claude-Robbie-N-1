extends SceneTree
## Solver v1: a mutation search for the cheapest program that certifies in a room
## (passes the survey fleet on the game's own survey seeds). Where the exploit hunt
## sweeps every short program, the solver wanders through longer ones (up to
## MAX_RULES), starting from our reference programs and from random ones.
##
##   godot --headless --path game --script res://tools/solve.gd -- <room> [total_evaluations=400] [progress_file]
## The count is cumulative across runs: a resumed search stops when the room's total reaches it.
##
## With a progress file the search is resumable and cumulative: every certified
## program it ever found is kept (text, CPU, survey passes), which also seeds the
## CPU histograms. Results: the cheapest certified programs, and how reliable the
## best few are on twenty other seeds (a lucky survey shows up there).

const MAX_RULES := 4
const HEADINGS := ["0", "45", "90", "135", "180", "225", "270", "315"]

var room: Room
var rng := RandomNumberGenerator.new()   # tooling only: the search itself needn't be deterministic
var cache := {}        # program text -> {"cpu", "passed", "certified"}
var found := {}        # certified program text -> {"cpu", "passed"}
var evaluations := 0
var actions: Array[String] = []
var conditions: Array[String] = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	room = RoomLibrary.load_room(args[0])
	var budget := int(args[1]) if args.size() > 1 else 400
	var progress := args[2] if args.size() > 2 else ""
	rng.randomize()
	actions = _actions()
	conditions = _conditions()
	var earlier := _load(progress)

	# Starting points: our reference programs for this room, and whatever certified before.
	var pool: Array[String] = []
	for path in Golden.program_paths():
		if path.get_base_dir().get_file() == room.id:
			pool.append(_normalise(ProgramFiles.load_program(path).to_text()))
	pool.append_array(earlier)   # re-checked below: the rooms and the sim change
	pool.append_array(_hunt_finds(progress))
	for t in pool:
		_evaluate(t)

	while evaluations < budget:
		var parent := _pick_parent(pool)
		var child := _mutate(parent)
		for i in rng.randi_range(0, 2):
			child = _mutate(child)
		var r := _evaluate(child)
		if r.is_empty():
			continue
		if r["certified"] or r["passed"] >= Survey.PASS_NEEDED - 4:
			pool.append(child)
		if progress != "" and evaluations % 25 == 0:
			_save(progress)
	if progress != "":
		_save(progress)
	print(JSON.stringify(_report(), "  "))
	quit(0)


# ---------------------------------------------------------------- evaluation

## Survey-fleet result for a program, stopping as soon as certification is out of reach.
func _evaluate(text: String) -> Dictionary:
	if cache.has(text):
		return cache[text]
	var p := Program.parse(text)
	if not p.is_valid() or p.rules.is_empty() or p.cpu() > room.cpu_budget:
		cache[text] = {}
		return {}
	evaluations += 1
	var passed := 0
	var failed := 0
	for s in range(Survey.FIRST_SEED, Survey.FIRST_SEED + Survey.FLEET):
		if Dive.new(room, p, s).run()["result"] == "exit":
			passed += 1
		else:
			failed += 1
			if failed > Survey.FLEET - Survey.PASS_NEEDED:
				break
	var r := {"cpu": p.cpu(), "passed": passed, "certified": passed >= Survey.PASS_NEEDED}
	cache[text] = r
	if r["certified"]:
		found[text] = {"cpu": p.cpu(), "passed": passed}
	return r


## How often a program gets through on seeds the survey never uses.
func _reliability(text: String, n: int = 20) -> int:
	var p := Program.parse(text)
	var ok := 0
	for s in range(1, n + 1):
		if Dive.new(room, p, s).run()["result"] == "exit":
			ok += 1
	return ok


# ---------------------------------------------------------------- search

## Mostly the cheapest certified programs (to push the CPU down), sometimes
## anything promising (to keep exploring).
func _pick_parent(pool: Array[String]) -> String:
	var certified := found.keys()
	if not certified.is_empty() and rng.randf() < 0.7:
		certified.sort_custom(func(a, b) -> bool: return found[a]["cpu"] < found[b]["cpu"])
		return certified[mini(rng.randi_range(0, 4), certified.size() - 1)]
	if not pool.is_empty() and rng.randf() < 0.8:
		return pool[rng.randi_range(0, pool.size() - 1)]
	return _random_rule()


func _mutate(text: String) -> String:
	var rules := Array(text.split("\n", false))
	match rng.randi_range(0, 6):
		0:  # add a rule somewhere
			if rules.size() < MAX_RULES:
				rules.insert(rng.randi_range(0, rules.size()), _random_rule())
		1:  # remove a rule
			if rules.size() > 1:
				rules.remove_at(rng.randi_range(0, rules.size() - 1))
		2:  # swap two neighbours
			if rules.size() > 1:
				var i := rng.randi_range(0, rules.size() - 2)
				var tmp: String = rules[i]
				rules[i] = rules[i + 1]
				rules[i + 1] = tmp
		3:  # new order, same condition
			var i := rng.randi_range(0, rules.size() - 1)
			rules[i] = _with_action(rules[i], actions[rng.randi_range(0, actions.size() - 1)])
		4:  # new condition, same order
			var i := rng.randi_range(0, rules.size() - 1)
			rules[i] = _action_of(rules[i]) + conditions[rng.randi_range(0, conditions.size() - 1)]
		5:  # drop a condition
			var i := rng.randi_range(0, rules.size() - 1)
			rules[i] = _action_of(rules[i])
		6:  # replace a rule
			rules[rng.randi_range(0, rules.size() - 1)] = _random_rule()
	return _normalise("\n".join(rules))


func _random_rule() -> String:
	return actions[rng.randi_range(0, actions.size() - 1)] + conditions[rng.randi_range(0, conditions.size() - 1)]


func _action_of(rule: String) -> String:
	var at := rule.find(" if ")
	return rule if at < 0 else rule.substr(0, at)


func _with_action(rule: String, action: String) -> String:
	var at := rule.find(" if ")
	return action if at < 0 else action + rule.substr(at)


## Canonical text, without dead rules: nothing after an unconditional order that
## always applies is ever read, so it would only pad the CPU and the histogram.
func _normalise(text: String) -> String:
	var p := Program.parse(text)
	if not p.is_valid():
		return text.strip_edges()
	var kept: Array[String] = []
	for line in p.to_text().strip_edges().split("\n", false):
		kept.append(line)
		if line.find(" if ") < 0 and not _falls_through(line):
			break
	return "\n".join(kept)


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
	var out: Array[String] = ["", "", "", ""]   # weighted: unconditional rules are common
	for id in Catalogue.CONDITIONS:
		var def: Dictionary = Catalogue.CONDITIONS[id]
		var variants: Array[String] = []
		if def.has("param") and def["param"] is Array:
			for p in def["param"]:
				variants.append("%s %s" % [id, p])
		elif def.has("param"):
			for r in range(1, MAX_RULES + 1):
				variants.append("%s %d" % [id, r])
		else:
			variants.append(id)
		for v in variants:
			out.append(" if " + v)
			out.append(" if not " + v)
	return out


# ---------------------------------------------------------------- results

func _report() -> Dictionary:
	var texts := found.keys()
	texts.sort_custom(func(a, b) -> bool:
		return found[a]["cpu"] < found[b]["cpu"] or (found[a]["cpu"] == found[b]["cpu"] and a.length() < b.length()))
	var best: Array = []
	for i in mini(5, texts.size()):
		var t: String = texts[i]
		if not found[t].has("reliability"):
			found[t]["reliability"] = _reliability(t)
		best.append({"program": t.replace("\n", " / "), "cpu": found[t]["cpu"], "survey": found[t]["passed"],
			"other_seeds": "%d/20" % int(found[t]["reliability"])})
	var histogram := {}
	for t in texts:
		var c := str(found[t]["cpu"])
		histogram[c] = int(histogram.get(c, 0)) + 1
	return {"room": room.id, "budget": room.cpu_budget, "evaluations": evaluations,
		"certified_programs": texts.size(), "cheapest": best, "cpu_histogram": histogram}


## Programs the exploit hunt found passing in this room (out/hunt/<room>.json next to
## out/solve/), as more starting points.
func _hunt_finds(progress: String) -> Array[String]:
	var out: Array[String] = []
	if progress == "":
		return out
	var hunt_path := progress.get_base_dir().get_base_dir().path_join("hunt").path_join(room.id + ".json")
	if not FileAccess.file_exists(hunt_path):
		return out
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(hunt_path))
	if typeof(d) != TYPE_DICTIONARY:
		return out
	for f in d.get("passing", []):
		var s := str(f)
		out.append(_normalise(s.substr(0, s.find("  (")).replace(" / ", "\n")))
	return out


func _load(path: String) -> Array[String]:
	var out: Array[String] = []
	if path == "" or not FileAccess.file_exists(path):
		return out
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(d) != TYPE_DICTIONARY:
		return out
	evaluations = int(d.get("evaluations", 0))
	for t in d.get("found", {}):
		out.append(str(t))
	return out


func _save(path: String) -> void:
	var r := _report()
	r["found"] = found
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(r, "  "))
