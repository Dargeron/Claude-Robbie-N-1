class_name DebtCounter
extends Control
## The Company's counter: what the operator owes, on rolling number wheels. Every hull lost
## is charged to the contract, and the wheels roll up with a clatter. Below it, the hulls lost.

var debt := 0
var lost := 0
var _shown := -1.0               # the value the wheels show right now (rolls towards debt)
var _clatter := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(d: int, l: int) -> void:
	if _shown < 0.0:
		_shown = float(d)
	debt = d
	lost = l


func _process(delta: float) -> void:
	if absf(_shown - debt) > 0.5:
		var step := maxf(400.0, absf(debt - _shown) * 1.8) * delta
		_shown = move_toward(_shown, float(debt), step)
		_clatter += delta
		if _clatter > 0.06:
			_clatter = 0.0
			Sfx.play("relay", -14.0, 1.6)
	else:
		_shown = float(debt)
	queue_redraw()


func _draw() -> void:
	var co := Desk.r("counter")
	var win := Rect2(co.position + Vector2(10, 34) - position, Vector2(co.size.x - 20, 38))
	var f := Desk.font("plate")
	var digits := 6
	var cw := win.size.x / digits
	var value := maxf(_shown, 0.0)
	for i in digits:
		# Odometer: each wheel turns with the one to its right as it passes 9.
		var place := pow(10.0, digits - 1 - i)
		var v := fmod(value / place, 10.0)
		var below := fmod(value, place)
		# A wheel turns only while every wheel to its right is rolling over from 9 to 0.
		var turning := clampf(below - (place - 1.0), 0.0, 1.0) if place > 1.0 else 0.0
		var d := floorf(v)
		var frac := (v - d) if place == 1.0 else turning
		var r := Rect2(win.position + Vector2(i * cw + 1, 0), Vector2(cw - 2, win.size.y))
		draw_rect(r, Color(0.9, 0.87, 0.78))
		# The digit showing rolls up and out as the next rolls in under it.
		for k in 2:
			var n := int(d + k) % 10
			var cy := r.get_center().y + (k - frac) * r.size.y
			if cy < r.position.y - 6.0 or cy > r.end.y + 6.0:
				continue
			Desk.centred(self, Rect2(Vector2(r.position.x, cy - 13.0), Vector2(r.size.x, 26)), str(n), f, 24, Color(0.08, 0.06, 0.05))
		# The curve of the wheel: darker top and bottom.
		for b in 6:
			var a := 0.09 * (6 - b)
			draw_rect(Rect2(r.position + Vector2(0, b * 2.0), Vector2(r.size.x, 2.0)), Color(0, 0, 0, a))
			draw_rect(Rect2(Vector2(r.position.x, r.end.y - (b + 1) * 2.0), Vector2(r.size.x, 2.0)), Color(0, 0, 0, a))
	draw_rect(win, Color(0, 0, 0, 0.6), false, 1.0)
	var lw := Rect2(co.position + Vector2(26, 84) - position, Vector2(co.size.x - 52, 24))
	Desk.centred(self, lw, "HULLS LOST  %02d" % lost, f, 14, Color(Desk.RED_LAMP, 0.85) if lost > 0 else Color(Desk.STENCIL, 0.6))
	Desk.centred(self, Rect2(co.position + Vector2(0, 10) - position, Vector2(co.size.x, 16)), "SCRIP", f, 12, Color(Desk.STENCIL, 0.6))
	var pr := Desk.plaque_rect("counter")
	Desk.engraved(self, Rect2(pr.position - position, pr.size), Desk.plaque("counter")[4], 13)
