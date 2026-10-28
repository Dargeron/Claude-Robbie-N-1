class_name Induction
extends Control
## The way into the game (Albert, 2026-10-28): a title screen over the dark desk, then, the first
## time, a welcome page in plain words and a tour of the office, one machine at a time, under a
## work lamp; then the first orders. It replaces the grease-pencil notes that used to teach the
## controls as you went. Esc on the desk brings the title back.
##   title -> (fresh contract) welcome -> tour -> the first memo
##   title -> CONTINUE -> the desk as it was

signal fresh_start                 # the operator chose a new contract on a used save
signal done(read_orders: bool)     # the induction is over; read_orders: open the first memo

const CARD_W := 372.0
const DARK := 0.86

## The tour: [title, words, layout rects to light (unioned)].
const STEPS := [
	["THE SONAR SCOPE",
		"This is where you watch Robbie. You see only what he senses: what his lamp lights, what he touches, what glows. Tap the screen to see it full size.",
		["screen"]],
	["ROBBIE'S FACE",
		"The hull in the water, live. Units are not supposed to have feelings. Watch his face anyway.",
		["porthole"]],
	["THE CARD READER",
		"Robbie's program. Many times a second he reads the slots from the top and does the first card that fits. While he swims, the lamps beside the slots show which card he is on.",
		["lamp_rail", "card_bed"]],
	["THE CARD PRESS",
		"Makes new cards. Turn the ORDER and CONDITION wheels by their red grips until the card you want sits between the marks, then pull PRINT. Drag the card into a slot.",
		["press"]],
	["PULP AND THE COUNTER",
		"Cards you don't want go down the PULP chute. The counter beside it keeps your account with the Company: every Robbie lost is a hull on your bill.",
		["chute", "counter"]],
	["THE DISPATCH LEVER",
		"Haul it all the way down and the next Robbie drops. The READY lamp means the reader will take your deck.",
		["dispatch"]],
	["THE WIRE RECORDER",
		"Every dive is recorded. Play it, rewind it, drag the reels to go back and forth. The knob sets the speed.",
		["recorder"]],
	["THE TELEPRINTER",
		"Types what Robbie sensed, as it happens. Tap a line and the recording jumps there. His last words come through here too.",
		["paper"]],
	["THE SEA TRIALS",
		"One good dive could be luck. Crank the engine and twenty Robbies try your deck. Sixteen through, and the sector is certified. Tap a red lamp to watch one that failed.",
		["trials"]],
	["ORDERS AND SECTORS",
		"The Company's orders come down the tube: tap the capsule to read them. Once a sector is certified, turn the SECTOR knob to the next one.",
		["tube", "sector", "shift"]],
	["THE BINDER AND THE WALL",
		"The binder explains every card you have been issued. The Wall remembers every Robbie you sent.",
		["binder", "wall"]],
	["YOUR FIRST ORDERS",
		"Sector 1 is waiting. Robbie already has one card in the reader: SWIM TOWARDS BEACON. Read your orders, then haul the lever.",
		["tube"]],
]

var mode := ""                     # "title", "welcome", "tour", "" (hidden)
var step := 0
var has_progress := false
var _dark := 0.0                   # the overlay's darkness, eased
var _hole := Rect2()               # the lit part of the desk, eased
var _hole_to := Rect2()
var _card := Rect2()               # the tour's caption card, or the welcome page
var _buttons: Array = []           # [[rect, id, label], ...], rebuilt every draw
var _hover := ""
var _confirm := false              # NEW CONTRACT asked once
var _t := 0.0
var _leaving := false


func _init() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func show_title(progress: bool) -> void:
	has_progress = progress
	_confirm = false
	_leaving = false
	mode = "title"
	visible = true
	_dark = maxf(_dark, 0.5)
	_set_hole(Desk.r("porthole").grow(-6))
	move_to_front()


func show_welcome() -> void:
	mode = "welcome"
	_leaving = false
	visible = true
	_set_hole(Rect2(640, 360, 0, 0))
	Sfx.play("paper", -6.0)
	move_to_front()


func show_tour(from := 0) -> void:
	mode = "tour"
	_leaving = false
	visible = true
	_go(from)
	move_to_front()


func _go(i: int) -> void:
	step = clampi(i, 0, STEPS.size() - 1)
	var r := Rect2()
	for key: String in STEPS[step][2]:
		r = Desk.r(key) if r.size == Vector2.ZERO else r.merge(Desk.r(key))
	_set_hole(r.grow(8))
	Sfx.play("switch", -9.0, 0.9 + 0.03 * step)


