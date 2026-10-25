class_name CardTable
extends Control
## The cards and where they lie: in the press's tray as they come out, in the reader's slots
## under the glass lid, or on their way down the pulp chute. Every card fills one slot; the
## reader has as many as the sector allows (two at first) and the rest are sealed.
##
## Lift the lid (tap it, or its handle), drag a card from the tray into a slot, drag cards
## between slots to reorder, and shut the lid: the reader won't read with it open. Drop a
## card in the PULP chute to destroy it. Dropped anywhere else, a card goes back where it was.
## This control covers the screen but only catches a touch on a card or on the lid.

signal changed                   # the cards in the slots changed
signal lid_moved(open: bool)
signal pulped
signal refused(why: String)

const TRAY_MAX := 4
const TRAY_STEP := 24.0
const MAX_SLOTS := 6
const DRAG_START := 6.0

var slot_count := 2
var cards: Array = []            # {rule, where: "slot"|"tray", i, pos: Vector2, born: float}
var lamps: Array = []            # per slot: {state, reason}
var lid_open := false
var _lid := 0.0                  # 0 shut .. 1 open
var _press := -1                 # card index under the finger
var _press_pos := Vector2.ZERO
var _grab := Vector2.ZERO
var _dragging := false
var _drag_pos := Vector2.ZERO
var _lid_press := false
var _pulp: Array = []            # {rule, from: Vector2, t0}
var _bits: Array = []            # shreds flying out of the chute: {p, v, t0, rot}
var _flash := {}                 # slot -> time it lit up


func _init() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(n_slots: int, slot_rules: Array, tray_rules: Array) -> void:
	slot_count = n_slots
	cards.clear()
	for i in mini(slot_rules.size(), n_slots):
		var r: Dictionary = slot_rules[i]
		if not r.is_empty():
			cards.append({"rule": r, "where": "slot", "i": i, "pos": slot_rect(i).position, "born": 0.0})
	for k in mini(tray_rules.size(), TRAY_MAX):
		cards.append({"rule": tray_rules[k], "where": "tray", "i": k, "pos": tray_pos(k), "born": 0.0})
	queue_redraw()


# ------------------------------------------------------------------ geometry

func card_size() -> Vector2:
	var s := Desk.v("card_size")
	return Vector2(float(s[0]), float(s[1]))


func slot_rect(i: int) -> Rect2:
	var bed := Desk.r("card_bed")
	var pitch := float(Desk.layout()["lamps"]["pitch"])
	var cs := card_size()
	return Rect2(Vector2(bed.position.x + (bed.size.x - cs.x) * 0.5, bed.position.y + 2.0 + i * pitch), cs)


func tray_pos(k: int) -> Vector2:
	var t := Desk.r("tray")
	return t.position + Vector2(4.0, 6.0 + k * TRAY_STEP)


func _target(c: Dictionary) -> Vector2:
	return slot_rect(c["i"]).position if c["where"] == "slot" else tray_pos(c["i"])


func _lid_rect() -> Rect2:
	return Desk.r("lid")


# ------------------------------------------------------------------ the deck

## The rules in the slots, in reading order (empty slots are skipped).
func deck() -> Array:
	var out: Array = []
	for i in slot_count:
		var c := _in_slot(i)
		if c >= 0:
			out.append(cards[c]["rule"])
	return out


## Slot index of each card of deck(), so lamps and flashes find their card.
func deck_slots() -> Array[int]:
	var out: Array[int] = []
	for i in slot_count:
		if _in_slot(i) >= 0:
			out.append(i)
	return out


func slot_rules() -> Array:
	var out: Array = []
	for i in slot_count:
		var c := _in_slot(i)
		out.append(cards[c]["rule"] if c >= 0 else {})
	return out


func tray_rules() -> Array:
	var t: Array = []
	for c: Dictionary in cards:
		if c["where"] == "tray":
			t.append(c)
	t.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["i"]) < int(b["i"]))
	return t.map(func(c: Dictionary) -> Dictionary: return c["rule"])


func tray_full() -> bool:
	return _tray_count() >= TRAY_MAX


func _tray_count() -> int:
	var n := 0
	for c: Dictionary in cards:
		if c["where"] == "tray":
			n += 1
	return n


