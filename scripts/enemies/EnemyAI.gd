extends BaseEnemy

## Melee enemy — chases the player and deals contact damage.

@onready var hitbox = $Hitbox

# Contact damage tick
var _target_in_hitbox: Node2D = null
var _damage_tick_timer: float = 0.0
const DAMAGE_TICK_INTERVAL: float = 0.5

func _enemy_ready():
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		hitbox.body_exited.connect(_on_hitbox_body_exited)

func _physics_process(delta):
	if not is_alive or not player or not player.is_alive:
		return

	# Chase the player
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()

	# Tick contact damage while overlapping
	if _target_in_hitbox and is_instance_valid(_target_in_hitbox):
		_damage_tick_timer -= delta
		if _damage_tick_timer <= 0.0:
			_target_in_hitbox.take_damage(damage)
			_damage_tick_timer = DAMAGE_TICK_INTERVAL

func _on_hitbox_body_entered(body):
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		_target_in_hitbox = body
		_damage_tick_timer = DAMAGE_TICK_INTERVAL

func _on_hitbox_body_exited(body):
	if body == _target_in_hitbox:
		_target_in_hitbox = null
