class_name WallView
extends Control
## The Wall behind the operator's chair: a corkboard with a strip of tape pinned up for
## every hull sent, newest first: its number, where it went, how it ended, its route as
## the sonar saw it, and its last words. Tap a strip to play that dive again on the scope.
## Drag to scroll. Regulation 6: the Wall is not a memorial. It is a record.

signal entry_chosen(room_id: String, entry: Dictionary)
signal closed

const COLS := 3
const STRIP := Vector2(388, 92)
const GAP := Vector2(22, 16)
const TOP := 104.0

var items: Array = []            # [{room, entry}]
var names := {}                  # room id -> short name
var summary := ""
var _scroll := 0.0
var _press := Vector2.ZERO
var _press_scroll := 0.0
var _dragging := false
var _down := false


func _init() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP


func refresh(state: GameState, sectors: Array, sector_names: Dictionary) -> void:
	names = sector_names
	items = []
	var parts: PackedStringArray = []
	for id: String in sectors:
		var lost := 0
		for e in state.own_dives(id):
			items.append({"room": id, "entry": e})
			if e["result"] != "exit":
				lost += 1
		var rs := state.room_state(id)
		if not rs.dives.is_empty():
			parts.append("%s: %d LOST%s" % [sector_names[id], lost, "  ·  CERTIFIED" if rs.certified else ""])
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["entry"]["serial"]) > int(b["entry"]["serial"]))
	summary = "      ".join(parts) if not parts.is_empty() else "NOTHING PINNED YET"
	_scroll = 0.0
	queue_redraw()


func _strip_rect(i: int) -> Rect2:
	var col := i % COLS
	var row := i / COLS
	return Rect2(Vector2(46 + col * (STRIP.x + GAP.x), TOP + row * (STRIP.y + GAP.y) - _scroll), STRIP)


func _max_scroll() -> float:
	var rows := (items.size() + COLS - 1) / COLS
	return maxf(0.0, TOP + rows * (STRIP.y + GAP.y) - 690.0)


func _back_rect() -> Rect2:
	return Rect2(1108, 22, 140, 38)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_scroll = clampf(_scroll + 60.0, 0.0, _max_scroll())
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_scroll = clampf(_scroll - 60.0, 0.0, _max_scroll())
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_down = true
				_press = event.position
				_press_scroll = _scroll
				_dragging = false
			elif _down:
				_down = false
				if not _dragging:
					_tap(event.position)
		accept_event()
		queue_redraw()
	elif event is InputEventMouseMotion and _down:
		if absf(event.position.y - _press.y) > 8.0:
			_dragging = true
		if _dragging:
			_scroll = clampf(_press_scroll - (event.position.y - _press.y), 0.0, _max_scroll())
			queue_redraw()


func _tap(p: Vector2) -> void:
	if _back_rect().has_point(p):
		Sfx.play("paper", -8.0)
		closed.emit()
		return
	for i in items.size():
		if _strip_rect(i).has_point(p) and p.y > TOP - 10.0:
			Sfx.play("paper", -6.0)
			entry_chosen.emit(items[i]["room"], items[i]["entry"])
			return


func _draw() -> void:
	# Cork in a wooden frame.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.17, 0.1, 0.05))
	var cork := Rect2(18, 14, 1244, 692)
	draw_rect(cork, Color(0.42, 0.29, 0.17))
	var t := Desk.tex("paper")
	if t != null:
		draw_texture_rect(t, cork, true, Color(0.25, 0.12, 0.02, 1.0))
		draw_texture_rect(t, cork.grow(-1), true, Color(0.1, 0.05, 0.0, 0.8))
	for i in 10:
		draw_rect(cork.grow(-i * 2.0), Color(0, 0, 0, 0.05), false, 2.0)
	var pl := Desk.font("plate")
	var ty := Desk.font("type")
	# Header: a brass plaque and a typed card with the count.
	draw_rect(Rect2(40, 26, 380, 34), Color(0.6, 0.46, 0.22))
	draw_rect(Rect2(40, 26, 380, 34), Color(0.25, 0.17, 0.06), false, 2.0)
	Desk.engraved(self, Rect2(40, 26, 380, 34), "THE WALL  ·  EVERY HULL SENT", 20)
	Desk.draw_paper(self, Rect2(440, 28, 640, 30), Desk.PAPER, 3, true)
	draw_string(ty, Vector2(452, 49), summary, HORIZONTAL_ALIGNMENT_LEFT, 620, 13, Desk.INK)
	var br := _back_rect()
	draw_rect(br, Color(0.6, 0.46, 0.22))
	draw_rect(br, Color(0.25, 0.17, 0.06), false, 2.0)
	Desk.engraved(self, br, "BACK TO THE DESK", 16)
	# The strips.
	for i in items.size():
		var r := _strip_rect(i)
		if r.end.y < TOP - 20.0 or r.position.y > 720.0:
			continue
		_draw_strip(r, items[i]["room"], items[i]["entry"], i)
	if items.is_empty():
		Desk.centred(self, Rect2(0, 300, 1280, 40), "nothing pinned yet. send someone down.", Desk.font("hand"), 30, Color(Desk.NOTE, 0.6))