func _in_slot(i: int) -> int:
	for k in cards.size():
		if cards[k]["where"] == "slot" and cards[k]["i"] == i:
			return k
	return -1


## A fresh card out of the press: it slides from the press's mouth into the tray.
func add_printed(rule: Dictionary) -> void:
	var ex := Desk.r("card_exit")
	cards.append({"rule": rule, "where": "tray", "i": _tray_count(), "pos": Vector2(ex.position.x + 40.0, ex.position.y - 4.0),
		"born": Time.get_ticks_msec() / 1000.0})
	queue_redraw()


func set_lid(open: bool) -> void:
	if open == lid_open:
		return
	lid_open = open
	Sfx.play("cover", -4.0, 1.1 if open else 0.9)
	if not open:
		get_tree().create_timer(0.22).timeout.connect(func() -> void: Sfx.play("switch", -4.0, 0.8))
	lid_moved.emit(open)


func flash(slot: int) -> void:
	_flash[slot] = Time.get_ticks_msec() / 1000.0


func _compact_tray() -> void:
	var t: Array = []
	for c: Dictionary in cards:
		if c["where"] == "tray":
			t.append(c)
	t.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["i"]) < int(b["i"]))
	for k in t.size():
		t[k]["i"] = k


# ------------------------------------------------------------------ touch

func _card_rect(k: int) -> Rect2:
	return Rect2(cards[k]["pos"], card_size())


func _card_at(p: Vector2) -> int:
	# Topmost first: tray cards stack downwards, so the last drawn is on top.
	var order := _draw_order()
	for j in range(order.size() - 1, -1, -1):
		var k: int = order[j]
		var c: Dictionary = cards[k]
		if c["where"] == "slot" and _lid < 0.9:
			continue
		var r := _card_rect(k)
		if c["where"] == "tray":
			# A card under another shows only its top strip.
			var above := _tray_count() - 1 - int(c["i"])
			if above > 0:
				r.size.y = TRAY_STEP
		if r.has_point(p):
			return k
	return -1


func _lid_hit(p: Vector2) -> bool:
	if Desk.r("lid_handle").has_point(p):
		return true
	var lr := _lid_rect()
	if not lid_open:
		return lr.has_point(p)
	return Rect2(lr.position + Vector2(0, -16), Vector2(lr.size.x, 34)).has_point(p)


func _has_point(p: Vector2) -> bool:
	return _dragging or _press >= 0 or _lid_press or _card_at(p) >= 0 or _lid_hit(p)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = _card_at(event.position)
			_press_pos = event.position
			_dragging = false
			_lid_press = _press < 0 and _lid_hit(event.position)
			if _press >= 0:
				_grab = event.position - cards[_press]["pos"]
			accept_event()
		else:
			if _press >= 0 and _dragging:
				_drop(_press, event.position)
			elif _lid_press:
				set_lid(not lid_open)
			_press = -1
			_dragging = false
			_lid_press = false
			queue_redraw()
	elif event is InputEventMouseMotion and _press >= 0:
		if not _dragging and event.position.distance_to(_press_pos) > DRAG_START:
			_dragging = true
			Sfx.play("paper", -12.0)
		if _dragging:
			_drag_pos = event.position
			cards[_press]["pos"] = event.position - _grab
			queue_redraw()


## Where a dragged card was let go.
func _drop(k: int, p: Vector2) -> void:
	var c: Dictionary = cards[k]
	if Desk.r("chute_mouth").grow(16).has_point(p) or Desk.r("chute").has_point(p):
		var from_slot: bool = c["where"] == "slot"
		_pulp.append({"rule": c["rule"], "from": c["pos"], "t0": Time.get_ticks_msec() / 1000.0})
		cards.remove_at(k)
		_compact_tray()
		Sfx.play("tear", -2.0)
		Sfx.play("crank", -6.0, 0.6)
		pulped.emit()
		if from_slot:
			changed.emit()
		return
	for j in slot_count:
		if slot_rect(j).grow(10).has_point(p):
			if not lid_open:
				refused.emit("lid")
				return
			var other := _in_slot(j)
			if other >= 0 and other != k:
				# Swap: the card already there goes where this one came from.
				cards[other]["where"] = c["where"]
				cards[other]["i"] = c["i"]
			c["where"] = "slot"
			c["i"] = j
			_compact_tray()
			Sfx.play("drum", -4.0, 0.7)
			changed.emit()
			return
	if Desk.r("tray").grow(12).has_point(p) and c["where"] == "slot":
		if tray_full():
			refused.emit("tray_full")
			return
		c["where"] = "tray"
		c["i"] = _tray_count()
		_compact_tray()
		changed.emit()
		return
	# Anywhere else: it slides back where it was.


