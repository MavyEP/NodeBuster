extends Resource
class_name RoomData

enum RoomType {
	START,
	NORMAL,
	TREASURE,
	BOSS
}

# What type of room this is
@export var room_type: RoomType = RoomType.NORMAL

# Which doors this room CAN have (designer sets this per room scene)
@export var has_door_north: bool = false
@export var has_door_south: bool = false
@export var has_door_east: bool = false
@export var has_door_west: bool = false

# Path to the actual scene for this room
@export var scene_path: String = ""

# How many enemies to spawn (0 for start/treasure rooms)
@export var min_enemies: int = 2
@export var max_enemies: int = 5
