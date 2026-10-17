class_name Survey
extends RefCounted
## The survey fleet (plan, decision 3): once a Robbie reaches the exit, the same
## program dives on FLEET fresh seeds. The level is certified when PASS_NEEDED make it.
##
## Block 13: 20 dives with 16 needed (was 10 with 8). With ten, a program that only
## gets through about half the time could pass on lucky seeds; with twenty it can't.
## Survey.Run lets the station send the fleet a few dives per frame, with progress.

const FLEET := 20
const PASS_NEEDED := 16
const FIRST_SEED := 1001  # the survey's own seeds; practice dives use 1, 101, 201... (GameState.iterate_seed)


static func run(room: Room, program: Program, fleet: int = FLEET, first_seed: int = FIRST_SEED) -> Dictionary:
	var r := Run.new(room, program, fleet, first_seed)
	while not r.step():
		pass
	return r.report()


## Just the verdict, stopping as soon as it is decided (for tests and tools).
static func certifies(room: Room, program: Program) -> bool:
	var r := Run.new(room, program)
	var needed := needed_for(r.fleet)
	while not r.step():
		if r.passed >= needed:
			return true
		if r.dives.size() - r.passed > r.fleet - needed:
			return false
	return r.passed >= needed


static func needed_for(fleet: int) -> int:
	return (fleet * PASS_NEEDED + FLEET - 1) / FLEET


## One survey in progress: step() sends the next Robbie and returns true when all are back.
class Run:
	var room: Room
	var program: Program
	var fleet := FLEET
	var first_seed := FIRST_SEED
	var passed := 0
	var dives: Array[Dictionary] = []

	func _init(r: Room, p: Program, n: int = FLEET, first: int = FIRST_SEED) -> void:
		room = r
		program = p
		fleet = n
		first_seed = first

	func done() -> bool:
		return dives.size() >= fleet

	func step() -> bool:
		if done():
			return true
		var s := first_seed + dives.size()
		var o := Dive.new(room, program, s).run()
		if o["result"] == "exit":
			passed += 1
		dives.append({"seed": s, "result": o["result"], "cause": o["cause"], "seconds": o["seconds"]})
		return done()

	func report() -> Dictionary:
		var needed := Survey.needed_for(fleet)
		return {
			"room": room.id,
			"cpu": program.cpu(),
			"fleet": fleet,
			"passed": passed,
			"needed": needed,
			"certified": passed >= needed,
			"dives": dives,
		}
