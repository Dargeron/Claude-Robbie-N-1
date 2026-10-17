class_name Room
extends RefCounted
## A level map loaded from a .room text file: one JSON header line, a line with
## "---", then the tile grid. Grid symbols:
##   #  rock          .  water        S  Robbie's start     E  exit (beacon)
##   G  valve (gate)  J  jellyfish    L  lurker niche       p  glowing plant (decor)
##   H  eel ("listener"): patrols the vertical shaft it starts in

enum Tile { WATER = 0, ROCK = 1, GATE = 2 }

var id := ""
var title := ""
var header: Dictionary = {}
var w := 0
var h := 0
var tiles := PackedByteArray()
var exits := PackedByteArray()
var start_tx := 1
var start_ty := 1
var start_heading_deg := 90
var cpu_budget := 10
var energy := 6000
var jelly_spawns: Array[Vector2i] = []
var lurker_spawns: Array[Vector2i] = []
var eel_spawns: Array[Vector2i] = []
var plants: Array[Vector2i] = []
var gate_tiles: Array[Vector2i] = []
var exit_cx := 0   # sub-pixel centre of the exit area (the beacon)
var exit_cy := 0
var error := ""


static func load_file(path: String) -> Room:
	var r := Room.new()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		r.error = "cannot open %s" % path
		return r
	r.parse(f.get_as_text())
	return r


func parse(text: String) -> void:
	var parts := text.split("\n---\n", false, 1)
	if parts.size() != 2:
		error = "room file needs a JSON header, a --- line, then the grid"
		return
	var parsed: Variant = JSON.parse_string(parts[0])
	if typeof(parsed) != TYPE_DICTIONARY:
		error = "bad JSON header"
		return
	header = parsed
	id = str(header.get("id", ""))
	title = str(header.get("name", id))
	cpu_budget = int(header.get("cpu", 10))
	energy = int(header.get("energy", 6000))
	start_heading_deg = int(header.get("start_heading", 90))
	var lines: Array[String] = []
	for line in parts[1].split("\n"):
		if line.strip_edges() != "":
			lines.append(line)
	h = lines.size()
	w = 0
	for line in lines:
		w = maxi(w, line.length())
	tiles.resize(w * h)
	exits.resize(w * h)
	var ex_sum := 0
	var ey_sum := 0
	var ecount := 0
	for y in h:
		var line: String = lines[y]
		for x in w:
			var c := line[x] if x < line.length() else "#"
			var t := Tile.WATER
			match c:
				"#":
					t = Tile.ROCK
				"G":
					t = Tile.GATE
					gate_tiles.append(Vector2i(x, y))
				"S":
					start_tx = x
					start_ty = y
				"E":
					exits[y * w + x] = 1
					ex_sum += x
					ey_sum += y
					ecount += 1
				"J":
					jelly_spawns.append(Vector2i(x, y))
				"L":
					lurker_spawns.append(Vector2i(x, y))
				"H":
					eel_spawns.append(Vector2i(x, y))
				"p":
					plants.append(Vector2i(x, y))
			tiles[y * w + x] = t
	if ecount == 0:
		error = "room has no exit"
		return
	# Beacon at the centre of the exit tiles (integer maths only).
	exit_cx = (ex_sum * Fx.TILE + ecount * Fx.TILE / 2) / ecount
	exit_cy = (ey_sum * Fx.TILE + ecount * Fx.TILE / 2) / ecount


func tile_at(tx: int, ty: int) -> int:
	if tx < 0 or ty < 0 or tx >= w or ty >= h:
		return Tile.ROCK
	return tiles[ty * w + tx]


func is_exit(tx: int, ty: int) -> bool:
	if tx < 0 or ty < 0 or tx >= w or ty >= h:
		return false
	return exits[ty * w + tx] == 1


func variation(key: String, default_value: int) -> int:
	var v: Variant = header.get("variation", {})
	if typeof(v) == TYPE_DICTIONARY and v.has(key):
		return int(v[key])
	return default_value


func gate_param(key: String, default_value: int) -> int:
	var g: Variant = header.get("gate", {})
	if typeof(g) == TYPE_DICTIONARY and g.has(key):
		return int(g[key])
	return default_value
