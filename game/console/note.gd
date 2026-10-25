class_name OpNote
extends Control
## One of Op. 5's notes: written in grease pencil straight onto the console, the way radar
## operators wrote on their scopes. It writes itself in, letter by letter, next to what it is
## about, loops the thing he means and draws an arrow to it; when its job is done it gets
## wiped off with a thumb, leaving a smear for a moment. It never takes a touch: the machine
## underneath stays usable.

const SIZE := 17
const LINE := 19.0
const WRITE_SPEED := 46.0          # letters a second
const WAX := Color(0.93, 0.89, 0.76)
const WIPE_TIME := 0.5

var text := ""
var lines: PackedStringArray = []
var targets: Array[Vector3] = []   # what he loops and points at: console x, y and the loop's size
var tilt := 0.0
var home := Vector2.ZERO           # where the console wants it written
var _born := 0.0
var _wiped := -1.0


## `to` is a console position, a Vector3 (position and loop size), or an array of them.
static func make(t: String, at: Vector2, w: float = 190.0, to: Variant = []) -> OpNote:
	var n := OpNote.new()
	n.text = t
	n.lines = wrap_lines(t, w)
	n.size = Vector2(w, n.lines.size() * LINE + 8.0)
	n.position = at
	n.home = at
	var list: Array = to if to is Array else [to]
	for x: Variant in list:
		if x is Vector3:
			n.targets.append(x)
		elif x is Vector2 and (x as Vector2).x >= 0.0:
			n.targets.append(Vector3((x as Vector2).x, (x as Vector2).y, 24.0))
	n.tilt = deg_to_rad(float((t.length() * 37) % 5) - 2.0) * 0.5
	return n


## How tall a note of this text and width is, to stack them.
static func height_of(t: String, w: float) -> float:
	return wrap_lines(t, w).size() * LINE + 8.0


static func wrap_lines(t: String, w: float) -> PackedStringArray:
	var f := Desk.font("hand")
	var out: PackedStringArray = []
	for para in t.split("\n"):
		var line := ""
		for word in para.split(" ", false):
			var cand := word if line == "" else line + " " + word
			if line != "" and f.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x > w:
				out.append(line)
				line = word
			else:
				line = cand
		out.append(line)
	return out


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_born = Time.get_ticks_msec() / 1000.0


## Wipe it off (the name is from when they were paper).
func peel() -> void:
	if _wiped < 0.0:
		_wiped = Time.get_ticks_msec() / 1000.0
		Sfx.play("paper", -16.0, 0.6)


