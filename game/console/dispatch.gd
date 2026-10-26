class_name PullChain
extends Control
## Dispatch: a chain hanging from the ceiling with a red T-handle on its end. Grab the handle and
## pull it down: the pull rod comes out of the ceiling against its spring, and at the bottom of
## its travel the steam whistle blows and the next Robbie drops. Let go and the rod springs back
## up, the chain jumping and swinging until it hangs still again. If the reader won't take the
## deck (or the sea trials are out) the rod stops short with a clunk.
## Two lamps on the panel: READY, and HOLD when it won't go. The next Robbie's number is on a
## counter in the plate. The chain is simulated (Verlet, links of fixed length), in console pixels.

signal dispatched
signal refused(why: String)

const LINKS := 22
const GRAVITY := 1600.0
const DAMP := 0.985
const SPRING := 70.0             # the pull rod's return spring...
const ROD_FRICTION := 15.0       # ...and its dashpot, so it settles back rather than flinging the chain

var refuse_reason := ""          # "" when the deck is fine
var busy := false                # sea trials are out
var serial := 1
var _serial_shown := -1.0
var _x := 0.0                    # where the chain hangs from (console x), and the ceiling's y
var _top := 0.0
var _rest := 0.0                 # the handle's y at rest
var _pull := 0.0                 # how far the rod can be drawn out
var _fire_at := 0.0
var _len := 0.0                  # the chain's length, rod to handle
var _seg := 0.0
var _p := PackedVector2Array()   # link joints, console coordinates; the last is the handle
var _prev := PackedVector2Array()
var _ext := 0.0                  # how far the rod is drawn out of the ceiling
var _ext_v := 0.0
var _grab := false
var _finger := Vector2.ZERO
var _fired := false
var _blocked := false
var _whistle := -10.0            # when the whistle last blew
var _clink := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var c: Dictionary = Desk.layout()["chain"]
	_x = float(c["x"])
	_top = float(c["top"])
	_rest = float(c["rest_y"])
	_pull = float(c["pull"])
	_fire_at = float(c["fire"])
	_len = _rest - _top
	_seg = _len / LINKS
	for i in LINKS + 1:
		_p.append(Vector2(_x, _top + _seg * i))
	_prev = _p.duplicate()


## Where the handle is, in console coordinates (for the play-through).
func handle() -> Vector2:
	return _p[LINKS] + Vector2(0, 12)


func ready_to_go() -> bool:
	return refuse_reason == "" and not busy


func _has_point(p: Vector2) -> bool:
	return _grab or (p + position).distance_to(handle()) < 32.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_grab = true
			_finger = event.position + position
			_fired = false
			_blocked = false
			Sfx.play("chain", -10.0, 0.9)
			accept_event()
		elif _grab:
			_grab = false
			if _ext > 6.0:
				Sfx.play("chain", -6.0, 1.05)
	elif event is InputEventMouseMotion and _grab:
		_finger = event.position + position


func _process(delta: float) -> void:
	var steps := 3
	var dt := minf(delta, 0.05) / steps
	for s in steps:
		_step(dt)
	# Clinks while it swings.
	var speed := (_p[LINKS] - _prev[LINKS]).length() / maxf(dt, 0.0001)
	_clink -= delta
	if speed > 260.0 and _clink <= 0.0:
		_clink = 0.18
		Sfx.play("chain", clampf(-26.0 + speed * 0.012, -24.0, -9.0), 0.9 + randf() * 0.2)
	_serial_shown = float(serial) if _serial_shown < 0.0 else move_toward(_serial_shown, float(serial), delta * 2.5)
	queue_redraw()


