class_name SonarView
extends DiveView
## A dive as the sonar receiver shows it (the Dead Air look): the sector painted by the
## terrain shader from what Robbie sensed, contacts as green echoes, the beacon's ping,
## and Robbie himself as the only warm thing, an amber glyph with his lamp as an amber
## wedge. When he is lost the glyph breaks up and the carrier drops: dead air.
## Also shows a sector's chart with no dive at all (setup_chart): what earlier Robbies
## charted, the drop point, and a cross where each one was lost.
## Uses DiveView's record of what was sensed when, so it never shows what Robbie couldn't know.

const GLYPH_STEPS := 16
const SWEEP_PERIOD := 2.6     # seconds per turn of the sweep

var terrain: Sprite2D
var losses: Array = []        # [{pos: Vector2, serial: int}] where earlier Robbies were lost
var chart_room: Room          # the room when there is no dive
var contact_ids := {}         # body index -> contact number, in the order Robbie found them
var dead := 0.0               # 0..1 how far the carrier has dropped (read by the scope)


func setup(d: Dive) -> void:
	super.setup(d)
	contact_ids = {}
	var order: Array = []
	for i in first_sensed.size():
		if first_sensed[i] != NEVER:
			order.append([first_sensed[i], i])
	order.sort()
	for n in order.size():
		contact_ids[order[n][1]] = n + 1
	_build_terrain(d.room)


func setup_chart(room: Room, memory: PackedByteArray) -> void:
	dive = null
	chart_room = room
	station_memory = memory
	_build_terrain(room)


func _room() -> Room:
	return dive.room if dive != null else chart_room


## The terrain sprite: the room's distance field drawn through the sonar shader, behind
## everything this node draws itself.
func _build_terrain(room: Room) -> void:
	if terrain != null:
		terrain.queue_free()
	terrain = Sprite2D.new()
	terrain.centered = false
	terrain.show_behind_parent = true
	terrain.texture = ImageTexture.create_from_image(_distance_field(room))
	terrain.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	terrain.scale = Vector2(room.w * 16.0, room.h * 16.0) / terrain.texture.get_size()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://console/sonar_terrain.gdshader")
	mat.set_shader_parameter("tiles", Vector2(room.w, room.h))
	mat.set_shader_parameter("reveal", ImageTexture.create_from_image(_reveal_image(room)))
	terrain.material = mat
	add_child(terrain)


## Signed distance to the rock's edge at 4 px cells (positive in water), by two chamfer passes.
static func _distance_field(room: Room) -> Image:
	var cw := room.w * 4
	var ch := room.h * 4
	var rock := PackedByteArray()
	rock.resize(cw * ch)
	for y in ch:
		for x in cw:
			rock[y * cw + x] = 1 if room.tile_at(x / 4, y / 4) == Room.Tile.ROCK else 0
	var to_rock := _chamfer(rock, cw, ch, 1)
	var to_water := _chamfer(rock, cw, ch, 0)
	var img := Image.create(cw, ch, false, Image.FORMAT_L8)
	for y in ch:
		for x in cw:
			var i := y * cw + x
			# Cell units are 4 px; chamfer distances are x3.
			var px := (float(to_rock[i]) - float(to_water[i])) / 3.0 * 4.0
			img.set_pixel(x, y, Color(clampf((128.0 + px * 2.0) / 255.0, 0.0, 1.0), 0, 0))
	return img


## Distance (3-4 chamfer) from every cell to the nearest cell whose rock flag equals `target`.
static func _chamfer(rock: PackedByteArray, w: int, h: int, target: int) -> PackedInt32Array:
	var big := 1 << 20
	var d := PackedInt32Array()
	d.resize(w * h)
	for i in w * h:
		d[i] = 0 if rock[i] == target else big
	for y in h:
		for x in w:
			var i := y * w + x
			var v := d[i]
			if x > 0:
				v = mini(v, d[i - 1] + 3)
			if y > 0:
				v = mini(v, d[i - w] + 3)
				if x > 0:
					v = mini(v, d[i - w - 1] + 4)
				if x < w - 1:
					v = mini(v, d[i - w + 1] + 4)
			d[i] = v
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var v := d[i]
			if x < w - 1:
				v = mini(v, d[i + 1] + 3)
			if y < h - 1:
				v = mini(v, d[i + w] + 3)
				if x < w - 1:
					v = mini(v, d[i + w + 1] + 4)
				if x > 0:
					v = mini(v, d[i + w - 1] + 4)
			d[i] = v
	return d


