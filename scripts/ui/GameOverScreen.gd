extends Control

@onready var time_label = $CenterContainer/MainContainer/StatsContainer/TimeLabel
@onready var level_label = $CenterContainer/MainContainer/StatsContainer/LevelLabel
@onready var kills_label = $CenterContainer/MainContainer/StatsContainer/KillsLabel
@onready var bosses_label = $CenterContainer/MainContainer/StatsContainer/BossesLabel
@onready var restart_button = $CenterContainer/MainContainer/RestartButton

func _ready():
	hide()
	
	# Connect restart button
	restart_button.pressed.connect(_on_restart_pressed)
	
	# Listen for game over
	GameManager.game_ended.connect(show_game_over)

func show_game_over():
	# Display final stats
	update_stats()
	
	# Show the screen
	show()

func update_stats():
	# Format time
	var time = GameManager.current_time
	var minutes = int(time) / 60
	var seconds = int(time) % 60
	time_label.text = "Time Survived: %d:%02d" % [minutes, seconds]
	
	# Other stats
	level_label.text = "Level Reached: " + str(ExperienceManager.current_level)
	kills_label.text = "Enemies Killed: " + str(GameManager.enemies_killed)
	bosses_label.text = "Bosses Defeated: " + str(BossManager.bosses_spawned)

func _on_restart_pressed():
	print("Restarting game...")
	
	# Hide this screen
	hide()
	
	# Reload the entire game scene
	get_tree().reload_current_scene()
