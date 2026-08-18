extends Area2D
## Visual, draggable camera region.
##
## Drop one of these in the scene and size it with the editor's move/scale
## tool (the collision rectangle is visible and draggable). The Camera2D
## picks every node in the "CameraRegions" group up automatically. At runtime
## this node does nothing on its own.

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0


func get_region_rect() -> Rect2:
	for child in get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var s: RectangleShape2D = child.shape
			var size := s.size * global_scale
			var half := size * 0.5
			# The collision shape may be offset from the Area2D origin, so the
			# rectangle is centred on the shape's own global position.
			return Rect2(child.global_position - half, size)
	return Rect2(global_position, Vector2.ZERO)