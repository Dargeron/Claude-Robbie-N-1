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
const AUTO_FAST := 4.0          # AUTO plays quiet stretches this fast...
const AUTO_SLOW := 1.0          # ...and slows to this around anything that happens
const AUTO_RAMP := 0.06         # speed change per tick of dive time (about 1.7 s from slow to fast)

var view: DiveView
var hud: Hud
var view_factory: Callable      # makes the view (a DiveView subclass); the station's own picture if unset
var show_hud := true            # the console draws its own readouts
var speed_i := 1
var auto := true                # AUTO speed: fast through quiet water, normal speed around events
var skip_until := -1            # skip ahead at SKIP_SPEED until this tick (just before the last Robbie was lost)
const SKIP_SPEED := 8.0
var auto_speeds := PackedFloat32Array()
var playing := true
var rewinding := false
var serial := 1
var captions: Array = []        # [[tick, text], ...] from Voice
var standalone := false
var auto_quit := false
var hold_frames := 45
var _ended := false
var _sound_tick := -1


func _ready() -> void:
	standalone = get_parent() == get_tree().root
	if not standalone:
		return
	scale = Vector2(2, 2)   # the canvas is 1280x720; dives are drawn at 640x360
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.start_ambience()
	var args := OS.get_cmdline_user_args()
	var room_id := args[0] if args.size() > 0 else "valve"
	var prog_path := args[1] if args.size() > 1 else "res://content/programs/valve/intended.rbt"
	var seed_v := int(args[2]) if args.size() > 2 else 1
	var ser := 1
	for a in args:
		if a == "speed=auto":
			auto = true
		elif a.begins_with("speed="):
			auto = false
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
	if hud != null:
		hud.queue_free()
		hud = null
	serial = serial_number
	captions = caption_list
	view = view_factory.call() if view_factory.is_valid() else DiveView.new()
	add_child(view)
	view.setup(dive)
	auto_speeds = ReplayPlayer.plan_auto_speeds(dive, captions)
	if show_hud:
		hud = Hud.new()
		hud.replay = self
		add_child(hud)
	playing = true
	rewinding = false
	_ended = false
	_sound_tick = -1


func has_dive() -> bool:
	return view != null


func tick() -> int:
	return clampi(int(view.t), 0, view.last_tick()) if view != null else 0


func seek(t: float) -> void:
	if view == null:
		return
	skip_until = -1   # once the player takes the playhead, stop skipping
	view.t = clampf(t, 0.0, float(view.last_tick()))
	_ended = view.t >= float(view.last_tick())


## The playback speed right now (in AUTO it depends on where the playhead is).
func speed() -> float:
	if skip_until > 0 and view != null and playing and not rewinding and tick() < skip_until:
		return SKIP_SPEED
	if auto and view != null and auto_speeds.size() > 0:
		return auto_speeds[tick()]
	return SPEEDS[speed_i]


## Speed button: AUTO, x0.5, x1, x2, x4, x8, AUTO...
func cycle_speed() -> void:
	if auto:
		auto = false
		speed_i = 0
	elif speed_i >= SPEEDS.size() - 1:
		auto = true
	else:
		speed_i += 1


## Arrow keys: one step slower or faster through x0.5 ... x8 (AUTO counts as x1 to start from).
func step_speed(dir: int) -> void:
	if auto:
		auto = false
		speed_i = 1
	speed_i = clampi(speed_i + dir, 0, SPEEDS.size() - 1)


func speed_label() -> String:
	if skip_until > 0 and view != null and tick() < skip_until:
		return "SKIP"
	return "AUTO" if auto else "×%s" % str(SPEEDS[speed_i]).trim_suffix(".0")


## AUTO speed for every tick: fast through quiet water, slowing to normal speed a
## moment before anything happens (a hit, the lurker waking, a shot, the valve
## closing, the exit), while Robbie talks, and for the last seconds.
static func plan_auto_speeds(dive: Dive, caption_list: Array) -> PackedFloat32Array:
	var n := dive.rec.ticks
	var s := PackedFloat32Array()
	s.resize(n)
	s.fill(AUTO_FAST)
	var spans: Array = []   # [from tick, to tick, speed]; packed arrays can't be changed inside a lambda
	for e in dive.world.events:
		match e["type"]:
			"damage", "lurker_wakes", "lurker_strikes", "valve_sting", "exit", "eel_hears":
				spans.append([int(e["t"]) - 30, int(e["t"]) + 30, AUTO_SLOW])
			"laser":
				spans.append([int(e["t"]) - 15, int(e["t"]) + 15, 2.0])   # shots are frequent: ease off, don't stop
			"valve":
				if e["state"] == "closing":
					spans.append([int(e["t"]) - 20, int(e["t"]) + 20, AUTO_SLOW])
	for c in caption_list:
		spans.append([int(c[0]), int(c[0]) + 60, 1.5])
	spans.append([n - 75, n, AUTO_SLOW])
	spans.append([0, 45, AUTO_SLOW])
	for sp in spans:
		for k in range(maxi(int(sp[0]), 0), mini(int(sp[1]), n)):
			s[k] = minf(s[k], float(sp[2]))
	# Ease in and out: never change faster than AUTO_RAMP per tick, so it slows down before a moment.
	for k in range(n - 2, -1, -1):
		s[k] = minf(s[k], s[k + 1] + AUTO_RAMP)
	for k in range(1, n):
		s[k] = minf(s[k], s[k - 1] + AUTO_RAMP)
	return s


