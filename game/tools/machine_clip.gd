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
	var lv: DispatchLever = console.dispatch
	if _f == 20:
		lv._drag = true
	elif _f > 20 and _f < 46:
		lv._angle = minf(lv._angle + 2.0, lv.PULLED)
		if lv._angle >= lv.PULLED - 2.0 and not lv._fired:
			lv._fire()
	elif _f == 60:
		lv._drag = false
	elif _f == 150:
		console.press._pulled = false
		console.press._pull()
