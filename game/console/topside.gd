class_name Topside
extends RefCounted
## Small machines along the top of the console: the Company tube, the sector selector,
## the shift counter and the hangar window. (Bathy's porthole is in porthole.gd.)


## The pneumatic tube: brass capsules from the Company drop into the window. Tap one to read it.
class Tube:
	extends Control
	signal opened
	var pending := 0
	var _drop := 0.0          # 0 resting .. 1 just released at the top
	var _vel := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func deliver() -> void:
		pending += 1
		_drop = 1.0
		_vel = 0.0

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and pending > 0:
			Sfx.play("paper", -4.0)
			opened.emit()
			accept_event()

	func _process(delta: float) -> void:
		if _drop > 0.0:
			_vel += delta * 5.0
			_drop = maxf(0.0, _drop - _vel * delta)
			if _drop == 0.0:
				Sfx.play("thump", -2.0)
		queue_redraw()

	func _draw() -> void:
		var w := Desk.r("tube_window")
		var wr := Rect2(w.position - position, w.size)
		var now := Time.get_ticks_msec() / 1000.0
		draw_rect(wr.grow(-2), Color(0.02, 0.03, 0.03))
		if pending > 0:
			var y := wr.end.y - 32.0 - _drop * (wr.size.y + 30.0)
			if y > wr.position.y - 40.0:
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				var clip_top := wr.position.y
				if y + 30 > clip_top:
					Desk.draw_sprite(self, "capsule", Vector2(wr.get_center().x, maxf(y, clip_top + 4.0) + 26.0))
			# The receiver lamp blinks while something waits.
			var a := 0.5 + 0.5 * sin(now * 5.0)
			Desk.draw_glow(self, Vector2(wr.get_center().x, wr.position.y - 8.0), 14.0, Color(Desk.RED_LAMP, 0.6 * a))
			draw_circle(Vector2(wr.get_center().x, wr.position.y - 8.0), 3.0, Color(Desk.RED_LAMP, 0.5 + 0.5 * a))
		else:
			draw_circle(Vector2(wr.get_center().x, wr.position.y - 8.0), 3.0, Color(0.15, 0.04, 0.03))
		# Glass.
		draw_rect(Rect2(wr.position + Vector2(6, 4), Vector2(6, wr.size.y - 8)), Color(1, 1, 1, 0.07))
		draw_rect(Rect2(wr.position + Vector2(15, 4), Vector2(2, wr.size.y - 8)), Color(1, 1, 1, 0.05))
		var pr := Desk.plaque_rect("tube")
		Desk.engraved(self, Rect2(pr.position - position, pr.size), Desk.plaque("tube")[4], 10)


## The sector selector: a bakelite knob with six positions; only the sectors the Company
## has opened will take it. Drag the knob or tap a name.
class SectorDial:
	extends Control
	signal chosen(i: int)
	var names: Array[String] = []
	var open: Array[bool] = []
	var certified: Array[bool] = []
	var index := 0
	var _angle := 0.0
	var _drag := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _c() -> Vector2:
		return Desk.r("sector_knob").get_center() - position

	func _pos_angle(i: int) -> float:
		return deg_to_rad(-160.0 + 28.0 * i)

	func _label_pos(i: int) -> Vector2:
		return _c() + Vector2.from_angle(_pos_angle(i)) * 56.0

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				for i in names.size():
					if event.position.distance_to(_label_pos(i)) < 16.0:
						_choose(i)
						accept_event()
						return
				if event.position.distance_to(_c()) < 32.0:
					_drag = true
					accept_event()
			elif _drag:
				_drag = false
				var best := index
				var bd := 99.0
				for i in names.size():
					var d := absf(wrapf(_angle - _pos_angle(i), -PI, PI))
					if d < bd and open[i]:
						bd = d
						best = i
				_choose(best)
		elif event is InputEventMouseMotion and _drag:
			_angle = (event.position - _c()).angle()
			queue_redraw()

	func _choose(i: int) -> void:
		if i < 0 or i >= names.size():
			return
		if not open[i]:
			Sfx.play("switch", -8.0, 0.5)
			return
		if i != index:
			Sfx.play("drum", -4.0, 0.6)
			index = i
			chosen.emit(i)
		queue_redraw()

	func _process(delta: float) -> void:
		if not _drag:
			_angle = lerp_angle(_angle, _pos_angle(index), minf(1.0, delta * 12.0))
		queue_redraw()

	func _draw() -> void:
		var f := Desk.font("plate")
		for i in names.size():
			var p := _label_pos(i)
			var col := Color(0.85, 0.75, 0.55, 0.8) if open[i] else Color(0.4, 0.36, 0.3, 0.45)
			if i == index:
				col = Desk.AMBER_HOT
				Desk.draw_glow(self, p, 14.0, Color(Desk.AMBER, 0.25))
			Desk.centred(self, Rect2(p - Vector2(10, 8), Vector2(20, 16)), str(i + 1), f, 14, col)
			if certified[i]:
				draw_circle(p + Vector2(8, -7), 2.0, Desk.GREEN_LAMP)
		Desk.draw_sprite(self, "knob_sector", _c(), _angle + PI * 0.5, Color.WHITE, 0.9)
		var pr := Desk.plaque_rect("sector")
		Desk.engraved(self, Rect2(pr.position - position, pr.size), Desk.plaque("sector")[4], 13)


