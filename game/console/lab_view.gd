class_name LabView
extends Control
## The hangar, where Robbies are fitted (Albert chose draft C, 2026-10-29; docs/design/lab-drafts.md):
## Bathy hangs from a chain under the work lamp, in the middle, with his six sockets round him. Tap a
## socket and a drawer of every part that fits it slides up from the bench; tap a part and Bathy wears
## it, and the bars show what changes; tap its stamp to requisition it (from the wage in hand) or fit
## it. A long press on a part (or its "i") opens its page in the Company's catalogue. Type plates and
## card-reader slots are on the board at the right; the debt can be paid in at the top.
## The art is layered: game/art/lab/bathy_<layer>.png from tools/art/lab_bathy.py --layers.

signal closed

const BG := Color(0.05, 0.065, 0.068)
const STEEL := Color(0.12, 0.15, 0.15)
const NAVY := Color(0.23, 0.31, 0.31)
const BRONZE := Color(0.43, 0.32, 0.19)
const BRONZE_DK := Color(0.21, 0.15, 0.09)
const VALVE := Color(0.61, 0.16, 0.1)
const BATHY_C := Vector2(640, 262)
const BATHY_PX := 400.0
const LONG_PRESS := 0.45
const PAY_STEP := 1000

## Where each socket's badge sits, and the point on Bathy (in the 512 px art) it is joined to.
const SOCKETS := {
	"hatch": [Vector2(640, 58), Vector2(250, 112)],
	"drive": [Vector2(372, 168), Vector2(138, 286)],
	"belly": [Vector2(384, 378), Vector2(250, 372)],
	"hull": [Vector2(904, 124), Vector2(366, 232)],
	"lamp": [Vector2(914, 258), Vector2(318, 352)],
	"tool": [Vector2(890, 392), Vector2(386, 378)],
}
const STOCK_LAYER := {"lamp": "lamp_std", "drive": "pods_std", "hatch": "antenna_std", "tool": "laser_std", "belly": "", "hull": ""}
const DRAW_ORDER := ["hull", "belly", "drive", "hatch", "lamp", "tool"]

var console              # the console (its accounts, sectors and debt)
var socket := "drive"    # the socket whose drawer is open
var preview := "-"       # the part being looked at in the drawer ("" stock, "-" nothing)
var page := ""           # a catalogue page open over everything ("" none, or a part id, or "stock:<socket>")
var _t := 0.0
var _in := 0.0
var _tex := {}
var _hits: Array = []    # [rect, kind, id], rebuilt every draw
var _press_at := -1.0
var _press_hit: Array = []
var _bounce := 0.0
var _deny := 0.0         # the IN HAND wheels flash when there isn't the money


func _init() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP


func open() -> void:
	visible = true
	_in = 0.0
	page = ""
	preview = "-"
	move_to_front()


func _layer(name: String) -> Texture2D:
	if name == "":
		return null
	if not _tex.has(name):
		var path := "res://art/lab/bathy_%s.png" % name
		_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex[name]


func _accounts() -> Accounts:
	return console.accounts


func _certified_count() -> int:
	var n := 0
	for i in console.SECTORS.size():
		if console._certified(i):
			n += 1
	return n


func _base_slots() -> int:
	return console.state.room_state(console.room_id).room.slots


## What fills each socket now, with the part being looked at swapped in.
func _fit_now() -> Dictionary:
	return _accounts().fitted().duplicate()


func _fit_previewed() -> Dictionary:
	var f := _fit_now()
	if preview == "-":
		return f
	if preview == "":
		f.erase(socket)
	else:
		f[socket] = preview
	return f


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_in = minf(1.0, _in + delta * 4.0)
	_bounce = maxf(0.0, _bounce - delta * 2.5)
	_deny = maxf(0.0, _deny - delta * 2.0)
	if _press_at >= 0.0 and _t - _press_at > LONG_PRESS and not _press_hit.is_empty():
		var h := _press_hit
		_press_at = -1.0
		_press_hit = []
		if h[1] == "card":
			page = str(h[2])
			Sfx.play("paper", -6.0)
	queue_redraw()


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_at = _t
			_press_hit = _hit_at(event.position)
		elif _press_at >= 0.0:
			_press_at = -1.0
			var h := _press_hit
			_press_hit = []
			if not h.is_empty():
				_tap(h)
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_BACK, KEY_B]:
		if page != "":
			page = ""
		else:
			_close()
		get_viewport().set_input_as_handled()


