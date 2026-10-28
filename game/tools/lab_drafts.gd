extends Control
## Three drafts of the Lab (the hangar), for Albert to choose from (docs/design/lab-drafts.md):
##   A. The hoist: Bathy on a chain under the work lamp; parts hang on a pegboard and are dragged onto him.
##   B. The catalogue: the Company's equipment catalogue beside Bathy on a turntable, and his fitting sheet.
##   C. The socket ring: six sockets round Bathy; tap one and a drawer of parts for it slides up.
## Mock-ups only: drawn with the console's own kit, nothing works.
##   xvfb-run -a godot --path game --rendering-driver opengl3 res://tools/lab_drafts.tscn -- <bathy_dir> <out_dir>

var bathy_dir := ""
var out_dir := "/tmp/lab_drafts"
var draft := "A"
var _tex := {}
var _queue := ["A", "B", "C"]
var _wait := 6

const BG := Color(0.05, 0.065, 0.068)
const STEEL := Color(0.12, 0.15, 0.15)
const NAVY := Color(0.23, 0.31, 0.31)
const BRONZE := Color(0.43, 0.32, 0.19)
const BRONZE_DK := Color(0.21, 0.15, 0.09)
const VALVE := Color(0.61, 0.16, 0.1)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	bathy_dir = args[0] if args.size() > 0 else ""
	if args.size() > 1:
		out_dir = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	size = Vector2(1280, 720)
	for n: String in ["stock", "a", "b", "c"]:
		var img := Image.load_from_file("%s/bathy_%s.png" % [bathy_dir, n])
		if img != null:
			_tex[n] = ImageTexture.create_from_image(img)


func _process(_d: float) -> void:
	queue_redraw()
	if _wait > 0:
		_wait -= 1
		return
	if _queue.is_empty():
		get_tree().quit()
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/lab_draft_%s.png" % [out_dir, draft.to_lower()])
	print("draft ", draft)
	_queue.pop_front()
	if not _queue.is_empty():
		draft = _queue[0]
	_wait = 4


func _draw() -> void:
	_room()
	match draft:
		"A":
			_draft_a()
		"B":
			_draft_b()
		"C":
			_draft_c()
	_header()


# ---------------------------------------------------------------- shared

func _room() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), BG)
	# Riveted wall panels, each a slightly different steel.
	for gx in 9:
		for gy in 5:
			var r := Rect2(gx * 148 - 20, gy * 150 - 30, 146, 148)
			var k := float((gx * 37 + gy * 91) % 11) / 11.0
			draw_rect(r, STEEL.darkened(0.25 + 0.25 * k))
			draw_rect(r, Color(0, 0, 0, 0.5), false, 2.0)
			for c: Vector2 in [r.position + Vector2(8, 8), Vector2(r.end.x - 8, r.position.y + 8), r.end - Vector2(8, 8), Vector2(r.position.x + 8, r.end.y - 8)]:
				draw_circle(c, 2.2, Color(0.22, 0.25, 0.24))
	# Rust weeping from a few rivets.
	for i in 14:
		var x := float((i * 173) % 1260) + 10.0
		var y := float((i * 97) % 600) + 20.0
		draw_rect(Rect2(x, y, 3, 26 + (i % 4) * 10), Color(0.35, 0.16, 0.06, 0.25))
	# The floor, and the hazard stripe along its edge.
	draw_rect(Rect2(0, 606, 1280, 114), Color(0.07, 0.075, 0.07))
	for i in 40:
		var x := i * 34.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 606), Vector2(x + 17, 606), Vector2(x + 5, 616), Vector2(x - 12, 616)]), Color(0.55, 0.45, 0.12, 0.5))
	# The dark at the edges.
	for i in 20:
		draw_rect(Rect2(Vector2(i * 4, i * 4), Vector2(1280 - i * 8, 720 - i * 8)), Color(0, 0, 0, 0.04), false, 4.0)


## The work lamp over the bench: the only warm light in the hangar.
func _work_lamp(at: Vector2, reach: float) -> void:
	var top := Vector2(at.x, 36)
	draw_line(Vector2(at.x, 0), top, Color(0.1, 0.1, 0.1), 3.0)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-34, 0), top + Vector2(34, 0), top + Vector2(22, -14), top + Vector2(-22, -14)]), NAVY.darkened(0.3))
	var cone := PackedVector2Array([top + Vector2(-30, 0), top + Vector2(30, 0), Vector2(at.x + reach, 610), Vector2(at.x - reach, 610)])
	draw_colored_polygon(cone, Color(1.0, 0.8, 0.45, 0.06))
	Desk.draw_glow(self, Vector2(at.x, at.y + 60), reach * 1.2, Color(1.0, 0.75, 0.4, 0.16))
	Desk.draw_glow(self, top, 40.0, Color(1.0, 0.85, 0.55, 0.5))
	draw_colored_polygon(PackedVector2Array([Vector2(at.x - reach * 0.9, 612), Vector2(at.x + reach * 0.9, 612), Vector2(at.x + reach * 0.7, 640), Vector2(at.x - reach * 0.7, 640)]), Color(1.0, 0.8, 0.5, 0.05))


