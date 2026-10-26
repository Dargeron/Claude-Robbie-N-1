extends Node
## A clip of the machine working, for Albert (run with --write-movie): the chain pulled down and
## let go, then a card printed. Sector 1, from a throwaway save.

var console: Control
var _f := 0


func _ready() -> void:
	console = load("res://console/console.tscn").instantiate()
	console.state.save_path = "user://machine_clip.json"
	console.state.persist = false
	add_child(console)
	console.state.reset()
	console._select_sector("dark")
	console.memo.visible = false


func _process(_d: float) -> void:
	_f += 1
	for n: Node in console._notes.values():
		(n as CanvasItem).visible = false
	var ch: PullChain = console.dispatch
	if _f == 20:
		ch._grab = true
		ch._finger = ch.handle()
	elif _f > 20 and _f < 50:
		ch._finger += Vector2(0.4, 3.4)
	elif _f == 50:
		ch._grab = false
		ch._finger += Vector2(18, 0)
	elif _f == 150:
		console.press._pulled = false
		console.press._pull()
