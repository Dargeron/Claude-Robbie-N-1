extends TestCase
## The sim and the VM must stay integer-only to be deterministic everywhere.

const DIRS := ["res://sim", "res://vm"]
const FORBIDDEN := [
	["float literal", "\\b\\d+\\.\\d+\\b"],
	["float type", "\\bfloat\\b"],
	["Vector2 (use Vector2i)", "\\bVector2\\b"],
	["engine trig/sqrt", "\\b(sin|cos|tan|atan|atan2|sqrt|pow|exp|log)\\("],
	["engine randomness", "\\b(randf|randi|randf_range|randi_range|RandomNumberGenerator)\\b"],
	["wall-clock time", "\\bTime\\."],
]


func test_sim_is_integer_only() -> void:
	var res: Array[RegEx] = []
	for f in FORBIDDEN:
		var re := RegEx.new()
		re.compile(f[1])
		res.append(re)
	for dir in DIRS:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):
				continue
			var lines := FileAccess.get_file_as_string(dir + "/" + file).split("\n")
			for n in lines.size():
				var code := lines[n]
				var hash_at := code.find("#")
				if hash_at >= 0:
					code = code.substr(0, hash_at)
				code = _strip_strings(code)
				for k in res.size():
					if res[k].search(code) != null:
						failures.append("%s/%s:%d uses %s" % [dir, file, n + 1, FORBIDDEN[k][0]])


func _strip_strings(code: String) -> String:
	var out := ""
	var in_str := false
	for ch in code:
		if ch == "\"":
			in_str = not in_str
			continue
		if not in_str:
			out += ch
	return out


## tools/ and tests/ are left out of exported builds, so game code must never use a
## class declared there (block 15: the station once called Golden and the web build
## failed to parse).
func test_game_code_does_not_use_tool_classes() -> void:
	var tool_classes: Array[String] = []
	var re_class := RegEx.new()
	re_class.compile("^class_name\\s+(\\w+)")
	for dir in ["res://tools", "res://tests"]:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				for line in FileAccess.get_file_as_string(dir + "/" + file).split("\n"):
					var m := re_class.search(line)
					if m != null:
						tool_classes.append(m.get_string(1))
	check(tool_classes.has("Golden") and tool_classes.has("TestCase"), "found the tool classes (%s)" % str(tool_classes))
	for dir in ["res://sim", "res://vm", "res://station", "res://view"]:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(dir + "/" + file)
			for cls in tool_classes:
				var re := RegEx.new()
				re.compile("\\b%s\\b" % cls)
				if re.search(text) != null:
					failures.append("%s/%s uses %s, which exported builds leave out" % [dir, file, cls])