func _hit_at(p: Vector2) -> Array:
	for i in range(_hits.size() - 1, -1, -1):
		var h: Array = _hits[i]
		if (h[0] as Rect2).has_point(p):
			return h
	return []


func _close() -> void:
	Sfx.play("lever", -8.0, 1.1)
	visible = false
	closed.emit()


func _tap(h: Array) -> void:
	var kind: String = h[1]
	var id: String = str(h[2])
	match kind:
		"back":
			_close()
		"page_close":
			page = ""
		"socket":
			socket = id
			preview = "-"
			Sfx.play("switch", -8.0)
		"card":
			preview = id
			Sfx.play("switch", -10.0, 1.2)
		"info":
			page = id
			Sfx.play("paper", -6.0)
		"act":
			_act(id)
		"plate":
			_buy_plate(id)
		"slot":
			if _accounts().buy_slot(_base_slots()):
				Sfx.play("stamp", -4.0)
				Sfx.play("relay", -8.0)
			else:
				_refuse()
		"pay":
			if _accounts().pay_debt(PAY_STEP, console._debt()) > 0:
				Sfx.play("relay", -6.0, 0.7)
				Sfx.play("thump", -8.0)
			else:
				_refuse()


## The stamp on a part's card: fit it, requisition it, or put the stock part back.
func _act(id: String) -> void:
	var a := _accounts()
	if id == "":
		a.fit(socket, "")
		_fitted_sound()
		return
	if a.fitted_in(socket) == id:
		a.fit(socket, "")
		_fitted_sound()
		return
	if a.owned(id):
		a.fit(socket, id)
		_fitted_sound()
		return
	var info := Accounts.part_info(id)
	if int(info.get("unlock", 0)) > _certified_count():
		_refuse()
		return
	if a.buy(id, int(info["price"])):
		Sfx.play("stamp", -3.0)
		Sfx.play("relay", -8.0, 0.9)
		a.fit(socket, id)
		_bounce = 1.0
	else:
		_refuse()


func _buy_plate(id: String) -> void:
	var info := Accounts.plate_info(id)
	if _accounts().owned(id):
		return
	if int(info.get("unlock", 0)) > _certified_count() or not _accounts().buy(id, int(info["price"])):
		_refuse()
		return
	Sfx.play("stamp", -3.0)
	Sfx.play("relay", -8.0, 0.9)


func _fitted_sound() -> void:
	Sfx.play("cover", -4.0, 0.8)
	Sfx.play("lever", -10.0, 1.3)
	_bounce = 1.0
	preview = "-"


func _refuse() -> void:
	Sfx.play("switch", -6.0, 0.5)
	_deny = 1.0


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	_hits = []
	_room()
	_work_lamp()
	_chain()
	_draw_bathy()
	_draw_sockets()
	_draw_stats()
	_draw_cards_panel()
	_draw_drawer()
	_header()
	if page != "":
		_draw_page()
	# Coming in: the hangar's dark lifts.
	if _in < 1.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 1.0 - _in))


func _room() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), BG)
	for gx in 9:
		for gy in 5:
			var r := Rect2(gx * 148 - 20, gy * 150 - 30, 146, 148)
			var k := float((gx * 37 + gy * 91) % 11) / 11.0
			draw_rect(r, STEEL.darkened(0.25 + 0.25 * k))
			draw_rect(r, Color(0, 0, 0, 0.5), false, 2.0)
			for c: Vector2 in [r.position + Vector2(8, 8), Vector2(r.end.x - 8, r.position.y + 8), r.end - Vector2(8, 8), Vector2(r.position.x + 8, r.end.y - 8)]:
				draw_circle(c, 2.2, Color(0.22, 0.25, 0.24))
	for i in 14:
		var x := float((i * 173) % 1260) + 10.0
		var y := float((i * 97) % 440) + 20.0
		draw_rect(Rect2(x, y, 3, 26 + (i % 4) * 10), Color(0.35, 0.16, 0.06, 0.25))
	for i in 20:
		draw_rect(Rect2(Vector2(i * 4, i * 4), Vector2(1280 - i * 8, 720 - i * 8)), Color(0, 0, 0, 0.04), false, 4.0)


