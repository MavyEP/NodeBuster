extends Node

func _ready():
	print("AbilityManager initialized - using dynamic scanning")

func get_all_abilities() -> Array:
	if not GameManager.player:
		print("AbilityManager: No player found!")
		return []
	
	var container = GameManager.player.get_node_or_null("AbilityContainer")
	if not container:
		print("AbilityManager: No AbilityContainer found on player!")
		return []
	
	var abilities = []
	for child in container.get_children():
		if child is BaseAbility:
			abilities.append(child)
	
	return abilities

func has_ability(ability_name: String) -> bool:
	for ability in get_all_abilities():
		if ability.ability_name == ability_name:
			return true
	return false

func get_ability(ability_name: String):
	for ability in get_all_abilities():
		if ability.ability_name == ability_name:
			return ability
	return null

func level_up_ability(ability_name: String) -> bool:
	var ability = get_ability(ability_name)
	
	if not ability:
		print("Cannot level up '", ability_name, "' - not found!")
		print_abilities()
		return false
	
	if ability.current_level >= ability.max_level:
		print(ability_name, " is already max level!")
		return false
	
	ability.level_up()
	return true

func unlock_ability(ability_script_path: String) -> bool:
	if not GameManager.player:
		return false
	
	var ability_script = load(ability_script_path)
	if not ability_script:
		print("Failed to load ability script: ", ability_script_path)
		return false
	
	var ability_node = Node.new()
	ability_node.set_script(ability_script)
	
	var ability_container = GameManager.player.get_node_or_null("AbilityContainer")
	if ability_container:
		ability_container.add_child(ability_node)
		print("Unlocked ability from: ", ability_script_path)
		return true
	
	return false

func print_abilities():
	print("=== Abilities in AbilityContainer ===")
	var abilities = get_all_abilities()
	if abilities.is_empty():
		print("  NONE FOUND")
	for ability in abilities:
		print("  - '", ability.ability_name, "' Lvl ", ability.current_level, "/", ability.max_level)
	print("=====================================")

func reset():
	print("AbilityManager: dynamic scanning active, nothing to reset")
