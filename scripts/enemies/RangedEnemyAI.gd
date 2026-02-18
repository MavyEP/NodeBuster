extends BaseEnemy

## Ranged enemy — keeps distance from the player and shoots projectiles
## when it has clear line of sight.

@export var preferred_range: float = 150.0   # tries to stay this far from player
@export var fire_rate: float = 1.5           # seconds between shots
@export var projectile_speed: float = 300.0
@export var projectile_damage: float = 8.0

# Contact damage tick
var _target_in_hitbox: Node2D = null
var _damage_tick_timer: float = 0.0
const DAMAGE_TICK_INTERVAL: float = 0.5

var _fire_timer: float = 0.0
var _enemy_projectile_scene = preload("res://scenes/enemies/EnemyProjectile.tscn")

func _physics_process(delta):
	if not is_alive or not player or not player.is_alive:
		return
	
	var to_player = player.global_position - global_position
	var dist = to_player.length()
	var dir = to_player.normalized()
	
	# Tick contact damage while overlapping
	if _target_in_hitbox and is_instance_valid(_target_in_hitbox):
		_damage_tick_timer -= delta
		if _damage_tick_timer <= 0.0:
			_target_in_hitbox.take_damage(damage)
			_damage_tick_timer = DAMAGE_TICK_INTERVAL
			
	# Keep distance — approach if too far, back off if too close
	if dist > preferred_range + 20.0:
		velocity = dir * move_speed
	elif dist < preferred_range - 20.0:
		velocity = -dir * move_speed * 0.5
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	# Shoot on cooldown if line of sight is clear
	_fire_timer -= delta
	if _fire_timer <= 0.0 and _has_line_of_sight():
		_shoot(dir)
		_fire_timer = fire_rate

func _has_line_of_sight() -> bool:
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position, player.global_position
	)
	query.collision_mask = 1   # walls on layer 1
	query.exclude = [self]
	var result = space.intersect_ray(query)
	# Clear LOS if ray hits nothing before player, or hits the player itself
	return result.is_empty() or result.collider == player

func _shoot(dir: Vector2):
	var proj = _enemy_projectile_scene.instantiate()
	proj.global_position = global_position
	proj.rotation = dir.angle()
	proj.speed = projectile_speed
	proj.damage = projectile_damage
	var room = RoomManager.current_room_instance
	if room and is_instance_valid(room):
		room.add_child(proj)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		_target_in_hitbox = body
		_damage_tick_timer = DAMAGE_TICK_INTERVAL


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == _target_in_hitbox:
		_target_in_hitbox = null
