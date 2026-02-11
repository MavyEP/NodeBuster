extends Node2D

@export var max_range: float = 900.0
@export var collision_mask: int = 1 << 0  # set to your "Walls" layer (and anything that should block shots)
@export var start_offset: Vector2 = Vector2.ZERO # local offset from parent (muzzle position)

@onready var line: Line2D = $Line2D

func _ready() -> void:
	# Basic Line2D setup (you can also set these in the editor)
	line.clear_points()
	line.points = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT * 10])

func _process(_delta: float) -> void:
	var start_global := (get_parent() as Node2D).global_position + start_offset.rotated((get_parent() as Node2D).global_rotation)

	var mouse_global := get_viewport().get_mouse_position()
	# If you're in a 2D camera world, use this instead:
	mouse_global = (get_parent() as Node2D).get_global_mouse_position()

	var dir := (mouse_global - start_global)
	if dir.length() < 0.001:
		_hide_laser()
		return
	dir = dir.normalized()

	var end_global := start_global + dir * max_range

	# Raycast
	var query := PhysicsRayQueryParameters2D.create(start_global, end_global)
	query.collision_mask = collision_mask
	query.exclude = [(get_parent() as Node2D)]  # exclude player body
	query.hit_from_inside = true

	var hit := get_world_2d().direct_space_state.intersect_ray(query)

	if not hit.is_empty():
		end_global = hit.position

	# Convert global points to this node's local space for Line2D
	# (Line2D uses local coordinates)
	var start_local := to_local(start_global)
	var end_local := to_local(end_global)

	line.points = PackedVector2Array([start_local, end_local])
	line.visible = true

func _hide_laser() -> void:
	line.visible = false
