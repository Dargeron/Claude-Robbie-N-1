extends Node
## Plays the console with pointer events only (taps and drags at screen positions, as a
## finger would), checking that every machine answers. Prints PASS/FAIL per step and
## quits with the number of failures.
##   xvfb-run -a godot --path game --rendering-driver opengl3 --audio-driver Dummy res://tools/console_play.tscn

var c: Control
var steps: Array = []
var op: Node = null               # the game root, when playing through a view
var fails := 0
var wait := 0
var _checks := 0
var _busy := false


func _ready() -> void:
	# ROBBIE_VIEW=chair: the same, played through the 3D chair view (positions traced onto its faces).
	if OS.get_environment("ROBBIE_VIEW") == "chair":
		op = load("res://console/operator.tscn").instantiate()
		c = op.console
	else:
		c = load("res://console/console.tscn").instantiate()
	c.state.save_path = "user://console_play.json"
	c.state.persist = false
	add_child(op if op != null else c)
	c.state.reset()
	c._select_sector("dark")
	steps = [
		["wait", 10],
		["tap", _tube], ["check", "the tube opens a memo", func() -> bool: return c.memo.visible],
		["tap_at", Vector2(80, 650)], ["check", "tapping outside files the memo", func() -> bool: return not c.memo.visible],
		["drag", _lever, Vector2(6, 95)], ["wait", 30], ["check", "pulling the chain down dispatches Robbie 001", func() -> bool: return c.state.next_serial == 2],
		["check", "the scope shows his dive", func() -> bool: return c.scope.has_dive()],
		["check", "the teleprinter has lines", func() -> bool: return c.teleprinter.lines.size() > 2],
		["arc", "order_wheel", -90.0, -30.0], ["check", "turning the ORDER wheel by its grip moves it two notches", func() -> bool: return c.press.order_wheel.index == 2],
		["tap", _wheel_left], ["check", "tapping left of the hub turns it back one", func() -> bool: return c.press.order_wheel.index == 1],
		["check", "the board reads FOLLOW WALL LEFT", func() -> bool: return c.press.rule()["action"] == "follow_wall" and c.press.rule()["param"] == "left"],
		["drag", _print_knob, Vector2(0, 170)], ["wait", 150], ["check", "pulling PRINT drops a card in the tray", func() -> bool: return c.table.tray_rules().size() == 1],
		["drag", _slot_card0, _to_chute], ["wait", 40], ["check", "a card dropped in the PULP chute is gone", func() -> bool: return c.table.deck().is_empty()],
		["drag", _tray_card, _to_slot1], ["wait", 20], ["check", "the printed card goes into slot 1", func() -> bool: return c.table.deck().size() == 1 and c.table.deck()[0]["action"] == "follow_wall"],
		["drag", _lever, Vector2(-4, 95)], ["wait", 30], ["check", "a second dispatch: Robbie 002", func() -> bool: return c.state.next_serial == 3],
		["check", "Robbie 002 reaches the beacon", func() -> bool: return c.current_entry.get("result", "") == "exit"],
		["drag", _reel, Vector2(0, 40)], ["check", "turning a reel scrubs the wire", func() -> bool: return not c.scope.replay.playing and c._scrubbed],
		["tap", _tape_line], ["check", "tapping a tape line winds the wire there", func() -> bool: return c.scope.replay.view.t < c.current_dive.rec.ticks - 1],
		["tap", _key_loss], ["check", "TO THE LOSS winds to the last seconds", func() -> bool: return c.scope.replay.view.t >= c.current_dive.rec.ticks - 95],
		["check", "the recorder starts at speed 1 (normal), not AUTO", func() -> bool: return not c.scope.replay.auto and c.scope.replay.speed() == 2.0],
		["tap", _speed_knob], ["check", "tapping the speed knob turns it to 2", func() -> bool: return not c.scope.replay.auto and c.scope.replay.speed() == 4.0],
		["tap", _speed_knob], ["check", "and once more to AUTO", func() -> bool: return c.scope.replay.auto],
		["drag", func() -> Vector2: return _speed_knob() + Vector2(0, -22), Vector2(-22, 32)], ["check", "dragging the speed knob round to ½ sets ½", func() -> bool: return not c.scope.replay.auto and c.scope.replay.speed() == 1.0],
		["tap", _order_drum], ["check", "touching the drum's glass does nothing", func() -> bool: return c.press.order_wheel.index == 1],
		["tap", _crank], ["check", "cranking sends the sea trials", func() -> bool: return c.survey_run != null],
		["await_trials"], ["check", "The Dark is certified", func() -> bool: return c.state.room_state("dark").certified],
		["wait", 30], ["tap", _tube], ["check", "the tally arrives by tube", func() -> bool: return c.memo.visible and c.memo.memo.get("kind", "") == "tally"],
		["tap", _file_it], ["check", "FILE IT puts it away", func() -> bool: return not c.memo.visible],
		["tap", _sector2], ["check", "the dial turns to The Jellyfish", func() -> bool: return c.room_id == "jellyfish"],
		["tap", _sector_knob], ["check", "tapping the sector knob clicks it on to the next open sector", func() -> bool: return c.room_id == "dark"],
		["tap", _sector2], ["check", "and the number takes it back", func() -> bool: return c.room_id == "jellyfish"],
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
	return c.dispatch.handle()

func _wheel_c(key: String) -> Vector2:
	var v := Desk.v(key)
	return Vector2(float(v[0]), float(v[1]))

func _wheel_left() -> Vector2:
	return _wheel_c("order_wheel") + Vector2(-30, 10)

func _print_knob() -> Vector2:
	return c.press._knob_pos() + c.press.position

func _tray_card() -> Vector2:
	return Desk.r("tray").position + Vector2(60, 20)

func _slot_card0() -> Vector2:
	return c.table.slot_rect(0).get_center()

func _to_slot1() -> Vector2:
	return c.table.slot_rect(0).get_center() - _tray_card()

func _to_chute() -> Vector2:
	return Desk.r("chute_mouth").get_center() - _slot_card0()

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

func _sector_knob() -> Vector2:
	return Desk.r("sector_knob").get_center()

func _order_drum() -> Vector2:
	return Desk.r("order_drum").get_center() + Vector2(0, -18)

func _binder() -> Vector2:
	return Desk.r("binder").get_center()

func _wall() -> Vector2:
	return Desk.r("wall").get_center()


func _screen(p: Vector2) -> Vector2:
	return op.to_screen(p) if op != null else p


func _mouse(pos: Vector2, pressed: bool) -> void:
	pos = _screen(pos)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e)


func _move(pos: Vector2, rel: Vector2) -> void:
	rel = _screen(pos) - _screen(pos - rel)
	pos = _screen(pos)
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
		"arc":
			# Drag the wheel's grip round from one angle to another (degrees, 0 = east, -90 = up).
			var ctr := _wheel_c(s[1])
			var rad := float(Desk.v(s[1])[2]) - 4.0
			var a0 := deg_to_rad(float(s[2]))
			var a1 := deg_to_rad(float(s[3]))
			_busy = true
			var p0 := ctr + Vector2.from_angle(a0) * rad
			_mouse(p0, true)
			await get_tree().process_frame
			var last := p0
			for i in range(1, 13):
				var p := ctr + Vector2.from_angle(lerpf(a0, a1, i / 12.0)) * rad
				_move(p, p - last)
				last = p
				await get_tree().process_frame
			_mouse(last, false)
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