## Per tile, when this Robbie first sensed it and whether earlier Robbies charted it. Rock
## heard at its face is drawn a little way in (two tiles, rippling inward), so walls read
## as the deep contoured masses of the Dead Air look instead of a single line.
func _reveal_image(room: Room) -> Image:
	var img := Image.create(room.w, room.h, false, Image.FORMAT_RGBA8)
	var n := room.w * room.h
	var has_mem := station_memory.size() == n
	var first := PackedInt32Array()
	first.resize(n)
	var mem := PackedByteArray()
	mem.resize(n)
	for i in n:
		first[i] = mini(first_seen[i], 65535) if dive != null and i < first_seen.size() else 65535
		mem[i] = 1 if has_mem and station_memory[i] == 1 else 0
	var dfirst := first.duplicate()
	var dmem := mem.duplicate()
	for y in room.h:
		for x in room.w:
			if room.tile_at(x, y) != Room.Tile.ROCK:
				continue
			var i := y * room.w + x
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= room.w or ny >= room.h:
						continue
					var j := ny * room.w + nx
					var dist := maxi(absi(dx), absi(dy))
					if first[j] < 65535:
						dfirst[i] = mini(dfirst[i], first[j] + dist * 8)
					if mem[j] == 1:
						dmem[i] = 1
	for y in room.h:
		for x in room.w:
			var i := y * room.w + x
			var f := mini(dfirst[i], 65535)
			img.set_pixel(x, y, Color8(f >> 8, f & 255, 255 if dmem[i] == 1 else 0, 255))
	return img


## The station memory arrives after setup (the scope sets it): refresh the chart.
func set_memory(memory: PackedByteArray) -> void:
	station_memory = memory
	if terrain != null:
		(terrain.material as ShaderMaterial).set_shader_parameter("reveal", ImageTexture.create_from_image(_reveal_image(_room())))


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var mat := terrain.material as ShaderMaterial if terrain != null else null
	if mat != null:
		mat.set_shader_parameter("sweep", fposmod(now / SWEEP_PERIOD * TAU, TAU))
		if dive != null:
			var k := clampi(int(t), 0, last_tick())
			mat.set_shader_parameter("now_tick", t)
			mat.set_shader_parameter("robbie", _robbie_pos())
			mat.set_shader_parameter("live", 1.0)
			dead = 0.0
			if dive.world.result != World.Result.EXIT and k >= last_tick():
				dead = 1.0
		else:
			var r := _room()
			mat.set_shader_parameter("robbie", _drop(r) if r != null else Vector2.ZERO)
			mat.set_shader_parameter("live", 0.0)
			dead = 0.0
	queue_redraw()


static func _drop(r: Room) -> Vector2:
	return Vector2(r.start_tx * 16 + 8, r.start_ty * 16 + 8)


func _robbie_pos() -> Vector2:
	var rec := dive.rec
	var k := clampi(int(t), 0, last_tick())
	var k2 := mini(k + 1, last_tick())
	return _lerp_pos(rec.rx, rec.ry, k, k2, t - float(k))


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_draw_losses()
	if dive == null:
		_draw_drop_point(now)
		return
	var rec := dive.rec
	var k := clampi(int(t), 0, last_tick())
	var k2 := mini(k + 1, last_tick())
	var f := t - float(k)
	var rpos := _robbie_pos()
	var lamp_on := (rec.rflags[k] & 1) == 1
	_draw_ghost_trail()
	if lamp_on and rec.rhp[k] > 0:
		_draw_wedge(k, rpos)
	_draw_plants_sonar(k, now)
	_draw_beacon_sonar(k, now)
	_draw_valve(k, now)
	_draw_contacts(k, k2, f, now)
	_draw_lasers(k)
	_draw_bearing_sonar(k, rpos, now)
	_draw_glyph(k, rpos, now)


