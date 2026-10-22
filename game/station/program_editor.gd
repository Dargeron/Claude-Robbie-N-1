class_name ProgramEditor
extends VBoxContainer
## The click-built rule editor. Each rule reads as a sentence:
##   1  [Keep distance from hostile ▾] [4 tiles ▾]                3 CPU  ↑ ↓ ✕
##      if [hostile is near ▾] [not] [4 ▾]

signal changed

const ACTION_ORDER := ["move_towards", "move", "keep_distance", "follow_wall", "stop", "shoot", "lamp"]
const COND_ORDER := ["hostile_near", "wall_ahead", "wall_behind", "valve_open", "valve_shut", "energy_below", "executing"]
const HEADINGS := ["0", "45", "90", "135", "180", "225", "270", "315"]
const COMPASS := ["up", "up-right", "right", "down-right", "down", "down-left", "left", "up-left"]

var program: Program
var highlight := -1   # rule shown as "running" by the replay


func set_program(p: Program) -> void:
	program = p
	rebuild()


func rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	if program == null:
		return
	for i in program.rules.size():
		add_child(_row(i))
	if program.rules.is_empty():
		var hint := Label.new()
		hint.text = "No rules yet. Robbie would just drift.\nPress  + New rule  to give it something to do."
		hint.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
		add_child(hint)


func set_highlight(i: int) -> void:
	if i == highlight:
		return
	highlight = i
	for c in get_children():
		if c is PanelContainer:
			var idx: int = c.get_meta("rule", -1)
			var on := idx == highlight
			c.add_theme_stylebox_override("panel", _card_box(on))


## A rule card: dark plate, brass edge; green edge on the rule that's driving Robbie.
static func _card_box(on: bool) -> StyleBoxFlat:
	var b := UiTheme.box(Color("16202b") if on else Color("121820"), UiTheme.GREEN if on else UiTheme.BRASS_EDGE, 6, 6)
	b.set_border_width_all(2 if on else 1)
	return b


## Two rivets at the bottom corners of a rule card.
class CardRivets:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		for p in [Vector2(0, size.y - 1), Vector2(size.x - 1, size.y - 1)]:
			draw_circle(p, 2.4, Brass.BRASS_DARK)
			draw_circle(p + Vector2(-0.5, -0.5), 1.1, Brass.BRASS)


func add_rule() -> void:
	program.rules.append({"action": "move_towards", "param": "beacon", "cond": "", "cond_param": "", "negate": false})
	rebuild()
	changed.emit()


func _row(i: int) -> Control:
	var rule: Dictionary = program.rules[i]
	var card := PanelContainer.new()
	card.set_meta("rule", i)
	card.add_theme_stylebox_override("panel", _card_box(i == highlight))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	card.add_child(CardRivets.new())

	var top := HBoxContainer.new()
	v.add_child(top)
	var num := Label.new()   # the rule's number on a brass badge
	num.text = str(i + 1)
	num.custom_minimum_size = Vector2(24, 24)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var badge := UiTheme.box(Brass.BRASS, Brass.BRASS_DARK, 12, 0)
	badge.set_border_width_all(2)
	num.add_theme_stylebox_override("normal", badge)
	num.add_theme_color_override("font_color", Color(0.16, 0.1, 0.03))
	num.add_theme_font_size_override("font_size", 13)
	top.add_child(num)
	var act := OptionButton.new()
	for a in ACTION_ORDER:
		act.add_item(Catalogue.ACTIONS[a]["label"])
		act.set_item_tooltip(act.item_count - 1, Catalogue.HELP.get(a, ""))
	act.select(ACTION_ORDER.find(rule["action"]))
	act.tooltip_text = Catalogue.HELP.get(rule["action"], "")
	act.custom_minimum_size = Vector2(230, 0)
	act.item_selected.connect(func(idx: int) -> void: _set_action(i, ACTION_ORDER[idx]))
	top.add_child(act)
	var pw := _param_widget(Catalogue.ACTIONS[rule["action"]], str(rule["param"]), func(val: String) -> void:
		program.rules[i]["param"] = val
		_changed_light())
	if pw != null:
		top.add_child(pw)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var cpu := Label.new()
	cpu.text = "%d CPU" % program.rule_cpu(rule)
	cpu.add_theme_color_override("font_color", UiTheme.CYAN)
	top.add_child(cpu)
	for b in [["up", -1], ["down", 1]]:
		var dir: int = b[1]
		var mv := IconButton.make(b[0], "Move this rule up" if dir < 0 else "Move this rule down", func() -> void: _move_rule(i, dir))
		mv.disabled = (i == 0 and dir < 0) or (i == program.rules.size() - 1 and dir > 0)
		top.add_child(mv)
	top.add_child(IconButton.make("close", "Delete this rule", func() -> void: _delete_rule(i)))

	var bottom := HBoxContainer.new()
	v.add_child(bottom)
	var ifl := Label.new()
	ifl.text = "      if"
	ifl.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	bottom.add_child(ifl)
	var cond := OptionButton.new()
	cond.add_item("always")
	cond.set_item_tooltip(0, Catalogue.HELP["always"])
	for c in COND_ORDER:
		cond.add_item(Catalogue.CONDITIONS[c]["label"])
		cond.set_item_tooltip(cond.item_count - 1, Catalogue.HELP.get(c, ""))
	cond.select(0 if rule["cond"] == "" else COND_ORDER.find(rule["cond"]) + 1)
	cond.tooltip_text = Catalogue.HELP.get(rule["cond"] if rule["cond"] != "" else "always", "")
	cond.custom_minimum_size = Vector2(170, 0)
	cond.item_selected.connect(func(idx: int) -> void: _set_cond(i, "" if idx == 0 else COND_ORDER[idx - 1]))
	bottom.add_child(cond)
	if rule["cond"] != "":
		var neg := CheckBox.new()
		neg.text = "not"
		neg.button_pressed = rule["negate"]
		neg.tooltip_text = Catalogue.HELP["not"]
		neg.toggled.connect(func(on: bool) -> void:
			program.rules[i]["negate"] = on
			_changed_light())
		bottom.add_child(neg)
		var cdef: Dictionary = Catalogue.CONDITIONS[rule["cond"]]
		var cw := _param_widget(cdef, str(rule["cond_param"]), func(val: String) -> void:
			program.rules[i]["cond_param"] = val
			_changed_light())
		if cw != null:
			bottom.add_child(cw)
	return card


