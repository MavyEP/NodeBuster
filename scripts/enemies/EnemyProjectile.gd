extends Area2D

## Projectile fired by ranged enemies. Damages the player on contact,
## destroyed on hitting walls.

@export var speed: float = 300.0
@export var damage: float = 8.0
@export var lifetime: float = 4.0

var _has_hit := false

func _ready():
	add_to_group("enemy_projectile")
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree():
		queue_free()

func _process(delta):
	position += transform.x * speed * delta

func _on_body_entered(body):
	if _has_hit:
		return
	_has_hit = true
	set_deferred("monitoring", false)

	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)

	queue_free()
