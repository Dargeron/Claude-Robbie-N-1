class_name Desk
extends RefCounted
## The console's look in one place: the layout (layout.json), fonts, inks and the small
## drawing helpers every machine shares (engraved plaque text, glows, paper).

const PHOSPHOR := Color(0.36, 1.0, 0.6)
const PHOSPHOR_DIM := Color(0.12, 0.42, 0.24)
const AMBER := Color(1.0, 0.7, 0.28)
const AMBER_HOT := Color(1.0, 0.86, 0.55)
const RED_LAMP := Color(1.0, 0.22, 0.12)
const RED_INK := Color(0.66, 0.1, 0.07)
const INK := Color(0.12, 0.1, 0.08)
const INK_SOFT := Color(0.24, 0.2, 0.16, 0.85)
const ENGRAVE := Color(0.13, 0.09, 0.04)
const CARD := Color(0.86, 0.81, 0.69)
const PAPER := Color(0.88, 0.85, 0.76)
const NOTE := Color(0.95, 0.86, 0.45)
const GREEN_LAMP := Color(0.45, 1.0, 0.45)
const STENCIL := Color(0.86, 0.79, 0.62)     # paint on dark steel

static var _layout: Dictionary = {}
static var _fonts: Dictionary = {}
static var _glow: Texture2D
static var _textures: Dictionary = {}


static func layout() -> Dictionary:
	if _layout.is_empty():
		_layout = JSON.parse_string(FileAccess.get_file_as_string("res://content/console_layout.json"))
	return _layout


## A rectangle from the layout, in screen pixels.
static func r(key: String) -> Rect2:
	var a: Array = layout()[key]
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


static func plaque(key: String) -> Array:
	return layout()["plaques"][key]


static func plaque_rect(key: String) -> Rect2:
	var a := plaque(key)
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


static func v(key: String) -> Array:
	return layout()[key]


## Fonts: "plate" (engraved plaques), "type" (typewriter: cards, tape, memos),
## "hand" (Op. 5's notes), "crt" (the scope), "letterhead" (the Company).
static func font(kind: String) -> Font:
	if _fonts.is_empty():
		var files := {"plate": "BigShoulders", "type": "SpecialElite", "hand": "PatrickHand", "crt": "VT323", "letterhead": "Cinzel"}
		for k: String in files:
			var f: FontFile = load("res://art/fonts/%s.ttf" % files[k])
			_fonts[k] = f
	return _fonts[kind]


static func tex(name: String) -> Texture2D:
	if not _textures.has(name):
		var file := name
		# Art-direction tests: ROBBIE_PLATE=plate_weathered swaps the desk plate for a variant.
		if name == "plate" and OS.get_environment("ROBBIE_PLATE") != "":
			file = OS.get_environment("ROBBIE_PLATE")
		var path := "res://art/console/%s.png" % file
		_textures[name] = load(path) if ResourceLoader.exists(path) else null
	return _textures[name]


## A soft round glow (white, alpha falling off from the centre), tinted when drawn.
static func glow_texture() -> Texture2D:
	if _glow == null:
		var g := GradientTexture2D.new()
		g.width = 128
		g.height = 128
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		grad.add_point(0.25, Color(1, 1, 1, 0.55))
		grad.add_point(0.55, Color(1, 1, 1, 0.14))
		g.gradient = grad
		_glow = g
	return _glow


