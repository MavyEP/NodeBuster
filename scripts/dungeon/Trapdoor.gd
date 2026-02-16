extends Node2D
class_name Trapdoor

## A trapdoor that appears in the boss room after the boss is defeated.
## When the player walks into it, the dungeon advances to the next level.

signal player_entered_trapdoor

var _area: Area2D
var _visual: ColorRect

const TRAPDOOR_SIZE: float = 64.0

func _ready():
	_build_visual()
	_build_area()

func _build_visual():
	_visual = ColorRect.new()
	_visual.name = "TrapdoorVisual"
	_visual.color = Color(0.1, 0.1, 0.1, 1.0)  # dark hole
	_visual.size = Vector2(TRAPDOOR_SIZE, TRAPDOOR_SIZE)
	_visual.position = Vector2(-TRAPDOOR_SIZE / 2.0, -TRAPDOOR_SIZE / 2.0)
	_visual.z_index = -3
	add_child(_visual)

	# Inner highlight ring
	var inner = ColorRect.new()
	inner.name = "TrapdoorInner"
	inner.color = Color(0.6, 0.4, 0.0, 1.0)  # golden border
	inner.size = Vector2(TRAPDOOR_SIZE + 8, TRAPDOOR_SIZE + 8)
	inner.position = Vector2(-(TRAPDOOR_SIZE + 8) / 2.0, -(TRAPDOOR_SIZE + 8) / 2.0)
	inner.z_index = -4
	add_child(inner)

func _build_area():
	_area = Area2D.new()
	_area.name = "TrapdoorArea"
	_area.collision_layer = 0
	_area.collision_mask = 1  # detect player
	add_child(_area)

	var shape = RectangleShape2D.new()
	shape.size = Vector2(TRAPDOOR_SIZE, TRAPDOOR_SIZE)
	var col = CollisionShape2D.new()
	col.shape = shape
	_area.add_child(col)

	_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_entered_trapdoor.emit()
