class_name GameState
extends RefCounted
## Everything the station remembers: each room's program, every Robbie sent,
## survey results, and the map assembled from every transmission.
## Dives are stored as inputs (program text + seed) and re-simulated on demand.

const ROOMS := ["dark", "jellyfish", "nursery", "valve", "listeners"]
const SAVE_PATH := "user://robbie_save.json"
const STARTER := "move_towards beacon\n"
const SURVEY_FIRST_SEED := Survey.FIRST_SEED

var next_serial := 1
var coach_done := false   # the first-visit guidance has been walked through
var persist := true   # tests turn this off so they never touch the player's save
var rooms := {}   # id -> RoomState


class RoomState:
	var id := ""
	var room: Room
	var program_text := GameState.STARTER
	var dives: Array = []        # Dictionaries, oldest first
	var certified := false
	var best_cpu := -1           # cheapest program that certified here, -1 = none yet
	var survey := {}
	var memory := PackedByteArray()


func _init() -> void:
	for id in ROOMS:
		var rs := RoomState.new()
		rs.id = id
		rs.room = RoomLibrary.load_room(id)
		rs.memory.resize(rs.room.w * rs.room.h)
		rooms[id] = rs


func room_state(id: String) -> RoomState:
	return rooms[id]


## "Same conditions while you iterate": one fixed seed per room.
func iterate_seed(id: String) -> int:
	return 1 + ROOMS.find(id) * 100


func own_dives(id: String) -> Array:
	return room_state(id).dives.filter(func(e): return not e.get("survey", false))


func launch(id: String, program: Program) -> Dictionary:
	var rs := room_state(id)
	var serial := next_serial
	next_serial += 1
	var history := history_for(id)
	var seed_v := iterate_seed(id)
	var dive := Dive.new(rs.room, program, seed_v)
	dive.vm.record_senses = true
	var o := dive.run()
	var entry := {
		"serial": serial, "seed": seed_v, "text": program.to_text(), "result": o["result"],
		"cause": o["cause"], "seconds": o["seconds"], "cpu": program.cpu(), "survey": false,
		"last_words": Voice.last_words(dive, serial, history),
		"seen": Marshalls.raw_to_base64(dive.world.seen),
		"path": GameState.encode_path(dive),
	}
	rs.program_text = program.to_text()
	rs.dives.append(entry)
	_remember(rs, dive)
	save()
	return {"entry": entry, "dive": dive, "history": history}


func history_for(id: String) -> Dictionary:
	var own := own_dives(id)
	if own.is_empty():
		return {}
	var last: Dictionary = own.back()
	return {"prev_serial": last["serial"], "prev_cause": last["cause"]}


func survey(id: String, program: Program) -> Dictionary:
	return finish_survey(id, program, Survey.run(room_state(id).room, program, Survey.FLEET, SURVEY_FIRST_SEED))


## Record a finished survey (run all at once by survey(), or a few dives per frame by the station).
func finish_survey(id: String, program: Program, report: Dictionary) -> Dictionary:
	var rs := room_state(id)
	rs.survey = report
	if report["certified"]:
		rs.certified = true
		if rs.best_cpu < 0 or program.cpu() < rs.best_cpu:
			rs.best_cpu = program.cpu()
	var text := program.to_text()
	for d in report["dives"]:
		if d["result"] != "exit":
			rs.dives.append({"serial": -1, "seed": d["seed"], "text": text, "result": d["result"],
				"cause": d["cause"], "seconds": d["seconds"], "cpu": program.cpu(), "survey": true,
				"last_words": ""})
	save()
	return report


func redive(id: String, entry: Dictionary) -> Dive:
	var d := Dive.new(room_state(id).room, Program.parse(entry["text"]), int(entry["seed"]))
	d.vm.record_senses = true
	d.run()
	return d


## A Robbie's route, kept small for the save file: whole-pixel positions every
## PATH_STEP ticks (and the final one), as signed 16-bit pairs in base64.
const PATH_STEP := 6

static func encode_path(dive: Dive) -> String:
	var rec := dive.rec
	var ticks: Array[int] = []
	for k in range(0, rec.ticks, PATH_STEP):
		ticks.append(k)
	if rec.ticks > 0 and ticks.back() != rec.ticks - 1:
		ticks.append(rec.ticks - 1)
	var b := PackedByteArray()
	b.resize(ticks.size() * 4)
	for i in ticks.size():
		b.encode_s16(i * 4, rec.rx[ticks[i]] / Fx.ONE)
		b.encode_s16(i * 4 + 2, rec.ry[ticks[i]] / Fx.ONE)
	return Marshalls.raw_to_base64(b)


