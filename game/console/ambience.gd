class_name Ambience
extends Control
## The station breathing around the desk: the press vents steam when it stamps, pipes leak
## a little now and then, condensation runs down the bulkhead seams, and the work lamp
## isn't quite steady. Drawn over the machines; never catches a touch.

var press: CardPress
var _puffs: Array = []           # {p, v, t0, r}
var _drips: Array = []           # {x, y, v, t0}
var _next_leak := 6.0
var _next_drip := 2.0
var _flicker := 0.0
var _next_flicker := 14.0
var _vented := false


func _init() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _puff(at: Vector2, n: int, up: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for i in n:
		_puffs.append({"p": at + Vector2(randf_range(-4, 4), 0), "v": Vector2(randf_range(-14, 14), -randf_range(up * 0.6, up)),
			"t0": now + i * 0.03, "r": randf_range(6, 12)})


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# The press vents as it stamps.
	var st := press.stamping() if press != null else -1.0
	if st >= 0.0 and st < 0.5 and not _vented:
		_vented = true
		_puff(Vector2(1182, 474), 14, 70.0)
		Sfx.play("lever", -14.0, 1.6)
	elif st < 0.0:
		_vented = false
	# A pipe leaks now and then.
	_next_leak -= delta
	if _next_leak <= 0.0:
		_next_leak = randf_range(9.0, 22.0)
		var spots := [Vector2(645, 132), Vector2(645, 476), Vector2(690, 6)]
		_puff(spots[randi() % spots.size()], 6, 40.0)
	# Condensation runs down a seam.
	_next_drip -= delta
	if _next_drip <= 0.0:
		_next_drip = randf_range(1.5, 5.0)
		var seams := [4.0, 160.0, 320.0, 480.0, 645.0, 1276.0]
		_drips.append({"x": seams[randi() % seams.size()] + randf_range(-1, 1), "y": randf_range(0, 300), "v": 0.0, "t0": now})
	for d: Dictionary in _drips:
		d["v"] = minf(float(d["v"]) + 60.0 * delta, 90.0)
		d["y"] = float(d["y"]) + float(d["v"]) * delta * (0.4 + 0.6 * float(int(now * 3.0 + float(d["x"])) % 2))
	_drips = _drips.filter(func(d: Dictionary) -> bool: return float(d["y"]) < 730.0 and now - float(d["t0"]) < 14.0)
	for p: Dictionary in _puffs:
		if now >= float(p["t0"]):
			p["p"] = (p["p"] as Vector2) + (p["v"] as Vector2) * delta
			p["v"] = (p["v"] as Vector2) * (1.0 - 0.8 * delta)
	_puffs = _puffs.filter(func(p: Dictionary) -> bool: return now - float(p["t0"]) < 2.2)
	# The work lamp stutters once in a while.
	_next_flicker -= delta
	if _next_flicker <= 0.0:
		_next_flicker = randf_range(18.0, 45.0)
		_flicker = 0.35
	_flicker = maxf(0.0, _flicker - delta)
	queue_redraw()


func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for p: Dictionary in _puffs:
		var age := now - float(p["t0"])
		if age < 0.0:
			continue
		var a := clampf(1.0 - age / 2.2, 0.0, 1.0)
		var r := float(p["r"]) * (1.0 + age * 1.6)
		Desk.draw_glow(self, p["p"], r, Color(0.85, 0.88, 0.85, 0.22 * a))
	for d: Dictionary in _drips:
		var x := float(d["x"])
		var y := float(d["y"])
		draw_line(Vector2(x, maxf(0.0, y - 40.0)), Vector2(x, y), Color(0.6, 0.75, 0.7, 0.06), 1.5)
		draw_circle(Vector2(x, y), 1.6, Color(0.8, 0.95, 0.9, 0.5))
		draw_circle(Vector2(x - 0.5, y - 0.5), 0.6, Color(1, 1, 1, 0.7))
	# Lamp flicker: the whole desk dips for a few frames, and a constant faint unsteadiness.
	var dip := 0.0
	if _flicker > 0.0:
		dip = 0.25 if int(now * 30.0) % 3 != 0 else 0.05
	dip += 0.015 * (0.5 + 0.5 * sin(now * 9.3) * sin(now * 3.1))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, dip))
