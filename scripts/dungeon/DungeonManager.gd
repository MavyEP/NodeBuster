extends Node

## Generates and stores the dungeon graph.
## Each room lives on a grid (Vector2i). Connections between adjacent cells
## are recorded so RoomManager knows which doors to place.

signal dungeon_generated

# --- Tunables ---------------------------------------------------------------
@export var dungeon_size: int = 12          # total rooms (including start)
@export var max_generation_attempts: int = 200

# --- Dungeon state ----------------------------------------------------------
# key   = Vector2i grid position
# value = RoomInfo (inner class below)
var dungeon_map: Dictionary = {}
var start_pos: Vector2i = Vector2i.ZERO

# Pool of room scene paths eligible for generation (auto-scanned)
var _room_pool: Array[String] = []

# Direction helpers
const DIRECTIONS = {
	"north": Vector2i(0, -1),
	"south": Vector2i(0,  1),
	"east":  Vector2i(1,  0),
	"west":  Vector2i(-1, 0),
}

const OPPOSITE = {
	"north": "south",
	"south": "north",
	"east":  "west",
	"west":  "east",
}

# ---- Inner data class -------------------------------------------------------
class RoomInfo:
	var scene_path: String = ""
	var grid_pos: Vector2i = Vector2i.ZERO
	var connections: Dictionary = {}   # direction_string -> Vector2i of neighbour
	var is_visited: bool = false
	var is_cleared: bool = false
	var is_start: bool = false
	var difficulty: int = 0
	var tags: Array[String] = []
	var saved_entities: Array = []     # persisted dynamic objects (orbs, chests, items…)

# ---- Lifecycle --------------------------------------------------------------
func _ready():
	_scan_room_pool()

func reset():
	dungeon_map.clear()
	start_pos = Vector2i.ZERO

# ---- Room pool scanning -----------------------------------------------------
func _scan_room_pool():
	_room_pool.clear()
	var dir = DirAccess.open("res://scenes/rooms/")
	if not dir:
		push_warning("DungeonManager: No scenes/rooms/ folder found!")
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tscn") and not file_name.begins_with("StartRoom"):
			_room_pool.append("res://scenes/rooms/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	print("DungeonManager: Found ", _room_pool.size(), " room(s) in pool")

# ---- Generation -------------------------------------------------------------
func generate_dungeon(size_override: int = -1):
	reset()
	var target_size = size_override if size_override > 0 else dungeon_size
	if _room_pool.is_empty():
		_scan_room_pool()

	# 1. Place start room
	var start_info = RoomInfo.new()
	start_info.scene_path = "res://scenes/rooms/StartRoom.tscn"
	start_info.grid_pos = Vector2i.ZERO
	start_info.is_start = true
	dungeon_map[Vector2i.ZERO] = start_info
	start_pos = Vector2i.ZERO

	# 2. Grow the dungeon via random walk from existing rooms
	var frontier: Array[Vector2i] = [Vector2i.ZERO]
	var attempts = 0

	while dungeon_map.size() < target_size and attempts < max_generation_attempts:
		attempts += 1
		# Pick a random existing room that still has free neighbours
		frontier.shuffle()
		var grew = false
		for src_pos in frontier:
			var free_dirs = _get_free_directions(src_pos)
			if free_dirs.is_empty():
				continue
			free_dirs.shuffle()
			var dir_name: String = free_dirs[0]
			var new_pos: Vector2i = src_pos + DIRECTIONS[dir_name]

			# Create the new room
			var room_info = RoomInfo.new()
			room_info.scene_path = _room_pool.pick_random()
			room_info.grid_pos = new_pos
			# Difficulty loosely based on distance from start
			room_info.difficulty = _manhattan_distance(Vector2i.ZERO, new_pos)
			dungeon_map[new_pos] = room_info

			# Connect both rooms
			dungeon_map[src_pos].connections[dir_name] = new_pos
			room_info.connections[OPPOSITE[dir_name]] = src_pos

			# Also connect to any other existing adjacent rooms (loop corridors)
			for other_dir in DIRECTIONS:
				if other_dir == OPPOSITE[dir_name]:
					continue
				var adj_pos = new_pos + DIRECTIONS[other_dir]
				if dungeon_map.has(adj_pos):
					# 40% chance to also connect (creates loops for backtracking)
					if randf() < 0.4:
						room_info.connections[other_dir] = adj_pos
						dungeon_map[adj_pos].connections[OPPOSITE[other_dir]] = new_pos

			frontier.append(new_pos)
			grew = true
			break

		if not grew:
			break  # no room can expand — stop

	# 3. Rebuild frontier (optional cleanup; not strictly needed)
	print("DungeonManager: Generated ", dungeon_map.size(), " rooms")
	dungeon_generated.emit()

# ---- Queries ----------------------------------------------------------------
func get_room_info(grid_pos: Vector2i) -> RoomInfo:
	return dungeon_map.get(grid_pos, null)

func mark_visited(grid_pos: Vector2i):
	var info = get_room_info(grid_pos)
	if info:
		info.is_visited = true

func mark_cleared(grid_pos: Vector2i):
	var info = get_room_info(grid_pos)
	if info:
		info.is_cleared = true

func get_connected_directions(grid_pos: Vector2i) -> Array:
	var info = get_room_info(grid_pos)
	if info:
		return info.connections.keys()
	return []

func get_neighbor_pos(grid_pos: Vector2i, direction: String) -> Vector2i:
	var info = get_room_info(grid_pos)
	if info and info.connections.has(direction):
		return info.connections[direction]
	return Vector2i(-999, -999)  # sentinel for "no neighbour"

# ---- Helpers ----------------------------------------------------------------
func _get_free_directions(pos: Vector2i) -> Array:
	var free: Array = []
	for dir_name in DIRECTIONS:
		var adj = pos + DIRECTIONS[dir_name]
		if not dungeon_map.has(adj):
			free.append(dir_name)
	return free

func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
