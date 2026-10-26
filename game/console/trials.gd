class_name SeaTrials
extends Control
## The analytical engine: turn the crank and it runs the deck through twenty dives under
## new conditions, lighting a lamp for each (green: reached the beacon, red: lost).
## Sixteen and the Company certifies the sector. Tap a red lamp to watch that dive.

signal cranked
signal lamp_tapped(i: int)
signal locked_tapped

var results: Array = []          # "exit" or a cause, in order
var fleet := Survey.FLEET
var needed := 16
var running := false
var enabled := false             # the deck has reached the beacon at least once
var certified := false
var _crank := 0.0
var _drag := false
var _drag_a := 0.0
var _turned := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _crank_c() -> Vector2:
	var c := Desk.v("crank")
	return Vector2(float(c[0]), float(c[1])) - position


func _lamp(i: int) -> Vector2:
	var t: Dictionary = Desk.layout()["trial_lamps"]
	var col := i % int(t["cols"])
	var row := i / int(t["cols"])
	return Vector2(float(t["x"]) + col * float(t["dx"]), float(t["y"]) + row * float(t["dy"])) - position


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.position.distance_to(_crank_c()) < 30.0:
				_drag = true
				_turned = 0.0
				_drag_a = (event.position - _crank_c()).angle()
				accept_event()
				return
			for i in results.size():
				if event.position.distance_to(_lamp(i)) < 8.0:
					lamp_tapped.emit(i)
					accept_event()
					return
		elif _drag:
			_drag = false
			if _turned < 0.4:
				_start()
	elif event is InputEventMouseMotion and _drag:
		var a: float = (event.position - _crank_c()).angle()
		var da := wrapf(a - _drag_a, -PI, PI)
		_drag_a = a
		if enabled and not running:
			_crank += da
			_turned += absf(da)
			if _turned > 2.0:
				_drag = false
				_start()
		queue_redraw()


func _start() -> void:
	if not enabled:
		Sfx.play("switch", -6.0, 0.5)
		locked_tapped.emit()
		return
	if running:
		return
	cranked.emit()


func _process(delta: float) -> void:
	if running:
		_crank += delta * 7.0
		if randf() < 0.25:
			Sfx.play("crank", -16.0, 0.9 + randf() * 0.2)
	queue_redraw()


func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for i in fleet:
		var p := _lamp(i)
		if i < results.size():
			var ok: bool = results[i] == "exit"
			var c := Desk.GREEN_LAMP if ok else Desk.RED_LAMP
			Desk.draw_glow(self, p, 11.0, Color(c, 0.5))
			draw_circle(p, 3.8, c)
		elif running and i == results.size():
			draw_circle(p, 3.8, Color(Desk.AMBER, 0.4 + 0.4 * sin(now * 20.0)))
		else:
			draw_circle(p, 3.8, Color(0.07, 0.06, 0.05))
	# Painted under the lamps, never changing: what it takes. Two lamps say where the deck stands.
	var tl: Dictionary = Desk.layout()["trial_lamps"]
	var y := float(tl["y"]) + float(tl["dy"]) * 2.0 - position.y
	var x0 := float(tl["x"]) - 6.0 - position.x
	var f := Desk.font("plate")
	draw_string(f, Vector2(x0, y + 4.0), "%d OF %d TO PASS" % [needed, fleet], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Desk.STENCIL, 0.7))
	# (Clear of the dispatch chain, which hangs past this panel.)
	Desk.draw_lamp(self, Vector2(x0 + 122.0, y), "BEACON", Desk.AMBER, 1.0 if enabled else 0.0, 3.8, 1, 10)
	Desk.draw_lamp(self, Vector2(x0 + 172.0, y), "CERTIFIED", Desk.GREEN_LAMP, 1.0 if certified else 0.0, 3.8, 1, 10)
	Desk.draw_sprite(self, "crank", _crank_c(), _crank, Color.WHITE if enabled else Color(0.6, 0.6, 0.6))
	var pr := Desk.plaque_rect("trials")
	Desk.engraved(self, Rect2(pr.position - position, pr.size), Desk.plaque("trials")[4], 12)
