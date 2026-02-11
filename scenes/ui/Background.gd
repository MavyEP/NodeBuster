extends ColorRect

@export var camera: Camera2D
@onready var mat := material as ShaderMaterial

func _process(_dt):
	if camera:
		mat.set_shader_parameter("camera_pos", camera.global_position)
