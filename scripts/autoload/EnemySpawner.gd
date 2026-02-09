extends Node

# Spawning settings
@export var base_spawn_interval: float = 2.0
@export var min_spawn_interval: float = 0.5
@export var spawn_distance: float = 600.0  # How far from player to spawn
@export var max_enemies: int = 100  # Performance limit

# Difficulty scaling
var current_spawn_interval: float = 2.0
var enemies_per_spawn: int = 1
var enemy_health_multiplier: float = 1.0
var enemy_speed_multiplier: float = 1.0

# Internal
var spawn_timer: Timer
var enemy_scene = preload("res://scenes/enemies/Enemy.tscn")
var active_enemies: int = 0

func _ready():
	print("EnemySpawner initialized")
	
	# Create spawn timer
	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.wait_time = current_spawn_interval
	spawn_timer.one_shot = false

func start_spawning():
	print("Enemy spawning started!")
	spawn_timer.start()
	GameManager.is_game_running = true

func stop_spawning():
	spawn_timer.stop()

func _process(delta):
	if not GameManager.is_game_running:
		return
	
	# Scale difficulty over time
	scale_difficulty()

func scale_difficulty():
	var time = GameManager.current_time
	
	# Every 30 seconds, increase difficulty
	var difficulty_tier = int(time / 30.0)
	
	# Spawn faster (but not too fast)
	current_spawn_interval = max(min_spawn_interval, base_spawn_interval - (difficulty_tier * 0.2))
	spawn_timer.wait_time = current_spawn_interval
	
	# More enemies per spawn
	enemies_per_spawn = 1 + int(difficulty_tier / 2)
	
	# Stronger enemies
	enemy_health_multiplier = 1.0 + (difficulty_tier * 0.3)
	enemy_speed_multiplier = 1.0 + (difficulty_tier * 0.1)

func _on_spawn_timer_timeout():
	if not GameManager.player or not GameManager.player.is_alive:
		return
	
	if active_enemies >= max_enemies:
		return  # Don't spawn more if at limit
	
	# Spawn multiple enemies
	for i in range(enemies_per_spawn):
		spawn_enemy()

func spawn_enemy():
	var enemy = enemy_scene.instantiate()
	
	# Spawn at random position around player
	var player_pos = GameManager.player.global_position
	var random_angle = randf() * TAU  # Random angle (0 to 2π)
	var spawn_pos = player_pos + Vector2(cos(random_angle), sin(random_angle)) * spawn_distance
	
	enemy.global_position = spawn_pos
	
	# Apply difficulty scaling
	enemy.move_speed *= enemy_speed_multiplier
	if enemy.has_node("HealthComponent"):
		enemy.get_node("HealthComponent").max_health *= enemy_health_multiplier
	
	# Add to scene
	get_tree().root.add_child(enemy)
	active_enemies += 1
	
	# Track when enemy dies
	enemy.tree_exited.connect(_on_enemy_died)

func _on_enemy_died():
	active_enemies -= 1
