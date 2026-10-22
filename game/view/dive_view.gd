class_name DiveView
extends Node2D
## Draws one moment of a recorded dive the way Robbie's camera saw it: black
## water, the lamp's cone (computed with the sim's own rays), glowing life,
## the beacon, and the station's memory of what earlier moments revealed.
## Nothing is drawn until Robbie has sensed it (Albert's note #11): creatures show
## while Robbie senses them and fade where they were last sensed; plants, the valve
## and the beacon stay on the chart once found. Robbie always knows the beacon's
## bearing (it's a radio signal), drawn as a small green tick beside it.
## Presentation only: floats are fine here, nothing feeds back into the sim.

const C_ROCK_LIT := Color(0.50, 0.42, 0.35)
const C_ROCK_MEMORY := Color(0.13, 0.12, 0.12)
const C_ROCK_CHART := Color(0.075, 0.075, 0.085)    # known from earlier Robbies
const C_WATER_CHART := Color(0.012, 0.028, 0.05)
const C_LAMP := Color(1.0, 0.82, 0.48)
const C_JELLY := Color(0.45, 0.9, 1.0)
const C_JELLY_LIT := Color(1.0, 0.6, 0.95)
const C_LURKER := Color(1.0, 0.2, 0.75)
const C_PLANT := Color(0.35, 1.0, 0.7)
const C_BEACON := Color(0.35, 1.0, 0.45)
const C_ROBBIE := Color(1.0, 0.78, 0.3)
const C_VALVE := Color(0.95, 0.5, 0.2)
const C_EEL := Color(0.78, 1.0, 0.45)
const LAMP_RAYS := 33
const SENSE_HOLD := 6                # ticks a creature stays drawn after Robbie stops sensing it
const FADE_TICKS := 60               # then it fades out where it was last sensed
const NEVER := 1 << 30

var dive: Dive
var t := 0.0                         # playback position in ticks (fractional)
var first_seen := PackedInt32Array() # tick at which each tile entered this dive's memory
var station_memory := PackedByteArray()  # tiles any Robbie in this room has ever seen
var ghost: Dictionary = {}           # the previous Robbie's route: {serial, path (px every PATH_STEP ticks), lost}
var last_sensed: Array[PackedInt32Array] = []  # per creature, per tick: the last tick up to then Robbie sensed it, or -1
var plant_found := PackedInt32Array()  # per plant: the first tick Robbie sensed it
var first_sensed := PackedInt32Array() # per creature: the first tick Robbie sensed it (a small "found it" ring)
var exit_found := NEVER                # the first tick Robbie saw the exit


func setup(d: Dive) -> void:
	dive = d
	_build_memory()
	_build_sight()
	queue_redraw()


## Replays the lamp over the recording once, so scrubbing can show what the
## station knew at any moment.
func _build_memory() -> void:
	var room := dive.room
	var rec := dive.rec
	var w := dive.world
	first_seen.resize(room.w * room.h)
	first_seen.fill(1 << 30)
	for k in range(0, rec.ticks, 3):
		var x := rec.rx[k]
		var y := rec.ry[k]
		_remember_around(x, y, k)
		if rec.rflags[k] & 1:
			var ends := w.lamp_ray_ends(x, y, rec.ra[k], rec.gate[k], 9)
			for i in range(0, ends.size(), 2):
				_remember_line(x, y, ends[i], ends[i + 1], k)


## Works out once, from the recording, what Robbie sensed and when: the same rules
## as the sim (World.sensed_from), so the picture never shows what Robbie couldn't know.
func _build_sight() -> void:
	var rec := dive.rec
	var w := dive.world
	var room := dive.room
	var n := rec.bx.size()
	last_sensed.clear()
	var kinds := PackedInt32Array()
	for i in n:
		var arr := PackedInt32Array()
		arr.resize(rec.ticks)
		last_sensed.append(arr)
		kinds.append(w.bodies[i].kind)
	var last := PackedInt32Array()
	last.resize(n)
	last.fill(-1)
	first_sensed.resize(n)
	first_sensed.fill(NEVER)
	plant_found.resize(room.plants.size())
	plant_found.fill(NEVER)
	for k in rec.ticks:
		var x := rec.rx[k]
		var y := rec.ry[k]
		var a := rec.ra[k]
		var lamp := (rec.rflags[k] & 1) == 1
		var g: int = rec.gate[k]
		for i in n:
			var st := rec.bstate[i][k]
			if (st & 1) == 1 and w.sensed_from(x, y, a, lamp, g, rec.bx[i][k], rec.by[i][k], kinds[i], (st >> 1) & 0x7f, (st & 256) != 0):
				last[i] = k
				if first_sensed[i] == NEVER:
					first_sensed[i] = k
			last_sensed[i][k] = last[i]
		if k % 3 == 0:
			for p in room.plants.size():
				if plant_found[p] == NEVER and w.plant_sensed_from(x, y, a, lamp, g, room.plants[p]):
					plant_found[p] = k
	exit_found = NEVER
	for ty in room.h:
		for tx in room.w:
			if room.is_exit(tx, ty):
				exit_found = mini(exit_found, first_seen[ty * room.w + tx])


