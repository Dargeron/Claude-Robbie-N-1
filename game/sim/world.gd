class_name World
extends RefCounted
## The deterministic simulation of one dive. Pure integer maths; no nodes, no
## rendering, no engine randomness. Same room + program + seed = same dive.
##
## Tick order (never change casually; golden replays depend on it):
##   1. the VM thinks (every THINK_EVERY ticks, unless Robbie is committed)
##   2. apply()  -> Robbie's current action
##   3. step():  valve, Robbie moves, creatures act, energy drains,
##               the explored map updates, end conditions, timers

enum Result { RUNNING, EXIT, DESTROYED, ENERGY, TIMEOUT }
enum GateState { OPEN, CLOSING, CLOSED }
enum Act { IDLE, MOVE, STOP, SHOOT, FLARE }

const THINK_EVERY := 3
const HASH_EVERY := 30
const MAX_TICKS := 9000
const TICKS_PER_SECOND := 30

# Robbie, prototype loadout
const R_RADIUS := 5 * 256
const R_SPEED := 256            # 1 px per tick
const R_TURN := 68              # ~6 degrees per tick
const R_REVERSE := 192          # 0.75 px per tick when backing away
const R_HP := 3
const LAMP_RANGE := 96 * 256
const LAMP_HALF := 398          # ~35 degrees either side
const PROX := 20 * 256          # pressure sense: anything this close is felt
const LASER_RANGE := 96 * 256
const LASER_COST := 200
const LASER_COMMIT := 6
const LASER_COOLDOWN := 30
const INVULN := 30
const VALVE_INVULN := 10         # the shut valve stings three times a second
const DRAIN_BASE := 1
const DRAIN_MOVE := 1
const WALL_AHEAD := 16 * 256    # look-ahead beyond the hull for "wall ahead"
const RAY_STEP := 2 * 256
const PLANT_GLOW := 40 * 256
const LURE_GLOW := 56 * 256       # the cold lights: seen by their own glow this far, past rock no
const LURE_REACH := 9 * 256       # ...and they go out when Robbie comes this close
const BONUS_REACH := 10 * 256     # a lost beacon is recovered when Robbie comes this close
const BONUS_GLOW := 32 * 256      # ...and it pings faintly: sensed (and "light") within two tiles
const FLARE_TICKS := 300          # a flare burns for ten seconds
const FLARE_PULL := 64 * 256      # jellyfish this close to a burning flare go to it
const HEARD_RANGE := 128 * 256    # the hydrophone hears eels and shellbacks 8 tiles off, through rock
const STUCK_TICKS := 60           # "stuck": got nowhere in two seconds...
const STUCK_PX := 6 * 256         # ...nowhere meaning less than this
const HIT_TICKS := 60             # "hit": hurt in the last two seconds
const TURN_HOLD := 16             # a quarter turn takes about half a second, without thinking

# Jellyfish
const J_RADIUS := 4 * 256
const J_GLOW := 48 * 256
const J_DRIFT := 64             # 0.25 px per tick
const J_CHASE := 282            # 1.1 px per tick: lit jellyfish dart at the lamp
const J_STING_COOLDOWN := 30
const LAMP_HALO := 48 * 256     # a lit lamp glows all around Robbie, not just ahead

# Lurker
const L_RADIUS := 6 * 256
const L_TRIGGER := 34 * 256
const L_REACH := 38 * 256
const L_GLOW := 40 * 256
const L_COOLDOWN := 120
const L_DAMAGE := 3

# Eel, "the listener": patrols a shaft, blind, and hunts by the sound of a moving Robbie
const E_RADIUS := 5 * 256
const E_GLOW := 64 * 256        # its stripes glow: sensed within 4 tiles in any light
const E_PATROL := 230           # 0.9 px per tick: faster than Robbie can back away
const E_HEAR := 48 * 256        # hears a moving Robbie within 3 tiles
const E_LUNGE := 384            # 1.5 px per tick
const E_LUNGE_TICKS := 75
const E_REST := 90
const E_DAMAGE := 2

# Shellback: a slow armoured grazer. Harmless unless shot: the laser glances off its shell and
# it comes for him. (The scope shows it yellow, and red while it is angry.)
const K_RADIUS := 8 * 256
const K_GLOW := 40 * 256         # its shell has a faint sheen: sensed within 2.5 tiles
const K_CRAWL := 77              # 0.3 px per tick
const K_CHARGE := 307            # 1.2 px per tick: faster than Robbie
const K_RAGE := 240              # angry for eight seconds
const K_DAMAGE := 2
const K_LEASH := 48 * 256        # it grazes within three tiles of where it lives

var room: Room
var kit: Kit
var seed_value := 0
var calm := false
var tick := 0
var robbie: Body
var bodies: Array[Body] = []
var energy := 0
var energy_max := 0
var lamp_on := true
var invuln := 0
var commit := 0
var laser_cd := 0
var act := Act.IDLE
var act_heading := 0
var act_face := -1             # >= 0: keep facing this way while moving (backing off)
var act_rule := -1
var moving := false
var result := Result.RUNNING
var cause := ""
var events: Array[Dictionary] = []
var seen := PackedByteArray()
var seen_count := 0
var gate_phase := 0
var gate_open_t := 75
var gate_closing_t := 45
var gate_closed_t := 105
var gate_state := GateState.OPEN
var last_laser_target := -1
var lure_out := PackedByteArray()  # per cold light: 1 once Robbie has reached it and it went dark
var lure_seen := PackedByteArray()
var bonus_taken := PackedByteArray()  # per lost beacon: 1 once Robbie has recovered it
var bonus_seen := PackedByteArray()
var flares_left := 0
var flare_x: Array[int] = []           # flares dropped, where, and when (they burn FLARE_TICKS)
var flare_y: Array[int] = []
var flare_t: Array[int] = []
var hold := 0                          # ticks Robbie keeps his order without thinking (a turn)
var reserve_used := false
var last_hit := -1
var _trail_x: Array[int] = []          # where Robbie was every 30 ticks (for "stuck")
var _trail_y: Array[int] = []


