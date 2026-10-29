class_name CardArt
extends RefCounted
## How an order card looks: cream card stock with the corner clipped, the order typed in
## capitals, its condition beneath, and the holes the press punched (a pattern from the
## card's own text). Every card is worth the same: one slot in the reader. A card the
## reader passed over is stamped in red with the reason.

const SHORT := {"move_towards": "SWIM TOWARDS", "keep_distance": "KEEP DISTANCE", "follow_wall": "FOLLOW WALL",
	"stop": "STOP", "shoot": "FIRE LASER", "lamp": "LAMP", "move": "SWIM"}
const COND_SHORT := {"hostile_near": "HOSTILE NEAR", "wall_ahead": "WALL AHEAD", "wall_behind": "WALL BEHIND",
	"valve_open": "VALVE OPEN", "valve_shut": "VALVE SHUT", "energy_below": "CHARGE BELOW", "executing": "RUNNING CARD"}
const COMPASS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]


## An order as the board and the card print it: SWIM TOWARDS BEACON, KEEP DISTANCE 4, SWIM 090° E.
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
			"beacon_seen":
				return "IN SIGHT" if neg else "NOT IN SIGHT"
			"stuck":
				return "STUCK" if neg else "MOVING"
			"hit":
				return "HURT" if neg else "NOT HURT"
			"heard":
				return "HEARD" if neg else "SILENCE"
		return "FALSE"
	match rule["action"]:
		"shoot":
			return "NO TARGET"
		"drop_flare":
			return "NO FLARES"
		"keep_distance":
			return "NOTHING NEAR"
		"move_towards":
			return "NO LIGHT" if rule["param"] == "light" else "NO WAY"
	return "CAN'T"


static func _fit(f: Font, text: String, width: float, size: int) -> int:
	var s := size
	while s > 9 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > width:
		s -= 1
	return s


## `base` is the transform the caller is drawing under (a lifted, tilted card), restored afterwards.
static func draw(ci: CanvasItem, r: Rect2, rule: Dictionary, lamp: Dictionary = {}, lit: float = 0.0, base := Transform2D.IDENTITY) -> void:
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
		var h := hash(str(rule))
		for p in pts:
			uvs.append((p - r.position + Vector2(h % 200, (h >> 8) % 200)) / 512.0)
		ci.draw_polygon(pts, PackedColorArray([Color(1, 1, 1, 0.6)]), uvs, t)
	# A faint printed grid, as on real cards.
	for gx in range(int(r.position.x) + 12, int(r.end.x) - 6, 7):
		ci.draw_line(Vector2(gx, r.position.y + 4), Vector2(gx, r.end.y - 4), Color(0.6, 0.35, 0.25, 0.07), 1.0)
	# The red band along the top: red is what the hand moves.
	ci.draw_colored_polygon(PackedVector2Array([r.position + Vector2(cut, 0), Vector2(r.end.x, r.position.y),
		Vector2(r.end.x, r.position.y + 3.5), r.position + Vector2(cut - 3.5, 3.5)]), Color(Desk.RED_INK, 0.85))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(0.35, 0.28, 0.18, 0.6), 1.0)
	var f := Desk.font("type")
	var l := lines(rule)
	var w := r.size.x - 20.0
	ci.draw_string(f, r.position + Vector2(12, 18), l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, _fit(f, l[0], w, 15), Desk.INK)
	ci.draw_string(f, r.position + Vector2(12, 32), l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, _fit(f, l[1], w, 11), Desk.INK_SOFT)
	# Holes along the bottom, punched in a pattern from the card's own words.
	var hh := hash(l[0] + l[1])
	for c in 30:
		var x := r.position.x + 12.0 + c * 7.6
		if x > r.end.x - 10.0:
			break
		if (hh >> (c % 28)) & 1 == 0:
			continue
		ci.draw_rect(Rect2(x, r.end.y - 9.0 - float((hh >> ((c + 3) % 28)) & 1) * 2.0, 3.0, 5.0), Color(0.04, 0.06, 0.05, 0.9))
	# The stamp: why the reader passed over this card.
	if lamp.get("state", "") == "skip" and str(lamp.get("reason", "")) != "":
		var txt: String = lamp["reason"]
		var sf := Desk.font("plate")
		var sw := sf.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 10.0
		var at := Vector2(r.end.x - 10.0 - sw, r.position.y + 22.0)
		ci.draw_set_transform_matrix(base * Transform2D(-0.07, at))
		ci.draw_rect(Rect2(0, 0, sw, 17), Color(Desk.RED_INK, 0.8), false, 1.5)
		ci.draw_string(sf, Vector2(5, 14), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(Desk.RED_INK, 0.9))
		ci.draw_set_transform_matrix(base)