func _step(dt: float) -> void:
	var anchor0 := Vector2(_x, _top)
	if _grab:
		# The rod comes out as far as the finger is past the chain's length; it stops short if it won't go.
		var limit := _pull if ready_to_go() else _fire_at * 0.45
		var want := clampf(_finger.distance_to(anchor0) - _len, 0.0, _pull)
		if want > limit and not ready_to_go() and not _blocked:
			_blocked = true
			Sfx.play("cover", -4.0, 0.7)
			refused.emit("busy" if busy else refuse_reason)
		_ext = minf(want, limit)
		_ext_v = 0.0
		if _ext >= _fire_at and not _fired:
			_fire()
	else:
		_ext_v += (-SPRING * _ext - ROD_FRICTION * _ext_v) * dt
		_ext += _ext_v * dt
		if _ext < 0.0:
			if _ext_v < -80.0:
				Sfx.play("cover", -14.0, 1.4)
			_ext = 0.0
			_ext_v = -_ext_v * 0.25
	var anchor := Vector2(_x, _top + _ext)
	# Verlet: carry each joint on by its own motion, with gravity.
	for i in range(1, LINKS + 1):
		var v := (_p[i] - _prev[i]) * DAMP
		_prev[i] = _p[i]
		_p[i] += v + Vector2(0, GRAVITY) * dt * dt
	# The rod yanks the chain with it as it moves.
	_p[0] = anchor
	_prev[0] = anchor
	if _grab:
		var to := _finger - anchor
		if to.length() > _len:
			to = to.normalized() * _len
		_p[LINKS] = anchor + to
	# Links keep their length.
	for it in 14:
		for i in LINKS:
			var a := _p[i]
			var b := _p[i + 1]
			var d := b - a
			var l := d.length()
			if l < 0.0001:
				continue
			var diff := (l - _seg) / l
			if i == 0:
				_p[1] -= d * diff
			elif i + 1 == LINKS and _grab:
				_p[i] += d * diff
			else:
				# The handle is heavy: it gives a quarter of what a link gives.
				var wa := 0.5 if i + 1 < LINKS else 0.8
				_p[i] += d * diff * wa
				_p[i + 1] -= d * diff * (1.0 - wa)


func _fire() -> void:
	_fired = true
	_whistle = Time.get_ticks_msec() / 1000.0
	Sfx.play("lever", -4.0, 0.8)
	Sfx.play("whistle", -3.0)
	dispatched.emit()


