extends Node
## Plays the console with pointer events only (taps and drags at screen positions, as a
## finger would), checking that every machine answers. Prints PASS/FAIL per step and
## quits with the number of failures.
##   xvfb-run -a godot --path game --rendering-driver opengl3 --audio-driver Dummy res://tools/console_play.tscn

var c: Control
var steps: Array = []
var fails := 0
var wait := 0
var _checks := 0
var _busy := false


func _ready() -> void:
	c = load("res://console/console.tscn").instantiate()
	c.state.save_path = "user://console_play.json"
	c.state.persist = false
	add_child(c)
	c.state.reset()
	c._select_sector("dark")
	steps = [
		["wait", 10],
		["tap", _tube], ["check", "the tube opens a memo", func() -> bool: return c.memo.visible],
		["tap_at", Vector2(80, 650)], ["check", "tapping outside files the memo", func() -> bool: return not c.memo.visible],
		["tap_at", Vector2(1212, 392)], ["check", "the cover lifts", func() -> bool: return c.dispatch.armed],
		["drag", _lever, Vector2(110, 0)], ["check", "pulling the lever dispatches Robbie 001", func() -> bool: return c.state.next_serial == 2],
		["check", "the scope shows his dive", func() -> bool: return c.scope.has_dive()],
		["check", "the teleprinter has lines", func() -> bool: return c.teleprinter.lines.size() > 2],
		["drag", _drum_centre, Vector2(0, -34)], ["check", "rolling the order drum moves it on", func() -> bool: return c.keypunch.order_drum.index == 1],
		["tap", _drum_lower], ["check", "tapping below the line turns it one more", func() -> bool: return c.keypunch.order_drum.index == 2],
		["tap", _drum_upper], ["check", "tapping above turns it back", func() -> bool: return c.keypunch.order_drum.index == 1],
		["drag", _punch_knob, Vector2(0, 170)], ["check", "pulling PUNCH adds a card", func() -> bool: return c.program.rules.size() == 2],
		["check", "the new card is FOLLOW WALL LEFT", func() -> bool: return c.program.rules[1]["action"] == "follow_wall" and c.program.rules[1]["param"] == "left"],
		["drag", _card0, _to_bin], ["check", "dragging card 1 into SPOILED bins it", func() -> bool: return c.program.rules.size() == 1 and c.program.rules[0]["action"] == "follow_wall"],
		["check", "the gauge reads the new deck", func() -> bool: return c.gauge.used == 3],
		["drag", _lever, Vector2(110, 0)], ["check", "a second dispatch: Robbie 002", func() -> bool: return c.state.next_serial == 3],
		["check", "Robbie 002 reaches the beacon", func() -> bool: return c.current_entry.get("result", "") == "exit"],
		["drag", _reel, Vector2(0, 40)], ["check", "turning a reel scrubs the wire", func() -> bool: return not c.scope.replay.playing and c._scrubbed],
		["tap", _tape_line], ["check", "tapping a tape line winds the wire there", func() -> bool: return c.scope.replay.view.t < c.current_dive.rec.ticks - 1],
		["tap", _key_loss], ["check", "TO THE LOSS winds to the last seconds", func() -> bool: return c.scope.replay.view.t >= c.current_dive.rec.ticks - 95],
		["tap", _speed_knob], ["check", "the speed knob turns off AUTO", func() -> bool: return not c.scope.replay.auto],
		["tap", _crank], ["check", "cranking sends the sea trials", func() -> bool: return c.survey_run != null],
		["await_trials"], ["check", "The Dark is certified", func() -> bool: return c.state.room_state("dark").certified],
		["wait", 30], ["tap", _tube], ["check", "the tally arrives by tube", func() -> bool: return c.memo.visible and c.memo.memo.get("kind", "") == "tally"],
		["tap", _file_it], ["check", "FILE IT puts it away", func() -> bool: return not c.memo.visible],
		["tap", _sector2], ["check", "the dial turns to The Jellyfish", func() -> bool: return c.room_id == "jellyfish"],
		["tap", _card0], ["check", "tapping a card loads it into the keypunch", func() -> bool: return c.keypunch.replace == 0],
		["tap", _binder], ["check", "the binder opens", func() -> bool: return c.memo.visible and c.memo.memo.get("kind", "") == "binder"],
		["tap_at", Vector2(40, 40)], ["check", "and closes", func() -> bool: return not c.memo.visible],
		["tap", _wall], ["check", "the Wall opens", func() -> bool: return c.wall.visible],
		["tap_at", Vector2(1170, 40)], ["check", "BACK TO THE DESK closes it", func() -> bool: return not c.wall.visible],
		["tap_at", Vector2(300, 200)], ["wait", 20], ["check", "tapping the scope magnifies it", func() -> bool: return c.magnified and c.scope.size.x > 1200],
		["tap_at", Vector2(640, 360)], ["wait", 20], ["check", "and tapping again puts it back", func() -> bool: return not c.magnified and c.scope.size.x < 700],
		["done"],
	]


