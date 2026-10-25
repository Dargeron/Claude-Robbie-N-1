class_name MemoView
extends Control
## Paper laid over the console: a Company memo out of the tube, the end-of-shift tally, a
## letter in Op. 5's hand, or the binder with its tabs. Drag the sheet about; tap outside
## it (or the FILE stamp) to put it away.

signal closed
signal start_over

var paper: Control
var body: RichTextLabel
var tabs: Array = []             # binder: [[title, bbcode], ...]
var tab := 0
var memo: Dictionary = {}
var _drag := false
var _grab := Vector2.ZERO
var _in := 0.0
var _confirm := false


func _init() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	paper = Control.new()
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	paper.gui_input.connect(_paper_input)
	paper.draw.connect(_draw_paper)
	add_child(paper)
	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.scroll_active = true
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_theme_font_override("normal_font", Desk.font("type"))
	body.add_theme_font_override("bold_font", Desk.font("type"))
	body.add_theme_font_override("italics_font", Desk.font("hand"))
	body.add_theme_font_size_override("normal_font_size", 15)
	body.add_theme_font_size_override("bold_font_size", 15)
	body.add_theme_font_size_override("italics_font_size", 19)
	body.add_theme_color_override("default_color", Desk.INK)
	body.add_theme_constant_override("line_separation", 3)
	var sb := StyleBoxEmpty.new()
	body.add_theme_stylebox_override("normal", sb)
	body.add_theme_stylebox_override("focus", sb)
	paper.add_child(body)


## memo: {kind: memo|tally|letter, ref, to, from, subject, body (bbcode), stamp, date}
func show_memo(m: Dictionary) -> void:
	memo = m
	tabs = []
	var letter: bool = m.get("kind", "memo") == "letter"
	paper.size = Vector2(560, 600) if not letter else Vector2(480, 520)
	paper.position = Vector2(640 - paper.size.x * 0.5, 60)
	paper.rotation = deg_to_rad(-1.2 if not letter else 1.6)
	paper.pivot_offset = paper.size * 0.5
	var top := 168.0 if not letter else 40.0
	body.position = Vector2(46, top)
	body.size = Vector2(paper.size.x - 92, paper.size.y - top - 70)
	if letter:
		body.text = "[i]%s[/i]" % m.get("body", "")
		body.add_theme_color_override("default_color", Color(0.16, 0.13, 0.25))
	else:
		body.text = m.get("body", "")
		body.add_theme_color_override("default_color", Desk.INK)
	_open()


## The binder: tabs of reference pages.
func show_binder(pages: Array, start := 0) -> void:
	memo = {"kind": "binder"}
	tabs = pages
	tab = start
	paper.size = Vector2(640, 620)
	paper.position = Vector2(320, 50)
	paper.rotation = deg_to_rad(0.6)
	paper.pivot_offset = paper.size * 0.5
	body.position = Vector2(44, 84)
	body.size = Vector2(paper.size.x - 88, paper.size.y - 130)
	body.add_theme_color_override("default_color", Desk.INK)
	body.text = tabs[tab][1]
	_open()


func _open() -> void:
	visible = true
	_in = 0.0
	move_to_front()
	Sfx.play("paper", -4.0)
	queue_redraw()
	paper.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()
		accept_event()


func _close() -> void:
	Sfx.play("paper", -8.0, 0.9)
	visible = false
	closed.emit()


func _paper_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var p: Vector2 = event.position
			if _file_rect().has_point(p):
				Sfx.play("stamp", -4.0)
				_close()
				paper.accept_event()
				return
			if _start_rect().has_point(p) and _on_contract():
				if _confirm:
					Sfx.play("tear", 0.0)
					_confirm = false
					start_over.emit()
					_close()
				else:
					_confirm = true
					Sfx.play("stamp", -6.0)
					paper.queue_redraw()
				paper.accept_event()
				return
			if not tabs.is_empty():
				for i in tabs.size():
					if _tab_rect(i).has_point(p):
						tab = i
						_confirm = false
						body.text = tabs[i][1]
						body.scroll_to_line(0)
						Sfx.play("paper", -10.0, 1.2)
						paper.queue_redraw()
						paper.accept_event()
						return
			_drag = true
			_grab = p
			paper.accept_event()
		else:
			_drag = false
	elif event is InputEventMouseMotion and _drag:
		paper.position += (event.position - _grab).rotated(paper.rotation)
		paper.position = paper.position.clamp(Vector2(-paper.size.x * 0.6, -paper.size.y * 0.6), Vector2(1280 - paper.size.x * 0.4, 720 - 80))


func _on_contract() -> bool:
	return not tabs.is_empty() and str(tabs[tab][0]) == "CONTRACT"


func _start_rect() -> Rect2:
	return Rect2(Vector2(paper.size.x * 0.5 - 140, paper.size.y - 200), Vector2(280, 64))