func _set_hole(r: Rect2) -> void:
	if _hole.size == Vector2.ZERO and r.size != Vector2.ZERO:
		_hole = Rect2(r.get_center(), Vector2.ZERO)
	_hole_to = r


func _leave(read_orders: bool) -> void:
	_leaving = true
	Sfx.play("lever", -8.0, 1.2)
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void:
		visible = false
		mode = ""
		done.emit(read_orders))


func _process(delta: float) -> void:
	_t += delta
	var want := 0.0 if _leaving else (0.94 if mode == "title" else DARK)
	_dark = move_toward(_dark, want, delta * (3.0 if _leaving else 1.6))
	var k := minf(1.0, delta * 7.0)
	_hole = Rect2(_hole.position.lerp(_hole_to.position, k), _hole.size.lerp(_hole_to.size, k))
	queue_redraw()


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _button_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := _button_at(event.position)
		if id != "":
			_press(id)
		elif mode == "tour" and not _card.has_point(event.position):
			_press("next")       # a tap on the desk moves the tour on
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or _leaving or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_RIGHT:
			_press("next" if mode != "title" else ("continue" if has_progress else "begin"))
		KEY_LEFT:
			if mode == "tour":
				_press("back")
		KEY_ESCAPE, KEY_BACK:
			if mode == "title" and has_progress:
				_press("continue")
			elif mode != "title":
				_press("skip")
		_:
			return
	get_viewport().set_input_as_handled()


func _button_at(p: Vector2) -> String:
	for b: Array in _buttons:
		if (b[0] as Rect2).has_point(p):
			return b[1]
	return ""


func _press(id: String) -> void:
	if _leaving:
		return
	Sfx.play("switch", -6.0)
	match id:
		"begin":
			show_welcome()
		"continue":
			_leave(false)
		"induction":
			show_welcome()
		"new":
			if not _confirm:
				_confirm = true
				return
			Sfx.play("tear", -4.0)
			fresh_start.emit()
			show_welcome()
		"next":
			if mode == "welcome":
				show_tour(0)
			elif mode == "tour":
				if step >= STEPS.size() - 1:
					_leave(true)
				else:
					_go(step + 1)
		"back":
			if mode == "tour" and step > 0:
				_go(step - 1)
			elif mode == "tour":
				show_welcome()
		"skip":
			_leave(true)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	_buttons = []
	_draw_dark()
	match mode:
		"title":
			_draw_title()
		"welcome":
			_draw_welcome()
		"tour":
			_draw_tour()


## The desk in the dark, except under the work lamp.
func _draw_dark() -> void:
	var a := _dark
	var h := _hole
	var col := Color(0.01, 0.012, 0.012, a)
	if h.size.x < 1.0:
		draw_rect(Rect2(Vector2.ZERO, size), col)
		return
	draw_rect(Rect2(0, 0, size.x, h.position.y), col)
	draw_rect(Rect2(0, h.end.y, size.x, size.y - h.end.y), col)
	draw_rect(Rect2(0, h.position.y, h.position.x, h.size.y), col)
	draw_rect(Rect2(h.end.x, h.position.y, size.x - h.end.x, h.size.y), col)
	# A soft edge, inside the hole.
	for i in 10:
		var g := h.grow(-1.5 * i - 0.75)
		if g.size.x <= 0.0 or g.size.y <= 0.0:
			break
		draw_rect(g, Color(col, a * 0.5 * (1.0 - i / 10.0)), false, 1.6)
	if mode == "tour":
		# Corner brackets round what is being shown, in the stencil paint.
		var c := Color(Desk.STENCIL, 0.75 * a)
		var L := minf(22.0, minf(h.size.x, h.size.y) * 0.3)
		for corner: Vector2 in [h.position, Vector2(h.end.x, h.position.y), h.end, Vector2(h.position.x, h.end.y)]:
			var sx := 1.0 if corner.x == h.position.x else -1.0
			var sy := 1.0 if corner.y == h.position.y else -1.0
			var o := corner + Vector2(-sx, -sy) * 3.0
			draw_line(o, o + Vector2(sx * L, 0), c, 2.5)
			draw_line(o, o + Vector2(0, sy * L), c, 2.5)


