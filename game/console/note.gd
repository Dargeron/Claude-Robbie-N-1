class_name OpNote
extends Control
## One of Op. 5's notes, taped to the console: yellow paper, his handwriting, sometimes a
## pencil arrow at the thing he means. Drag it out of the way; it stays where you put it.
## When its job is done it peels off and falls.

signal dropped

var text := ""
var target := Vector2(-1, -1)    # console position the arrow points at, or (-1, -1)
var tilt := 0.0
var moved := false               # the operator put it somewhere: leave it there
var home := Vector2.ZERO         # where the console wants it
var _drag := false
var _grab := Vector2.ZERO
var _falling := 0.0
var _born := 0.0


static func make(t: String, at: Vector2, w: float = 190.0, arrow_to := Vector2(-1, -1)) -> OpNote:
	var n := OpNote.new()
	n.text = t
	n.target = arrow_to
	var f := Desk.font("hand")
	var lines := f.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, 17).y
	n.size = Vector2(w, lines + 30.0)
	n.position = at
	n.tilt = deg_to_rad(float((t.length() * 37) % 7) - 3.0)
	return n


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_born = Time.get_ticks_msec() / 1000.0


func peel() -> void:
	if _falling == 0.0:
		_falling = 0.001
		Sfx.play("paper", -10.0, 1.2)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag = true
			_grab = event.position
			move_to_front()
			Sfx.play("paper", -14.0)
			accept_event()
		else:
			_drag = false
			dropped.emit()
	elif event is InputEventMouseMotion and _drag:
		moved = true
		position += event.position - _grab
		position = position.clamp(Vector2(-size.x * 0.5, 0), Vector2(1280 - size.x * 0.5, 720 - 30))
		queue_redraw()


func _process(delta: float) -> void:
	if not moved and _falling == 0.0 and home != Vector2.ZERO and position.distance_to(home) > 0.5:
		position = position.lerp(home, minf(1.0, delta * 8.0))
	if _falling > 0.0:
		_falling += delta
		position.y += _falling * 2400.0 * delta
		rotation += delta * 2.0
		modulate.a = clampf((0.55 - _falling) * 5.0, 0.0, 1.0)
		if _falling > 0.55:
			queue_free()
	queue_redraw()


func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var pop := clampf((now - _born) / 0.25, 0.0, 1.0)
	# The pencil arrow, under the paper.
	if target.x >= 0.0 and _falling == 0.0:
		var from := Vector2(size.x * 0.5, size.y * 0.5)
		var to := target - global_position
		var mid := (from + to) * 0.5 + (to - from).orthogonal().normalized() * 26.0
		var pts := PackedVector2Array()
		for i in 17:
			var t := i / 16.0
			pts.append(from.lerp(mid, t).lerp(mid.lerp(to, t), t))
		var start := 0
		while start < pts.size() - 2 and Rect2(Vector2.ZERO, size).grow(4).has_point(pts[start]):
			start += 1
		if pts.size() - start >= 3:
			var seg := pts.slice(start)
			draw_polyline(seg, Color(0.85, 0.82, 0.7, 0.55 * pop), 1.6, true)
			var tip := seg[seg.size() - 1]
			var d := (tip - seg[seg.size() - 3]).normalized()
			draw_line(tip, tip - d.rotated(0.5) * 9.0, Color(0.85, 0.82, 0.7, 0.55 * pop), 1.6)
			draw_line(tip, tip - d.rotated(-0.5) * 9.0, Color(0.85, 0.82, 0.7, 0.55 * pop), 1.6)
	draw_set_transform(size * 0.5, tilt, Vector2.ONE * (0.9 + 0.1 * pop))
	var r := Rect2(-size * 0.5, size)
	Desk.draw_paper(self, r, Desk.NOTE, int(size.x + size.y), true)
	# Tape at the top.
	draw_rect(Rect2(Vector2(-22, r.position.y - 7), Vector2(44, 14)), Color(0.9, 0.88, 0.75, 0.55))
	var f := Desk.font("hand")
	draw_multiline_string(f, r.position + Vector2(10, 24), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20.0, 17, -1, Color(0.16, 0.13, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
