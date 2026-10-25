class_name CardArt
extends RefCounted
## How an order card looks: cream card stock with the corner clipped, the slot number, the
## order typed in capitals, its condition beneath, the holes the keypunch made (one column
## per unit of CPU) and the cost in a red circle. A failed check is stamped in red.


const SHORT := {"move_towards": "SWIM TOWARDS", "keep_distance": "KEEP DISTANCE", "follow_wall": "FOLLOW WALL",
	"stop": "STOP", "shoot": "FIRE LASER", "lamp": "LAMP", "move": "SWIM"}
const COND_SHORT := {"hostile_near": "HOSTILE NEAR", "wall_ahead": "WALL AHEAD", "wall_behind": "WALL BEHIND",
	"valve_open": "VALVE OPEN", "valve_shut": "VALVE SHUT", "energy_below": "CHARGE BELOW", "executing": "RUNNING CARD"}
const COMPASS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]


## An order as the drum and the card print it: SWIM TOWARDS BEACON, KEEP DISTANCE 4, SWIM 090° E.
static func order_label(action: String, param: String) -> String:
	var s: String = SHORT.get(action, action.to_upper())
	if action == "move":
		var deg := int(param)
		return "SWIM %03d° %s" % [deg, COMPASS[posmod(roundi(deg / 45.0), 8)]]
	if param != "":
		s += " " + param.replace("_", " ").to_upper()
	return s


static func cond_label(cond: String, param: String, negate: bool) -> String:
	if cond == "":
		return "ALWAYS"
	var s := "IF " + ("NOT " if negate else "") + str(COND_SHORT.get(cond, cond.to_upper()))
	if param != "":
		s += " " + param + ("%" if cond == "energy_below" else "")
	return s


static func lines(rule: Dictionary) -> Array[String]:
	return [order_label(rule["action"], rule["param"]), cond_label(rule["cond"], rule["cond_param"], rule["negate"])]


## Why a card was passed over, in the words of a rubber stamp.
static func reason(rule: Dictionary, code: String) -> String:
	if code == "cond_false":
		var neg: bool = rule["negate"]
		match rule["cond"]:
			"hostile_near":
				return "CONTACT" if neg else "NO CONTACT"
			"wall_ahead", "wall_behind":
				return "WALL" if neg else "NO WALL"
			"energy_below":
				return "LOW CHARGE" if neg else "CHARGE OK"
			"valve_open":
				return "VALVE OPEN" if neg else "NOT OPEN"
			"valve_shut":
				return "VALVE SHUT" if neg else "NOT SHUT"
			"executing":
				return "RUNNING" if neg else "NOT RUNNING"
		return "FALSE"
	match rule["action"]:
		"shoot":
			return "NO TARGET"
		"keep_distance":
			return "NOTHING NEAR"
		"move_towards":
			return "NO LIGHT" if rule["param"] == "light" else "NO WAY"
	return "CAN'T"


static func draw(ci: CanvasItem, r: Rect2, program: Program, rule: Dictionary, index: int, lamp: Dictionary, lit: float = 0.0) -> void:
	var cut := 9.0
	var shadow := PackedVector2Array([r.position + Vector2(cut + 2, 3), r.position + Vector2(r.size.x + 2, 3),
		r.end + Vector2(2, 3), Vector2(r.position.x + 2, r.end.y + 3), r.position + Vector2(2, cut + 3)])
	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
	var pts := PackedVector2Array([r.position + Vector2(cut, 0), Vector2(r.end.x, r.position.y), r.end,
		Vector2(r.position.x, r.end.y), r.position + Vector2(0, cut)])
	var running: bool = lamp.get("state", "") == "run"
	var stock := Desk.CARD.lerp(Color(1.0, 0.92, 0.7), 0.25 if running else 0.0).lerp(Color(1, 0.85, 0.5), lit * 0.4)
	ci.draw_colored_polygon(pts, stock)
	var t := Desk.tex("paper")
	if t != null:
		var uvs := PackedVector2Array()
		for p in pts:
			uvs.append((p - r.position + Vector2(index * 37 % 200, index * 61 % 200)) / 512.0)
		ci.draw_polygon(pts, PackedColorArray([Color(1, 1, 1, 0.6)]), uvs, t)
	# A faint printed grid, as on real cards.
	for gx in range(int(r.position.x) + 40, int(r.end.x) - 34, 7):
		ci.draw_line(Vector2(gx, r.position.y + 4), Vector2(gx, r.end.y - 4), Color(0.6, 0.35, 0.25, 0.07), 1.0)
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(0.35, 0.28, 0.18, 0.6), 1.0)
	# Slot number.
	var num := Desk.font("plate")
	ci.draw_string(num, r.position + Vector2(10, 33), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Desk.INK)
	# The order and its condition.
	var f := Desk.font("type")
	var l := lines(rule)
	ci.draw_string(f, r.position + Vector2(38, 18), l[0], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 80, 15, Desk.INK)
	ci.draw_string(f, r.position + Vector2(38, 32), l[1], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 80, 11, Desk.INK_SOFT)
	# Holes: one column per unit of CPU, a pattern from the rule's own text.
	var cpu := program.rule_cpu(rule)
	var h := 0
	for ch in program.rule_text(rule):
		h = (h * 31 + ch.unicode_at(0)) & 0xffffff
	for c in cpu * 3:
		var x := r.position.x + 40.0 + c * 7.0
		if x > r.end.x - 40.0:
			break
		var y := r.end.y - 9.0 - float((h >> (c % 22)) & 1) * 2.0
		ci.draw_rect(Rect2(x, y, 3.0, 5.0), Color(0.04, 0.06, 0.05, 0.9))
	# Cost, circled in red.
	var cc := Vector2(r.end.x - 20.0, r.position.y + r.size.y * 0.5)
	ci.draw_arc(cc, 11.0, 0, TAU, 24, Color(Desk.RED_INK, 0.85), 1.6)
	Desk.centred(ci, Rect2(cc - Vector2(11, 11), Vector2(22, 22)), str(cpu), num, 16, Desk.RED_INK)
	# The stamp: why the reader passed over this card.
	if lamp.get("state", "") == "skip" and str(lamp.get("reason", "")) != "":
		var txt: String = lamp["reason"]
		var sf := Desk.font("plate")
		var w := sf.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 10.0
		var at := Vector2(r.end.x - 42.0 - w, r.position.y + 23.0)
		ci.draw_set_transform(at, -0.07, Vector2.ONE)
		ci.draw_rect(Rect2(0, 0, w, 17), Color(Desk.RED_INK, 0.8), false, 1.5)
		ci.draw_string(sf, Vector2(5, 14), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(Desk.RED_INK, 0.9))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