func _process(delta: float) -> void:
	if view == null:
		return
	var ticks_per_second: float = float(World.TICKS_PER_SECOND) * speed()
	if playing:
		var dir := -1.0 if rewinding else 1.0
		view.t = clampf(view.t + dir * ticks_per_second * delta, 0.0, float(view.last_tick()))
		if rewinding and view.t <= 0.0:
			rewinding = false
	_sounds()
	if view.t >= float(view.last_tick()) and not _ended:
		_ended = true
		reached_end.emit()
	if auto_quit and _ended:
		hold_frames -= 1
		if hold_frames <= 0:
			get_tree().quit()


## Sounds for everything the playhead passed since last frame, but only while
## watching forwards at up to double speed (scrubbing and fast-forward stay quiet).
func _sounds() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	var k := tick()
	if sfx == null:
		return
	sfx.set_dive_level(1.0 if playing and not _ended else 0.25)
	if not playing or rewinding or speed() > 2.0 or k < _sound_tick or k - _sound_tick > 20:
		_sound_tick = k
		return
	var d := view.dive
	for e in d.world.events:
		var t: int = e["t"]
		if t <= _sound_tick or t > k:
			continue
		match e["type"]:
			"damage":
				match e["cause"]:
					"jellyfish":
						sfx.play("sting", -4.0)
					"wall":
						sfx.play("crash", -3.0)
					"valve":
						sfx.play("sting", -4.0, 0.7)
					"lurker":
						sfx.play("strike")
			"lurker_wakes":
				sfx.play("lurker_wake", -2.0)
			"eel_hears":
				sfx.play("lurker_wake", -3.0, 1.5)
			"lurker_strikes":
				if not e["hit"]:
					sfx.play("strike", -8.0, 1.3)
			"valve":
				if e["state"] == "closing":
					sfx.play("valve", -6.0)
			"laser":
				sfx.play("laser", -5.0)
			"exit":
				sfx.play("exit", -3.0)
	for c in captions:
		var ct: int = c[0]
		if ct > _sound_tick and ct <= k:
			_babble(sfx, str(c[1]))
	if _sound_tick < 0 and k <= 1:
		sfx.play("launch", -4.0)
	if k >= view.last_tick() and _sound_tick < view.last_tick():
		sfx.play("burst", -6.0)
	_sound_tick = k


## Robbie's voice: a few blips whose pitch follows the words.
func _babble(sfx: Node, text: String) -> void:
	var n := clampi(text.length() / 9, 2, 6)
	for i in n:
		var ch := text.unicode_at((i * 7) % maxi(text.length(), 1))
		var pitch := 0.85 + float((ch * 7 + serial * 13) % 40) / 100.0
		get_tree().create_timer(0.07 * i).timeout.connect(func() -> void: sfx.play("blip", -12.0, pitch))


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
			auto = false
			speed_i = mini(speed_i + 1, SPEEDS.size() - 1)
		KEY_DOWN:
			auto = false
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
		var spd: float = replay.speed()
		var vhs: bool = replay.rewinding or absf(spd - 1.0) > 0.05 or not replay.playing
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
		var shown := "%.1f" % spd if replay.auto else str(spd).trim_suffix(".0")
		var mode := "PAUSED" if not replay.playing else ("REWIND x%s" % shown if replay.rewinding else ("PLAY x%s" % shown if absf(spd - 1.0) > 0.05 else "PLAY"))
		if replay.auto and replay.playing and not replay.rewinding:
			mode = "AUTO x%s" % shown
		if replay.skip_until > 0 and k < replay.skip_until and replay.playing and not replay.rewinding:
			mode = "SKIPPING AHEAD"
		draw_string(font, Vector2(560, 355), mode, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, dim)
		if k >= v.last_tick():
			var ok := d.world.result == World.Result.EXIT
			var msg := "REACHED THE EXIT" if ok else "LOST: %s" % Voice.cause_label(d.world.cause).to_upper()
			# Keep the card away from where Robbie ended.
			var cy := 22.0 if rec.ry[k] / Fx.ONE > 150 else 270.0
			draw_rect(Rect2(170, cy, 300, 40), Color(0, 0, 0, 0.75))
			draw_string(font, Vector2(170, cy + 16), "TRANSMISSION ENDS", HORIZONTAL_ALIGNMENT_CENTER, 300, 10, dim)
			draw_string(font, Vector2(170, cy + 33), msg, HORIZONTAL_ALIGNMENT_CENTER, 300, 12, Color(0.5, 1, 0.6) if ok else Color(1, 0.45, 0.4))
