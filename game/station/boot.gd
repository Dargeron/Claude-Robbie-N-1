extends Node2D
## Placeholder main scene for P0a. The real station arrives in P0b.

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.03, 0.06))
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(24, 40), "ROBBIE N+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.8, 0.4))
	draw_string(f, Vector2(24, 70), "P0a: the simulation runs headless. Try tools/dive.sh", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.75, 0.8))
