extends Node2D
class_name DoorController

## A single door placed at the edge of a room.
## Emits `player_entered_door` when the player walks into it while unlocked.

##
## Texture workflow:
##   Set locked_texture / unlocked_texture in the inspector (or from code)
##   to replace the placeholder colored rectangles with real sprites.
##   The door will tween-animate between them on lock/unlock.

signal player_entered_door(direction: String)

## Which wall this door sits on — set by RoomManager when instantiating.
var direction: String = "north"
## Room size — used to auto-position the door.  Set before adding to tree.
var room_size: Vector2 = Vector2(1152, 648)

var is_locked: bool = false

# ---- Texture exports --------------------------------------------------------
## Sprite shown when the door is locked (e.g. iron bars / closed gate).
var locked_texture: Texture2D = null
## Sprite shown when the door is unlocked (e.g. open doorway).
var unlocked_texture: Texture2D = null


# Child references (created in _ready)
var _area: Area2D
var _blocker: StaticBody2D
var _visual: ColorRect      # fallback when no textures
var _sprite: Sprite2D        # used when textures are assignedt

# Door dimensions
const DOOR_WIDTH: float = 32.0
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
	var use_sprites = locked_texture != null or unlocked_texture != null

	if use_sprites:
		# Sprite-based door
		_sprite = Sprite2D.new()
		_sprite.name = "DoorSprite"
		_sprite.z_index = -4
		# Rotate east/west doors so the sprite faces the right way
		if direction in ["east", "west"]:
			_sprite.rotation_degrees = 90.0
		add_child(_sprite)
	else:
		# ColorRect fallback (original behavior)
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
	for col_child in _blocker.get_children():
		if col_child is CollisionShape2D:
			col_child.disabled = false
	if _sprite:
		_sprite.texture = locked_texture if locked_texture else unlocked_texture
		_play_door_tween()
	elif _visual:
		_visual.color = Color(0.6, 0.15, 0.15, 1.0)   # red = locked

func unlock():
	is_locked = false
	for col_child in _blocker.get_children():
		if col_child is CollisionShape2D:
			col_child.disabled = true
	if _sprite:
		_sprite.texture = unlocked_texture if unlocked_texture else locked_texture
		_play_door_tween()
	elif _visual:
		_visual.color = Color(0.2, 0.7, 0.3, 1.0)   # green = open

## Quick scale-bounce animation when the door state changes.
## Looks like the door slamming shut or swinging open.
func _play_door_tween():
	if not _sprite or not is_inside_tree():
		return
	var tw = create_tween()
	tw.tween_property(_sprite, "scale", Vector2(1.15, 0.7), 0.06)
	tw.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)
	
# ---- Detection --------------------------------------------------------------
func _on_body_entered(body: Node2D):
	if is_locked:
		return
	if body.is_in_group("player"):
		player_entered_door.emit(direction)