# ------------------------------------------------------------------ animation and drawing

func _process(delta: float) -> void:
	_lid = move_toward(_lid, 1.0 if lid_open else 0.0, delta * 4.0)
	for k in cards.size():
		if _dragging and k == _press:
			continue
		var c: Dictionary = cards[k]
		var t := _target(c)
		var p: Vector2 = c["pos"]
		c["pos"] = p.lerp(t, minf(1.0, delta * (9.0 if c["born"] == 0.0 else 6.0)))
	var now := Time.get_ticks_msec() / 1000.0
	for i in range(_pulp.size() - 1, -1, -1):
		var age: float = now - float(_pulp[i]["t0"])
		if age > 0.5 and not _pulp[i].has("shredded"):
			_pulp[i]["shredded"] = true
			var m := Desk.r("chute_mouth")
			for b in 18:
				_bits.append({"p": m.get_center() + Vector2(randf_range(-30, 30), 0), "v": Vector2(randf_range(-60, 60), randf_range(-160, -60)),
					"t0": now, "rot": randf() * TAU})
		if age > 0.6:
			_pulp.remove_at(i)
	for i in range(_bits.size() - 1, -1, -1):
		var b: Dictionary = _bits[i]
		b["v"] = (b["v"] as Vector2) + Vector2(0, 420) * delta
		b["p"] = (b["p"] as Vector2) + (b["v"] as Vector2) * delta
		if now - float(b["t0"]) > 1.2:
			_bits.remove_at(i)
	queue_redraw()


func _draw_order() -> Array[int]:
	var o: Array[int] = []
	for k in cards.size():
		if cards[k]["where"] == "slot":
			o.append(k)
	var t: Array[int] = []
	for k in cards.size():
		if cards[k]["where"] == "tray":
			t.append(k)
	t.sort_custom(func(a: int, b: int) -> bool: return int(cards[a]["i"]) < int(cards[b]["i"]))
	o.append_array(t)
	return o


