extends Control

@onready var level_label = $MainMargin/TopInfo/StatsRow/LevelLabel
@onready var time_label = $MainMargin/TopInfo/StatsRow/TimeLabel
@onready var kill_label = $MainMargin/TopInfo/StatsRow/KillLabel

@onready var health_label = $MainMargin/TopInfo/HealthContainer/HealthLabel
@onready var health_bar = $MainMargin/TopInfo/HealthContainer/HealthBar

@onready var boss_warning = $BossWarning

@onready var xp_label = $MainMargin/TopInfo/XPContainer/XPLabel
@onready var xp_bar = $MainMargin/TopInfo/XPContainer/XPBar

@onready var room_label = $MainMargin/TopInfo/StatsRow/RoomLabel

@onready var boss_health_container = $BossHealthContainer
@onready var boss_name_label = $BossHealthContainer/BossNameLabel
@onready var boss_health_bar = $BossHealthContainer/BossHealthBar

var _current_boss: CharacterBody2D = null

func _ready():
	# Connect to player health - use deferred to ensure player is ready
	call_deferred("connect_to_player")

	# Hide boss warning and boss health bar initially
	if boss_warning:
		boss_warning.hide()
	if boss_health_container:
		boss_health_container.hide()

	# Connect to boss spawning / room clear
	RoomManager.boss_spawned.connect(_on_boss_spawned)
	RoomManager.boss_room_cleared.connect(_on_boss_room_cleared)

	# Connect to experience system
	ExperienceManager.experience_gained.connect(_on_xp_gained)
	ExperienceManager.level_up.connect(_on_level_up)

	# Connect to room events
	RoomManager.room_entered.connect(_on_room_entered)
	RoomManager.doors_locked.connect(_on_doors_locked)
	RoomManager.doors_unlocked.connect(_on_doors_unlocked)

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

func _on_room_entered(grid_pos: Vector2i):
	if room_label:
		var info = DungeonManager.get_room_info(grid_pos)
		var status = ""
		if info and info.is_cleared:
			status = " [CLEAR]"
		elif info and info.is_start:
			status = " [START]"
		room_label.text = "Room: %d,%d%s" % [grid_pos.x, grid_pos.y, status]

func _on_doors_locked():
	if room_label:
		room_label.modulate = Color(1.0, 0.4, 0.4)

func _on_doors_unlocked():
	if room_label:
		room_label.modulate = Color(1.0, 1.0, 1.0)
		# Update cleared status
		_on_room_entered(RoomManager.current_grid_pos)

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