func _bathy(key: String, centre: Vector2, px: float) -> void:
	var t: Texture2D = _tex.get(key, _tex.get("stock"))
	if t == null:
		draw_circle(centre, px * 0.3, Color(0.83, 0.6, 0.27))
		return
	draw_texture_rect(t, Rect2(centre - Vector2(px, px) * 0.5, Vector2(px, px)), false)


func _header() -> void:
	var pl := Desk.font("plate")
	var plaque := Rect2(20, 14, 300, 34)
	draw_rect(plaque, BRONZE_DK)
	draw_rect(plaque.grow(-3), BRONZE)
	Desk.engraved(self, plaque, "HANGAR  ·  STATION 9", 18)
	# Draft letter, in chalk on the wall.
	draw_string(Desk.font("hand"), Vector2(338, 42), "draft %s" % draft, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.9, 0.9, 0.85, 0.55))
	# What you owe and what you have.
	for i in 2:
		var x := 900.0 + i * 186.0
		Desk.draw_odometer(self, Rect2(x, 14, 118, 32), 48000.0 if i == 0 else 7400.0, 6, 22)
		draw_string(pl, Vector2(x + 124, 26), "OWING" if i == 0 else "IN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Desk.STENCIL, 0.8))
		draw_string(pl, Vector2(x + 124, 42), "SCRIP" if i == 0 else "HAND", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Desk.STENCIL, 0.8))
	_knob(Vector2(1250, 82), "BACK TO THE DESK", true)


## A red push knob with a stencilled label (red means you can put your hand on it).
func _knob(c: Vector2, label: String, label_left := false, hot := false) -> void:
	draw_circle(c + Vector2(1, 2), 13.0, Color(0, 0, 0, 0.5))
	draw_circle(c, 13.0, VALVE.darkened(0.35))
	draw_circle(c, 10.0, VALVE.lightened(0.15) if hot else VALVE)
	draw_arc(c, 10.0, PI * 1.1, PI * 1.6, 8, Color(0.85, 0.35, 0.25, 0.5), 2.0)
	var f := Desk.font("plate")
	var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var p := c + (Vector2(-22 - w, 5) if label_left else Vector2(20, 5))
	draw_string(f, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(Desk.STENCIL, 0.9))


