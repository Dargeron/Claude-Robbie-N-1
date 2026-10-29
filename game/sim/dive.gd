class_name Dive
extends RefCounted
## One complete dive: a room, a program and a seed, run to the end.
## This is the only entry point the game, the replay and the tools use.

var room: Room
var program: Program
var world: World
var vm: Vm
var rec: Recorder
var seed_value := 0
var calm := false
var kit: Kit


func _init(r: Room, p: Program, seed_v: int, calm_v: bool = false, kit_v: Kit = null) -> void:
	room = r
	program = p
	seed_value = seed_v
	calm = calm_v
	kit = kit_v if kit_v != null else Kit.stock()
	world = World.new(r, seed_v, calm_v, kit)
	vm = Vm.new(p)
	rec = Recorder.new(world)


func run() -> Dictionary:
	while world.result == World.Result.RUNNING:
		if world.commit == 0 and world.hold == 0 and world.tick % World.THINK_EVERY == 0:
			world.apply(vm.think(world))
		world.step()
		rec.capture(world)
	return outcome()


func outcome() -> Dictionary:
	var chosen := {}
	for t in vm.trace:
		var k := str(t["rule"] + 1) if t["rule"] >= 0 else "none"
		chosen[k] = chosen.get(k, 0) + 1
	var damage := 0
	for e in world.events:
		if e["type"] == "damage":
			damage += 1
	return {
		"room": room.id,
		"seed": seed_value,
		"calm": calm,
		"result": World.result_name(world.result),
		"cause": world.cause,
		"ticks": world.tick,
		"seconds": "%d.%d" % [world.tick / World.TICKS_PER_SECOND, (world.tick % World.TICKS_PER_SECOND) * 10 / World.TICKS_PER_SECOND],
		"hp": world.robbie.hp,
		"energy": world.energy,
		"cpu": program.cpu(),
		"cpu_budget": room.cpu_budget,
		"explored": world.seen_count,
		"hits_taken": damage,
		"rules_chosen": chosen,
		"final_hash": world.state_hash(),
		"bonus": bonuses_taken(),
	}


## The lost beacons this Robbie recovered (indices into room.bonuses).
func bonuses_taken() -> Array[int]:
	var out: Array[int] = []
	for i in world.bonus_taken.size():
		if world.bonus_taken[i] == 1:
			out.append(i)
	return out


func succeeded() -> bool:
	return world.result == World.Result.EXIT
