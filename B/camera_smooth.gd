extends Camera2D

## Follows the player with a lead in the direction of travel.
##
## A small dead zone keeps the camera still while the character shuffles
## around its centre, so the view reads as stable. When he commits to a
## direction, the camera eases ahead to show what he is running into, and
## eases back as he slows. Vertical follow is looser on the ground so hops do
## not heave the whole view up and down, but tightens while airborne so he
## does not outrun the frame on a full jump.

@export var target: Node2D

@export_group("Dead zone")
## Half-size of the box around the camera centre where the player moves
## freely without moving the camera, in pixels.
@export var dead_zone: Vector2 = Vector2(40, 25)
## How hard the camera pushes to drag the player back into the dead zone
## once he steps out of it.
@export var dead_zone_return: float = 6.0

@export_group("Follow")
## How firmly the camera chases its mark horizontally. Higher = tighter.
@export var follow_speed: float = 9.0
## Vertical follow is deliberately looser, so small hops do not heave the
## whole view up and down.
@export var vertical_follow_speed: float = 4.5
## Vertical follow while airborne. Much tighter than on the ground: a full
## Hollow-Knight-scale jump climbs 342 px, and at the relaxed ground rate the
## player outruns the camera and presses against the top of the frame.
@export var airborne_vertical_follow_speed: float = 10.0

@export_group("Look ahead")
## Seconds of travel to lead by. At 260 px/s, 0.4 leads by about 104 px.
@export var look_ahead_seconds: float = 0.35
## Ceiling on the lead, so a fast fall or a launch cannot fling the view away.
@export var max_look_ahead: float = 130.0
## How quickly the lead builds and releases. Slower than the follow, so the
## camera eases outward instead of snapping the moment a key goes down.
@export var look_ahead_speed: float = 2.6

var _player: PlayerController
var _look_ahead: float = 0.0
var _kick: float = 0.0
var _centred: bool = false


func _ready() -> void:
	_player = target as PlayerController
	if target != null:
		global_position = target.global_position
		_centred = true


func _physics_process(delta: float) -> void:
	if target == null:
		return

	# Lead the view in the direction of travel, but only while the player is
	# actually moving, not while he is idling inside the dead zone.
	var desired_look := 0.0
	if _player != null:
		desired_look = clampf(_player.velocity.x * look_ahead_seconds,
			-max_look_ahead, max_look_ahead)
	_look_ahead = lerpf(_look_ahead, desired_look,
		1.0 - exp(-look_ahead_speed * delta))

	var vertical_speed := vertical_follow_speed
	if _player != null and not _player.is_on_floor():
		vertical_speed = airborne_vertical_follow_speed

	var mark := target.global_position + Vector2(_look_ahead, 0.0)

	var offset := global_position - mark
	var correction := Vector2.ZERO

	# Only nudge the camera once the player steps out of the dead zone.
	if absf(offset.x) > dead_zone.x:
		correction.x = offset.x - signf(offset.x) * dead_zone.x
	if absf(offset.y) > dead_zone.y:
		correction.y = offset.y - signf(offset.y) * dead_zone.y

	global_position = Vector2(
		lerpf(global_position.x, global_position.x - correction.x,
			1.0 - exp(-follow_speed * delta)),
		lerpf(global_position.y, global_position.y - correction.y,
			1.0 - exp(-vertical_speed * delta)))

	# Landing kick: only on genuinely heavy landings, and a fraction of what
	# the old code did so it reads as weight, not camera shake.
	if _player != null and _player.just_landed:
		_kick = 3.0 * _player.landing_impact
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-9.0 * delta))
	global_position.y += _kick
