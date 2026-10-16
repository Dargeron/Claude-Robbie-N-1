class_name Timeline
extends Control
## The scrub bar under the monitor: a band coloured by the rule driving Robbie,
## markers for what happened, and the playhead. Click or drag to seek.

signal seek_requested(t: float)

var dive: Dive
var playhead := 0.0


func set_dive(d: Dive) -> void:
	dive = d
	queue_redraw()


func set_playhead(t: float) -> void:
	if absf(t - playhead) > 0.01:
		playhead = t
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color("0b1016"))
	draw_rect(Rect2(0, 0, w, h), UiTheme.PANEL_EDGE, false, 1.0)
	if dive == null:
		return
	var rec := dive.rec
	var n := maxi(rec.ticks, 1)
	# Rule band.
	var px := 0
	while px < int(w):
		var k := mini(int(float(px) / w * n), n - 1)
		var r := rec.rrule[k]
		var c := Color(0.35, 0.35, 0.35) if r < 0 else PathImage.RULE_COLOURS[r % PathImage.RULE_COLOURS.size()]
		draw_rect(Rect2(px, h - 8, 2, 6), Color(c, 0.85))
		px += 2
	# Event markers.
	for e in dive.world.events:
		var x := float(e["t"]) / n * w
		match e["type"]:
			"damage":
				draw_rect(Rect2(x - 1, 2, 3, h - 12), UiTheme.RED)
			"lurker_wakes":
				draw_rect(Rect2(x - 1, 4, 2, h - 14), Color(1, 0.3, 0.8))
			"laser":
				draw_rect(Rect2(x, 4, 1, h - 14), Color.WHITE)
			"valve":
				if e["state"] == "closed":
					draw_rect(Rect2(x, 6, 1, h - 16), Color(0.95, 0.5, 0.2, 0.6))
	var end_c := UiTheme.GREEN if dive.world.result == World.Result.EXIT else UiTheme.RED
	draw_rect(Rect2(w - 3, 0, 3, h), end_c)
	var hx := playhead / n * w
	draw_rect(Rect2(hx - 1, 0, 2, h), UiTheme.AMBER)


func _gui_input(event: InputEvent) -> void:
	if dive == null:
		return
	var drag: bool = event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if drag or click:
		var t: float = clampf(event.position.x / size.x, 0.0, 1.0) * dive.rec.ticks
		seek_requested.emit(t)
		accept_event()
