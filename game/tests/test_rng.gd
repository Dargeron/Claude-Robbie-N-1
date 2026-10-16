extends TestCase


func test_same_seed_same_sequence() -> void:
	var a := Rng.new(42)
	var b := Rng.new(42)
	for i in 100:
		eq(a.next_u32(), b.next_u32(), "draw %d" % i)


func test_streams_and_seeds_differ() -> void:
	check(Rng.new(1).next_u32() != Rng.new(2).next_u32(), "seeds 1 and 2 differ")
	check(Rng.new(1, 0).next_u32() != Rng.new(1, 1).next_u32(), "streams differ")


func test_known_values() -> void:
	# Pinned (cross-checked with a Python implementation). If this changes, every golden replay changes.
	var r := Rng.new(1)
	eq([r.next_u32(), r.next_u32(), r.next_u32()], [3745685276, 411726028, 2229840677], "pinned xorshift output")


func test_between_bounds() -> void:
	var r := Rng.new(7)
	for i in 1000:
		var v := r.between(-5, 5)
		check(v >= -5 and v <= 5, "between in range")
	eq(r.between(3, 3), 3, "empty range")
