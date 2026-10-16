class_name IconButton
extends Button
## A button whose symbol is drawn as shapes, so it looks the same everywhere
## (the web build has no system fonts to borrow arrows and triangles from).
## icon_name: restart, rewind, play, pause, faster, up, down, close, expand

var icon_name := "play"


static func make(icon: String, tip: String, on_press: Callable) -> IconButton:
	var b := IconButton.new()
	b.icon_name = icon
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(30, 28)
	b.pressed.connect(on_press)
	return b


func set_icon(icon: String) -> void:
	if icon != icon_name:
		icon_name = icon
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var col := UiTheme.TEXT if not disabled else Color("4d545c")
	if is_hovered() and not disabled:
		col = Color.WHITE
	var s := 5.0
	match icon_name:
		"play":
			_tri(c + Vector2(1, 0), s, 1, col)
		"pause":
			draw_rect(Rect2(c.x - 4, c.y - 5, 3, 10), col)
			draw_rect(Rect2(c.x + 1, c.y - 5, 3, 10), col)
		"rewind":
			_tri(c + Vector2(-3, 0), s, -1, col)
			_tri(c + Vector2(4, 0), s, -1, col)
		"faster":
			_tri(c + Vector2(-3, 0), s, 1, col)
			_tri(c + Vector2(4, 0), s, 1, col)
		"restart":
			draw_rect(Rect2(c.x - 6, c.y - 5, 2, 10), col)
			_tri(c + Vector2(1, 0), s, -1, col)
		"up":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 3), c + Vector2(-5, 3)]), col)
		"down":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, 5), c + Vector2(5, -3), c + Vector2(-5, -3)]), col)
		"expand":
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				var p0: Vector2 = c + corner * 6.0
				draw_line(p0, p0 - Vector2(corner.x * 4.0, 0), col, 2.0)
				draw_line(p0, p0 - Vector2(0, corner.y * 4.0), col, 2.0)
		"close":
			draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), col, 2.0)
			draw_line(c + Vector2(-4, 4), c + Vector2(4, -4), col, 2.0)


func _tri(at: Vector2, s: float, dir: int, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(s * dir, 0), at + Vector2(-s * dir, -s), at + Vector2(-s * dir, s)]), col)
