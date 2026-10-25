class_name WireRecorder
extends Control
## Every dive is recorded on wire. Drag a reel (or the wire itself) to scrub; the marks on
## the wire are what happened (red: hits; green: contacts; amber: card changes). Keys:
## back five seconds, play/pause, forward five seconds, and to the last loss. The knob sets
## the speed: ½, 1 or 2 (1 is normal speed, and every dive plays at what the knob says), or
## AUTO, which skims quiet water at 2 and slows to 1 for anything that happens.

signal scrubbed

const KEYS := ["◂◂", "PLAY", "▸▸", "TO THE LOSS"]
const SPEEDS := ["½", "1", "2", "AUTO"]
const RATE := [1.0, 2.0, 4.0]      # ticks played per tick of dive time, at each marked speed (1 is normal)

var replay: ReplayPlayer
var marks: Array = []            # [{t, kind}] from the tape
var _press_key := -1
var _drag := ""                  # "track" or "reel"
var _drag_a := 0.0
var _speed_i := 1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _r(key: String) -> Rect2:
	var r := Desk.r(key)
	return Rect2(r.position - position, r.size)


func _key_rect(i: int) -> Rect2:
	var k := _r("keys")
	var widths := [58.0, 70.0, 58.0, 122.0]
	var x := k.position.x + 4.0
	for j in i:
		x += widths[j] + 6.0
	return Rect2(x, k.position.y + 3.0, widths[i], k.size.y - 6.0)


func _has_dive() -> bool:
	return replay != null and replay.has_dive()


func _t_frac() -> float:
	if not _has_dive():
		return 0.0
	return replay.view.t / maxf(1.0, float(replay.view.last_tick()))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var p: Vector2 = event.position
			for i in KEYS.size():
				if _key_rect(i).has_point(p):
					_press_key = i
					Sfx.play("switch", -10.0, 1.3)
					_key(i)
					accept_event()
					queue_redraw()
					return
			if _r("track").grow(8).has_point(p) and _has_dive():
				_drag = "track"
				_seek_track(p.x)
			elif (_r("reel_a").grow(4).has_point(p) or _r("reel_b").grow(4).has_point(p)) and _has_dive():
				_drag = "reel"
				var c := _r("reel_a").get_center() if _r("reel_a").grow(4).has_point(p) else _r("reel_b").get_center()
				_drag_a = (p - c).angle()
				replay.playing = false
			elif _r("speed_knob").has_point(p):
				_speed_i = (_speed_i + 1) % SPEEDS.size()
				_apply_speed()
				Sfx.play("drum", -8.0, 0.8)
			accept_event()
		else:
			_press_key = -1
			_drag = ""
			queue_redraw()
	elif event is InputEventMouseMotion and _drag != "" and _has_dive():
		if _drag == "track":
			_seek_track(event.position.x)
		else:
			var c := _r("reel_a").get_center() if event.position.x < _r("reel_b").position.x - 2 else _r("reel_b").get_center()
			var a: float = (event.position - c).angle()
			var da := wrapf(a - _drag_a, -PI, PI)
			_drag_a = a
			# One turn of the reel is four seconds of wire.
			replay.seek(replay.view.t + da / TAU * 4.0 * World.TICKS_PER_SECOND)
			scrubbed.emit()


func _seek_track(x: float) -> void:
	var tr := _r("track")
	var f := clampf((x - tr.position.x) / tr.size.x, 0.0, 1.0)
	replay.seek(f * replay.view.last_tick())
	replay.playing = false
	scrubbed.emit()


func _key(i: int) -> void:
	if not _has_dive():
		return
	var tps := float(World.TICKS_PER_SECOND)
	match i:
		0:
			replay.seek(replay.view.t - 5.0 * tps)
			scrubbed.emit()
		1:
			if replay.tick() >= replay.view.last_tick() and not replay.playing:
				replay.seek(0.0)
			replay.playing = not replay.playing
			replay.rewinding = false
		2:
			replay.seek(replay.view.t + 5.0 * tps)
			scrubbed.emit()
		3:
			replay.seek(maxf(0.0, replay.view.last_tick() - 3.0 * tps))
			replay.playing = true
			scrubbed.emit()


func _apply_speed() -> void:
	if replay == null:
		return
	replay.skip_until = -1
	replay.auto = _speed_i == SPEEDS.size() - 1
	if not replay.auto:
		replay.speed_i = ReplayPlayer.SPEEDS.find(RATE[_speed_i])