func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var o := position
	# Lamps: READY when the reader will take the deck, HOLD when it won't (blinking while the trials are out).
	var rl := Desk.v("ready_lamp")
	var lp := Vector2(float(rl[0]), float(rl[1])) - o
	var hold := 0.0
	if busy:
		hold = 1.0 if fmod(now, 0.8) < 0.45 else 0.0
	elif refuse_reason != "":
		hold = 1.0
	Desk.draw_lamp(self, lp + Vector2(-56, 0), "HOLD", Desk.RED_LAMP, hold, 5.5)
	Desk.draw_lamp(self, lp, "READY", Desk.GREEN_LAMP, 1.0 if ready_to_go() else 0.0, 5.5)
	# The plate.
	var pr := Desk.plaque_rect("dispatch")
	Desk.engraved(self, Rect2(pr.position - o, Vector2(pr.size.x - 52, pr.size.y)), "DISPATCH  ·  ROBBIE", 13)
	Desk.draw_odometer(self, Rect2(pr.end - o - Vector2(50, pr.size.y + 2), Vector2(42, pr.size.y + 4)), _serial_shown, 3, 13)
	# The whistle's steam, rising off its mouth.
	var wr := Desk.r("whistle")
	var age := now - _whistle
	if age < 2.4:
		var mouth := Vector2(wr.get_center().x, wr.position.y + 6) - o
		for k in 14:
			var t := age - k * 0.08
			if t < 0.0 or t > 1.6:
				continue
			var rise := t * 90.0
			var p := mouth + Vector2(sin(k * 2.3 + t * 3.0) * (6.0 + rise * 0.25), -rise)
			Desk.draw_glow(self, p, 10.0 + t * 26.0, Color(0.85, 0.88, 0.86, 0.32 * (1.0 - t / 1.6)))
	# The pull rod, out of the ceiling as far as it's drawn.
	var anchor := _p[0] - o
	draw_rect(Rect2(Vector2(anchor.x - 4.5, _top - 30.0 - o.y), Vector2(9, anchor.y - (_top - 30.0 - o.y))), Color(0.3, 0.22, 0.12))
	draw_rect(Rect2(Vector2(anchor.x - 4.5, _top - 30.0 - o.y), Vector2(3, anchor.y - (_top - 30.0 - o.y))), Color(0.58, 0.44, 0.24, 0.8))
	# The chain: links alternately face on (an oval ring) and edge on (a bar).
	var shadow := Vector2(4, 6)
	for pass_i in 2:
		for i in LINKS:
			var a := _p[i] - o
			var b := _p[i + 1] - o
			if pass_i == 0:
				a += shadow
				b += shadow
			_link(a, b, i, pass_i == 0)
	# The handle: a ring on the last link, and the red T-bar across.
	var h := _p[LINKS] - o
	var dirv := (_p[LINKS] - _p[LINKS - 1]).normalized()
	if dirv == Vector2.ZERO:
		dirv = Vector2.DOWN
	var ang := dirv.angle() - PI * 0.5
	for pass_i in 2:
		var at := h + (shadow if pass_i == 0 else Vector2.ZERO)
		draw_set_transform(at, ang, Vector2.ONE)
		if pass_i == 0:
			draw_rect(Rect2(-24, 6, 48, 13), Color(0, 0, 0, 0.35))
		else:
			draw_arc(Vector2(0, 2), 5.0, 0, TAU, 14, Color(0.34, 0.25, 0.13), 2.6)
			# Red T-bar, chipped, with bronze caps.
			draw_rect(Rect2(-22, 6, 44, 12), Color(0.45, 0.09, 0.05))
			draw_rect(Rect2(-22, 6, 44, 4), Color(0.62, 0.15, 0.09))
			draw_rect(Rect2(-22, 15, 44, 3), Color(0.3, 0.06, 0.03))
			for cx: float in [-15.0, -4.0, 9.0]:
				draw_rect(Rect2(cx, 8 + fmod(cx * 7.0, 5.0), 3, 2), Color(0.42, 0.32, 0.18, 0.8))
			for sx: float in [-25.0, 22.0]:
				draw_rect(Rect2(sx, 5, 3, 14), Color(0.42, 0.31, 0.16))
			draw_rect(Rect2(-3, 0, 6, 7), Color(0.38, 0.28, 0.15))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _link(a: Vector2, b: Vector2, i: int, shade: bool) -> void:
	var mid := (a + b) * 0.5
	var d := b - a
	var ang := d.angle()
	var ll := d.length() * 0.62 + 3.0
	if shade:
		if i % 2 == 0:
			draw_set_transform(mid, ang, Vector2(1.0, 0.55))
			draw_arc(Vector2.ZERO, ll * 0.62, 0, TAU, 16, Color(0, 0, 0, 0.3), 5.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_line(mid - d.normalized() * ll * 0.6, mid + d.normalized() * ll * 0.6, Color(0, 0, 0, 0.3), 5.0)
		return
	var dark := Color(0.16, 0.12, 0.07)
	var body := Color(0.42, 0.32, 0.18)
	var lit := Color(0.72, 0.56, 0.32)
	if i % 2 == 0:
		draw_set_transform(mid, ang, Vector2(1.0, 0.6))
		draw_arc(Vector2.ZERO, ll * 0.62, 0, TAU, 18, dark, 5.2)
		draw_arc(Vector2.ZERO, ll * 0.62, 0, TAU, 18, body, 3.0)
		draw_arc(Vector2.ZERO, ll * 0.62, PI * 1.05, PI * 1.75, 8, lit, 1.4)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var n := d.normalized()
		var c := mid
		draw_line(c - n * ll * 0.64, c + n * ll * 0.64, dark, 5.4)
		draw_line(c - n * ll * 0.6, c + n * ll * 0.6, body, 3.2)
		draw_line(c - n * ll * 0.5 - n.orthogonal() * 0.9, c + n * ll * 0.5 - n.orthogonal() * 0.9, lit, 1.1)
