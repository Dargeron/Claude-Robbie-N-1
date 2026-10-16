class_name DiveView
extends Node2D
## Draws one moment of a recorded dive the way Robbie's camera saw it: black
## water, the lamp's cone (computed with the sim's own rays), glowing life,
## the beacon, and the station's memory of what earlier moments revealed.
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
const LAMP_RAYS := 33

var dive: Dive
var t := 0.0                         # playback position in ticks (fractional)
var first_seen := PackedInt32Array() # tick at which each tile entered this dive's memory
var station_memory := PackedByteArray()  # tiles any Robbie in this room has ever seen


func setup(d: Dive) -> void:
	dive = d
	_build_memory()
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
	var rpos := _lerp_pos(rec.rx, rec.ry, k, k2, f)
	var lamp_on := (rec.rflags[k] & 1) == 1
	if lamp_on:
		_draw_lamp(k, rpos)
	_draw_plants(now)
	_draw_beacon(now)
	_draw_valve(k, now)
	_draw_creatures(k, k2, f, rpos, lamp_on, now)
	_draw_lasers(k)
	_draw_robbie(k, rpos, now)


func _p(x: int, y: int) -> Vector2:
	return Vector2(x, y) / float(Fx.ONE)


func _lerp_pos(xs: PackedInt32Array, ys: PackedInt32Array, k: int, k2: int, f: float) -> Vector2:
	return _p(xs[k], ys[k]).lerp(_p(xs[k2], ys[k2]), f)


func _draw_memory(k: int) -> void:
	var room := dive.room
	var has_station := station_memory.size() == room.w * room.h
	for ty in room.h:
		for tx in room.w:
			if first_seen[ty * room.w + tx] > k:
				# Not seen by this Robbie yet: the station's chart, very faint.
				if has_station and station_memory[ty * room.w + tx] == 1:
					var t2 := room.tile_at(tx, ty)
					if t2 == Room.Tile.ROCK:
						draw_rect(Rect2(tx * 16, ty * 16, 16, 16), C_ROCK_CHART)
					elif room.is_exit(tx, ty):
						draw_rect(Rect2(tx * 16, ty * 16, 16, 16), Color(0.02, 0.07, 0.035))
					else:
						draw_rect(Rect2(tx * 16, ty * 16, 16, 16), C_WATER_CHART)
				continue
			var tile := room.tile_at(tx, ty)
			if tile == Room.Tile.ROCK:
				draw_rect(Rect2(tx * 16, ty * 16, 16, 16), C_ROCK_MEMORY)
			elif room.is_exit(tx, ty):
				draw_rect(Rect2(tx * 16, ty * 16, 16, 16), Color(0.03, 0.1, 0.05))


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
	draw_polygon(pts, cols)
	# Rock struck by the light.
	for tile: Vector2i in lit_tiles:
		if dive.room.tile_at(tile.x, tile.y) == Room.Tile.ROCK:
			var reach: float = lit_tiles[tile]
			draw_rect(Rect2(tile.x * 16, tile.y * 16, 16, 16), C_ROCK_LIT.darkened(reach * 0.6))


func _glow(pos: Vector2, col: Color, radius: float, strength: float) -> void:
	for i in 4:
		var r := radius * (1.0 - i * 0.22)
		draw_circle(pos, r, Color(col, strength * (0.06 + i * 0.05)))


func _draw_plants(now: float) -> void:
	for p in dive.room.plants:
		var pos := Vector2(p.x * 16 + 8, p.y * 16 + 8)
		var pulse := 0.75 + 0.25 * sin(now * 1.3 + p.x)
		_glow(pos, C_PLANT, 14.0 * pulse, 0.8)
		draw_circle(pos, 1.5, C_PLANT)


func _draw_beacon(now: float) -> void:
	var c := _p(dive.room.exit_cx, dive.room.exit_cy)
	var ping := fmod(now, 1.6) / 1.6
	draw_arc(c, 4.0 + ping * 22.0, 0, TAU, 32, Color(C_BEACON, 0.6 * (1.0 - ping)), 1.0)
	draw_circle(c, 2.0, C_BEACON)


func _draw_valve(k: int, now: float) -> void:
	var room := dive.room
	if room.gate_tiles.is_empty():
		return
	var state: int = dive.rec.gate[k]
	for gt in room.gate_tiles:
		var seen := first_seen[gt.y * room.w + gt.x] <= k
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
		match dive.world.bodies[i].kind:
			Body.Kind.JELLYFISH:
				var near := pos.distance_to(rpos) <= 64.0
				var darting := state == 1
				var col := C_JELLY_LIT if darting else C_JELLY
				var strength := 1.0 if (near or darting) else 0.35
				var pulse := 0.8 + 0.2 * sin(now * 3.0 + i)
				_glow(pos, col, 10.0 * pulse, strength)
				draw_circle(pos, 3.0, Color(col, 0.9 * strength))
				for tnt in 3:
					var sway := sin(now * 4.0 + i + tnt) * 1.5
					var base := pos + Vector2(-2 + tnt * 2, 2)
					draw_line(base, base + Vector2(sway, 4), Color(col, 0.6 * strength), 1.0)
			Body.Kind.LURKER:
				if state == 1:
					_glow(pos, C_LURKER, 16.0, 1.0)
					draw_circle(pos + Vector2(-2, 0), 1.2, Color(1, 0.9, 1))
					draw_circle(pos + Vector2(2, 0), 1.2, Color(1, 0.9, 1))
				elif state == 2:
					draw_circle(pos + Vector2(-2, 0), 0.8, Color(C_LURKER, 0.4))
					draw_circle(pos + Vector2(2, 0), 0.8, Color(C_LURKER, 0.4))
				elif lamp_on and pos.distance_to(rpos) < 96.0:
					draw_circle(pos, 5.0, Color(0.2, 0.18, 0.2, 0.35))   # a shape in the rock, barely
	# Strike flashes.
	for e in dive.world.events:
		if e["type"] == "lurker_strikes" and k >= e["t"] and k < e["t"] + 8:
			var b: int = e["src"]
			var pos := _p(rec.bx[b][e["t"]], rec.by[b][e["t"]])
			draw_arc(pos, 10.0 + (k - e["t"]) * 4.0, 0, TAU, 24, Color(C_LURKER, 1.0 - (k - e["t"]) / 8.0), 2.0)


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
	if flags & 2:
		for b in 3:
			var off := fmod(now * 2.0 + b * 0.33, 1.0)
			draw_circle(pos - fwd * (6.0 + off * 8.0) + side * sin(now * 7.0 + b) * 1.5, 0.8 + off, Color(0.7, 0.85, 1.0, 0.5 * (1.0 - off)))
	var hull := PackedVector2Array([pos + fwd * 6.5, pos + side * 4.0 + fwd * 1.0, pos - fwd * 5.0 + side * 3.0,
		pos - fwd * 5.0 - side * 3.0, pos - side * 4.0 + fwd * 1.0])
	draw_colored_polygon(hull, body)
	draw_circle(pos + fwd * 2.5, 1.6, Color(0.15, 0.25, 0.35))
	draw_circle(pos + fwd * 6.0, 1.0, Color(1, 1, 0.85))


func _draw_end_burst(k: int, pos: Vector2) -> void:
	var age := float(k - _end_tick())
	draw_circle(pos, 6.0 + age, Color(1, 0.9, 0.6, 0.8))
	draw_line(pos, Vector2(pos.x, 0), Color(1, 0.95, 0.8, 0.9), 2.0)   # the transmission burst


func _end_tick() -> int:
	return last_tick()
