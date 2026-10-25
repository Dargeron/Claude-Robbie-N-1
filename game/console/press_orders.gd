class_name PressOrders
extends RefCounted
## What the press's wheels can carry. Data only, so tests and the binder can read it.

## Every order the wheel can carry, with the type plate it needs.
const ORDERS := [
	["move_towards", "beacon", "towards_beacon"],
	["follow_wall", "left", "follow_wall"],
	["follow_wall", "right", "follow_wall"],
	["move", "0", "move"], ["move", "45", "move"], ["move", "90", "move"], ["move", "135", "move"],
	["move", "180", "move"], ["move", "225", "move"], ["move", "270", "move"], ["move", "315", "move"],
	["stop", "", "stop"],
	["lamp", "off", "lamp"], ["lamp", "on", "lamp"],
	["keep_distance", "2", "keep_distance"], ["keep_distance", "4", "keep_distance"], ["keep_distance", "6", "keep_distance"],
	["move_towards", "light", "towards_light"],
	["shoot", "", "shoot"],
	["move_towards", "open_water", "towards_open_water"],
]
const CONDS := ["", "wall_ahead", "wall_behind", "hostile_near", "energy_below", "executing", "valve_open", "valve_shut"]
const COND_VALUES := {"hostile_near": ["2", "4", "6"], "energy_below": ["25", "50", "75"], "executing": ["1", "2", "3", "4", "5", "6"]}
