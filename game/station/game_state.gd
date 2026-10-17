class_name GameState
extends RefCounted
## Everything the station remembers: each room's program, every Robbie sent,
## survey results, and the map assembled from every transmission.
## Dives are stored as inputs (program text + seed) and re-simulated on demand.

const ROOMS := ["dark", "jellyfish", "valve"]
const SAVE_PATH := "user://robbie_save.json"
const STARTER := "move_towards beacon\n"
const SURVEY_FIRST_SEED := 101

var next_serial := 1
var persist := true   # tests turn this off so they never touch the player's save
var rooms := {}   # id -> RoomState


class RoomState:
	var id := ""
	var room: Room
	var program_text := GameState.STARTER
	var dives: Array = []        # Dictionaries, oldest first
	var certified := false
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
	var o := dive.run()
	var entry := {
		"serial": serial, "seed": seed_v, "text": program.to_text(), "result": o["result"],
		"cause": o["cause"], "seconds": o["seconds"], "cpu": program.cpu(), "survey": false,
		"last_words": Voice.last_words(dive, serial, history),
		"seen": Marshalls.raw_to_base64(dive.world.seen),
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
	var rs := room_state(id)
	var report := Survey.run(rs.room, program, Survey.FLEET, SURVEY_FIRST_SEED)
	rs.survey = report
	if report["certified"]:
		rs.certified = true
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
	d.run()
	return d


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
	var data := {"version": 1, "next_serial": next_serial, "rooms": {}}
	for id in ROOMS:
		var rs := room_state(id)
		data["rooms"][id] = {"program": rs.program_text, "dives": rs.dives, "certified": rs.certified,
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
		rs.survey = s.get("survey", {})
		var mem := Marshalls.base64_to_raw(str(s.get("memory", "")))
		if mem.size() == rs.memory.size():
			rs.memory = mem


func reset() -> void:
	next_serial = 1
	for id in ROOMS:
		var rs := room_state(id)
		rs.program_text = STARTER
		rs.dives = []
		rs.certified = false
		rs.survey = {}
		rs.memory.fill(0)
	save()
