class_name RoomLibrary
extends RefCounted
## Finds rooms by id under res://content/rooms, or loads a path directly.

const ROOM_DIR := "res://content/rooms"


static func load_room(id_or_path: String) -> Room:
	if id_or_path.ends_with(".room"):
		return Room.load_file(id_or_path)
	return Room.load_file("%s/%s.room" % [ROOM_DIR, id_or_path])


static func ids() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(ROOM_DIR)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".room"):
			out.append(f.get_basename())
	out.sort()
	return out
