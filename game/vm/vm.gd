class_name Vm
extends RefCounted
## Robbie's rule interpreter. Each think it reads the program from the top and
## runs the first rule whose condition holds and whose order can be carried out.
## "instant" orders (lamp) are applied and the reading continues.
##
## Every think leaves a trace entry, which the replay's Why? panel explains:
##   {"t": tick, "rule": chosen index or -1, "checks": [[index, code, value], ...], "senses": see senses()}
## codes: "cond_false", "not_applicable", "instant", "chosen"

const HYST := 12 * 256   # "near" switches off 12 px further out than it switches on

var program: Program
var last_rule := -1
var near_mem: Dictionary = {}
var trace: Array[Dictionary] = []
var record_senses := false   # the station turns this on for dives it shows; fleets and hunts skip the cost


func _init(p: Program) -> void:
	program = p


func think(w: World) -> Dictionary:
	var checks: Array = []
	var decision := {"act": World.Act.IDLE, "heading": w.robbie.angle, "rule": -1, "target": -1}
	for i in program.rules.size():
		var rule: Dictionary = program.rules[i]
		var c := _cond(rule, i, w)
		if not c[0]:
			checks.append([i, "cond_false", c[1]])
			continue
		var a := _action(rule, i, w)
		if a["instant"]:
			checks.append([i, "instant", a["value"]])
			continue
		if not a["ok"]:
			checks.append([i, "not_applicable", a["value"]])
			continue
		decision = a["decision"]
		decision["rule"] = i
		checks.append([i, "chosen", a["value"]])
		break
	last_rule = decision["rule"]
	var entry := {"t": w.tick, "rule": decision["rule"], "checks": checks}
	if record_senses:
		entry["senses"] = senses(w)
	trace.append(entry)
	return decision


## What Robbie's sensors read at this think, for the Why? panel (pure reads, no side effects):
## [wall ahead 0/1, nearest sensed hostile distance or -1, its Body.Kind or -1,
##  valve ahead 0 = not sensed / 1 = open / 2 = shut or closing, energy %]
static func senses(w: World) -> PackedInt32Array:
	var nh := w.nearest_hostile()
	var valve := 0
	if not w.room.gate_tiles.is_empty() and w.valve_sensed():
		valve = 1 if w.gate_state == World.GateState.OPEN else 2
	var kind: int = w.bodies[nh[0]].kind if nh[0] >= 0 else -1
	return PackedInt32Array([1 if w.wall_ahead() else 0, nh[1], kind, valve, w.energy_percent()])


## Returns [holds: bool, value: int]. The value is what the sensor read
## (distance in sub-pixels, energy %, ...), for the Why? panel.
func _cond(rule: Dictionary, i: int, w: World) -> Array:
	var cond: String = rule["cond"]
	if cond == "":
		return [true, 0]
	var ok := false
	var value := 0
	match cond:
		"hostile_near":
			var nh := w.nearest_hostile()
			var reach := int(rule["cond_param"]) * Fx.TILE
			if near_mem.get(i, false):
				reach += HYST
			ok = nh[0] != -1 and nh[1] <= reach
			near_mem[i] = ok
			value = nh[1]
		"wall_ahead":
			ok = w.wall_ahead()
		"valve_open":
			ok = w.gate_open_sensed()
		"valve_shut":
			ok = w.gate_shut_sensed()
		"energy_below":
			value = w.energy_percent()
			ok = value < int(rule["cond_param"])
		"executing":
			value = last_rule + 1
			ok = last_rule == int(rule["cond_param"]) - 1
	if rule["negate"]:
		ok = not ok
	return [ok, value]


func _action(rule: Dictionary, i: int, w: World) -> Dictionary:
	var res := {"ok": false, "instant": false, "decision": {}, "value": 0}
	var param: String = rule["param"]
	match rule["action"]:
		"move":
			res["ok"] = true
			res["decision"] = _move(Fx.from_deg(int(param)))
		"move_towards":
			var h := -1
			match param:
				"beacon":
					h = w.beacon_heading()
				"light":
					h = w.light_heading()
				"open_water":
					h = w.open_water_heading()
			if h >= 0:
				res["ok"] = true
				res["decision"] = _move(h)
		"keep_distance":
			var nh := w.nearest_hostile()
			var reach := int(param) * Fx.TILE
			if last_rule == i:
				reach += HYST
			res["value"] = nh[1]
			if nh[0] != -1 and nh[1] <= reach:
				var b: Body = w.bodies[nh[0]]
				res["ok"] = true
				var away := Fx.angle_of(w.robbie.x - b.x, w.robbie.y - b.y)
				res["decision"] = {"act": World.Act.MOVE, "heading": away, "face": Fx.norm(away + Fx.HALF_TURN), "target": -1}
		"follow_wall":
			res["ok"] = true
			res["decision"] = _move(w.follow_wall_heading(-1 if param == "left" else 1))
		"stop":
			res["ok"] = true
			res["decision"] = {"act": World.Act.STOP, "heading": w.robbie.angle, "target": -1}
		"shoot":
			var t := w.shoot_target()
			if t >= 0:
				res["ok"] = true
				res["value"] = t
				res["decision"] = {"act": World.Act.SHOOT, "heading": w.robbie.angle, "target": t}
		"lamp":
			w.lamp_on = param == "on"
			res["instant"] = true
			res["value"] = 1 if w.lamp_on else 0
	return res


func _move(h: int) -> Dictionary:
	return {"act": World.Act.MOVE, "heading": h, "target": -1}
