extends Node

## Handles room instantiation, transitions, enemy tracking, and door state.
## Works hand-in-hand with DungeonManager (graph data) to run the game-play
## side of the dungeon.

signal room_entered(grid_pos: Vector2i)
signal room_cleared(grid_pos: Vector2i)
signal boss_room_cleared(grid_pos: Vector2i)
signal boss_spawned(boss_node: CharacterBody2D)
signal trapdoor_entered
signal doors_locked
signal doors_unlocked
signal transition_started
signal transition_finished

# ---- Constants --------------------------------------------------------------
const ROOM_WIDTH: int = 480 
const ROOM_HEIGHT: int = 270
const DOOR_SCENE_PATH = "res://scenes/rooms/Door.tscn"

# Player spawn offsets from room center when entering from a direction
const ENTRY_OFFSETS = {
	"north": Vector2(0, -240),   # came from south of previous room → top area
	"south": Vector2(0,  240),   # came from north of previous room → bottom
	"east":  Vector2( 480, 0),   # came from west  → right area
	"west":  Vector2(-480, 0),   # came from east  → left area
	"center": Vector2.ZERO,      # start room / default
}

# ---- State ------------------------------------------------------------------
var current_grid_pos: Vector2i = Vector2i.ZERO
var current_room_instance: Node2D = null
var _active_enemies: Array = []
var _doors: Dictionary = {}          # direction_string -> DoorController node
var _is_transitioning: bool = false

# References set by Game.gd during setup
var room_container: Node2D = null     # parent node for room instances
var player: CharacterBody2D = null
var camera: Camera2D = null
var transition_rect: ColorRect = null # fullscreen overlay for fade

var _enemy_scene = preload("res://scenes/enemies/Enemy.tscn")
var _door_scene: PackedScene = null

# Door textures — set these to pass sprites to every door in the dungeon.
# Leave null for the default ColorRect look.
var door_locked_texture: Texture2D = null
var door_unlocked_texture: Texture2D = null

# Boss pool: array of { "scene": PackedScene, "level_min": int, "level_max": int }
# Bosses are eligible when dungeon_level is in [level_min, level_max].
# level_max of -1 means no upper bound.
# To add a new boss: append to this array or call register_boss().
var boss_pool: Array[Dictionary] = []
var _default_boss_scene = preload("res://scenes/enemies/Boss.tscn")

# ---- Lifecycle --------------------------------------------------------------
func _ready():
	_door_scene = load(DOOR_SCENE_PATH)
	_init_default_boss_pool()

# ---- Boss pool management ---------------------------------------------------

## Initialise the default boss pool. Override or extend this to add more bosses.
## Each entry: { "scene": PackedScene, "level_min": int, "level_max": int }
##   level_max = -1 means "no upper bound" (available from level_min onward).
##
## Example setups:
##   Levels 1-4  → default Boss
##   Level 5     → only a specific boss (set level_min=5, level_max=5)
##   Levels 6-9  → a different pool
##   Levels 10+  → yet another set
func _init_default_boss_pool():
	boss_pool.clear()
	# Default boss — available at all levels as a fallback
	boss_pool.append({
		"scene": _default_boss_scene,
		"level_min": 1,
		"level_max": -1,  # no cap
	})

## Register an additional boss scene for a given level range.
func register_boss(scene: PackedScene, level_min: int = 1, level_max: int = -1):
	boss_pool.append({
		"scene": scene,
		"level_min": level_min,
		"level_max": level_max,
	})

## Pick a random boss scene that is eligible for the current dungeon level.
func _pick_boss_scene() -> PackedScene:
	var level = DungeonManager.dungeon_level
	var eligible: Array[PackedScene] = []
	for entry in boss_pool:
		var lmin: int = entry["level_min"]
		var lmax: int = entry["level_max"]
		if level >= lmin and (lmax == -1 or level <= lmax):
			eligible.append(entry["scene"])
	if eligible.is_empty():
		push_warning("RoomManager: No boss in pool for level ", level, " — using default")
		return _default_boss_scene
	return eligible.pick_random()

# ---- Public API -------------------------------------------------------------

