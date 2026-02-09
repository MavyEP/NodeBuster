extends Node

# Available upgrades in the game (loaded from resources folder)
var all_upgrades: Array[UpgradeData] = []
var player_upgrades: Dictionary = {}  # upgrade_name: stack_count

func _ready():
	print("UpgradeManager initialized")
	load_upgrades_from_resources()

func load_upgrades_from_resources():
	# Load all upgrade .tres files from the resources/upgrades folder
	var upgrades_path = "res://resources/upgrades/"
	
	# Load stat upgrades
	load_upgrades_from_folder(upgrades_path + "stats/")
	
	# Load ability upgrades
	load_upgrades_from_folder(upgrades_path + "abilities/")
	
	print("Loaded ", all_upgrades.size(), " upgrades from resource files")

func load_upgrades_from_folder(folder_path: String):
	var dir = DirAccess.open(folder_path)
	
	if not dir:
		print("Warning: Could not open upgrades folder: ", folder_path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		# Only load .tres files
		if file_name.ends_with(".tres"):
			var full_path = folder_path + file_name
			var upgrade = load(full_path) as UpgradeData
			
			if upgrade:
				all_upgrades.append(upgrade)
				print("  Loaded upgrade: ", upgrade.upgrade_name, " from ", file_name)
			else:
				print("  Warning: Failed to load ", full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func get_random_upgrades(count: int = 3) -> Array[UpgradeData]:
	# Filter out unavailable upgrades
	var available = all_upgrades.filter(func(upgrade):
		# Check stack limit
		var current_stacks = player_upgrades.get(upgrade.upgrade_name, 0)
		if current_stacks >= upgrade.max_stacks:
			return false
		
		# For ability level-ups, check if player has the ability and if it's maxed
		if upgrade.upgrade_type == UpgradeData.UpgradeType.ABILITY_LEVEL:
			if not AbilityManager.has_ability(upgrade.ability_name):
				return false  # Don't offer if player doesn't have this ability
			
			var ability = AbilityManager.get_ability(upgrade.ability_name)
			if ability and ability.current_level >= ability.max_level:
				return false  # Don't offer if ability is max level
		
		# For ability unlocks, check if player already has it
		if upgrade.upgrade_type == UpgradeData.UpgradeType.UNLOCK_ABILITY:
			if AbilityManager.has_ability(upgrade.ability_name):
				return false  # Already unlocked
		
		return true
	)
	
	if available.is_empty():
		return []
	
	# Shuffle and take first 'count'
	available.shuffle()
	var selected = available.slice(0, min(count, available.size()))
	
	return selected

func apply_upgrade(upgrade: UpgradeData):
	# Track that player took this upgrade
	if not player_upgrades.has(upgrade.upgrade_name):
		player_upgrades[upgrade.upgrade_name] = 0
	player_upgrades[upgrade.upgrade_name] += 1
	
	# Apply based on type
	match upgrade.upgrade_type:
		UpgradeData.UpgradeType.STAT_BOOST:
			apply_stat_boost(upgrade)
		
		UpgradeData.UpgradeType.ABILITY_LEVEL:
			apply_ability_level_up(upgrade)
		
		UpgradeData.UpgradeType.UNLOCK_ABILITY:
			apply_ability_unlock(upgrade)

func apply_stat_boost(upgrade: UpgradeData):
	var player = GameManager.player
	if not player:
		return
	
	var stats_comp = player.get_node("StatsComponent")
	if not stats_comp:
		return
	
	# Apply stat bonuses
	if upgrade.move_speed_bonus != 0:
		stats_comp.modify_stat("move_speed", upgrade.move_speed_bonus)
	
	if upgrade.max_health_bonus != 0:
		var health_comp = player.get_node("HealthComponent")
		if health_comp:
			health_comp.increase_max_health(upgrade.max_health_bonus)

	if upgrade.detection_range_bonus != 0:
		stats_comp.modify_stat("detection_radius", upgrade.detection_range_bonus)
	
	if upgrade.pickup_range_bonus != 0:
		stats_comp.modify_stat("pickup_radius", upgrade.pickup_range_bonus)
	
	if upgrade.health_regen_bonus != 0:  
		stats_comp.modify_stat("health_regen", upgrade.health_regen_bonus)

func apply_ability_level_up(upgrade: UpgradeData):
	if AbilityManager.level_up_ability(upgrade.ability_name):
		print("Leveled up ", upgrade.ability_name)
	else:
		print("Failed to level up ", upgrade.ability_name)

func apply_ability_unlock(upgrade: UpgradeData):
	if AbilityManager.unlock_ability(upgrade.ability_script_path):
		print("Unlocked new ability: ", upgrade.ability_name)
	else:
		print("Failed to unlock ", upgrade.ability_name)

func reset():
	player_upgrades.clear()
