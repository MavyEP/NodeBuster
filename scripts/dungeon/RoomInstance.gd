extends RefCounted
class_name RoomInstance

# Where this room sits in the dungeon grid
var grid_coord: Vector2i = Vector2i.ZERO

# Room blueprint
var room_data: RoomData = null

# Runtime connections: direction string → neighbor grid_coord
# Example: {"north": Vector2i(0,-1), "east": Vector2i(1,0)}
var connections: Dictionary = {}

# State
var is_cleared: bool = false   # All enemies dead
var is_visited: bool = false   # Player has been here

# Which directions actually have active doors (subset of room_data)
var active_doors: Array[String] = []

func _init(coord: Vector2i, data: RoomData):
	grid_coord = coord
	room_data = data

func get_neighbor_coord(direction: String) -> Vector2i:
	return connections.get(direction, Vector2i(-999, -999))

func has_connection(direction: String) -> bool:
	return connections.has(direction)

# Opposite direction helper
static func opposite(direction: String) -> String:
	match direction:
		"north": return "south"
		"south": return "north"
		"east":  return "west"
		"west":  return "east"
	return ""

# Direction → grid offset
static func direction_to_offset(direction: String) -> Vector2i:
	match direction:
		"north": return Vector2i(0, -1)
		"south": return Vector2i(0,  1)
		"east":  return Vector2i(1,  0)
		"west":  return Vector2i(-1, 0)
	return Vector2i.ZERO