func _draw_drop_point(now: float) -> void:
	var r := _room()
	if r == null:
		return
	var p := _drop(r)
	var a := 0.55 + 0.35 * sin(now * 3.0)
	draw_arc(p, 6.0, 0, TAU, 20, Color(Desk.AMBER, a), 1.0)
	draw_line(p + Vector2(-9, 0), p + Vector2(-4, 0), Color(Desk.AMBER, a), 1.0)
	draw_line(p + Vector2(4, 0), p + Vector2(9, 0), Color(Desk.AMBER, a), 1.0)
	draw_line(p + Vector2(0, -9), p + Vector2(0, -4), Color(Desk.AMBER, a), 1.0)
	draw_line(p + Vector2(0, 4), p + Vector2(0, 9), Color(Desk.AMBER, a), 1.0)
	var font := Desk.font("crt")
	draw_string(font, p + Vector2(10, -6), "DROP", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(Desk.AMBER, 0.8))


## A small cross and serial where each earlier Robbie went silent.
func _draw_losses() -> void:
	var font := Desk.font("crt")
	for l: Dictionary in losses:
		var p: Vector2 = l["pos"]
		var c := Color(Desk.PHOSPHOR, 0.38)
		draw_line(p + Vector2(-3, -3), p + Vector2(3, 3), c, 1.0)
		draw_line(p + Vector2(-3, 3), p + Vector2(3, -3), c, 1.0)
		draw_string(font, p + Vector2(4, -3), "%03d" % int(l["serial"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(Desk.PHOSPHOR, 0.3))


func _draw_ghost_trail() -> void:
	if ghost.is_empty():
		return
	var path: PackedVector2Array = ghost["path"]
	var step := float(GameState.PATH_STEP)
	var n := mini(int(t / step) + 1, path.size())
	var c := Color(Desk.PHOSPHOR, 0.22)
	for i in range(0, n - 1, 2):
		draw_line(path[i], path[i + 1], c, 1.0)


## The lamp: an amber wedge, the cone the sim's own rays allow.
func _draw_wedge(k: int, rpos: Vector2) -> void:
	var rec := dive.rec
	var ends := dive.world.lamp_ray_ends(int(rpos.x * Fx.ONE), int(rpos.y * Fx.ONE), rec.ra[k], rec.gate[k], LAMP_RAYS)
	var pts := PackedVector2Array([rpos])
	var cols := PackedColorArray([Color(Desk.AMBER, 0.34)])
	var rim := PackedVector2Array()
	for i in range(0, ends.size(), 2):
		var e := _p(ends[i], ends[i + 1])
		pts.append(e)
		rim.append(e)
		cols.append(Color(Desk.AMBER, lerpf(0.2, 0.02, clampf(e.distance_to(rpos) / 96.0, 0.0, 1.0))))
	if not Geometry2D.triangulate_polygon(pts).is_empty():
		draw_polygon(pts, cols)
	draw_polyline(rim, Color(Desk.AMBER, 0.28), 1.0)
	draw_arc(rpos, 48.0, 0, TAU, 48, Color(Desk.AMBER, 0.08), 1.0)


func _draw_plants_sonar(k: int, now: float) -> void:
	var plants := dive.room.plants
	for i in plants.size():
		var p := plants[i]
		var pos := Vector2(p.x * 16 + 8, p.y * 16 + 8)
		var found := i < plant_found.size() and plant_found[i] <= k
		if not found and not _in_station_memory(p.x, p.y):
			continue
		var a := 0.85 if found else 0.3
		var pulse := 0.7 + 0.3 * sin(now * 1.3 + p.x)
		for s in 6:
			var ang := TAU * s / 6.0 + p.x
			draw_line(pos + Vector2.from_angle(ang) * 2.0, pos + Vector2.from_angle(ang) * (5.0 + pulse), Color(Desk.PHOSPHOR, a * 0.7), 1.0)
		draw_circle(pos, 1.4, Color(Desk.PHOSPHOR, a))
		if found:
			_found_ring(pos, k, plant_found[i], Desk.PHOSPHOR, 10.0)


func _draw_beacon_sonar(k: int, now: float) -> void:
	var room := dive.room
	var c := _p(room.exit_cx, room.exit_cy)
	var font := Desk.font("crt")
	if exit_found <= k:
		for j in 2:
			var ping := fmod(now + j * 0.8, 1.6) / 1.6
			draw_arc(c, 4.0 + ping * 26.0, 0, TAU, 36, Color(Desk.PHOSPHOR, 0.7 * (1.0 - ping)), 1.0)
		draw_circle(c, 2.2, Desk.PHOSPHOR)
		draw_string(font, c + Vector2(8, -6), "BEACON", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(Desk.PHOSPHOR, 0.85))
		_found_ring(c, k, exit_found, Desk.PHOSPHOR, 30.0)
	elif _in_station_memory(room.exit_cx / Fx.TILE, room.exit_cy / Fx.TILE):
		draw_arc(c, 5.0, 0, TAU, 24, Color(Desk.PHOSPHOR, 0.25), 1.0)


## The beacon's radio bearing: a small green tick beside Robbie.
func _draw_bearing_sonar(k: int, rpos: Vector2, now: float) -> void:
	if dive.rec.rhp[k] <= 0:
		return
	var c := _p(dive.room.exit_cx, dive.room.exit_cy)
	if c.distance_to(rpos) < 14.0:
		return
	var dir := (c - rpos).normalized()
	var a := 0.8 - 0.4 * (fmod(now, 1.6) / 1.6)
	draw_line(rpos + dir * 12.0, rpos + dir * 17.0, Color(Desk.PHOSPHOR, a), 1.5)


## Creatures as echoes: drawn only while Robbie senses them, a fading ring where he lost them.
func _draw_contacts(k: int, k2: int, f: float, now: float) -> void:
	var rec := dive.rec
	var font := Desk.font("crt")
	for i in rec.bx.size():
		var st := rec.bstate[i][k]
		if (st & 1) == 0:
			continue
		var kind := dive.world.bodies[i].kind
		var state := (st >> 1) & 0x7f
		var ls := last_sensed[i][k] if i < last_sensed.size() else k
		var sensed := ls >= 0 and k - ls <= SENSE_HOLD
		if not sensed:
			if ls >= 0 and k - ls < FADE_TICKS + SENSE_HOLD:
				var fade := 1.0 - float(k - ls - SENSE_HOLD) / FADE_TICKS
				var at := _p(rec.bx[i][ls], rec.by[i][ls])
				draw_arc(at, 4.0 + (1.0 - fade) * 4.0, 0, TAU, 16, Color(Desk.PHOSPHOR, 0.3 * clampf(fade, 0.0, 1.0)), 1.0)
			continue
		var pos := _smooth_pos(i, k, f, 4) if kind == Body.Kind.JELLYFISH else _lerp_pos(rec.bx[i], rec.by[i], k, k2, f)
		if i < first_sensed.size():
			_found_ring(pos, k, first_sensed[i], Desk.PHOSPHOR, 12.0)
		var hot := state == 1
		var col := Color(Desk.PHOSPHOR, 1.0 if hot else 0.8)
		match kind:
			Body.Kind.JELLYFISH:
				var beat := sin(now * (8.0 if hot else 3.0) + i * 1.7)
				var w := 3.6 + 0.5 * beat
				draw_arc(pos, w, PI, TAU, 10, col, 1.2)
				draw_line(pos + Vector2(-w, 0), pos + Vector2(w, 0), col, 1.0)
				for tt in 3:
					var bx := pos.x + (tt - 1) * w * 0.6
					var sway := sin(now * 4.0 + i + tt) * 1.2
					draw_line(Vector2(bx, pos.y + 1), Vector2(bx + sway, pos.y + 6.0 + 0.5 * beat), Color(col, 0.6), 1.0)
				if hot:
					draw_arc(pos, 7.0 + 2.0 * sin(now * 10.0), 0, TAU, 16, Color(Desk.PHOSPHOR, 0.5), 1.0)
			Body.Kind.EEL:
				var back := _p(rec.bx[i][maxi(k - 5, 0)], rec.by[i][maxi(k - 5, 0)])
				var dir := (pos - back).normalized() if pos.distance_to(back) > 0.5 else Vector2(0, 1)
				var side := Vector2(-dir.y, dir.x)
				var pts := PackedVector2Array()
				for s in 8:
					pts.append(pos - dir * (s * 2.2) + side * sin(now * 9.0 - s * 0.9 + i) * (0.4 + s * 0.3))
				draw_polyline(pts, col, 1.6 if hot else 1.1)
			Body.Kind.LURKER:
				var spikes := PackedVector2Array()
				for s in 13:
					var a := TAU * s / 12.0
					spikes.append(pos + Vector2.from_angle(a) * (7.0 if s % 2 == 0 else 4.5) * (1.0 + (0.15 * sin(now * 18.0) if hot else 0.0)))
				draw_polyline(spikes, col, 1.2)
			_:
				draw_circle(pos, 2.5, col)
		var n: int = contact_ids.get(i, 0)
		if n > 0:
			draw_string(font, pos + Vector2(7, -5), "C-%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(Desk.PHOSPHOR, 0.7))
	for e in dive.world.events:
		if e["type"] == "lurker_strikes" and k >= e["t"] and k < e["t"] + 8:
			var b: int = e["src"]
			draw_arc(_p(rec.bx[b][e["t"]], rec.by[b][e["t"]]), 10.0 + (k - e["t"]) * 4.0, 0, TAU, 24,
				Color(Desk.PHOSPHOR, 1.0 - (k - e["t"]) / 8.0), 2.0)


## Bathy on the scope: a round amber hull with a porthole and two eye dots, pods behind,
## turned in sixteen steps like a transponder glyph. Hurt, he flickers; lost, he breaks into static.
func _draw_glyph(k: int, pos: Vector2, now: float) -> void:
	var rec := dive.rec
	if rec.rhp[k] <= 0 or (dive.world.result != World.Result.EXIT and k >= last_tick()):
		_draw_dead_air(pos, now)
		return
	var step := TAU / GLYPH_STEPS
	var ang := roundf(rec.ra[k] * TAU / 4096.0 / step) * step
	var fwd := Vector2(sin(ang), -cos(ang))
	var side := Vector2(-fwd.y, fwd.x)
	var hurt := (rec.rflags[k] & 8) != 0
	if hurt and int(now * 14.0) % 2 == 0:
		return
	var col := Desk.AMBER
	Desk.draw_glow(self, pos, 24.0, Color(Desk.AMBER, 0.45))
	# Pods behind, one each side.
	for sgn: float in [-1.0, 1.0]:
		draw_circle(pos - fwd * 5.0 + side * sgn * 6.4, 2.6, col.darkened(0.12))
	draw_circle(pos, 7.4, col)
	draw_arc(pos, 7.4, 0, TAU, 24, Desk.AMBER_HOT, 1.0)
	# The porthole, and in it two eyes looking where he swims.
	var eye := pos + fwd * 1.8
	draw_circle(eye, 4.4, Color(0.16, 0.08, 0.02))
	for sgn: float in [-1.0, 1.0]:
		draw_circle(eye + side * sgn * 1.7 + fwd * 0.7, 1.1, Desk.AMBER_HOT)
	# Antenna, its tip blinking with the transmitter.
	var tip := pos - fwd * 8.5 - side * 3.5
	draw_line(pos - fwd * 6.0 - side * 2.0, tip, col, 1.0)
	if fmod(now, 1.2) < 0.2:
		Desk.draw_glow(self, tip, 6.0, Color(Desk.AMBER_HOT, 0.9))


func _draw_dead_air(pos: Vector2, now: float) -> void:
	var seed_v := int(now * 20.0)
	for i in 40:
		var h := float((seed_v * 7919 + i * 104729) % 1000) / 1000.0
		var h2 := float((seed_v * 3571 + i * 7907) % 1000) / 1000.0
		var p := pos + Vector2(h - 0.5, h2 - 0.5) * 22.0
		draw_rect(Rect2(p, Vector2(1.5, 1.0)), Color(Desk.AMBER, 0.25 + 0.5 * h))
