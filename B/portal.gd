extends Area2D
## A touch-to-travel portal.
##
## The ring visual is drawn in code (a glowing octagon) and the scene provides
## an ember particle layer, so no texture is needed. When the player's body
## enters the trigger area the scene is changed to `target_scene`.

@export var target_scene: String = ""

@onready var _ring: Polygon2D = Polygon2D.new()


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)

	_ring.polygon = PackedVector2Array([
		Vector2(0, -26), Vector2(12, -12), Vector2(26, 0), Vector2(12, 12),
		Vector2(0, 26), Vector2(-12, 12), Vector2(-26, 0), Vector2(-12, -12),
	])
	_ring.color = Color(0.35, 0.85, 1.0, 0.85)
	add_child(_ring)


func _on_body_entered(body: Node) -> void:
	if target_scene.is_empty():
		return
	if body.is_in_group("Player") or body is CharacterBody2D:
		# Deferred so the scene is not torn down inside the physics callback.
		call_deferred("change_scene", target_scene)


func change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
