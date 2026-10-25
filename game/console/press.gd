class_name CardPress
extends Control
## The press that makes order cards. Turn the ORDER wheel and the CONDITION wheel (drag them
## round by the grip, or tap either side to click one notch), set the value wheel and the
## NOT switch; each wheel rolls a printed drum behind the glass above it, so the operator sees the
## choice at the index line and the ones either side. Pull PRINT: the press stamps the
## card and it slides out into the tray, where the operator picks it up.
## Which orders the wheels carry depends on the type plates the Company has issued.

signal printed(rule: Dictionary)
signal refused(why: String)

const ORDERS := PressOrders.ORDERS
const CONDS := PressOrders.CONDS
const COND_VALUES := PressOrders.COND_VALUES
const PRINT_TIME := 0.7

var plates: Array = []
var order_wheel: Wheel
var cond_wheel: Wheel
var value: Drum
var order_drum: Drum
var cond_drum: Drum
var negate := false
var tray_full := false
var slots := 2
var _orders: Array = []
var _conds: Array[String] = []
var _lever := 0.0
var _lever_drag := false
var _lever_grab := 0.0
var _pulled := false
var _printing := -1.0            # time printing started, or -1
var _print_rule: Dictionary = {}
var _fresh := {}                 # plate -> time it was issued (its entries glint on the board)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func setup() -> void:
	order_drum = Drum.new()
	order_drum.font_size = 16
	_put(order_drum, Desk.r("order_drum"))
	cond_drum = Drum.new()
	cond_drum.font_size = 16
	for d: Drum in [order_drum, cond_drum]:
		d.wrap = true
		d.shade = 0.3
	_put(cond_drum, Desk.r("cond_drum"))
	order_wheel = Wheel.new()
	_put_wheel(order_wheel, "order_wheel", "wheel_order")
	cond_wheel = Wheel.new()
	_put_wheel(cond_wheel, "cond_wheel", "wheel_cond")
	# The wheels roll the drums; the drums can be rolled by hand too, and turn their wheel.
	order_wheel.turned.connect(func(i: int) -> void:
		order_drum.select(i)
		_show())
	cond_wheel.turned.connect(func(i: int) -> void:
		cond_drum.select(i)
		_refresh_value()
		_show())
	order_drum.turned.connect(func(i: int) -> void:
		order_wheel.turn_to(i)
		_show())
	cond_drum.turned.connect(func(i: int) -> void:
		cond_wheel.turn_to(i)
		_refresh_value()
		_show())
	value = Drum.new()
	value.font_size = 18
	_put(value, Desk.r("value_wheel"))
	value.turned.connect(func(_i: int) -> void: _show())


func _put(c: Control, r: Rect2) -> void:
	c.position = r.position - position
	c.size = r.size
	add_child(c)


func _put_wheel(w: Wheel, key: String, sprite: String) -> void:
	var v := Desk.v(key)
	var rad := float(v[2])
	w.sprite = sprite
	w.radius = rad
	w.position = Vector2(float(v[0]), float(v[1])) - position - Vector2(rad + 12, rad + 12)
	w.size = Vector2(rad + 12, rad + 12) * 2.0
	add_child(w)


func set_plates(p: Array, fresh: Array = []) -> void:
	plates = p
	var keep_o := order_wheel.index
	var old_order: Array = _orders[keep_o] if keep_o < _orders.size() else []
	_orders = []
	for o: Array in ORDERS:
		if plates.has(o[2]):
			_orders.append(o)
	_conds = []
	for c: String in CONDS:
		if c == "" or plates.has(c):
			_conds.append(c)
	order_wheel.count = _orders.size()
	cond_wheel.count = _conds.size()
	if not old_order.is_empty():
		order_wheel.index = maxi(0, _orders.find(old_order))
	cond_wheel.index = mini(cond_wheel.index, maxi(0, _conds.size() - 1))
	var now := Time.get_ticks_msec() / 1000.0
	for f: String in fresh:
		_fresh[f] = now
	_label_drums()
	order_drum.select(order_wheel.index)
	cond_drum.select(cond_wheel.index)
	_refresh_value()
	_show()


