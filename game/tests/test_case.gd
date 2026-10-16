class_name TestCase
extends RefCounted
## Minimal test base. Methods named test_* are run by tools/run_tests.gd.

var failures: Array[String] = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [msg, str(expected), str(actual)])