## Line drawings of the parts, as they'd be engraved in the catalogue or chalked on the board.
func _icon(id: String, c: Vector2, s: float, col: Color, w := 2.0) -> void:
	match id:
		"lamp", "spotlight", "red lamp", "floodlight":
			draw_arc(c + Vector2(-s * 0.2, 0), s * 0.3, PI * 0.5, PI * 1.5, 12, col, w)
			draw_line(c + Vector2(-s * 0.2, -s * 0.3), c + Vector2(s * 0.15, -s * 0.3), col, w)
			draw_line(c + Vector2(-s * 0.2, s * 0.3), c + Vector2(s * 0.15, s * 0.3), col, w)
			draw_line(c + Vector2(s * 0.15, -s * 0.35), c + Vector2(s * 0.15, s * 0.35), col, w)
			var spread := 0.15 if id == "spotlight" else (0.6 if id == "floodlight" else 0.35)
			for k in 3:
				var a := (k - 1) * spread
				draw_line(c + Vector2(s * 0.25, 0), c + Vector2(s * 0.25, 0) + Vector2.from_angle(a) * s * 0.4, col if id != "red lamp" else Color(0.85, 0.25, 0.15), w * 0.8)
		"pods", "screws", "fins", "jet":
			draw_rect(Rect2(c - Vector2(s * 0.35, s * 0.15), Vector2(s * 0.55, s * 0.3)), col, false, w)
			var blades := 4 if id == "screws" else 3
			for k in blades:
				var a := k * TAU / blades + 0.4
				draw_line(c + Vector2(s * 0.3, 0), c + Vector2(s * 0.3, 0) + Vector2(cos(a) * s * 0.08, sin(a) * s * 0.3), col, w)
			if id == "jet":
				for k in 3:
					draw_line(c + Vector2(-s * 0.4 - k * 6, -6 + k * 6), c + Vector2(-s * 0.55 - k * 6, -6 + k * 6), col, w * 0.7)
		"battery", "cell", "reserve":
			for k in (2 if id == "battery" else 1):
				var r := Rect2(c + Vector2(-s * 0.3 + k * s * 0.32, -s * 0.32), Vector2(s * 0.26, s * 0.64))
				draw_rect(r, col, false, w)
				draw_rect(Rect2(r.position + Vector2(s * 0.07, -s * 0.07), Vector2(s * 0.12, s * 0.07)), col)
		"plating", "hull":
			var pts := PackedVector2Array([c + Vector2(-s * 0.35, -s * 0.25), c + Vector2(s * 0.35, -s * 0.25), c + Vector2(s * 0.3, s * 0.3), c + Vector2(-s * 0.3, s * 0.3), c + Vector2(-s * 0.35, -s * 0.25)])
			draw_polyline(pts, col, w)
			for k in 4:
				draw_circle(c + Vector2(-s * 0.22 + k * s * 0.15, -s * 0.12), 2.2, col)
		"laser":
			draw_rect(Rect2(c - Vector2(s * 0.4, s * 0.1), Vector2(s * 0.3, s * 0.2)), col, false, w)
			draw_line(c + Vector2(-s * 0.1, 0), c + Vector2(s * 0.4, 0), col, w * 1.5)
			draw_circle(c + Vector2(s * 0.42, 0), 3.0, Color(1.0, 0.3, 0.15))
		"hydrophone":
			draw_line(c + Vector2(-s * 0.3, s * 0.3), c + Vector2(0, 0), col, w)
			draw_polyline(PackedVector2Array([c, c + Vector2(s * 0.35, -s * 0.3), c + Vector2(s * 0.1, -s * 0.38), c]), col, w)
			for k in 2:
				draw_arc(c + Vector2(s * 0.3, -s * 0.35), s * (0.15 + k * 0.1), -0.6, 0.9, 8, col, w * 0.6)
		"thermometer":
			draw_line(c + Vector2(0, -s * 0.35), c + Vector2(0, s * 0.2), col, w * 2.5)
			draw_circle(c + Vector2(0, s * 0.28), s * 0.11, Color(0.85, 0.25, 0.15))
		"grapple":
			draw_line(c + Vector2(-s * 0.4, s * 0.2), c + Vector2(s * 0.25, -s * 0.15), col, w)
			draw_line(c + Vector2(s * 0.25, -s * 0.15), c + Vector2(s * 0.12, -s * 0.3), col, w)
			draw_line(c + Vector2(s * 0.25, -s * 0.15), c + Vector2(s * 0.38, -s * 0.02), col, w)
		"flares", "buoy", "rattle":
			for k in (3 if id == "flares" else 1):
				var x := c.x - s * 0.2 + k * s * 0.2
				draw_rect(Rect2(Vector2(x - 4, c.y - s * 0.2), Vector2(8, s * 0.45)), col, false, w)
				draw_circle(Vector2(x, c.y - s * 0.25), 4.0, Color(0.85, 0.25, 0.15))
			if id == "buoy":
				draw_arc(c + Vector2(0, -s * 0.3), s * 0.2, PI * 1.2, PI * 1.8, 8, col, w * 0.7)
		"drill":
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.35, -s * 0.15), c + Vector2(s * 0.1, -s * 0.15), c + Vector2(s * 0.4, 0), c + Vector2(s * 0.1, s * 0.15), c + Vector2(-s * 0.35, s * 0.15), c + Vector2(-s * 0.35, -s * 0.15)]), col, w)
		_:
			draw_circle(c, s * 0.3, col, false, w)


# ---------------------------------------------------------------- A. The hoist

