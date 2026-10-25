class_name Keypunch
extends Control
## The keypunch: turn the order drum and the condition drum, set the value wheel, flip NOT,
## and pull PUNCH. The card in the bed shows what will be punched and what it will cost.
## Which entries the drums carry depends on the type plates the Company has issued.

signal punched(rule: Dictionary, replace: int)
signal plate_missing(what: String)

## Every order the drum can carry, with the type plate it needs.
const ORDERS := [
	["move_towards", "beacon", "towards_beacon"],
	["follow_wall", "left", "follow_wall"],
	["follow_wall", "right", "follow_wall"],
	["move", "0", "move"], ["move", "45", "move"], ["move", "90", "move"], ["move", "135", "move"],
	["move", "180", "move"], ["move", "225", "move"], ["move", "270", "move"], ["move", "315", "move"],
	["stop", "", "stop"],
	["lamp", "off", "lamp"], ["lamp", "on", "lamp"],
	["keep_distance", "2", "keep_distance"], ["keep_distance", "4", "keep_distance"], ["keep_distance", "6", "keep_distance"],
	["move_towards", "light", "towards_light"],
	["shoot", "", "shoot"],
	["move_towards", "open_water", "towards_open_water"],
]
const CONDS := ["", "wall_ahead", "wall_behind", "hostile_near", "energy_below", "executing", "valve_open", "valve_shut"]
const COND_VALUES := {"hostile_near": ["2", "4", "6"], "energy_below": ["25", "50", "75"], "executing": ["1", "2", "3", "4", "5", "6"]}

var plates: Array = []           # type plates fitted
var order_drum: Drum
var cond_drum: Drum
var wheel: Drum
var negate := false
var replace := -1                # the rack slot being repunched, or -1 for a new card
var rack_size := 0
var rack_full := false
var bin_hot := false             # a card is hovering over the bin
var bed_hot := false
var _orders: Array = []          # ORDERS entries currently on the drum
var _conds: Array[String] = []
var _lever := 0.0                # 0 up .. 1 fully pulled
var _lever_drag := false
var _lever_grab := 0.0
var _punched_this_pull := false
var _spit := 0.0                 # the punched card leaving the bed (animation)
var _spit_rule: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func setup() -> void:
	order_drum = _drum("order_drum", 16)
	cond_drum = _drum("cond_drum", 15)
	wheel = _drum("param_wheel", 18)
	order_drum.turned.connect(func(_i: int) -> void: queue_redraw())
	cond_drum.turned.connect(func(_i: int) -> void:
		_refresh_wheel()
		queue_redraw())
	wheel.turned.connect(func(_i: int) -> void: queue_redraw())


func _drum(key: String, fs: int) -> Drum:
	var d := Drum.new()
	var r := Desk.r(key)
	d.position = r.position - position
	d.size = r.size
	d.font_size = fs
	add_child(d)
	return d


## Fit the plates the Company has issued; `fresh` are the ones that just arrived.
func set_plates(p: Array, fresh: Array = []) -> void:
	plates = p
	var keep_o := order_drum.current()
	var keep_c := cond_drum.current()
	_orders = []
	var labels: Array[String] = []
	for o: Array in ORDERS:
		if plates.has(o[2]):
			_orders.append(o)
			labels.append(_order_label(o))
	order_drum.set_entries(labels, keep_o)
	_conds = []
	var cl: Array[String] = []
	for c: String in CONDS:
		if c == "" or plates.has(c):
			_conds.append(c)
			cl.append(_cond_label(c))
	cond_drum.set_entries(cl, keep_c)
	var now := Time.get_ticks_msec() / 1000.0
	for o: Array in ORDERS:
		if fresh.has(o[2]):
			order_drum.fresh[_order_label(o)] = now
	for c: String in CONDS:
		if fresh.has(c):
			cond_drum.fresh[_cond_label(c)] = now
	_refresh_wheel()
	queue_redraw()


static func _order_label(o: Array) -> String:
	return CardArt.order_label(o[0], o[1])


static func _cond_label(c: String) -> String:
	return CardArt.cond_label(c, "", false).trim_prefix("IF ")


func _refresh_wheel() -> void:
	var c := _cond()
	var vals: Array[String] = []
	if COND_VALUES.has(c):
		for v: String in COND_VALUES[c]:
			if c == "executing" and int(v) > maxi(rack_size + (1 if replace < 0 else 0), 1):
				continue
			vals.append(v)
	else:
		vals.append("–")
	wheel.locked = not COND_VALUES.has(c)
	var keep := wheel.current()
	wheel.set_entries(vals, keep if vals.has(keep) else (vals[mini(1, vals.size() - 1)] if c == "hostile_near" else ""))


func _cond() -> String:
	return _conds[cond_drum.index] if cond_drum.index < _conds.size() else ""


## The rule the machine is set to punch.
func rule() -> Dictionary:
	if _orders.is_empty():
		return {}
	var o: Array = _orders[order_drum.index]
	var c := _cond()
	return {"action": o[0], "param": o[1], "cond": c, "cond_param": wheel.current() if COND_VALUES.has(c) else "",
		"negate": negate and c != "" and plates.has("not")}


## Set the drums to an existing card, to repunch it.
func load_rule(r: Dictionary, slot: int) -> void:
	replace = slot
	for i in _orders.size():
		if _orders[i][0] == r["action"] and _orders[i][1] == r["param"]:
			order_drum.select(i)
	var ci := _conds.find(str(r["cond"]))
	if ci >= 0:
		cond_drum.select(ci)
	_refresh_wheel()
	var wi := wheel.entries.find(str(r["cond_param"]))
	if wi >= 0:
		wheel.select(wi)
	negate = bool(r["negate"])
	Sfx.play("drum", -6.0, 0.7)
	queue_redraw()