## A ring that opens once where something was found for the first time.
func _found_ring(pos: Vector2, k: int, found: int, col: Color, size: float) -> void:
	var age := k - found
	if age < 0 or age >= 24:
		return
	var f := float(age) / 24.0
	draw_arc(pos, 3.0 + f * size, 0, TAU, 24, Color(col, 0.8 * (1.0 - f)), 1.0)


func _in_station_memory(tx: int, ty: int) -> bool:
	var room := dive.room
	return station_memory.size() == room.w * room.h and tx >= 0 and ty >= 0 and tx < room.w and ty < room.h \
		and station_memory[ty * room.w + tx] == 1


func _remember_around(x: int, y: int, k: int) -> void:
	var r := World.PROX
	for ty in range((y - r) / Fx.TILE, (y + r) / Fx.TILE + 1):
		for tx in range((x - r) / Fx.TILE, (x + r) / Fx.TILE + 1):
			_mark(tx, ty, k)


func _remember_line(ax: int, ay: int, bx: int, by: int, k: int) -> void:
	var n := maxi(1, Fx.dist(bx - ax, by - ay) / (4 * Fx.ONE))
	for i in n + 1:
		_mark((ax + (bx - ax) * i / n) / Fx.TILE, (ay + (by - ay) * i / n) / Fx.TILE, k)


func _mark(tx: int, ty: int, k: int) -> void:
	var room := dive.room
	if tx < 0 or ty < 0 or tx >= room.w or ty >= room.h:
		return
	var i := ty * room.w + tx
	if first_seen[i] > k:
		first_seen[i] = k


func last_tick() -> int:
	return dive.rec.ticks - 1


func _process(_delta: float) -> void:
	queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if dive == null:
		return
	var rec := dive.rec
	var k := clampi(int(t), 0, last_tick())
	var k2 := mini(k + 1, last_tick())
	var f := t - float(k)
	var now := Time.get_ticks_msec() / 1000.0
	draw_rect(Rect2(0, 0, 640, 360), Color(0.0, 0.01, 0.025))
	_draw_memory(k)
	_draw_ghost()
	var rpos := _lerp_pos(rec.rx, rec.ry, k, k2, f)
	var lamp_on := (rec.rflags[k] & 1) == 1
	if lamp_on:
		_draw_lamp(k, rpos)
		_draw_snow(k, rpos, now)
	_draw_plants(k, now)
	_draw_beacon(k, now)
	_draw_valve(k, now)
	_draw_creatures(k, k2, f, rpos, lamp_on, now)
	_draw_lasers(k)
	_draw_bearing(k, rpos, now)
	_draw_robbie(k, rpos, now)


func _p(x: int, y: int) -> Vector2:
	return Vector2(x, y) / float(Fx.ONE)


func _lerp_pos(xs: PackedInt32Array, ys: PackedInt32Array, k: int, k2: int, f: float) -> Vector2:
	return _p(xs[k], ys[k]).lerp(_p(xs[k2], ys[k2]), f)


## What the station knows of the room at tick k: the chart from earlier Robbies (faint)
## and what this Robbie has seen so far. Rock is drawn rounded (_draw_blobs).
func _draw_memory(k: int) -> void:
	var room := dive.room
	var n := room.w * room.h
	var has_station := station_memory.size() == n
	var chart_water := PackedByteArray()
	var chart_rock := PackedByteArray()
	var chart_exit := PackedByteArray()
	var rock := PackedByteArray()
	var exit_seen := PackedByteArray()
	for arr: PackedByteArray in [chart_water, chart_rock, chart_exit, rock, exit_seen]:
		arr.resize(n)
	for ty in room.h:
		for tx in room.w:
			var i := ty * room.w + tx
			var is_rock := room.tile_at(tx, ty) == Room.Tile.ROCK
			var is_exit := room.is_exit(tx, ty)
			if first_seen[i] <= k:
				if is_rock:
					rock[i] = 1
					chart_rock[i] = 1
				elif is_exit:
					exit_seen[i] = 1
			elif has_station and station_memory[i] == 1:
				if is_rock:
					chart_rock[i] = 1
				elif is_exit:
					chart_exit[i] = 1
				else:
					chart_water[i] = 1
	_draw_blobs(chart_water, C_WATER_CHART)
	_draw_blobs(chart_exit, Color(0.02, 0.07, 0.035))
	_draw_blobs(chart_rock, C_ROCK_CHART)
	_draw_blobs(rock, C_ROCK_MEMORY)
	_draw_blobs(exit_seen, Color(0.03, 0.1, 0.05))