## Enter a room. Called at game start and on every door transition.
func enter_room(grid_pos: Vector2i, entry_direction: String = "center"):
	var room_info = DungeonManager.get_room_info(grid_pos)
	if not room_info:
		push_error("RoomManager: No room at ", grid_pos)
		return

	# Tear down previous room
	_cleanup_current_room()

	current_grid_pos = grid_pos

	# Instantiate the room scene
	var scene: PackedScene = load(room_info.scene_path)
	current_room_instance = scene.instantiate()
	room_container.add_child(current_room_instance)
	current_room_instance.position = Vector2.ZERO

	# Build room visuals (walls + floor) — pass connected directions so
	# the wall builder knows where to leave gaps for doors.
	var connections = DungeonManager.get_connected_directions(grid_pos)
	if current_room_instance.has_method("draw_floor"):
		current_room_instance.draw_floor()
	if current_room_instance.has_method("draw_wall_visuals"):
		current_room_instance.draw_wall_visuals(connections)
	if current_room_instance.has_method("build_walls"):
		current_room_instance.build_walls(connections)

	# Place doors
	_setup_doors(grid_pos)

	# Place player
	var room_center = Vector2(ROOM_WIDTH / 2.0, ROOM_HEIGHT / 2.0)
	var offset = ENTRY_OFFSETS.get(entry_direction, Vector2.ZERO)
	player.global_position = room_center + offset

	# Center camera on room
	if camera:
		camera.global_position = room_center

	# Mark visited
	var first_visit = not room_info.is_visited
	DungeonManager.mark_visited(grid_pos)

	# Spawn enemies on first visit (skip start room)
	if first_visit and not room_info.is_start:
		_lock_doors()
		if room_info.is_boss_room:
			_spawn_boss(room_info)
		else:
			_spawn_enemies(room_info)
	else:
		_unlock_doors()

	# Restore any previously saved entities (orbs, chests, items…)
	_restore_room_state(room_info)

	room_entered.emit(grid_pos)

## Called by DoorController when the player steps through a door.
func transition_to_room(direction: String):
	if _is_transitioning:
		return
	_is_transitioning = true
	transition_started.emit()

	var target_pos = DungeonManager.get_neighbor_pos(current_grid_pos, direction)
	if target_pos == Vector2i(-999, -999):
		_is_transitioning = false
		return

	var entry_dir = DungeonManager.OPPOSITE[direction]

	# Fade out
	if transition_rect:
		var tw = create_tween()
		tw.tween_property(transition_rect, "color:a", 1.0, 0.15)
		await tw.finished

	enter_room(target_pos, entry_dir)

	# Fade in
	if transition_rect:
		var tw = create_tween()
		tw.tween_property(transition_rect, "color:a", 0.0, 0.15)
		await tw.finished

	_is_transitioning = false
	transition_finished.emit()

func reset():
	_cleanup_current_room()
	current_grid_pos = Vector2i.ZERO
	_is_transitioning = false

# ---- Doors ------------------------------------------------------------------
func _setup_doors(grid_pos: Vector2i):
	_doors.clear()
	var connections = DungeonManager.get_connected_directions(grid_pos)
	for dir_name in connections:
		var door_instance = _door_scene.instantiate()
		door_instance.direction = dir_name
		door_instance.room_size = Vector2(ROOM_WIDTH, ROOM_HEIGHT)
			# Pass door textures if set
		door_instance.locked_texture = door_locked_texture
		door_instance.unlocked_texture = door_unlocked_texture
		current_room_instance.add_child(door_instance)
		_doors[dir_name] = door_instance
		door_instance.player_entered_door.connect(_on_player_entered_door)

func _lock_doors():
	for door in _doors.values():
		door.lock()
	doors_locked.emit()

func _unlock_doors():
	for door in _doors.values():
		door.unlock()
	doors_unlocked.emit()

# ---- Enemies ----------------------------------------------------------------
func _spawn_enemies(room_info: DungeonManager.RoomInfo):
	_active_enemies.clear()

	# Gather spawn points from the room template
	var spawn_points = _get_spawn_points()
	if spawn_points.is_empty():
		# Fallback: random positions inside the room
		spawn_points = _generate_fallback_spawns(3 + room_info.difficulty)

	# Determine enemy count based on difficulty
	var count = clampi(2 + room_info.difficulty, 2, spawn_points.size())

	# Shuffle and pick
	spawn_points.shuffle()
	for i in range(count):
		var pos: Vector2 = spawn_points[i % spawn_points.size()]
		_spawn_single_enemy(pos, room_info.difficulty)

func _spawn_single_enemy(pos: Vector2, difficulty: int):
	var enemy = _enemy_scene.instantiate()
	enemy.global_position = pos

	# Scale with difficulty
	var health_mult = 1.0 + difficulty * 0.25
	var speed_mult  = 1.0 + difficulty * 0.08
	enemy.move_speed *= speed_mult
	if enemy.has_node("HealthComponent"):
		var hc = enemy.get_node("HealthComponent")
		hc.max_health *= health_mult
		hc.current_health = hc.max_health

	current_room_instance.add_child(enemy)
	_active_enemies.append(enemy)
	enemy.tree_exiting.connect(_on_enemy_died.bind(enemy))

