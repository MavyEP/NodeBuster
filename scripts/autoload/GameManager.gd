extends Node

# Signals
signal game_ended
signal dungeon_level_changed(new_level: int)

# Game state
var is_game_running: bool = false
var current_time: float = 0.0
var enemies_killed: int = 0
var dungeon_level: int = 1

# Player reference
var player = null

func _ready():
	print("GameManager initialized")

func start_game(int):
	# Clean up any leftover entities
	cleanup_game()
	is_game_running = true
	if int == 1:
			
	
		current_time = 0.0
		enemies_killed = 0
		dungeon_level = 1
		DungeonManager.dungeon_level = 1

		# Reset systems
		ExperienceManager.reset()
		BossManager.reset()
		UpgradeManager.reset()
		#DungeonManager.reset()
		#RoomManager.reset()

	# Unpause
	get_tree().paused = false

	print("Game started!")

func advance_dungeon_level():
	dungeon_level += 1
	DungeonManager.dungeon_level = dungeon_level
	print("=== ADVANCING TO DUNGEON LEVEL ", dungeon_level, " ===")
	dungeon_level_changed.emit(dungeon_level)

func end_game():
	is_game_running = false
	print("Game ended! Time survived: ", current_time, "s, Enemies killed: ", enemies_killed)

	# Emit signal for UI
	game_ended.emit()

func _process(delta):
	if is_game_running:
		current_time += delta

func cleanup_game():
	# Remove all enemies
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy):
			enemy.queue_free()

	# Remove all bosses
	for boss in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(boss):
			boss.queue_free()

	# Remove all projectiles
	for projectile in get_tree().get_nodes_in_group("projectile"):
		if is_instance_valid(projectile):
			projectile.queue_free()

	# Remove all enemy projectiles
	for proj in get_tree().get_nodes_in_group("enemy_projectile"):
		if is_instance_valid(proj):
			proj.queue_free()

	# Remove all XP orbs
	var orbs = get_tree().get_nodes_in_group("xp_orb")
	for orb in orbs:
		if is_instance_valid(orb):
			orb.queue_free()

	print("Game cleaned up")
