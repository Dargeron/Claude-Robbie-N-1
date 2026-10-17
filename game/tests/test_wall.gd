extends TestCase
## The Wall of Robbies lists every Robbie, newest first, and keeps the score per room.


func _state() -> GameState:
	var s := GameState.new()
	s.persist = false
	return s


func test_plaques_newest_first_with_survey_after_its_robbie() -> void:
	var s := _state()
	s.launch("dark", Program.parse("move_towards beacon"))            # Robbie 1, lost
	s.launch("jellyfish", Program.parse("move_towards beacon"))       # Robbie 2, lost
	s.launch("dark", Program.parse("move_towards beacon\nfollow_wall left"))  # Robbie 3
	s.survey("dark", Program.parse("move_towards beacon"))            # ten survey Robbies, all lost
	var items := RobbieWall.plaques(s)
	eq(items.size(), 13, "3 launched + 10 lost survey Robbies")
	var first: Dictionary = items[0]["entry"]
	check(first.get("survey", false), "the latest survey losses come first")
	var own: Array = items.filter(func(it): return not it["entry"].get("survey", false))
	eq(own.map(func(it): return int(it["entry"]["serial"])), [3, 2, 1], "own Robbies newest first")
	eq(items[10]["entry"]["serial"], 3, "the survey sits just after the Robbie before it")


func test_room_summary_counts_losses() -> void:
	var s := _state()
	s.launch("dark", Program.parse("move_towards beacon"))
	s.launch("dark", Program.parse("follow_wall left"))
	var sm := RobbieWall.room_summary(s, "dark")
	eq(sm["sent"], 2, "two Robbies")
	eq(sm["lost"], 1, "one lost")
	eq(sm["first_exit"], 2, "Robbie 002 got through first")
	eq(RobbieWall.room_summary(s, "valve")["sent"], 0, "nothing sent to The Valve")


func test_ghost_is_the_previous_robbie_in_the_room() -> void:
	var s := _state()
	var a: Dictionary = s.launch("dark", Program.parse("move_towards beacon"))["entry"]
	s.launch("valve", Program.parse("move_towards beacon"))
	var b: Dictionary = s.launch("dark", Program.parse("follow_wall left"))["entry"]
	eq(s.ghost_for("dark", a), {}, "the first Robbie has no ghost")
	var g := s.ghost_for("dark", b)
	eq(g.get("serial", -1), 1, "Robbie 003's ghost is Robbie 001, not the Valve's 002")
	check(g.get("lost", false), "Robbie 001 was lost")
	var path: PackedVector2Array = g["path"]
	var d := s.redive("dark", a)
	eq(path[0], Vector2(d.rec.rx[0] / Fx.ONE, d.rec.ry[0] / Fx.ONE), "the path starts where Robbie started")
	eq(path[path.size() - 1], Vector2(d.rec.rx[d.rec.ticks - 1] / Fx.ONE, d.rec.ry[d.rec.ticks - 1] / Fx.ONE), "and ends where it was lost")
