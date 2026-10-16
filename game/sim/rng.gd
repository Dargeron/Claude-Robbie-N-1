class_name Rng
extends RefCounted
## Deterministic 32-bit xorshift generator. Never use Godot's RandomNumberGenerator
## inside the sim: its algorithm may change between engine versions.

const MASK := 0xFFFFFFFF

var state: int


func _init(seed_value: int, stream: int = 0) -> void:
	state = (seed_value ^ 0x9E3779B9 ^ ((stream & 0xFFFF) << 16) ^ (stream >> 16)) & MASK
	if state == 0:
		state = 0x6D2B79F5
	# Warm up so that nearby seeds diverge quickly.
	for _i in 8:
		next_u32()


func next_u32() -> int:
	var x := state
	x ^= (x << 13) & MASK
	x ^= x >> 17
	x ^= (x << 5) & MASK
	state = x
	return x


## Uniform integer in [0, n). n must be > 0.
func below(n: int) -> int:
	return next_u32() % n


## Uniform integer in [lo, hi], inclusive.
func between(lo: int, hi: int) -> int:
	if hi <= lo:
		return lo
	return lo + below(hi - lo + 1)