func _work_lamp() -> void:
	var top := Vector2(BATHY_C.x + 150, 28)
	draw_line(Vector2(top.x, 0), top, Color(0.1, 0.1, 0.1), 3.0)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-30, 0), top + Vector2(30, 0), top + Vector2(20, -12), top + Vector2(-20, -12)]), NAVY.darkened(0.3))
	var cone := PackedVector2Array([top + Vector2(-26, 0), top + Vector2(26, 0), Vector2(BATHY_C.x + 160, 470), Vector2(BATHY_C.x - 220, 470)])
	draw_colored_polygon(cone, Color(1.0, 0.8, 0.45, 0.05))
	Desk.draw_glow(self, BATHY_C, 240.0, Color(1.0, 0.75, 0.4, 0.13 + 0.01 * sin(_t * 1.7)))
	Desk.draw_glow(self, top, 36.0, Color(1.0, 0.85, 0.55, 0.5))


func _bob() -> Vector2:
	return Vector2(sin(_t * 0.9) * 2.0, sin(_t * 1.3) * 3.0 - _bounce * sin(_bounce * 12.0) * 6.0)


func _chain() -> void:
	var top := Vector2(BATHY_C.x, 0)
	var hook := BATHY_C + _bob() + Vector2(-6, -BATHY_PX * 0.36)
	for k in 10:
		var p := top.lerp(hook, k / 10.0)
		draw_arc(p, 4.5, 0, TAU, 10, Color(0.3, 0.3, 0.28), 2.5)


func _to_screen(p512: Vector2) -> Vector2:
	return BATHY_C + _bob() + (p512 - Vector2(256, 256)) * (BATHY_PX / 512.0)


func _draw_bathy() -> void:
	var fit := _fit_previewed()
	var r := Rect2(BATHY_C + _bob() - Vector2(BATHY_PX, BATHY_PX) * 0.5, Vector2(BATHY_PX, BATHY_PX))
	var body := _layer("body")
	if body != null:
		draw_texture_rect(body, r, false)
	for s: String in DRAW_ORDER:
		var id: String = str(fit.get(s, ""))
		var t := _layer(id if id != "" else str(STOCK_LAYER[s]))
		if t != null:
			draw_texture_rect(t, r, false)


func _draw_sockets() -> void:
	var fit := _fit_now()
	for s: String in SOCKETS:
		var badge: Vector2 = SOCKETS[s][0]
		var on_body := _to_screen(SOCKETS[s][1])
		var sel := s == socket
		draw_line(badge, on_body, Color(Desk.AMBER_HOT, 0.85) if sel else Color(Desk.STENCIL, 0.35), 2.0 if sel else 1.2)
		draw_circle(on_body, 4.5, Desk.AMBER_HOT if sel else Color(Desk.STENCIL, 0.5))
		if sel:
			Desk.draw_glow(self, badge, 64.0, Color(Desk.AMBER, 0.32))
		draw_circle(badge, 38.0, BRONZE_DK)
		draw_circle(badge, 33.0, NAVY.darkened(0.35))
		draw_arc(badge, 38.0, 0, TAU, 36, VALVE if sel else BRONZE, 4.0 if sel else 2.5)
		var id: String = str(fit.get(s, ""))
		LabView.icon(self, id if id != "" else str(STOCK_LAYER[s]) if STOCK_LAYER[s] != "" else s, badge, 48.0, Color(0.9, 0.8, 0.55), 2.4)
		var lr := Rect2(badge + Vector2(-46, 41), Vector2(92, 21))
		draw_rect(lr, BRONZE)
		Desk.engraved(self, lr, str(Accounts.catalogue()["socket_names"][s]), 14)
		_hits.append([Rect2(badge - Vector2(42, 42), Vector2(84, 108)), "socket", s])


