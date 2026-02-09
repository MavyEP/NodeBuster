extends Control

@onready var level_label = $MainMargin/TopInfo/StatsRow/LevelLabel
@onready var time_label = $MainMargin/TopInfo/StatsRow/TimeLabel
@onready var kill_label = $MainMargin/TopInfo/StatsRow/KillLabel

@onready var health_label = $MainMargin/TopInfo/HealthContainer/HealthLabel
@onready var health_bar = $MainMargin/TopInfo/HealthContainer/HealthBar

@onready var boss_warning = $BossWarning

@onready var xp_label = $MainMargin/TopInfo/XPContainer/XPLabel
@onready var xp_bar = $MainMargin/TopInfo/XPContainer/XPBar

func _ready():
	
	# Connect to player health - use deferred to ensure player is ready
	call_deferred("connect_to_player")
	
	# Hide boss warning initially
	if boss_warning:
		boss_warning.hide()
	
	# Connect to experience system
	ExperienceManager.experience_gained.connect(_on_xp_gained)
	ExperienceManager.level_up.connect(_on_level_up)
	
	# Initial update
	update_xp()
	update_level()

func _process(delta):
	update_time()
	update_kills()
	check_boss_warning()

func update_time():
	var time = GameManager.current_time
	var minutes = int(time) / 60
	var seconds = int(time) % 60
	time_label.text = "Time: %d:%02d" % [minutes, seconds]

func update_kills():
	kill_label.text = "Kills: " + str(GameManager.enemies_killed)

func update_level():
	level_label.text = "Level: " + str(ExperienceManager.current_level)

func update_xp():
	xp_label.text = "XP: %d/%d" % [ExperienceManager.current_xp, ExperienceManager.xp_to_next_level]
	xp_bar.max_value = ExperienceManager.xp_to_next_level
	xp_bar.value = ExperienceManager.current_xp

func _on_health_changed(current: float, maximum: float):
	health_label.text = "Health: %d/%d" % [int(current), int(maximum)]
	health_bar.max_value = maximum
	health_bar.value = current

func _on_xp_gained(amount):
	update_xp()

func _on_level_up(new_level):
	update_level()
	update_xp()

func check_boss_warning():
	# Show warning 10 seconds before boss spawn
	var time_to_next_boss = BossManager.next_boss_time - GameManager.current_time
	
	if time_to_next_boss <= 10.0 and time_to_next_boss > 9.0:
		# Only show once (when it crosses 10 seconds)
		if boss_warning and not boss_warning.visible:
			show_boss_warning()


func show_boss_warning():
	if not boss_warning:
		return
	
	boss_warning.show()
	
	# Flash the warning
	var tween = create_tween()
	tween.set_loops(6)
	tween.tween_property(boss_warning, "modulate:a", 0.0, 0.25)
	tween.tween_property(boss_warning, "modulate:a", 1.0, 0.25)
	
	# Hide after 3 seconds
	await get_tree().create_timer(3.0).timeout
	boss_warning.hide()

func connect_to_player():
	if GameManager.player:
		var health_comp = GameManager.player.get_node("HealthComponent")
		if health_comp:
			health_comp.health_changed.connect(_on_health_changed)
			# Manually trigger initial update
			_on_health_changed(health_comp.current_health, health_comp.max_health)
