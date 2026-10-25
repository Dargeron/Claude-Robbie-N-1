class_name CardRack
extends Control
## Robbie's program as a rack of punched cards, read top to bottom. Each slot has a pilot
## lamp: amber while its card drives Robbie, dim red with the reason stamped when its
## condition failed, dark when the reader never got to it.
## Drag a card to reorder; drop it in the bin to discard it, or on the keypunch to repunch it.
## Tap a card to load it into the keypunch.

signal changed
signal card_tapped(index: int)
signal card_dropped(index: int, where: String)   # where: "bin" or "keypunch"

const SLOTS := 6
const CARD_H := 46.0
const DRAG_START := 6.0

var program: Program
var lamps: Array = []            # per card: {state: "off"|"run"|"skip"|"set", reason: String}
var drop_zone: Callable          # (global position) -> "bin" | "keypunch" | ""
var highlight_drop := ""
var bed: Rect2                   # the card bed, in this control's coordinates
var _y: Array[float] = []        # animated y of each card
var _press := -1
var _press_pos := Vector2.ZERO
var _dragging := false
var _drag_pos := Vector2.ZERO
var _grab := Vector2.ZERO
var _order: Array[int] = []      # card indices in display order while dragging
var _flash := {}                 # card index -> time it last lit up


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(p: Program) -> void:
	program = p
	var b := Desk.r("card_bed")
	bed = Rect2(b.position - position, b.size)
	_y.clear()
	for i in program.rules.size():
		_y.append(_slot_y(i))
	queue_redraw()


## The program changed elsewhere (punched, loaded): re-seat the cards. A new card at the
## end slides up from the keypunch.
func refresh(new_card := -1) -> void:
	while _y.size() < program.rules.size():
		_y.append(size.y + 60.0)
	_y.resize(program.rules.size())
	if new_card >= 0 and new_card < _y.size():
		_y[new_card] = size.y + 80.0
	queue_redraw()


func _slot_y(i: int) -> float:
	return bed.position.y + i * (bed.size.y / SLOTS) + 2.0


func card_rect(i: int) -> Rect2:
	return Rect2(bed.position.x + 2.0, _y[i] if i < _y.size() else _slot_y(i), bed.size.x - 4.0, CARD_H)


func lamp_pos(slot: int) -> Vector2:
	var l: Dictionary = Desk.layout()["lamps"]
	return Vector2(float(l["rail_x"]), float(l["first_y"]) + slot * float(l["pitch"])) - position


func _process(delta: float) -> void:
	var moving := false
	var order := _display_order()
	for slot in order.size():
		var i: int = order[slot]
		if _dragging and i == _press:
			continue
		var target := _slot_y(slot)
		if absf(_y[i] - target) > 0.5:
			_y[i] = lerpf(_y[i], target, minf(1.0, delta * 14.0))
			moving = true
		else:
			_y[i] = target
	if moving or _dragging or not lamps.is_empty():
		queue_redraw()


func _display_order() -> Array[int]:
	if _dragging and _order.size() == program.rules.size():
		return _order
	var o: Array[int] = []
	for i in program.rules.size():
		o.append(i)
	return o


func _card_at(p: Vector2) -> int:
	for i in range(program.rules.size() - 1, -1, -1):
		if card_rect(i).has_point(p):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = _card_at(event.position)
			_press_pos = event.position
			_dragging = false
			if _press >= 0:
				_grab = event.position - card_rect(_press).position
				accept_event()
		else:
			if _press >= 0:
				if _dragging:
					_finish_drag(event.global_position)
				else:
					card_tapped.emit(_press)
			_press = -1
			_dragging = false
			highlight_drop = ""
			z_index = 0
			queue_redraw()
	elif event is InputEventMouseMotion and _press >= 0:
		if not _dragging and event.position.distance_to(_press_pos) > DRAG_START:
			_dragging = true
			z_index = 20
			_order.clear()
			for i in program.rules.size():
				_order.append(i)
			Sfx.play("paper", -10.0)
		if _dragging:
			_drag_pos = event.position
			_y[_press] = event.position.y - _grab.y
			highlight_drop = drop_zone.call(event.global_position) if drop_zone.is_valid() else ""
			# Reorder live while the card is over the rack.
			if highlight_drop == "" and bed.grow(30).has_point(event.position):
				var slot := clampi(int((event.position.y - _grab.y + CARD_H * 0.5 - bed.position.y) / (bed.size.y / SLOTS)), 0, program.rules.size() - 1)
				_order.erase(_press)
				_order.insert(slot, _press)
			queue_redraw()


func _finish_drag(global_pos: Vector2) -> void:
	var where: String = drop_zone.call(global_pos) if drop_zone.is_valid() else ""
	if where != "":
		card_dropped.emit(_press, where)
		return
	# Reorder the program to the new order.
	var rules: Array[Dictionary] = []
	var ys: Array[float] = []
	for i in _order:
		rules.append(program.rules[i])
		ys.append(_y[i])
	var moved := false
	for j in _order.size():
		if _order[j] != j:
			moved = true
	program.rules = rules
	_y = ys
	if moved:
		Sfx.play("drum", -6.0, 0.8)
		changed.emit()


func flash(i: int) -> void:
	_flash[i] = Time.get_ticks_msec() / 1000.0


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if program == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	# Pilot lamps, one per slot.
	var order := _display_order()
	for slot in SLOTS:
		var lp := lamp_pos(slot)
		var st := "off"
		if slot < order.size() and not _dragging:
			var i: int = order[slot]
			if i < lamps.size():
				st = lamps[i]["state"]
		_draw_lamp(lp, st, now)
	if program.rules.is_empty():
		var f := Desk.font("hand")
		Desk.centred(self, Rect2(bed.position + Vector2(0, bed.size.y * 0.35), Vector2(bed.size.x, 40)),
			"empty rack. punch a card.", f, 22, Color(Desk.NOTE, 0.35))
	for slot in order.size():
		var i: int = order[slot]
		if _dragging and i == _press:
			continue
		_draw_card_at(i, card_rect(i), now, false)
	if _dragging and _press >= 0:
		var r := card_rect(_press)
		r.position.x = _drag_pos.x - _grab.x
		_draw_card_at(_press, r, now, true)


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


func _draw_card_at(i: int, r: Rect2, now: float, lifted: bool) -> void:
	var lamp: Dictionary = lamps[i] if i < lamps.size() else {}
	var f: float = _flash.get(i, -10.0)
	var lit := clampf(1.0 - (now - f) / 0.6, 0.0, 1.0)
	if lifted:
		draw_set_transform(r.get_center(), -0.03, Vector2(1.03, 1.03))
		r = Rect2(-r.size * 0.5, r.size)
		draw_rect(Rect2(r.position + Vector2(8, 12), r.size), Color(0, 0, 0, 0.45))
	CardArt.draw(self, r, program, program.rules[i], i, lamp, lit)
	if lifted:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
