class_name UiTheme
extends RefCounted
## The station's look: dark panels, amber accents, quiet text. Built in code so
## there is one place to change it.

const BG := Color("070a0f")
const PANEL := Color("10161e")
const PANEL_EDGE := Color("243041")
const TEXT := Color("ddd6c6")
const TEXT_DIM := Color("8b8f94")
const AMBER := Color("ffc35a")
const GREEN := Color("7dffa0")
const RED := Color("ff6a5a")
const CYAN := Color("7fd8ff")


static func box(bg: Color, edge: Color = PANEL_EDGE, radius: int = 4, margin: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 14
	t.set_stylebox("panel", "PanelContainer", box(PANEL))
	t.set_stylebox("panel", "Panel", box(PANEL))
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, box(Color("18212c"), PANEL_EDGE, 3, 6))
		t.set_stylebox("hover", type, box(Color("223044"), Color("3a4b62"), 3, 6))
		t.set_stylebox("pressed", type, box(Color("2c3d55"), AMBER, 3, 6))
		t.set_stylebox("disabled", type, box(Color("0f141b"), Color("1b232e"), 3, 6))
		t.set_stylebox("focus", type, box(Color(0, 0, 0, 0), Color("4a5d78"), 3, 6))
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, AMBER)
		t.set_color("font_disabled_color", type, Color("4d545c"))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("panel", "ItemList", box(Color("0b1016")))
	t.set_stylebox("selected", "ItemList", box(Color("223044"), AMBER, 2, 4))
	t.set_stylebox("selected_focus", "ItemList", box(Color("223044"), AMBER, 2, 4))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_stylebox("background", "ProgressBar", box(Color("0b1016"), PANEL_EDGE, 2, 0))
	t.set_stylebox("fill", "ProgressBar", box(AMBER, AMBER, 2, 0))
	t.set_stylebox("normal", "RichTextLabel", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 2))
	return t
