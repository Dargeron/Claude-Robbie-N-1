class_name DispatchLever
extends Control
## Dispatch: a big lever. A long bronze arm on a pivot at the left of the panel, a thick red grip
## on its end. Haul it down through its notched quadrant: at the bottom it clunks home, the steam
## whistle blows and the next Robbie drops. Let go and it springs back up against its stop. If the
## reader won't take the deck (or the sea trials are out) it jams a few degrees down, with a clunk.
## A tap on the grip throws it for you. Two lamps: READY, and HOLD when it won't go. The next
## Robbie's number is on a counter in the plate.

signal dispatched
signal refused(why: String)

const REST := -24.0              # degrees from pointing right: up...
const PULLED := 24.0             # ...and thrown down
const JAM := 6.0                 # how far it gives when it won't go
const SPRING := 90.0             # the return spring (per second squared, per degree)
const DAMPING := 9.0

var refuse_reason := ""          # "" when the deck is fine
var busy := false                # sea trials are out
var serial := 1
var _serial_shown := -1.0
var _angle := REST
var _vel := 0.0
var _drag := false
var _moved := false
var _press := Vector2.ZERO
var _grab_off := 0.0             # finger angle minus lever angle, when grabbed
var _fired := false
var _jammed := false
var _whistle := -10.0            # when the whistle last blew (on _clock)
var _clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _pivot() -> Vector2:
	var p := Desk.v("dispatch_pivot")
	return Vector2(float(p[0]), float(p[1])) - position


func _arm_len() -> float:
	return float(Desk.v("dispatch_pivot")[2])


func _dir(deg: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(deg))


func _grip_local() -> Vector2:
	return _pivot() + _dir(_angle) * (_arm_len() - 14.0)


## Where the grip is, in console coordinates (for the notes and the play-through).
func handle() -> Vector2:
	return _grip_local() + position


func ready_to_go() -> bool:
	return refuse_reason == "" and not busy


func _has_point(p: Vector2) -> bool:
	return _drag or p.distance_to(_grip_local()) < 36.0


func _finger_angle(p: Vector2) -> float:
	return rad_to_deg((p - _pivot()).angle())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag = true
			_moved = false
			_press = event.position
			_grab_off = _finger_angle(event.position) - _angle
			_fired = false
			_jammed = false
			accept_event()
		elif _drag:
			_drag = false
			if not _moved and not _fired:
				_throw()
	elif event is InputEventMouseMotion and _drag:
		if event.position.distance_to(_press) > 5.0:
			_moved = true
		var limit := PULLED if ready_to_go() else REST + JAM
		var a := clampf(_finger_angle(event.position) - _grab_off, REST, PULLED)
		if a > limit:
			a = limit
			_jam()
		_vel = 0.0
		_angle = a
		if _angle >= PULLED - 2.0 and not _fired:
			_fire()


## A tap: throw it all the way, or find it jammed.
func _throw() -> void:
	if not ready_to_go():
		_angle = REST + JAM
		_jam()
		return
	var tw := create_tween()
	tw.tween_property(self, "_angle", PULLED, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		if not _fired:
			_fire())


func _jam() -> void:
	if _jammed:
		return
	_jammed = true
	Sfx.play("cover", -3.0, 0.7)
	refused.emit("busy" if busy else refuse_reason)


func _fire() -> void:
	_fired = true
	_angle = PULLED
	_whistle = _clock
	Sfx.play("lever", -1.0, 0.8)
	Sfx.play("whistle", -3.0)
	dispatched.emit()


func _process(delta: float) -> void:
	_clock += delta
	if not _drag:
		# The return spring takes it back up; it knocks against its stop and settles.
		_vel += (-SPRING * (_angle - REST) - DAMPING * _vel) * delta
		_angle += _vel * delta
		if _angle < REST:
			if _vel < -40.0:
				Sfx.play("cover", -12.0, 1.3)
			_angle = REST
			_vel = -_vel * 0.3
	_serial_shown = float(serial) if _serial_shown < 0.0 else move_toward(_serial_shown, float(serial), delta * 2.5)
	queue_redraw()


