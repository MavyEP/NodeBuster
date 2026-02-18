extends Node2D

## Main game scene — wires up DungeonManager + RoomManager, then starts play.

@onready var room_container: Node2D = $RoomContainer
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $RoomCamera
@onready var transition_rect: ColorRect = $TransitionLayer/TransitionRect

func _ready():
	# Small delay so all autoloads are initialised
	await get_tree().create_timer(0.3).timeout

	RoomManager.door_locked_texture = preload("res://assets/prototypeKennyAssets/Tiles/tile_0045.png")
	RoomManager.door_unlocked_texture = preload("res://assets/prototypeKennyAssets/Tiles/tile_0021.png")
	

	# Hand references to RoomManager
	RoomManager.room_container = room_container
	RoomManager.player = player
	RoomManager.camera = camera
	RoomManager.transition_rect = transition_rect
	GameManager.player = player

	RoomManager.trapdoor_entered.connect(_on_trapdoor_entered)

	# Connect the callback BEFORE generating
	DungeonManager.dungeon_generated.connect(_on_dungeon_generation_complete)


	# Generate dungeon (signal fires when done)
	DungeonManager.generate_dungeon()

func _on_dungeon_generation_complete():
	# Dungeon graph is ready — now enter the first room
	RoomManager.enter_room(DungeonManager.start_pos, "center")

	
	
	# Fade from black to reveal the game
	if transition_rect:
		var tw = create_tween()
		tw.tween_property(transition_rect, "color:a", 0.0, 0.4)
		await tw.finished
		
	transition_rect.color.a = 0.0
	GameManager.start_game()

func _on_trapdoor_entered():
	# Advance to next dungeon level
	GameManager.advance_dungeon_level()

	# Clean up current dungeon
	GameManager.cleanup_game()
	RoomManager.reset()

	# Generate a new, bigger dungeon
	DungeonManager.generate_dungeon()

	
