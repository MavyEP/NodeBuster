extends Area2D

signal player_entered_door(direction: String)

@export var direction: String = "north"  # "north","south","east","west"

@onready var locked_overlay = $LockedOverlay
@onready var direction_label = $DirectionLabel

var is_locked: bool = true
var is_enabled: bool = true  # False = no door in this direction

func _ready():
	direction_label.text = direction.substr(0, 1).to_upper()
	
	# Connect collision
	body_entered.connect(_on_body_entered)
	
	# Start locked
	set_locked(true)

func set_locked(locked: bool):
	is_locked = locked
	locked_overlay.visible = locked

func set_enabled(enabled: bool):
	is_enabled = enabled
	visible = enabled
	set_process(enabled)

func _on_body_entered(body):
	if not is_enabled or is_locked:
		return
	
	if body.is_in_group("player"):
		print("Player entered door: ", direction)
		player_entered_door.emit(direction)
