extends Camera2D

@export var target: Node2D
@export var smoothing: float = 8.0
@export var dead_zone: Vector2 = Vector2(100, 80)
@export var focus_offset: Vector2 = Vector2(50, 0)

func _physics_process(delta: float) -> void:
	if not target:
		return

	var screen_pos := target.global_position - (global_position + focus_offset)

	var move := Vector2.ZERO
	if absf(screen_pos.x) > dead_zone.x:
		move.x = screen_pos.x - signf(screen_pos.x) * dead_zone.x
	if absf(screen_pos.y) > dead_zone.y:
		move.y = screen_pos.y - signf(screen_pos.y) * dead_zone.y

	global_position += move * clampf(smoothing * delta, 0.0, 1.0)