## The shift counter: two nixie tubes.
class Nixies:
	extends Control
	var value := 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var f := Desk.font("crt")
		var now := Time.get_ticks_msec() / 1000.0
		var digits := "%02d" % value
		for i in 2:
			var r := Rect2(Vector2(14 + i * 34, 18), Vector2(30, 82))
			var c := r.get_center() + Vector2(0, -4)
			draw_rect(r.grow(-3), Color(0.06, 0.03, 0.02, 0.9))
			# The unlit cathodes stacked behind.
			for d in 10:
				Desk.centred(self, Rect2(c - Vector2(15, 26), Vector2(30, 52)), str(d), f, 54, Color(0.45, 0.3, 0.2, 0.06))
			var flick := 0.92 + 0.08 * sin(now * 37.0 + i)
			Desk.draw_glow(self, c, 30.0, Color(1.0, 0.45, 0.12, 0.45 * flick))
			Desk.centred(self, Rect2(c - Vector2(15, 26), Vector2(30, 52)), digits[i], f, 54, Color(1.0, 0.62, 0.25, flick))
			# Glass.
			draw_rect(Rect2(r.position + Vector2(5, 6), Vector2(4, r.size.y - 16)), Color(1, 1, 1, 0.08))
			draw_arc(Vector2(r.get_center().x, r.position.y + 12), 11.0, PI, TAU, 12, Color(1, 1, 1, 0.1), 1.5)
		var pr := Desk.plaque_rect("shift")
		Desk.engraved(self, Rect2(pr.position - position, pr.size), Desk.plaque("shift")[4], 13)


## The hangar behind the console, through a small window: the spare hulls on their chains.
## Sealed for now.
class HangarWindow:
	extends Control
	signal tapped
	var hulls := 3

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			tapped.emit()
			accept_event()

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var v := Desk.r("hangar_view")
		var r := Rect2(v.position - position, v.size)
		var now := Time.get_ticks_msec() / 1000.0
		draw_rect(r, Color(0.03, 0.035, 0.035))
		# The work lamp's pool of light at the far end.
		Desk.draw_glow(self, r.position + Vector2(r.size.x * 0.62, 6), 60.0, Color(1.0, 0.75, 0.4, 0.22))
		# Hulls hanging on chains, swaying a little.
		for i in hulls:
			var x := r.position.x + 22.0 + i * 36.0
			var sway := sin(now * 0.7 + i * 1.9) * 1.5
			var top := Vector2(x, r.position.y)
			var body := Vector2(x + sway, r.position.y + 46.0 + (i % 2) * 6.0)
			for s in 8:
				var p := top.lerp(body - Vector2(0, 12), s / 8.0)
				draw_arc(p, 1.6, 0, TAU, 6, Color(0.35, 0.3, 0.22, 0.8), 1.0)
			var lit := 0.55 if i == 1 else 0.3
			draw_circle(body, 12.0, Color(0.55 * lit, 0.42 * lit, 0.22 * lit))
			draw_circle(body + Vector2(-9, 8), 4.0, Color(0.45 * lit, 0.34 * lit, 0.18 * lit))
			draw_circle(body + Vector2(9, 8), 4.0, Color(0.45 * lit, 0.34 * lit, 0.18 * lit))
			draw_circle(body + Vector2(0, -1), 6.0, Color(0.05, 0.06, 0.07))
			draw_arc(body + Vector2(0, -1), 6.0, 0, TAU, 16, Color(0.7 * lit, 0.55 * lit, 0.3 * lit), 1.2)
			draw_string(Desk.font("plate"), body + Vector2(-8, 22), "N+%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.7, 0.5, 0.35))
		# Sealed: stencilled tape across the glass.
		draw_set_transform(r.get_center(), -0.18, Vector2.ONE)
		draw_rect(Rect2(-70, -9, 140, 18), Color(0.75, 0.6, 0.12, 0.85))
		for s in 9:
			draw_colored_polygon(PackedVector2Array([Vector2(-70 + s * 16, -9), Vector2(-62 + s * 16, -9), Vector2(-70 + s * 16 + 0, 9), Vector2(-78 + s * 16, 9)]), Color(0.08, 0.07, 0.05, 0.85))
		Desk.centred(self, Rect2(-70, -9, 140, 18), "SEALED · AUDIT", Desk.font("plate"), 13, Color(0.05, 0.04, 0.02))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x * 0.3, 3)), Color(1, 1, 1, 0.06))
		var pr := Desk.plaque_rect("hangar")
		Desk.engraved(self, Rect2(pr.position - position, pr.size), Desk.plaque("hangar")[4], 13)
