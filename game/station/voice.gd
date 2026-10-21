class_name Voice
extends RefCounted
## Robbie's subtitles. Lines live in res://content/voice/lines.json so they can be
## edited without touching code. Choices are deterministic: the same Robbie always
## says the same thing at the same moment.

const LINES_PATH := "res://content/voice/lines.json"
const LAST_WORDS_LEAD := 45   # ticks before the end: last words show during the final moments

static var _lines: Dictionary = {}


static func lines() -> Dictionary:
	if _lines.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LINES_PATH))
		_lines = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _lines


static func cause_label(cause: String) -> String:
	match cause:
		"wall":
			return "the wall"
		"jellyfish":
			return "the jellyfish"
		"lurker":
			return "the lurker"
		"eel":
			return "the eel"
		"valve":
			return "the valve"
		"energy":
			return "no energy"
		"exit":
			return "the exit"
	return cause


static func pick(key: String, serial: int, history: Dictionary = {}) -> String:
	var pool: Array = lines().get(key, [])
	if pool.is_empty():
		return ""
	var h := 0
	for ch in key:
		h += ch.unicode_at(0)
	var line: String = pool[(serial * 31 + h) % pool.size()]
	var prev: int = history.get("prev_serial", serial - 1)
	return line.format({
		"n": "%03d" % serial,
		"next": "Robbie %03d" % (serial + 1),
		"prev": "Robbie %03d" % prev,
		"cause": cause_label(str(history.get("prev_cause", ""))),
	})


## Subtitles for a finished dive: [[tick, text], ...] in time order.
## history may hold prev_serial and prev_cause (the previous Robbie in this room).
static func captions(dive: Dive, serial: int, history: Dictionary) -> Array:
	var out: Array = []
	var rec := dive.rec
	var w := dive.world
	out.append([0, pick("launch", serial)])
	# First time a jellyfish comes close.
	for k in range(0, rec.ticks, 3):
		var seen := false
		for i in rec.bx.size():
			if w.bodies[i].kind == Body.Kind.JELLYFISH and (rec.bstate[i][k] & 1) == 1:
				if Fx.dist(rec.bx[i][k] - rec.rx[k], rec.by[i][k] - rec.ry[k]) <= 64 * Fx.ONE:
					seen = true
		if seen:
			out.append([k, pick("first_jellyfish", serial)])
			break
	var hurt_said := {}
	var low_said := false
	for e in w.events:
		match e["type"]:
			"laser":
				if e.get("bounced", false) and not hurt_said.has("laser_bounce"):
					hurt_said["laser_bounce"] = true
					out.append([e["t"], pick("laser_bounce", serial)])
			"eel_hears":
				if not hurt_said.has("eel_hears"):
					hurt_said["eel_hears"] = true
					out.append([e["t"], pick("eel_hears", serial)])
			"lurker_wakes":
				if not hurt_said.has("lurker_wakes"):
					hurt_said["lurker_wakes"] = true
					out.append([e["t"], pick("lurker_wakes", serial)])
			"damage":
				var c: String = e["cause"]
				if int(e["hp"]) > 0 and not hurt_said.has(c) and lines().has("hurt_" + c):
					hurt_said[c] = true
					out.append([e["t"], pick("hurt_" + c, serial)])
	for k in range(0, rec.ticks, 30):
		if not low_said and rec.ren[k] * 4 < w.energy_max:
			low_said = true
			out.append([k, pick("low_energy", serial)])
	var end := maxi(0, rec.ticks - 1 - LAST_WORDS_LEAD)
	# Nothing else may talk over the last words.
	out = out.filter(func(c): return c[0] < end - 30)
	# A Robbie's last words are chosen once, at launch, and kept with it (see final_line).
	var words: String = history.get("last_words", "")
	out.append([end, words if words != "" else final_line(dive, serial, history)])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out


