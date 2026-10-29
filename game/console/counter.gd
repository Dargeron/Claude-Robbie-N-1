class_name DebtCounter
extends Control
## The Company's counter: what the operator owes, on rolling number wheels. Every hull lost
## is charged to the contract, and the wheels roll up with a clatter. Under it, the wage in hand
## (survey fees and lost beacons pay into it; the hangar spends it), and the hulls lost.

var debt := 0
var lost := 0
var wage := 0
var _shown := -1.0               # the value the wheels show right now (rolls towards debt)
var _lost_shown := -1.0
var _wage_shown := -1.0
var _clatter := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(d: int, l: int, w: int = 0) -> void:
	if _shown < 0.0:
		_shown = float(d)
		_lost_shown = float(l)
		_wage_shown = float(w)
	debt = d
	lost = l
	wage = w


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
	if absf(_wage_shown - wage) > 0.5:
		_wage_shown = move_toward(_wage_shown, float(wage), maxf(400.0, absf(wage - _wage_shown) * 1.8) * delta)
		_clatter += delta
		if _clatter > 0.06:
			_clatter = 0.0
			Sfx.play("relay", -14.0, 2.0)
	else:
		_wage_shown = float(wage)
	queue_redraw()


func _draw() -> void:
	var co := Desk.r("counter")
	var o := co.position - position
	var f := Desk.font("plate")
	var paint := Color(Desk.STENCIL, 0.7)
	Desk.centred(self, Rect2(o + Vector2(0, 4), Vector2(co.size.x, 11)), "OWING", f, 10, paint)
	Desk.draw_odometer(self, Rect2(o + Vector2(10, 15), Vector2(co.size.x - 20, 25)), _shown, 6, 17)
	Desk.centred(self, Rect2(o + Vector2(0, 42), Vector2(co.size.x, 11)), "IN HAND", f, 10, paint)
	Desk.draw_odometer(self, Rect2(o + Vector2(10, 53), Vector2(co.size.x - 20, 25)), _wage_shown, 6, 17,
		Color(0.12, 0.2, 0.14), Color(0.86, 0.95, 0.82))
	# The hulls lost, on two small wheels of their own, red-faced.
	draw_string(f, o + Vector2(16, 95), "HULLS LOST", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, paint)
	Desk.draw_odometer(self, Rect2(o + Vector2(70, 82), Vector2(30, 18)), _lost_shown, 2, 13,
		Color(0.72, 0.16, 0.1), Color(0.95, 0.9, 0.8))
	var pr := Desk.plaque_rect("counter")
	Desk.engraved(self, Rect2(pr.position - position, pr.size), Desk.plaque("counter")[4], 13)
