extends Node
## Scripted screenshots of the operator's console, for checking it without a human.
##   xvfb-run -a godot --path game --rendering-driver opengl3 res://tools/console_shots.tscn -- <out_dir>
## Plays through the three sectors with a throwaway save, reading memos, dispatching,
## watching, magnifying, running sea trials, and captures the moments that matter.

var out_dir := "/tmp/console_shots"
var console: Control
var steps: Array = []
var wait := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	console = load("res://console/console.tscn").instantiate()
	console.state.save_path = "user://console_shots.json"
	console.state.persist = false
	add_child(console)
	console.state.reset()
	console._select_sector("dark")
	steps = [
		["wait", 30], ["shot", "c01-start"],
		["memo"], ["wait", 12], ["shot", "c02-memo"], ["close"],
		["wait", 4], ["shot", "c03-notes-dispatch"],
		["dispatch"], ["seek", 0.45], ["wait", 8], ["shot", "c04-dark-naive"],
		["seek", 1.0], ["wait", 30], ["shot", "c05-lost"],
		["magnify"], ["wait", 20], ["shot", "c06-magnified"], ["magnify"], ["wait", 20],
		["scrubbed"], ["wait", 4], ["shot", "c07-notes-deck"],
		["dial_order", "follow_wall", "left"], ["wait", 30], ["shot", "c08a-flaps"],
		["print"], ["wait", 8], ["shot", "c08b-printing"], ["wait", 40], ["shot", "c08c-printed"],
		["lid", true], ["wait", 20], ["shot", "c08d-lid-open"],
		["insert", 0, 1], ["wait", 20], ["pulp_slot", 0], ["wait", 12], ["shot", "c08e-pulping"],
		["lid", false], ["wait", 20], ["program", "follow_wall left"], ["dispatch"], ["seek", 0.35], ["wait", 8], ["shot", "c09-dark-follow"],
		["seek", 1.0], ["wait", 8], ["trials"], ["wait", 6], ["shot", "c10-trials-running"], ["await_trials"], ["wait", 10], ["shot", "c11-certified"],
		["memo"], ["wait", 12], ["shot", "c12-tally"], ["close"], ["memo"], ["wait", 12], ["shot", "c13-letter"], ["close"],
		["memo"], ["wait", 12], ["close"],
		["binder"], ["wait", 10], ["shot", "c14-binder"], ["close"],
		["sector", "jellyfish"], ["wait", 6], ["shot", "c15-jellyfish-chart"],
		["program", "move_towards beacon"], ["dispatch"], ["seek_event", "damage", -10], ["wait", 8], ["shot", "c16-jelly-contact"],
		["program", "lamp off\nmove_towards beacon"], ["dispatch"], ["seek", 0.4], ["wait", 8], ["shot", "c17-jelly-dark"],
		["seek", 1.0], ["trials"], ["await_trials"], ["wait", 10], ["memo"], ["close"], ["memo"], ["close"], ["memo"], ["close"],
		["sector", "nursery"], ["program", "shoot\nfollow_wall left"], ["dispatch"], ["seek_event", "laser", 2], ["wait", 8], ["shot", "c18-nursery-laser"],
		["wall"], ["wait", 10], ["shot", "c19-wall"], ["wall_close"],
		["sector", "dark"], ["wait", 30], ["shot", "c20-dark-chart-after"],
		["quit"],
	]


func _process(_d: float) -> void:
	if wait > 0:
		wait -= 1
		return
	if steps.is_empty():
		return
	var s: Array = steps.pop_front()
	var rp: ReplayPlayer = console.scope.replay
	match s[0]:
		"wait":
			wait = s[1]
		"shot":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, s[1]])
			print("shot ", s[1])
		"memo":
			console._open_next_memo()
		"close":
			console.memo.visible = false
		"binder":
			console._open_binder()
		"dispatch":
			console.dispatch.armed = true
			console._dispatch()
		"seek":
			rp.seek(s[1] * float(rp.view.last_tick()))
			rp.playing = false
		"seek_event":
			for e in console.current_dive.world.events:
				if e["type"] == s[1]:
					rp.seek(float(int(e["t"]) + int(s[2])))
					rp.playing = false
					break
		"magnify":
			console._toggle_magnify()
		"scrubbed":
			console._scrubbed = true
		"program":
			var rules: Array = Program.parse(s[1]).rules
			console.table.setup(console.state.room_state(console.room_id).room.slots, rules, [])
			console._on_deck_changed()
		"dial_order":
			var pr: CardPress = console.press
			for i in pr._orders.size():
				if pr._orders[i][0] == s[1] and pr._orders[i][1] == s[2]:
					pr.order_wheel._step(i - pr.order_wheel.index)
		"print":
			console.press._pulled = false
			console.press._pull()
		"lid":
			console.table.set_lid(s[1])
		"insert":
			var t: CardTable = console.table
			for c: Dictionary in t.cards:
				if c["where"] == "tray" and c["i"] == s[1]:
					t._drop(t.cards.find(c), t.slot_rect(s[2]).get_center())
					break
		"pulp_slot":
			var t: CardTable = console.table
			var k := t._in_slot(s[1])
			if k >= 0:
				t._drop(k, Desk.r("chute_mouth").get_center())
		"trials":
			console._start_trials()
		"await_trials":
			if console.survey_run != null:
				steps.push_front(["await_trials"])
		"sector":
			console._select_sector(s[1])
		"wall":
			console._open_wall()
		"wall_close":
			console.wall.visible = false
		"quit":
			get_tree().quit()
