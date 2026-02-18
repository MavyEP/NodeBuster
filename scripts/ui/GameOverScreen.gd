extends Control

@onready var restart_button = $CenterContainer/MainContainer/RestartButton

func _ready():
	hide()
	
	# Connect restart button
	restart_button.pressed.connect(_on_restart_pressed)
	
	# Listen for game over
	GameManager.game_ended.connect(show_game_over)

func show_game_over():	
	# Show the screen
	show()




func _on_restart_pressed():
	print("Restarting game...")
	
	# Hide this screen
	hide()
	DungeonManager.dungeon_level = 1
	# Reload the entire game scene
	get_tree().reload_current_scene()