## The last transmission: what this Robbie says as its burst fires (Albert's note #10).
## Chosen by how it ended and the circumstances (circumstances()): lines written for this
## cause in this circumstance first, then lines for the circumstance, then the cause's
## general lines. history["used"] lists last words earlier Robbies already sent; those
## are skipped while there's anything else to say, so lines rarely repeat. Deterministic:
## the same Robbie with the same history always says the same thing.
static func final_line(dive: Dive, serial: int, history: Dictionary) -> String:
	var w := dive.world
	var tags := circumstances(dive, history)
	var head := "exit" if w.result == World.Result.EXIT else "last_" + w.cause
	var lib := lines()
	var weighted: Array = []   # [key, weight]
	for t in tags:
		weighted.append([head + "/" + t, 6])
		if head != "exit":
			weighted.append(["last_any/" + t, 3])
	if head != "exit" and history.get("prev_cause", "") == w.cause and w.cause != "":
		weighted.append(["same_death", 1])
	weighted.append([head, 2])
	var used_norm := {}
	for u in history.get("used", []):
		used_norm[_norm(str(u))] = true
	var fill := {
		"n": "%03d" % serial,
		"next": "Robbie %03d" % (serial + 1),
		"prev": "Robbie %03d" % int(history.get("prev_serial", serial - 1)),
		"cause": cause_label(str(history.get("prev_cause", ""))),
	}
	for skip_used in [true, false]:
		var cands: Array = []   # [text, weight]
		for kw in weighted:
			for raw in lib.get(kw[0], []):
				var text := str(raw).format(fill)
				if skip_used and used_norm.has(_norm(text)):
					continue
				cands.append([text, int(kw[1])])
		if cands.is_empty():
			continue
		var total := 0
		for c in cands:
			total += int(c[1])
		var h := (serial * 7919 + head.length() * 104729 + tags.size() * 31) % total
		for c in cands:
			h -= int(c[1])
			if h < 0:
				return c[0]
	return ""


## A line with its Robbie numbers taken out: "Tell Robbie 008: ..." and "Tell Robbie 012: ..."
## are the same line for the purpose of not repeating.
static var _digits: RegEx = null

static func _norm(t: String) -> String:
	if _digits == null:
		_digits = RegEx.create_from_string("\\d{3}")
	return _digits.sub(t, "#", true)


## What was going on when this Robbie's dive ended, as tags for choosing its last words.
## history may hold prev_serial (none: the first Robbie in the room) and losses (since
## the room's last success, before this Robbie).
static func circumstances(dive: Dive, history: Dictionary) -> Array[String]:
	var w := dive.world
	var rec := dive.rec
	var k := rec.ticks - 1
	var tags: Array[String] = []
	if not history.has("prev_serial"):
		tags.append("first")
	if int(history.get("losses", 0)) >= 4:
		tags.append("persistent")
	var to_exit := Fx.dist(w.room.exit_cx - rec.rx[k], w.room.exit_cy - rec.ry[k])
	var lost := w.result != World.Result.EXIT
	if lost and to_exit <= 7 * Fx.TILE:
		tags.append("near_exit")
	if lost and rec.ticks <= 7 * World.TICKS_PER_SECOND:
		tags.append("early")
	if rec.ticks >= 40 * World.TICKS_PER_SECOND:
		tags.append("late")
	if (rec.rflags[k] & 1) == 0:
		tags.append("lamp_off")
	if lost and (rec.rflags[k] & 2) == 0 and w.cause != "energy":
		tags.append("still")
	if w.cause != "energy" and rec.ren[k] * 4 < w.energy_max:
		tags.append("low_energy")
	var hurt_early := false   # hurt, and kept going for a while after
	for e in w.events:
		if e["type"] == "laser":
			if not tags.has("laser"):
				tags.append("laser")
		elif e["type"] == "damage" and (not lost or int(e["t"]) < k - 3 * World.TICKS_PER_SECOND):
			hurt_early = true
	if hurt_early:
		tags.append("bruised")
	return tags


## The epitaph for the Wall of Robbies.
static func last_words(dive: Dive, serial: int, history: Dictionary) -> String:
	return final_line(dive, serial, history)


const HINTS_PATH := "res://content/voice/hints.json"
static var _hints: Dictionary = {}


static func hints() -> Dictionary:
	if _hints.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(HINTS_PATH))
		_hints = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _hints


## Mission control's line for the station, or "" when it has nothing to add.
## streak = [n, cause] (consecutive losses to one cause); losses = losses since the last success.
static func mission_control(room_id: String, own_count: int, streak: Array, losses: int, next_serial: int) -> String:
	var h := hints()
	if own_count == 0:
		return str(h.get("start", "")).format({"n": "%03d" % next_serial})
	var best := ""
	var key := "%s/%s" % [room_id, streak[1]]
	for step in h.get("rooms", {}).get(key, []):
		if int(streak[0]) >= int(step["after"]):
			best = "Mission control: " + str(step["text"])
	if best == "" and losses >= int(h.get("stuck", {}).get("after", 99)):
		best = "Mission control: " + str(h["stuck"]["text"])
	if best == "" and own_count == 1 and losses == 1:
		best = str(h.get("first_loss", ""))
	return best
