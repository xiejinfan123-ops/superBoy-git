@tool
extends EditorPlugin

## Traces a sprite's alpha channel into an ordered polygon, previews it over
## the source art, optionally shatters it into Voronoi shards, and builds a
## ready-to-place, hittable/breakable scene from the result.

const DockScene := preload("res://addons/breakable_2d_sprites/dock.gd")

var _dock: Control

func _enter_tree() -> void:
	_dock = DockScene.new()
	_dock.name = "Breakable 2D Sprites"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)

func _exit_tree() -> void:
	remove_control_from_docks(_dock)
	_dock.free()
