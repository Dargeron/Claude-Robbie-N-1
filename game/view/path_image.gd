class_name PathImage
extends RefCounted
## Draws a dive as a still image: the map, what Robbie explored, its path
## coloured by the rule that drove it, hits, laser shots and where it ended.
## Used by the headless tools and tests; the real replay lives in view/.

const SCALE := 2
const RULE_COLOURS: Array[Color] = [
	Color(1.0, 0.75, 0.3), Color(0.35, 0.85, 1.0), Color(0.6, 1.0, 0.45), Color(1.0, 0.45, 0.8),
	Color(0.75, 0.6, 1.0), Color(1.0, 1.0, 0.5), Color(0.4, 1.0, 0.85), Color(1.0, 0.55, 0.45),
]


static func render(dive: Dive) -> Image:
	var room := dive.room
	var w := dive.world
	var rec := dive.rec
	var t := Fx.TILE_PX * SCALE
	var img := Image.create(room.w * t, room.h * t, false, Image.FORMAT_RGBA8)
	for ty in room.h:
		for tx in room.w:
			var c := Color(0.03, 0.05, 0.09)
			var tile := room.tile_at(tx, ty)
			var seen := w.seen[ty * room.w + tx] == 1
			if tile == Room.Tile.ROCK:
				c = Color(0.32, 0.29, 0.27) if seen else Color(0.16, 0.15, 0.15)
			elif tile == Room.Tile.GATE:
				c = Color(0.85, 0.45, 0.15)
			elif room.is_exit(tx, ty):
				c = Color(0.15, 0.45, 0.2)
			elif seen:
				c = Color(0.08, 0.14, 0.22)
			img.fill_rect(Rect2i(tx * t, ty * t, t, t), c)
	for p in room.plants:
		_dot(img, p.x * Fx.TILE + Fx.TILE / 2, p.y * Fx.TILE + Fx.TILE / 2, 3, Color(0.3, 1.0, 0.7))
	# Creature tracks, faint.
	for i in rec.bx.size():
		var kind := w.bodies[i].kind
		var col := Color(0.5, 0.8, 1.0, 0.5) if kind == Body.Kind.JELLYFISH else Color(0.9, 0.3, 0.9, 0.6)
		for k in range(0, rec.ticks, 3):
			if rec.bstate[i][k] & 1:
				_dot(img, rec.bx[i][k], rec.by[i][k], 1, col)
		_dot(img, rec.bx[i][0], rec.by[i][0], 3, col.lightened(0.3))
	# Robbie's path, coloured by rule.
	for k in rec.ticks:
		var r := rec.rrule[k]
		var col := Color(0.6, 0.6, 0.6) if r < 0 else RULE_COLOURS[r % RULE_COLOURS.size()]
		_dot(img, rec.rx[k], rec.ry[k], 1, col)
	for e in w.events:
		var k: int = mini(e["t"], rec.ticks - 1)
		match e["type"]:
			"damage":
				_dot(img, rec.rx[k], rec.ry[k], 4, Color(1, 0.15, 0.15))
			"laser":
				var b: int = e["target"]
				_line(img, rec.rx[k], rec.ry[k], rec.bx[b][k], rec.by[b][k], Color(1, 0.3, 0.3))
	var last := rec.ticks - 1
	var end_col := Color(0.3, 1, 0.4) if w.result == World.Result.EXIT else Color(1, 0.2, 0.2)
	_cross(img, rec.rx[last], rec.ry[last], 6, end_col)
	_dot(img, rec.rx[0], rec.ry[0], 3, Color(1, 1, 1))
	return img


static func _dot(img: Image, x: int, y: int, r: int, c: Color) -> void:
	var cx := x * SCALE / Fx.ONE
	var cy := y * SCALE / Fx.ONE
	img.fill_rect(Rect2i(cx - r, cy - r, r * 2 + 1, r * 2 + 1).intersection(Rect2i(Vector2i.ZERO, img.get_size())), c)


static func _cross(img: Image, x: int, y: int, r: int, c: Color) -> void:
	var cx := x * SCALE / Fx.ONE
	var cy := y * SCALE / Fx.ONE
	for d in range(-r, r + 1):
		for p in [Vector2i(cx + d, cy + d), Vector2i(cx + d, cy - d)]:
			if Rect2i(Vector2i.ZERO, img.get_size()).has_point(p):
				img.set_pixelv(p, c)


static func _line(img: Image, ax: int, ay: int, bx: int, by: int, c: Color) -> void:
	var a := Vector2i(ax * SCALE / Fx.ONE, ay * SCALE / Fx.ONE)
	var b := Vector2i(bx * SCALE / Fx.ONE, by * SCALE / Fx.ONE)
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var p := a + (b - a) * i / maxi(n, 1)
		if Rect2i(Vector2i.ZERO, img.get_size()).has_point(p):
			img.set_pixelv(p, c)
