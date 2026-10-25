class_name Teleprinter
extends Control
## The teleprinter types the dive as the recording plays: contacts, cards taking over,
## hits, the end, and Robbie's own words, in a two-colour ribbon (red for harm).
## Tap a line to wind the recorder to that moment. Pull the strip up to tear it off and
## pin it to the Wall.

signal line_tapped(t: int, rule: int)
signal torn

const LINE_H := 17.0
const CPS := 70.0                # characters per second as it types

var replay: ReplayPlayer
var lines: Array = []            # from Tape.lines
var header := ""                 # what the strip says before any dive
var _shown := {}                 # line index -> wall-clock time it started typing
var _drag := false
var _drag_y := 0.0
var _pull := 0.0
var _tearing := 0.0
var _torn_after := -1            # lines up to this index were torn off
var _last_count := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


## Lines too long for the strip carry on in the row below, without a time.
func set_lines(l: Array) -> void:
	var f := Desk.font("type")
	var width := _paper().size.x - 100.0
	lines = []
	for src: Dictionary in l:
		var words: PackedStringArray = str(src["text"]).split(" ")
		var row := ""
		var first := true
		for w in words:
			var trial := w if row == "" else row + " " + w
			if row != "" and f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x > width:
				var d := src.duplicate()
				d["text"] = row
				d["cont"] = not first
				lines.append(d)
				first = false
				row = "  " + w
			else:
				row = trial
		var last := src.duplicate()
		last["text"] = row
		last["cont"] = not first
		lines.append(last)
	_shown = {}
	_torn_after = -1
	_last_count = 0
	queue_redraw()


func _paper() -> Rect2:
	var r := Desk.r("paper")
	return Rect2(r.position - position, r.size)


func _visible_count() -> int:
	if replay == null or not replay.has_dive():
		return 0
	var t := replay.view.t
	var n := 0
	for l: Dictionary in lines:
		if float(l["t"]) <= t + 0.5:
			n += 1
	return n


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag = true
			_drag_y = event.position.y
			_pull = 0.0
			accept_event()
		elif _drag:
			_drag = false
			if _pull > 46.0:
				_tear()
			elif _pull < 6.0:
				var i := _line_at(event.position)
				if i >= 0:
					line_tapped.emit(int(lines[i]["t"]), int(lines[i]["rule"]))
			_pull = 0.0
	elif event is InputEventMouseMotion and _drag:
		_pull = maxf(0.0, _drag_y - event.position.y)
		queue_redraw()


func _tear() -> void:
	var n := _visible_count()
	if n == 0:
		return
	Sfx.play("tear", -2.0)
	_tearing = 1.0
	_torn_after = n - 1
	torn.emit()


## Where each visible line sits: newest at the platen, older ones higher up.
func _line_y(i: int, n: int) -> float:
	var p := _paper()
	return p.end.y - 26.0 - (n - 1 - i) * LINE_H


func _line_at(pos: Vector2) -> int:
	var n := _visible_count()
	for i in range(n - 1, maxi(-1, _torn_after), -1):
		var y := _line_y(i, n) - _pull
		if pos.y > y - LINE_H + 3 and pos.y <= y + 4:
			return i
	return -1


func _process(delta: float) -> void:
	if _tearing > 0.0:
		_tearing = maxf(0.0, _tearing - delta * 2.0)
	var n := _visible_count()
	var now := Time.get_ticks_msec() / 1000.0
	if n > _last_count:
		var jump := n - _last_count > 2
		for i in range(_last_count, n):
			_shown[i] = now - (100.0 if jump else 0.0)
		if not jump and replay != null and replay.playing:
			Sfx.play("type", -14.0, 0.95 + randf() * 0.1)
	elif n < _last_count:
		for i in range(n, _last_count):
			_shown.erase(i)
		if n - 1 < _torn_after:
			_torn_after = n - 1
	_last_count = n
	queue_redraw()


