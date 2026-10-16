class_name Fx
extends RefCounted
## Fixed-point maths for the deterministic simulation.
##
## Rules for everything under sim/ and vm/: integers only. No float, no Vector2,
## no sin/cos/sqrt/atan2 from the engine. tests/test_lint.gd enforces this.
##
## Units:
##   positions  sub-pixels, ONE (256) per pixel, TILE (4096) per 16-px tile
##   angles     compass style, 4096 per turn: 0 = up (north), 1024 = right (east),
##              clockwise, screen y grows downwards
##   trig       sin/cos values scaled by TRIG_ONE (16384)

const ONE := 256
const TILE_PX := 16
const TILE := TILE_PX * ONE
const TURN := 4096
const HALF_TURN := 2048
const QUARTER := 1024
const TRIG_ONE := 16384


static func px(p: int) -> int:
	return p * ONE


static func norm(a: int) -> int:
	return a & 4095


## Degrees (any integer) to angle units, rounded.
static func from_deg(deg: int) -> int:
	var d := posmod(deg, 360)
	return norm((d * TURN + 180) / 360)


static func to_deg(a: int) -> int:
	return (norm(a) * 360 + HALF_TURN) / TURN


static func isin(a: int) -> int:
	a = a & 4095
	if a <= 1024:
		return FxTables.SIN_Q[a]
	if a <= 2048:
		return FxTables.SIN_Q[2048 - a]
	if a <= 3072:
		return -FxTables.SIN_Q[a - 2048]
	return -FxTables.SIN_Q[4096 - a]


static func icos(a: int) -> int:
	return isin(a + 1024)


## Unit direction for a compass angle, scaled by TRIG_ONE. Screen y grows down.
static func dir_x(a: int) -> int:
	return isin(a)


static func dir_y(a: int) -> int:
	return -icos(a)


## v * t / TRIG_ONE with symmetric rounding (same result for +v and -v).
static func mul_trig(v: int, t: int) -> int:
	var p := v * t
	if p >= 0:
		return (p + 8192) / TRIG_ONE
	return -((-p + 8192) / TRIG_ONE)


## Compass angle of the vector (dx, dy), screen coordinates. (0, 0) gives 0.
static func angle_of(dx: int, dy: int) -> int:
	var u := dx       # east component
	var v := -dy      # north component
	if u == 0 and v == 0:
		return 0
	var au := absi(u)
	var av := absi(v)
	var a: int
	if au <= av:
		a = FxTables.ATAN[(au * 1024) / av]
	else:
		a = QUARTER - FxTables.ATAN[(av * 1024) / au]
	# a is the angle from north towards east for the first quadrant
	if u >= 0 and v >= 0:
		return norm(a)
	if u >= 0 and v < 0:
		return norm(HALF_TURN - a)
	if u < 0 and v < 0:
		return norm(HALF_TURN + a)
	return norm(TURN - a)


## Signed shortest turn from a to b, in [-2048, 2047].
static func angle_diff(a: int, b: int) -> int:
	return ((b - a + HALF_TURN) & 4095) - HALF_TURN


## Integer square root (floor) for n >= 0.
static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var x := n
	var y := (x + 1) >> 1
	while y < x:
		x = y
		y = (x + n / x) >> 1
	return x


static func dist(dx: int, dy: int) -> int:
	return isqrt(dx * dx + dy * dy)


static func clampi_(v: int, lo: int, hi: int) -> int:
	if v < lo:
		return lo
	if v > hi:
		return hi
	return v