## What the drums have printed on them: one entry per notch of their wheel.
func _label_drums() -> void:
	var o_labels: Array[String] = []
	order_drum.fresh = {}
	for o: Array in _orders:
		var l := CardArt.order_label(o[0], o[1])
		o_labels.append(l)
		if _fresh.has(o[2]):
			order_drum.fresh[l] = _fresh[o[2]]
	order_drum.set_entries(o_labels)
	var c_labels: Array[String] = []
	cond_drum.fresh = {}
	for c: String in _conds:
		var l := CardArt.cond_label(c, "", negate and c != "")
		c_labels.append(l)
		if _fresh.has(c) or (negate and _fresh.has("not")):
			cond_drum.fresh[l] = _fresh.get(c, _fresh.get("not", 0.0))
	cond_drum.set_entries(c_labels)


func _cond() -> String:
	return _conds[cond_wheel.index] if cond_wheel.index < _conds.size() else ""


func _refresh_value() -> void:
	var c := _cond()
	var vals: Array[String] = []
	if COND_VALUES.has(c):
		for v: String in COND_VALUES[c]:
			if c == "executing" and int(v) > slots:
				continue
			vals.append(v)
	else:
		vals.append("–")
	value.locked = not COND_VALUES.has(c)
	var keep := value.current()
	value.set_entries(vals, keep if vals.has(keep) else (vals[mini(1, vals.size() - 1)] if c == "hostile_near" else ""))


## The card the press is set to print.
func rule() -> Dictionary:
	if _orders.is_empty():
		return {}
	var o: Array = _orders[order_wheel.index]
	var c := _cond()
	return {"action": o[0], "param": o[1], "cond": c, "cond_param": value.current() if COND_VALUES.has(c) else "",
		"negate": negate and c != "" and plates.has("not")}


func _show() -> void:
	var r := rule()
	if r.is_empty():
		return
	queue_redraw()


func _knob_pos() -> Vector2:
	var s := Desk.v("print_slot")
	var top := Vector2(float(s[0]) + float(s[2]) * 0.5, float(s[1]) + 14.0) - position
	return top + Vector2(0, (float(s[3]) - 28.0) * _lever)


func _local(key: String) -> Rect2:
	var r := Desk.r(key)
	return Rect2(r.position - position, r.size)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.position.distance_to(_knob_pos()) < 28.0:
				_lever_drag = true
				_lever_grab = event.position.y - _knob_pos().y
				_pulled = false
				accept_event()
			elif _local("not_switch").has_point(event.position):
				_flip_not()
				accept_event()
		elif _lever_drag:
			_lever_drag = false
			if _lever < 0.15 and not _pulled:
				var tw := create_tween()
				tw.tween_property(self, "_lever", 1.0, 0.18).set_ease(Tween.EASE_IN)
				tw.tween_callback(_pull)
	elif event is InputEventMouseMotion and _lever_drag:
		var s := Desk.v("print_slot")
		var travel := float(s[3]) - 28.0
		var top := float(s[1]) + 14.0 - position.y
		_lever = clampf((event.position.y - _lever_grab - top) / travel, 0.0, 1.0)
		if _lever > 0.95:
			_pull()
		queue_redraw()


func _pull() -> void:
	if _pulled:
		return
	_pulled = true
	if _printing >= 0.0:
		return
	if tray_full:
		Sfx.play("switch", -4.0, 0.5)
		refused.emit("tray_full")
		return
	var r := rule()
	if r.is_empty():
		return
	_print_rule = r
	_printing = Time.get_ticks_msec() / 1000.0
	Sfx.play("punch", -2.0)
	Sfx.play("type", -10.0)


func _flip_not() -> void:
	if not plates.has("not"):
		Sfx.play("switch", -10.0, 0.6)
		refused.emit("not")
		return
	negate = not negate
	Sfx.play("switch", -6.0)
	_label_drums()
	cond_drum.select(cond_wheel.index)
	_show()


## 0..1 while the press stamps a card (for the steam and the shake), else -1.
func stamping() -> float:
	if _printing < 0.0:
		return -1.0
	return clampf((Time.get_ticks_msec() / 1000.0 - _printing) / PRINT_TIME, 0.0, 1.0)


func _process(delta: float) -> void:
	if not _lever_drag and _lever > 0.0:
		_lever = maxf(0.0, _lever - delta * 3.0)
	if _printing >= 0.0 and stamping() >= 1.0:
		_printing = -1.0
		Sfx.play("punch", -6.0, 1.3)
		printed.emit(_print_rule)
	queue_redraw()