func _tube() -> Vector2:
	return Desk.r("tube_window").get_center()

func _lever() -> Vector2:
	return c.dispatch._knob() + c.dispatch.position

func _drum_centre() -> Vector2:
	return Desk.r("order_drum").get_center()

func _drum_lower() -> Vector2:
	return Desk.r("order_drum").get_center() + Vector2(0, 40)

func _drum_upper() -> Vector2:
	return Desk.r("order_drum").get_center() + Vector2(0, -40)

func _punch_knob() -> Vector2:
	return c.keypunch._knob_pos() + c.keypunch.position

func _card0() -> Vector2:
	return c.rack.card_rect(0).get_center() + c.rack.position

func _to_bin() -> Vector2:
	return Desk.r("bin").get_center() - _card0()

func _reel() -> Vector2:
	return Desk.r("reel_a").get_center() + Vector2(30, 0)

func _tape_line() -> Vector2:
	var p := Desk.r("paper")
	return Vector2(p.position.x + 120, p.end.y - 26 - 17 * 2 - 6)

func _key_loss() -> Vector2:
	return c.recorder._key_rect(3).get_center() + c.recorder.position

func _speed_knob() -> Vector2:
	return Desk.r("speed_knob").get_center()

func _crank() -> Vector2:
	return Vector2(Desk.v("crank")[0], Desk.v("crank")[1])

func _file_it() -> Vector2:
	return c.memo.paper.get_global_transform() * c.memo._file_rect().get_center()

func _sector2() -> Vector2:
	return c.dial._label_pos(1) + c.dial.position

func _binder() -> Vector2:
	return Desk.r("binder").get_center()

func _wall() -> Vector2:
	return Desk.r("wall").get_center()


func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e)


func _move(pos: Vector2, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)


func _process(_d: float) -> void:
	if _busy:
		return
	if wait > 0:
		wait -= 1
		return
	if steps.is_empty():
		return
	var s: Array = steps.pop_front()
	match s[0]:
		"wait":
			wait = s[1]
		"tap", "tap_at":
			var p: Vector2 = (s[1] as Callable).call() if s[0] == "tap" else s[1]
			_busy = true
			_mouse(p, true)
			await get_tree().process_frame
			_mouse(p, false)
			_busy = false
			wait = 3
		"drag":
			var p0: Vector2 = (s[1] as Callable).call()
			var d: Vector2 = s[2].call() if s[2] is Callable else s[2]
			_busy = true
			_mouse(p0, true)
			await get_tree().process_frame
			for i in range(1, 11):
				_move(p0 + d * i / 10.0, d / 10.0)
				await get_tree().process_frame
			_mouse(p0 + d, false)
			_busy = false
			wait = 4
		"await_trials":
			if c.survey_run != null:
				steps.push_front(["await_trials"])
		"check":
			_checks += 1
			var ok: bool = (s[2] as Callable).call()
			print("%s  %s" % ["PASS" if ok else "FAIL", s[1]])
			if not ok:
				fails += 1
		"done":
			print("console_play: %d checks, %d failed" % [_checks, fails])
			get_tree().quit(fails)
