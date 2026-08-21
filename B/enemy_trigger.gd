extends Area2D
## Activates a target enemy the first time the player enters this zone.
##
## The enemy is placed in the scene hidden and inert; the moment the player
## walks into this trigger the enemy becomes active and starts hunting. A
## one-shot guard keeps it from re-firing.

@export var enemy_path: NodePath

var _used: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _used:
		return
	if not (body.is_in_group("Player") or body is CharacterBody2D):
		return
	_used = true
	# Activate every enemy in the "EnemyFlyer" group, plus any single enemy the
	# enemy_path points at (kept for scenes that wire one target manually).
	for node in get_tree().get_nodes_in_group("EnemyFlyer"):
		if node.has_method("activate"):
			node.activate()
	if not enemy_path.is_empty():
		var enemy := get_node_or_null(enemy_path) as Node
		if enemy != null and enemy.has_method("activate"):
			enemy.activate()