func _draw_title() -> void:
	var fade := clampf((_dark - 0.4) / 0.5, 0.0, 1.0)
	var pl := Desk.font("plate")
	# The scope, still sweeping in the dark: the only other light in the room.
	var sc := Desk.r("screen")
	var c := sc.get_center()
	var ang := fmod(_t * 0.9, TAU)
	for i in 3:
		draw_arc(c, 50.0 + i * 52.0, 0, TAU, 48, Color(Desk.PHOSPHOR, 0.05 * fade), 1.0)
	for k in 14:
		var a2 := ang - k * 0.045
		draw_line(c, c + Vector2.from_angle(a2) * 160.0, Color(Desk.PHOSPHOR, 0.11 * fade * (1.0 - k / 14.0)), 2.0)
	# The nameplate: a bronze plaque screwed to the dark.
	var r := Rect2(330, 176, 620, 168)
	draw_rect(r.grow(6), Color(0.05, 0.04, 0.03, fade))
	draw_rect(r, Color(0.27, 0.2, 0.11, fade))
	draw_rect(r.grow(-8), Color(0.21, 0.16, 0.09, fade))
	draw_rect(r.grow(-8), Color(0.45, 0.34, 0.18, 0.35 * fade), false, 1.5)
	for p: Vector2 in [r.position + Vector2(18, 18), Vector2(r.end.x - 18, r.position.y + 18), r.end - Vector2(18, 18), Vector2(r.position.x + 18, r.end.y - 18)]:
		draw_circle(p, 5.0, Color(0.12, 0.09, 0.05, fade))
		draw_line(p - Vector2(3, 3), p + Vector2(3, 3), Color(0.42, 0.32, 0.17, fade), 1.2)
	var tr := Rect2(r.position + Vector2(0, 18), Vector2(r.size.x, 100))
	Desk.centred(self, Rect2(tr.position + Vector2(2, 3), tr.size), "ROBBIE  N+1", pl, 92, Color(0, 0, 0, 0.6 * fade))
	Desk.centred(self, tr, "ROBBIE  N+1", pl, 92, Color(Desk.STENCIL, fade))
	Desk.centred(self, Rect2(r.position.x, r.position.y + 118, r.size.x, 30), "DEEP SURVEY   ·   STATION 9   ·   JUPITER", pl, 20, Color(Desk.STENCIL, 0.7 * fade))
	# The choices: enamel strips, each with a red push button.
	var items: Array = []
	if has_progress:
		items.append(["continue", "CONTINUE"])
		items.append(["induction", "SHOW ME THE OFFICE AGAIN"])
		items.append(["new", "TAP AGAIN TO TEAR UP YOUR CONTRACT" if _confirm else "NEW CONTRACT  (START OVER)"])
	else:
		items.append(["begin", "BEGIN"])
	var y := 392.0
	for it: Array in items:
		var br := Rect2(460, y, 360, 46)
		_button_strip(br, it[0], it[1], fade, it[0] == "new" and _confirm)
		y += 58.0
	var hint := "ESC ON THE DESK BRINGS YOU BACK HERE"
	Desk.centred(self, Rect2(0, 664, 1280, 20), hint, pl, 13, Color(Desk.STENCIL, 0.35 * fade))


func _button_strip(br: Rect2, id: String, label: String, fade: float, warn := false) -> void:
	var hot := _hover == id
	draw_rect(br, Color(0.1, 0.13, 0.12, 0.95 * fade))
	draw_rect(br, Color(0.3, 0.36, 0.32, (0.9 if hot else 0.5) * fade), false, 1.5)
	var kc := br.position + Vector2(26, br.size.y * 0.5)
	draw_circle(kc + Vector2(1, 2), 13.0, Color(0, 0, 0, 0.5 * fade))
	draw_circle(kc, 13.0, Color(0.36, 0.08, 0.05, fade))
	draw_circle(kc, 10.0, Color(0.55 if hot else 0.46, 0.11, 0.06, fade))
	draw_arc(kc, 10.0, PI * 1.1, PI * 1.6, 8, Color(0.85, 0.35, 0.25, 0.5 * fade), 2.0)
	var col := Color(Desk.RED_LAMP, fade) if warn else Color(Desk.STENCIL, (1.0 if hot else 0.85) * fade)
	draw_string(Desk.font("plate"), br.position + Vector2(52, br.size.y * 0.5 + 8), label, HORIZONTAL_ALIGNMENT_LEFT, br.size.x - 60, 22, col)
	_buttons.append([br, id, label])


