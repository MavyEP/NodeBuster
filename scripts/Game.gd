extends Node2D

## Main game scene — wires up DungeonManager + RoomManager, then starts play.

@onready var room_container: Node2D = $RoomContainer
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $RoomCamera
@onready var transition_rect: ColorRect = $TransitionLayer/TransitionRect

func _ready():
	# Small delay so all autoloads are initialised
	await get_tree().create_timer(0.3).timeout
	
	#RoomManager.door_locked_texture = preload("res://assets/prototypeKennyAssets/Tiles/tile_0045.png")
	#RoomManager.door_unlocked_texture = preload("res://assets/prototypeKennyAssets/Tiles/tile_0021.png")
	# Hand references to RoomManager
	RoomManager.room_container = room_container
	RoomManager.player = player
	RoomManager.camera = camera
	RoomManager.transition_rect = transition_rect

	# Register player globally
	GameManager.player = player

	# Connect level advancement
	RoomManager.trapdoor_entered.connect(_on_trapdoor_entered)

	# Generate dungeon and enter the first room
	DungeonManager.generate_dungeon()
	RoomManager.enter_room(DungeonManager.start_pos, "center")

	GameManager.start_game()

func _on_trapdoor_entered():
	# Advance to next dungeon level
	GameManager.advance_dungeon_level()

	# Clean up current dungeon
	GameManager.cleanup_game()
	RoomManager.reset()

	# Generate a new, bigger dungeon
	DungeonManager.generate_dungeon()

	# Fade transition
	if transition_rect:
		var tw = create_tween()
		tw.tween_property(transition_rect, "color:a", 1.0, 0.3)
		await tw.finished

	# Enter the new dungeon's start room
	RoomManager.enter_room(DungeonManager.start_pos, "center")

	if transition_rect:
		var tw = create_tween()
		tw.tween_property(transition_rect, "color:a", 0.0, 0.3)
		await tw.finished

	print("Entered dungeon level ", GameManager.dungeon_level)
