class_name DispatchLever
extends Control
## Dispatch: lift the red safety cover to arm it, then pull the lever across. Two lamps: SAFE
## while the cover is down, READY when it is up and the reader will take the deck. The next
## Robbie's number is on a counter in the plate.

signal dispatched
signal refused(why: String)

const REST := -38.0
const PULLED := 38.0

var armed := false
var refuse_reason := ""          # "" when the deck is fine
var busy := false                # sea trials are out
var serial := 1
var _serial_shown := -1.0
var _angle := REST
var _drag := false
var _fired := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _pivot() -> Vector2:
	var p := Desk.v("dispatch_pivot")
	return Vector2(float(p[0]), float(p[1])) - position


func _cover_rect() -> Rect2:
	var c := Desk.v("cover")
	return Rect2(Vector2(float(c[0]), float(c[1])) - position - Vector2(0, 18), Vector2(float(c[2]), float(c[3]) + 18))


func _knob() -> Vector2:
	var p := Desk.v("dispatch_pivot")
	return _pivot() + Vector2.from_angle(deg_to_rad(_angle - 90.0)) * float(p[2])


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _cover_rect().has_point(event.position):
				armed = not armed
				Sfx.play("cover", -4.0, 1.0 if armed else 0.85)
				accept_event()
			elif event.position.distance_to(_knob()) < 30.0 or (event.position.distance_to(_pivot()) < 90.0 and event.position.y < _pivot().y):
				_drag = true
				_fired = false
				accept_event()
		elif _drag:
			_drag = false
			if not _fired and _angle < REST + 8.0:
				_try_auto()
			elif not _fired and _angle > lerpf(REST, PULLED, 0.6):
				_fire()
	elif event is InputEventMouseMotion and _drag:
		var d: Vector2 = event.position - _pivot()
		var a := rad_to_deg(atan2(d.x, -d.y))
		var limit := PULLED if _ok() else REST + 12.0
		_angle = clampf(a, REST, limit)
		if _angle >= PULLED - 10.0 and not _fired:
			_fire()
		queue_redraw()


func _ok() -> bool:
	return armed and refuse_reason == "" and not busy


func _try_auto() -> void:
	if not _ok():
		_complain()
		return
	var tw := create_tween()
	tw.tween_property(self, "_angle", PULLED, 0.18).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if not _fired:
			_fire())


func _complain() -> void:
	Sfx.play("switch", -6.0, 0.5)
	if not armed:
		refused.emit("cover")
	elif busy:
		refused.emit("busy")
	else:
		refused.emit(refuse_reason)


func _fire() -> void:
	_fired = true
	Sfx.play("lever", -2.0)
	dispatched.emit()


func _process(delta: float) -> void:
	if not _drag and _angle > REST:
		_angle = maxf(REST, _angle - delta * 160.0)
	_serial_shown = float(serial) if _serial_shown < 0.0 else move_toward(_serial_shown, float(serial), delta * 2.5)
	queue_redraw()


func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# Lamps: SAFE (amber) with the cover down, READY (green) with it up and a deck the reader
	# will take; while the sea trials are out, SAFE blinks.
	var rl := Desk.v("ready_lamp")
	var lp := Vector2(float(rl[0]), float(rl[1])) - position
	var safe := 0.0
	if busy:
		safe = 1.0 if fmod(now, 0.8) < 0.45 else 0.0
	elif not armed:
		safe = 1.0
	var ready := 1.0 if armed and not busy and refuse_reason == "" else 0.0
	Desk.draw_lamp(self, lp + Vector2(-66, 0), "SAFE", Desk.AMBER, safe, 5.5)
	Desk.draw_lamp(self, lp, "READY", Desk.GREEN_LAMP, ready, 5.5)
	var f := Desk.font("plate")
	# Under the cover, when it's up.
	var c := Desk.v("cover")
	var hinge := Vector2(float(c[0]) + float(c[2]) * 0.5, float(c[1]) + 1.0) - position
	if armed:
		Desk.centred(self, Rect2(hinge + Vector2(-36, 12), Vector2(72, 34)), "ARMED", f, 16, Color(Desk.RED_LAMP, 0.8))
	Desk.draw_sprite(self, "cover_open" if armed else "cover_closed", hinge)
	# The lever.
	Desk.draw_sprite(self, "lever_dispatch", _pivot(), deg_to_rad(_angle))
	var pr := Desk.plaque_rect("dispatch")
	Desk.engraved(self, Rect2(pr.position - position, Vector2(pr.size.x - 52, pr.size.y)), "DISPATCH  ·  ROBBIE", 13)
	Desk.draw_odometer(self, Rect2(pr.end - position - Vector2(50, pr.size.y + 2), Vector2(42, pr.size.y + 4)), _serial_shown, 3, 13)
