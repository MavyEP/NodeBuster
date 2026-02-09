extends Node

# Signals
signal experience_gained(amount)
signal level_up(new_level)

# XP System
var current_xp: int = 0
var current_level: int = 1
var xp_to_next_level: int = 10

# XP curve - gets harder each level
var xp_base: int = 10
var xp_multiplier: float = 1.5

func _ready():
	print("ExperienceManager initialized")
	calculate_xp_requirement()

func add_experience(amount: int):
	current_xp += amount
	experience_gained.emit(amount)
	
	print("Gained ", amount, " XP! (", current_xp, "/", xp_to_next_level, ")")
	
	# Check if leveled up
	while current_xp >= xp_to_next_level:
		level_up_player()

func level_up_player():
	current_xp -= xp_to_next_level
	current_level += 1
	
	calculate_xp_requirement()
	
	print("LEVEL UP! Now level ", current_level)
	level_up.emit(current_level)
	
	# Pause game for upgrade selection
	get_tree().paused = true

func calculate_xp_requirement():
	# Formula: each level requires more XP
	xp_to_next_level = int(xp_base * pow(xp_multiplier, current_level - 1))

func reset():
	current_xp = 0
	current_level = 1
	calculate_xp_requirement()
