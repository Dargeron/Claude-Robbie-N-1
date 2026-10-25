class_name DebtCounter
extends Control
## The Company's counter: what the operator owes, on rolling number wheels. Every hull lost
## is charged to the contract, and the wheels roll up with a clatter. Below it, the hulls lost.

var debt := 0
var lost := 0
var _shown := -1.0               # the value the wheels show right now (rolls towards debt)
var _lost_shown := -1.0
var _clatter := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(d: int, l: int) -> void:
	if _shown < 0.0:
		_shown = float(d)
		_lost_shown = float(l)
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
	_lost_shown = move_toward(_lost_shown, float(lost), delta * 2.0)
	queue_redraw()


func _draw() -> void:
	var co := Desk.r("counter")
	var win := Rect2(co.position + Vector2(10, 34) - position, Vector2(co.size.x - 20, 38))
	Desk.draw_odometer(self, win, _shown, 6, 24)
	# The hulls lost, on two small wheels of their own, red-faced.
	var f := Desk.font("plate")
	Desk.centred(self, Rect2(co.position + Vector2(0, 74) - position, Vector2(co.size.x, 12)), "HULLS LOST", f, 10, Color(Desk.STENCIL, 0.7))
	Desk.draw_odometer(self, Rect2(co.position + Vector2(co.size.x * 0.5 - 22, 86) - position, Vector2(44, 22)), _lost_shown, 2, 17,
		Color(0.72, 0.16, 0.1), Color(0.95, 0.9, 0.8))
	Desk.centred(self, Rect2(co.position + Vector2(0, 10) - position, Vector2(co.size.x, 16)), "SCRIP", f, 12, Color(Desk.STENCIL, 0.6))
	var pr := Desk.plaque_rect("counter")
	Desk.engraved(self, Rect2(pr.position - position, pr.size), Desk.plaque("counter")[4], 13)
