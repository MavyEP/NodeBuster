extends Node

# Boss spawning settings
@export var boss_interval: float = 300.0  # 5 minutes in seconds (5 * 60)

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
			pass  # wait until boss is dead
		else:
			spawn_boss()
			next_boss_time += boss_interval

func spawn_boss():
	if not GameManager.player or not GameManager.player.is_alive:
		return

	bosses_spawned += 1
	print("=== BOSS #", bosses_spawned, " SPAWNING at ", format_time(GameManager.current_time), " ===")

	var boss = boss_scene.instantiate()

	# Spawn inside the current room at a random spawn point
	var room_center = Vector2(RoomManager.ROOM_WIDTH / 2.0, RoomManager.ROOM_HEIGHT / 2.0)
	var offset = Vector2(randf_range(-200, 200), randf_range(-200, 200))
	boss.global_position = room_center + offset

	# Scale boss difficulty based on boss number
	scale_boss_difficulty(boss, bosses_spawned)

	# Track the boss
	active_boss = boss
	boss.tree_exited.connect(_on_boss_defeated)

	# Add to the current room container
	if RoomManager.current_room_instance and is_instance_valid(RoomManager.current_room_instance):
		RoomManager.current_room_instance.add_child(boss)
		# Also track as room enemy so doors stay locked
		RoomManager._active_enemies.append(boss)
		boss.tree_exiting.connect(RoomManager._on_enemy_died.bind(boss))
	else:
		get_tree().root.add_child(boss)

func scale_boss_difficulty(boss, boss_number: int):
	var health_multiplier = 1.0 + ((boss_number - 1) * 0.5)
	var damage_multiplier = 1.0 + ((boss_number - 1) * 0.3)
	var speed_multiplier = 1.0 + ((boss_number - 1) * 0.1)

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
