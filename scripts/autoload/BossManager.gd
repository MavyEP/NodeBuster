extends Node

# Boss spawning settings
@export var boss_interval: float = 300.0  # 5 minutes in seconds (5 * 60)
@export var spawn_distance: float = 700.0

var boss_scene = preload("res://scenes/enemies/Boss.tscn")
var active_boss = null

# Track boss spawning
var next_boss_time: float = 300.0  # First boss at 5 minutes
var bosses_spawned: int = 0

func _ready():
	print("BossManager initialized - First boss at 5:00")

func _process(delta):
	if not GameManager.is_game_running:
		return
	
	# Check if it's time to spawn a boss
	if GameManager.current_time >= next_boss_time:
		# Check if there's already a boss alive
		if active_boss and is_instance_valid(active_boss):
			print("Boss still alive at ", format_time(next_boss_time), ", waiting...")
			# Don't increment time, wait until boss is dead
		else:
			# Spawn the boss
			spawn_boss()
			
			# Set next boss spawn time
			next_boss_time += boss_interval

func spawn_boss():
	bosses_spawned += 1
	
	print("=== BOSS #", bosses_spawned, " SPAWNING at ", format_time(GameManager.current_time), " ===")
	
	var boss = boss_scene.instantiate()
	
	# Spawn at random position around player
	var player_pos = GameManager.player.global_position
	var random_angle = randf() * TAU
	var spawn_pos = player_pos + Vector2(cos(random_angle), sin(random_angle)) * spawn_distance
	
	boss.global_position = spawn_pos
	
	# Scale boss difficulty based on boss number
	scale_boss_difficulty(boss, bosses_spawned)
	
	# Track the boss
	active_boss = boss
	boss.tree_exited.connect(_on_boss_defeated)
	
	# Add to scene
	get_tree().root.add_child(boss)

func scale_boss_difficulty(boss, boss_number: int):
	# Each boss gets progressively stronger
	var health_multiplier = 1.0 + ((boss_number - 1) * 0.5)  # +50% HP per boss
	var damage_multiplier = 1.0 + ((boss_number - 1) * 0.3)  # +30% damage per boss
	var speed_multiplier = 1.0 + ((boss_number - 1) * 0.1)   # +10% speed per boss
	
	# Apply scaling
	boss.move_speed *= speed_multiplier
	boss.damage *= damage_multiplier
	
	if boss.has_node("HealthComponent"):
		var health_comp = boss.get_node("HealthComponent")
		health_comp.max_health *= health_multiplier
		health_comp.current_health = health_comp.max_health
	
	print("Boss #", boss_number, " scaled: HP x", health_multiplier, ", DMG x", damage_multiplier, ", SPD x", speed_multiplier)

func _on_boss_defeated():
	print("Boss #", bosses_spawned, " defeated! Next boss at ", format_time(next_boss_time))
	active_boss = null

func format_time(seconds: float) -> String:
	var mins = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%d:%02d" % [mins, secs]

func reset():
	next_boss_time = boss_interval
	bosses_spawned = 0
	active_boss = null
