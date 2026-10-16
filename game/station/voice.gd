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
	out.append([end, final_line(dive, serial, history)])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out


## The last transmission: what this Robbie says as its burst fires.
static func final_line(dive: Dive, serial: int, history: Dictionary) -> String:
	var w := dive.world
	if w.result == World.Result.EXIT:
		return pick("exit", serial)
	if history.get("prev_cause", "") == w.cause and w.cause != "" and serial % 2 == 0:
		return pick("same_death", serial, history)
	return pick("last_" + w.cause, serial)


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
