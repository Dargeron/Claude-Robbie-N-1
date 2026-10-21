class_name RobbieManual
extends Control
## Robbie's manual: how Robbie reads its rules, and every order and condition with
## its CPU cost, in the same words as the editor's tooltips (Catalogue.HELP).

signal closed


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Label.new()
	title.text = "ROBBIE'S MANUAL"
	title.position = Vector2(140, 16)
	title.add_theme_color_override("font_color", UiTheme.AMBER)
	title.add_theme_font_size_override("font_size", 20)
	add_child(title)
	var close := IconButton.make("close", "Back to the station (H or Esc)", func() -> void: closed.emit())
	close.position = Vector2(1222, 14)
	close.custom_minimum_size = Vector2(34, 32)
	add_child(close)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(140, 56)
	scroll.size = Vector2(1000, 650)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size = Vector2(980, 0)
	text.add_theme_font_size_override("normal_font_size", 14)
	text.add_theme_font_size_override("bold_font_size", 14)
	text.text = RobbieManual.body()
	scroll.add_child(text)


static func body() -> String:
	var amber := "#ffc35a"
	var cyan := "#7fd8ff"
	var dim := "#8b8f94"
	var out := ""
	out += "[color=%s][b]HOW ROBBIE THINKS[/b][/color]\n" % amber
	out += "Several times a second, Robbie reads its rules from the top and follows the [b]first one that applies[/b]: its condition holds and its order can be carried out right now. "
	out += "Settings (the lamp) are applied and Robbie keeps reading. A shot is finished before Robbie reads again. "
	out += "If no rule applies, Robbie drifts: it holds still until something changes.\n"
	out += "Every rule costs CPU, and each room has a CPU budget. A program that doesn't fit can't be launched.\n\n"
	out += "[color=%s][b]WHAT THE TRANSMISSION SHOWS[/b][/color]\n" % amber
	out += "Only what Robbie sensed: rock its lamp lit, creatures in its light or glowing close by, anything near enough to feel. "
	out += "When Robbie loses track of a creature, a ring fades where it was last sensed. Rock, plants and the exit stay on the station's chart once found, "
	out += "and later Robbies see them faintly. The green tick beside Robbie points at the beacon: Robbie always knows which way the exit is, never how far.\n\n"
	out += "[color=%s][b]ORDERS[/b][/color]\n" % amber
	for a in ProgramEditor.ACTION_ORDER:
		var def: Dictionary = Catalogue.ACTIONS[a]
		var cost := "%d CPU" % Catalogue.action_cpu(a, "")
		if def.has("cpu_by_param"):
			var by: Dictionary = def["cpu_by_param"]
			for p in by:
				cost += " (%s: %d)" % [str(p).replace("_", " "), int(by[p])]
		out += "[b]%s[/b]  [color=%s]%s[/color]\n[color=%s]%s[/color]\n\n" % [def["label"], cyan, cost, "#ddd6c6", Catalogue.HELP.get(a, "")]
	out += "[color=%s][b]CONDITIONS[/b][/color]  [color=%s]A condition adds 1 CPU for the \"if\", plus its own cost; \"not\" adds 1 more.[/color]\n" % [amber, dim]
	for c in ProgramEditor.COND_ORDER:
		var cdef: Dictionary = Catalogue.CONDITIONS[c]
		out += "[b]%s[/b]  [color=%s]+%d CPU[/color]\n%s\n\n" % [cdef["label"], cyan, Catalogue.IF_CPU + Catalogue.condition_cpu(c), Catalogue.HELP.get(c, "")]
	out += "[color=%s]Hover over any order or condition in the editor for the same explanation.[/color]" % dim
	return out


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_H]:
		closed.emit()
		get_viewport().set_input_as_handled()
