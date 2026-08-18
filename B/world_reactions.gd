class_name WorldReactions
extends Node

## Makes the scenery answer the character: foliage bends away as he runs
## through it, shudders when he lands nearby, and twitches at his footfalls,
## then springs back with a damped wobble.
##
## Registration is by texture, not by hand-tagging: any Sprite2D inside the
## world-space decoration containers whose texture matches a known foliage
## pattern gets a spring. New decorations of the same kinds join automatically
## the next time the scene loads. Parallax layers are deliberately excluded —
## they are backdrop, not world.
##
## Each spring pivots at the sprite's bottom edge, so plants bend from the
## root the way the player's own squash pivots at his feet.

## Horizontal reach of a passing body, in px.
@export var brush_radius: float = 55.0
## Vertical tolerance — decorations far above or below his feet do not react.
@export var vertical_reach: float = 90.0
## Bend from running through, radians at full speed dead-centre.
@export var brush_strength: float = 0.55
## Bend from a nearby landing, radians at full impact point-blank.
@export var landing_strength: float = 0.5
## Reach of a landing thump, px.
@export var landing_radius: float = 140.0
## Twitch from a footfall, radians.
@export var footfall_strength: float = 0.07
## Spring return rate. Higher = snappier plants.
@export var spring_rate: float = 42.0
## Wobble decay. Lower = springier, longer after-sway.
@export var spring_damping: float = 5.0

## texture filename fragment -> how pliant that foliage kind is (1 = full).
const FOLIAGE_KINDS := {
	"Coral_grass": 1.0,
	"fine-edited_chroma": 0.55,
	"coral_break_set": 0.22,
	"grass_ball": 1.0,
	"Moss_clump": 0.7,
}
const CONTAINER_NAMES := ["场景1装饰", "场景1装饰2"]

class Blade:
	var sprite: Sprite2D
	var pliancy: float
	var pivot: Vector2          # World-space root of the plant.
	var base_offset: Vector2    # Sprite origin relative to the pivot, unrotated.
	var base_rotation: float
	var angle: float = 0.0
	var angle_velocity: float = 0.0

var _player: PlayerController
var _blades: Array[Blade] = []
# Foliage textures are often small plants on large mostly-empty canvases, so
# the plant's true bottom comes from the opaque pixel bounds, not the canvas.
# Cached per texture — the same bush texture is reused twenty times.
var _used_rect_cache: Dictionary = {}


func _ready() -> void:
	var root := get_parent()
	_player = root.get_node_or_null("Player") as PlayerController
	if _player == null:
		return

	for container_name in CONTAINER_NAMES:
		var container := root.get_node_or_null(container_name)
		if container == null:
			continue
		for child in container.get_children():
			_try_register(child)

	var visuals := _player.get_node_or_null("VisualRoot") as PlayerVisuals
	if visuals != null:
		visuals.footfall.connect(_on_footfall)


func _try_register(node: Node) -> void:
	var sprite := node as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	var file := sprite.texture.resource_path.get_file()
	for pattern in FOLIAGE_KINDS:
		if file.begins_with(pattern):
			var blade := Blade.new()
			blade.sprite = sprite
			blade.pliancy = FOLIAGE_KINDS[pattern]
			var content := _content_rect(sprite.texture)
			var centre := sprite.texture.get_size() * 0.5
			var root_offset := Vector2(
				(content.get_center().x - centre.x) * sprite.scale.x,
				(content.end.y - centre.y) * sprite.scale.y)
			blade.pivot = sprite.global_position + root_offset
			blade.base_offset = sprite.global_position - blade.pivot
			blade.base_rotation = sprite.rotation
			_blades.append(blade)
			return


func _content_rect(texture: Texture2D) -> Rect2:
	var key := texture.resource_path
	if not _used_rect_cache.has(key):
		var image := texture.get_image()
		_used_rect_cache[key] = Rect2(image.get_used_rect()) if image != null 			else Rect2(Vector2.ZERO, texture.get_size())
	return _used_rect_cache[key]


func _physics_process(delta: float) -> void:
	if _player == null:
		return

	var feet := _player.global_position + Vector2(0.0, 39.375)
	var speed_ratio := absf(_player.velocity.x) / maxf(_player.max_run_speed, 1.0)
	var landing := _player.just_landed

	for blade in _blades:
		var to_blade := blade.pivot - feet
		var near_vertically := absf(to_blade.y) < vertical_reach

		# Brushing through: bend in the direction of travel, strongest at the
		# centre of the pass and at full run.
		if near_vertically and speed_ratio > 0.05:
			var lateral := absf(to_blade.x)
			if lateral < brush_radius:
				var falloff := 1.0 - lateral / brush_radius
				var target := brush_strength * blade.pliancy * falloff \
					* speed_ratio * signf(_player.velocity.x)
				blade.angle_velocity += (target - blade.angle) * spring_rate * delta

		# A landing thumps outward from the impact point.
		if landing and near_vertically:
			var lateral_land := absf(to_blade.x)
			if lateral_land < landing_radius and lateral_land > 0.5:
				var punch := landing_strength * blade.pliancy * _player.landing_impact \
					* (1.0 - lateral_land / landing_radius) * signf(to_blade.x)
				blade.angle_velocity += punch * spring_rate * delta * 6.0

		# Damped spring back to rest.
		blade.angle_velocity += (-blade.angle * spring_rate
			- blade.angle_velocity * spring_damping) * delta
		blade.angle += blade.angle_velocity * delta
		blade.angle = clampf(blade.angle, -1.1, 1.1)

		blade.sprite.rotation = blade.base_rotation + blade.angle
		blade.sprite.global_position = blade.pivot + blade.base_offset.rotated(blade.angle)


func _on_footfall(strength: float) -> void:
	var feet := _player.global_position + Vector2(0.0, 39.375)
	for blade in _blades:
		var to_blade := blade.pivot - feet
		if absf(to_blade.y) < vertical_reach and absf(to_blade.x) < brush_radius:
			blade.angle_velocity += footfall_strength * blade.pliancy * strength \
				* signf(to_blade.x if absf(to_blade.x) > 0.5 else 1.0)


## Test hook: current bend angle of the blade nearest to a world position.
func nearest_blade_angle(world_x: float) -> float:
	var best: Blade = null
	var best_distance := INF
	for blade in _blades:
		var d := absf(blade.pivot.x - world_x)
		if d < best_distance:
			best_distance = d
			best = blade
	return best.angle if best != null else 0.0


## Test hook: how many pieces of scenery are wired up.
func blade_count() -> int:
	return _blades.size()