func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var f := Desk.font("plate")
	var cs := card_size()
	# Slot guides, numbers and the sealed slots.
	for i in MAX_SLOTS:
		var r := slot_rect(i)
		if i < slot_count:
			draw_rect(r.grow(2), Color(0, 0, 0, 0.35), false, 1.0)
			for side: float in [r.position.x - 3.0, r.end.x + 1.0]:
				draw_rect(Rect2(side, r.position.y + 6, 2, r.size.y - 12), Color(0.7, 0.55, 0.3, 0.7))
			draw_string(f, Vector2(r.position.x - 22, r.get_center().y + 7), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Desk.STENCIL, 0.55))
		else:
			_draw_sealed(r)
	# Pilot lamps.
	var lr: Dictionary = Desk.layout()["lamps"]
	for i in MAX_SLOTS:
		var lp := Vector2(float(lr["rail_x"]), float(lr["first_y"]) + i * float(lr["pitch"]))
		var st := "off"
		if i < lamps.size():
			st = lamps[i]["state"]
		_draw_lamp(lp, st if i < slot_count else "off", now)
	# Cards in the slots.
	for k in _draw_order():
		var c: Dictionary = cards[k]
		if _dragging and k == _press:
			continue
		if c["where"] == "slot":
			var lamp: Dictionary = lamps[c["i"]] if int(c["i"]) < lamps.size() else {}
			var lit := clampf(1.0 - (now - float(_flash.get(c["i"], -10.0))) / 0.6, 0.0, 1.0)
			CardArt.draw(self, Rect2(c["pos"], cs), c["rule"], lamp, lit)
	_draw_lid(now)
	# Cards in the tray (above the reader's glass, below the dragged card).
	for k in _draw_order():
		var c: Dictionary = cards[k]
		if (_dragging and k == _press) or c["where"] != "tray":
			continue
		var tilt := deg_to_rad(1.2 if int(c["i"]) % 2 == 0 else -0.8)
		var rr := Rect2(c["pos"], cs)
		var base := Transform2D(tilt, rr.get_center())
		draw_set_transform_matrix(base)
		CardArt.draw(self, Rect2(-cs * 0.5, cs), c["rule"], {}, 0.0, base)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	var tr := Desk.r("tray")
	if _tray_count() == 0:
		Desk.centred(self, Rect2(tr.position + Vector2(0, 50), Vector2(tr.size.x, 30)), "tray empty", Desk.font("hand"), 20, Color(Desk.NOTE, 0.25))
	# Drop zones while dragging.
	if _dragging and _press >= 0:
		var m := Desk.r("chute_mouth")
		var over_chute := m.grow(16).has_point(_drag_pos) or Desk.r("chute").has_point(_drag_pos)
		Desk.draw_glow(self, m.get_center(), 60.0, Color(Desk.RED_LAMP, 0.35 if over_chute else 0.12))
		if lid_open:
			for j in slot_count:
				if slot_rect(j).grow(10).has_point(_drag_pos):
					draw_rect(slot_rect(j).grow(4), Color(Desk.AMBER, 0.6), false, 2.0)
	# The chute: its flap swings in as a card goes down; the card sinks out of sight.
	_draw_chute(now)
	# The dragged card, lifted.
	if _dragging and _press >= 0:
		var c: Dictionary = cards[_press]
		var rr := Rect2(c["pos"], cs)
		draw_rect(Rect2(rr.position + Vector2(10, 14), rr.size), Color(0, 0, 0, 0.4))
		var base := Transform2D(-0.04, Vector2(1.04, 1.04), 0.0, rr.get_center())
		draw_set_transform_matrix(base)
		CardArt.draw(self, Rect2(-cs * 0.5, cs), c["rule"], {}, 0.0, base)
		draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_sealed(r: Rect2) -> void:
	var pr := r.grow_individual(4, 1, 4, 1)
	draw_rect(pr, Color(0.16, 0.17, 0.16))
	draw_rect(pr, Color(0.05, 0.05, 0.05), false, 2.0)
	for k in 6:
		var x := pr.position.x + 18.0 + k * 9.0
		draw_line(Vector2(x, pr.position.y + 4), Vector2(x - 8, pr.end.y - 4), Color(0.75, 0.62, 0.1, 0.5), 3.0)
	for cx: float in [pr.position.x + 7.0, pr.end.x - 7.0]:
		for cy: float in [pr.position.y + 7.0, pr.end.y - 7.0]:
			draw_circle(Vector2(cx, cy), 2.6, Color(0.45, 0.45, 0.42))
	Desk.centred(self, Rect2(pr.position + Vector2(60, 0), pr.size - Vector2(60, 0)), "SEALED  ·  REQUISITION PENDING", Desk.font("plate"), 13,
		Color(Desk.STENCIL, 0.45))


func _draw_lamp(p: Vector2, st: String, now: float) -> void:
	match st:
		"run":
			Desk.draw_glow(self, p, 30.0, Color(Desk.AMBER, 0.8))
			draw_circle(p, 6.0, Desk.AMBER)
			draw_circle(p + Vector2(-1.5, -1.5), 2.2, Desk.AMBER_HOT)
		"set":
			var a := 0.5 + 0.4 * sin(now * 9.0)
			Desk.draw_glow(self, p, 22.0, Color(Desk.AMBER, 0.45 * a))
			draw_circle(p, 6.0, Color(Desk.AMBER, a))
		"skip":
			Desk.draw_glow(self, p, 18.0, Color(Desk.RED_LAMP, 0.35))
			draw_circle(p, 6.0, Color(0.55, 0.1, 0.06))
			draw_circle(p + Vector2(-1.5, -1.5), 1.8, Color(0.9, 0.3, 0.2, 0.7))
		_:
			draw_circle(p, 6.0, Color(0.09, 0.07, 0.05))
			draw_circle(p + Vector2(-1.5, -1.5), 1.6, Color(1, 1, 1, 0.08))