func _draw() -> void:
	var o := position
	# Lamps: READY when the reader will take the deck, HOLD when it won't (blinking while the trials are out).
	var rl := Desk.v("ready_lamp")
	var lp := Vector2(float(rl[0]), float(rl[1])) - o
	var hold := 0.0
	if busy:
		hold = 1.0 if fmod(_clock, 0.8) < 0.45 else 0.0
	elif refuse_reason != "":
		hold = 1.0
	Desk.draw_lamp(self, lp, "HOLD", Desk.RED_LAMP, hold, 5.0)
	Desk.draw_lamp(self, lp + Vector2(0, 22), "READY", Desk.GREEN_LAMP, 1.0 if ready_to_go() else 0.0, 5.0)
	# The plate.
	var pr := Desk.plaque_rect("dispatch")
	Desk.engraved(self, Rect2(pr.position - o, Vector2(pr.size.x - 52, pr.size.y)), "DISPATCH  ·  ROBBIE", 13)
	Desk.draw_odometer(self, Rect2(pr.end - o - Vector2(50, pr.size.y + 2), Vector2(42, pr.size.y + 4)), _serial_shown, 3, 13)
	# Steam off the whistle when it blows.
	var wr := Desk.r("whistle")
	var age := _clock - _whistle
	if age < 2.4:
		var mouth := Vector2(wr.get_center().x, wr.position.y + 4) - o
		for k in 16:
			var t := age - k * 0.07
			if t < 0.0 or t > 1.6:
				continue
			var rise := t * 95.0
			var p := mouth + Vector2(sin(k * 2.3 + t * 3.0) * (5.0 + rise * 0.3) + rise * 0.25, -rise)
			Desk.draw_glow(self, p, 10.0 + t * 28.0, Color(0.85, 0.88, 0.86, 0.34 * (1.0 - t / 1.6)))
	# The lever: shadow, arm, grip, then the hub over the arm's root.
	_draw_lever(Desk.SHADOW * 1.6, true)
	_draw_lever(Vector2.ZERO, false)


func _draw_lever(off: Vector2, shade: bool) -> void:
	var piv := _pivot() + off
	var d := _dir(_angle)
	var n := d.orthogonal()
	var ln := _arm_len()
	var dark := Color(0, 0, 0, 0.38)
	# The arm: a forged bronze bar, thick at the root, a little thinner out to the grip.
	var arm := PackedVector2Array([piv + n * 10.0, piv + d * (ln - 40.0) + n * 7.0, piv + d * (ln - 40.0) - n * 7.0, piv - n * 10.0])
	draw_colored_polygon(arm, dark if shade else Color(0.32, 0.23, 0.12))
	if not shade:
		draw_line(piv + n * 7.5, piv + d * (ln - 40.0) + n * 5.0, Color(0.6, 0.46, 0.25, 0.85), 2.5)
		draw_line(piv - n * 8.5, piv + d * (ln - 40.0) - n * 6.0, Color(0.14, 0.1, 0.05), 2.0)
		for k in 3:
			draw_circle(piv + d * (34.0 + k * 26.0), 2.4, Color(0.18, 0.13, 0.07))
	# The grip: a thick red sleeve, chipped, between bronze ferrules.
	var g0 := piv + d * (ln - 42.0)
	var g1 := piv + d * ln
	var grip := PackedVector2Array([g0 + n * 13.0, g1 + n * 12.0, g1 + d * 4.0 + n * 8.0, g1 + d * 4.0 - n * 8.0, g1 - n * 12.0, g0 - n * 13.0])
	draw_colored_polygon(grip, dark if shade else Color(0.45, 0.09, 0.05))
	if not shade:
		draw_line(g0 + n * 9.0, g1 + n * 8.0, Color(0.64, 0.16, 0.09), 4.0)
		draw_line(g0 - n * 10.0, g1 - n * 9.0, Color(0.28, 0.05, 0.03), 3.0)
		for k in 5:
			var p := g0.lerp(g1, 0.15 + 0.17 * k) + n * (float((k * 37) % 9) - 4.0)
			draw_rect(Rect2(p, Vector2(3, 2)), Color(0.42, 0.32, 0.18, 0.8))
		for fp: Vector2 in [g0, g1]:
			draw_line(fp + n * 14.0, fp - n * 14.0, Color(0.36, 0.27, 0.14), 4.0)
			draw_line(fp + n * 14.0, fp - n * 14.0 + d * 0.0, Color(0.58, 0.45, 0.25, 0.6), 1.2)
	# The hub and its nut.
	draw_circle(piv, 20.0, dark if shade else Color(0.3, 0.22, 0.12))
	if not shade:
		draw_arc(piv, 18.5, PI * 1.05, PI * 1.8, 12, Color(0.6, 0.46, 0.26, 0.8), 2.0)
		draw_circle(piv, 11.0, Color(0.22, 0.16, 0.08))
		var hexp := PackedVector2Array()
		for k in 6:
			hexp.append(piv + Vector2.from_angle(TAU * k / 6.0 + deg_to_rad(_angle)) * 8.0)
		draw_colored_polygon(hexp, Color(0.46, 0.35, 0.19))
