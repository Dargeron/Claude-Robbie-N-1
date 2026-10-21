class_name RoomGoals
extends VBoxContainer
## The room's goals, always in view under LAUNCH (Albert's notes #4 and #5):
##   1. Reach the exit.
##   2. Prove it wasn't luck: the survey fleet, with its big button and its strip of squares.
##   3. Lean: certify with as little CPU as the cheapest program the station knows.
## Each goal has a mark that fills in green when it's done. When the program on the
## editor has just reached the exit, the survey button glows and pulses.

var survey_btn: Button
var strip: SurveyStrip
var marks: Array[GoalMark] = []
var labels: Array[RichTextLabel] = []
var ready_to_survey := false
var _t := 0.0


func _init(button: Button) -> void:
	add_theme_constant_override("separation", 3)
	survey_btn = button
	survey_btn.custom_minimum_size = Vector2(236, 34)
	survey_btn.add_theme_font_size_override("font_size", 14)
	for i in 3:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var m := GoalMark.new()
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(m)
		marks.append(m)
		var l := RichTextLabel.new()
		l.bbcode_enabled = true
		l.fit_content = true
		l.scroll_active = false
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(120, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.add_theme_font_size_override("normal_font_size", 13)
		l.add_theme_font_size_override("bold_font_size", 13)
		row.add_child(l)
		labels.append(l)
		if i == 1:
			row.add_child(survey_btn)
		add_child(row)
		if i == 1:
			strip = SurveyStrip.new()
			add_child(strip)


## made_it: some Robbie reached the exit here. this_made_it: the program in the editor did.
func update(rs: GameState.RoomState, made_it: bool, this_made_it: bool, record: int, needed: int, fleet: int) -> void:
	var dim := "#8b8f94"
	marks[0].done = made_it
	labels[0].text = "Reach the exit" if made_it else "Reach the exit  [color=%s]the green tick points the way[/color]" % dim
	marks[1].done = rs.certified
	if rs.certified:
		labels[1].text = "Prove it wasn't luck  [color=#7dffa0]%d of %d made it[/color]" % [rs.survey.get("passed", 0), rs.survey.get("fleet", fleet)]
	else:
		labels[1].text = "Prove it wasn't luck  [color=%s]%d of %d must get through[/color]" % [dim, needed, fleet]
	var lean := rs.certified and record > 0 and rs.best_cpu > 0 and rs.best_cpu <= record
	marks[2].done = lean
	if record <= 0:
		labels[2].text = "Lean  [color=%s]certify, then try again with less CPU[/color]" % dim
	elif rs.best_cpu > 0:
		labels[2].text = "Lean  [color=%s]certify with %d CPU or less (yours: %d)[/color]" % [dim, record, rs.best_cpu]
	else:
		labels[2].text = "Lean  [color=%s]certify with %d CPU or less[/color]" % [dim, record]
	for m in marks:
		m.queue_redraw()
	ready_to_survey = this_made_it and not survey_btn.disabled and not rs.certified
	survey_btn.add_theme_color_override("font_color", UiTheme.AMBER if ready_to_survey else UiTheme.TEXT)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if ready_to_survey:
		queue_redraw()


func _draw() -> void:
	if not ready_to_survey:
		return
	# A glow behind the survey button: it's the thing to press now.
	var r := survey_btn.get_global_rect()
	r.position -= get_global_rect().position
	var a := 0.45 + 0.4 * sin(_t * 4.0)
	draw_rect(r.grow(2.0), Color(UiTheme.AMBER, a), false, 2.0)
	draw_rect(r.grow(5.0), Color(UiTheme.AMBER, a * 0.3), false, 1.0)


## A goal's mark: an empty ring, or a green disc with a tick once it's done.
class GoalMark:
	extends Control
	var done := false

	func _init() -> void:
		custom_minimum_size = Vector2(16, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		if done:
			draw_circle(c, 7.0, UiTheme.GREEN)
			draw_polyline(PackedVector2Array([c + Vector2(-3.5, 0.2), c + Vector2(-1.0, 2.8), c + Vector2(3.8, -2.6)]),
				Color(0.05, 0.12, 0.07), 2.0)
		else:
			draw_arc(c, 6.5, 0, TAU, 20, UiTheme.TEXT_DIM, 1.5)