func _process(_delta: float) -> void:
	if _wiped < 0.0 and home != Vector2.ZERO:
		position = home
	if _wiped >= 0.0 and Time.get_ticks_msec() / 1000.0 - _wiped > 3.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var f := Desk.font("hand")
	var shown := (now - _born) * WRITE_SPEED
	var wipe := 0.0 if _wiped < 0.0 else clampf((now - _wiped) / WIPE_TIME, 0.0, 1.0)
	var smear := 0.0 if _wiped < 0.0 else clampf(1.0 - (now - _wiped - WIPE_TIME) / 2.5, 0.0, 1.0)
	var a := 1.0 - wipe
	draw_set_transform(Vector2.ZERO, tilt, Vector2.ONE)
	# Where he rubbed the grime off with his sleeve before writing: a darker, cleaner patch.
	var back := Rect2(Vector2(-10, -4), size + Vector2(20, 8))
	var reveal := clampf(shown / 12.0, 0.0, 1.0)
	draw_texture_rect(Desk.glow_texture(), back.grow(18), false, Color(0, 0, 0, 0.55 * reveal * maxf(a, smear * 0.5)))
	# The smear a wipe leaves: the wax dragged sideways, fading.
	if _wiped >= 0.0:
		for k in 3:
			var off := Vector2(10.0 + 14.0 * k, 2.0 * k) * wipe
			var sa := 0.16 * smear * (1.0 - 0.25 * k)
			for i in lines.size():
				draw_string(f, Vector2(off.x, 16.0 + i * LINE + off.y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, Color(WAX, sa))
	# The writing, letter by letter.
	var left := shown
	for i in lines.size():
		if left <= 0.0:
			break
		var ln := lines[i]
		var n := mini(ln.length(), int(left))
		left -= ln.length() + 1
		var part := ln.substr(0, n)
		var at := Vector2(0, 16.0 + i * LINE)
		draw_string_outline(f, at, part, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, 4, Color(0, 0, 0, 0.45 * a))
		draw_string(f, at + Vector2(0.6, 0.4), part, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, Color(WAX, 0.55 * a))
		draw_string(f, at, part, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, Color(WAX, 0.95 * a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Once the words are down: a loop round each thing he means, an arrow to the nearest.
	var total := 0
	for ln in lines:
		total += ln.length() + 1
	var after := (shown - total) / (WRITE_SPEED * 0.6)
	if after > 0.0 and not targets.is_empty():
		var k := clampf(after, 0.0, 1.0)
		var best := -1
		var best_d := INF
		for i in targets.size():
			var tl := Vector2(targets[i].x, targets[i].y) - global_position
			var d := Rect2(Vector2.ZERO, size).get_center().distance_to(tl)
			if d < best_d:
				best_d = d
				best = i
		for i in targets.size():
			var tl := Vector2(targets[i].x, targets[i].y) - global_position
			var r := targets[i].z
			_loop(tl, r, k, a, i)
			if i == best and not Rect2(Vector2.ZERO, size).grow(r).has_point(tl):
				_arrow(tl, r, k, a)


func _stroke(pts: PackedVector2Array, a: float, w: float = 2.2) -> void:
	if pts.size() < 2:
		return
	draw_polyline(pts, Color(0, 0, 0, 0.35 * a), w + 2.5, true)
	draw_polyline(pts, Color(WAX, 0.9 * a), w, true)


## A hand-drawn loop: not quite round, overshooting where it closes.
func _loop(c: Vector2, r: float, k: float, a: float, seed_i: int) -> void:
	var pts := PackedVector2Array()
	var n := 30
	var start := -2.2 + 0.7 * seed_i
	var sweep := TAU * 1.12 * k
	for i in n + 1:
		var t := float(i) / n
		var ang := start + sweep * t
		var rr := r * (1.0 + 0.08 * sin(ang * 2.0 + seed_i) + 0.06 * t)
		pts.append(c + Vector2(cos(ang) * rr * 1.12, sin(ang) * rr * 0.9))
	_stroke(pts, a)


func _arrow(to: Vector2, loop_r: float, k: float, a: float) -> void:
	var box := Rect2(Vector2.ZERO, size)
	# From the edge of the writing nearest the target to the edge of its loop.
	var from := Vector2(clampf(to.x, box.position.x, box.end.x), clampf(to.y, box.position.y, box.end.y))
	if box.has_point(to):
		return
	from += (to - from).normalized() * 6.0
	var end := to - (to - from).normalized() * (loop_r + 6.0)
	if from.distance_to(end) < 14.0:
		return
	var mid := (from + end) * 0.5 + (end - from).orthogonal().normalized() * minf(30.0, from.distance_to(end) * 0.15)
	var pts := PackedVector2Array()
	var steps := 18
	for i in int(steps * k) + 1:
		var t := float(i) / steps
		pts.append(from.lerp(mid, t).lerp(mid.lerp(end, t), t))
	_stroke(pts, a, 2.0)
	if k >= 1.0 and pts.size() >= 3:
		var tip := pts[pts.size() - 1]
		var d := (tip - pts[pts.size() - 3]).normalized()
		_stroke(PackedVector2Array([tip - d.rotated(0.55) * 11.0, tip, tip - d.rotated(-0.55) * 11.0]), a, 2.0)
