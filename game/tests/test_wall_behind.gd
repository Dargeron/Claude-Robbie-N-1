extends TestCase
## "wall behind": Robbie feels rock behind it, in the direction keep_distance backs away.


func test_wall_behind_is_the_mirror_of_wall_ahead() -> void:
	var w := World.new(RoomLibrary.load_room("dark"), 1)
	# One tile in from the west wall of The Dark, facing east: rock behind, water ahead.
	w.robbie.x = Fx.TILE + Fx.TILE / 2
	w.robbie.y = 2 * Fx.TILE + Fx.TILE / 2
	w.robbie.angle = Fx.from_deg(90)
	check(w.wall_behind(), "rock behind when facing away from the west wall")
	check(not w.wall_ahead(), "open water ahead")
	w.robbie.angle = Fx.from_deg(270)
	check(w.wall_ahead(), "facing the wall: rock ahead")
	check(not w.wall_behind(), "...and water behind")


func test_the_condition_parses_and_costs_one() -> void:
	var p := Program.parse("keep_distance 2 if not wall_behind")
	check(p.is_valid(), "parses: %s" % [p.errors])
	eq(p.cpu(), 3 + 1 + 1 + 1, "keep distance 3, if 1, not 1, wall behind 1")
