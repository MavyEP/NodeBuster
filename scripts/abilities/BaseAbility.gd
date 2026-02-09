extends Node
class_name BaseAbility

# Ability info
@export var ability_name: String = "Base Ability"
@export var max_level: int = 5

# Current state
var current_level: int = 1
var cooldown_timer: Timer

# Reference to player
var player: CharacterBody2D

func _ready():
	# Get player reference
	player = get_parent().get_parent()  # Ability → AbilityContainer → Player
	
	# Create cooldown timer
	cooldown_timer = Timer.new()
	add_child(cooldown_timer)
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	cooldown_timer.one_shot = false
	
	# Initialize the ability
	initialize()
	
	# Register with AbilityManager (ADD THIS LINE)
	AbilityManager.register_ability(self)

# Override this in child abilities
func initialize():
	pass

# Override this in child abilities - called when cooldown expires
func activate():
	pass

func level_up():
	if current_level < max_level:
		current_level += 1
		on_level_up()
		print(ability_name, " leveled up to ", current_level)

# Override this to apply level-up effects
func on_level_up():
	pass

func _on_cooldown_timeout():
	activate()

# Helper: Find nearest enemy WITHIN DETECTION RADIUS
func find_nearest_enemy() -> CharacterBody2D:
	if not player:
		return null
	
	var detection_range = player.get_stat("detection_radius")
	var enemies = get_tree().get_nodes_in_group("enemy")
	var nearest_enemy = null
	var nearest_distance = INF
	
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			var distance = player.global_position.distance_to(enemy.global_position)
			
			# Only consider enemies within detection radius
			if distance <= detection_range and distance < nearest_distance:
				nearest_distance = distance
				nearest_enemy = enemy
	
	return nearest_enemy

# Helper: Find all enemies within range
func find_enemies_in_range(range_radius: float) -> Array:
	if not player:
		return []
	
	var enemies = get_tree().get_nodes_in_group("enemy")
	var enemies_in_range = []
	
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			var distance = player.global_position.distance_to(enemy.global_position)
			if distance <= range_radius:
				enemies_in_range.append(enemy)
	
	return enemies_in_range
