class_name Catalogue
extends RefCounted
## Every order and condition Robbie understands, with CPU costs.
## Program text uses the ids; the station UI shows the labels.
##
## kind: "move"    the rule drives Robbie until the next think
##       "commit"  the rule runs to completion first (laser)
##       "instant" a setting; the VM applies it and keeps reading the list

const ACTIONS := {
	"move": {"label": "Move", "param": "heading", "cpu": 1, "kind": "move"},
	"move_towards": {"label": "Move towards", "param": ["beacon", "light", "open_water"],
		"cpu": 2, "cpu_by_param": {"open_water": 3}, "kind": "move"},
	"keep_distance": {"label": "Keep distance from hostile", "param": ["2", "4", "6"],
		"unit": "tiles", "cpu": 3, "kind": "move"},
	"follow_wall": {"label": "Follow wall", "param": ["left", "right"], "cpu": 3, "kind": "move"},
	"stop": {"label": "Stop", "cpu": 1, "kind": "move"},
	"shoot": {"label": "Shoot laser", "cpu": 3, "kind": "commit"},
	"lamp": {"label": "Lamp", "param": ["on", "off"], "cpu": 1, "kind": "instant"},
}

const CONDITIONS := {
	"hostile_near": {"label": "hostile is near", "param": ["2", "4", "6"], "unit": "tiles", "cpu": 2},
	"wall_ahead": {"label": "wall ahead", "cpu": 1},
	"valve_open": {"label": "valve is open", "cpu": 2},
	"valve_shut": {"label": "valve is shut", "cpu": 2},
	"energy_below": {"label": "energy below", "param": ["25", "50", "75"], "unit": "%", "cpu": 1},
	"executing": {"label": "executing rule", "param": "rule", "cpu": 2},
}

## Plain-language help for the editor's tooltips and Robbie's manual. Keep these true
## to the sim (ranges are in tiles; one tile is 16 px).
const HELP := {
	"move_towards": "Turn towards a target and swim. The beacon is the exit's radio signal: it points straight at the exit, through rock if need be (the green tick beside Robbie). Robbie knows which way it is, not how far. Light is the nearest glow Robbie can sense. Open water is the clearest way ahead (3 CPU). With no light in sight, \"light\" doesn't apply and Robbie reads on.",
	"move": "Turn to a fixed compass heading and swim that way.",
	"keep_distance": "If Robbie senses a hostile closer than this, back away from it while facing it. Backing away is slower than swimming forwards, and Robbie can't see behind it. With nothing that close, the rule doesn't apply and Robbie reads on.",
	"follow_wall": "Keep the rock on one side and swim along it.",
	"stop": "Hold still. Robbie uses half the energy while still.",
	"shoot": "Fire the laser at the nearest hostile Robbie senses within 6 tiles. Each shot costs energy, and Robbie stands still while it fires. Some creatures can't be hurt by it. With nothing to shoot, the rule doesn't apply and Robbie reads on.",
	"lamp": "A setting: switch the lamp on or off, then keep reading the rules. The lamp lights 6 tiles ahead and glows 3 tiles all around. Robbie starts each dive with it on.",
	"hostile_near": "Robbie senses a hostile closer than this. Robbie senses what its lamp lights, anything that glows, and anything within about a tile. Camouflaged creatures (lurkers) can't be sensed until they wake.",
	"wall_ahead": "There is rock, or a shut valve, just ahead of Robbie.",
	"valve_open": "Robbie senses the valve ahead, and it is fully open.",
	"valve_shut": "Robbie senses the valve ahead, and it is closing or shut.",
	"energy_below": "Robbie's energy is below this share of a full charge.",
	"executing": "This rule was the one driving Robbie at its last think.",
	"always": "No condition: the rule applies whenever Robbie reads it.",
	"not": "Run the rule when the condition is NOT true (1 CPU).",
}

const IF_CPU := 1
const NOT_CPU := 1


static func action_cpu(action: String, param: String) -> int:
	var def: Dictionary = ACTIONS.get(action, {})
	if def.is_empty():
		return 0
	var by: Dictionary = def.get("cpu_by_param", {})
	if by.has(param):
		return int(by[param])
	return int(def.get("cpu", 0))


static func condition_cpu(cond: String) -> int:
	var def: Dictionary = CONDITIONS.get(cond, {})
	return int(def.get("cpu", 0))


## Validate a parameter. Returns "" when fine, or an error message.
static func check_param(def: Dictionary, param: String, rule_count: int) -> String:
	if not def.has("param"):
		return "" if param == "" else "takes no parameter"
	var spec: Variant = def["param"]
	if param == "":
		return "needs a parameter"
	if typeof(spec) == TYPE_ARRAY:
		if not (spec as Array).has(param):
			return "parameter must be one of %s" % ", ".join(spec)
		return ""
	if spec == "heading":
		if not param.is_valid_int():
			return "heading must be a whole number of degrees"
		return ""
	if spec == "rule":
		if not param.is_valid_int() or int(param) < 1 or int(param) > rule_count:
			return "rule number must be between 1 and %d" % rule_count
		return ""
	return ""
