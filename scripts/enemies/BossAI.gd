extends CharacterBody2D

# Boss stats - stronger than regular enemies
@export var move_speed: float = 100.0  # Slower but tankier
@export var damage: float = 25.0  # Hits harder
@export var xp_value: int = 50  # More XP

# Components
@onready var health_component = $HealthComponent
@onready var hitbox = $Hitbox

var player = null
var is_alive: bool = true

func _ready():
	# Add to boss group
	add_to_group("boss")
	
	# Connect health signals
	if health_component:
		health_component.died.connect(_on_died)
	
	# Connect hitbox
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	# Find player
	player = GameManager.player
	
	print("BOSS SPAWNED!")

func _physics_process(delta):
	if not is_alive or not player or not player.is_alive:
		return
	
	# Chase player (same as regular enemy)
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * move_speed
	rotation = direction.angle()
	move_and_slide()

func take_damage(amount: float):
	if health_component:
		health_component.take_damage(amount)

func _on_hitbox_body_entered(body):
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)

func _on_died():
	is_alive = false
	GameManager.enemies_killed += 1
	
	print("BOSS DEFEATED!")
	
	# Drop legendary reward
	spawn_legendary_reward()
	
	# Spawn extra XP
	for i in range(10):
		spawn_xp()
	
	await get_tree().create_timer(0.1).timeout
	queue_free()

func spawn_xp():
	var xp_orb_scene = preload("res://scenes/game/XPOrb.tscn")
	var xp_orb = xp_orb_scene.instantiate()
	
	# Scatter XP in random directions
	var random_offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
	xp_orb.global_position = global_position + random_offset
	xp_orb.xp_amount = xp_value / 10
	
	get_tree().root.add_child(xp_orb)

func spawn_legendary_reward():
	# For now, just give a powerful upgrade automatically
	# Later we can make a special legendary upgrade selection
	print("Boss dropped legendary reward!")
	
	# Give player a bonus level up
	ExperienceManager.level_up.emit(ExperienceManager.current_level)
