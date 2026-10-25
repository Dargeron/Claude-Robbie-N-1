class_name Drum
extends Control
## A printed drum behind a window: roll it by dragging up or down, or tap above or below
## the index line to turn it one step. Entries are labels; `index` is the one at the line.

signal turned(index: int)

const ROW := 0.52        # radians between rows on the drum

var entries: Array[String] = []
var index := 0
var font_size := 17
var locked := false      # greyed and still (the plate isn't fitted)
var wrap := false        # a full drum: the last entry sits just above the first
var shade := 1.0         # how dark the drum turns away from the window's middle
var fresh := {}          # entry label -> time it arrived (a new type plate glints)
var _roll := 0.0         # fractional index shown
var _press := false
var _press_y := 0.0
var _press_roll := 0.0
var _moved := false
var _last_detent := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func set_entries(e: Array[String], keep := "") -> void:
	entries = e
	var at := entries.find(keep) if keep != "" else -1
	index = clampi(at if at >= 0 else index, 0, maxi(entries.size() - 1, 0))
	_roll = float(index)
	queue_redraw()


func select(i: int) -> void:
	index = _fit(i)
	_near()
	queue_redraw()


func _fit(i: int) -> int:
	if wrap and entries.size() > 0:
		return posmod(i, entries.size())
	return clampi(i, 0, maxi(entries.size() - 1, 0))


## On a full drum, roll the short way round to the new entry.
func _near() -> void:
	if wrap and entries.size() > 0:
		_roll = index + wrapf(_roll - index, -entries.size() * 0.5, entries.size() * 0.5)


func current() -> String:
	return entries[index] if index < entries.size() else ""


func _gui_input(event: InputEvent) -> void:
	if locked or entries.size() <= 1:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = true
			_moved = false
			_press_y = event.position.y
			_press_roll = _roll
			_last_detent = index
			accept_event()
		elif _press:
			_press = false
			if not _moved:
				var step := -1 if event.position.y < size.y * 0.5 else 1
				_set_index(index + step)
			else:
				_set_index(int(roundf(_roll)))
	elif event is InputEventMouseMotion and _press:
		var dy: float = event.position.y - _press_y
		if absf(dy) > 4.0:
			_moved = true
		if _moved:
			_roll = _press_roll - dy / 30.0
			if not wrap:
				_roll = clampf(_roll, -0.4, entries.size() - 0.6)
			var d := _fit(int(roundf(_roll)))
			if d != _last_detent:
				_last_detent = d
				Sfx.play("drum", -12.0, 1.0 + randf() * 0.1)
			queue_redraw()


func _set_index(i: int) -> void:
	var n := _fit(i)
	if n != index:
		Sfx.play("drum", -8.0)
	index = n
	_near()
	turned.emit(index)
	queue_redraw()


func _process(delta: float) -> void:
	if not _press and absf(_roll - index) > 0.002:
		_roll = lerpf(_roll, float(index), minf(1.0, delta * 16.0))
		queue_redraw()
	elif not fresh.is_empty():
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var cy := h * 0.5
	var radius := h * 0.62
	# The drum's ivory face, shaded as a cylinder.
	var bands := 24
	for b in bands:
		var y0 := h * b / bands
		var a := asin(clampf((y0 + h / bands * 0.5 - cy) / radius, -1.0, 1.0))
		var lum := cos(a) * 0.85 + 0.15 - maxf(0.0, -sin(a)) * 0.05
		var base := Color(0.86, 0.8, 0.66) if not locked else Color(0.45, 0.43, 0.38)
		draw_rect(Rect2(0, y0, w, h / bands + 1.0), Color(base.r * lum, base.g * lum, base.b * lum))
	var f := Desk.font("type")
	var now := Time.get_ticks_msec() / 1000.0
	for i in entries.size():
		var di := float(i) - _roll
		if wrap:
			di = wrapf(di, -entries.size() * 0.5, entries.size() * 0.5)
		var a := di * ROW
		if absf(a) > 1.35:
			continue
		var y := cy + sin(a) * radius
		var sy := cos(a)
		var col := Color(Desk.INK, clampf(sy * 1.1 - 0.15, 0.0, 1.0) * (1.0 - 0.35 * (1.0 - shade) * absf(a)))
		if locked:
			col = Color(0.2, 0.2, 0.2, 0.6 * sy)
		draw_set_transform(Vector2(0, y), 0.0, Vector2(1.0, sy))
		var txt := entries[i]
		var size_now := font_size
		while f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size_now).x > w - 16 and size_now > 9:
			size_now -= 1
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size_now).x
		draw_string(f, Vector2((w - tw) * 0.5, size_now * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size_now, col)
		if fresh.has(txt) and now - float(fresh[txt]) < 30.0 and absf(a) < 0.8:
			var g := 0.5 + 0.5 * sin(now * 5.0)
			# A new type plate glints on the drum.
			draw_rect(Rect2(Vector2(4, -size_now * 0.5), Vector2(w - 8, size_now)), Color(Desk.AMBER, 0.18 * g))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The index line and the glass.
	draw_line(Vector2(0, cy - 15), Vector2(w, cy - 15), Color(0.5, 0.08, 0.05, 0.45), 1.0)
	draw_line(Vector2(0, cy + 15), Vector2(w, cy + 15), Color(0.5, 0.08, 0.05, 0.45), 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(0, cy - 6), Vector2(7, cy), Vector2(0, cy + 6)]), Color(0.75, 0.55, 0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(w, cy - 6), Vector2(w - 7, cy), Vector2(w, cy + 6)]), Color(0.75, 0.55, 0.25))
	for i in 10:
		var a2 := 0.022 * (10 - i)
		draw_rect(Rect2(0, i * 1.6, w, 1.6), Color(0, 0, 0, a2 * 9.0 * shade))
		draw_rect(Rect2(0, h - (i + 1) * 1.6, w, 1.6), Color(0, 0, 0, a2 * 9.0 * shade))
	draw_rect(Rect2(0, 3, w, h * 0.22), Color(1, 1, 1, 0.05))
