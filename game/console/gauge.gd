class_name LoadGauge
extends Control
## The card reader's load: what the deck weighs against what Robbie's reader can hold (the
## CPU budget). Past the red line the reader refuses the deck.

var used := 0
var budget := 10
var _needle := 0.0
var _vel := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_load(u: int, b: int) -> void:
	used = u
	budget = b


func _top() -> int:
	return budget + 4


func _process(delta: float) -> void:
	var target := clampf(float(used) / float(_top()), 0.0, 1.04)
	# A damped spring: the needle overshoots a little and settles.
	_vel += (target - _needle) * 90.0 * delta
	_vel *= exp(-9.0 * delta)
	_needle += _vel * delta
	queue_redraw()


func _draw() -> void:
	var g := Desk.v("gauge_c")
	var c := Vector2(float(g[0]), float(g[1])) - position
	var rad := float(g[2]) - 1.0
	# The enamel face.
	var face := PackedVector2Array()
	for i in 49:
		var a := PI + PI * i / 48.0
		face.append(c + Vector2.from_angle(a) * rad)
	face.append(c + Vector2(rad, 2))
	face.append(c + Vector2(-rad, 2))
	draw_colored_polygon(face, Color(0.84, 0.79, 0.66))
	var t := Desk.tex("paper")
	if t != null:
		var uvs := PackedVector2Array()
		for p in face:
			uvs.append(p / 512.0)
		draw_polygon(face, PackedColorArray([Color(1, 1, 1, 0.5)]), uvs, t)
	# Red zone past the budget.
	var top := _top()
	var a0 := PI + PI * float(budget) / top
	var red := PackedVector2Array()
	for i in 13:
		red.append(c + Vector2.from_angle(lerpf(a0, TAU, i / 12.0)) * (rad - 4.0))
	for i in 13:
		red.append(c + Vector2.from_angle(lerpf(TAU, a0, i / 12.0)) * (rad - 16.0))
	draw_colored_polygon(red, Color(0.7, 0.12, 0.08, 0.85))
	# Ticks and numbers.
	var f := Desk.font("plate")
	for v in top + 1:
		var a := PI + PI * float(v) / top
		var major := v % 2 == 0
		var d := Vector2.from_angle(a)
		draw_line(c + d * (rad - 4.0), c + d * (rad - (14.0 if major else 9.0)), Desk.INK, 2.0 if major else 1.0)
		if major:
			Desk.centred(self, Rect2(c + d * (rad - 26.0) - Vector2(10, 8), Vector2(20, 16)), str(v), f, 13, Desk.INK)
	# The reading.
	var over := used > budget
	Desk.centred(self, Rect2(c + Vector2(-40, -58), Vector2(80, 14)), "REFUSED" if over else "HOLES", f, 12 if over else 10,
		Desk.RED_INK if over else Desk.INK_SOFT)
	# The needle.
	var na := PI + PI * clampf(_needle, -0.02, 1.04)
	var nd := Vector2.from_angle(na)
	draw_line(c + Vector2(2, 3), c + nd * (rad - 8.0) + Vector2(2, 3), Color(0, 0, 0, 0.3), 3.0)
	draw_line(c - nd * 12.0, c + nd * (rad - 8.0), Color(0.1, 0.08, 0.06), 2.5)
	draw_circle(c, 6.0, Color(0.35, 0.27, 0.15))
	draw_circle(c + Vector2(-1.5, -1.5), 2.0, Color(0.9, 0.75, 0.45, 0.6))
	# Glass.
	draw_arc(c, rad - 3.0, PI * 1.12, PI * 1.45, 16, Color(1, 1, 1, 0.12), 6.0)
	Desk.engraved(self, Rect2(Desk.plaque_rect("gauge").position - position, Desk.plaque_rect("gauge").size),
		"READER LOAD  ·  %d / %d" % [used, budget], 13, Desk.RED_LAMP if over else Desk.ENGRAVE)
