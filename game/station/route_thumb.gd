class_name RouteThumb
extends Control
## A small map of a room with one Robbie's route on it, for the Wall of Robbies.
## The route comes from the entry's saved path (GameState.encode_path); survey
## Robbies and Robbies saved before routes were kept show the room alone.

var room: Room
var path := PackedVector2Array()
var made_it := false


static func make(r: Room, entry: Dictionary, size_px: Vector2) -> RouteThumb:
	var t := RouteThumb.new()
	t.room = r
	t.path = GameState.decode_path(str(entry.get("path", "")))
	t.made_it = entry.get("result", "") == "exit"
	t.custom_minimum_size = size_px
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _draw() -> void:
	if room == null:
		return
	var s := size.x / float(room.w)   # pixels per tile
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.05, 0.075))
	for ty in room.h:
		for tx in room.w:
			var r := Rect2(tx * s, ty * s, s + 0.5, s + 0.5)
			if room.tile_at(tx, ty) == Room.Tile.ROCK:
				draw_rect(r, Color(0.17, 0.16, 0.16))
			elif room.is_exit(tx, ty):
				draw_rect(r, Color(0.12, 0.35, 0.18))
	if path.size() < 2:
		return
	var k := s / 16.0   # path points are in pixels, 16 per tile
	var pts := PackedVector2Array()
	for p in path:
		pts.append(p * k)
	var col := UiTheme.GREEN if made_it else UiTheme.AMBER
	draw_polyline(pts, Color(col, 0.9), 1.2)
	draw_circle(pts[0], 1.6, Color(1, 1, 1, 0.8))
	var end := pts[pts.size() - 1]
	if not made_it:
		draw_line(end + Vector2(-2.5, -2.5), end + Vector2(2.5, 2.5), UiTheme.RED, 1.5)
		draw_line(end + Vector2(-2.5, 2.5), end + Vector2(2.5, -2.5), UiTheme.RED, 1.5)
