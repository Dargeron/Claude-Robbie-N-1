extends SceneTree
## Test runner: loads res://tests/test_*.gd and runs every test_* method.
##   godot --headless --path game --script res://tools/run_tests.gd -- [name-filter]
## Exit code 0 when everything passes, 1 otherwise.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var filter := args[0] if args.size() > 0 else ""
	var files: Array[String] = []
	var d := DirAccess.open("res://tests")
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			files.append("res://tests/" + f)
	files.sort()
	var run := 0
	var failed := 0
	var start := Time.get_ticks_msec()
	for path in files:
		var script: GDScript = load(path)
		var inst: TestCase = script.new()
		for m in inst.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			if filter != "" and path.find(filter) < 0 and name.find(filter) < 0:
				continue
			inst.failures.clear()
			var t0 := Time.get_ticks_msec()
			inst.call(name)
			run += 1
			var ms := Time.get_ticks_msec() - t0
			if inst.failures.is_empty():
				print("  ok    %s.%s (%d ms)" % [path.get_file().get_basename(), name, ms])
			else:
				failed += 1
				print("  FAIL  %s.%s" % [path.get_file().get_basename(), name])
				for msg in inst.failures:
					print("        - ", msg)
	print("\n%d tests, %d failed, %.1f s" % [run, failed, (Time.get_ticks_msec() - start) / 1000.0])
	quit(1 if failed > 0 or run == 0 else 0)
