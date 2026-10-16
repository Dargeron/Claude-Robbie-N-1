extends TestCase


func test_sin_cos_key_angles() -> void:
	eq(Fx.isin(0), 0, "sin 0")
	eq(Fx.isin(1024), 16384, "sin 90")
	eq(Fx.isin(2048), 0, "sin 180")
	eq(Fx.isin(3072), -16384, "sin 270")
	eq(Fx.icos(0), 16384, "cos 0")
	eq(Fx.icos(2048), -16384, "cos 180")
	eq(Fx.isin(-1024), -16384, "sin wraps negative angles")


func test_compass_directions() -> void:
	# 0 = up (screen y negative), 1024 = right.
	eq(Fx.dir_y(0), -16384, "north points up")
	eq(Fx.dir_x(1024), 16384, "east points right")
	eq(Fx.angle_of(0, -100), 0, "up is 0")
	eq(Fx.angle_of(100, 0), 1024, "right is 1024")
	eq(Fx.angle_of(0, 100), 2048, "down is 2048")
	eq(Fx.angle_of(-100, 0), 3072, "left is 3072")


func test_angle_of_round_trip() -> void:
	var worst := 0
	for a in range(0, 4096, 7):
		var back := Fx.angle_of(Fx.dir_x(a), Fx.dir_y(a))
		worst = maxi(worst, absi(Fx.angle_diff(a, back)))
	check(worst <= 1, "angle_of(dir(a)) within 1 unit of a, worst %d" % worst)


func test_angle_diff() -> void:
	eq(Fx.angle_diff(100, 200), 100, "small positive")
	eq(Fx.angle_diff(4000, 100), 196, "across zero")
	eq(Fx.angle_diff(100, 4000), -196, "across zero backwards")


func test_isqrt() -> void:
	for n in [0, 1, 2, 3, 4, 15, 16, 17, 99, 100, 65535, 65536, 123456789, 27000000000]:
		var r := Fx.isqrt(n)
		check(r * r <= n and (r + 1) * (r + 1) > n, "isqrt(%d) = %d" % [n, r])


func test_degrees() -> void:
	eq(Fx.from_deg(90), 1024, "90 degrees")
	eq(Fx.from_deg(-90), 3072, "-90 degrees wraps")
	eq(Fx.to_deg(Fx.from_deg(135)), 135, "round trip")


func test_mul_trig_is_symmetric() -> void:
	for v in [1, 7, 255, 256, 1000]:
		for a in [1, 100, 1500, 3000]:
			eq(Fx.mul_trig(-v, Fx.isin(a)), -Fx.mul_trig(v, Fx.isin(a)), "mul_trig symmetric v=%d a=%d" % [v, a])