func _init(r: Room, seed_v: int, calm_v: bool = false, kit_v: Kit = null) -> void:
	room = r
	kit = kit_v if kit_v != null else Kit.stock()
	seed_value = seed_v
	calm = calm_v
	var eff_seed := 0 if calm else seed_v
	var vr := Rng.new(eff_seed, 1)

	robbie = Body.new()
	robbie.kind = Body.Kind.ROBBIE
	robbie.index = -1
	robbie.x = room.start_tx * Fx.TILE + Fx.TILE / 2
	robbie.y = room.start_ty * Fx.TILE + Fx.TILE / 2
	robbie.angle = Fx.from_deg(room.start_heading_deg)
	robbie.radius = R_RADIUS
	robbie.hp = kit.hp
	energy = room.energy * kit.energy_pct / 100
	energy_max = energy
	flares_left = kit.flares
	lure_out.resize(room.lures.size())
	lure_seen.resize(room.lures.size())
	bonus_taken.resize(room.bonuses.size())
	bonus_seen.resize(room.bonuses.size())

	gate_open_t = room.gate_param("open", 75)
	gate_closing_t = room.gate_param("closing", 45)
	gate_closed_t = room.gate_param("closed", 105)
	var phase_range := room.variation("gate_phase", 0)
	gate_phase = 0 if (calm or phase_range <= 0) else vr.below(phase_range)

	var jitter := room.variation("jelly_jitter_px", 0) * Fx.ONE
	var jelly_tiles: Array[Vector2i] = room.jelly_spawns.duplicate()
	jelly_tiles.append_array(_scatter_tiles(vr, room.variation("jelly_scatter", 0)))
	for i in jelly_tiles.size():
		var sp: Vector2i = jelly_tiles[i]
		var b := Body.new()
		b.kind = Body.Kind.JELLYFISH
		b.index = bodies.size()
		b.radius = J_RADIUS
		b.glow = J_GLOW
		b.x = sp.x * Fx.TILE + Fx.TILE / 2
		b.y = sp.y * Fx.TILE + Fx.TILE / 2
		if not calm and jitter > 0:
			var nx := b.x + vr.between(-jitter, jitter)
			var ny := b.y + vr.between(-jitter, jitter)
			if not _circle_hits_solid(nx, ny, b.radius + Fx.ONE * 2):
				b.x = nx
				b.y = ny
		b.rng = Rng.new(eff_seed, 100 + i)
		b.angle = b.rng.below(Fx.TURN)
		b.timer = 30 + b.rng.below(60)
		bodies.append(b)
	for i in room.lurker_spawns.size():
		var sp: Vector2i = room.lurker_spawns[i]
		var b := Body.new()
		b.kind = Body.Kind.LURKER
		b.index = bodies.size()
		b.radius = L_RADIUS
		b.x = sp.x * Fx.TILE + Fx.TILE / 2
		b.y = sp.y * Fx.TILE + Fx.TILE / 2
		b.rng = Rng.new(eff_seed, 200 + i)
		b.windup = 17 if calm else vr.between(15, 20)
		bodies.append(b)
	for i in room.eel_spawns.size():
		var sp: Vector2i = room.eel_spawns[i]
		var b := Body.new()
		b.kind = Body.Kind.EEL
		b.index = bodies.size()
		b.radius = E_RADIUS
		b.glow = E_GLOW
		b.home_x = sp.x * Fx.TILE + Fx.TILE / 2
		b.x = b.home_x
		b.y = _eel_start_y(sp, vr)
		b.rng = Rng.new(eff_seed, 300 + i)
		b.angle = 0 if calm or vr.below(2) == 0 else Fx.HALF_TURN
		bodies.append(b)
	for i in room.shell_spawns.size():
		var sp: Vector2i = room.shell_spawns[i]
		var b := Body.new()
		b.kind = Body.Kind.SHELLBACK
		b.index = bodies.size()
		b.radius = K_RADIUS
		b.glow = K_GLOW
		b.x = sp.x * Fx.TILE + Fx.TILE / 2
		b.y = sp.y * Fx.TILE + Fx.TILE / 2
		b.home_x = b.x
		b.home_y = b.y
		b.rng = Rng.new(eff_seed, 400 + i)
		b.angle = b.rng.below(Fx.TURN)
		b.timer = 40 + b.rng.below(60)
		bodies.append(b)

	seen.resize(room.w * room.h)
	_update_gate(true)
	_update_seen()


## Where an eel starts in its shaft: anywhere along the run of water above and
## below its marker (the marker itself on calm dives).
func _eel_start_y(sp: Vector2i, vr: Rng) -> int:
	var top := sp.y
	while top > 0 and room.tile_at(sp.x, top - 1) == Room.Tile.WATER:
		top -= 1
	var bottom := sp.y
	while bottom < room.h - 1 and room.tile_at(sp.x, bottom + 1) == Room.Tile.WATER:
		bottom += 1
	var ty := sp.y if calm else vr.between(top, bottom)
	return ty * Fx.TILE + Fx.TILE / 2


