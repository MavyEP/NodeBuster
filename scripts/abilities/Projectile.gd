extends Area2D

@export var speed: float = 500.0
@export var damage: float = 20.0
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var target: Node2D = null

var _has_hit := false

func _ready():
	
	add_to_group("projectile")
		
	# Connect collision
	body_entered.connect(_on_body_entered)
	
	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _process(delta):
	# If we have a target, home in on it

	# Move in direction
	position += transform.x  * speed * delta
	

func setup(start_pos: Vector2, target_enemy: Node2D, projectile_damage: float):
	global_position = start_pos
	target = target_enemy
	damage = projectile_damage
	
	if target:
		direction = (target.global_position - global_position).normalized()

func _on_body_entered(body):
	if _has_hit:
		return

	_has_hit = true

	# Disable further collisions instantly (prevents double-hit same frame)

	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	
	if  (body and (body.is_in_group("enemy") or body.is_in_group("boss")) and body.has_method("take_damage")):
		body.take_damage(damage)
	elif (body and body.is_in_group("player")):
		return
		
	
	queue_free()
