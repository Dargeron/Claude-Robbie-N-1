extends Node
## Scripted screenshots of the station, for checking the UI without a human.
##   xvfb-run -a godot --path game --rendering-driver opengl3 res://tools/shots.tscn -- <out_dir> [script]
## Scripts: "tour" (default) launches naive and intended programs in each room and captures moments.

var out_dir := "/tmp/shots"
var station: Control
var steps: Array = []
var frame := 0
var wait := 0
var shot_n := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	station = load("res://station/station.tscn").instantiate()
	station.state.reset()
	add_child(station)
	steps = [
		["wait", 10], ["shot", "01-start"],
		["launch"], ["seek", 0.35], ["wait", 5], ["shot", "02-dark-naive-mid"],
		["launch"], ["seek", 1.0], ["wait", 5], ["shot", "03-dark-hint"],
		["program", "follow_wall left"], ["launch"], ["seek", 0.3], ["wait", 5], ["shot", "04-dark-chart"],
		["watch"], ["seek", 0.55], ["wait", 5], ["shot", "05-watch-large"], ["watch"],
		["seek", 1.0], ["survey"], ["wait", 5], ["shot", "06-dark-certified"],
		["room", "valve"], ["program", "keep_distance 4\nstop if valve_shut\nmove_towards beacon"], ["launch"],
		["seek_tick", 362], ["wait", 5], ["shot", "07-valve-lurker"],
		["room", "jellyfish"], ["program", "move_towards beacon"], ["launch"], ["seek", 0.85], ["wait", 5], ["shot", "08-jellyfish-naive"],
		["program", "lamp off\nkeep_distance 2\nmove_towards beacon"], ["launch"], ["seek", 0.12], ["wait", 5], ["shot", "08b-jellyfish-ghost"],
		["room", "valve"], ["program", "move_towards beacon"], ["launch"],
		["wall"], ["wait", 5], ["shot", "09-wall"],
		["wall_pick", 3], ["wait", 5], ["shot", "10-from-wall"],
		["quit"],
	]


func _process(_d: float) -> void:
	frame += 1
	if wait > 0:
		wait -= 1
		return
	if steps.is_empty():
		return
	var s: Array = steps.pop_front()
	match s[0]:
		"wait":
			wait = s[1]
		"shot":
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/%s.png" % [out_dir, s[1]])
			print("shot ", s[1])
		"launch":
			station._launch()
		"seek":
			station.replay.seek(s[1] * float(station.replay.view.last_tick()))
			station.replay.playing = false
		"seek_tick":
			station.replay.seek(float(s[1]))
			station.replay.playing = false
		"program":
			station.program = Program.parse(s[1])
			station.editor.set_program(station.program)
			station._on_program_changed()
		"survey":
			station._survey()
		"room":
			station._select_room(s[1])
		"watch":
			station._toggle_watch()
		"wall":
			station._open_wall()
		"wall_pick":
			var items := RobbieWall.plaques(station.state)
			var it: Dictionary = items[s[1]]
			station._open_from_wall(it["room"], it["entry"])
		"quit":
			get_tree().quit()
