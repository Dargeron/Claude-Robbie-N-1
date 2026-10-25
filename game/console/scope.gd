class_name Scope
extends Control
## The sonar receiver: a SubViewport where the dive (or the sector's chart) is drawn at
## 1280x720, shown through the CRT shader at whatever size the scope has on the console.
## Tapping it magnifies it to the whole screen (the hood) and back.

signal tapped

const VIEW_SIZE := Vector2i(1280, 720)

var viewport: SubViewport
var replay: ReplayPlayer
var chart: SonarView
var hud: ScopeHud
var screen: TextureRect
var crt: ShaderMaterial
var room: Room
var sector_label := ""
var serial := 0
var entry: Dictionary = {}
var _power := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(viewport)
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.012, 0.008)
	bg.size = Vector2(VIEW_SIZE)
	viewport.add_child(bg)
	replay = ReplayPlayer.new()
	replay.view_factory = func() -> DiveView: return SonarView.new()
	replay.show_hud = false
	replay.scale = Vector2(2, 2)
	viewport.add_child(replay)
	chart = SonarView.new()
	chart.scale = Vector2(2, 2)
	viewport.add_child(chart)
	hud = ScopeHud.new()
	hud.scope = self
	viewport.add_child(hud)
	screen = TextureRect.new()
	screen.texture = viewport.get_texture()
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	crt = ShaderMaterial.new()
	crt.shader = load("res://console/crt.gdshader")
	screen.material = crt
	add_child(screen)
	resized.connect(_on_resized)


func _on_resized() -> void:
	crt.set_shader_parameter("screen_px", size)
	crt.set_shader_parameter("corner_px", 22.0 if size.x < 900 else 34.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit()
		accept_event()


## Show a sector's chart with no Robbie in the water.
func show_chart(r: Room, memory: PackedByteArray, losses: Array, label: String) -> void:
	room = r
	sector_label = label
	entry = {}
	serial = 0
	if replay.view != null:
		replay.view.queue_free()
		replay.view = null
	chart.visible = true
	chart.losses = losses
	chart.setup_chart(r, memory)


func play(dive: Dive, e: Dictionary, history: Dictionary, memory: PackedByteArray, ghost: Dictionary, losses: Array, label: String) -> void:
	room = dive.room
	sector_label = label
	entry = e
	serial = int(e.get("serial", 0))
	chart.visible = false
	var h := history.duplicate()
	h["last_words"] = e.get("last_words", "")
	replay.play(dive, maxi(serial, 0), Voice.captions(dive, maxi(serial, 1), h) if serial > 0 else [])
	var v := replay.view as SonarView
	v.ghost = ghost
	v.losses = losses
	v.set_memory(memory)


func has_dive() -> bool:
	return replay.view != null


func sonar() -> SonarView:
	return replay.view as SonarView


## Warm the tube up (after a dispatch, or when switching sectors).
func warm_up() -> void:
	_power = 0.0


func _process(delta: float) -> void:
	_power = minf(1.0, _power + delta * 2.5)
	var d := 0.0
	if has_dive():
		d = sonar().dead
		# The carrier drops over a second after the last tick, then stays mostly static.
		if d > 0.0:
			d = 0.72
	crt.set_shader_parameter("dead", d)
	crt.set_shader_parameter("power", 0.25 + 0.75 * _power)


## The receiver's own readouts, drawn into the tube at full resolution.
class ScopeHud:
	extends Node2D
	var scope: Scope

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var f := Desk.font("crt")
		var g := Color(Desk.PHOSPHOR, 0.9)
		var gd := Color(Desk.PHOSPHOR, 0.55)
		var now := Time.get_ticks_msec() / 1000.0
		draw_string(f, Vector2(46, 58), scope.sector_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, gd)
		if not scope.has_dive():
			var msg := "NO CARRIER"
			if fmod(now, 1.6) < 1.1:
				Desk.centred(self, Rect2(0, 600, 1280, 60), msg, f, 44, Color(Desk.PHOSPHOR, 0.7))
			Desk.centred(self, Rect2(0, 648, 1280, 40), "CHART FROM EARLIER ROBBIES  ·  DROP POINT MARKED", f, 28, gd)
			return
		var rp := scope.replay
		var v := rp.view
		var d := v.dive
		var rec := d.rec
		var k := clampi(int(v.t), 0, v.last_tick())
		var who := "ROBBIE %03d" % scope.serial if scope.serial > 0 else "TRIAL HULL"
		draw_string(f, Vector2(46, 96), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color(Desk.AMBER, 0.95))
		var secs := float(k) / World.TICKS_PER_SECOND
		draw_string(f, Vector2(1020, 58), "T+%02d:%04.1f" % [int(secs) / 60, fmod(secs, 60.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 38, g)
		# Hull and charge.
		draw_string(f, Vector2(1020, 96), "HULL", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, gd)
		for h in World.R_HP:
			var on := h < rec.rhp[k]
			draw_rect(Rect2(1080 + h * 30, 76, 22, 16), Desk.AMBER if on else Color(Desk.AMBER, 0.15))
		var e := float(rec.ren[k]) / float(d.world.energy_max)
		draw_string(f, Vector2(1020, 128), "CHG", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, gd)
		draw_rect(Rect2(1080, 112, 150, 12), Color(Desk.PHOSPHOR, 0.15))
		draw_rect(Rect2(1080, 112, 150.0 * e, 12), g if e > 0.25 else Color(Desk.RED_LAMP, 0.9))
		# Robbie's voice, as he sends it.
		var cap: String = rp.caption_at(k)
		if cap != "":
			var w := f.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
			draw_rect(Rect2(640 - w / 2 - 18, 604, w + 36, 46), Color(0, 0, 0, 0.6))
			draw_string(f, Vector2(640 - w / 2, 638), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Desk.AMBER_HOT)
		# Transport state.
		var spd: float = rp.speed()
		var mode := "PAUSED" if not rp.playing else ("REWIND" if rp.rewinding else ("AUTO ×%s" % ("%.1f" % spd) if rp.auto else "PLAY ×%s" % str(spd).trim_suffix(".0")))
		if rp.skip_until > 0 and k < rp.skip_until and rp.playing:
			mode = "SKIPPING TO THE TROUBLE"
		draw_string(f, Vector2(46, 686), mode, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, gd)
		if k >= v.last_tick():
			var ok := d.world.result == World.Result.EXIT
			var msg := "BEACON REACHED" if ok else "CARRIER LOST"
			if ok or fmod(now, 1.0) < 0.7:
				var col := Desk.PHOSPHOR if ok else Color(0.85, 1.0, 0.85)
				draw_rect(Rect2(380, 300, 520, 110), Color(0, 0, 0, 0.55))
				Desk.centred(self, Rect2(380, 300, 520, 70), msg, f, 64, col)
				Desk.centred(self, Rect2(380, 362, 520, 40), Voice.cause_label(d.world.cause).to_upper() if not ok else "HULL RECOVERABLE", f, 30, gd)
