extends Node2D
class_name DoorController

## A single door placed at the edge of a room.
## Emits `player_entered_door` when the player walks into it while unlocked.

signal player_entered_door(direction: String)

## Which wall this door sits on — set by RoomManager when instantiating.
var direction: String = "north"
## Room size — used to auto-position the door.  Set before adding to tree.
var room_size: Vector2 = Vector2(1152, 648)

var is_locked: bool = false

# Child references (created in _ready)
var _area: Area2D
var _blocker: StaticBody2D
var _visual: ColorRect

# Door dimensions
const DOOR_WIDTH: float = 96.0
const DOOR_DEPTH: float = 32.0

func _ready():
	_position_self()
	_build_area()
	_build_blocker()
	_build_visual()
	unlock()   # default state

# ---- Positioning ------------------------------------------------------------
func _position_self():
	var w = room_size.x
	var h = room_size.y
	match direction:
		"north":
			position = Vector2(w / 2.0, 0)
		"south":
			position = Vector2(w / 2.0, h)
		"east":
			position = Vector2(w, h / 2.0)
		"west":
			position = Vector2(0, h / 2.0)

# ---- Building child nodes ---------------------------------------------------
func _build_area():
	_area = Area2D.new()
	_area.name = "DoorArea"
	_area.collision_layer = 0
	_area.collision_mask = 1   # detect player (layer 1)
	add_child(_area)

	var shape = RectangleShape2D.new()
	var col = CollisionShape2D.new()

	match direction:
		"north", "south":
			shape.size = Vector2(DOOR_WIDTH, DOOR_DEPTH * 2)
		"east", "west":
			shape.size = Vector2(DOOR_DEPTH * 2, DOOR_WIDTH)

	col.shape = shape
	_area.add_child(col)
	_area.body_entered.connect(_on_body_entered)

func _build_blocker():
	_blocker = StaticBody2D.new()
	_blocker.name = "DoorBlocker"
	_blocker.collision_layer = 1   # same layer as walls
	add_child(_blocker)

	var shape = RectangleShape2D.new()
	var col = CollisionShape2D.new()

	match direction:
		"north", "south":
			shape.size = Vector2(DOOR_WIDTH, DOOR_DEPTH)
		"east", "west":
			shape.size = Vector2(DOOR_DEPTH, DOOR_WIDTH)

	col.shape = shape
	_blocker.add_child(col)

func _build_visual():
	_visual = ColorRect.new()
	_visual.name = "DoorVisual"
	_visual.z_index = -4

	match direction:
		"north", "south":
			_visual.size = Vector2(DOOR_WIDTH, DOOR_DEPTH)
			_visual.position = Vector2(-DOOR_WIDTH / 2.0, -DOOR_DEPTH / 2.0)
		"east", "west":
			_visual.size = Vector2(DOOR_DEPTH, DOOR_WIDTH)
			_visual.position = Vector2(-DOOR_DEPTH / 2.0, -DOOR_WIDTH / 2.0)

	add_child(_visual)

# ---- Lock / Unlock ----------------------------------------------------------
func lock():
	is_locked = true
	_blocker.collision_layer = 1
	# Show blocker visual
	for col_child in _blocker.get_children():
		if col_child is CollisionShape2D:
			col_child.disabled = false
	_visual.color = Color(0.6, 0.15, 0.15, 1.0)   # red = locked

func unlock():
	is_locked = false
	# Disable blocker collision
	for col_child in _blocker.get_children():
		if col_child is CollisionShape2D:
			col_child.disabled = true
	_visual.color = Color(0.2, 0.7, 0.3, 1.0)   # green = open

# ---- Detection --------------------------------------------------------------
func _on_body_entered(body: Node2D):
	if is_locked:
		return
	if body.is_in_group("player"):
		player_entered_door.emit(direction)
