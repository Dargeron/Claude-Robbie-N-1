class_name ReplayPlayer
extends Node2D
## Plays a dive's transmission: the DiveView plus a HUD (serial, time, hull, energy,
## the rule driving Robbie, Robbie's subtitles) and VHS lines when not at normal speed.
##
## Embedded in the station inside a 640x360 SubViewport. Also runs standalone, e.g. to
## record a movie:
##   godot --path game res://view/replay_scene.tscn -- <room> <program.rbt> [seed] [speed=2] [serial=4] [hold=60] [movie]
## Keys (standalone): Space pause, Left/Right scrub 1 s, Up/Down speed, R rewind, Home restart.

signal reached_end

const SPEEDS := [0.5, 1.0, 2.0, 4.0, 8.0]

var view: DiveView
var hud: Hud
var speed_i := 1
var playing := true
var rewinding := false
var serial := 1
var captions: Array = []        # [[tick, text], ...] from Voice
var standalone := false
var auto_quit := false
var hold_frames := 45
var _ended := false


func _ready() -> void:
	standalone = get_parent() == get_tree().root
	if not standalone:
		return
	scale = Vector2(2, 2)   # the canvas is 1280x720; dives are drawn at 640x360
	var args := OS.get_cmdline_user_args()
	var room_id := args[0] if args.size() > 0 else "valve"
	var prog_path := args[1] if args.size() > 1 else "res://content/programs/valve/intended.rbt"
	var seed_v := int(args[2]) if args.size() > 2 else 1
	var ser := 1
	for a in args:
		if a.begins_with("speed="):
			speed_i = maxi(0, SPEEDS.find(float(a.substr(6))))
		elif a.begins_with("hold="):
			hold_frames = int(a.substr(5))
		elif a.begins_with("serial="):
			ser = int(a.substr(7))
		elif a == "movie":
			auto_quit = true
	var dive := Dive.new(RoomLibrary.load_room(room_id), ProgramFiles.load_program(prog_path), seed_v)
	dive.run()
	play(dive, ser, Voice.captions(dive, ser, {}))


func play(dive: Dive, serial_number: int, caption_list: Array = []) -> void:
	if view != null:
		view.queue_free()
		hud.queue_free()
	serial = serial_number
	captions = caption_list
	view = DiveView.new()
	add_child(view)
	view.setup(dive)
	hud = Hud.new()
	hud.replay = self
	add_child(hud)
	playing = true
	rewinding = false
	_ended = false


func has_dive() -> bool:
	return view != null


func tick() -> int:
	return clampi(int(view.t), 0, view.last_tick()) if view != null else 0


func seek(t: float) -> void:
	if view == null:
		return
	view.t = clampf(t, 0.0, float(view.last_tick()))
	_ended = view.t >= float(view.last_tick())


func speed() -> float:
	return SPEEDS[speed_i]


func cycle_speed() -> void:
	speed_i = (speed_i + 1) % SPEEDS.size()
	if speed_i == 0:
		speed_i = 1


func _process(delta: float) -> void:
	if view == null:
		return
	var ticks_per_second: float = float(World.TICKS_PER_SECOND) * float(SPEEDS[speed_i])
	if playing:
		var dir := -1.0 if rewinding else 1.0
		view.t = clampf(view.t + dir * ticks_per_second * delta, 0.0, float(view.last_tick()))
		if rewinding and view.t <= 0.0:
			rewinding = false
	if view.t >= float(view.last_tick()) and not _ended:
		_ended = true
		reached_end.emit()
	if auto_quit and _ended:
		hold_frames -= 1
		if hold_frames <= 0:
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not standalone or view == null:
		return
	if not (event is InputEventKey) or not event.pressed:
		return
	match event.keycode:
		KEY_SPACE:
			playing = not playing
		KEY_RIGHT:
			seek(view.t + World.TICKS_PER_SECOND)
		KEY_LEFT:
			seek(view.t - World.TICKS_PER_SECOND)
		KEY_UP:
			speed_i = mini(speed_i + 1, SPEEDS.size() - 1)
		KEY_DOWN:
			speed_i = maxi(speed_i - 1, 0)
		KEY_R:
			rewinding = not rewinding
		KEY_HOME:
			seek(0.0)


