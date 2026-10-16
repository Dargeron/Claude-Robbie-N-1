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