func _file_rect() -> Rect2:
	return Rect2(paper.size - Vector2(150, 62), Vector2(120, 40))


func _tab_rect(i: int) -> Rect2:
	var w := (paper.size.x - 60.0) / maxf(1.0, tabs.size())
	return Rect2(30.0 + i * w, 24.0, w - 6.0, 34.0)


func _process(delta: float) -> void:
	if visible and _in < 1.0:
		_in = minf(1.0, _in + delta * 5.0)
		queue_redraw()
		paper.modulate.a = _in
		paper.scale = Vector2.ONE * (0.94 + 0.06 * _in)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55 * _in))


func _stamp_text(r: Rect2, text: String, size_px: int) -> void:
	Desk.centred(paper, r, text, Desk.font("plate"), size_px, Color(Desk.RED_INK, 0.9))


func _draw_paper() -> void:
	var r := Rect2(Vector2.ZERO, paper.size)
	var kind: String = memo.get("kind", "memo")
	var base := Desk.PAPER if kind != "letter" else Desk.NOTE.lerp(Desk.PAPER, 0.55)
	Desk.draw_paper(paper, r, base, 11 + int(paper.size.x), true)
	var lh := Desk.font("letterhead")
	var ty := Desk.font("type")
	var pl := Desk.font("plate")
	if kind == "binder":
		for i in tabs.size():
			var tr := _tab_rect(i)
			paper.draw_rect(tr, Color(0.72, 0.66, 0.5) if i == tab else Color(0.6, 0.55, 0.42))
			paper.draw_rect(tr, Color(0.3, 0.22, 0.1, 0.5), false, 1.0)
			Desk.centred(paper, tr, str(tabs[i][0]), pl, 15, Desk.INK if i == tab else Desk.INK_SOFT)
		paper.draw_line(Vector2(30, 60), Vector2(paper.size.x - 30, 60), Color(0.3, 0.22, 0.1, 0.5), 1.0)
		for y in [120.0, 300.0, 480.0]:
			paper.draw_circle(Vector2(18, y), 7.0, Color(0.05, 0.05, 0.04, 0.85))
	elif kind != "letter":
		Desk.centred(paper, Rect2(0, 30, r.size.x, 30), "THE COMPANY", lh, 28, Desk.INK)
		Desk.centred(paper, Rect2(0, 60, r.size.x, 18), memo.get("from", "DIRECTORATE OF DEEP ASSETS  ·  JOVIAN STATION 9"), lh, 11, Desk.INK_SOFT)
		paper.draw_line(Vector2(46, 86), Vector2(r.size.x - 46, 86), Desk.INK, 1.5)
		paper.draw_line(Vector2(46, 89), Vector2(r.size.x - 46, 89), Desk.INK, 0.6)
		var hy := 110.0
		for pair: Array in [["REF", memo.get("ref", "")], ["TO", memo.get("to", "OPERATOR 6")], ["RE", memo.get("subject", "")]]:
			paper.draw_string(ty, Vector2(46, hy), str(pair[0]) + ":", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Desk.INK_SOFT)
			paper.draw_string(ty, Vector2(96, hy), str(pair[1]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 150, 13, Desk.INK)
			hy += 18.0
	# A stamp, if the Company stamped it.
	var stamp: String = memo.get("stamp", "")
	if stamp != "":
		var sw := pl.get_string_size(stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 24.0
		paper.draw_set_transform(Vector2(r.size.x - sw - 40, 120), -0.18, Vector2.ONE)
		var sc := Desk.RED_INK if stamp != "CERTIFIED" else Color(0.1, 0.35, 0.18)
		paper.draw_rect(Rect2(0, 0, sw, 44), Color(sc, 0.75), false, 3.0)
		paper.draw_string(pl, Vector2(12, 33), stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(sc, 0.8))
		paper.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _on_contract():
		var sr := _start_rect()
		paper.draw_set_transform(sr.get_center(), -0.05, Vector2.ONE)
		var rr := Rect2(-sr.size * 0.5, sr.size)
		paper.draw_rect(rr, Color(Desk.RED_INK, 0.8), false, 3.0)
		_stamp_text(rr, "TAP AGAIN: TEAR IT UP" if _confirm else "TEAR UP THE CONTRACT", 22)
		paper.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# File it.
	var fr := _file_rect()
	paper.draw_rect(fr, Color(Desk.INK, 0.6), false, 2.0)
	Desk.centred(paper, fr, "FILE IT" if kind != "binder" else "CLOSE", pl, 20, Color(Desk.INK, 0.75))
	if kind == "letter":
		paper.draw_string(Desk.font("hand"), Vector2(paper.size.x - 150, paper.size.y - 80), "— Op. 5", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.16, 0.13, 0.25))
