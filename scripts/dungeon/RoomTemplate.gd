extends Node2D
class_name RoomTemplate

## Attach this script to the root of every room scene.
## It carries metadata that the dungeon generator and room manager read.
##
## To create a new room:
##   1.  Create a new scene with a Node2D root.
##   2.  Attach this script (or extend it).
##   3.  Add child Marker2D nodes under a "SpawnPoints" Node2D.
##   4.  Optionally set the exports below.
##   5.  Save into  res://scenes/rooms/  — it will be picked up automatically.

## Difficulty hint (0 = easy, higher = harder).  The generator may use this
## to place the room further from start.
@export var difficulty: int = 0

## Free-form tags the generator can filter on (e.g. "combat", "treasure", "boss").
@export var tags: PackedStringArray = []

## Room interior size — keep consistent across all rooms for MVP.
@export var room_width: int = 480
@export var room_height: int = 270

## Wall thickness used when the room builds its own collision walls.
@export var wall_thickness: float = 16.0

## Door gap size (opening in the wall where doors are placed).
@export var door_gap: float = 16.0

# ---- Texture exports --------------------------------------------------------
# Set these in the inspector to replace the placeholder ColorRects with real art.
# Leave null to keep the colored-rectangle fallback.

@export_group("Room Textures")

## Floor texture — tiled across the entire room interior.
## Use a small seamless tile (e.g. 64x64 or 128x128 stone/dirt texture).
@export var floor_texture: Texture2D = null

## Wall texture — tiled along each wall segment.
@export var wall_texture: Texture2D = null

## Fallback colours used when no texture is assigned.
@export var floor_color: Color = Color(0.15, 0.15, 0.2)
@export var wall_color: Color = Color(0.35, 0.3, 0.25)


func build_walls(connected_directions: Array = []) -> StaticBody2D:
	var walls = StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1  
	add_child(walls)

	var w = float(room_width)
	var h = float(room_height)
	var t = wall_thickness
	var gap = door_gap


	_add_wall_pair(walls, "north" in connected_directions,
		Vector2(0, 0), Vector2(w, t), gap, true)


	_add_wall_pair(walls, "south" in connected_directions,
		Vector2(0, h - t), Vector2(w, h), gap, true)


	_add_wall_pair(walls, "west" in connected_directions,
		Vector2(0, 0), Vector2(t, h), gap, false)


	_add_wall_pair(walls, "east" in connected_directions,
		Vector2(w - t, 0), Vector2(w, h), gap, false)

	return walls

func _add_wall_pair(parent: Node, has_door: bool,
		top_left: Vector2, bottom_right: Vector2,
		gap: float, is_horizontal: bool):
	var size = bottom_right - top_left
	if not has_door:
		# Solid wall — single shape
		_add_rect_collision(parent, top_left, size)
		return

	# Split wall into two halves with a gap in the centre
	if is_horizontal:
		var mid = top_left.x + size.x / 2.0
		var half_gap = gap / 2.0
		# Left segment
		_add_rect_collision(parent, top_left,
			Vector2(mid - half_gap - top_left.x, size.y))
		# Right segment
		_add_rect_collision(parent,
			Vector2(mid + half_gap, top_left.y),
			Vector2(bottom_right.x - mid - half_gap, size.y))
	else:
		var mid = top_left.y + size.y / 2.0
		var half_gap = gap / 2.0
		# Top segment
		_add_rect_collision(parent, top_left,
			Vector2(size.x, mid - half_gap - top_left.y))
		# Bottom segment
		_add_rect_collision(parent,
			Vector2(top_left.x, mid + half_gap),
			Vector2(size.x, bottom_right.y - mid - half_gap))

func _add_rect_collision(parent: Node, pos: Vector2, size: Vector2):
	if size.x <= 0 or size.y <= 0:
		return
	var shape = RectangleShape2D.new()
	shape.size = size
	var col = CollisionShape2D.new()
	col.shape = shape
	col.position = pos + size / 2.0
	parent.add_child(col)

## Draw the room floor. Uses floor_texture if set, otherwise a solid ColorRect.
func draw_floor(color: Color = Color(-1, -1, -1)):
	# Allow callers to pass a color override, but default to the export value
	if color == Color(-1, -1, -1):
		color = floor_color

	if floor_texture:
		var tex_rect = TextureRect.new()
		tex_rect.name = "Floor"
		tex_rect.texture = floor_texture
		tex_rect.position = Vector2.ZERO
		tex_rect.size = Vector2(room_width, room_height)
		tex_rect.stretch_mode = TextureRect.STRETCH_TILE
		tex_rect.z_index = -10
		add_child(tex_rect)
		move_child(tex_rect, 0)
	else:
		var rect = ColorRect.new()
		rect.name = "Floor"
		rect.color = color
		rect.position = Vector2.ZERO
		rect.size = Vector2(room_width, room_height)
		rect.z_index = -10
		add_child(rect)
		move_child(rect, 0)

## Draw wall visuals matching the collision walls.
## Uses wall_texture if set, otherwise solid ColorRects.
func draw_wall_visuals(connected_directions: Array = [],
		color_override: Color = Color(-1, -1, -1)):
			
	if color_override == Color(-1, -1, -1):
		color_override = wall_color
	var w = float(room_width)
	var h = float(room_height)
	var t = wall_thickness
	var gap = door_gap

	# North
	_draw_wall_visual_pair("north" in connected_directions,
		Vector2(0, 0), Vector2(w, t), gap, true, color_override)
	# South
	_draw_wall_visual_pair("south" in connected_directions,
		Vector2(0, h - t), Vector2(w, h), gap, true, color_override)
	# West
	_draw_wall_visual_pair("west" in connected_directions,
		Vector2(0, 0), Vector2(t, h), gap, false, color_override)
	# East
	_draw_wall_visual_pair("east" in connected_directions,
		Vector2(w - t, 0), Vector2(w, h), gap, false, color_override)

func _draw_wall_visual_pair(has_door: bool, top_left: Vector2,
		bottom_right: Vector2, gap: float, is_horizontal: bool,
		color: Color):
	var size = bottom_right - top_left
	if not has_door:
		_add_visual_rect(top_left, size, color)
		return

	if is_horizontal:
		var mid = top_left.x + size.x / 2.0
		var half_gap = gap / 2.0
		_add_visual_rect(top_left,
			Vector2(mid - half_gap - top_left.x, size.y), color)
		_add_visual_rect(Vector2(mid + half_gap, top_left.y),
			Vector2(bottom_right.x - mid - half_gap, size.y), color)
	else:
		var mid = top_left.y + size.y / 2.0
		var half_gap = gap / 2.0
		_add_visual_rect(top_left,
			Vector2(size.x, mid - half_gap - top_left.y), color)
		_add_visual_rect(Vector2(top_left.x, mid + half_gap),
			Vector2(size.x, bottom_right.y - mid - half_gap), color)

## Creates either a TextureRect (tiled) or a ColorRect for a wall segment.
func _add_visual_rect(pos: Vector2, size: Vector2, color: Color):
	if size.x <= 0 or size.y <= 0:
		return
	if wall_texture:
		var tex_rect = TextureRect.new()
		tex_rect.texture = wall_texture
		tex_rect.position = pos
		tex_rect.size = size
		tex_rect.stretch_mode = TextureRect.STRETCH_TILE
		tex_rect.z_index = -5
		add_child(tex_rect)
	else:
		var rect = ColorRect.new()
		rect.color = color
		rect.position = pos
		rect.size = size
		rect.z_index = -5
		add_child(rect)