## The glass lid on its hinge along the top: shut, it lies over the cards with the work
## lamp's reflection in it; open, it stands up towards the operator, foreshortened to a sliver.
func _draw_lid(now: float) -> void:
	var lr := _lid_rect()
	var ang := _lid * deg_to_rad(84.0)
	var s := cos(ang)
	var hinge := Vector2(lr.get_center().x, lr.position.y)
	var base := Transform2D(0.0, Vector2(1.0, s), 0.0, hinge)
	draw_set_transform_matrix(base)
	var local := Rect2(Vector2(-lr.size.x * 0.5, 0), lr.size)
	# Glass.
	var g := local.grow(-9)
	draw_rect(g, Color(0.55, 0.75, 0.7, 0.07 + 0.08 * _lid))
	# The work lamp's reflection: two streaks across the glass.
	var sh := 0.08 + 0.1 * (1.0 - s)
	draw_line(g.position + Vector2(84, 2), g.position + Vector2(2, 150), Color(1, 1, 1, sh), 26.0)
	draw_line(g.position + Vector2(160, 2), g.position + Vector2(2, 290), Color(1, 1, 1, sh * 0.5), 8.0)
	var tex := Desk.tex("lid")
	if tex != null:
		var tsz := tex.get_size() * 0.5
		draw_texture_rect(tex, Rect2(Vector2(-tsz.x * 0.5 + 13.0, lr.size.y * 0.5 - tsz.y * 0.5), tsz), false,
			Color(1, 1, 1).darkened(0.35 * _lid))
	else:
		draw_rect(local, Color(0.6, 0.46, 0.22), false, 8.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# Condensation on the glass, beading when it's shut.
	if _lid < 0.05:
		for i in 26:
			var h := hash(i * 7919)
			var p := Vector2(lr.position.x + 14 + float(h % 250), lr.position.y + 14 + float((h >> 9) % 290))
			draw_circle(p, 1.0 + float((h >> 3) % 3) * 0.5, Color(0.8, 0.95, 0.9, 0.12))
	# The latch handle: label it.
	var hr := Desk.r("lid_handle")
	Desk.centred(self, Rect2(hr.position + Vector2(0, hr.size.y + 2), Vector2(hr.size.x, 14)), "OPEN" if not lid_open else "SHUT",
		Desk.font("plate"), 12, Color(Desk.STENCIL, 0.75))


func _draw_chute(now: float) -> void:
	var m := Desk.r("chute_mouth")
	var open := 0.0
	for p: Dictionary in _pulp:
		var age: float = now - float(p["t0"])
		open = maxf(open, 1.0 - absf(age - 0.25) * 3.0)
		# The card sinks into the throat, shaking.
		var k := clampf(age / 0.5, 0.0, 1.0)
		var cs := card_size() * (1.0 - 0.6 * k)
		var to := m.get_center() + Vector2(0, 10 * k)
		var pos: Vector2 = (p["from"] as Vector2).lerp(to - cs * 0.5, minf(1.0, age * 5.0))
		pos += Vector2(sin(now * 80.0) * 2.0 * k, 0)
		if k < 1.0:
			var base := Transform2D(sin(age * 30.0) * 0.1 * k, pos + cs * 0.5)
			draw_set_transform_matrix(base)
			CardArt.draw(self, Rect2(-cs * 0.5, cs), p["rule"], {}, 0.0, base)
			draw_set_transform_matrix(Transform2D.IDENTITY)
	var flap := Desk.tex("chute_flap")
	if flap != null:
		var fs := flap.get_size() * 0.5
		var s := 1.0 - 0.85 * clampf(open, 0.0, 1.0)
		draw_set_transform_matrix(Transform2D(0.0, Vector2(1.0, s), 0.0, Vector2(m.get_center().x, m.position.y)))
		draw_texture_rect(flap, Rect2(Vector2(-fs.x * 0.5, -4.0), fs), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	for b: Dictionary in _bits:
		var age := now - float(b["t0"])
		var a := clampf(1.2 - age, 0.0, 1.0)
		var pp: Vector2 = b["p"]
		var rot := float(b["rot"]) + age * 9.0
		var d := Vector2.from_angle(rot) * 4.0
		draw_line(pp - d, pp + d, Color(Desk.CARD, a), 2.0)
	var pr := Desk.plaque_rect("chute")
	Desk.engraved(self, pr, Desk.plaque("chute")[4], 13)