func _draft_a() -> void:
	var centre := Vector2(640, 330)
	_work_lamp(centre, 230.0)
	# The chain hoist.
	for k in 9:
		var y := 50.0 + k * 13.0
		draw_arc(Vector2(640, y), 5.0, 0, TAU, 10, Color(0.3, 0.3, 0.28), 3.0)
	draw_line(Vector2(640, 166), Vector2(640, 190), Color(0.3, 0.3, 0.28), 4.0)
	_bathy("a", centre + Vector2(0, 30), 440.0)
	# The pegboard of parts, left.
	var board := Rect2(28, 72, 340, 520)
	draw_rect(board, Color(0.3, 0.22, 0.14))
	draw_rect(board, Color(0.12, 0.08, 0.04), false, 3.0)
	for gx in 17:
		for gy in 26:
			draw_circle(board.position + Vector2(10 + gx * 20, 10 + gy * 20), 2.0, Color(0.12, 0.08, 0.05))
	Desk.engraved(self, Rect2(board.position.x, board.position.y - 2, board.size.x, 22), "PARTS", 16, Color(Desk.STENCIL, 0.8))
	var hung := [["spotlight", "SPOTLIGHT", "OWNED"], ["screws", "TWIN SCREWS", "OWNED"], ["fins", "SILENT FINS", "4,000"],
		["red lamp", "RED LAMP", "6,000"], ["jet", "JET PUMP", "6,000"], ["plating", "PLATING", "4,000"],
		["hydrophone", "HYDROPHONE", "4,000"], ["thermometer", "THERMOMETER", "6,000"], ["flares", "FLARES", "5,000"],
		["grapple", "GRAPPLE", "6,000"], ["buoy", "MARKER BUOYS", "6,000"], ["drill", "DRILL", "LOCKED"]]
	for i in hung.size():
		var gx := i % 3
		var gy := i / 3
		var c := board.position + Vector2(60 + gx * 110, 74 + gy * 120)
		var h: Array = hung[i]
		draw_line(c + Vector2(0, -44), c + Vector2(0, -30), Color(0.6, 0.6, 0.55), 2.0)
		var owned: bool = h[2] == "OWNED"
		if i == 1:
			# The twin screws are in his hand: only the empty hook and their chalk outline.
			_icon(h[0], c, 54.0, Color(0.9, 0.9, 0.85, 0.25), 1.5)
		elif owned:
			draw_circle(c, 30.0, Color(0, 0, 0, 0.35))
			_icon(h[0], c, 58.0, Color(0.85, 0.72, 0.45), 3.0)
		else:
			_icon(h[0], c, 54.0, Color(0.9, 0.9, 0.85, 0.55 if h[2] != "LOCKED" else 0.2), 1.5)
		var tag := Rect2(c + Vector2(-46, 30), Vector2(92, 34))
		Desk.draw_paper(self, tag, Desk.CARD if owned else Desk.PAPER, 13 + i, false)
		Desk.centred(self, Rect2(tag.position + Vector2(0, 2), Vector2(tag.size.x, 14)), h[1], Desk.font("type"), 10, Desk.INK)
		var price_col := Color(0.1, 0.35, 0.18) if owned else (Desk.RED_INK if h[2] != "LOCKED" else Desk.INK_SOFT)
		Desk.centred(self, Rect2(tag.position + Vector2(0, 16), Vector2(tag.size.x, 16)), h[2], Desk.font("plate"), 14, price_col)
	# The twin screws, being carried to his drive pods: the socket glows.
	var held := Vector2(842, 236)
	var pod := Vector2(760, 330)
	for k in 12:
		var a := held.lerp(pod, k / 12.0)
		draw_circle(a, 2.0, Color(Desk.AMBER, 0.6))
	Desk.draw_glow(self, pod, 60.0, Color(Desk.AMBER, 0.35))
	draw_arc(pod, 30.0, 0, TAU, 32, Color(Desk.AMBER_HOT, 0.9), 2.5)
	draw_circle(held, 34.0, Color(0, 0, 0, 0.35))
	_icon("screws", held, 64.0, Color(0.95, 0.8, 0.5), 3.5)
	_hand(held + Vector2(22, 24))
	var slip := Rect2(860, 262, 170, 54)
	Desk.draw_paper(self, slip, Desk.NOTE.lerp(Desk.PAPER, 0.5), 5, true)
	draw_string(Desk.font("hand"), slip.position + Vector2(10, 22), "drop on the DRIVE pods", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.16, 0.13, 0.25))
	draw_string(Desk.font("hand"), slip.position + Vector2(10, 44), "faster, but LOUD", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.16, 0.13, 0.25))
	# Type plates hang on a rack, right; reader slots below them.
	var rack := Rect2(1046, 110, 214, 300)
	draw_rect(rack, Color(0.09, 0.11, 0.11))
	draw_rect(rack, BRONZE_DK, false, 3.0)
	Desk.engraved(self, Rect2(rack.position.x, rack.position.y + 4, rack.size.x, 20), "TYPE PLATES", 15, Color(Desk.STENCIL, 0.85))
	var plates := [["IF BEACON IN SIGHT", "2,500"], ["FOR n SECONDS", "3,000"], ["ONCE", "2,000"], ["TURN LEFT / RIGHT", "1,500"], ["IF STUCK", "2,500"], ["IF COIN", "2,000"]]
	for i in plates.size():
		var pr := Rect2(rack.position + Vector2(12, 34 + i * 43), Vector2(rack.size.x - 24, 34))
		draw_rect(pr, NAVY.darkened(0.2))
		draw_rect(pr, Color(0, 0, 0, 0.5), false, 1.5)
		draw_string(Desk.font("plate"), pr.position + Vector2(8, 15), plates[i][0], HORIZONTAL_ALIGNMENT_LEFT, pr.size.x - 16, 13, Color(Desk.STENCIL, 0.9))
		draw_string(Desk.font("plate"), pr.position + Vector2(8, 30), plates[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.4, 0.3))
	# The requisition hatch.
	var hatch := Rect2(1046, 424, 214, 168)
	draw_rect(hatch, Color(0.1, 0.12, 0.12))
	draw_rect(hatch, BRONZE_DK, false, 3.0)
	Desk.engraved(self, Rect2(hatch.position.x, hatch.position.y + 6, hatch.size.x, 20), "REQUISITIONS", 15, Color(Desk.STENCIL, 0.85))
	draw_rect(Rect2(hatch.position + Vector2(20, 40), Vector2(174, 10)), Color(0, 0, 0, 0.9))
	var form := Rect2(hatch.position + Vector2(30, 52), Vector2(154, 70))
	Desk.draw_paper(self, form, Desk.PAPER, 9, false)
	draw_string(Desk.font("type"), form.position + Vector2(8, 18), "FORM 27-B  PART: SILENT FINS", HORIZONTAL_ALIGNMENT_LEFT, form.size.x - 12, 9, Desk.INK)
	draw_string(Desk.font("type"), form.position + Vector2(8, 34), "COST: 4,000  SIGN:", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Desk.INK)
	_knob(hatch.position + Vector2(28, 146), "SEND UP", false)
	_knob(hatch.position + Vector2(130, 146), "PAY DEBT", false)
	_gauges(Vector2(400, 652), {"CHARGE": [0.55, 0.55], "HULL": [0.5, 0.5], "SPEED": [0.45, 0.68], "NOISE": [0.3, 0.62], "LIGHT": [0.5, 0.5]})


