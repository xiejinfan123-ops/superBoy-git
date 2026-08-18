extends Node2D
## Drives every Parallax2D child of this node so the background scrolls with
## the player instead of with the camera.
##
## Each frame the player's horizontal movement is fed into each Parallax2D's
## scroll_offset scaled by its own scroll_scale, so near layers move faster
## than far ones — exactly like normal parallax, but keyed to the character.

@export var target: Node2D
@export var y_follow := false

var _parallax: Array[Parallax2D] = []
var _prev_x: float = 0.0
var _prev_y: float = 0.0
var _init: bool = false


func _ready() -> void:
	for child in get_children():
		if child is Parallax2D:
			_parallax.append(child)


func _physics_process(_delta: float) -> void:
	if target == null or _parallax.is_empty():
		return

	if not _init:
		_prev_x = target.global_position.x
		_prev_y = target.global_position.y
		_init = true

	var dx := target.global_position.x - _prev_x
	var dy := 0.0
	if y_follow:
		dy = target.global_position.y - _prev_y
	_prev_x = target.global_position.x
	_prev_y = target.global_position.y

	for p in _parallax:
		if p.scroll_scale.x == 0.0:
			continue
		p.scroll_offset += Vector2(dx * p.scroll_scale.x, dy * p.scroll_scale.y)