## Tiles drawn as worn shapes instead of squares: a disc per tile, joined to the tiles
## beside and below it by bands. Where tiles meet in a block they fill solid; outer
## corners come out round (half a tile), inner corners stay sharp.
func _draw_blobs(mask: PackedByteArray, col: Color) -> void:
	var room := dive.room
	var w := room.w
	for ty in room.h:
		for tx in w:
			var i := ty * w + tx
			if mask[i] == 0:
				continue
			var cx := tx * 16.0 + 8.0
			var cy := ty * 16.0 + 8.0
			draw_circle(Vector2(cx, cy), 8.0, col)
			if tx + 1 < w and mask[i + 1] == 1:
				draw_rect(Rect2(cx, cy - 8.0, 16.0, 16.0), col)
			if ty + 1 < room.h and mask[i + w] == 1:
				draw_rect(Rect2(cx - 8.0, cy, 16.0, 16.0), col)


## The previous Robbie, swimming its own route alongside this one: its trail so
## far, a faint outline where it is now, and a cross where it was lost.
func _draw_ghost() -> void:
	if ghost.is_empty():
		return
	var path: PackedVector2Array = ghost["path"]
	var step := float(GameState.PATH_STEP)
	var col := Color(0.62, 0.78, 1.0)
	var f := t / step
	var n := mini(int(f) + 1, path.size())
	if n >= 2:
		var trail := path.slice(0, n)
		if n < path.size():
			trail.append(path[n - 1].lerp(path[n], f - float(n - 1)))
		draw_polyline(trail, Color(col, 0.3), 1.0)
	var font := ThemeDB.fallback_font
	var label := "%03d" % int(ghost["serial"])
	if n < path.size():
		var pos := path[n - 1].lerp(path[n], f - float(n - 1))
		draw_arc(pos, 4.5, 0, TAU, 16, Color(col, 0.35), 1.0)
		draw_string(font, pos + Vector2(6, -5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(col, 0.45))
	else:
		var end := path[path.size() - 1]
		if ghost.get("lost", true):
			draw_line(end + Vector2(-3, -3), end + Vector2(3, 3), Color(col, 0.4), 1.0)
			draw_line(end + Vector2(-3, 3), end + Vector2(3, -3), Color(col, 0.4), 1.0)
		draw_string(font, end + Vector2(6, -5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(col, 0.35))


func _draw_lamp(k: int, rpos: Vector2) -> void:
	var rec := dive.rec
	var ends := dive.world.lamp_ray_ends(int(rpos.x * Fx.ONE), int(rpos.y * Fx.ONE), rec.ra[k], rec.gate[k], LAMP_RAYS)
	var pts := PackedVector2Array([rpos])
	var cols := PackedColorArray([Color(C_LAMP, 0.42)])
	var lit_tiles := {}
	for i in range(0, ends.size(), 2):
		var e := _p(ends[i], ends[i + 1])
		pts.append(e)
		var reach := clampf(e.distance_to(rpos) / 96.0, 0.0, 1.0)
		cols.append(Color(C_LAMP, lerpf(0.30, 0.03, reach)))
		lit_tiles[Vector2i(ends[i] / Fx.TILE, ends[i + 1] / Fx.TILE)] = reach
	# Pressed against rock, the rays all stop at once and the cone folds to nothing: skip it.
	if not Geometry2D.triangulate_polygon(pts).is_empty():
		draw_polygon(pts, cols)
	# The glow all around Robbie (World.LAMP_HALO, 48 px): jellyfish inside it see the lamp too.
	for i in 12:
		draw_circle(rpos, 48.0 * (1.0 - i * 0.075), Color(C_LAMP, 0.010 + i * 0.002))
	draw_arc(rpos, 48.0, 0, TAU, 48, Color(C_LAMP, 0.07), 1.0)
	# Rock struck by the light, rounded like the rest of the rock.
	for tile: Vector2i in lit_tiles:
		if dive.room.tile_at(tile.x, tile.y) == Room.Tile.ROCK:
			var reach: float = lit_tiles[tile]
			var col := C_ROCK_LIT.darkened(reach * 0.6)
			var c := Vector2(tile.x * 16 + 8, tile.y * 16 + 8)
			draw_circle(c, 8.0, col)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb := tile + d
				if lit_tiles.has(nb) and dive.room.tile_at(nb.x, nb.y) == Room.Tile.ROCK:
					draw_rect(Rect2(c + Vector2(d) * 8.0 - Vector2(8, 8), Vector2(16, 16)), col)


## Marine snow: specks drifting slowly down through the water, seen only where the lamp
## lights them. Ambience, not part of the sim.
const SNOW := 160

func _draw_snow(k: int, rpos: Vector2, now: float) -> void:
	var ang := dive.rec.ra[k] * TAU / 4096.0
	var fwd := Vector2(sin(ang), -cos(ang))
	for j in SNOW:
		var vx := sin(j * 1.7) * 1.5
		var vy := 2.0 + float(j % 5) * 0.6
		var p := Vector2(fposmod(float((j * 7919) % 640) + vx * now + sin(now * 0.7 + j) * 2.0, 640.0),
			fposmod(float((j * 104729) % 360) + vy * now, 360.0))
		var off := p - rpos
		if absf(off.x) > 96.0 or absf(off.y) > 96.0:
			continue
		var d := off.length()
		var lit := 0.0
		if d < 48.0:
			lit = 1.0 - d / 48.0
		if d < 96.0 and fwd.dot(off) > 0.82 * d:   # inside the beam
			lit = maxf(lit, 1.0 - d / 96.0)
		if lit <= 0.02 or dive.room.tile_at(int(p.x) / 16, int(p.y) / 16) == Room.Tile.ROCK:
			continue
		draw_circle(p, 0.55 + float(j % 3) * 0.25, Color(1.0, 0.95, 0.85, 0.55 * lit))


func _glow(pos: Vector2, col: Color, radius: float, strength: float) -> void:
	for i in 4:
		var r := radius * (1.0 - i * 0.22)
		draw_circle(pos, r, Color(col, strength * (0.06 + i * 0.05)))


## Glowing plants: hidden until Robbie senses one, then on the chart for good. Plants
## an earlier Robbie found show as faint dots.
func _draw_plants(k: int, now: float) -> void:
	var plants := dive.room.plants
	for i in plants.size():
		var p := plants[i]
		var pos := Vector2(p.x * 16 + 8, p.y * 16 + 8)
		if i < plant_found.size() and plant_found[i] <= k:
			var pulse := 0.75 + 0.25 * sin(now * 1.3 + p.x)
			var fresh := clampf(float(k - plant_found[i]) / 20.0, 0.0, 1.0)   # brightens as it's found
			_glow(pos, C_PLANT, 14.0 * pulse * (0.5 + 0.5 * fresh), 0.8)
			_draw_anemone(pos, now, p.x * 7 + p.y * 3, 0.5 + 0.5 * fresh)
			_found_ring(pos, k, plant_found[i], C_PLANT, 10.0)
		elif _in_station_memory(p.x, p.y):
			_draw_anemone(pos, 0.0, p.x * 7 + p.y * 3, 0.25)


## A glowing plant seen from above: a little anemone, fronds swaying, a bright bead on
## each tip.
func _draw_anemone(pos: Vector2, now: float, seed_v: int, strength: float) -> void:
	for f in 6:
		var ang := TAU * f / 6.0 + seed_v * 0.37 + sin(now * 1.2 + seed_v + f * 1.1) * 0.18
		var reach := 5.5 + float((seed_v + f) % 3)
		var bend := sin(now * 1.6 + f + seed_v) * 0.35
		var a := pos + Vector2(cos(ang), sin(ang)) * reach * 0.5
		var tip := pos + Vector2(cos(ang + bend), sin(ang + bend)) * reach
		draw_polyline(PackedVector2Array([pos, a, tip]), Color(C_PLANT.darkened(0.35), 0.8 * strength), 1.1)
		draw_circle(tip, 1.1, Color(C_PLANT, strength))
	draw_circle(pos, 1.8, Color(C_PLANT.lightened(0.3), strength))


## The exit's beacon: drawn once Robbie has seen the exit (or faintly, if an earlier
## Robbie did). Until then only the bearing tick beside Robbie points the way.
func _draw_beacon(k: int, now: float) -> void:
	var room := dive.room
	var c := _p(room.exit_cx, room.exit_cy)
	if exit_found <= k:
		var ping := fmod(now, 1.6) / 1.6
		draw_arc(c, 5.0 + ping * 22.0, 0, TAU, 32, Color(C_BEACON, 0.6 * (1.0 - ping)), 1.0)
		var ping2 := fmod(now + 0.8, 1.6) / 1.6
		draw_arc(c, 5.0 + ping2 * 22.0, 0, TAU, 32, Color(C_BEACON, 0.3 * (1.0 - ping2)), 1.0)
		# The beacon itself: a little six-sided buoy with a lamp that flashes with each ping.
		var hexa := PackedVector2Array()
		for s2 in 7:
			hexa.append(c + Vector2.from_angle(TAU * s2 / 6.0 + PI / 6.0) * 4.2)
		draw_colored_polygon(hexa.slice(0, 6), Color(0.1, 0.28, 0.16))
		draw_polyline(hexa, C_BEACON, 1.0)
		var flash := ping < 0.15
		draw_circle(c, 1.8 if flash else 1.3, C_BEACON.lightened(0.5) if flash else C_BEACON.darkened(0.2))
		_found_ring(c, k, exit_found, C_BEACON, 30.0)
	elif _in_station_memory(room.exit_cx / Fx.TILE, room.exit_cy / Fx.TILE):
		draw_arc(c, 5.0, 0, TAU, 24, Color(C_BEACON, 0.22), 1.0)
		draw_circle(c, 1.5, Color(C_BEACON, 0.35))


## Robbie's radio always knows which way the beacon is, never how far: a small green
## tick beside Robbie, pulsing with the beacon's ping.
func _draw_bearing(k: int, rpos: Vector2, now: float) -> void:
	if dive.rec.rhp[k] <= 0:
		return
	var c := _p(dive.room.exit_cx, dive.room.exit_cy)
	if c.distance_to(rpos) < 14.0:
		return
	var dir := (c - rpos).normalized()
	var side := Vector2(-dir.y, dir.x)
	var ping := fmod(now, 1.6) / 1.6
	var a := 0.85 - 0.45 * ping
	var base := rpos + dir * 11.0
	draw_colored_polygon(PackedVector2Array([base + dir * 4.5, base + side * 2.6, base + dir * 1.2, base - side * 2.6]),
		Color(C_BEACON, a))
	draw_arc(rpos, 11.0, dir.angle() - 0.35, dir.angle() + 0.35, 8, Color(C_BEACON, a * 0.4), 1.0)


func _draw_valve(k: int, now: float) -> void:
	var room := dive.room
	if room.gate_tiles.is_empty():
		return
	var state: int = dive.rec.gate[k]
	for gt in room.gate_tiles:
		var seen := first_seen[gt.y * room.w + gt.x] <= k
		if not seen and not _in_station_memory(gt.x, gt.y):
			continue   # not found yet
		var a := 1.0 if seen else 0.25
		var r := Rect2(gt.x * 16, gt.y * 16, 16, 16)
		match state:
			World.GateState.OPEN:
				draw_rect(Rect2(r.position.x, r.position.y, 2, 16), Color(C_VALVE, 0.5 * a))
				draw_rect(Rect2(r.position.x + 14, r.position.y, 2, 16), Color(C_VALVE, 0.5 * a))
			World.GateState.CLOSING:
				var j := sin(now * 40.0) * 1.0
				var wdt := 4.0 + 3.0 * sin(now * 6.0) + 3.0
				draw_rect(Rect2(r.position.x + j, r.position.y, wdt, 16), Color(C_VALVE, 0.7 * a))
				draw_rect(Rect2(r.position.x + 16 - wdt - j, r.position.y, wdt, 16), Color(C_VALVE, 0.7 * a))
			World.GateState.CLOSED:
				draw_rect(r, Color(C_VALVE, 0.85 * a))
				draw_line(r.position + Vector2(8, 0), r.position + Vector2(8, 16), Color(0.3, 0.1, 0.0, a), 1.0)


func _draw_creatures(k: int, k2: int, f: float, rpos: Vector2, lamp_on: bool, now: float) -> void:
	var rec := dive.rec
	for i in rec.bx.size():
		var st := rec.bstate[i][k]
		if (st & 1) == 0:
			continue
		var pos := _lerp_pos(rec.bx[i], rec.by[i], k, k2, f)
		var state := (st >> 1) & 0x7f
		var kind := dive.world.bodies[i].kind
		var ls := last_sensed[i][k] if i < last_sensed.size() else k
		var sensed := ls >= 0 and k - ls <= SENSE_HOLD
		if kind == Body.Kind.LURKER:
			_draw_lurker(k, pos, rpos, state, lamp_on, now, sensed)
			if not sensed:
				_draw_lost_track(i, k, ls, C_LURKER)
			continue
		if not sensed:
			_draw_lost_track(i, k, ls, C_JELLY if kind == Body.Kind.JELLYFISH else C_EEL)
			continue
		if i < first_sensed.size():
			_found_ring(pos, k, first_sensed[i], C_JELLY if kind == Body.Kind.JELLYFISH else C_EEL, 10.0)
		match kind:
			Body.Kind.JELLYFISH:
				_draw_jelly(i, k, f, state, now)
			Body.Kind.EEL:
				_draw_eel(i, k, pos, state, now)
	# Strike flashes.
	for e in dive.world.events:
		if e["type"] == "lurker_strikes" and k >= e["t"] and k < e["t"] + 8:
			var b: int = e["src"]
			var pos := _p(rec.bx[b][e["t"]], rec.by[b][e["t"]])
			draw_arc(pos, 10.0 + (k - e["t"]) * 4.0, 0, TAU, 24, Color(C_LURKER, 1.0 - (k - e["t"]) / 8.0), 2.0)


## A lurker. Awake (winding up): wide glowing eyes and a pulsing ring, the moment Robbie
## can sense it. Resting after a strike: half-shut eyes. Asleep: camouflaged, but when the
## lamp's beam falls on it the player sees a lumpy shape with closed eyes. Robbie itself
## still can't sense it then (that's the point of camouflage); the hints and manual say so.
## Otherwise it isn't drawn at all.
func _draw_lurker(k: int, pos: Vector2, rpos: Vector2, state: int, lamp_on: bool, now: float, sensed: bool) -> void:
	var lit := false
	if lamp_on and pos.distance_to(rpos) < 48.0:   # inside the lamp's halo (World.LAMP_HALO)
		lit = true
	elif lamp_on and pos.distance_to(rpos) < 96.0:   # or ahead, in the beam
		var ang := dive.rec.ra[k] * TAU / 4096.0
		var fwd := Vector2(sin(ang), -cos(ang))
		lit = absf(fwd.angle_to(pos - rpos)) < 0.62
	if not sensed and not lit:
		return
	if state == 1 and sensed:
		var pulse := 0.5 + 0.5 * sin(now * 18.0)
		_glow(pos, C_LURKER, 16.0, 1.0)
		draw_arc(pos, 9.0 + pulse * 3.0, 0, TAU, 24, Color(C_LURKER, 0.7), 1.5)
		# The rock it was pretending to be, now very much awake.
		var lump := PackedVector2Array()
		for s3 in 12:
			var t3 := s3 * TAU / 12.0
			lump.append(pos + Vector2(cos(t3), sin(t3)) * (6.8 + sin(t3 * 3.0 + 1.3) * 0.9 + pulse * 0.4))
		draw_colored_polygon(lump, Color(0.42, 0.26, 0.38))
		lump.append(lump[0])
		draw_polyline(lump, Color(C_LURKER, 0.9), 1.0)
		var look := (rpos - pos).normalized() * 0.6   # it looks at Robbie
		for ex: float in [-2.3, 2.3]:
			draw_circle(pos + Vector2(ex, -1.0), 1.8, Color(1, 0.92, 1))
			draw_circle(pos + Vector2(ex, -1.0) + look, 0.8, Color(0.3, 0, 0.2))
		var teeth := PackedVector2Array()
		for t4 in 7:
			teeth.append(pos + Vector2(-3.0 + t4, 2.4 + (0.9 if t4 % 2 == 0 else 0.0)))
		draw_polyline(teeth, Color(1, 0.9, 1, 0.9), 0.8)
	elif state == 2:
		draw_circle(pos, 6.0, Color(0.25, 0.2, 0.26, 0.5))
		draw_line(pos + Vector2(-3.2, 0), pos + Vector2(-1.2, 0), Color(C_LURKER, 0.6), 1.0)
		draw_line(pos + Vector2(1.2, 0), pos + Vector2(3.2, 0), Color(C_LURKER, 0.6), 1.0)
	elif lit:
		var reach := clampf(pos.distance_to(rpos) / 96.0, 0.0, 1.0)
		var a := lerpf(0.9, 0.35, reach)
		# A lump in the rock that isn't quite rock: a bumpy outline and two closed eyes.
		var pts := PackedVector2Array()
		for s in 12:
			var t := s * TAU / 12.0
			var r := 6.5 + sin(t * 3.0 + 1.3) * 0.9
			pts.append(pos + Vector2(cos(t), sin(t)) * r)
		draw_colored_polygon(pts, Color(0.36, 0.3, 0.36, a * 0.8))
		pts.append(pts[0])
		draw_polyline(pts, Color(0.62, 0.52, 0.6, a), 1.0)
		draw_arc(pos + Vector2(-2.3, 0.3), 1.4, 0.2, PI - 0.2, 6, Color(0.95, 0.8, 0.95, a), 1.0)
		draw_arc(pos + Vector2(2.3, 0.3), 1.4, 0.2, PI - 0.2, 6, Color(0.95, 0.8, 0.95, a), 1.0)


## Average recorded position of body i over ticks k-r..k+r, eased between k and k+1.
## View only: it rounds off the sim's step changes of heading into curves.
func _smooth_pos(i: int, k: int, f: float, r: int) -> Vector2:
	var a := _avg_pos(i, k, r)
	return a.lerp(_avg_pos(i, mini(k + 1, last_tick()), r), f)


func _avg_pos(i: int, k: int, r: int) -> Vector2:
	var rec := dive.rec
	var sx := 0
	var sy := 0
	var n := 0
	for j in range(maxi(0, k - r), mini(last_tick(), k + r) + 1):
		sx += rec.bx[i][j]
		sy += rec.by[i][j]
		n += 1
	return Vector2(sx, sy) / float(n * Fx.ONE)


## A jellyfish: a pulsing bell with two dot eyes, swimming bell-first, its tentacles
## swaying behind it. It darts pink when the lamp draws it. Drawn along a smoothed path.
func _draw_jelly(i: int, k: int, f: float, state: int, now: float) -> void:
	var pos := _smooth_pos(i, k, f, 6)
	var travel := _avg_pos(i, mini(k + 6, last_tick()), 6) - _avg_pos(i, maxi(k - 6, 0), 6)
	# Bell-first when swimming; when it barely moves it floats bell-up.
	var moving := clampf(travel.length() / 6.0, 0.0, 1.0)
	var up := Vector2(0, -1)
	if travel.length() > 0.01:
		up = (travel.normalized() * moving + Vector2(0, -1) * (1.0 - moving)).normalized()
	var side := Vector2(-up.y, up.x)
	var darting := state == 1
	var col := C_JELLY_LIT if darting else C_JELLY
	var beat := sin(now * (8.0 if darting else 3.0) + i * 1.7)
	var w := 3.7 + 0.5 * beat
	var h := 3.3 - 0.5 * beat
	_glow(pos, col, 11.0, 0.9)
	for t in 4:
		var base := pos + side * ((t - 1.5) * w * 0.42) - up * 0.4
		var strand := PackedVector2Array([base])
		for seg in range(1, 5):
			var sway := sin(now * 4.0 + i + t * 1.3 - seg * 0.9) * (0.3 + seg * 0.35)
			strand.append(base - up * (seg * 1.5 + 0.4 * beat) + side * sway)
		draw_polyline(strand, Color(col, 0.55), 1.0)
	var bell := PackedVector2Array()
	for s2 in 11:
		var a := PI * s2 / 10.0
		bell.append(pos + side * (cos(a) * w) + up * (sin(a) * h))
	draw_colored_polygon(bell, Color(col, 0.85))
	draw_polyline(bell, Color(col.lightened(0.4), 0.9), 0.8)
	var eye_y := up * (h * 0.4)
	draw_circle(pos + eye_y + side * 1.25, 0.6, Color(0.04, 0.08, 0.16))
	draw_circle(pos + eye_y - side * 1.25, 0.6, Color(0.04, 0.08, 0.16))
	draw_circle(pos + up * (h * 0.78) - side * (w * 0.35), 0.55, Color(1, 1, 1, 0.65))


## Where Robbie lost track of a creature: a faint ring at the spot it was last sensed,
## fading. It doesn't follow the creature: Robbie doesn't know where it went.
func _draw_lost_track(i: int, k: int, ls: int, col: Color) -> void:
	if ls < 0 or k - ls >= FADE_TICKS + SENSE_HOLD:
		return
	var fade := 1.0 - float(k - ls - SENSE_HOLD) / FADE_TICKS
	var at := _p(dive.rec.bx[i][ls], dive.rec.by[i][ls])
	draw_arc(at, 4.0 + (1.0 - fade) * 3.0, 0, TAU, 16, Color(col, 0.35 * fade), 1.0)


## An eel: a glowing striped body trailing behind its head. Pale while it patrols,
## red-eyed while it lunges at a sound, dim while it swims back to its shaft.
func _draw_eel(i: int, k: int, pos: Vector2, state: int, now: float) -> void:
	var rec := dive.rec
	var back_k := maxi(k - 4, 0)
	var dir := pos - _p(rec.bx[i][back_k], rec.by[i][back_k])
	if dir.length() < 0.5:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var side := Vector2(-dir.y, dir.x)
	var col := C_EEL
	var strength := 0.8
	if state == 1:
		col = Color(1.0, 0.45, 0.3)
		strength = 1.0
	elif state == 2:
		strength = 0.45
	_glow(pos, col, 10.0, strength * 0.55)
	# A tapering body along a wavy spine, head first.
	var spine := PackedVector2Array()
	var speed := 11.0 if state == 1 else 6.0
	for s2 in 9:
		var wave := sin(now * speed - s2 * 0.85 + i) * (0.3 + s2 * 0.32)
		spine.append(pos - dir * (s2 * 2.0) + side * wave)
	# Drawn as overlapping discs, outline first: a body polygon can fold over itself as it waves.
	for pass_i in 2:
		for s2 in range(spine.size() - 1, -1, -1):
			var w := lerpf(2.4, 0.5, float(s2) / (spine.size() - 1))
			if pass_i == 0:
				draw_circle(spine[s2], w + 0.6, Color(col, 0.9 * strength))
			else:
				draw_circle(spine[s2], w, Color(col.darkened(0.35), strength))
	for s2 in [2, 4, 6]:   # the glowing stripes that give it away
		var a := spine[s2 - 1]
		var b := spine[s2 + 1]
		var nrm := (a - b).normalized().orthogonal()
		var w := lerpf(2.4, 0.4, float(s2) / (spine.size() - 1))
		draw_line(spine[s2] + nrm * w, spine[s2] - nrm * w, Color(1, 1, 0.8, 0.85 * strength), 1.0)
	# Blind: its eyes are closed, two little curves. Lunging, its mouth opens.
	var eye_c := Color(0.1, 0.18, 0.05, strength)
	draw_arc(pos + dir * 0.3 + side * 1.0, 0.7, dir.angle() - 0.2, dir.angle() + PI + 0.2, 5, eye_c, 0.7)
	draw_arc(pos + dir * 0.3 - side * 1.0, 0.7, dir.angle() - 0.2, dir.angle() + PI + 0.2, 5, eye_c, 0.7)
	if state == 1:
		draw_colored_polygon(PackedVector2Array([pos + dir * 1.4, pos + dir * 3.0 + side * 1.4, pos + dir * 3.0 - side * 1.4]),
			Color(0.35, 0.05, 0.05))
		# Listening: arcs ahead of it, towards the sound.
		var ping := fmod(now * 3.0, 1.0)
		draw_arc(pos + dir * 2.0, 4.0 + ping * 5.0, dir.angle() - 0.6, dir.angle() + 0.6, 8, Color(col, 0.6 * (1.0 - ping)), 1.0)


func _draw_lasers(k: int) -> void:
	var rec := dive.rec
	for e in dive.world.events:
		if e["type"] == "laser" and k >= e["t"] and k < e["t"] + World.LASER_COMMIT:
			var b: int = e["target"]
			var a := _p(rec.rx[e["t"]], rec.ry[e["t"]])
			var z := _p(rec.bx[b][e["t"]], rec.by[b][e["t"]])
			var fade := 1.0 - float(k - e["t"]) / World.LASER_COMMIT
			draw_line(a, z, Color(1, 0.3, 0.25, fade), 2.0)
			draw_line(a, z, Color(1, 0.9, 0.8, fade), 1.0)
			if e.get("bounced", false):
				# Glancing off armoured rock: sparks scattering back towards Robbie.
				var back := (a - z).normalized()
				var age := float(k - e["t"])
				for s in 7:
					var dir := back.rotated((s - 3) * 0.45 + sin(s * 12.9898) * 0.2)
					var p0 := z + dir * (2.0 + age * 1.2)
					draw_line(p0, p0 + dir * 3.0, Color(1, 0.85, 0.5, fade), 1.0)


func _draw_robbie(k: int, pos: Vector2, now: float) -> void:
	var rec := dive.rec
	var ang := rec.ra[k] * TAU / 4096.0
	var fwd := Vector2(sin(ang), -cos(ang))
	var side := Vector2(-fwd.y, fwd.x)
	var flags := rec.rflags[k]
	var hurt := (flags & 8) != 0 and int(now * 12.0) % 2 == 0
	var body := Color(1, 0.3, 0.25) if hurt else C_ROBBIE
	if rec.rhp[k] <= 0:
		_draw_end_burst(k, pos)
		return
	var moving := (flags & 2) != 0
	if moving:
		for b in 3:
			var off := fmod(now * 2.0 + b * 0.33, 1.0)
			draw_circle(pos - fwd * (6.5 + off * 8.0) + side * sin(now * 7.0 + b) * 1.5, 0.8 + off, Color(0.7, 0.85, 1.0, 0.5 * (1.0 - off)))
	# Two little fins at the back, paddling while it swims.
	var flap := sin(now * 16.0) * 0.9 if moving else 0.0
	for sgn: float in [-1.0, 1.0]:
		var root := pos - fwd * 3.2 + side * sgn * 2.6
		draw_colored_polygon(PackedVector2Array([root, root - fwd * 3.2 + side * sgn * (2.0 + flap), root - fwd * 0.6 + side * sgn * 0.4]),
			body.darkened(0.25))
	# A round body, a little longer in front.
	var hull := PackedVector2Array()
	for s2 in 18:
		var a := TAU * s2 / 18.0
		var along := cos(a) * (6.0 if cos(a) > 0.0 else 4.8)
		hull.append(pos + fwd * along + side * (sin(a) * 4.3))
	draw_colored_polygon(hull, body)
	hull.append(hull[0])
	draw_polyline(hull, body.darkened(0.4), 0.8)
	# One big porthole eye with a glint.
	var eye := pos + fwd * 1.8
	draw_circle(eye, 2.4, Color(0.10, 0.17, 0.26))
	draw_arc(eye, 2.4, 0, TAU, 16, body.darkened(0.5), 0.8)
	draw_circle(eye + fwd * 0.7 + side * 0.8, 0.75, Color(0.9, 0.97, 1.0))
	# The radio antenna, its tip blinking with the transmitter.
	var ant := pos - fwd * 2.8 - side * 2.2
	draw_line(pos - fwd * 1.5 - side * 1.2, ant, body.darkened(0.45), 0.8)
	var blink := fmod(now, 1.2) < 0.18
	draw_circle(ant, 0.8, Color(1.0, 0.35, 0.3) if blink else body.darkened(0.3))
	draw_circle(pos + fwd * 6.1, 1.0, Color(1, 1, 0.85) if (flags & 1) else Color(0.4, 0.38, 0.3))


func _draw_end_burst(k: int, pos: Vector2) -> void:
	var age := float(k - _end_tick())
	draw_circle(pos, 6.0 + age, Color(1, 0.9, 0.6, 0.8))
	draw_line(pos, Vector2(pos.x, 0), Color(1, 0.95, 0.8, 0.9), 2.0)   # the transmission burst


func _end_tick() -> int:
	return last_tick()
