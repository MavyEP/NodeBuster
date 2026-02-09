extends Node
class_name HealthComponent

# Signals for other systems to listen to
signal health_changed(current_health, max_health)
signal died
signal damaged(amount)

# Health stats
@export var max_health: float = 100.0
var current_health: float

func _ready():
	current_health = max_health
	health_changed.emit(current_health, max_health)

func take_damage(amount: float):
	if current_health <= 0:
		return  # Already dead
	
	current_health -= amount
	current_health = max(0, current_health)  # Don't go below 0
	
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	
	# Check if dead
	if current_health <= 0:
		die()

func heal(amount: float):
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func die():
	died.emit()
	print(get_parent().name, " died!")

func is_alive() -> bool:
	return current_health > 0
	
func increase_max_health(amount: float):
	max_health += amount
	current_health += amount  # Also heal by the amount
	health_changed.emit(current_health, max_health)
	print(get_parent().name, " max health increased to ", max_health)

func set_max_health(new_max: float):
	var health_percentage = current_health / max_health
	max_health = new_max
	current_health = max_health * health_percentage  # Keep same % health
	health_changed.emit(current_health, max_health)
