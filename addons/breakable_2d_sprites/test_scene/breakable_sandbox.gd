extends Node2D

## Empty test bed: drag any built_items/*.tscn into this scene (in the
## editor, from the FileSystem dock — drop it anywhere in the 2D viewport or
## onto this node in the Scene tree) and position them wherever you like.
## Run the scene and click any of them to break it — this doesn't know or
## care what specific items are present, it just physics-queries whatever's
## under the click and calls take_hit() on anything that responds to it, so
## it works for however many items you've dragged in.
##
## Camera2D/Floor/Label are real scene nodes (visible while editing, not
## just at runtime) — this script only positions the camera dynamically.

@onready var _camera: Camera2D = $Camera2D

func _ready() -> void:
	_camera.make_current()
	_frame_camera_on_items()

## Items dragged into this scene in the editor can land anywhere — the
## camera's placed position would only work if you happened to place things
## near it. Instead, frame the camera around whatever breakable items are
## actually present (falls back to its placed position/zoom if none yet).
func _frame_camera_on_items() -> void:
	var items := _find_items()
	if items.is_empty():
		return

	var bounds := Rect2(items[0].global_position, Vector2.ZERO)
	for item in items:
		bounds = bounds.expand(item.global_position)
	bounds = bounds.grow(200.0) # generous margin so a full silhouette isn't clipped at the edge

	_camera.global_position = bounds.get_center()

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1152, 648) # fallback if layout hasn't settled yet
	var zoom_level := clampf(minf(viewport_size.x / maxf(bounds.size.x, 1.0), viewport_size.y / maxf(bounds.size.y, 1.0)), 0.15, 1.0)
	_camera.zoom = Vector2(zoom_level, zoom_level)

func _find_items() -> Array:
	var items := []
	for child in get_children():
		if child.has_method("take_hit"):
			items.append(child)
	return items

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Convert the click's own screen position to world space directly,
		# rather than reading get_global_mouse_position() — that reflects
		# the viewport's separately-tracked cursor position, which is only
		# kept fresh by real OS mouse-motion events. Using the event's own
		# coordinates avoids depending on that being up to date yet.
		var world_pos: Vector2 = get_viewport().canvas_transform.affine_inverse() * event.position
		_try_break_at(world_pos)

func _try_break_at(click_position: Vector2) -> void:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = click_position
	query.collide_with_bodies = true
	query.collide_with_areas = false

	for result in space_state.intersect_point(query, 8):
		var collider = result.get("collider")
		# Duck-typed on purpose: breaks anything with take_hit(), not just
		# ItemShapeBreakableItem specifically, in case a project subclasses it.
		if collider != null and collider.has_method("take_hit"):
			collider.take_hit(click_position)
			return
