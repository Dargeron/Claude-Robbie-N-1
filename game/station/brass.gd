class_name Brass
extends Control
## Mission Control's fittings (Albert's #7: less "browser game"): a backdrop of riveted
## hull plates behind everything, and brass rivets on the corners of the main panels.
## Drawing only; it never takes the mouse.

const BRASS := Color(0.86, 0.63, 0.28)
const BRASS_DARK := Color(0.52, 0.35, 0.14)

var panels: Array[Rect2] = []   # rivet these rectangles' corners
var backdrop := false


static func make_backdrop() -> Brass:
	var b := Brass.new()
	b.backdrop = true
	return b


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if backdrop:
		_draw_backdrop()
		return
	for r in panels:
		for p in [r.position + Vector2(5, 5), Vector2(r.end.x - 5, r.position.y + 5),
				Vector2(r.position.x + 5, r.end.y - 5), r.end - Vector2(5, 5)]:
			draw_circle(p, 2.6, BRASS_DARK)
			draw_circle(p + Vector2(-0.6, -0.6), 1.2, BRASS)


## Dark hull plates with seams and rivet lines, and a faint warm glow from the middle,
## like the inside of a station rather than a web page.
func _draw_backdrop() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)
	for i in 10:
		draw_circle(Vector2(640, 380), 700.0 - i * 60.0, Color(1.0, 0.7, 0.35, 0.006 + i * 0.0015))
	var seam := Color(0.12, 0.15, 0.19)
	var rivet := Color(0.16, 0.19, 0.24)
	for y in range(0, 720, 180):
		draw_line(Vector2(0, y), Vector2(1280, y), seam, 2.0)
		for x in range(12, 1280, 40):
			draw_circle(Vector2(x, y + 7), 1.6, rivet)
	for x in range(0, 1280, 320):
		draw_line(Vector2(x, 0), Vector2(x, 720), seam, 2.0)