static func draw_glow(ci: CanvasItem, at: Vector2, radius: float, col: Color) -> void:
	ci.draw_texture_rect(glow_texture(), Rect2(at - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, col)


## Text stamped into brass: a dark fill with a light lip under it, centred in rect.
static func engraved(ci: CanvasItem, rect: Rect2, text: String, size: int = 13, col: Color = ENGRAVE) -> void:
	if text == "":
		return
	var f := font("plate")
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc := f.get_ascent(size)
	var desc := f.get_descent(size)
	var pos := Vector2(rect.position.x + (rect.size.x - w) * 0.5, rect.position.y + (rect.size.y + asc - desc) * 0.5)
	if rect.size.y < 17.0 and col == ENGRAVE:
		# Thin plaques are too dark for black lettering: paint it cream instead.
		ci.draw_string(f, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.8))
		ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, STENCIL)
		return
	ci.draw_string(f, pos + Vector2(0, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 0.9, 0.6, 0.35))
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Text centred in a rect in any font.
static func centred(ci: CanvasItem, rect: Rect2, text: String, f: Font, size: int, col: Color) -> void:
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc := f.get_ascent(size)
	var desc := f.get_descent(size)
	ci.draw_string(f, Vector2(rect.position.x + (rect.size.x - w) * 0.5, rect.position.y + (rect.size.y + asc - desc) * 0.5),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## A sprite rendered at 2x, drawn at screen size with its centre at `at`, turned by `angle`.
static func draw_sprite(ci: CanvasItem, name: String, at: Vector2, angle: float = 0.0, modulate: Color = Color.WHITE, scale: float = 1.0) -> void:
	var t := tex(name)
	if t == null:
		return
	var sz := t.get_size() * 0.5 * scale
	ci.draw_set_transform(at, angle, Vector2.ONE)
	ci.draw_texture_rect(t, Rect2(-sz * 0.5, sz), false, modulate)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A row of number wheels behind a window (an odometer): numbers on the machine turn, they
## never just change. `value` may be fractional while it rolls: each wheel turns with the one
## to its right as that passes 9.
static func draw_odometer(ci: CanvasItem, win: Rect2, value: float, digits: int, size: int = 24,
		face := Color(0.9, 0.87, 0.78), ink := Color(0.08, 0.06, 0.05)) -> void:
	var f := font("plate")
	var cw := win.size.x / digits
	value = maxf(value, 0.0)
	for i in digits:
		var place := pow(10.0, digits - 1 - i)
		var v := fmod(value / place, 10.0)
		var below := fmod(value, place)
		var turning := clampf(below - (place - 1.0), 0.0, 1.0) if place > 1.0 else 0.0
		var d := floorf(v)
		var frac := (v - d) if place == 1.0 else turning
		var r := Rect2(win.position + Vector2(i * cw + 1, 0), Vector2(cw - 2, win.size.y))
		ci.draw_rect(r, face)
		for k in 2:
			var n := int(d + k) % 10
			var cy := r.get_center().y + (k - frac) * r.size.y
			if cy < r.position.y - size * 0.25 or cy > r.end.y + size * 0.25:
				continue
			centred(ci, Rect2(Vector2(r.position.x, cy - size * 0.55), Vector2(r.size.x, size * 1.1)), str(n), f, size, ink)
		var bands := 6
		var bh := r.size.y / 18.0
		for b in bands:
			var a := 0.09 * (bands - b)
			ci.draw_rect(Rect2(r.position + Vector2(0, b * bh), Vector2(r.size.x, bh)), Color(0, 0, 0, a))
			ci.draw_rect(Rect2(Vector2(r.position.x, r.end.y - (b + 1) * bh), Vector2(r.size.x, bh)), Color(0, 0, 0, a))
	ci.draw_rect(win, Color(0, 0, 0, 0.6), false, 1.0)


## A pilot lamp in its chrome socket with its name painted beside it (the name never changes;
## whether it is lit says the state). `side` is where the label goes: 1 right, -1 left.
static func draw_lamp(ci: CanvasItem, at: Vector2, label: String, col: Color, lit: float, r: float = 5.0, side: int = 1, size: int = 11) -> void:
	ci.draw_circle(at, r + 2.5, Color(0.55, 0.56, 0.55))
	ci.draw_circle(at, r + 1.0, Color(0.12, 0.12, 0.11))
	if lit > 0.0:
		draw_glow(ci, at, r * 4.0, Color(col, 0.6 * lit))
	ci.draw_circle(at, r, Color(0.08, 0.07, 0.06).lerp(col, lit))
	ci.draw_circle(at + Vector2(-r * 0.35, -r * 0.35), r * 0.35, Color(1, 1, 1, 0.18 + 0.2 * lit))
	if label != "":
		var f := font("plate")
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var x := at.x + r + 5.0 if side > 0 else at.x - r - 5.0 - w
		ci.draw_string(f, Vector2(x + 1, at.y + size * 0.36 + 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.7))
		ci.draw_string(f, Vector2(x, at.y + size * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(STENCIL, 0.8))


## A sheet of paper: a flat colour with fibres and a darker edge, deterministic per seed.
static func draw_paper(ci: CanvasItem, rect: Rect2, base: Color, seed_v: int = 1, shadow: bool = true) -> void:
	if shadow:
		ci.draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), Color(0, 0, 0, 0.45))
		ci.draw_rect(Rect2(rect.position + Vector2(1, 2), rect.size), Color(0, 0, 0, 0.35))
	ci.draw_rect(rect, base)
	var t := tex("paper")
	if t != null:
		ci.draw_texture_rect(t, rect, true, Color(1, 1, 1, 0.55))
	# Edges a little darker, as paper handled for a while.
	for i in 4:
		var c := Color(0.25, 0.18, 0.08, 0.05)
		ci.draw_rect(Rect2(rect.position + Vector2(i, i), rect.size - Vector2(i, i) * 2.0), c, false, 1.0)
