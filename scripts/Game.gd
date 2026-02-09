extends Node2D

func _ready():
	# Auto-start the game
	await get_tree().create_timer(0.5).timeout  # Small delay for everything to initialize
	GameManager.start_game()
