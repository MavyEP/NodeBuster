extends CharacterBody2D
class_name BaseEnemy

## Shared foundation for all enemy types.
## Handles health, death, XP spawning, and player reference.
## Subclasses override _enemy_ready() and _physics_process() for behavior.

@export var move_speed: float = 150.0
@export var damage: float = 10.0
@export var xp_value: int = 5

@onready var health_component = $HealthComponent

var player: Node2D = null
var is_alive: bool = true

func _ready():
	add_to_group("enemy")
	if health_component:
		health_component.died.connect(_on_died)
	player = GameManager.player
	_enemy_ready()

## Override in subclasses instead of _ready().
func _enemy_ready():
	pass

func take_damage(amount: float):
	if health_component:
		health_component.take_damage(amount)

func _on_died():
	is_alive = false
	GameManager.enemies_killed += 1
	call_deferred("_spawn_xp")
	await get_tree().create_timer(0.1).timeout
	queue_free()

func _spawn_xp():
	var xp_orb_scene = preload("res://scenes/game/XPOrb.tscn")
	var xp_orb = xp_orb_scene.instantiate()
	xp_orb.global_position = global_position
	xp_orb.xp_amount = xp_value
	var room = RoomManager.current_room_instance
	if room and is_instance_valid(room):
		room.add_child(xp_orb)
	else:
		get_tree().root.add_child(xp_orb)