## The bars: this hull now (white), and with the part being looked at (amber more, red less).
func _draw_stats() -> void:
	var now := Kit.from_parts(_fit_now().values())
	var then := Kit.from_parts(_fit_previewed().values())
	var st := Rect2(26, 84, 246, 330)
	draw_rect(st, Color(0.06, 0.08, 0.08, 0.92))
	draw_rect(st, BRONZE_DK, false, 2.0)
	Desk.engraved(self, Rect2(st.position.x, st.position.y + 6, st.size.x, 18), "THIS HULL", 15, Color(Desk.STENCIL, 0.85))
	var slots := mini(Accounts.MAX_SLOTS, _base_slots() + _accounts().slots_bought())
	var rows := [
		["CHARGE", now.energy_pct / 140.0, then.energy_pct / 140.0, true],
		["KNOCKS", now.hp / 5.0, then.hp / 5.0, true],
		["SPEED", now.speed / 384.0, then.speed / 384.0, true],
		["LAMP REACH", now.lamp_range / float(160 * Fx.ONE), then.lamp_range / float(160 * Fx.ONE), true],
		["LAMP WIDTH", now.lamp_half / 1365.0, then.lamp_half / 1365.0, true],
		["NOISE", now.eel_hear / float(96 * Fx.ONE), then.eel_hear / float(96 * Fx.ONE), false],
		["CARD SLOTS", slots / 6.0, slots / 6.0, true],
	]
	var f := Desk.font("plate")
	for i in rows.size():
		var y := st.position.y + 44 + i * 40
		var row: Array = rows[i]
		draw_string(f, Vector2(st.position.x + 14, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(Desk.STENCIL, 0.85))
		var br := Rect2(st.position.x + 14, y + 6, st.size.x - 28, 12)
		draw_rect(br, Color(0, 0, 0, 0.6))
		var a: float = clampf(row[1], 0.0, 1.0)
		var b: float = clampf(row[2], 0.0, 1.0)
		var better: bool = (b > a) == bool(row[3])
		if b > a:
			draw_rect(Rect2(br.position, Vector2(br.size.x * b, br.size.y)), Color(Desk.AMBER, 0.9) if better else Color(Desk.RED_LAMP, 0.85))
		draw_rect(Rect2(br.position, Vector2(br.size.x * minf(a, b) if b < a else br.size.x * a, br.size.y)), Color(0.85, 0.85, 0.8))
		if b < a:
			draw_rect(Rect2(br.position + Vector2(br.size.x * b, 0), Vector2(br.size.x * (a - b), br.size.y)), Color(Desk.AMBER, 0.6) if better else Color(Desk.RED_LAMP, 0.7))
	var extra := []
	if then.red_lamp:
		extra.append("JELLYFISH CAN'T SEE THE LAMP")
	if then.flares > 0:
		extra.append("%d FLARES, NO LASER" % then.flares)
	if then.reserve:
		extra.append("A RESERVE CELL")
	if then.insulated:
		extra.append("VALVES DON'T STING")
	if then.hydrophone:
		extra.append("HEARS THROUGH ROCK")
	for i in extra.size():
		draw_string(f, Vector2(st.position.x + 14, st.end.y + 20 + i * 18), str(extra[i]), HORIZONTAL_ALIGNMENT_LEFT, st.size.x - 20, 13, Color(Desk.AMBER, 0.85))


func _draw_cards_panel() -> void:
	var a := _accounts()
	var cp := Rect2(1008, 84, 246, 330)
	draw_rect(cp, Color(0.06, 0.08, 0.08, 0.92))
	draw_rect(cp, BRONZE_DK, false, 2.0)
	Desk.engraved(self, Rect2(cp.position.x, cp.position.y + 6, cp.size.x, 18), "TYPE PLATES", 15, Color(Desk.STENCIL, 0.85))
	var f := Desk.font("plate")
	var certs := _certified_count()
	var y := cp.position.y + 32
	for p: Dictionary in Accounts.catalogue()["plates"]:
		var id: String = p["id"]
		var owned := a.owned(id)
		var locked := int(p["unlock"]) > certs
		var r := Rect2(cp.position.x + 10, y, cp.size.x - 20, 42)
		draw_rect(r, NAVY.darkened(0.15) if owned else Color(0.08, 0.09, 0.09))
		draw_rect(r, Color(0, 0, 0, 0.5), false, 1.5)
		draw_string(f, r.position + Vector2(8, 17), str(p["name"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 70, 14, Color(Desk.STENCIL, 0.95 if owned else 0.6))
		draw_string(Desk.font("type"), r.position + Vector2(8, 34), str(p["text"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 10, Color(Desk.STENCIL, 0.55))
		var tag := "ISSUED" if owned else ("SECTOR %d" % (int(p["unlock"]) + 1) if locked else Accounts.fmt(int(p["price"])))
		var tc := Color(0.5, 0.9, 0.55) if owned else (Color(Desk.STENCIL, 0.4) if locked else Color(0.95, 0.45, 0.32))
		draw_string(f, Vector2(r.end.x - 8 - f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, r.position.y + 17), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tc)
		if not owned and not locked:
			_hits.append([r, "plate", id])
		y += 48
	# Card-reader slots: the open ones, and the price of the next.
	Desk.engraved(self, Rect2(cp.position.x, y + 4, cp.size.x, 16), "CARD READER SLOTS", 13, Color(Desk.STENCIL, 0.85))
	var open := mini(Accounts.MAX_SLOTS, _base_slots() + a.slots_bought())
	var price := a.next_slot_price(_base_slots())
	for i in Accounts.MAX_SLOTS:
		var r := Rect2(cp.position.x + 12 + i * 38, y + 26, 32, 40)
		var is_open := i < open
		draw_rect(r, Desk.CARD if is_open else Color(0.08, 0.09, 0.09))
		draw_rect(r, Color(0, 0, 0, 0.6), false, 1.5)
		if not is_open:
			_lock(r.get_center() + Vector2(0, -4))
			if i == open and price > 0:
				draw_circle(r.get_center() + Vector2(0, 12), 5.0, VALVE)
				_hits.append([r, "slot", str(i)])
	if price > 0:
		draw_string(f, Vector2(cp.position.x + 12, y + 84), "NEXT SLOT  %s" % Accounts.fmt(price), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.45, 0.32))


func _lock(c: Vector2) -> void:
	draw_arc(c + Vector2(0, -4), 6.0, PI, TAU, 8, Color(Desk.STENCIL, 0.5), 2.0)
	draw_rect(Rect2(c + Vector2(-7, -4), Vector2(14, 11)), Color(Desk.STENCIL, 0.5))


## The drawer: every part for the open socket, as cards on the bench.
func _draw_drawer() -> void:
	var a := _accounts()
	var dr := Rect2(0, 470, 1280, 250)
	draw_rect(dr, Color(0.09, 0.1, 0.1))
	draw_rect(Rect2(0, 470, 1280, 6), BRONZE)
	for i in 40:
		var x := i * 34.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 476), Vector2(x + 17, 476), Vector2(x + 5, 484), Vector2(x - 12, 484)]), Color(0.55, 0.45, 0.12, 0.35))
	var sname: String = Accounts.catalogue()["socket_names"][socket]
	Desk.engraved(self, Rect2(0, 488, 1280, 20), "%s  ·  WHAT FITS HERE  ·  TAP TO LOOK, STAMP TO FIT OR BUY" % sname, 15, Color(Desk.STENCIL, 0.85))
	var cards: Array = [{"id": "", "name": Accounts.catalogue()["stock"][socket]["name"], "text": Accounts.catalogue()["stock"][socket]["text"]}]
	for p: Dictionary in Accounts.parts_for(socket):
		cards.append(p)
	var certs := _certified_count()
	var w := 190.0
	var gap := 16.0
	var x0 := (1280.0 - (cards.size() * w + (cards.size() - 1) * gap)) * 0.5
	for i in cards.size():
		var p: Dictionary = cards[i]
		var id: String = p["id"]
		var fitted: bool = a.fitted_in(socket) == id
		var owned: bool = id == "" or a.owned(id)
		var locked: bool = id != "" and int(p.get("unlock", 0)) > certs
		var sel: bool = preview == id
		var cr := Rect2(x0 + i * (w + gap), 518 - (14 if sel else 0), w, 186)
		Desk.draw_paper(self, cr, Desk.CARD if owned else Desk.PAPER, 41 + i, true)
		if sel:
			draw_rect(cr.grow(3), Color(Desk.AMBER_HOT, 0.9), false, 3.0)
		var art := id if id != "" else str(STOCK_LAYER[socket]) if STOCK_LAYER[socket] != "" else socket
		LabView.icon(self, art, cr.position + Vector2(cr.size.x * 0.5, 46), 64.0, Desk.INK if not locked else Desk.INK_SOFT, 2.5)
		Desk.centred(self, Rect2(cr.position.x + 4, cr.position.y + 84, cr.size.x - 8, 20), str(p["name"]), Desk.font("plate"), 18, Desk.INK)
		draw_multiline_string(Desk.font("type"), cr.position + Vector2(12, 120), str(p["text"]), HORIZONTAL_ALIGNMENT_LEFT, cr.size.x - 24, 12, 3, Desk.INK_SOFT)
		# The stamp.
		var label := ""
		var col := Desk.RED_INK
		if fitted:
			label = "FITTED"
			col = Color(0.1, 0.35, 0.18)
		elif owned:
			label = "FIT IT"
			col = Desk.INK
		elif locked:
			label = "SECTOR %d" % (int(p["unlock"]) + 1)
			col = Desk.INK_SOFT
		else:
			label = "BUY  %s" % Accounts.fmt(int(p["price"]))
			if a.wage() < int(p["price"]):
				col = Color(Desk.RED_INK, 0.5)
		var badge := Rect2(cr.position + Vector2(cr.size.x * 0.5 - 64, cr.size.y - 36), Vector2(128, 28))
		draw_rect(badge, Color(col, 0.85), false, 2.0)
		Desk.centred(self, badge, label, Desk.font("plate"), 16, col)
		var info := Rect2(cr.end - Vector2(26, cr.size.y - 6), Vector2(20, 20))
		draw_circle(info.get_center(), 9.0, Color(Desk.INK, 0.12))
		draw_arc(info.get_center(), 9.0, 0, TAU, 16, Color(Desk.INK, 0.5), 1.2)
		Desk.centred(self, info, "i", Desk.font("type"), 13, Desk.INK)
		_hits.append([cr, "card", id])
		if not fitted and not locked:
			_hits.append([badge, "act", id])
		elif fitted and id != "":
			_hits.append([badge, "act", id])   # tapping FITTED takes it off again
		_hits.append([info, "info", id if id != "" else "stock:" + socket])


