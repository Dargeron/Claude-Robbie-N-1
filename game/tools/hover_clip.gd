extends Node
## A few seconds of a dive on the scope at normal speed, for a clip of how Bathy swims (run with
## --write-movie). Sector 1, FOLLOW WALL LEFT, from a throwaway save.

var console: Control
var _f := 0


func _ready() -> void:
	console = load("res://console/console.tscn").instantiate()
	console.state.save_path = "user://hover_clip.json"
	console.state.persist = false
	add_child(console)
	console.state.reset()
	console._select_sector("dark")
	console.memo.visible = false
	var rules: Array = Program.parse("follow_wall left").rules
	console.table.setup(console.state.room_state("dark").room.slots, rules, [])
	console._on_deck_changed()
	console.dispatch.armed = true
	console._dispatch()
	console.scope.replay.seek(float(console.scope.replay.view.last_tick()) * 0.12)
	console.scope.replay.playing = true


func _process(_d: float) -> void:
	_f += 1
	for n: Node in console._notes.values():
		(n as CanvasItem).visible = false
