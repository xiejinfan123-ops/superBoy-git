extends Camera2D

@export var target: Node2D
@export var smoothing: float = 8.0

func _physics_process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(target.global_position, smoothing * delta)