@tool
class_name ItemShapeTracePreview
extends Control

## Draws the source texture with the traced contour(s) overlaid: the chosen
## silhouette in bright green with its vertices marked, any other (smaller,
## discarded) contours dimmed in red so a noisy alpha channel is easy to spot.

const BG_COLOR := Color(0.12, 0.12, 0.14)
const MAIN_COLOR := Color(0.3, 1.0, 0.4)
const OTHER_COLOR := Color(1.0, 0.4, 0.3, 0.7)
const VERTEX_COLOR := Color(1.0, 0.9, 0.2)
const SHARD_LINE_COLOR := Color(1.0, 1.0, 1.0, 0.85)

var _texture: Texture2D = null
var _polygons: Array[PackedVector2Array] = []
var _main_index: int = -1
var _shards: Array[PackedVector2Array] = []

func set_data(p_texture: Texture2D, p_polygons: Array[PackedVector2Array], p_main_index: int) -> void:
	_texture = p_texture
	_polygons = p_polygons
	_main_index = p_main_index
	queue_redraw()

func clear_data() -> void:
	_texture = null
	_polygons = []
	_main_index = -1
	_shards = []
	queue_redraw()

func set_shards(p_shards: Array[PackedVector2Array]) -> void:
	_shards = p_shards
	queue_redraw()

func clear_shards() -> void:
	_shards = []
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)
	if _texture == null:
		return

	var tex_size := _texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	var fit_scale := minf(size.x / tex_size.x, size.y / tex_size.y)
	var draw_size := tex_size * fit_scale
	var offset := (size - draw_size) * 0.5

	draw_texture_rect(_texture, Rect2(offset, draw_size), false)

	for i in _polygons.size():
		var poly := _polygons[i]
		if poly.size() < 2:
			continue
		var screen_points := PackedVector2Array()
		screen_points.resize(poly.size())
		for j in poly.size():
			screen_points[j] = offset + poly[j] * fit_scale
		var is_main := i == _main_index
		var color := MAIN_COLOR if is_main else OTHER_COLOR
		var width := 2.0 if is_main else 1.0
		var closed_points := screen_points.duplicate()
		closed_points.append(screen_points[0])
		draw_polyline(closed_points, color, width, true)
		if is_main:
			for pt in screen_points:
				draw_circle(pt, 1.5, VERTEX_COLOR)

	for i in _shards.size():
		var shard := _shards[i]
		if shard.size() < 2:
			continue
		var screen_points := PackedVector2Array()
		screen_points.resize(shard.size())
		for j in shard.size():
			screen_points[j] = offset + shard[j] * fit_scale
		var fill_color := Color.from_hsv(fmod(i * 0.61803398875, 1.0), 0.55, 0.95, 0.3)
		draw_colored_polygon(screen_points, fill_color)
		var closed_points := screen_points.duplicate()
		closed_points.append(screen_points[0])
		draw_polyline(closed_points, SHARD_LINE_COLOR, 1.0, true)