func _spawn_boss(room_info: DungeonManager.RoomInfo):
	_active_enemies.clear()

	var room_center = Vector2(ROOM_WIDTH / 2.0, ROOM_HEIGHT / 2.0)
	var boss_scene = _pick_boss_scene()
	var boss = boss_scene.instantiate()
	boss.global_position = room_center

	# Scale boss with dungeon level
	var level = DungeonManager.dungeon_level
	var health_mult = 1.0 + (level - 1) * 0.5
	var damage_mult = 1.0 + (level - 1) * 0.3
	var speed_mult = 1.0 + (level - 1) * 0.1
	boss.move_speed *= speed_mult
	boss.damage *= damage_mult
	if boss.has_node("HealthComponent"):
		var hc = boss.get_node("HealthComponent")
		hc.max_health *= health_mult
		hc.current_health = hc.max_health

	current_room_instance.add_child(boss)
	_active_enemies.append(boss)
	boss.tree_exiting.connect(_on_enemy_died.bind(boss))

	# Notify UI so the boss health bar can appear
	boss_spawned.emit(boss)

	print("RoomManager: Boss '", boss.boss_name, "' spawned for dungeon level ", level)

func _spawn_trapdoor():
	var room_center = Vector2(ROOM_WIDTH / 2.0, ROOM_HEIGHT / 2.0)
	var trapdoor = Trapdoor.new()
	trapdoor.position = room_center
	current_room_instance.add_child(trapdoor)
	trapdoor.player_entered_trapdoor.connect(_on_trapdoor_entered)
	print("RoomManager: Trapdoor spawned at room center")

func _on_trapdoor_entered():
	trapdoor_entered.emit()

func _on_enemy_died(enemy: Node):
	_active_enemies.erase(enemy)
	# Check if room is now clear
	if _active_enemies.is_empty():
		DungeonManager.mark_cleared(current_grid_pos)
		_unlock_doors()
		room_cleared.emit(current_grid_pos)

		# If this was the boss room, spawn trapdoor and emit boss signal
		var room_info = DungeonManager.get_room_info(current_grid_pos)
		if room_info and room_info.is_boss_room:
			_spawn_trapdoor()
			boss_room_cleared.emit(current_grid_pos)

func _get_spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	if not current_room_instance:
		return points
	var spawn_container = current_room_instance.get_node_or_null("SpawnPoints")
	if spawn_container:
		for child in spawn_container.get_children():
			if child is Marker2D:
				points.append(child.global_position)
	return points

func _generate_fallback_spawns(count: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var margin = 100.0
	for i in range(count):
		var x = randf_range(margin, ROOM_WIDTH - margin)
		var y = randf_range(margin, ROOM_HEIGHT - margin)
		points.append(Vector2(x, y))
	return points

# ---- Room state persistence --------------------------------------------------

## Save every dynamic entity in the current room so it can be restored later.
func _save_room_state():
	if not current_room_instance or not is_instance_valid(current_room_instance):
		return
	var room_info = DungeonManager.get_room_info(current_grid_pos)
	if not room_info:
		return

	room_info.saved_entities.clear()

	# XP orbs
	for orb in get_tree().get_nodes_in_group("xp_orb"):
		if not is_instance_valid(orb):
			continue
		room_info.saved_entities.append({
			"type": "xp_orb",
			"position": orb.global_position,
			"xp_amount": orb.xp_amount,
		})

	# Generic ground items (any node in "ground_item" group)
	for item in get_tree().get_nodes_in_group("ground_item"):
		if not is_instance_valid(item):
			continue
		var data: Dictionary = {
			"type": "ground_item",
			"position": item.global_position,
			"scene_path": item.scene_file_path,
		}
		if item.has_method("get_save_data"):
			data.merge(item.get_save_data())
		room_info.saved_entities.append(data)

	# Chests (any node in "chest" group)
	for chest in get_tree().get_nodes_in_group("chest"):
		if not is_instance_valid(chest):
			continue
		var data: Dictionary = {
			"type": "chest",
			"position": chest.global_position,
			"scene_path": chest.scene_file_path,
		}
		if chest.has_method("get_save_data"):
			data.merge(chest.get_save_data())
		room_info.saved_entities.append(data)

## Recreate entities that were saved when the player previously left this room.
func _restore_room_state(room_info: DungeonManager.RoomInfo):
	if room_info.saved_entities.is_empty():
		return

	var xp_orb_scene = preload("res://scenes/game/XPOrb.tscn")

	for entity_data in room_info.saved_entities:
		match entity_data.type:
			"xp_orb":
				var orb = xp_orb_scene.instantiate()
				orb.global_position = entity_data.position
				orb.xp_amount = entity_data.xp_amount
				current_room_instance.add_child(orb)
			"ground_item", "chest":
				if entity_data.has("scene_path") and entity_data.scene_path != "":
					var scene = load(entity_data.scene_path)
					if scene:
						var node = scene.instantiate()
						node.global_position = entity_data.position
						if node.has_method("apply_save_data"):
							node.apply_save_data(entity_data)
						current_room_instance.add_child(node)

	room_info.saved_entities.clear()

# ---- Cleanup ----------------------------------------------------------------
func _cleanup_current_room():
	_save_room_state()
	_active_enemies.clear()
	_doors.clear()
	if current_room_instance and is_instance_valid(current_room_instance):
		current_room_instance.queue_free()
		current_room_instance = null

# ---- Door callback ----------------------------------------------------------
func _on_player_entered_door(direction: String):
	transition_to_room(direction)
