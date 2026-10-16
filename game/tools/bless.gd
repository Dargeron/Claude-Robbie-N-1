extends SceneTree
## Re-record every golden replay from the current simulation.
##   godot --headless --path game --script res://tools/bless.gd


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(Golden.DIR)
	var n := 0
	for path in Golden.program_paths():
		var room_id := path.get_base_dir().get_file()
		for s in Golden.SEEDS:
			var g := Golden.record(room_id, path, s)
			var f := FileAccess.open(Golden.file_for(path, s), FileAccess.WRITE)
			f.store_string(JSON.stringify(g, "  ") + "\n")
			n += 1
	print("blessed %d golden replays" % n)
	quit(0)
