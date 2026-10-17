extends TestCase
## AUTO playback: fast through quiet water, normal speed around events.


func test_auto_slows_down_around_events() -> void:
	var d := Dive.new(RoomLibrary.load_room("valve"), Program.parse("keep_distance 4\nstop if valve_shut\nmove_towards beacon"), 1)
	d.run()
	var s := ReplayPlayer.plan_auto_speeds(d, [])
	eq(s.size(), d.rec.ticks, "one speed per tick")
	var wake := -1
	for e in d.world.events:
		if e["type"] == "lurker_wakes":
			wake = int(e["t"])
			break
	check(wake > 0, "the lurker wakes in this dive")
	check(absf(s[wake] - ReplayPlayer.AUTO_SLOW) < 0.01, "normal speed when the lurker wakes (got %.2f)" % s[wake])
	check(absf(s[d.rec.ticks - 1] - ReplayPlayer.AUTO_SLOW) < 0.01, "normal speed at the end")
	var fastest := 0.0
	for k in s.size():
		fastest = maxf(fastest, s[k])
	check(fastest > 3.9, "somewhere it skims at full speed (max %.2f)" % fastest)
	for k in range(1, s.size()):
		if absf(s[k] - s[k - 1]) > ReplayPlayer.AUTO_RAMP + 0.001:
			failures.append("speed jumps at tick %d: %.2f -> %.2f" % [k, s[k - 1], s[k]])
			break
