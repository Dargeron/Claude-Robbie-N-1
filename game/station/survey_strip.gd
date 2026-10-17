class_name SurveyStrip
extends Control
## One small square per survey Robbie: grey while it's still out, green if it made
## it, red if it was lost. Shows the fleet coming back one by one, then the result.

var run: Survey.Run = null
var dives: Array = []
var fleet := 0


func _init() -> void:
	custom_minimum_size = Vector2(0, 14)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # always takes its space (empty when there's no survey), so nothing jumps


func start(r: Survey.Run) -> void:
	run = r
	fleet = r.fleet
	queue_redraw()


## Show a stored survey report (or nothing).
func show_report(report: Dictionary) -> void:
	run = null
	dives = report.get("dives", [])
	fleet = int(report.get("fleet", 0))
	queue_redraw()


func _draw() -> void:
	var list: Array = run.dives if run != null else dives
	if fleet <= 0:
		return
	var w := minf(14.0, (size.x - 4.0) / fleet - 3.0)
	for i in fleet:
		var r := Rect2(2.0 + i * (w + 3.0), 1.0, w, 11.0)
		if i < list.size():
			var ok: bool = list[i]["result"] == "exit"
			draw_rect(r, UiTheme.GREEN if ok else UiTheme.RED)
		else:
			draw_rect(r, Color(0.3, 0.33, 0.38), false, 1.0)
	var needed := Survey.needed_for(fleet)
	var x := 2.0 + needed * (w + 3.0) - 2.0
	draw_line(Vector2(x, 0), Vector2(x, 13), UiTheme.AMBER, 1.0)   # the pass mark: this many must make it
