extends TestCase
## The Lab's parts do what the catalogue says, and a hull with none is the stock hull every room
## was tuned for (docs/design/lab-parts-and-pay.md).


func _dive(room_id: String, text: String, parts: Array, seed_v := 1) -> Dive:
	var d := Dive.new(RoomLibrary.load_room(room_id), Program.parse(text), seed_v, false, Kit.from_parts(parts))
	d.run()
	return d


func test_stock_kit_changes_nothing() -> void:
	var room := RoomLibrary.load_room("dark")
	var p := Program.parse("follow_wall left")
	var a := Dive.new(room, p, 1).run()
	var b := Dive.new(room, p, 1, false, Kit.from_parts([])).run()
	eq(a["final_hash"], b["final_hash"], "an empty kit is the stock hull")
	check(Kit.stock().is_stock(), "stock has no parts")


func test_one_part_per_socket() -> void:
	var k := Kit.from_parts(["spotlight", "red_lamp", "plating", "nonsense"])
	eq(k.to_text(), "plating,spotlight", "the second lamp and an unknown part are dropped")
	eq(Kit.from_text(k.to_text()).to_text(), k.to_text(), "round trip through text")


func test_numbers() -> void:
	eq(Kit.from_parts(["plating"]).hp, 5, "plating: two more knocks")
	check(Kit.from_parts(["plating"]).speed < Kit.stock().speed, "plating is heavy")
	var d := _dive("dark", "stop", ["battery_bank"])
	eq(d.world.energy_max, RoomLibrary.load_room("dark").energy * 140 / 100, "battery bank: 40% more charge")
	check(Kit.from_parts(["spotlight"]).lamp_range > Kit.stock().lamp_range, "the spotlight reaches further")
	check(Kit.from_parts(["floodlight"]).lamp_half > Kit.stock().lamp_half, "the floodlight is wider")


func test_reserve_cell_gives_a_second_wind() -> void:
	var plain := _dive("dark", "stop", [])
	var spare := _dive("dark", "stop", ["reserve_cell"])
	check(spare.world.tick > plain.world.tick, "a stopped Robbie lasts longer with a reserve cell")
	var found := false
	for e in spare.world.events:
		found = found or e["type"] == "reserve"
	check(found, "the reserve cell kicks in, once")


func test_silent_fins_against_the_listeners() -> void:
	# Swimming straight down the corridor: the eels hear the stock pods, not the fins.
	var loud := _dive("listeners", "move_towards beacon", [], 201)
	var quiet := _dive("listeners", "move_towards beacon", ["silent_fins"], 201)
	var heard_loud := 0
	var heard_quiet := 0
	for e in loud.world.events:
		if e["type"] == "eel_hears":
			heard_loud += 1
	for e in quiet.world.events:
		if e["type"] == "eel_hears":
			heard_quiet += 1
	check(heard_loud > 0, "the eels hear the stock hull")
	eq(heard_quiet, 0, "and never the silent fins")


func test_lost_beacon_is_recovered_and_counts_after_a_loss() -> void:
	var d := _dive("dark", "follow_wall right", [])
	check(d.world.result != World.Result.EXIT, "the right hand doesn't get out")
	check(d.bonuses_taken().has(0), "but it passes the bottom cave's lost beacon")


func test_shellback_is_harmless_until_shot() -> void:
	var calm := _dive("jellyfish", "lamp off\nfollow_wall right", ["plating"], 101)
	for e in calm.world.events:
		check(e["type"] != "shell_angry", "left alone, it stays calm")
	var shot := _dive("jellyfish", "shoot if hostile_near 4\nfollow_wall right", [], 101)
	var angry := false
	for e in shot.world.events:
		angry = angry or e["type"] == "shell_angry"
	check(angry, "shot, it comes for him")


func test_turn_is_a_quarter() -> void:
	var room := RoomLibrary.load_room("jellyfish")
	var d := Dive.new(room, Program.parse("turn left\nstop"), 1)
	var start := d.world.robbie.angle
	d.world.apply(d.vm.think(d.world))
	for i in World.TURN_HOLD:
		d.world.step()
	eq(Fx.angle_diff(start, d.world.robbie.angle), -Fx.QUARTER, "turn left turns a quarter to the left")


func test_flares_draw_jellyfish() -> void:
	var d := _dive("jellyfish", "lamp off\ndrop_flare if hostile_near 4\nmove_towards beacon", ["flares"], 101)
	var dropped := 0
	for e in d.world.events:
		if e["type"] == "flare":
			dropped += 1
	check(dropped >= 1 and dropped <= Kit.FLARE_COUNT, "flares are dropped, no more than he carries (%d)" % dropped)


func test_new_conditions_parse_and_cost() -> void:
	var p := Program.parse("move_towards beacon if beacon_seen\nturn right if stuck\nstop if hit\nstop if heard\nfollow_wall left")
	check(p.is_valid(), "the new cards parse: %s" % str(p.errors))
	eq(p.rule_cpu(p.rules[0]), 2 + 1 + 2, "beacon in sight costs 2")