func _param_widget(def: Dictionary, current: String, on_pick: Callable) -> Control:
	if not def.has("param"):
		return null
	var spec: Variant = def["param"]
	var ob := OptionButton.new()
	var values: Array[String] = []
	if spec is Array:
		for p in spec:
			values.append(str(p))
			ob.add_item(str(p).replace("_", " ") + (" " + str(def["unit"]) if def.has("unit") and def["unit"] != "%" else ("%" if def.get("unit", "") == "%" else "")))
	elif spec == "heading":
		for h in HEADINGS.size():
			values.append(HEADINGS[h])
			ob.add_item("%s° %s" % [HEADINGS[h], COMPASS[h]])
		if not values.has(current) and current != "":
			values.append(current)
			ob.add_item("%s°" % current)
	elif spec == "rule":
		for r in program.rules.size():
			values.append(str(r + 1))
			ob.add_item("rule %d" % (r + 1))
	var at := values.find(current)
	ob.select(maxi(at, 0))
	ob.item_selected.connect(func(idx: int) -> void: on_pick.call(values[idx]))
	return ob


func _default_param(def: Dictionary) -> String:
	if not def.has("param"):
		return ""
	var spec: Variant = def["param"]
	if spec is Array:
		return str(spec[0])
	if spec == "heading":
		return "90"
	return "1"


func _set_action(i: int, action: String) -> void:
	program.rules[i]["action"] = action
	program.rules[i]["param"] = _default_param(Catalogue.ACTIONS[action])
	rebuild()
	changed.emit()


func _set_cond(i: int, cond: String) -> void:
	program.rules[i]["cond"] = cond
	program.rules[i]["negate"] = false
	program.rules[i]["cond_param"] = "" if cond == "" else _default_param(Catalogue.CONDITIONS[cond])
	rebuild()
	changed.emit()


func _move_rule(i: int, dir: int) -> void:
	var j := i + dir
	if j < 0 or j >= program.rules.size():
		return
	var tmp: Dictionary = program.rules[i]
	program.rules[i] = program.rules[j]
	program.rules[j] = tmp
	rebuild()
	changed.emit()


func _delete_rule(i: int) -> void:
	program.rules.remove_at(i)
	# Keep "executing rule n" pointing at a rule that exists.
	for r in program.rules:
		if r["cond"] == "executing" and int(r["cond_param"]) > program.rules.size():
			r["cond_param"] = str(maxi(program.rules.size(), 1))
	rebuild()
	changed.emit()


## A parameter changed: costs may change, but the layout doesn't.
func _changed_light() -> void:
	for c in get_children():
		if c is PanelContainer:
			var idx: int = c.get_meta("rule", -1)
			var cpu_label: Label = _find_cpu_label(c)
			if cpu_label != null and idx >= 0 and idx < program.rules.size():
				cpu_label.text = "%d CPU" % program.rule_cpu(program.rules[idx])
	changed.emit()


func _find_cpu_label(card: Node) -> Label:
	for n in card.find_children("*", "Label", true, false):
		if (n as Label).text.ends_with("CPU"):
			return n
	return null
