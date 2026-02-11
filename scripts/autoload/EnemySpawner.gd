extends Node

## EnemySpawner is now a thin helper.
## Room-based spawning is handled by RoomManager.
## This autoload is kept for compatibility and provides the enemy scene
## plus any shared difficulty scaling utilities that other systems need.

var enemy_scene = preload("res://scenes/enemies/Enemy.tscn")
var active_enemies: int = 0

func _ready():
	print("EnemySpawner initialized (room-based mode)")

func start_spawning():
	# No-op in room-based mode — RoomManager drives spawning per room.
	pass

func stop_spawning():
	pass

func _on_enemy_died():
	active_enemies = max(0, active_enemies - 1)
