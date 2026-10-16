class_name Survey
extends RefCounted
## The survey fleet (plan, decision 3): once a Robbie reaches the exit, the same
## program dives on FLEET fresh seeds. The level is certified when PASS_NEEDED make it.

const FLEET := 10
const PASS_NEEDED := 8


static func run(room: Room, program: Program, fleet: int = FLEET, first_seed: int = 1) -> Dictionary:
	var passed := 0
	var dives: Array[Dictionary] = []
	for s in range(first_seed, first_seed + fleet):
		var d := Dive.new(room, program, s)
		var o := d.run()
		if o["result"] == "exit":
			passed += 1
		dives.append({"seed": s, "result": o["result"], "cause": o["cause"], "seconds": o["seconds"]})
	var needed := (fleet * PASS_NEEDED + FLEET - 1) / FLEET
	return {
		"room": room.id,
		"cpu": program.cpu(),
		"fleet": fleet,
		"passed": passed,
		"needed": needed,
		"certified": passed >= needed,
		"dives": dives,
	}