## A gloved hand, in silhouette: someone is carrying the part.
func _hand(at: Vector2) -> void:
	var col := Color(0.18, 0.13, 0.1)
	draw_circle(at, 16.0, col)
	for k in 4:
		draw_line(at + Vector2(-10 + k * 7, -6), at + Vector2(-14 + k * 7, -26), col, 7.0)
	draw_line(at + Vector2(10, 4), at + Vector2(24, -6), col, 7.0)
	draw_line(at + Vector2(4, 14), at + Vector2(22, 46), col, 18.0)


## Round dials along the bench: what the hull will be, the needle where it is now, a red ghost where it would go.
func _gauges(left: Vector2, vals: Dictionary) -> void:
	var i := 0
	for k: String in vals:
		var c := left + Vector2(i * 120, 0)
		var v: Array = vals[k]
		draw_circle(c, 40.0, BRONZE_DK)
		draw_circle(c, 34.0, Color(0.85, 0.82, 0.72))
		draw_arc(c, 28.0, PI * 0.8, PI * 2.2, 24, Color(0.2, 0.2, 0.2, 0.6), 1.5)
		for t in 7:
			var a := PI * 0.8 + t / 6.0 * PI * 1.4
			draw_line(c + Vector2.from_angle(a) * 24.0, c + Vector2.from_angle(a) * 30.0, Desk.INK, 1.2)
		var now := PI * 0.8 + float(v[0]) * PI * 1.4
		var then := PI * 0.8 + float(v[1]) * PI * 1.4
		if absf(then - now) > 0.01:
			draw_line(c, c + Vector2.from_angle(then) * 26.0, Color(Desk.RED_INK, 0.7), 2.0)
		draw_line(c, c + Vector2.from_angle(now) * 26.0, Desk.INK, 2.5)
		draw_circle(c, 4.0, BRONZE)
		Desk.centred(self, Rect2(c.x - 50, c.y + 42, 100, 16), k, Desk.font("plate"), 14, Color(Desk.STENCIL, 0.9))
		i += 1


# ---------------------------------------------------------------- B. The catalogue

