extends Node2D

@onready var nozzle: Marker2D = $Nozzle

var base_damage: float = 15.0
var base_cooldown: float = 1.0
var projectile_scene = preload("res://scenes/abilities/Projectile.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("fire"):
		var mouse_pos = get_global_mouse_position()
		var projectile_instance = projectile_scene.instantiate()
		get_tree().root.add_child(projectile_instance)
		projectile_instance.global_position = nozzle.global_position
		projectile_instance.rotation = nozzle.global_position.angle_to_point(mouse_pos)

		