func new_card_mode() -> void:
	replace = -1
	_refresh_wheel()
	queue_redraw()


func _local(key: String) -> Rect2:
	var r := Desk.r(key)
	return Rect2(r.position - position, r.size)


func _knob_pos() -> Vector2:
	var s := Desk.v("punch_slot")
	var top := Vector2(float(s[0]) + float(s[2]) * 0.5, float(s[1]) + 14.0) - position
	return top + Vector2(0, (float(s[3]) - 28.0) * _lever)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.position.distance_to(_knob_pos()) < 26.0:
				_lever_drag = true
				_lever_grab = event.position.y - _knob_pos().y
				_punched_this_pull = false
				accept_event()
			elif _local("not_switch").has_point(event.position):
				_flip_not()
				accept_event()
			elif _local("punch_bed").has_point(event.position) and replace >= 0:
				new_card_mode()
				accept_event()
		elif _lever_drag:
			_lever_drag = false
			# A short tap on the knob pulls it all the way for you.
			if _lever < 0.15 and not _punched_this_pull:
				_auto_pull()
	elif event is InputEventMouseMotion and _lever_drag:
		var s := Desk.v("punch_slot")
		var travel := float(s[3]) - 28.0
		var top := float(s[1]) + 14.0 - position.y
		_lever = clampf((event.position.y - _lever_grab - top) / travel, 0.0, 1.0)
		if _lever > 0.96 and not _punched_this_pull:
			_punched_this_pull = true
			_punch()
		queue_redraw()


func _auto_pull() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_lever", 1.0, 0.16).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if not _punched_this_pull:
			_punched_this_pull = true
			_punch())


func _flip_not() -> void:
	if not plates.has("not"):
		Sfx.play("switch", -10.0, 0.6)
		plate_missing.emit("not")
		return
	negate = not negate
	Sfx.play("switch", -6.0)
	queue_redraw()


func _punch() -> void:
	var r := rule()
	if r.is_empty():
		return
	if rack_full and replace < 0:
		Sfx.play("switch", -4.0, 0.5)
		plate_missing.emit("rack_full")
		return
	Sfx.play("punch", -2.0)
	_spit_rule = r
	_spit = 1.0
	punched.emit(r, replace)
	replace = -1
	_refresh_wheel()


func _process(delta: float) -> void:
	if not _lever_drag and _lever > 0.0:
		_lever = maxf(0.0, _lever - delta * 3.2)
		queue_redraw()
	if _spit > 0.0:
		_spit = maxf(0.0, _spit - delta * 3.0)
		queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	for k in ["order", "cond", "param", "punch"]:
		Desk.engraved(self, _rel(Desk.plaque_rect(k)), Desk.plaque(k)[4], 13)
	# The card in the bed.
	var bed := _local("punch_bed")
	var r := rule()
	if not r.is_empty():
		var card := Rect2(bed.position + Vector2(24, 16), Vector2(bed.size.x - 48, 46))
		if _spit > 0.0:
			card.position.y -= (1.0 - _spit) * 0.0
		var tmp := Program.new()
		tmp.rules.append(r)
		var slot := replace if replace >= 0 else rack_size
		CardArt.draw(self, card, tmp, r, slot, {})
		if _spit > 0.0:
			draw_rect(card, Color(1, 0.9, 0.6, _spit * 0.35))
		var tag := "REPUNCH CARD %d  ·  TAP BED FOR A NEW CARD" % (replace + 1) if replace >= 0 else ("RACK FULL" if rack_full else "NEW CARD")
		draw_string(Desk.font("plate"), bed.position + Vector2(26, 12), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(1, 0.85, 0.5, 0.55) if not rack_full or replace >= 0 else Color(Desk.RED_LAMP, 0.8))
	if bed_hot:
		draw_rect(bed.grow(-2), Color(Desk.AMBER, 0.25), false, 2.0)
	# NOT switch.
	var ns := _local("not_switch")
	var has_not := plates.has("not")
	Desk.draw_sprite(self, "toggle_down" if negate else "toggle_up", ns.get_center() + Vector2(0, -4), 0.0,
		Color.WHITE if has_not else Color(0.5, 0.5, 0.5))
	Desk.centred(self, Rect2(ns.position + Vector2(0, ns.size.y - 20), Vector2(ns.size.x, 14)), "NOT", Desk.font("plate"), 13,
		Color(Desk.STENCIL, 0.8 if has_not else 0.3))
	if negate and has_not:
		Desk.draw_glow(self, ns.position + Vector2(ns.size.x * 0.5, 8), 10.0, Color(Desk.AMBER, 0.7))
	# The bin.
	var bn := _local("bin")
	Desk.centred(self, Rect2(bn.position + Vector2(0, bn.size.y - 30), Vector2(bn.size.x, 16)), "SPOILED", Desk.font("plate"), 14,
		Color(Desk.STENCIL, 0.75))
	if bin_hot:
		draw_rect(bn.grow(-3), Color(Desk.RED_LAMP, 0.35), false, 2.0)
		Desk.draw_glow(self, bn.get_center(), 50.0, Color(Desk.RED_LAMP, 0.25))
	# The PUNCH lever's knob in its slot.
	Desk.draw_sprite(self, "punch_knob", _knob_pos() + Vector2(0, 4))


func _rel(r: Rect2) -> Rect2:
	return Rect2(r.position - position, r.size)
