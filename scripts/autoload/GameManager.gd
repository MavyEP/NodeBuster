extends Node

# Signals
signal game_ended

# Game state
var is_game_running: bool = false
var current_time: float = 0.0
var enemies_killed: int = 0

# Player reference
var player = null

func _ready():
	print("GameManager initialized")

func start_game():
	
	# Clean up any leftover entities
	cleanup_game()
	
	is_game_running = true
	current_time = 0.0
	enemies_killed = 0
	
	# Reset systems
	ExperienceManager.reset()
	BossManager.reset()
	UpgradeManager.reset()
	AbilityManager.reset()
	
	# Start enemy spawning
	EnemySpawner.start_spawning()
	
	# Unpause
	get_tree().paused = false
	
	print("Game started!")

func end_game():
	is_game_running = false
	EnemySpawner.stop_spawning()
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
	
	# Remove all projectiles (if they have a group)
	for projectile in get_tree().get_nodes_in_group("projectile"):
		if is_instance_valid(projectile):
			projectile.queue_free()
	
	# Remove all XP orbs
	var orbs = get_tree().get_nodes_in_group("xp_orb")
	for orb in orbs:
		if is_instance_valid(orb):
			orb.queue_free()
	
	print("Game cleaned up")
