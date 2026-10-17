extends TestCase
## The whole design rests on this: same inputs, same dive, every time.


func _dive(room_id: String, text: String, seed_v: int, calm := false) -> Dive:
	var d := Dive.new(RoomLibrary.load_room(room_id), Program.parse(text), seed_v, calm)
	d.run()
	return d


func test_same_inputs_same_dive() -> void:
	for room_id in ["dark", "jellyfish", "valve"]:
		var a := _dive(room_id, "keep_distance 2\nshoot if hostile_near 4\nfollow_wall left", 7)
		var b := _dive(room_id, "keep_distance 2\nshoot if hostile_near 4\nfollow_wall left", 7)
		eq(a.rec.hashes, b.rec.hashes, "%s: hash timeline" % room_id)
		eq(a.outcome(), b.outcome(), "%s: outcome" % room_id)


func test_seeds_change_the_weather() -> void:
	var a := _dive("jellyfish", "lamp off\nkeep_distance 2\nmove_towards beacon", 1)
	var b := _dive("jellyfish", "lamp off\nkeep_distance 2\nmove_towards beacon", 2)
	check(a.rec.hashes != b.rec.hashes, "different seeds give different jellyfish")


func test_calm_ignores_the_seed() -> void:
	var a := _dive("valve", "keep_distance 4\nstop if valve_shut\nmove_towards beacon", 1, true)
	var b := _dive("valve", "keep_distance 4\nstop if valve_shut\nmove_towards beacon", 99, true)
	eq(a.rec.hashes, b.rec.hashes, "calm dives are identical whatever the seed")


func test_recording_covers_every_tick() -> void:
	var d := _dive("dark", "follow_wall left", 1)
	eq(d.rec.ticks, d.world.tick, "one snapshot per tick")
	eq(d.rec.rx.size(), d.world.tick, "robbie channel length")


func test_recording_senses_changes_nothing() -> void:
	var room := RoomLibrary.load_room("valve")
	var prog := Program.parse("keep_distance 4\nstop if valve_shut\nmove_towards beacon")
	var plain := Dive.new(room, prog, 3)
	var a := plain.run()
	var watched := Dive.new(room, prog, 3)
	watched.vm.record_senses = true
	var b := watched.run()
	eq(b["final_hash"], a["final_hash"], "reading the senses for the Why? panel never changes a dive")
	check(watched.vm.trace[0].has("senses") and not plain.vm.trace[0].has("senses"), "senses only when asked")
	var lines := DiveText.senses(room, watched.vm.trace[watched.vm.trace.size() - 1])
	check(lines.size() == 4, "valve room: wall, hostile, valve, energy (got %d)" % lines.size())
