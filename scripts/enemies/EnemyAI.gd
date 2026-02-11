extends CharacterBody2D

# Enemy stats
@export var move_speed: float = 150.0
@export var damage: float = 10.0
@export var xp_value: int = 5

# Components
@onready var health_component = $HealthComponent
@onready var hitbox = $Hitbox

var player = null
var is_alive: bool = true

func _ready():
	
	add_to_group("enemy")
	# Connect health signals
	if health_component:
		health_component.died.connect(_on_died)
	
	# Connect hitbox for collisions with player
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	# Find player
	player = GameManager.player

func _physics_process(delta):
	if not is_alive or not player or not player.is_alive:
		return
	
	# Chase the player
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * move_speed
	
	# Face the player
	rotation = direction.angle()
	
	# Move
	move_and_slide()

func take_damage(amount: float):
	if health_component:
		health_component.take_damage(amount)

func _on_hitbox_body_entered(body):
	# If we hit the player, damage them
	body.take_damage(damage)

func _on_died():
	is_alive = false
	GameManager.enemies_killed += 1
	
	# Spawn XP orb
	call_deferred("spawn_xp")
	
	# Die with a small delay (for future death animation)
	await get_tree().create_timer(0.1).timeout
	queue_free()

func spawn_xp():
	var xp_orb_scene = preload("res://scenes/game/XPOrb.tscn")
	var xp_orb = xp_orb_scene.instantiate()
	xp_orb.global_position = global_position
	xp_orb.xp_amount = xp_value
	var room = RoomManager.current_room_instance
	if room and is_instance_valid(room):
		room.add_child(xp_orb)
	else:
		get_tree().root.add_child(xp_orb)