func _draw() -> void:
	var p := _paper()
	var now := Time.get_ticks_msec() / 1000.0
	var n := _visible_count()
	var first := _torn_after + 1
	var top_line := maxi(first, 0)
	# The roll feeds from above: the strip fills the well, unless it was torn, in which case
	# it starts just above the oldest line printed since.
	var strip_top := p.position.y - 30.0
	if _torn_after >= 0:
		strip_top = maxf(strip_top, p.end.y - 26.0 - (n - top_line) * LINE_H - 10.0 - _pull)
	var strip := Rect2(p.position.x + 6.0, strip_top, p.size.x - 12.0, p.end.y + 8.0 - strip_top)
	Desk.draw_paper(self, strip, Desk.PAPER.darkened(0.04), 7, true)
	# The torn edge (only in view after a tear).
	var zz := PackedVector2Array()
	var x := strip.position.x
	var k := 0
	while x < strip.end.x:
		zz.append(Vector2(x, strip.position.y + (3.0 if k % 2 == 0 else -1.0)))
		x += 7.0
		k += 1
	zz.append(Vector2(strip.end.x, strip.position.y))
	zz.append(Vector2(strip.end.x, strip.position.y - 6))
	zz.append(Vector2(strip.position.x, strip.position.y - 6))
	draw_colored_polygon(zz, Color(0.02, 0.025, 0.02))
	# Sprocket holes down both edges.
	var hy := strip.position.y + 8.0
	while hy < strip.end.y:
		draw_circle(Vector2(strip.position.x + 7, hy), 2.2, Color(0.03, 0.04, 0.03))
		draw_circle(Vector2(strip.end.x - 7, hy), 2.2, Color(0.03, 0.04, 0.03))
		hy += 12.0
	var f := Desk.font("type")
	if n == 0 and header != "":
		draw_string(f, Vector2(p.position.x + 24, p.end.y - 26.0), header, HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 40, 13, Desk.INK)
	var cur_tick := replay.view.t if replay != null and replay.has_dive() else 0.0
	for i in range(top_line, n):
		var l: Dictionary = lines[i]
		var y := _line_y(i, n) - _pull
		if y < p.position.y - 20.0:
			continue
		var txt: String = l["text"]
		var shown_at: float = _shown.get(i, now - 100.0)
		var chars := int((now - shown_at) * CPS)
		var t := "" if l.get("cont", false) else "%d:%04.1f  " % [int(l["t"]) / 1800, fmod(float(l["t"]) / 30.0, 60.0)]
		var body := txt.substr(0, maxi(0, chars - t.length())) if chars < t.length() + txt.length() else txt
		var col := Desk.RED_INK if l["kind"] == "hit" or l["kind"] == "end" else Desk.INK
		if l["kind"] == "voice":
			col = Color(0.28, 0.18, 0.1)
		var x0 := p.position.x + 22.0
		draw_string(f, Vector2(x0, y), t.substr(0, mini(chars, t.length())), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Desk.INK, 0.55))
		draw_string(f, Vector2(x0 + 62.0, y), body, HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 96.0, 13, col)
		# The line the recorder is on gets a faint pencil mark.
		if i == n - 1 and not l.get("cont", false) and absf(float(l["t"]) - cur_tick) < 45.0:
			draw_line(Vector2(x0 - 10, y - 4), Vector2(x0 - 4, y - 4), Color(Desk.RED_INK, 0.6), 2.0)
	# The strip flying off after a tear.
	if _tearing > 0.0:
		var fly := Rect2(strip.position + Vector2(0, -(1.0 - _tearing) * 260.0), Vector2(strip.size.x, 60))
		draw_set_transform(fly.get_center(), (1.0 - _tearing) * 0.4, Vector2.ONE)
		draw_rect(Rect2(-fly.size * 0.5, fly.size), Color(Desk.PAPER, _tearing))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The platen and its cover over the paper.
	var pl := Desk.r("platen")
	Desk.draw_sprite(self, "platen", pl.get_center() - position)
	var pr := Desk.plaque_rect("teleprinter")
	if Desk.tex("platen") != null:
		Desk.engraved(self, Rect2(pr.position - position, pr.size), Desk.plaque("teleprinter")[4], 12, Color(0.75, 0.62, 0.4, 0.7))
