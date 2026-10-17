class_name Coach
extends Control
## First-visit guidance: a pulsing outline around the one control to use next, with
## a short label. It walks a new player through the loop once (launch, scrub the
## transmission, change a rule, launch again) and then never shows again.

var target: Control
var text := ""
var _t := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func point_at(c: Control, label: String) -> void:
	target = c
	text = label
	visible = c != null
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	if target == null or not target.is_visible_in_tree():
		return
	var r := target.get_global_rect().grow(4.0)
	r.position -= get_global_rect().position
	var a := 0.45 + 0.4 * sin(_t * 4.0)
	draw_rect(r, Color(UiTheme.AMBER, a), false, 2.0)
	draw_rect(r.grow(3.0), Color(UiTheme.AMBER, a * 0.35), false, 1.0)
	if text == "":
		return
	var font := get_theme_default_font()
	var fs := 13
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18.0
	var h := 24.0
	# The label sits above the target, or below it when there is no room above.
	var x := clampf(r.position.x + r.size.x / 2.0 - w / 2.0, 6.0, size.x - w - 6.0)
	var y := r.position.y - h - 8.0
	if y < 4.0:
		y = r.end.y + 8.0
	var box := Rect2(x, y, w, h)
	draw_rect(box, Color(0.06, 0.05, 0.02, 0.95))
	draw_rect(box, Color(UiTheme.AMBER, 0.9), false, 1.0)
	draw_string(font, Vector2(x + 9.0, y + 17.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.AMBER)
