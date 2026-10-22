class_name RobbieLab
extends Control
## The Lab (Albert's note #6), first sketch: Robbie on the workbench, big, with a slot for
## each thing it carries. Nothing to buy yet: the empty slots are where upgrades will go
## once the currencies are decided. View and UI only.

signal closed

const BRASS := Color(0.86, 0.63, 0.28)
const BRASS_DARK := Color(0.52, 0.35, 0.14)
const HULL := Color(1.0, 0.78, 0.3)
const S := 24.0                     # Robbie's dive-view size, scaled up for the bench
const CENTRE := Vector2(640, 350)
const FWD := Vector2(-1, 0)         # Robbie faces left: its lamp, laser and eye towards the cards on the left
const SIDE := Vector2(0, 1)

var _t := 0.0
var _cards: Array[Dictionary] = []  # {box: Rect2, title, text, anchor: Vector2 on Robbie, empty: bool}
var _font: Font


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var close := IconButton.make("close", "Back to the station (B or Esc)", func() -> void: closed.emit())
	close.position = Vector2(1222, 14)
	close.custom_minimum_size = Vector2(34, 32)
	add_child(close)


## Fill the slots for the room the player is working on.
func show_for(room: Room, serial: int) -> void:
	_font = get_theme_default_font()
	var up := Vector2(0, -1)
	_cards = [
		{"box": Rect2(40, 120, 320, 120), "title": "LAMP", "anchor": CENTRE + FWD * 6.1 * S,
			"text": "Lights 6 tiles ahead and glows 3 tiles all around. Jellyfish swim to it; a sleeping lurker shows in it. The Lamp order switches it on or off."},
		{"box": Rect2(40, 270, 320, 120), "title": "LASER", "anchor": CENTRE + FWD * 5.0 * S + SIDE * 3.0 * S,
			"text": "Fires at the nearest hostile Robbie senses within 6 tiles. Every shot costs energy, and Robbie holds still while it fires. Lurkers' armour bounces it; eels slip out of it."},
		{"box": Rect2(40, 420, 320, 110), "title": "CPU", "anchor": CENTRE + FWD * 1.8 * S + up * 2.75 * S,
			"text": "%d CPU in %s: how many rules Robbie's brain can hold. Every order and condition costs some; the editor counts it." % [room.cpu_budget, room.title]},
		{"box": Rect2(920, 120, 320, 110), "title": "HULL", "anchor": CENTRE - FWD * 1.5 * S + up * 4.2 * S,
			"text": "Takes three knocks. Rock, stings, bites and the valve all count. The fourth is the last transmission."},
		{"box": Rect2(920, 260, 320, 120), "title": "BATTERY", "anchor": CENTRE - FWD * 4.6 * S,
			"text": "%d units of energy in %s. Swimming uses it; holding still uses half as much. When it runs out, Robbie stops for good." % [room.energy, room.title]},
		{"box": Rect2(920, 410, 320, 110), "title": "EMPTY SLOT", "anchor": CENTRE - FWD * 3.2 * S + SIDE * 3.2 * S, "empty": true,
			"text": "Upgrades come later: new instruments and better parts, built from what Robbies bring back."},
		{"box": Rect2(480, 610, 320, 90), "title": "EMPTY SLOT", "anchor": CENTRE + SIDE * 4.3 * S, "empty": true,
			"text": "Robbie has room for a few more parts. Choosing which to carry is part of each dive."},
	]
	_serial = serial
	queue_redraw()


var _serial := 1


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_B]:
		closed.emit()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if _font == null:
		_font = get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)
	# The workbench: a warm pool of light, a brass rail and a grid of rivets.
	for i in 14:
		draw_circle(CENTRE + Vector2(0, 30), 330.0 - i * 20.0, Color(1.0, 0.75, 0.4, 0.012 + i * 0.002))
	draw_rect(Rect2(420, 560, 440, 10), BRASS_DARK)
	draw_rect(Rect2(420, 558, 440, 3), BRASS)
	for x in range(430, 860, 30):
		draw_circle(Vector2(x, 565), 2.0, BRASS)
	draw_string(_font, Vector2(40, 44), "THE LAB", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiTheme.AMBER)
	draw_string(_font, Vector2(40, 70), "Robbie %03d on the bench. A first sketch: every part it carries, and room for more." % _serial,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.TEXT_DIM)
	for c in _cards:
		_draw_leader(c)
	_draw_robbie()
	for c in _cards:
		_draw_card(c)


## A leader line from a card to its part on Robbie (drawn behind Robbie).
func _draw_leader(c: Dictionary) -> void:
	var box: Rect2 = c["box"]
	var empty: bool = c.get("empty", false)
	var edge := UiTheme.PANEL_EDGE if empty else BRASS_DARK
	var from := Vector2(box.end.x if box.position.x < 640 else box.position.x, box.get_center().y)
	if box.position.y > 580:
		from = Vector2(box.get_center().x, box.position.y)
	draw_line(from, c["anchor"], Color(edge, 0.9), 1.5)