func _draw_welcome() -> void:
	var r := Rect2(300, 40, 680, 640)
	_card = r
	Desk.draw_paper(self, r, Desk.PAPER, 77, true)
	var lh := Desk.font("letterhead")
	var ty := Desk.font("type")
	Desk.centred(self, Rect2(r.position.x, r.position.y + 30, r.size.x, 34), "WELCOME TO STATION 9", lh, 30, Desk.INK)
	Desk.centred(self, Rect2(r.position.x, r.position.y + 66, r.size.x, 18), "A COMPANY OUTPOST IN THE DEEP OCEAN OF JUPITER", lh, 11, Desk.INK_SOFT)
	draw_line(r.position + Vector2(50, 96), Vector2(r.end.x - 50, r.position.y + 96), Desk.INK, 1.2)
	var text := "You are the new operator. Under the station is an ocean nobody has charted, and you explore it with Robbies: small survey robots.\n\nYou can't steer a Robbie. You give him cards, and each card is an order, like SWIM TOWARDS BEACON or FOLLOW WALL. He follows them by himself.\n\nSend him down and watch what happens. If he's lost, fix the cards and send the next one: Robbie N+1.\n\nGet a Robbie to the beacon, prove it wasn't luck, and the Company opens the next sector."
	draw_multiline_string(ty, r.position + Vector2(56, 130), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 112, 17, -1, Desk.INK)
	# The loop, in four pictures.
	var labels := ["MAKE CARDS", "SEND HIM", "WATCH", "FIX THEM"]
	var y := r.position.y + 446.0
	for i in 4:
		var c := Vector2(r.position.x + 118 + i * 148, y)
		_pictogram(i, c)
		Desk.centred(self, Rect2(c.x - 70, y + 40, 140, 20), labels[i], Desk.font("plate"), 16, Desk.INK)
		if i < 3:
			var a0 := c + Vector2(48, 0)
			var a1 := c + Vector2(100, 0)
			draw_line(a0, a1, Desk.INK_SOFT, 2.0)
			draw_line(a1, a1 + Vector2(-7, -5), Desk.INK_SOFT, 2.0)
			draw_line(a1, a1 + Vector2(-7, 5), Desk.INK_SOFT, 2.0)
	# Back round, from FIX to MAKE, under the labels.
	var x0 := r.position.x + 118.0
	var x1 := r.position.x + 118.0 + 3 * 148.0
	var back := PackedVector2Array()
	for k in 25:
		var f := k / 24.0
		back.append(Vector2(lerpf(x1, x0, f), y + 72.0 + sin(f * PI) * 22.0))
	draw_polyline(back, Color(Desk.INK_SOFT, 0.7), 1.6)
	var tip := Vector2(x0, y + 66.0)
	draw_line(back[24], tip, Color(Desk.INK_SOFT, 0.7), 1.6)
	draw_line(tip, tip + Vector2(-5, 7), Color(Desk.INK_SOFT, 0.7), 1.6)
	draw_line(tip, tip + Vector2(5, 7), Color(Desk.INK_SOFT, 0.7), 1.6)
	Desk.centred(self, Rect2(x0, y + 96, x1 - x0, 18), "AND AGAIN, UNTIL ONE GETS THROUGH", Desk.font("plate"), 13, Desk.INK_SOFT)
	var nb := Rect2(r.end.x - 300, r.end.y - 76, 250, 46)
	_stamp_button(nb, "next", "SHOW ME THE OFFICE")
	var sb := Rect2(r.position.x + 50, r.end.y - 70, 120, 34)
	_stamp_button(sb, "skip", "SKIP", true)


