extends Area2D

@export var speed: float = 500.0
@export var damage: float = 20.0
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var target: Node2D = null

func _ready():
	
	add_to_group("projectile")
		
	# Connect collision
	body_entered.connect(_on_body_entered)
	
	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _process(delta):
	# If we have a target, home in on it
	if target and is_instance_valid(target):
		direction = (target.global_position - global_position).normalized()
	
	# Move in direction
	global_position += direction * speed * delta
	
	# Rotate to face direction
	rotation = direction.angle()

func setup(start_pos: Vector2, target_enemy: Node2D, projectile_damage: float):
	global_position = start_pos
	target = target_enemy
	damage = projectile_damage
	
	if target:
		direction = (target.global_position - global_position).normalized()

func _on_body_entered(body):
	# Hit an enemy
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()  # Destroy projectile on hit
