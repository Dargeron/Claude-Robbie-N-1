class_name Golden
extends RefCounted
## Golden replays: recorded outcomes of reference programs. If the simulation
## changes behaviour, these fail and say at which second the dives diverge.
## Re-approve deliberate changes with tools/bless.sh and explain why in the commit.

const DIR := "res://content/golden"
const PROGRAM_DIR := "res://content/programs"
const SEEDS := [1, 2]


static func program_paths() -> Array[String]:
	var out: Array[String] = []
	for room_dir in DirAccess.get_directories_at(PROGRAM_DIR):
		for f in DirAccess.get_files_at(PROGRAM_DIR + "/" + room_dir):
			if f.ends_with(".rbt"):
				out.append("%s/%s/%s" % [PROGRAM_DIR, room_dir, f])
	out.sort()
	return out


static func record(room_id: String, program_path: String, seed_v: int) -> Dictionary:
	var dive := Dive.new(RoomLibrary.load_room(room_id), ProgramFiles.load_program(program_path), seed_v)
	var o := dive.run()
	return {
		"room": room_id,
		"program": program_path.trim_prefix(PROGRAM_DIR + "/"),
		"seed": seed_v,
		"result": o["result"],
		"cause": o["cause"],
		"ticks": o["ticks"],
		"final_hash": o["final_hash"],
		"hashes": Array(dive.rec.hashes),
	}


static func file_for(program_path: String, seed_v: int) -> String:
	var rel := program_path.trim_prefix(PROGRAM_DIR + "/").trim_suffix(".rbt").replace("/", "__")
	return "%s/%s__s%d.json" % [DIR, rel, seed_v]
