class_name SplitFlap
extends Control
## A split-flap readout, like a railway departures board: each character is a flap that
## clatters through the alphabet until it reaches the letter it should show.

const ALPHABET := " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789°%-·"
const STEP := 0.032              # seconds per flap

var lines := 2
var cells := 28
var _now: Array = []             # per line: PackedInt32Array of alphabet indices shown
var _goal: Array = []
var _next_flip: Array = []       # per line, per cell: when it flips next
var _flipped_at: Array = []      # per line, per cell: when it last flipped (for the fold)
var _sound_at := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(n_lines: int, n_cells: int) -> void:
	lines = n_lines
	cells = n_cells
	_now.clear()
	_goal.clear()
	_next_flip.clear()
	_flipped_at.clear()
	for l in lines:
		var a := PackedInt32Array()
		a.resize(cells)
		var b := PackedInt32Array()
		b.resize(cells)
		var c := PackedFloat32Array()
		c.resize(cells)
		var d := PackedFloat32Array()
		d.resize(cells)
		_now.append(a)
		_goal.append(b)
		_next_flip.append(c)
		_flipped_at.append(d)


## Show `text` on line `l` (centred); the flaps run to it, each starting a moment after the last.
func show_text(l: int, text: String) -> void:
	var t := text.to_upper()
	if t.length() > cells:
		t = t.substr(0, cells)
	var pad := (cells - t.length()) / 2
	var now := Time.get_ticks_msec() / 1000.0
	var goal: PackedInt32Array = _goal[l]
	var nf: PackedFloat32Array = _next_flip[l]
	for i in cells:
		var ch := " "
		if i >= pad and i - pad < t.length():
			ch = t[i - pad]
		var k := ALPHABET.find(ch)
		goal[i] = k if k >= 0 else 0
		nf[i] = now + i * 0.012
	_goal[l] = goal
	_next_flip[l] = nf


func busy() -> bool:
	for l in lines:
		if _now[l] != _goal[l]:
			return true
	return false


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var flipped := false
	for l in lines:
		var cur: PackedInt32Array = _now[l]
		var goal: PackedInt32Array = _goal[l]
		var nf: PackedFloat32Array = _next_flip[l]
		var fa: PackedFloat32Array = _flipped_at[l]
		for i in cells:
			if cur[i] != goal[i] and now >= nf[i]:
				cur[i] = (cur[i] + 1) % ALPHABET.length()
				nf[i] = now + STEP
				fa[i] = now
				flipped = true
		_now[l] = cur
		_next_flip[l] = nf
		_flipped_at[l] = fa
	if flipped and now - _sound_at > 0.07:
		_sound_at = now
		Sfx.play("relay", -20.0, 0.8 + randf() * 0.4)
	queue_redraw()


func _draw() -> void:
	var f := Desk.font("plate")
	var now := Time.get_ticks_msec() / 1000.0
	var cw := size.x / cells
	var lh := size.y / lines
	for l in lines:
		var cur: PackedInt32Array = _now[l]
		var fa: PackedFloat32Array = _flipped_at[l]
		for i in cells:
			var r := Rect2(i * cw + 1, l * lh + 2, cw - 2, lh - 4)
			draw_rect(r, Color(0.07, 0.065, 0.06))
			# The flap's hinge across the middle, and a little light on the upper flap.
			draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.5)), Color(1, 1, 1, 0.03))
			var ch := ALPHABET[cur[i]]
			var age := now - fa[i]
			var fold := clampf(age / STEP, 0.0, 1.0)
			if ch != " ":
				var sz := int(lh * 0.62)
				var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
				var base := r.position + Vector2((r.size.x - w) * 0.5, r.size.y * 0.5 + sz * 0.36)
				draw_string(f, base, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.93, 0.88, 0.74))
			if fold < 1.0:
				# The falling flap, mid-turn: the top half closing over the letter.
				var hh := r.size.y * 0.5 * (1.0 - fold)
				draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.5 - hh), Vector2(r.size.x, hh)), Color(0.12, 0.11, 0.1))
			draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color(0, 0, 0, 0.9), 1.0)
