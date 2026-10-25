class_name MoodPorthole
extends Control
## Bathy's face screen, relayed live through a brass porthole: the only full-colour, warm
## thing on the console. Calm, curious, worried, scared, hurt, happy at the beacon, dim
## when running dark; static when the carrier drops.

var mood := "idle"
var look := Vector2.ZERO         # where his eyes point, -1..1
var serial := 0
var _look := Vector2.ZERO
var _blink_at := 2.0
var _shake := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_look = _look.lerp(look, minf(1.0, delta * 6.0))
	_shake = 1.0 if mood == "scared" else maxf(0.0, _shake - delta * 4.0)
	queue_redraw()


func _draw() -> void:
	var pc := Desk.v("porthole_c")
	var c := Vector2(float(pc[0]), float(pc[1])) - position
	var rad := float(pc[2]) - 11.0
	var now := Time.get_ticks_msec() / 1000.0
	# The face screen behind the glass.
	draw_circle(c, rad, Color(0.04, 0.07, 0.12))
	Desk.draw_glow(self, c, rad * 1.1, Color(0.3, 0.75, 1.0, 0.18))
	if mood == "lost":
		for i in 90:
			var h := float((int(now * 25.0) * 7919 + i * 104729) % 1000) / 1000.0
			var h2 := float((int(now * 25.0) * 3571 + i * 7907) % 1000) / 1000.0
			var p := c + Vector2(h - 0.5, h2 - 0.5) * rad * 1.6
			if p.distance_to(c) < rad - 2.0:
				draw_rect(Rect2(p, Vector2(2, 1.5)), Color(0.6, 0.8, 0.9, 0.3 + 0.5 * h))
		Desk.centred(self, Rect2(c - Vector2(rad, 8), Vector2(rad * 2, 16)), "NO SIGNAL", Desk.font("crt"), 16, Color(0.7, 0.9, 1.0, 0.6))
		_label()
		return
	var shake := Vector2(sin(now * 47.0), cos(now * 53.0)) * 1.2 * _shake
	var lk := _look * 4.0 + shake
	var eye_col := Color(0.45, 0.95, 1.0)
	var dim := 1.0
	if mood == "dark":
		dim = 0.45
	eye_col = Color(eye_col, dim)
	var blink := fmod(now, _blink_at) < 0.12 and mood in ["idle", "curious", "dark", "worried"]
	if fmod(now, _blink_at) < 0.02:
		_blink_at = 2.4 + fmod(now * 7.13, 2.0)
	var ex := 12.0
	for sgn: float in [-1.0, 1.0]:
		var e := c + Vector2(sgn * ex, -4.0) + lk
		match mood:
			"happy":
				draw_arc(e + Vector2(0, 3), 6.0, PI * 1.1, PI * 1.9, 10, eye_col, 3.0)
			"hurt":
				draw_line(e + Vector2(5 * sgn, -4), e + Vector2(-4 * sgn, 0), eye_col, 2.5)
				draw_line(e + Vector2(5 * sgn, 4), e + Vector2(-4 * sgn, 0), eye_col, 2.5)
			"scared":
				draw_circle(e, 7.5, eye_col)
				draw_circle(e + _look * 2.0, 2.0, Color(0.04, 0.07, 0.12))
			_:
				if blink:
					draw_line(e + Vector2(-5, 0), e + Vector2(5, 0), eye_col, 2.5)
				else:
					var hh := 13.0 if mood != "dark" else 6.0
					if mood == "worried":
						hh = 10.0
					var er := Rect2(e - Vector2(5, hh * 0.5), Vector2(10, hh))
					draw_rect(er, eye_col)
					draw_circle(er.position + Vector2(5, 0), 5.0, eye_col)
					draw_circle(er.end - Vector2(5, 0), 5.0, eye_col)
					draw_circle(e + Vector2(-2, -hh * 0.3), 1.6, Color(1, 1, 1, 0.8 * dim))
		if mood == "worried" or mood == "scared":
			draw_line(e + Vector2(-6 * sgn, -12), e + Vector2(5 * sgn, -15), Color(eye_col, 0.8), 2.0)
		Desk.draw_glow(self, e, 14.0, Color(0.4, 0.9, 1.0, 0.25 * dim))
	# Blush and mouth.
	var blush := 0.55 if mood == "happy" else 0.3
	for sgn: float in [-1.0, 1.0]:
		draw_circle(c + Vector2(sgn * 22.0, 9.0) + lk * 0.5, 5.0, Color(1.0, 0.45, 0.6, blush * dim))
	var m := c + Vector2(0, 13) + lk * 0.6
	match mood:
		"happy":
			draw_arc(m, 5.0, 0.2, PI - 0.2, 10, eye_col, 2.0)
		"scared", "hurt":
			draw_arc(m + Vector2(0, 2), 3.0, 0, TAU, 10, eye_col, 1.6)
		"worried":
			draw_arc(m + Vector2(0, 4), 4.0, PI + 0.4, TAU - 0.4, 8, eye_col, 1.6)
		_:
			draw_line(m + Vector2(-3, 0), m + Vector2(3, 0), Color(eye_col, 0.8), 1.6)
	# Scanlines of the face screen and the porthole's glass.
	for y in range(int(c.y - rad), int(c.y + rad), 3):
		var half := sqrt(maxf(0.0, rad * rad - (y - c.y) * (y - c.y)))
		draw_line(Vector2(c.x - half, y), Vector2(c.x + half, y), Color(0, 0, 0, 0.18), 1.0)
	draw_arc(c, rad - 4.0, PI * 1.08, PI * 1.5, 14, Color(1, 1, 1, 0.14), 5.0)
	_label()


func _label() -> void:
	var pr := Desk.plaque_rect("porthole")
	Desk.engraved(self, Rect2(pr.position - position, pr.size), "ROBBIE %03d" % serial if serial > 0 else "NO HULL OUT", 12)
