extends Control

@onready var level_label = $MainMargin/TopInfo/StatsRow/LevelLabel

@onready var health_label = $MainMargin/TopInfo/HealthContainer/HealthLabel
@onready var health_bar = $MainMargin/TopInfo/HealthContainer/HealthBar

@onready var xp_label = $MainMargin/TopInfo/XPContainer/XPLabel
@onready var xp_bar = $MainMargin/TopInfo/XPContainer/XPBar

@onready var boss_health_container = $BossHealthContainer
@onready var boss_name_label = $BossHealthContainer/BossNameLabel
@onready var boss_health_bar = $BossHealthContainer/BossHealthBar

var _current_boss: CharacterBody2D = null

func _ready():
	# Connect to player health - use deferred to ensure player is ready
	call_deferred("connect_to_player")


	if boss_health_container:
		boss_health_container.hide()

	# Connect to boss spawning / room clear
	RoomManager.boss_spawned.connect(_on_boss_spawned)
	RoomManager.boss_room_cleared.connect(_on_boss_room_cleared)

	# Connect to experience system
	ExperienceManager.experience_gained.connect(_on_xp_gained)
	ExperienceManager.level_up.connect(_on_level_up)

	# Initial update
	update_xp()
	update_level()



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



func connect_to_player():
	if GameManager.player:
		var health_comp = GameManager.player.get_node("HealthComponent")
		if health_comp:
			health_comp.health_changed.connect(_on_health_changed)
			# Manually trigger initial update
			_on_health_changed(health_comp.current_health, health_comp.max_health)

# ---- Boss health bar --------------------------------------------------------
func _on_boss_spawned(boss: CharacterBody2D):
	_current_boss = boss
	if not boss_health_container:
		return

	# Set boss name
	var display_name: String = boss.boss_name if boss.get("boss_name") else "Boss"
	boss_name_label.text = display_name

	# Connect to boss health
	var hc = boss.get_node_or_null("HealthComponent")
	if hc:
		hc.health_changed.connect(_on_boss_health_changed)
		boss_health_bar.max_value = hc.max_health
		boss_health_bar.value = hc.current_health

	boss_health_container.show()

func _on_boss_health_changed(current: float, maximum: float):
	if boss_health_bar:
		boss_health_bar.max_value = maximum
		boss_health_bar.value = current

func _on_boss_room_cleared(_grid_pos: Vector2i):
	_current_boss = null
	if boss_health_container:
		boss_health_container.hide()