func _draft_b() -> void:
	_work_lamp(Vector2(900, 330), 200.0)
	# The turntable.
	var tc := Vector2(900, 560)
	draw_colored_polygon(_ellipse(tc, 170, 34), BRONZE_DK)
	draw_colored_polygon(_ellipse(tc + Vector2(0, -8), 164, 30), BRONZE)
	draw_arc(tc + Vector2(-110, -6), 12.0, PI * 0.9, PI * 1.6, 6, Color(1, 1, 1, 0.3), 2.0)
	_bathy("b", Vector2(900, 360), 420.0)
	draw_string(Desk.font("hand"), Vector2(800, 610), "drag to turn him round", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.85, 0.5))
	# The catalogue, open on the bench.
	var book := Rect2(26, 108, 590, 590)
	draw_rect(book.grow(8), Color(0.18, 0.08, 0.06))
	var lp := Rect2(book.position, Vector2(book.size.x * 0.5, book.size.y))
	var rp := Rect2(book.position + Vector2(book.size.x * 0.5, 0), Vector2(book.size.x * 0.5, book.size.y))
	Desk.draw_paper(self, lp, Desk.PAPER, 21, false)
	Desk.draw_paper(self, rp, Desk.PAPER, 22, false)
	draw_line(Vector2(rp.position.x, book.position.y), Vector2(rp.position.x, book.end.y), Color(0, 0, 0, 0.35), 4.0)
	# The tabs along the top: sockets, then type plates and the reader.
	var tabs := ["LAMP", "DRIVE", "HATCH", "BELLY", "TOOL", "HULL", "PLATES", "READER"]
	for i in tabs.size():
		var tr := Rect2(book.position.x + 6 + i * 73, book.position.y - 34, 69, 30)
		var on: bool = i == 3
		draw_rect(tr, Color(0.72, 0.66, 0.5) if on else Color(0.55, 0.5, 0.38))
		draw_rect(tr, Color(0.3, 0.22, 0.1, 0.5), false, 1.0)
		Desk.centred(self, tr, tabs[i], Desk.font("plate"), 15, Desk.INK if on else Desk.INK_SOFT)
	var lh := Desk.font("letterhead")
	var ty := Desk.font("type")
	Desk.centred(self, Rect2(lp.position.x, lp.position.y + 20, lp.size.x, 20), "THE COMPANY  ·  EQUIPMENT FOR SURVEY UNITS", lh, 11, Desk.INK_SOFT)
	Desk.centred(self, Rect2(lp.position.x, lp.position.y + 44, lp.size.x, 16), "SECTION 4  ·  BELLY BAND", lh, 11, Desk.INK_SOFT)
	# The engraving: a big drawing of the part.
	_icon("battery", Vector2(lp.get_center().x, lp.position.y + 220), 220.0, Desk.INK, 3.0)
	for k in 9:
		draw_line(Vector2(lp.position.x + 70 + k * 18, lp.position.y + 380), Vector2(lp.position.x + 60 + k * 18, lp.position.y + 392), Color(Desk.INK, 0.3), 1.0)
	Desk.centred(self, Rect2(lp.position.x, lp.position.y + 410, lp.size.x, 36), "BATTERY BANK", Desk.font("plate"), 34, Desk.INK)
	Desk.centred(self, Rect2(lp.position.x, lp.position.y + 452, lp.size.x, 20), "PATTERN 7  ·  TWO SPARE CELLS", ty, 13, Desk.INK_SOFT)
	Desk.centred(self, Rect2(lp.position.x, lp.position.y + 520, lp.size.x, 40), "4,000 SCRIP", Desk.font("plate"), 32, Desk.RED_INK)
	draw_string(ty, Vector2(lp.position.x + 30, lp.end.y - 24), "< page 1 of 4", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Desk.INK_SOFT)
	draw_string(ty, Vector2(rp.end.x - 110, rp.end.y - 24), "page 2 >", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Desk.INK_SOFT)
	var text := "Two spare cells slung under the unit's belly. More charge for long sectors.\n\nThe extra weight costs a little speed.\n\nFits the BELLY band. Takes the place of the standard cell."
	draw_multiline_string(ty, rp.position + Vector2(26, 50), text, HORIZONTAL_ALIGNMENT_LEFT, rp.size.x - 52, 15, -1, Desk.INK)
	# What changes, in two columns: as he is, and with this part.
	var ty0 := rp.position.y + 250.0
	draw_string(ty, Vector2(rp.position.x + 26, ty0), "", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Desk.INK)
	draw_string(Desk.font("plate"), Vector2(rp.position.x + 140, ty0), "NOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Desk.INK_SOFT)
	draw_string(Desk.font("plate"), Vector2(rp.position.x + 205, ty0), "WITH IT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Desk.INK_SOFT)
	var rows := [["CHARGE", "100%", "140%", true], ["SPEED", "1.0", "0.95", false], ["HULL", "3", "3", null], ["NEW CARD", "", "none", null]]
	for i in rows.size():
		var y := ty0 + 28 + i * 26
		var row: Array = rows[i]
		draw_string(ty, Vector2(rp.position.x + 26, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Desk.INK)
		draw_string(ty, Vector2(rp.position.x + 140, y), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Desk.INK_SOFT)
		var col := Desk.INK
		if row[3] == true:
			col = Color(0.1, 0.35, 0.18)
		elif row[3] == false:
			col = Desk.RED_INK
		draw_string(ty, Vector2(rp.position.x + 205, y), row[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
	# Requisition it (a red stamp) or fit it (if owned).
	var st := Rect2(rp.position.x + 30, rp.position.y + 430, 230, 56)
	draw_set_transform(st.get_center(), -0.06, Vector2.ONE)
	var sr := Rect2(-st.size * 0.5, st.size)
	draw_rect(sr, Color(Desk.RED_INK, 0.85), false, 3.0)
	draw_rect(sr.grow(-5), Color(Desk.RED_INK, 0.85), false, 1.2)
	Desk.centred(self, sr, "REQUISITION", Desk.font("plate"), 30, Color(Desk.RED_INK, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(ty, Vector2(rp.position.x + 34, rp.position.y + 516), "(tap to stamp: it arrives by tube)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Desk.INK_SOFT)
	# His fitting sheet, clipped to the wall: what is in each socket now.
	var sheet := Rect2(1096, 112, 168, 344)
	draw_rect(Rect2(sheet.position + Vector2(54, -10), Vector2(60, 18)), Color(0.3, 0.3, 0.28))
	Desk.draw_paper(self, sheet, Desk.CARD, 3, true)
	Desk.centred(self, Rect2(sheet.position.x, sheet.position.y + 14, sheet.size.x, 16), "FITTING SHEET", Desk.font("plate"), 16, Desk.INK)
	Desk.centred(self, Rect2(sheet.position.x, sheet.position.y + 32, sheet.size.x, 14), "UNIT  ROBBIE 012", ty, 11, Desk.INK_SOFT)
	var fit := [["LAMP", "standard"], ["DRIVE", "standard"], ["HATCH", "antenna"], ["BELLY", "standard"], ["TOOL", "laser"], ["HULL", "plating"]]
	for i in fit.size():
		var y := sheet.position.y + 70 + i * 44
		draw_string(Desk.font("plate"), Vector2(sheet.position.x + 12, y), fit[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Desk.INK)
		draw_string(ty, Vector2(sheet.position.x + 12, y + 18), fit[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Desk.INK_SOFT)
		draw_line(Vector2(sheet.position.x + 10, y + 26), Vector2(sheet.end.x - 10, y + 26), Color(Desk.INK, 0.2), 1.0)
		if fit[i][0] == "BELLY":
			var ring := PackedVector2Array()
			for k in 33:
				var a := k * TAU / 32.0
				ring.append(Vector2(sheet.position.x + 62, y + 6) + Vector2(cos(a) * 58.0, sin(a) * 20.0))
			draw_polyline(ring, Color(Desk.RED_INK, 0.6), 2.0)
	# Card reader slots, under the sheet.
	Desk.engraved(self, Rect2(1096, 470, 168, 20), "READER SLOTS", 14, Color(Desk.STENCIL, 0.85))
	for i in 6:
		var r := Rect2(1102 + (i % 3) * 54, 496 + (i / 3) * 44, 48, 36)
		draw_rect(r, NAVY if i < 2 else Color(0.08, 0.09, 0.09))
		draw_rect(r, Color(0, 0, 0, 0.6), false, 1.5)
		if i >= 2:
			draw_string(Desk.font("plate"), r.position + Vector2(5, 23), "%d,000" % (6 + i * 2), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.4, 0.3))


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for k in 40:
		var a := k * TAU / 40.0
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return p


# ---------------------------------------------------------------- C. The socket ring

func _draft_c() -> void:
	var centre := Vector2(640, 268)
	_work_lamp(centre, 210.0)
	_bathy("c", centre, 430.0)
	# The six sockets round him, each joined to its place on the hull.
	var sockets := [
		["HATCH", "hydrophone", Vector2(640, 64), Vector2(628, 128)],
		["LAMP", "lamp", Vector2(900, 250), Vector2(690, 345)],
		["HULL", "hull", Vector2(890, 120), Vector2(735, 215)],
		["TOOL", "laser", Vector2(880, 400), Vector2(760, 368)],
		["DRIVE", "screws", Vector2(380, 160), Vector2(518, 285)],
		["BELLY", "battery", Vector2(390, 370), Vector2(612, 380)],
	]
	for s: Array in sockets:
		var on: bool = s[0] == "DRIVE"
		var c: Vector2 = s[2]
		var body: Vector2 = s[3]
		draw_line(c, body, Color(Desk.AMBER_HOT, 0.8) if on else Color(Desk.STENCIL, 0.35), 2.0 if on else 1.2)
		draw_circle(body, 5.0, Desk.AMBER_HOT if on else Color(Desk.STENCIL, 0.5))
		if on:
			Desk.draw_glow(self, c, 70.0, Color(Desk.AMBER, 0.35))
		draw_circle(c, 40.0, BRONZE_DK)
		draw_circle(c, 35.0, NAVY.darkened(0.35))
		draw_arc(c, 40.0, 0, TAU, 36, VALVE if on else BRONZE, 4.0 if on else 2.5)
		_icon(s[1], c, 52.0, Color(0.9, 0.8, 0.55), 2.5)
		var lr := Rect2(c + Vector2(-46, 44), Vector2(92, 22))
		draw_rect(lr, BRONZE)
		Desk.engraved(self, lr, s[0], 14)
	# What he'll be, as bars on the left (white: now; amber: with the part you're looking at).
	var st := Rect2(30, 90, 240, 300)
	draw_rect(st, Color(0.06, 0.08, 0.08, 0.9))
	draw_rect(st, BRONZE_DK, false, 2.0)
	Desk.engraved(self, Rect2(st.position.x, st.position.y + 6, st.size.x, 18), "THIS HULL", 15, Color(Desk.STENCIL, 0.85))
	var bars := [["CHARGE", 0.6, 0.6], ["HULL", 0.5, 0.5], ["SPEED", 0.45, 0.7], ["NOISE", 0.3, 0.65], ["LAMP", 0.5, 0.5], ["CARDS", 0.33, 0.33]]
	for i in bars.size():
		var y := st.position.y + 46 + i * 42
		var b: Array = bars[i]
		draw_string(Desk.font("plate"), Vector2(st.position.x + 14, y), b[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(Desk.STENCIL, 0.85))
		var br := Rect2(st.position.x + 14, y + 6, st.size.x - 28, 12)
		draw_rect(br, Color(0, 0, 0, 0.6))
		var then: float = b[2]
		var now: float = b[1]
		if then > now:
			draw_rect(Rect2(br.position, Vector2(br.size.x * then, br.size.y)), Color(Desk.AMBER, 0.85 if b[0] != "NOISE" else 0.0))
			if b[0] == "NOISE":
				draw_rect(Rect2(br.position, Vector2(br.size.x * then, br.size.y)), Color(Desk.RED_LAMP, 0.8))
		draw_rect(Rect2(br.position, Vector2(br.size.x * now, br.size.y)), Color(0.85, 0.85, 0.8))
	# Cards and slots, right: what the press will have.
	var cp := Rect2(1010, 90, 240, 300)
	draw_rect(cp, Color(0.06, 0.08, 0.08, 0.9))
	draw_rect(cp, BRONZE_DK, false, 2.0)
	Desk.engraved(self, Rect2(cp.position.x, cp.position.y + 6, cp.size.x, 18), "CARDS AND SLOTS", 15, Color(Desk.STENCIL, 0.85))
	var plates := [["SWIM TOWARDS BEACON", true], ["FOLLOW WALL", true], ["IF HEARD", true], ["DASH (with the jet)", false], ["IF BEACON IN SIGHT", false], ["FOR n SECONDS", false]]
	for i in plates.size():
		var y := cp.position.y + 36 + i * 30
		var owned: bool = plates[i][1]
		draw_rect(Rect2(cp.position.x + 12, y, cp.size.x - 24, 24), NAVY.darkened(0.2) if owned else Color(0.08, 0.09, 0.09))
		draw_string(Desk.font("plate"), Vector2(cp.position.x + 20, y + 17), plates[i][0], HORIZONTAL_ALIGNMENT_LEFT, cp.size.x - 70, 13, Color(Desk.STENCIL, 0.9 if owned else 0.45))
		if not owned:
			draw_circle(Vector2(cp.end.x - 26, y + 12), 7.0, VALVE)
	for i in 6:
		var r := Rect2(cp.position.x + 14 + i * 36, cp.end.y - 50, 30, 36)
		draw_rect(r, Desk.CARD if i < 2 else Color(0.08, 0.09, 0.09))
		draw_rect(r, Color(0, 0, 0, 0.6), false, 1.5)
		if i >= 2:
			_lock(r.get_center())
	# The drawer: every part for the DRIVE socket.
	var dr := Rect2(0, 470, 1280, 250)
	draw_rect(dr, Color(0.09, 0.1, 0.1))
	draw_rect(Rect2(0, 470, 1280, 6), BRONZE)
	Desk.engraved(self, Rect2(0, 480, 1280, 20), "DRIVE  ·  WHAT FITS HIS PODS", 16, Color(Desk.STENCIL, 0.85))
	var parts := [["pods", "STANDARD PODS", "FITTED", "1 tile a second."], ["screws", "TWIN SCREWS", "OWNED", "Half again as fast. Loud: eels hear him twice as far."],
		["fins", "SILENT FINS", "4,000", "Slower. Eels can't hear him at all."], ["jet", "JET PUMP", "6,000", "New card: DASH. A burst, three times as fast."],
		["pods", "CRAWLER LEGS", "SECTOR 7", "Walks on the rock. Currents can't move him."], ["pods", "DRAG ANCHOR", "2,500", "New card: ANCHOR."]]
	for i in parts.size():
		var p: Array = parts[i]
		var sel := i == 1
		var cr := Rect2(30 + i * 206, 512 - (18 if sel else 0), 190, 186)
		Desk.draw_paper(self, cr, Desk.CARD if p[2] in ["FITTED", "OWNED"] else Desk.PAPER, 41 + i, true)
		if sel:
			draw_rect(cr.grow(3), Color(Desk.AMBER_HOT, 0.9), false, 3.0)
		_icon(p[0], cr.position + Vector2(cr.size.x * 0.5, 50), 70.0, Desk.INK if p[2] != "SECTOR 7" else Desk.INK_SOFT, 2.5)
		Desk.centred(self, Rect2(cr.position.x, cr.position.y + 92, cr.size.x, 20), p[1], Desk.font("plate"), 19, Desk.INK)
		draw_multiline_string(Desk.font("type"), cr.position + Vector2(12, 128), p[3], HORIZONTAL_ALIGNMENT_LEFT, cr.size.x - 24, 12, 3, Desk.INK_SOFT)
		var status: String = p[2]
		var col := Desk.RED_INK
		if status == "FITTED":
			col = Color(0.1, 0.35, 0.18)
		elif status == "OWNED":
			col = Desk.INK
		var badge := Rect2(cr.position + Vector2(cr.size.x * 0.5 - 60, cr.size.y - 34), Vector2(120, 26))
		draw_rect(badge, Color(col, 0.85), false, 2.0)
		Desk.centred(self, badge, ("TAP TO FIT" if sel else status) if status == "OWNED" else (status if status in ["FITTED", "SECTOR 7"] else "BUY  " + status), Desk.font("plate"), 15, col)


func _lock(c: Vector2) -> void:
	draw_arc(c + Vector2(0, -4), 6.0, PI, TAU, 8, Color(Desk.STENCIL, 0.5), 2.0)
	draw_rect(Rect2(c + Vector2(-7, -4), Vector2(14, 11)), Color(Desk.STENCIL, 0.5))
