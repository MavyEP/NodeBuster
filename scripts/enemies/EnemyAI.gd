extends CharacterBody2D

# Enemy stats
@export var move_speed: float = 150.0
@export var damage: float = 10.0
@export var xp_value: int = 5

# Components
@onready var health_component = $HealthComponent
@onready var hitbox = $Hitbox

@export var turn_speed: float = 12.0 # bigger = faster turning

var player = null
var is_alive: bool = true

var _target_in_hitbox: Node2D = null
var _damage_tick_timer: float = 0.0
const DAMAGE_TICK_INTERVAL: float = 0.5  

func _ready():
	
	add_to_group("enemy")
	# Connect health signals
	if health_component:
		health_component.died.connect(_on_died)
	
	# Connect hitbox for collisions with player
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		hitbox.body_exited.connect(_on_hitbox_body_exited)
	# Find player
	player = GameManager.player

func _physics_process(delta):
	if not is_alive or not player or not player.is_alive:
		return
	
	# Chase the player
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * move_speed

	
	# Move
	move_and_slide()
	
	 # Contact damage tick
	if _target_in_hitbox and is_instance_valid(_target_in_hitbox):
		_damage_tick_timer -= delta
		if _damage_tick_timer <= 0.0:
			_target_in_hitbox.take_damage(damage)
			_damage_tick_timer = DAMAGE_TICK_INTERVAL

func take_damage(amount: float):
	if health_component:
		health_component.take_damage(amount)

func _on_hitbox_body_entered(body):
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		_target_in_hitbox = body
		_damage_tick_timer = DAMAGE_TICK_INTERVAL  # reset timer so next tick waits the full interval

func _on_hitbox_body_exited(body):
	if body == _target_in_hitbox:
		_target_in_hitbox = null


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