## Little drawings for the loop: a card, the lever, the scope, a card with a pencil.
func _pictogram(i: int, c: Vector2) -> void:
	var ink := Desk.INK
	match i:
		0, 3:
			var cr := Rect2(c - Vector2(34, 16), Vector2(68, 32))
			draw_rect(cr, Desk.CARD)
			draw_rect(cr, ink, false, 1.5)
			draw_line(cr.position + Vector2(0, 8), Vector2(cr.end.x, cr.position.y + 8), Color(Desk.RED_INK, 0.8), 1.5)
			for k in 6:
				draw_rect(Rect2(cr.position + Vector2(8 + k * 9, 15 + (k % 3) * 4), Vector2(4, 3)), ink)
			if i == 3:
				draw_line(c + Vector2(10, 22), c + Vector2(38, -12), ink, 4.0)
				draw_line(c + Vector2(10, 22), c + Vector2(6, 28), Desk.RED_INK, 3.0)
		1:
			draw_circle(c + Vector2(-16, 6), 9.0, ink)
			draw_line(c + Vector2(-16, 6), c + Vector2(24, 22), ink, 6.0)
			draw_line(c + Vector2(14, 18), c + Vector2(30, 25), Desk.RED_INK, 9.0)
			draw_arc(c + Vector2(-16, 6), 34.0, -0.9, 0.5, 10, Desk.INK_SOFT, 1.2)
		2:
			draw_circle(c, 26.0, Color(0.05, 0.12, 0.08))
			draw_arc(c, 26.0, 0, TAU, 24, ink, 2.0)
			draw_arc(c, 16.0, 0, TAU, 20, Color(Desk.PHOSPHOR, 0.5), 1.0)
			draw_line(c, c + Vector2.from_angle(-0.7) * 24.0, Desk.PHOSPHOR, 1.5)
			draw_circle(c + Vector2(8, 6), 3.0, Desk.AMBER)


func _draw_tour() -> void:
	var s: Array = STEPS[step]
	var last := step == STEPS.size() - 1
	var ty := Desk.font("type")
	var pl := Desk.font("plate")
	var body_h := _text_height(ty, str(s[1]), CARD_W - 48, 16)
	var h := 64.0 + body_h + 74.0
	_card = _place_card(_hole_to, Vector2(CARD_W, h))
	Desk.draw_paper(self, _card, Desk.PAPER, 31 + step * 7, true)
	var p := _card.position
	draw_string(ty, p + Vector2(24, 28), "INDUCTION  ·  %d OF %d" % [step + 1, STEPS.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Desk.INK_SOFT)
	draw_string(pl, p + Vector2(24, 56), str(s[0]), HORIZONTAL_ALIGNMENT_LEFT, CARD_W - 48, 26, Desk.INK)
	draw_multiline_string(ty, p + Vector2(24, 84), str(s[1]), HORIZONTAL_ALIGNMENT_LEFT, CARD_W - 48, 16, -1, Desk.INK)
	var by := _card.end.y - 52
	_stamp_button(Rect2(_card.end.x - 186, by, 162, 34), "next", "READ MY ORDERS" if last else "NEXT")
	_stamp_button(Rect2(p.x + 24, by, 84, 34), "back", "BACK", true)
	if not last:
		_stamp_button(Rect2(_card.end.x - 84, p.y + 12, 64, 26), "skip", "SKIP", true)


func _text_height(f: Font, text: String, w: float, sz: int) -> float:
	return f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, sz).y


## Put the caption beside what is lit: to its right, left, below or above, whichever fits.
func _place_card(hole: Rect2, sz: Vector2) -> Rect2:
	var m := 14.0
	var bounds := Rect2(Vector2(m, m), size - Vector2(m, m) * 2.0)
	var cy := clampf(hole.get_center().y - sz.y * 0.5, m, size.y - m - sz.y)
	var cx := clampf(hole.get_center().x - sz.x * 0.5, m, size.x - m - sz.x)
	var tries := [
		Rect2(Vector2(hole.end.x + 18, cy), sz),
		Rect2(Vector2(hole.position.x - 18 - sz.x, cy), sz),
		Rect2(Vector2(cx, hole.end.y + 18), sz),
		Rect2(Vector2(cx, hole.position.y - 18 - sz.y), sz),
	]
	for t: Rect2 in tries:
		if bounds.encloses(t) and not t.intersects(hole):
			return t
	# Nothing fits beside it (the press is wide): over the far side of the desk.
	return Rect2(Vector2(cx, m + 40), sz) if hole.get_center().y > size.y * 0.5 else Rect2(Vector2(cx, size.y - m - sz.y), sz)


## A rubber-stamp button on paper: red ink frame (red means you can press it).
func _stamp_button(br: Rect2, id: String, label: String, quiet := false) -> void:
	var hot := _hover == id
	var col := Color(Desk.RED_INK, 0.95 if hot else (0.6 if quiet else 0.85))
	if hot:
		draw_rect(br, Color(Desk.RED_INK, 0.08))
	draw_rect(br, col, false, 2.5 if not quiet else 1.6)
	Desk.centred(self, br, label, Desk.font("plate"), 20 if not quiet else 16, col)
	_buttons.append([br, id, label])
