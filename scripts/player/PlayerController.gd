extends CharacterBody2D

# Components
@onready var health_component = $HealthComponent
@onready var stats_component = $StatsComponent

var is_alive: bool = true
var is_invulnerable: bool = false

# --- DASH SETTINGS ---
@export var dash_distance: float = 140.0
@export var dash_duration: float = 0.12
@export var dash_cooldown: float = 0.35

# Set this to the physics layer(s) your walls are on.
# Example: if walls are on layer 1 -> 1 << 0
#          if walls are on layer 2 -> 1 << 1
@export var dash_wall_mask: int = 1 << 0

var _last_move_dir: Vector2 = Vector2.RIGHT
var _is_dashing: bool = false
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_velocity: Vector2 = Vector2.ZERO


func _ready():
	# Register with GameManager
	GameManager.player = self
	add_to_group("player")

	# Sync stats with components FIRST
	if stats_component and health_component:
		health_component.max_health = stats_component.max_health
		health_component.current_health = stats_component.max_health
		health_component.health_changed.emit(health_component.current_health, health_component.max_health)

	# Connect to health component signals
	if health_component:
		health_component.died.connect(_on_died)

	print("Player ready!")


func _physics_process(delta):
	if not is_alive:
		return

	# Cooldowns tick
	_dash_cooldown_left = max(0.0, _dash_cooldown_left - delta)

	# If dashing, override normal movement
	if _is_dashing:
		_dash_time_left -= delta
		velocity = _dash_velocity
		move_and_slide()

		if _dash_time_left <= 0.0:
			_is_dashing = false
			is_invulnerable = false
		return

	# Get input direction
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Remember last non-zero move direction (used when dashing from standstill)
	if input_direction.length() > 0.01:
		_last_move_dir = input_direction.normalized()

	# Dash input (press)
	if Input.is_action_just_pressed("dash"):
		_try_dash(input_direction)
		# If dash started, skip normal movement this frame
		if _is_dashing:
			velocity = _dash_velocity
			move_and_slide()
			return

	# Normal movement
	var current_speed = stats_component.move_speed if stats_component else 300.0
	velocity = input_direction * current_speed
	move_and_slide()


func _process(delta):
	if not is_alive or not health_component or not stats_component:
		return

	# Apply health regeneration
	if stats_component.health_regen_per_second > 0:
		health_component.heal(stats_component.health_regen_per_second * delta)


func _try_dash(input_direction: Vector2) -> void:
	if _dash_cooldown_left > 0.0:
		return

	var dir := input_direction
	if dir.length() < 0.01:
		dir = _last_move_dir
	dir = dir.normalized()

	# Clamp dash distance if a wall is in front
	var allowed_dist := _get_allowed_dash_distance(dir, dash_distance)
	if allowed_dist < 4.0:
		return # basically blocked / hugging a wall

	_is_dashing = true
	is_invulnerable = true
	_dash_time_left = dash_duration
	_dash_cooldown_left = dash_cooldown

	var dash_speed := allowed_dist / dash_duration
	_dash_velocity = dir * dash_speed


func _get_allowed_dash_distance(dir: Vector2, desired_dist: float) -> float:
	var from := global_position
	var to := global_position + dir * desired_dist

	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = dash_wall_mask
	query.exclude = [self]
	query.hit_from_inside = true

	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return desired_dist

	var hit_pos: Vector2 = result.position
	var dist := from.distance_to(hit_pos)

	# Keep a small margin so we don't end inside the wall
	return max(0.0, dist - 6.0)


func take_damage(amount: float):
	if health_component && is_invulnerable==false:
		health_component.take_damage(amount)


func _on_died():
	is_alive = false
	print("Player died!")
	GameManager.end_game()
	modulate.a = 0.5


# Helper for abilities to get stats
func get_stat(stat_name: String) -> float:
	if stats_component:
		return stats_component.get_stat(stat_name)
	return 0.0