func _draw_strip(r: Rect2, room_id: String, e: Dictionary, i: int) -> void:
	var tilt := deg_to_rad(float((int(e["serial"]) * 37) % 5) - 2.0)
	draw_set_transform(r.get_center(), tilt, Vector2.ONE)
	var rr := Rect2(-r.size * 0.5, r.size)
	Desk.draw_paper(self, rr, Desk.PAPER.darkened(0.05), int(e["serial"]), true)
	# Ragged torn ends.
	for side in 2:
		var x := rr.position.x if side == 0 else rr.end.x
		var y := rr.position.y
		var k := 0
		while y < rr.end.y:
			var d := 3.0 if k % 2 == 0 else 0.0
			draw_rect(Rect2(x - (d if side == 0 else 0.0) - (0.0 if side == 0 else 0.0), y, d, 6), Color(0.42, 0.29, 0.17))
			y += 6.0
			k += 1
	var lost: bool = e["result"] != "exit"
	var ty := Desk.font("type")
	var head := "ROBBIE %03d  ·  %s" % [int(e["serial"]), names.get(room_id, room_id.to_upper())]
	draw_string(ty, rr.position + Vector2(96, 22), head, HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 104, 14, Desk.INK)
	var how := ("LOST: %s" % Voice.cause_label(e["cause"]).to_upper()) if lost else "REACHED THE BEACON"
	draw_string(ty, rr.position + Vector2(96, 39), "%s  ·  %s S  ·  %d CPU" % [how, e["seconds"], int(e["cpu"])],
		HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 104, 12, Desk.RED_INK if lost else Color(0.1, 0.32, 0.16))
	var words: String = e.get("last_words", "")
	if words != "":
		draw_multiline_string(ty, rr.position + Vector2(96, 56), "“%s”" % words, HORIZONTAL_ALIGNMENT_LEFT,
			rr.size.x - 106, 11, 2, Color(0.28, 0.18, 0.1))
	# The route, as the sonar drew it.
	var th := Rect2(rr.position + Vector2(10, 12), Vector2(78, 50))
	draw_rect(th, Color(0.01, 0.04, 0.025))
	var path := GameState.decode_path(str(e.get("path", "")))
	if path.size() >= 2:
		var sc := minf(th.size.x / 640.0, th.size.y / 352.0)
		var off := th.position + (th.size - Vector2(640, 352) * sc) * 0.5
		var pts := PackedVector2Array()
		for p in path:
			pts.append(off + p * sc)
		draw_polyline(pts, Color(Desk.PHOSPHOR, 0.85), 1.0)
		var end := pts[pts.size() - 1]
		if lost:
			draw_line(end + Vector2(-2.5, -2.5), end + Vector2(2.5, 2.5), Desk.AMBER, 1.2)
			draw_line(end + Vector2(-2.5, 2.5), end + Vector2(2.5, -2.5), Desk.AMBER, 1.2)
		else:
			draw_circle(end, 2.0, Desk.PHOSPHOR)
	draw_rect(th, Color(0.3, 0.25, 0.15, 0.6), false, 1.0)
	# The pin.
	draw_circle(Vector2(0, rr.position.y + 5) + Vector2(2, 3), 5.0, Color(0, 0, 0, 0.4))
	draw_circle(Vector2(0, rr.position.y + 5), 5.0, Color(0.72, 0.12, 0.08))
	draw_circle(Vector2(-1.5, rr.position.y + 3.5), 1.6, Color(1, 0.7, 0.6, 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