## Current subtitle: the newest caption that started less than 2.5 s ago.
func caption_at(k: int) -> String:
	var best := ""
	for c in captions:
		if c[0] <= k and k - c[0] < 75:
			best = c[1]
	return best


class Hud:
	extends Node2D
	var replay

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var v: DiveView = replay.view
		if v == null or v.dive == null:
			return
		var d := v.dive
		var rec := d.rec
		var k := clampi(int(v.t), 0, v.last_tick())
		var font := ThemeDB.fallback_font
		var amber := Color(1.0, 0.78, 0.35)
		var dim := Color(0.75, 0.75, 0.7, 0.85)
		var vhs: bool = replay.rewinding or replay.speed_i != 1 or not replay.playing
		if vhs:
			for y in range(0, 360, 3):
				draw_line(Vector2(0, y), Vector2(640, y), Color(1, 1, 1, 0.035), 1.0)
			var now := Time.get_ticks_msec() / 1000.0
			for band in 2:
				var y := fmod(now * (90.0 + band * 55.0) + band * 140.0, 400.0) - 20.0
				draw_rect(Rect2(0, y, 640, 2 + band), Color(0.85, 0.85, 0.85, 0.12))
		draw_rect(Rect2(0, 0, 640, 14), Color(0, 0, 0, 0.55))
		draw_string(font, Vector2(6, 10), "ROBBIE %03d  -  %s" % [replay.serial, d.room.title.to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, amber)
		var secs := float(k) / World.TICKS_PER_SECOND
		draw_string(font, Vector2(440, 10), "T+%02d:%04.1f" % [int(secs) / 60, fmod(secs, 60.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, amber)
		for h in World.R_HP:
			draw_rect(Rect2(520 + h * 9, 4, 7, 6), amber if h < rec.rhp[k] else Color(0.3, 0.25, 0.2))
		var e := float(rec.ren[k]) / float(d.world.energy_max)
		draw_rect(Rect2(552, 5, 80, 4), Color(0.2, 0.2, 0.2))
		draw_rect(Rect2(552, 5, 80.0 * e, 4), Color(0.5, 0.85, 1.0) if e > 0.25 else Color(1, 0.4, 0.3))
		# Robbie's subtitle.
		var cap: String = replay.caption_at(k)
		if cap != "":
			var wdt := font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 16
			draw_rect(Rect2(320 - wdt / 2, 318, wdt, 18), Color(0, 0, 0, 0.65))
			draw_string(font, Vector2(320 - wdt / 2 + 8, 331), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.93, 0.75))
		# The rule driving Robbie right now.
		draw_rect(Rect2(0, 344, 640, 16), Color(0, 0, 0, 0.6))
		var r := rec.rrule[k]
		var label := "no rule applies: drifting" if r < 0 else "RULE %d  >  %s" % [r + 1, d.program.rule_label(d.program.rules[r])]
		draw_string(font, Vector2(6, 355), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6, 1.0, 0.7) if r >= 0 else dim)
		var spd: float = replay.SPEEDS[replay.speed_i]
		var mode := "PAUSED" if not replay.playing else ("REWIND x%s" % spd if replay.rewinding else ("PLAY x%s" % spd if spd != 1.0 else "PLAY"))
		draw_string(font, Vector2(560, 355), mode, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, dim)
		if k >= v.last_tick():
			var ok := d.world.result == World.Result.EXIT
			var msg := "REACHED THE EXIT" if ok else "LOST: %s" % Voice.cause_label(d.world.cause).to_upper()
			draw_rect(Rect2(170, 22, 300, 40), Color(0, 0, 0, 0.75))
			draw_string(font, Vector2(170, 38), "TRANSMISSION ENDS", HORIZONTAL_ALIGNMENT_CENTER, 300, 10, dim)
			draw_string(font, Vector2(170, 55), msg, HORIZONTAL_ALIGNMENT_CENTER, 300, 12, Color(0.5, 1, 0.6) if ok else Color(1, 0.45, 0.4))