## A fresh swarm for every dive: n open-water tiles chosen by the seed, away from
## Robbie's start and the exit, spread at least two tiles apart.
func _scatter_tiles(vr: Rng, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if n <= 0:
		return out
	var ex := room.exit_cx / Fx.TILE
	var ey := room.exit_cy / Fx.TILE
	var tries := 0
	while out.size() < n and tries < n * 60:
		tries += 1
		var t := Vector2i(vr.between(1, room.w - 2), vr.between(1, room.h - 2))
		if room.tile_at(t.x, t.y) != Room.Tile.WATER or room.is_exit(t.x, t.y):
			continue
		if maxi(absi(t.x - room.start_tx), absi(t.y - room.start_ty)) < 6:
			continue
		if maxi(absi(t.x - ex), absi(t.y - ey)) < 3:
			continue
		var crowded := false
		for o in out:
			if maxi(absi(o.x - t.x), absi(o.y - t.y)) < 2:
				crowded = true
				break
		for o in room.jelly_spawns:
			if maxi(absi(o.x - t.x), absi(o.y - t.y)) < 2:
				crowded = true
				break
		if not crowded:
			out.append(t)
	return out


# ---------------------------------------------------------------- tiles

func solid(tx: int, ty: int) -> bool:
	var t := room.tile_at(tx, ty)
	if t == Room.Tile.ROCK:
		return true
	if t == Room.Tile.GATE:
		return gate_state == GateState.CLOSED
	return false


## Obstacle for Robbie's sensors: rock, or a valve that is not fully open.
func obstacle(tx: int, ty: int) -> bool:
	var t := room.tile_at(tx, ty)
	if t == Room.Tile.ROCK:
		return true
	if t == Room.Tile.GATE:
		return gate_state != GateState.OPEN
	return false


func _circle_hits_solid(cx: int, cy: int, r: int) -> bool:
	var tx0 := (cx - r) / Fx.TILE
	var tx1 := (cx + r) / Fx.TILE
	var ty0 := (cy - r) / Fx.TILE
	var ty1 := (cy + r) / Fx.TILE
	for ty in range(ty0, ty1 + 1):
		for tx in range(tx0, tx1 + 1):
			if solid(tx, ty) and _circle_rect(cx, cy, r, tx, ty):
				return true
	return false


func _circle_rect(cx: int, cy: int, r: int, tx: int, ty: int) -> bool:
	var rx0 := tx * Fx.TILE
	var ry0 := ty * Fx.TILE
	var nx := clampi(cx, rx0, rx0 + Fx.TILE)
	var ny := clampi(cy, ry0, ry0 + Fx.TILE)
	var dx := cx - nx
	var dy := cy - ny
	return dx * dx + dy * dy < r * r


## Push a body out of solid tiles. Returns the total push applied.
func _resolve_walls(b: Body) -> Vector2i:
	var total := Vector2i.ZERO
	var r := b.radius
	for _iter in 2:
		var moved := false
		var tx0 := (b.x - r) / Fx.TILE
		var tx1 := (b.x + r) / Fx.TILE
		var ty0 := (b.y - r) / Fx.TILE
		var ty1 := (b.y + r) / Fx.TILE
		for ty in range(ty0, ty1 + 1):
			for tx in range(tx0, tx1 + 1):
				if not solid(tx, ty):
					continue
				var rx0 := tx * Fx.TILE
				var ry0 := ty * Fx.TILE
				var rx1 := rx0 + Fx.TILE
				var ry1 := ry0 + Fx.TILE
				var cx := clampi(b.x, rx0, rx1)
				var cy := clampi(b.y, ry0, ry1)
				var dx := b.x - cx
				var dy := b.y - cy
				var d2 := dx * dx + dy * dy
				if d2 >= r * r:
					continue
				var px := 0
				var py := 0
				if d2 == 0:
					# Centre inside the tile: leave by the shallowest side.
					var left := b.x - rx0
					var right := rx1 - b.x
					var up := b.y - ry0
					var down := ry1 - b.y
					var m := mini(mini(left, right), mini(up, down))
					if m == left:
						px = -(left + r)
					elif m == right:
						px = right + r
					elif m == up:
						py = -(up + r)
					else:
						py = down + r
				else:
					var d := Fx.isqrt(d2)
					if d <= 0:
						d = 1
					var pen := r - d
					px = dx * pen / d
					py = dy * pen / d
					if px == 0 and py == 0:
						px = signi(dx)
						py = signi(dy)
				b.x += px
				b.y += py
				total += Vector2i(px, py)
				moved = true
		if not moved:
			break
	return total


# ---------------------------------------------------------------- sensing

func dist_to(b: Body) -> int:
	return Fx.dist(b.x - robbie.x, b.y - robbie.y)


## True when no solid tile lies between the two points.
func los(ax: int, ay: int, bx: int, by: int) -> bool:
	var dx := bx - ax
	var dy := by - ay
	var d := Fx.dist(dx, dy)
	if d <= RAY_STEP:
		return true
	var steps := d / RAY_STEP
	for i in range(1, steps):
		var px := ax + dx * i * RAY_STEP / d
		var py := ay + dy * i * RAY_STEP / d
		if solid(px / Fx.TILE, py / Fx.TILE):
			return false
	return true


func in_cone(tx_: int, ty_: int) -> bool:
	var a := Fx.angle_of(tx_ - robbie.x, ty_ - robbie.y)
	return absi(Fx.angle_diff(robbie.angle, a)) <= kit.lamp_half


## The lamp lights this point (range, cone and line of sight).
func lit(px_: int, py_: int) -> bool:
	if not lamp_on:
		return false
	if Fx.dist(px_ - robbie.x, py_ - robbie.y) > kit.lamp_range:
		return false
	if not in_cone(px_, py_):
		return false
	return los(robbie.x, robbie.y, px_, py_)


## Robbie can currently sense this body.
func sensed(b: Body) -> bool:
	if not b.alive:
		return false
	var d := dist_to(b)
	if d <= PROX:
		return true
	# Cheap tests first: only bodies close enough to glow at Robbie, or inside the lamp's
	# reach, need the (expensive) line-of-sight check. Same answer as before, much faster.
	var by_glow := b.glow > 0 and d <= b.glow
	var by_lamp := lamp_on and d <= kit.lamp_range and not (b.kind == Body.Kind.LURKER and b.state != 1)
	if not by_glow and not by_lamp:
		return false
	if not los(robbie.x, robbie.y, b.x, b.y):
		return false
	if by_glow:
		return true
	return in_cone(b.x, b.y)


## sensed() for a recorded moment, with everything passed in: the replay uses it to show
## the player only what Robbie could sense (Albert's note #11). Same rules as sensed();
## tests/test_sight.gd checks they agree on every tick of real dives.
func sensed_from(rx_: int, ry_: int, ra_: int, lamp: bool, gstate: int, bx_: int, by_: int, kind: int, state: int, glowing: bool) -> bool:
	var dx := bx_ - rx_
	var dy := by_ - ry_
	var bound := maxi(kit.lamp_range, E_GLOW)
	if absi(dx) > bound or absi(dy) > bound:   # beyond the lamp and every glow
		return false   # far away: the common case, decided without a square root
	var d := Fx.dist(dx, dy)
	if d <= PROX:
		return true
	var g := glow_radius(kind) if glowing else 0
	var by_glow := g > 0 and d <= g
	var by_lamp := lamp and d <= kit.lamp_range and not (kind == Body.Kind.LURKER and state != 1)
	if not by_glow and not by_lamp:
		return false
	if not los_at_state(rx_, ry_, bx_, by_, gstate):
		return false
	if by_glow:
		return true
	return absi(Fx.angle_diff(ra_, Fx.angle_of(dx, dy))) <= kit.lamp_half


## A glowing plant at this tile is sensed from (x, y) at this moment: its glow, or the lamp.
func plant_sensed_from(rx_: int, ry_: int, ra_: int, lamp: bool, gstate: int, p: Vector2i) -> bool:
	var cx := p.x * Fx.TILE + Fx.TILE / 2
	var cy := p.y * Fx.TILE + Fx.TILE / 2
	var dx := cx - rx_
	var dy := cy - ry_
	var bound := maxi(kit.lamp_range, PLANT_GLOW)
	if absi(dx) > bound or absi(dy) > bound:
		return false
	var d := Fx.dist(dx, dy)
	var by_lamp := lamp and d <= kit.lamp_range and absi(Fx.angle_diff(ra_, Fx.angle_of(dx, dy))) <= kit.lamp_half
	if d > PLANT_GLOW and not by_lamp:
		return false
	return los_at_state(rx_, ry_, cx, cy, gstate)


## How far a glowing body of this kind can be sensed by its own light.
static func glow_radius(kind: int) -> int:
	match kind:
		Body.Kind.JELLYFISH:
			return J_GLOW
		Body.Kind.EEL:
			return E_GLOW
		Body.Kind.LURKER:
			return L_GLOW
		Body.Kind.SHELLBACK:
			return K_GLOW
	return 0


## los() with the valve's state passed in.
func los_at_state(ax: int, ay: int, bx_: int, by_: int, gstate: int) -> bool:
	var dx := bx_ - ax
	var dy := by_ - ay
	var d := Fx.dist(dx, dy)
	if d <= RAY_STEP:
		return true
	var steps := d / RAY_STEP
	for i in range(1, steps):
		var px_ := ax + dx * i * RAY_STEP / d
		var py_ := ay + dy * i * RAY_STEP / d
		if solid_at_state(px_ / Fx.TILE, py_ / Fx.TILE, gstate):
			return false
	return true


## Nearest sensed hostile as [body_index, distance], or [-1, -1]. Several rules can ask
## in one think; nothing moves during a think, so the answer is kept until something
## that matters changes (the tick, the lamp, or Robbie's position or heading).
func nearest_hostile() -> Array[int]:
	var key: Array[int] = [tick, 1 if lamp_on else 0, robbie.x, robbie.y, robbie.angle]
	if key == _nh_key:
		return _nh_value
	_nh_key = key
	_nh_value = _nearest_hostile_now()
	return _nh_value


var _nh_key: Array[int] = []
var _nh_value: Array[int] = []


func _nearest_hostile_now() -> Array[int]:
	var best := -1
	var best_d := -1
	for b in bodies:
		if not sensed(b):
			continue
		var d := dist_to(b)
		if best == -1 or d < best_d:
			best = b.index
			best_d = d
	return [best, best_d]


## Distance from Robbie's centre along an angle to the first obstacle.
## Tiles Robbie currently overlaps are ignored ("you can't see the wall you're in").
func ray_dist(angle: int, max_len: int) -> int:
	var dxu := Fx.dir_x(angle)
	var dyu := Fx.dir_y(angle)
	var steps := max_len / RAY_STEP
	for i in range(1, steps + 1):
		var dl := i * RAY_STEP
		var px_ := robbie.x + Fx.mul_trig(dl, dxu)
		var py_ := robbie.y + Fx.mul_trig(dl, dyu)
		var tx := px_ / Fx.TILE
		var ty := py_ / Fx.TILE
		if obstacle(tx, ty) and not _robbie_overlaps(tx, ty):
			return dl
	return max_len


func _robbie_overlaps(tx: int, ty: int) -> bool:
	return _circle_rect(robbie.x, robbie.y, robbie.radius, tx, ty)


func wall_ahead() -> bool:
	var reach := R_RADIUS + WALL_AHEAD
	if ray_dist(robbie.angle, reach) < reach:
		return true
	if ray_dist(robbie.angle - 256, reach) < reach:
		return true
	if ray_dist(robbie.angle + 256, reach) < reach:
		return true
	return false


## Rock (or a shut valve) just behind Robbie: it feels it with its tail. Robbie backs away
## facing the danger, so this is what lies in the way of keep_distance.
func wall_behind() -> bool:
	var reach := R_RADIUS + WALL_AHEAD
	var back := Fx.norm(robbie.angle + Fx.HALF_TURN)
	if ray_dist(back, reach) < reach:
		return true
	if ray_dist(back - 256, reach) < reach:
		return true
	if ray_dist(back + 256, reach) < reach:
		return true
	return false


## Robbie senses the valve ahead: a valve tile in front of it (not one it is
## inside), lit by the lamp or within reach of the pressure sense.
func valve_sensed() -> bool:
	for gt in room.gate_tiles:
		if _robbie_overlaps(gt.x, gt.y):
			return false   # inside the valve: it is around Robbie, not ahead
	for gt in room.gate_tiles:
		var cx := gt.x * Fx.TILE + Fx.TILE / 2
		var cy := gt.y * Fx.TILE + Fx.TILE / 2
		var a := Fx.angle_of(cx - robbie.x, cy - robbie.y)
		if absi(Fx.angle_diff(robbie.angle, a)) > Fx.QUARTER:
			continue
		if Fx.dist(cx - robbie.x, cy - robbie.y) <= PROX + Fx.TILE / 2:
			return true
		if lit(cx, cy):
			return true
	return false


## "valve is open": sensed ahead and fully open.
func gate_open_sensed() -> bool:
	return gate_state == GateState.OPEN and valve_sensed()


## "valve is shut": sensed ahead and closing or closed.
func gate_shut_sensed() -> bool:
	return gate_state != GateState.OPEN and valve_sensed()


## "beacon in sight": nothing but water between Robbie and the beacon.
func beacon_seen() -> bool:
	return los(robbie.x, robbie.y, room.exit_cx, room.exit_cy)


## "stuck": two seconds of pushing and getting nowhere.
func stuck() -> bool:
	if _trail_x.size() < 3:
		return false
	return Fx.dist(robbie.x - _trail_x[0], robbie.y - _trail_y[0]) < STUCK_PX


## "hit": hurt in the last two seconds.
func hit_recently() -> bool:
	return last_hit >= 0 and tick - last_hit <= HIT_TICKS


## "heard" (the hydrophone): an eel or a shellback within 8 tiles, rock or no rock.
func heard() -> bool:
	if not kit.hydrophone:
		return false
	for b in bodies:
		if b.alive and (b.kind == Body.Kind.EEL or b.kind == Body.Kind.SHELLBACK) and dist_to(b) <= HEARD_RANGE:
			return true
	return false


## A lost beacon Robbie senses now: in the lamp, or close enough to feel.
func bonus_sensed(i: int) -> bool:
	var cx := room.bonuses[i].x * Fx.TILE + Fx.TILE / 2
	var cy := room.bonuses[i].y * Fx.TILE + Fx.TILE / 2
	var d := Fx.dist(cx - robbie.x, cy - robbie.y)
	if d <= PROX:
		return true
	if d <= BONUS_GLOW and los(robbie.x, robbie.y, cx, cy):
		return true
	return lit(cx, cy)


func beacon_heading() -> int:
	return Fx.angle_of(room.exit_cx - robbie.x, room.exit_cy - robbie.y)


## Heading to the nearest sensed light (glowing creature or plant), or -1.
func light_heading() -> int:
	var best_d := -1
	var best_a := -1
	for b in bodies:
		if b.glow > 0 and sensed(b):
			var d := dist_to(b)
			if best_d == -1 or d < best_d:
				best_d = d
				best_a = Fx.angle_of(b.x - robbie.x, b.y - robbie.y)
	for p in room.plants:
		var cx := p.x * Fx.TILE + Fx.TILE / 2
		var cy := p.y * Fx.TILE + Fx.TILE / 2
		var d := Fx.dist(cx - robbie.x, cy - robbie.y)
		if (d <= PLANT_GLOW and los(robbie.x, robbie.y, cx, cy)) or lit(cx, cy):
			if best_d == -1 or d < best_d:
				best_d = d
				best_a = Fx.angle_of(cx - robbie.x, cy - robbie.y)
	for i in room.lures.size():
		if lure_out[i] == 1 or not lure_sensed(i):
			continue
		var cx := room.lures[i].x * Fx.TILE + Fx.TILE / 2
		var cy := room.lures[i].y * Fx.TILE + Fx.TILE / 2
		var d := Fx.dist(cx - robbie.x, cy - robbie.y)
		if best_d == -1 or d < best_d:
			best_d = d
			best_a = Fx.angle_of(cx - robbie.x, cy - robbie.y)
	# A lost beacon's ping counts as light too: the way to home in on one.
	for i in room.bonuses.size():
		if bonus_taken[i] == 1 or not bonus_sensed(i):
			continue
		var cx := room.bonuses[i].x * Fx.TILE + Fx.TILE / 2
		var cy := room.bonuses[i].y * Fx.TILE + Fx.TILE / 2
		var d := Fx.dist(cx - robbie.x, cy - robbie.y)
		if best_d == -1 or d < best_d:
			best_d = d
			best_a = Fx.angle_of(cx - robbie.x, cy - robbie.y)
	return best_a


## A cold light still burning that Robbie senses now: by its own glow, or in the lamp.
func lure_sensed(i: int) -> bool:
	if lure_out[i] == 1:
		return false
	var cx := room.lures[i].x * Fx.TILE + Fx.TILE / 2
	var cy := room.lures[i].y * Fx.TILE + Fx.TILE / 2
	var dx := cx - robbie.x
	var dy := cy - robbie.y
	var bound := maxi(kit.lamp_range, LURE_GLOW)
	if absi(dx) > bound or absi(dy) > bound:
		return false
	var d := Fx.dist(dx, dy)
	if d <= LURE_GLOW and los(robbie.x, robbie.y, cx, cy):
		return true
	return lit(cx, cy)


func open_water_heading() -> int:
	var best_score := -1
	var best_a := robbie.angle
	for i in 16:
		var a := Fx.norm(robbie.angle + i * 256)
		var d := ray_dist(a, 80 * Fx.ONE)
		var score := d * 4 - absi(Fx.angle_diff(robbie.angle, a)) * 8
		if score > best_score:
			best_score = score
			best_a = a
	return best_a


## Steering for "Follow wall". side: -1 = keep the wall on the left, +1 = right.
func follow_wall_heading(side: int) -> int:
	var a := robbie.angle
	var probe := 40 * Fx.ONE
	var front := ray_dist(a, probe)
	var diag := ray_dist(a + side * 512, probe)
	var lateral := ray_dist(a + side * 1024, probe)
	if front < 18 * Fx.ONE or diag < 11 * Fx.ONE:
		return Fx.norm(a - side * 700)        # wall ahead: turn away from the wall side
	if lateral >= 30 * Fx.ONE and diag >= probe:
		return Fx.norm(a + side * 500)        # lost the wall: curl towards it
	var err := lateral - 12 * Fx.ONE        # positive: too far from the wall
	# Converging on the wall? Parallel to a straight wall, diag = lateral * sqrt(2).
	var conv := 0
	if diag < probe:
		conv = lateral * 181 / 128 - diag     # positive: heading into the wall
	var adj := clampi(err / 40 - conv / 24, -300, 300)
	return Fx.norm(a + side * adj)


func shoot_target() -> int:
	if laser_cd > 0 or energy < LASER_COST:
		return -1
	var nh := nearest_hostile()
	if nh[0] == -1 or nh[1] > LASER_RANGE:
		return -1
	var b := bodies[nh[0]]
	if not los(robbie.x, robbie.y, b.x, b.y):
		return -1
	return nh[0]


func energy_percent() -> int:
	if energy_max <= 0:
		return 0
	return energy * 100 / energy_max


# ---------------------------------------------------------------- actions

## Called by the dive after the VM decides. decision keys: act, heading, rule, target.
func apply(decision: Dictionary) -> void:
	act = decision.get("act", Act.IDLE)
	act_heading = decision.get("heading", robbie.angle)
	act_face = decision.get("face", -1)
	act_rule = decision.get("rule", -1)
	if act == Act.SHOOT:
		var ti: int = decision.get("target", -1)
		if ti >= 0 and ti < bodies.size() and bodies[ti].alive:
			var b := bodies[ti]
			# Lurkers are armoured rock: the beam glances off. Robbie still pays for the
			# shot and stands still while it fires, which is the worst place to be.
			var bounced := b.kind == Body.Kind.LURKER or b.kind == Body.Kind.EEL or b.kind == Body.Kind.SHELLBACK   # eels slip aside
			if not bounced:
				b.alive = false
				b.glow = 0
			if b.kind == Body.Kind.SHELLBACK:
				# It felt that. Now it comes for him.
				if b.state != 1:
					events.append({"t": tick, "type": "shell_angry", "src": ti})
				b.state = 1
				b.timer = K_RAGE
			energy -= LASER_COST
			commit = LASER_COMMIT
			laser_cd = LASER_COOLDOWN
			last_laser_target = ti
			robbie.angle = Fx.angle_of(b.x - robbie.x, b.y - robbie.y)
			events.append({"t": tick, "type": "laser", "target": ti, "kind": b.kind_name(), "bounced": bounced})
		act = Act.STOP
	elif act == Act.FLARE:
		if flares_left > 0:
			flares_left -= 1
			flare_x.append(robbie.x)
			flare_y.append(robbie.y)
			flare_t.append(tick)
			commit = 3
			events.append({"t": tick, "type": "flare", "x": robbie.x, "y": robbie.y})
		act = Act.STOP
	hold = int(decision.get("hold", 0))


# ---------------------------------------------------------------- step

func step() -> void:
	if result != Result.RUNNING:
		return
	_update_gate(false)
	if result == Result.RUNNING:
		_move_robbie()
	if result == Result.RUNNING:
		_update_creatures()
	energy -= DRAIN_BASE + (kit.drain_move if moving else 0)
	if energy <= 0 and kit.reserve and not reserve_used and result == Result.RUNNING:
		reserve_used = true
		energy = energy_max * 15 / 100
		events.append({"t": tick, "type": "reserve"})
	if energy <= 0:
		energy = 0
		if result == Result.RUNNING:
			result = Result.ENERGY
			cause = "energy"
			events.append({"t": tick, "type": "energy_out"})
	if tick % THINK_EVERY == 0:
		_update_seen()
	_update_lures()
	_update_bonuses()
	if tick % 30 == 0:
		_trail_x.append(robbie.x)
		_trail_y.append(robbie.y)
		if _trail_x.size() > 3:
			_trail_x.pop_front()
			_trail_y.pop_front()
	if result == Result.RUNNING and room.is_exit(robbie.x / Fx.TILE, robbie.y / Fx.TILE):
		result = Result.EXIT
		cause = "exit"
		events.append({"t": tick, "type": "exit"})
	tick += 1
	if invuln > 0:
		invuln -= 1
	if laser_cd > 0:
		laser_cd -= 1
	if hold > 0:
		hold -= 1
	if result == Result.RUNNING and tick >= MAX_TICKS:
		result = Result.TIMEOUT
		cause = "timeout"


## The cold lights: each is noted the first time Robbie senses it, and goes out when he reaches it.
func _update_lures() -> void:
	for i in room.lures.size():
		if lure_out[i] == 1:
			continue
		if lure_seen[i] == 0 and lure_sensed(i):
			lure_seen[i] = 1
			events.append({"t": tick, "type": "lure_seen", "i": i})
		var cx := room.lures[i].x * Fx.TILE + Fx.TILE / 2
		var cy := room.lures[i].y * Fx.TILE + Fx.TILE / 2
		if Fx.dist(cx - robbie.x, cy - robbie.y) <= LURE_REACH:
			lure_out[i] = 1
			events.append({"t": tick, "type": "lure_out", "i": i})


## The lost beacons: noted the first time Robbie senses one, recovered when he reaches it. Once
## recovered, its code is on the wire: it counts even if he's lost afterwards.
func _update_bonuses() -> void:
	for i in room.bonuses.size():
		if bonus_taken[i] == 1 or result != Result.RUNNING:
			continue
		if bonus_seen[i] == 0 and bonus_sensed(i):
			bonus_seen[i] = 1
			events.append({"t": tick, "type": "bonus_seen", "i": i})
		var cx := room.bonuses[i].x * Fx.TILE + Fx.TILE / 2
		var cy := room.bonuses[i].y * Fx.TILE + Fx.TILE / 2
		if Fx.dist(cx - robbie.x, cy - robbie.y) <= BONUS_REACH:
			bonus_taken[i] = 1
			if bonus_seen[i] == 0:
				bonus_seen[i] = 1
				events.append({"t": tick, "type": "bonus_seen", "i": i})
			events.append({"t": tick, "type": "bonus", "i": i})


func flare_burning(i: int) -> bool:
	return tick - flare_t[i] < FLARE_TICKS


func _update_gate(initial: bool) -> void:
	if room.gate_tiles.is_empty():
		return
	var cycle := gate_open_t + gate_closing_t + gate_closed_t
	var p := (tick + gate_phase) % cycle
	var ns := GateState.OPEN
	if p >= gate_open_t + gate_closing_t:
		ns = GateState.CLOSED
	elif p >= gate_open_t:
		ns = GateState.CLOSING
	if initial:
		gate_state = ns
		return
	if ns == gate_state:
		return
	gate_state = ns
	events.append({"t": tick, "type": "valve", "state": ["open", "closing", "closed"][ns]})
	if ns == GateState.CLOSED:
		for gt in room.gate_tiles:
			if _circle_rect(robbie.x, robbie.y, robbie.radius, gt.x, gt.y):
				_damage(3, "valve", -1, false)
				break


func _move_robbie() -> void:
	moving = false
	if commit > 0:
		commit -= 1
		return
	if act != Act.MOVE:
		return
	var travel := robbie.angle
	var spd := kit.speed
	if act_face >= 0:
		# Back away: turn to keep facing the threat, thrust along act_heading.
		var df := clampi(Fx.angle_diff(robbie.angle, act_face), -R_TURN, R_TURN)
		robbie.angle = Fx.norm(robbie.angle + df)
		travel = act_heading
		spd = kit.reverse
	else:
		var d := clampi(Fx.angle_diff(robbie.angle, act_heading), -R_TURN, R_TURN)
		robbie.angle = Fx.norm(robbie.angle + d)
		travel = robbie.angle
	var vx := Fx.mul_trig(spd, Fx.dir_x(travel))
	var vy := Fx.mul_trig(spd, Fx.dir_y(travel))
	robbie.x += vx
	robbie.y += vy
	moving = true
	var push := _resolve_walls(robbie)
	_push_off_shells()
	if push != Vector2i.ZERO:
		if _touching_shut_valve():
			if invuln == 0:
				events.append({"t": tick, "type": "valve_sting"})
				if not kit.insulated:
					_damage(1, "valve", -1, true)
				invuln = VALVE_INVULN
			return
		var plen := Fx.dist(push.x, push.y)
		var into := -(vx * push.x + vy * push.y)
		if plen > 0 and into * 100 > 85 * spd * plen:
			events.append({"t": tick, "type": "crash"})
			_damage(1, "wall", -1, true)


## A shellback is solid: Robbie bumps off its shell (no harm done, unless it's angry).
func _push_off_shells() -> void:
	for b in bodies:
		if b.kind != Body.Kind.SHELLBACK or not b.alive:
			continue
		var dx := robbie.x - b.x
		var dy := robbie.y - b.y
		var d := Fx.dist(dx, dy)
		var need := b.radius + robbie.radius
		if d >= need:
			continue
		if d <= 0:
			dx = Fx.ONE
			d = Fx.ONE
		robbie.x = b.x + dx * need / d
		robbie.y = b.y + dy * need / d
		_resolve_walls(robbie)


func _touching_shut_valve() -> bool:
	if gate_state != GateState.CLOSED:
		return false
	for gt in room.gate_tiles:
		if _circle_rect(robbie.x, robbie.y, robbie.radius + Fx.ONE, gt.x, gt.y):
			return true
	return false


func _update_creatures() -> void:
	for b in bodies:
		if not b.alive or result != Result.RUNNING:
			continue
		match b.kind:
			Body.Kind.JELLYFISH:
				_step_jellyfish(b)
			Body.Kind.LURKER:
				_step_lurker(b)
			Body.Kind.EEL:
				_step_eel(b)
			Body.Kind.SHELLBACK:
				_step_shell(b)


func _step_jellyfish(b: Body) -> void:
	var spd := J_DRIFT
	var seen_lamp := false
	if not kit.red_lamp:   # a red lamp is dark to them
		var in_halo := lamp_on and dist_to(b) <= kit.lamp_halo and los(robbie.x, robbie.y, b.x, b.y)
		seen_lamp = in_halo or lit(b.x, b.y)
	var flare := _flare_for(b) if not seen_lamp else -1
	if seen_lamp:
		b.state = 1
		b.angle = Fx.angle_of(robbie.x - b.x, robbie.y - b.y)
		spd = J_CHASE
	elif flare >= 0:
		b.state = 1
		var fdx := flare_x[flare] - b.x
		var fdy := flare_y[flare] - b.y
		if Fx.dist(fdx, fdy) <= J_RADIUS:
			spd = 0   # clustered on the flare
		else:
			b.angle = Fx.angle_of(fdx, fdy)
			spd = J_CHASE
	else:
		b.state = 0
		b.timer -= 1
		if b.timer <= 0:
			b.angle = b.rng.below(Fx.TURN)
			b.timer = 60 + b.rng.below(60)
	var nx := b.x + Fx.mul_trig(spd, Fx.dir_x(b.angle))
	var ny := b.y + Fx.mul_trig(spd, Fx.dir_y(b.angle))
	if _circle_hits_solid(nx, ny, b.radius):
		if b.state == 0:
			b.angle = b.rng.below(Fx.TURN)
	else:
		b.x = nx
		b.y = ny
	if b.timer2 > 0:
		b.timer2 -= 1
	if b.timer2 == 0 and dist_to(b) < b.radius + robbie.radius:
		b.timer2 = J_STING_COOLDOWN
		_damage(1, "jellyfish", b.index, true)


## The nearest burning flare a jellyfish can see, or -1.
func _flare_for(b: Body) -> int:
	var best := -1
	var best_d := 0
	for i in flare_x.size():
		if not flare_burning(i):
			continue
		var d := Fx.dist(flare_x[i] - b.x, flare_y[i] - b.y)
		if d <= FLARE_PULL and (best == -1 or d < best_d) and los(b.x, b.y, flare_x[i], flare_y[i]):
			best = i
			best_d = d
	return best


## state 0: crawls about, minding its own business; 1: angry (it was shot), charges him.
func _step_shell(b: Body) -> void:
	var spd := K_CRAWL
	if b.state == 1:
		b.angle = Fx.angle_of(robbie.x - b.x, robbie.y - b.y)
		spd = K_CHARGE
		b.timer -= 1
		if b.timer <= 0:
			b.state = 0
			b.timer = 60
	else:
		b.timer -= 1
		if b.timer <= 0:
			b.angle = b.rng.below(Fx.TURN)
			b.timer = 60 + b.rng.below(90)
	var nx := b.x + Fx.mul_trig(spd, Fx.dir_x(b.angle))
	var ny := b.y + Fx.mul_trig(spd, Fx.dir_y(b.angle))
	var strays := b.state == 0 and Fx.dist(nx - b.home_x, ny - b.home_y) > K_LEASH
	if _circle_hits_solid(nx, ny, b.radius) or strays:
		if b.state == 0:
			b.angle = Fx.angle_of(b.home_x - b.x, b.home_y - b.y) if strays else b.rng.below(Fx.TURN)
	else:
		b.x = nx
		b.y = ny
	if b.timer2 > 0:
		b.timer2 -= 1
	if b.state == 1 and b.timer2 == 0 and dist_to(b) < b.radius + robbie.radius + Fx.ONE * 2:
		b.timer2 = 30
		_damage(K_DAMAGE, "shellback", b.index, true)


func _step_lurker(b: Body) -> void:
	var d := dist_to(b)
	match b.state:
		0:
			b.glow = 0
			if d <= L_TRIGGER:
				b.state = 1
				b.timer = b.windup
				b.glow = L_GLOW
				events.append({"t": tick, "type": "lurker_wakes", "src": b.index})
		1:
			b.timer -= 1
			if b.timer <= 0:
				events.append({"t": tick, "type": "lurker_strikes", "src": b.index, "hit": d <= L_REACH})
				if d <= L_REACH:
					_damage(L_DAMAGE, "lurker", b.index, false)
				b.state = 2
				b.timer = L_COOLDOWN
				b.glow = 0
		2:
			b.timer -= 1
			if b.timer <= 0:
				b.state = 0


## state 0: patrol up and down its shaft; 1: lunge at the sound; 2: swim back and rest.
func _step_eel(b: Body) -> void:
	match b.state:
		0:
			if moving and dist_to(b) <= kit.eel_hear and los(robbie.x, robbie.y, b.x, b.y):
				b.state = 1
				b.timer = E_LUNGE_TICKS
				events.append({"t": tick, "type": "eel_hears", "src": b.index})
				return
			if not _eel_swim(b, b.angle, E_PATROL):
				b.angle = Fx.norm(b.angle + Fx.HALF_TURN)
		1:
			b.angle = Fx.angle_of(robbie.x - b.x, robbie.y - b.y)
			_eel_swim(b, b.angle, E_LUNGE)
			b.timer -= 1
			if dist_to(b) < b.radius + robbie.radius:
				_damage(E_DAMAGE, "eel", b.index, true)
				b.state = 2
				b.timer = E_REST
			elif b.timer <= 0:
				b.state = 2
				b.timer = E_REST
		2:
			var dx := b.home_x - b.x
			if absi(dx) > E_PATROL:
				_eel_swim(b, Fx.angle_of(dx, 0), E_PATROL)
			else:
				b.x = b.home_x
			b.timer -= 1
			if b.timer <= 0 and b.x == b.home_x:
				b.state = 0
				b.angle = 0 if b.rng.below(2) == 0 else Fx.HALF_TURN


func _eel_swim(b: Body, a: int, spd: int) -> bool:
	var nx := b.x + Fx.mul_trig(spd, Fx.dir_x(a))
	var ny := b.y + Fx.mul_trig(spd, Fx.dir_y(a))
	if _circle_hits_solid(nx, ny, b.radius):
		return false
	b.x = nx
	b.y = ny
	return true


func _damage(n: int, why: String, src: int, respect_invuln: bool) -> void:
	if result != Result.RUNNING:
		return
	if respect_invuln and invuln > 0:
		return
	robbie.hp -= n
	invuln = INVULN
	last_hit = tick
	events.append({"t": tick, "type": "damage", "n": n, "cause": why, "src": src, "hp": robbie.hp})
	if robbie.hp <= 0:
		robbie.hp = 0
		robbie.alive = false
		result = Result.DESTROYED
		cause = why


func _update_seen() -> void:
	# Pressure sense: the tiles right around Robbie.
	var r := PROX
	for ty in range((robbie.y - r) / Fx.TILE, (robbie.y + r) / Fx.TILE + 1):
		for tx in range((robbie.x - r) / Fx.TILE, (robbie.x + r) / Fx.TILE + 1):
			_mark_seen(tx, ty)
	if not lamp_on:
		return
	for k in range(-4, 5):
		var a := Fx.norm(robbie.angle + k * kit.lamp_half / 4)
		var dxu := Fx.dir_x(a)
		var dyu := Fx.dir_y(a)
		var steps := kit.lamp_range / (4 * Fx.ONE)
		for i in range(1, steps + 1):
			var dl := i * 4 * Fx.ONE
			var tx := (robbie.x + Fx.mul_trig(dl, dxu)) / Fx.TILE
			var ty := (robbie.y + Fx.mul_trig(dl, dyu)) / Fx.TILE
			_mark_seen(tx, ty)
			if solid(tx, ty):
				break


func _mark_seen(tx: int, ty: int) -> void:
	if tx < 0 or ty < 0 or tx >= room.w or ty >= room.h:
		return
	var i := ty * room.w + tx
	if seen[i] == 0:
		seen[i] = 1
		seen_count += 1


# ---------------------------------------------------------------- views

## Solidity with an explicit valve state, for views replaying a recording.
func solid_at_state(tx: int, ty: int, gstate: int) -> bool:
	var t := room.tile_at(tx, ty)
	if t == Room.Tile.ROCK:
		return true
	if t == Room.Tile.GATE:
		return gstate == GateState.CLOSED
	return false


## Endpoints of n lamp rays from (x, y) facing angle, each stopping at the first
## solid tile or at LAMP_RANGE. Flat array: x0, y0, x1, y1, ... in sub-pixels.
## The view draws the lit cone from these, so the picture matches the sim.
func lamp_ray_ends(x: int, y: int, angle: int, gstate: int, n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in n:
		var a := Fx.norm(angle - kit.lamp_half + (2 * kit.lamp_half * k) / maxi(n - 1, 1))
		var dxu := Fx.dir_x(a)
		var dyu := Fx.dir_y(a)
		var ex := x + Fx.mul_trig(kit.lamp_range, dxu)
		var ey := y + Fx.mul_trig(kit.lamp_range, dyu)
		var steps := kit.lamp_range / RAY_STEP
		for i in range(1, steps + 1):
			var dl := i * RAY_STEP
			var px_ := x + Fx.mul_trig(dl, dxu)
			var py_ := y + Fx.mul_trig(dl, dyu)
			if solid_at_state(px_ / Fx.TILE, py_ / Fx.TILE, gstate):
				ex = px_
				ey = py_
				break
		out.append(ex)
		out.append(ey)
	return out


# ---------------------------------------------------------------- checks

## FNV-1a over the full state. Two runs that agree here agree everywhere.
func state_hash() -> int:
	var hsh := 0x811C9DC5
	var vals: Array[int] = [tick, robbie.x, robbie.y, robbie.angle, robbie.hp, energy,
		1 if lamp_on else 0, gate_state, act, act_heading, commit, invuln]
	for b in bodies:
		vals.append_array([b.x, b.y, b.angle, b.state, b.timer, 1 if b.alive else 0])
	for v in vals:
		hsh = ((hsh ^ (v & 0xFFFFFFFF)) * 0x01000193) & 0xFFFFFFFF
	return hsh


static func result_name(r: int) -> String:
	return ["running", "exit", "destroyed", "energy", "timeout"][r]
