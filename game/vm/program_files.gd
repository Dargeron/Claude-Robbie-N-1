class_name ProgramFiles
extends RefCounted
## Loads .rbt program files. Header comments may carry metadata used by tests:
##   # expect: exit            (or: fail)
##   # certify: yes            (or: no) - should the survey fleet pass?


static func load_program(path: String) -> Program:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		var p := Program.new()
		p.errors.append("cannot open %s" % path)
		return p
	var prog := Program.parse(f.get_as_text())
	prog.name = path.get_file().get_basename()
	return prog


static func metadata(path: String) -> Dictionary:
	var meta := {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return meta
	for line in f.get_as_text().split("\n"):
		var s := line.strip_edges()
		if not s.begins_with("#"):
			continue
		s = s.substr(1).strip_edges()
		var colon := s.find(":")
		if colon > 0:
			meta[s.substr(0, colon).strip_edges().to_lower()] = s.substr(colon + 1).strip_edges()
	return meta
