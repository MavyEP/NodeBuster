extends CharacterBody2D

# Components
@onready var health_component = $HealthComponent
@onready var stats_component = $StatsComponent

var is_alive: bool = true

func _ready():
	# Register with GameManager
	GameManager.player = self
	add_to_group("player")

	# Sync stats with components FIRST
	if stats_component and health_component:
		# Set health from stats
		health_component.max_health = stats_component.max_health
		health_component.current_health = stats_component.max_health

		# Emit initial health signal for UI
		health_component.health_changed.emit(health_component.current_health, health_component.max_health)

	# Connect to health component signals
	if health_component:
		health_component.died.connect(_on_died)

	print("Player ready!")

func _physics_process(delta):
	if not is_alive:
		return

	# Get input direction
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Use move_speed from stats
	var current_speed = stats_component.move_speed if stats_component else 300.0
	velocity = input_direction * current_speed

	# Move the player
	move_and_slide()

	# Rotate player to face movement direction
	if input_direction.length() > 0:
		rotation = input_direction.angle()

func _process(delta):
	if not is_alive or not health_component or not stats_component:
		return

	# Apply health regeneration
	if stats_component.health_regen_per_second > 0:
		health_component.heal(stats_component.health_regen_per_second * delta)

func take_damage(amount: float):
	if health_component:
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