func _header() -> void:
	var a := _accounts()
	var pl := Desk.font("plate")
	var plaque := Rect2(20, 14, 300, 34)
	draw_rect(plaque, BRONZE_DK)
	draw_rect(plaque.grow(-3), BRONZE)
	Desk.engraved(self, plaque, "HANGAR  ·  STATION 9", 18)
	var owing: int = console._debt()
	Desk.draw_odometer(self, Rect2(690, 14, 118, 32), float(owing), 6, 22)
	draw_string(pl, Vector2(814, 26), "OWING", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Desk.STENCIL, 0.8))
	draw_string(pl, Vector2(814, 42), "SCRIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Desk.STENCIL, 0.8))
	var hand := Rect2(900, 14, 118, 32)
	Desk.draw_odometer(self, hand, float(a.wage()), 6, 22, Color(0.12, 0.2, 0.14), Color(0.86, 0.95, 0.82))
	if _deny > 0.0:
		draw_rect(hand.grow(3), Color(Desk.RED_LAMP, _deny), false, 3.0)
	draw_string(pl, Vector2(1024, 26), "IN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Desk.STENCIL, 0.8))
	draw_string(pl, Vector2(1024, 42), "HAND", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Desk.STENCIL, 0.8))
	_knob(Vector2(1248, 30), "BACK TO THE DESK", true)
	_hits.append([Rect2(1080, 10, 190, 42), "back", ""])
	_knob(Vector2(370, 30), "PAY %s IN AGAINST THE DEBT" % Accounts.fmt(PAY_STEP), false)
	_hits.append([Rect2(354, 10, 300, 42), "pay", ""])


func _knob(c: Vector2, label: String, label_left := false) -> void:
	draw_circle(c + Vector2(1, 2), 13.0, Color(0, 0, 0, 0.5))
	draw_circle(c, 13.0, VALVE.darkened(0.35))
	draw_circle(c, 10.0, VALVE)
	draw_arc(c, 10.0, PI * 1.1, PI * 1.6, 8, Color(0.85, 0.35, 0.25, 0.5), 2.0)
	var f := Desk.font("plate")
	var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var p := c + (Vector2(-22 - w, 5) if label_left else Vector2(20, 5))
	draw_string(f, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(Desk.STENCIL, 0.9))


## A part's page in the Company's catalogue (draft B, on a long press): the engraving, its story, and
## what would change, NOW and WITH IT.
func _draw_page() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var stock := page.begins_with("stock:")
	var info: Dictionary = {}
	var sock := socket
	if stock:
		sock = page.substr(6)
		var st: Dictionary = Accounts.catalogue()["stock"][sock]
		info = {"id": "", "name": st["name"], "story": st["text"], "socket": sock}
	else:
		info = Accounts.part_info(page)
		sock = str(info.get("socket", socket))
	var r := Rect2(220, 60, 840, 600)
	Desk.draw_paper(self, r, Desk.PAPER, 61, true)
	draw_line(Vector2(r.get_center().x, r.position.y + 20), Vector2(r.get_center().x, r.end.y - 20), Color(0, 0, 0, 0.25), 3.0)
	var lh := Desk.font("letterhead")
	var ty := Desk.font("type")
	var lp := Rect2(r.position, Vector2(r.size.x * 0.5, r.size.y))
	var rp := Rect2(r.position + Vector2(r.size.x * 0.5, 0), Vector2(r.size.x * 0.5, r.size.y))
	Desk.centred(self, Rect2(lp.position.x, lp.position.y + 22, lp.size.x, 18), "THE COMPANY  ·  EQUIPMENT FOR SURVEY UNITS", lh, 11, Desk.INK_SOFT)
	Desk.centred(self, Rect2(lp.position.x, lp.position.y + 42, lp.size.x, 16), "SOCKET: %s" % Accounts.catalogue()["socket_names"][sock], lh, 11, Desk.INK_SOFT)
	var art := str(info.get("id", "")) if str(info.get("id", "")) != "" else (str(STOCK_LAYER[sock]) if STOCK_LAYER[sock] != "" else sock)
	LabView.icon(self, art, Vector2(lp.get_center().x, lp.position.y + 230), 220.0, Desk.INK, 3.0)
	Desk.centred(self, Rect2(lp.position.x, lp.position.y + 400, lp.size.x, 40), str(info["name"]), Desk.font("plate"), 34, Desk.INK)
	if not stock:
		Desk.centred(self, Rect2(lp.position.x, lp.position.y + 470, lp.size.x, 40), "%s SCRIP" % Accounts.fmt(int(info["price"])), Desk.font("plate"), 30, Desk.RED_INK)
	draw_multiline_string(ty, rp.position + Vector2(26, 56), str(info.get("story", info.get("text", ""))), HORIZONTAL_ALIGNMENT_LEFT, rp.size.x - 52, 15, -1, Desk.INK)
	# NOW / WITH IT.
	var now := Kit.from_parts(_fit_now().values())
	var with_f := _fit_now()
	if stock:
		with_f.erase(sock)
	else:
		with_f[sock] = page
	var then := Kit.from_parts(with_f.values())
	var y0 := rp.position.y + 290.0
	draw_string(Desk.font("plate"), Vector2(rp.position.x + 170, y0), "NOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Desk.INK_SOFT)
	draw_string(Desk.font("plate"), Vector2(rp.position.x + 250, y0), "WITH IT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Desk.INK_SOFT)
	var rows := [
		["CHARGE", "%d%%" % now.energy_pct, "%d%%" % then.energy_pct, then.energy_pct - now.energy_pct],
		["KNOCKS", str(now.hp), str(then.hp), then.hp - now.hp],
		["SPEED", "%.2f" % (now.speed / 256.0), "%.2f" % (then.speed / 256.0), then.speed - now.speed],
		["LAMP REACH", "%.1f" % (now.lamp_range / float(Fx.TILE)), "%.1f" % (then.lamp_range / float(Fx.TILE)), then.lamp_range - now.lamp_range],
		["HEARD AT", "%.0f" % (now.eel_hear / float(Fx.TILE)), "%.0f" % (then.eel_hear / float(Fx.TILE)), now.eel_hear - then.eel_hear],
	]
	for i in rows.size():
		var y := y0 + 28 + i * 26
		var row: Array = rows[i]
		draw_string(ty, Vector2(rp.position.x + 26, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Desk.INK)
		draw_string(ty, Vector2(rp.position.x + 170, y), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Desk.INK_SOFT)
		var d: int = row[3]
		draw_string(ty, Vector2(rp.position.x + 250, y), row[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.1, 0.35, 0.18) if d > 0 else (Desk.RED_INK if d < 0 else Desk.INK))
	var fr := Rect2(rp.end.x - 160, rp.end.y - 64, 130, 40)
	draw_rect(fr, Color(Desk.INK, 0.6), false, 2.0)
	Desk.centred(self, fr, "CLOSE", Desk.font("plate"), 20, Color(Desk.INK, 0.75))
	_hits.append([Rect2(Vector2.ZERO, size), "page_close", ""])


## Line drawings of the parts, as engraved in the catalogue (and on the sockets).
static func icon(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color, w := 2.0) -> void:
	match id:
		"lamp_std", "spotlight", "red_lamp", "floodlight", "lamp":
			ci.draw_arc(c + Vector2(-s * 0.2, 0), s * 0.3, PI * 0.5, PI * 1.5, 12, col, w)
			ci.draw_line(c + Vector2(-s * 0.2, -s * 0.3), c + Vector2(s * 0.15, -s * 0.3), col, w)
			ci.draw_line(c + Vector2(-s * 0.2, s * 0.3), c + Vector2(s * 0.15, s * 0.3), col, w)
			ci.draw_line(c + Vector2(s * 0.15, -s * 0.35), c + Vector2(s * 0.15, s * 0.35), col, w)
			var spread := 0.15 if id == "spotlight" else (0.6 if id == "floodlight" else 0.35)
			for k in 3:
				var a := (k - 1) * spread
				ci.draw_line(c + Vector2(s * 0.25, 0), c + Vector2(s * 0.25, 0) + Vector2.from_angle(a) * s * 0.4, col if id != "red_lamp" else Color(0.85, 0.25, 0.15), w * 0.8)
		"pods_std", "twin_screws", "silent_fins", "drive":
			ci.draw_rect(Rect2(c - Vector2(s * 0.35, s * 0.15), Vector2(s * 0.55, s * 0.3)), col, false, w)
			if id == "silent_fins":
				ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.2, -s * 0.15), c + Vector2(s * 0.45, -s * 0.3), c + Vector2(s * 0.45, s * 0.3), c + Vector2(s * 0.2, s * 0.15)]), col, w)
			else:
				var blades := 4 if id == "twin_screws" else 3
				for k in blades:
					var a := k * TAU / blades + 0.4
					ci.draw_line(c + Vector2(s * 0.3, 0), c + Vector2(s * 0.3, 0) + Vector2(cos(a) * s * 0.08, sin(a) * s * 0.3), col, w)
		"battery_bank", "reserve_cell", "belly":
			for k in (2 if id == "battery_bank" else 1):
				var r := Rect2(c + Vector2(-s * 0.3 + k * s * 0.32 + (0.16 * s if id != "battery_bank" else 0.0), -s * 0.32), Vector2(s * 0.26, s * 0.64))
				ci.draw_rect(r, col, false, w)
				ci.draw_rect(Rect2(r.position + Vector2(s * 0.07, -s * 0.07), Vector2(s * 0.12, s * 0.07)), col if id != "reserve_cell" else Color(0.85, 0.25, 0.15))
		"plating", "insulated", "hull":
			var pts := PackedVector2Array([c + Vector2(-s * 0.35, -s * 0.25), c + Vector2(s * 0.35, -s * 0.25), c + Vector2(s * 0.3, s * 0.3), c + Vector2(-s * 0.3, s * 0.3), c + Vector2(-s * 0.35, -s * 0.25)])
			ci.draw_polyline(pts, col, w)
			if id == "plating":
				for k in 4:
					ci.draw_circle(c + Vector2(-s * 0.22 + k * s * 0.15, -s * 0.12), 2.2, col)
			elif id == "insulated":
				ci.draw_line(c + Vector2(-s * 0.32, s * 0.02), c + Vector2(s * 0.32, s * 0.02), col, w * 2.0)
		"laser_std", "tool":
			ci.draw_rect(Rect2(c - Vector2(s * 0.4, s * 0.1), Vector2(s * 0.3, s * 0.2)), col, false, w)
			ci.draw_line(c + Vector2(-s * 0.1, 0), c + Vector2(s * 0.4, 0), col, w * 1.5)
			ci.draw_circle(c + Vector2(s * 0.42, 0), 3.0, Color(1.0, 0.3, 0.15))
		"hydrophone":
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.3), c, col, w)
			ci.draw_polyline(PackedVector2Array([c, c + Vector2(s * 0.35, -s * 0.3), c + Vector2(s * 0.1, -s * 0.38), c]), col, w)
			for k in 2:
				ci.draw_arc(c + Vector2(s * 0.3, -s * 0.35), s * (0.15 + k * 0.1), -0.6, 0.9, 8, col, w * 0.6)
		"antenna_std", "hatch":
			ci.draw_line(c + Vector2(0, s * 0.35), c + Vector2(0, -s * 0.25), col, w)
			ci.draw_circle(c + Vector2(0, -s * 0.3), s * 0.07, Color(0.5, 1.0, 0.6))
			for k in 2:
				ci.draw_arc(c + Vector2(0, -s * 0.3), s * (0.16 + k * 0.1), -PI * 0.85, -PI * 0.15, 8, col, w * 0.6)
		"flares":
			for k in 3:
				var x := c.x - s * 0.2 + k * s * 0.2
				ci.draw_rect(Rect2(Vector2(x - 4, c.y - s * 0.2), Vector2(8, s * 0.45)), col, false, w)
				ci.draw_circle(Vector2(x, c.y - s * 0.25), 4.0, Color(0.85, 0.25, 0.15))
		_:
			ci.draw_circle(c, s * 0.3, col, false, w)
