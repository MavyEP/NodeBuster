extends Node2D

## Main game scene — wires up DungeonManager + RoomManager, then starts play.

@onready var room_container: Node2D = $RoomContainer
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $RoomCamera
@onready var transition_rect: ColorRect = $TransitionLayer/TransitionRect

func _ready():
	# Small delay so all autoloads are initialised
	await get_tree().create_timer(0.3).timeout

	# Hand references to RoomManager
	RoomManager.room_container = room_container
	RoomManager.player = player
	RoomManager.camera = camera
	RoomManager.transition_rect = transition_rect

	# Register player globally
	GameManager.player = player

	# Generate dungeon and enter the first room
	DungeonManager.generate_dungeon()
	RoomManager.enter_room(DungeonManager.start_pos, "center")

	GameManager.start_game()
