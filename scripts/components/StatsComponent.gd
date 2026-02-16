extends Node
class_name StatsComponent

# Signal when stats change
signal stats_changed

# Base stats
@export var max_health: float = 100.0
@export var move_speed: float = 200.0


# Ability-related stats
@export var detection_radius: float = 400.0  # How far abilities can "see" enemies
@export var pickup_radius: float = 100.0    # How far XP orbs get attracted

# Regeneration
@export var health_regen_per_second: float = 0.0

# Get current stat values
func get_stat(stat_name: String) -> float:
	match stat_name:
		"max_health": return max_health
		"move_speed": return move_speed
		"detection_radius": return detection_radius
		"pickup_radius": return pickup_radius
		"health_regen": return health_regen_per_second
		_: return 0.0

# Modify a stat
func modify_stat(stat_name: String, amount: float):
	match stat_name:
		"max_health":
			max_health += amount
		"move_speed":
			move_speed += amount
		"detection_radius":
			detection_radius += amount
			print("Detection radius increased to ", detection_radius)
		"pickup_radius":
			pickup_radius += amount
			print("Pickup radius increased to ", pickup_radius)
		"health_regen":
			health_regen_per_second += amount
			print("Health regen increased to ", health_regen_per_second, "/s")
	
	stats_changed.emit()