static func decode_path(text: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	if text == "":
		return out
	var b := Marshalls.base64_to_raw(text)
	for i in range(0, b.size() - 3, 4):
		out.append(Vector2(b.decode_s16(i), b.decode_s16(i + 2)))
	return out


## The ghost for a replay: the route of the Robbie sent to this room just before
## this one. Survey Robbies and first Robbies have none.
func ghost_for(id: String, entry: Dictionary) -> Dictionary:
	if entry.get("survey", false):
		return {}
	var own := own_dives(id)
	var at := own.find(entry)
	if at <= 0:
		return {}
	var prev: Dictionary = own[at - 1]
	var path := GameState.decode_path(str(prev.get("path", "")))
	if path.size() < 2:
		return {}
	return {"serial": int(prev["serial"]), "path": path, "lost": prev["result"] != "exit"}


## The cheapest certified program the station's simulator knows for each room
## (content/solver/records.json, written by tools/solver_records.py from solver runs).
static var _records: Dictionary = {}

static func record_cpu(id: String) -> int:
	if _records.is_empty() and FileAccess.file_exists("res://content/solver/records.json"):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/solver/records.json"))
		_records = d if typeof(d) == TYPE_DICTIONARY else {"_": 0}
	return int(_records.get(id, {}).get("cpu", -1))


## Has this exact program reached the exit in this room?
func program_made_it(id: String, text: String) -> bool:
	for e in own_dives(id):
		if e["text"] == text and e["result"] == "exit":
			return true
	return false


## What the station knew about the room before this Robbie dived: the union of
## everything earlier Robbies saw (so a replay never shows its own future path).
func memory_before(id: String, entry: Dictionary) -> PackedByteArray:
	var rs := room_state(id)
	var mem := PackedByteArray()
	mem.resize(rs.room.w * rs.room.h)
	for e in own_dives(id):
		if e == entry or int(e["serial"]) >= int(entry.get("serial", 1 << 30)) and int(entry.get("serial", -1)) > 0:
			break
		var seen := Marshalls.base64_to_raw(str(e.get("seen", "")))
		if seen.size() == mem.size():
			for i in mem.size():
				if seen[i] == 1:
					mem[i] = 1
	return mem


## How many of this room's latest own Robbies were lost to the same cause, and which.
func loss_streak(id: String) -> Array:
	var own := own_dives(id)
	if own.is_empty() or own.back()["result"] == "exit":
		return [0, ""]
	var cause: String = own.back()["cause"]
	var n := 0
	for i in range(own.size() - 1, -1, -1):
		if own[i]["result"] == "exit" or own[i]["cause"] != cause:
			break
		n += 1
	return [n, cause]


func losses_since_success(id: String) -> int:
	var n := 0
	var own := own_dives(id)
	for i in range(own.size() - 1, -1, -1):
		if own[i]["result"] == "exit":
			break
		n += 1
	return n


func _remember(rs: RoomState, dive: Dive) -> void:
	for i in rs.memory.size():
		if dive.world.seen[i] == 1:
			rs.memory[i] = 1


func save() -> void:
	if not persist:
		return
	var data := {"version": 1, "next_serial": next_serial, "coach_done": coach_done, "rooms": {}}
	for id in ROOMS:
		var rs := room_state(id)
		data["rooms"][id] = {"program": rs.program_text, "dives": rs.dives, "certified": rs.certified, "best_cpu": rs.best_cpu,
			"survey": rs.survey, "memory": Marshalls.raw_to_base64(rs.memory)}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	next_serial = int(parsed.get("next_serial", 1))
	# Saves from before the coach existed: anyone who already sent Robbies doesn't need it.
	coach_done = bool(parsed.get("coach_done", next_serial > 1))
	var saved: Dictionary = parsed.get("rooms", {})
	for id in ROOMS:
		if not saved.has(id):
			continue
		var s: Dictionary = saved[id]
		var rs := room_state(id)
		rs.program_text = str(s.get("program", STARTER))
		rs.dives = s.get("dives", [])
		for e in rs.dives:
			e["serial"] = int(e["serial"])
			e["seed"] = int(e["seed"])
		rs.certified = bool(s.get("certified", false))
		rs.best_cpu = int(s.get("best_cpu", rs.survey.get("cpu", -1) if rs.certified else -1))
		rs.survey = s.get("survey", {})
		var mem := Marshalls.base64_to_raw(str(s.get("memory", "")))
		if mem.size() == rs.memory.size():
			rs.memory = mem


func reset() -> void:
	next_serial = 1
	coach_done = false
	for id in ROOMS:
		var rs := room_state(id)
		rs.program_text = STARTER
		rs.dives = []
		rs.certified = false
		rs.best_cpu = -1
		rs.survey = {}
		rs.memory.fill(0)
	save()
