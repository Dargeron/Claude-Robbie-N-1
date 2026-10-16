class_name Program
extends RefCounted
## A Robbie program: an ordered list of rules. Each rule is
##   { action, param, cond, cond_param, negate }
## Text form, one rule per line ('#' starts a comment):
##   keep_distance 2
##   lamp off
##   move_towards beacon if valve_open        (ids, see Catalogue)
##   stop if wall_ahead
##   move 90 if not hostile_near 4

var rules: Array[Dictionary] = []
var errors: Array[String] = []
var name := ""


static func parse(text: String) -> Program:
	var p := Program.new()
	var lines := text.split("\n")
	var raw: Array[PackedStringArray] = []
	var line_numbers: Array[int] = []
	for n in lines.size():
		var line := lines[n]
		var hash_at := line.find("#")
		if hash_at >= 0:
			line = line.substr(0, hash_at)
		var toks := line.strip_edges().split(" ", false)
		if toks.is_empty():
			continue
		raw.append(toks)
		line_numbers.append(n + 1)
	for i in raw.size():
		var rule := _parse_rule(raw[i], raw.size())
		if rule.has("error"):
			p.errors.append("line %d: %s" % [line_numbers[i], rule["error"]])
		else:
			p.rules.append(rule)
	return p


static func _parse_rule(toks: PackedStringArray, rule_count: int) -> Dictionary:
	var action := toks[0]
	if not Catalogue.ACTIONS.has(action):
		return {"error": "unknown order '%s'" % action}
	var def: Dictionary = Catalogue.ACTIONS[action]
	var i := 1
	var param := ""
	if def.has("param") and i < toks.size() and toks[i] != "if":
		param = toks[i]
		i += 1
	var err := Catalogue.check_param(def, param, rule_count)
	if err != "":
		return {"error": "%s: %s" % [action, err]}
	var rule := {"action": action, "param": param, "cond": "", "cond_param": "", "negate": false}
	if i < toks.size():
		if toks[i] != "if":
			return {"error": "expected 'if' after '%s', found '%s'" % [action, toks[i]]}
		i += 1
		if i < toks.size() and toks[i] == "not":
			rule["negate"] = true
			i += 1
		if i >= toks.size():
			return {"error": "'if' needs a condition"}
		var cond := toks[i]
		if not Catalogue.CONDITIONS.has(cond):
			return {"error": "unknown condition '%s'" % cond}
		i += 1
		var cdef: Dictionary = Catalogue.CONDITIONS[cond]
		var cparam := ""
		if cdef.has("param") and i < toks.size():
			cparam = toks[i]
			i += 1
		var cerr := Catalogue.check_param(cdef, cparam, rule_count)
		if cerr != "":
			return {"error": "%s: %s" % [cond, cerr]}
		rule["cond"] = cond
		rule["cond_param"] = cparam
		if i < toks.size():
			return {"error": "unexpected '%s' at the end of the rule" % toks[i]}
	return rule


func is_valid() -> bool:
	return errors.is_empty()


func rule_cpu(rule: Dictionary) -> int:
	var c := Catalogue.action_cpu(rule["action"], rule["param"])
	if rule["cond"] != "":
		c += Catalogue.IF_CPU + Catalogue.condition_cpu(rule["cond"])
		if rule["negate"]:
			c += Catalogue.NOT_CPU
	return c


func cpu() -> int:
	var total := 0
	for r in rules:
		total += rule_cpu(r)
	return total


func rule_text(rule: Dictionary) -> String:
	var s: String = rule["action"]
	if rule["param"] != "":
		s += " " + rule["param"]
	if rule["cond"] != "":
		s += " if " + ("not " if rule["negate"] else "") + rule["cond"]
		if rule["cond_param"] != "":
			s += " " + rule["cond_param"]
	return s


func to_text() -> String:
	var out: PackedStringArray = []
	for r in rules:
		out.append(rule_text(r))
	return "\n".join(out) + "\n"


## Human-readable label, as the station shows it.
func rule_label(rule: Dictionary) -> String:
	var def: Dictionary = Catalogue.ACTIONS[rule["action"]]
	var s: String = def["label"]
	if rule["param"] != "":
		var p: String = rule["param"]
		if def.get("param") is String and def["param"] == "heading":
			s += " %s°" % p
		else:
			s += " " + p.replace("_", " ")
			if def.has("unit"):
				s += " " + str(def["unit"])
	if rule["cond"] != "":
		var cdef: Dictionary = Catalogue.CONDITIONS[rule["cond"]]
		s += " if " + ("not " if rule["negate"] else "") + str(cdef["label"])
		if rule["cond_param"] != "":
			s += " " + str(rule["cond_param"])
			if cdef.has("unit"):
				s += ("" if cdef["unit"] == "%" else " ") + str(cdef["unit"])
	return s