func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# The board flashes as the press stamps.
	var st := stamping()
	if st >= 0.0:
		var fr := _local("drum_window")
		draw_rect(fr.grow(3), Color(Desk.AMBER, 0.25 * (1.0 - st)), false, 3.0)
	# NOT switch.
	var ns := _local("not_switch")
	var has_not := plates.has("not")
	Desk.draw_sprite(self, "toggle_down" if negate else "toggle_up", ns.get_center() + Vector2(0, -6), 0.0,
		Color.WHITE if has_not else Color(0.5, 0.5, 0.5))
	Desk.centred(self, Rect2(ns.position + Vector2(0, ns.size.y - 16), Vector2(ns.size.x, 12)), "NOT", Desk.font("plate"), 12,
		Color(Desk.STENCIL, 0.8 if has_not else 0.3))
	if negate and has_not:
		Desk.draw_glow(self, ns.position + Vector2(ns.size.x * 0.5, 8), 10.0, Color(Desk.AMBER, 0.7))
	# New type plates glint on their wheel.
	for f: String in _fresh:
		if now - float(_fresh[f]) < 40.0:
			var g := 0.5 + 0.5 * sin(now * 4.0)
			var on_cond := CONDS.has(f) or f == "not"
			var key := "cond_wheel" if on_cond else "order_wheel"
			var v := Desk.v(key)
			Desk.draw_glow(self, Vector2(float(v[0]), float(v[1])) - position, float(v[2]) + 18.0, Color(Desk.AMBER, 0.12 * g))
	# Labels.
	for k in ["order_wheel", "cond_wheel", "print", "tray"]:
		var pr := Desk.plaque_rect(k)
		Desk.engraved(self, Rect2(pr.position - position, pr.size), Desk.plaque(k)[4], 12)
	# The PRINT lever's knob.
	Desk.draw_sprite(self, "punch_knob", _knob_pos() + Vector2(0, 4))


## A selector wheel: drag it round by the grip (one notch every NOTCH of turn), or tap
## left or right of the hub to click one notch. Its index wraps round.
class Wheel:
	extends Control
	signal turned(index: int)
	const NOTCH := PI / 6.0
	var sprite := ""
	var radius := 60.0
	var count := 1
	var index := 0
	var _angle := 0.0            # shown angle
	var _drag := false
	var _moved := false
	var _last := 0.0
	var _press := Vector2.ZERO
	var _spin := 0.0             # accumulated drag rotation since the last notch

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _c() -> Vector2:
		return size * 0.5

	func _has_point(p: Vector2) -> bool:
		return p.distance_to(_c()) <= radius + 8.0

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag = true
				_moved = false
				_press = event.position
				_last = (event.position - _c()).angle()
				_spin = 0.0
				accept_event()
			elif _drag:
				_drag = false
				if not _moved:
					_step(1 if event.position.x >= _c().x else -1)
		elif event is InputEventMouseMotion and _drag:
			if event.position.distance_to(_press) > 6.0:
				_moved = true
			if event.position.distance_to(_c()) < 10.0:
				return
			var a: float = (event.position - _c()).angle()
			var da := wrapf(a - _last, -PI, PI)
			_last = a
			_angle += da
			_spin += da
			while _spin >= NOTCH:
				_spin -= NOTCH
				_step(1, false)
			while _spin <= -NOTCH:
				_spin += NOTCH
				_step(-1, false)

	## Turned from elsewhere (its drum was rolled by hand): go to that notch, quietly.
	func turn_to(i: int) -> void:
		if count <= 0 or i == index:
			return
		var d := i - index
		index = posmod(i, count)
		_angle += d * NOTCH

	func _step(d: int, animate := true) -> void:
		if count <= 0:
			return
		index = posmod(index + d, count)
		if animate:
			_angle += d * NOTCH
		Sfx.play("drum", -8.0, 0.9 + randf() * 0.15)
		turned.emit(index)

	func _process(delta: float) -> void:
		if not _drag:
			# Settle onto the nearest notch.
			var target := roundf(_angle / NOTCH) * NOTCH
			_angle = lerpf(_angle, target, minf(1.0, delta * 12.0))
		queue_redraw()

	func _draw() -> void:
		Desk.draw_sprite(self, sprite, _c(), _angle)
