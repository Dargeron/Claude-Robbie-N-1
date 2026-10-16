extends TestCase


func test_all_rooms_load() -> void:
	var ids := RoomLibrary.ids()
	check(ids.size() >= 3, "at least three rooms, found %s" % str(ids))
	for id in ids:
		var r := RoomLibrary.load_room(id)
		eq(r.error, "", "%s loads" % id)
		eq(r.w, 40, "%s width" % id)
		eq(r.h, 22, "%s height" % id)
		check(r.tile_at(r.start_tx, r.start_ty) == Room.Tile.WATER, "%s start is water" % id)
		check(r.cpu_budget > 0 and r.energy > 0, "%s has budget and energy" % id)


func test_border_is_rock() -> void:
	for id in RoomLibrary.ids():
		var r := RoomLibrary.load_room(id)
		for x in r.w:
			check(r.tile_at(x, 0) == Room.Tile.ROCK and r.tile_at(x, r.h - 1) == Room.Tile.ROCK, "%s border row at x=%d" % [id, x])
		for y in r.h:
			check(r.tile_at(0, y) == Room.Tile.ROCK and r.tile_at(r.w - 1, y) == Room.Tile.ROCK, "%s border column at y=%d" % [id, y])
