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
enum Act { IDLE, MOVE, STOP, SHOOT }

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

# Jellyfish
const J_RADIUS := 4 * 256
const J_GLOW := 48 * 256
const J_DRIFT := 64             # 0.25 px per tick
const J_CHASE := 282            # 1.1 px per tick: lit jellyfish dart at the lamp
const J_STING_COOLDOWN := 30

# Lurker
const L_RADIUS := 6 * 256
const L_TRIGGER := 34 * 256
const L_REACH := 38 * 256
const L_GLOW := 40 * 256
const L_COOLDOWN := 120
const L_DAMAGE := 3

var room: Room
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


func _init(r: Room, seed_v: int, calm_v: bool = false) -> void:
	room = r
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
	robbie.hp = R_HP
	energy = room.energy
	energy_max = room.energy

	gate_open_t = room.gate_param("open", 75)
	gate_closing_t = room.gate_param("closing", 45)
	gate_closed_t = room.gate_param("closed", 105)
	var phase_range := room.variation("gate_phase", 0)
	gate_phase = 0 if (calm or phase_range <= 0) else vr.below(phase_range)

	var jitter := room.variation("jelly_jitter_px", 0) * Fx.ONE
	for i in room.jelly_spawns.size():
		var sp: Vector2i = room.jelly_spawns[i]
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

	seen.resize(room.w * room.h)
	_update_gate(true)
	_update_seen()


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
	return absi(Fx.angle_diff(robbie.angle, a)) <= LAMP_HALF


## The lamp lights this point (range, cone and line of sight).
func lit(px_: int, py_: int) -> bool:
	if not lamp_on:
		return false
	if Fx.dist(px_ - robbie.x, py_ - robbie.y) > LAMP_RANGE:
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
	if not los(robbie.x, robbie.y, b.x, b.y):
		return false
	if b.glow > 0 and d <= b.glow:
		return true
	if b.kind == Body.Kind.LURKER and b.state != 1:
		return false  # camouflaged, except while it winds up to strike
	if lamp_on and d <= LAMP_RANGE and in_cone(b.x, b.y):
		return true
	return false


## Nearest sensed hostile as [body_index, distance], or [-1, -1].
func nearest_hostile() -> Array[int]:
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
	return best_a


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
	var adj := clampi(err / 16, -400, 400)
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
			b.alive = false
			b.glow = 0
			energy -= LASER_COST
			commit = LASER_COMMIT
			laser_cd = LASER_COOLDOWN
			last_laser_target = ti
			robbie.angle = Fx.angle_of(b.x - robbie.x, b.y - robbie.y)
			events.append({"t": tick, "type": "laser", "target": ti, "kind": b.kind_name()})
		act = Act.STOP


# ---------------------------------------------------------------- step

func step() -> void:
	if result != Result.RUNNING:
		return
	_update_gate(false)
	if result == Result.RUNNING:
		_move_robbie()
	if result == Result.RUNNING:
		_update_creatures()
	energy -= DRAIN_BASE + (DRAIN_MOVE if moving else 0)
	if energy <= 0:
		energy = 0
		if result == Result.RUNNING:
			result = Result.ENERGY
			cause = "energy"
			events.append({"t": tick, "type": "energy_out"})
	if tick % THINK_EVERY == 0:
		_update_seen()
	if result == Result.RUNNING and room.is_exit(robbie.x / Fx.TILE, robbie.y / Fx.TILE):
		result = Result.EXIT
		cause = "exit"
		events.append({"t": tick, "type": "exit"})
	tick += 1
	if invuln > 0:
		invuln -= 1
	if laser_cd > 0:
		laser_cd -= 1
	if result == Result.RUNNING and tick >= MAX_TICKS:
		result = Result.TIMEOUT
		cause = "timeout"


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
	var spd := R_SPEED
	if act_face >= 0:
		# Back away: turn to keep facing the threat, thrust along act_heading.
		var df := clampi(Fx.angle_diff(robbie.angle, act_face), -R_TURN, R_TURN)
		robbie.angle = Fx.norm(robbie.angle + df)
		travel = act_heading
		spd = R_REVERSE
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
	if push != Vector2i.ZERO:
		if _touching_shut_valve():
			if invuln == 0:
				events.append({"t": tick, "type": "valve_sting"})
				_damage(1, "valve", -1, true)
				invuln = VALVE_INVULN
			return
		var plen := Fx.dist(push.x, push.y)
		var into := -(vx * push.x + vy * push.y)
		if plen > 0 and into * 100 > 85 * spd * plen:
			events.append({"t": tick, "type": "crash"})
			_damage(1, "wall", -1, true)


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


func _step_jellyfish(b: Body) -> void:
	var spd := J_DRIFT
	if lit(b.x, b.y):
		b.state = 1
		b.angle = Fx.angle_of(robbie.x - b.x, robbie.y - b.y)
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


func _damage(n: int, why: String, src: int, respect_invuln: bool) -> void:
	if result != Result.RUNNING:
		return
	if respect_invuln and invuln > 0:
		return
	robbie.hp -= n
	invuln = INVULN
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
		var a := Fx.norm(robbie.angle + k * LAMP_HALF / 4)
		var dxu := Fx.dir_x(a)
		var dyu := Fx.dir_y(a)
		var steps := LAMP_RANGE / (4 * Fx.ONE)
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
