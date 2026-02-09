extends Button

@onready var icon_color = $Content/IconColor
@onready var name_label = $Content/NameLabel
@onready var description_label = $Content/DescriptionLabel

var upgrade_data: UpgradeData

func setup(upgrade: UpgradeData):
	upgrade_data = upgrade
	
	# Set visuals
	icon_color.color = upgrade.icon_color
	name_label.text = upgrade.upgrade_name
	
	# Build description based on type
	var desc = upgrade.description
	
	# For ability level-ups, show current level
	if upgrade.upgrade_type == UpgradeData.UpgradeType.ABILITY_LEVEL:
		if AbilityManager.has_ability(upgrade.ability_name):
			var ability = AbilityManager.get_ability(upgrade.ability_name)
			if ability:
				desc += "\n(Lvl %d → %d)" % [ability.current_level, ability.current_level + 1]
	
	# Show stack count for stackable upgrades
	var current_stacks = UpgradeManager.player_upgrades.get(upgrade.upgrade_name, 0)
	if current_stacks > 0 and upgrade.can_stack:
		name_label.text += " [%d/%d]" % [current_stacks, upgrade.max_stacks]
	
	description_label.text = desc