func _draw_card(c: Dictionary) -> void:
	var box: Rect2 = c["box"]
	var empty: bool = c.get("empty", false)
	var edge := UiTheme.PANEL_EDGE if empty else BRASS_DARK
	var anchor: Vector2 = c["anchor"]
	draw_circle(anchor, 4.0, edge if empty else BRASS)
	draw_arc(anchor, 4.0, 0, TAU, 12, Color(0.1, 0.07, 0.03), 1.0)
	draw_rect(box, Color(UiTheme.PANEL, 0.6 if empty else 0.95))
	draw_rect(box, edge, false, 1.5)
	for p in [box.position + Vector2(6, 6), Vector2(box.end.x - 6, box.position.y + 6), Vector2(box.position.x + 6, box.end.y - 6), box.end - Vector2(6, 6)]:
		draw_circle(p, 2.0, edge)
	var title_col := UiTheme.TEXT_DIM if empty else UiTheme.AMBER
	draw_string(_font, box.position + Vector2(16, 26), c["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, title_col)
	draw_multiline_string(_font, box.position + Vector2(16, 48), c["text"], HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 32, 13, -1,
		UiTheme.TEXT_DIM if empty else UiTheme.TEXT)


## Robbie as in the dive view (round hull, porthole eye, fins, antenna), drawn big, with
## brass trim and rivets for the bench.
func _draw_robbie() -> void:
	var c := CENTRE
	var fwd := FWD
	var side := SIDE
	var bob := sin(_t * 1.6) * 3.0
	c.y += bob
	var flap := sin(_t * 5.0) * 0.5
	for sgn: float in [-1.0, 1.0]:
		# A paddle-shaped fin at the back, swept out and back.
		var root := c - fwd * 3.4 * S + side * sgn * 2.6 * S
		var dir := (-fwd * 1.0 + side * sgn * (0.8 + flap * 0.4)).normalized()
		var mid := root + dir * 1.5 * S
		var perp := dir.orthogonal()
		var fin := PackedVector2Array()
		for i in 21:
			var a := TAU * i / 20.0
			fin.append(mid + dir * cos(a) * 1.7 * S + perp * sin(a) * 0.75 * S)
		draw_colored_polygon(fin, HULL.darkened(0.25))
		draw_polyline(fin, BRASS_DARK, 2.0)
		draw_line(root, mid + dir * 1.2 * S, BRASS_DARK, 1.5)
	var hull := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		var along := cos(a) * (6.0 if cos(a) > 0.0 else 4.8)
		hull.append(c + fwd * along * S + side * sin(a) * 4.3 * S)
	draw_colored_polygon(hull, HULL)
	# A soft shade on the belly, a highlight on top.
	var shade := PackedVector2Array()
	for i in 25:
		var a := PI * i / 24.0
		var along := cos(a) * (5.6 if cos(a) > 0.0 else 4.4)
		shade.append(c + fwd * along * S + side * (sin(a) * 4.0 * S))
	draw_colored_polygon(shade, Color(0.75, 0.5, 0.15, 0.35))
	hull.append(hull[0])
	draw_polyline(hull, BRASS_DARK, 3.0)
	# A brass band round the middle, with rivets.
	draw_line(c - fwd * 0.6 * S - side * 4.2 * S, c - fwd * 0.6 * S + side * 4.2 * S, BRASS, 6.0)
	for i in 7:
		draw_circle(c - fwd * 0.6 * S + side * (i - 3) * 1.15 * S, 2.6, BRASS_DARK)
	for i in 10:
		var a := TAU * i / 10.0
		var along := cos(a) * (5.3 if cos(a) > 0.0 else 4.2)
		draw_circle(c + fwd * along * S + side * sin(a) * 3.75 * S, 2.2, BRASS_DARK)
	# The porthole eye: brass rim, dark glass, a glint, and a pupil that looks about.
	var eye := c + fwd * 1.8 * S
	draw_circle(eye, 2.75 * S, BRASS)
	draw_circle(eye, 2.35 * S, Color(0.10, 0.17, 0.26))
	var look := Vector2(cos(_t * 0.7), sin(_t * 0.9)) * 0.5 * S
	draw_circle(eye + look, 0.9 * S, Color(0.22, 0.45, 0.62))
	draw_circle(eye + look, 0.45 * S, Color(0.04, 0.07, 0.1))
	draw_circle(eye + fwd * 0.8 * S - side * 0.9 * S, 0.45 * S, Color(0.95, 0.98, 1.0, 0.9))
	for i in 8:
		draw_circle(eye + Vector2.from_angle(TAU * i / 8.0) * 2.55 * S, 2.0, BRASS_DARK)
	# A shy blush under the eye, and a small smile towards the nose.
	var cheek := c + fwd * 3.0 * S + side * 2.3 * S
	for i in 3:
		draw_circle(cheek, (0.9 - i * 0.2) * S, Color(1.0, 0.45, 0.45, 0.18 + i * 0.08))
	draw_arc(c + fwd * 4.3 * S + side * 1.2 * S, 0.7 * S, PI * 0.15, PI * 0.85, 10, BRASS_DARK, 2.5)
	# The lamp at the nose, glowing.
	var lamp := c + fwd * 6.1 * S
	for i in 6:
		draw_circle(lamp, (6 - i) * 6.0, Color(1.0, 0.9, 0.6, 0.05 + i * 0.03))
	draw_circle(lamp, 0.9 * S, Color(1, 1, 0.85))
	draw_arc(lamp, 0.9 * S, 0, TAU, 24, BRASS_DARK, 2.0)
	# The laser under the chin.
	var laser := c + fwd * 3.6 * S + side * 3.0 * S
	draw_line(laser, laser + fwd * 1.6 * S, BRASS_DARK, 0.7 * S)
	draw_circle(laser + fwd * 1.6 * S, 0.35 * S, Color(1, 0.3, 0.25))
	# The antenna, blinking.
	var root2 := c - fwd * 1.5 * S - side * 3.6 * S
	var tip := root2 - fwd * 1.6 * S - side * 2.2 * S
	draw_line(root2, tip, BRASS_DARK, 3.0)
	var blink := fmod(_t, 1.2) < 0.2
	draw_circle(tip, 0.6 * S, Color(1.0, 0.35, 0.3) if blink else Color(0.45, 0.2, 0.18))
