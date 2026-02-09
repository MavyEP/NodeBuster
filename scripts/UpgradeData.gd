extends Resource
class_name UpgradeData

# Visual
@export var upgrade_name: String = "Upgrade"
@export var description: String = "Does something cool"
@export var icon_color: Color = Color.WHITE

# Upgrade Type
enum UpgradeType {
	STAT_BOOST,      # Increases player stats (health, speed)
	ABILITY_LEVEL,   # Levels up an existing ability
	UNLOCK_ABILITY   # Unlocks a new ability
}

@export var upgrade_type: UpgradeType = UpgradeType.STAT_BOOST

# For STAT_BOOST type
@export_group("Stat Modifications")
@export var max_health_bonus: float = 0
@export var move_speed_bonus: float = 0
@export var pickup_range_bonus: float = 0
@export var detection_range_bonus: float = 0 
@export var health_regen_bonus: float = 0

# For ABILITY_LEVEL or UNLOCK_ABILITY type
@export_group("Ability Info")
@export var ability_name: String = ""  # e.g. "Fireball", "TomeOfArea"
@export var ability_script_path: String = ""  # e.g. "res://scripts/abilities/FireballAbility.gd"

# Stacking
@export_group("Stacking")
@export var can_stack: bool = true
@export var max_stacks: int = 5
