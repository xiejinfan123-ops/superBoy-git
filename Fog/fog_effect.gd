extends Node2D

@export var scroll_speed := 30.0
@export var fog_modulate: Color = Color(0.9, 0.92, 0.95, 0.35)
@export var band_modulate: Color = Color(0.85, 0.88, 0.92, 0.28)

@onready var _low_sprites: Array[Sprite2D] = _collect("LowFog")
@onready var _band_sprites: Array[Sprite2D] = _collect("BandFog")

func _collect(group_name: String) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for child in get_tree().get_nodes_in_group(group_name):
		if child is Sprite2D:
			out.append(child)
	return out

func _process(delta: float) -> void:
	var low_step := _spacing(_low_sprites)
	var band_step := _spacing(_band_sprites)

	for i in _low_sprites.size():
		var s: Sprite2D = _low_sprites[i]
		s.position.x -= scroll_speed * delta
		if s.position.x < -low_step * 0.5:
			s.position.x += low_step

	for i in _band_sprites.size():
		var s: Sprite2D = _band_sprites[i]
		s.position.x -= scroll_speed * 0.6 * delta
		if s.position.x < -band_step * 0.5:
			s.position.x += band_step

func _spacing(arr: Array[Sprite2D]) -> float:
	if arr.is_empty():
		return 0.0
	var s: Sprite2D = arr[0]
	var base_w := 400.0 if s.texture == null or s.texture.get_width() == 0 else float(s.texture.get_width())
	return base_w * s.scale.x * 0.85
