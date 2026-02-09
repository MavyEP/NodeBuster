extends Control

@onready var upgrade_buttons_container = $CenterContainer/UpgradeContainer/UpgradeButtonsContainer
@onready var title_label = $CenterContainer/UpgradeContainer/TitleLabel

var upgrade_button_scene = preload("res://scenes/ui/UpgradeButton.tscn")

func _ready():
	hide()
	
	# Listen for level ups
	ExperienceManager.level_up.connect(_on_level_up)

func _on_level_up(new_level: int):
	show_upgrade_selection(new_level)

func show_upgrade_selection(level: int):
	# Update title
	title_label.text = "LEVEL " + str(level) + "!"
	
	# Clear old buttons
	for child in upgrade_buttons_container.get_children():
		child.queue_free()
	
	# Get random upgrades
	var upgrades = UpgradeManager.get_random_upgrades(3)
	
	# Create buttons for each upgrade
	for upgrade in upgrades:
		var button = upgrade_button_scene.instantiate()
		upgrade_buttons_container.add_child(button)
		button.setup(upgrade)
		button.pressed.connect(_on_upgrade_selected.bind(upgrade))
	
	# Show panel
	show()

func _on_upgrade_selected(upgrade: UpgradeData):
	# Apply the upgrade
	UpgradeManager.apply_upgrade(upgrade)
	
	# Hide panel and resume game
	hide()
	get_tree().paused = false
