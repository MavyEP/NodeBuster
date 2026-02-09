extends Node

# Track player's abilities
var player_abilities: Dictionary = {}  # ability_name: {node: Node, level: int}

func _ready():
	print("AbilityManager initialized")

func register_ability(ability_node: Node):
	var ability_name = ability_node.ability_name
	player_abilities[ability_name] = {
		"node": ability_node,
		"level": ability_node.current_level
	}
	print("Registered ability: ", ability_name, " at level ", ability_node.current_level)

func has_ability(ability_name: String) -> bool:
	return player_abilities.has(ability_name)

func get_ability(ability_name: String):
	if player_abilities.has(ability_name):
		return player_abilities[ability_name]["node"]
	return null

func level_up_ability(ability_name: String) -> bool:
	if not has_ability(ability_name):
		print("Cannot level up ", ability_name, " - player doesn't have it")
		return false
	
	var ability = player_abilities[ability_name]["node"]
	
	if ability.current_level >= ability.max_level:
		print(ability_name, " is already max level!")
		return false
	
	ability.level_up()
	player_abilities[ability_name]["level"] = ability.current_level
	return true

func unlock_ability(ability_script_path: String) -> bool:
	if not GameManager.player:
		return false
	
	# Load the ability script
	var ability_script = load(ability_script_path)
	if not ability_script:
		print("Failed to load ability script: ", ability_script_path)
		return false
	
	# Create new ability node
	var ability_node = Node.new()
	ability_node.set_script(ability_script)
	
	# Add to player's AbilityContainer
	var ability_container = GameManager.player.get_node("AbilityContainer")
	if ability_container:
		ability_container.add_child(ability_node)
		print("Unlocked new ability: ", ability_script_path)
		return true
	
	return false

func reset():
	player_abilities.clear()
