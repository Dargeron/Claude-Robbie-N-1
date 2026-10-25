extends Node
## The game's root: the operator's console, face on, filling the screen.
## The 3D view from the chair (ChairView) that 0.3.0 offered beside it is set aside for now
## (Albert, 2026-10-26: "clunky"; we keep upgrading the 2D desk) but still works, for the
## tools only: ROBBIE_VIEW=chair. There the console draws into an offscreen viewport laid on
## the faces of a 3D console; touches are traced from the screen onto those faces and handed to
## it as if they had landed there; paper (memos, the binder, the Wall) comes up flat to read;
## pinch, or the mouse wheel, leans in.

var console: Control
var chair: ChairView
var view := "flat"
var _sub: SubViewport
var _ui: CanvasLayer
var _paper: TextureRect          # chair view: memos and the Wall brought up flat
var _paper_up := 0.0
var _touches := {}               # finger index -> position, for the pinch
var _pinch_d := 0.0
var _pinch_zoom := 0.0
var _pinching := false


func _init() -> void:
	# Made here, so a tool can point the console at its own save before it starts.
	console = load("res://console/console.tscn").instantiate()


func _ready() -> void:
	if OS.get_environment("ROBBIE_VIEW") == "chair":
		view = "chair"
	if view == "flat":
		add_child(console)
		return
	_sub = SubViewport.new()
	var win := DisplayServer.window_get_size()
	var w := clampi(int(win.x * 1.2), 1280, 2560)
	_sub.size = Vector2i(w, w * 9 / 16)
	_sub.size_2d_override = Vector2i(1280, 720)
	_sub.size_2d_override_stretch = true
	_sub.disable_3d = true
	_sub.handle_input_locally = true
	add_child(_sub)
	chair = ChairView.new()
	chair.screen_texture = _sub.get_texture()
	add_child(chair)
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)
	_paper = TextureRect.new()
	_paper.texture = _sub.get_texture()
	_paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_paper.stretch_mode = TextureRect.STRETCH_SCALE
	_paper.size = Vector2(1280, 720)
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.modulate.a = 0.0
	_ui.add_child(_paper)
	_sub.add_child(console)
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	chair.camera.make_current()


## Is paper up in front of the console (read flat even in the chair view)?
func _reading() -> bool:
	return console.memo.visible or console.wall.visible


func _process(delta: float) -> void:
	if view != "chair":
		return
	_paper_up = move_toward(_paper_up, 1.0 if _reading() else 0.0, delta * 5.0)
	_paper.modulate.a = _paper_up


## Where a screen position lands on the console, in the current view.
func to_console(p: Vector2) -> Vector2:
	if view != "chair" or _paper_up > 0.5:
		return p
	return chair.console_point(p)


## And back: where a console position shows on the screen (for the scripted play-through).
func to_screen(p: Vector2) -> Vector2:
	if view != "chair" or _reading():
		return p
	return chair.screen_point(p)


func _input(event: InputEvent) -> void:
	if view != "chair":
		return
	get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_pinch(event)
		return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if event.pressed and _paper_up < 0.5:
			var dz := 0.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.12
			chair.lean(chair.zoom + dz, chair.console_point(event.position) if chair.zoom == 0.0 else _focus_console())
		return
	if event is InputEventMouse:
		if _pinching:
			return
		var e := event.duplicate() as InputEventMouse
		var p := to_console(event.position)
		e.position = p
		e.global_position = p
		if e is InputEventMouseMotion:
			var em := e as InputEventMouseMotion
			em.relative = p - to_console(event.position - (event as InputEventMouseMotion).relative)
		_sub.push_input(e, true)
		return
	_sub.push_input(event, true)


func _focus_console() -> Vector2:
	var f := chair.focus
	return chair.console_point(chair.camera.unproject_position(f))


## Two fingers lean in or sit back: spread them to go closer to what is between them.
func _pinch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
	if _touches.size() >= 2:
		var ks := _touches.keys()
		var a: Vector2 = _touches[ks[0]]
		var b: Vector2 = _touches[ks[1]]
		var d := a.distance_to(b)
		if not _pinching:
			_pinching = true
			_pinch_d = maxf(d, 1.0)
			_pinch_zoom = chair.zoom
			# Let go of whatever the first finger had hold of.
			var up := InputEventMouseButton.new()
			up.button_index = MOUSE_BUTTON_LEFT
			up.pressed = false
			up.position = to_console(a)
			up.global_position = up.position
			_sub.push_input(up, true)
		var mid := (a + b) * 0.5
		chair.lean(_pinch_zoom + (d / _pinch_d - 1.0) * 1.2, chair.console_point(mid) if _pinch_zoom == 0.0 else _focus_console())
	elif _touches.is_empty():
		_pinching = false
