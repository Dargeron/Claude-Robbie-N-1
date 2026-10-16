extends TestCase


func test_parse_and_cost() -> void:
	var p := Program.parse("keep_distance 4\nstop if valve_shut\nmove_towards beacon\n")
	check(p.is_valid(), "valid program: %s" % str(p.errors))
	eq(p.rules.size(), 3, "three rules")
	eq(p.cpu(), 3 + (1 + 1 + 2) + 2, "cpu cost")


func test_negation_and_params() -> void:
	var p := Program.parse("move 90 if not hostile_near 4  # comment\nlamp off")
	check(p.is_valid(), "valid: %s" % str(p.errors))
	eq(p.rules[0]["negate"], true, "negated")
	eq(p.rules[0]["cond_param"], "4", "condition parameter")
	eq(p.cpu(), 1 + 1 + 1 + 2 + 1, "cost includes not")


func test_errors_are_explained() -> void:
	var p := Program.parse("fly 90\nmove\nkeep_distance 5\nstop if teleport\nmove 90 when wall_ahead\nfollow_wall left if executing 9")
	eq(p.errors.size(), 6, "six bad lines: %s" % str(p.errors))
	check(p.errors[0].find("unknown order") >= 0, "unknown order message")


func test_round_trip_text() -> void:
	var src := "keep_distance 2\nlamp off\nmove_towards beacon if not hostile_near 6\n"
	eq(Program.parse(src).to_text(), src, "to_text round trip")


func test_labels() -> void:
	var p := Program.parse("move_towards open_water if energy_below 25\nmove 90\nkeep_distance 2 if not valve_open")
	eq(p.rule_label(p.rules[0]), "Move towards open water if energy below 25%", "label 0")
	eq(p.rule_label(p.rules[1]), "Move 90°", "label 1")
	eq(p.rule_label(p.rules[2]), "Keep distance from hostile 2 tiles if not valve is open", "label 2")
