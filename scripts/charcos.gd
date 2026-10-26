extends GPUParticles2D

@export var camera: Camera2D


func _process(_delta: float) -> void:
	global_position = camera.global_position
