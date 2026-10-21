extends TestCase
## The replay shows only what Robbie could sense (Albert's note #11). It decides that from
## the recording with World.sensed_from(); this checks it agrees with the sim's own
## sensed() on every tick of real dives, for every creature.


func _agree(room_id: String, program: String, seed_v: int) -> void:
	var d := Dive.new(RoomLibrary.load_room(room_id), Program.parse(program), seed_v)
	var w := d.world
	var rec := d.rec
	var checked := 0
	var seen := 0
	while w.result == World.Result.RUNNING:
		if w.commit == 0 and w.tick % World.THINK_EVERY == 0:
			w.apply(d.vm.think(w))
		w.step()
		rec.capture(w)
		var k := rec.ticks - 1
		var lamp := (rec.rflags[k] & 1) == 1
		for i in w.bodies.size():
			var b := w.bodies[i]
			if not b.alive:
				continue
			var st := rec.bstate[i][k]
			var from_rec := w.sensed_from(rec.rx[k], rec.ry[k], rec.ra[k], lamp, rec.gate[k],
				rec.bx[i][k], rec.by[i][k], b.kind, (st >> 1) & 0x7f, (st & 256) != 0)
			if from_rec != w.sensed(b):
				failures.append("%s seed %d tick %d body %d (%s): sim says %s, recording says %s"
					% [room_id, seed_v, k, i, b.kind_name(), w.sensed(b), from_rec])
				return
			checked += 1
			if from_rec:
				seen += 1
	check(checked > 0, "%s: some creatures were checked" % room_id)
	check(seen > 0, "%s: Robbie sensed something at some point" % room_id)


func test_jellyfish() -> void:
	_agree("jellyfish", "move_towards beacon", 1)
	_agree("jellyfish", "lamp off\nkeep_distance 2\nmove_towards beacon", 2)


func test_valve() -> void:
	_agree("valve", "keep_distance 4\nstop if valve_shut\nmove_towards beacon", 1)


func test_listeners_and_nursery() -> void:
	_agree("listeners", "stop if hostile_near 4\nmove_towards beacon", 1)
	_agree("nursery", "shoot\nfollow_wall left", 1)