## Turn the knob one mark (the arrow keys), stopping at ½ and at AUTO.
func step_speed(d: int) -> void:
	var i := clampi(_speed_i + d, 0, SPEEDS.size() - 1)
	if i != _speed_i:
		_speed_i = i
		Sfx.play("switch", -10.0, 0.8)
		_apply_speed()


## The speed as the knob marks it (1 is normal), for the scope's readout.
static func marked(rate: float) -> String:
	return str(rate / 2.0).trim_suffix(".0").replace("0.5", "½")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var t := replay.view.t if _has_dive() else 0.0
	var f := _t_frac()
	# Reels: wire moves from the left reel to the right as the dive plays.
	for side in 2:
		var rr := _r("reel_a" if side == 0 else "reel_b")
		var c := rr.get_center()
		var fill := (1.0 - f) if side == 0 else f
		draw_circle(c, 14.0 + 22.0 * fill, Color(0.32, 0.25, 0.14))
		draw_arc(c, 14.0 + 22.0 * fill, 0, TAU, 40, Color(0.6, 0.48, 0.28, 0.5), 1.0)
		Desk.draw_sprite(self, "reel", c, -t / 40.0 + side * 1.3)
	# The wire between them.
	var a := _r("reel_a").get_center()
	var b := _r("reel_b").get_center()
	draw_line(a + Vector2(0, 38), b + Vector2(0, 38), Color(0.75, 0.62, 0.38, 0.6), 1.0)
	# Track with marks and the playhead.
	var tr := _r("track")
	draw_rect(tr.grow(-2), Color(0.03, 0.05, 0.04))
	if _has_dive():
		var last := maxf(1.0, float(replay.view.last_tick()))
		draw_rect(Rect2(tr.position + Vector2(2, 2), Vector2((tr.size.x - 4) * f, tr.size.y - 4)), Color(Desk.PHOSPHOR, 0.12))
		for m: Dictionary in marks:
			var x := tr.position.x + 2 + (tr.size.x - 4) * float(m["t"]) / last
			var col: Color = {"hit": Desk.RED_LAMP, "contact": Desk.PHOSPHOR, "card": Desk.AMBER, "end": Color.WHITE}.get(m["kind"], Color(1, 1, 1, 0.3))
			var hgt: float = {"hit": 1.0, "contact": 0.7, "card": 0.45, "end": 1.0}.get(m["kind"], 0.3)
			if m["kind"] == "voice" or m["kind"] == "info":
				continue
			draw_line(Vector2(x, tr.end.y - 3), Vector2(x, tr.end.y - 3 - (tr.size.y - 6) * hgt), Color(col, 0.85), 1.5)
		var px := tr.position.x + 2 + (tr.size.x - 4) * f
		draw_line(Vector2(px, tr.position.y - 3), Vector2(px, tr.end.y + 3), Desk.AMBER_HOT, 2.0)
		Desk.draw_glow(self, Vector2(px, tr.get_center().y), 14.0, Color(Desk.AMBER, 0.5))
	# Keys.
	var font := Desk.font("plate")
	for i in KEYS.size():
		var kr := _key_rect(i)
		var down := _press_key == i
		var tx: String = KEYS[i]
		if i == 1 and _has_dive():
			tx = "PAUSE" if replay.playing else "PLAY"
		var sp := Desk.tex("key_down" if down else "key_up")
		if sp != null:
			draw_texture_rect(sp, Rect2(kr.position - Vector2(4, 3), kr.size + Vector2(8, 8)), false)
		else:
			draw_rect(kr, Color(0.06, 0.05, 0.05))
		Desk.centred(self, Rect2(kr.position + Vector2(0, 1 if down else -1), kr.size), tx, font, 14, Color(0.85, 0.78, 0.6, 0.9 if _has_dive() else 0.35))
	# Speed knob and its scale.
	var kn := _r("speed_knob")
	var kc := kn.get_center()
	for i in SPEEDS.size():
		var ang := deg_to_rad(-210.0 + 60.0 * i)
		var p := kc + Vector2.from_angle(ang) * 34.0
		Desk.centred(self, Rect2(p - Vector2(14, 7), Vector2(28, 14)), SPEEDS[i], font, 10 if i == SPEEDS.size() - 1 else 12,
			Desk.AMBER_HOT if i == _speed_i else Color(0.85, 0.78, 0.6, 0.6))
	Desk.draw_sprite(self, "knob_speed", kc, deg_to_rad(-210.0 + 60.0 * _speed_i + 90.0), Color.WHITE, 0.62)
	var pr := Desk.plaque_rect("recorder")
	Desk.engraved(self, Rect2(pr.position - position, pr.size), Desk.plaque("recorder")[4], 13)
