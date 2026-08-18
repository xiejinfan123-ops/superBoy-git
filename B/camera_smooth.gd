extends Camera2D

## Follows the player with a lead in the direction of travel.
##
## A camera locked to the character's centre gives the player no view of what
## they are running into, and reads as stiff however smooth the follow is. This
## one drifts ahead as he builds speed and drifts back as he slows, which is
## most of what "responsive" means for a side-scroller.
##
## The smoothing happens here rather than through Camera2D's own
## position_smoothing, because this script writes global_position directly every
## frame and would simply override it.

@export var target: Node2D

@export_group("Follow")
## How firmly the camera chases its mark horizontally. Higher = tighter.
@export var follow_speed: float = 9.0
## Vertical follow is deliberately looser, so small hops do not heave the whole
## view up and down.
@export var vertical_follow_speed: float = 4.5
## Vertical follow while airborne. Much tighter than on the ground: a full
## Hollow-Knight-scale jump climbs 342 px, and at the relaxed ground rate the
## player outruns the camera and presses against the top of the frame.
@export var airborne_vertical_follow_speed: float = 10.0

@export_group("Look ahead")
## Seconds of travel to lead by. At 260 px/s, 0.4 leads by about 104 px.
@export var look_ahead_seconds: float = 0.4
## Ceiling on the lead, so a fast fall or a launch cannot fling the view away.
@export var max_look_ahead: float = 150.0
## How quickly the lead builds and releases. Slower than the follow, so the
## camera eases outward instead of snapping the moment a key goes down.
@export var look_ahead_speed: float = 2.6

@export_group("Landing kick")
## Vertical nudge on the heaviest landing, in pixels.
@export var landing_kick: float = 5.0
## How quickly that nudge recovers.
@export var kick_recovery: float = 9.0

var _player: PlayerController
var _look_ahead: float = 0.0
var _kick: float = 0.0


func _ready() -> void:
	_player = target as PlayerController
	if target != null:
		global_position = target.global_position


func _physics_process(delta: float) -> void:
	if target == null:
		return

	var desired_look := 0.0
	if _player != null:
		desired_look = clampf(_player.velocity.x * look_ahead_seconds,
			-max_look_ahead, max_look_ahead)
		if _player.just_landed:
			_kick = landing_kick * _player.landing_impact
	_look_ahead = lerpf(_look_ahead, desired_look,
		1.0 - exp(-look_ahead_speed * delta))
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-kick_recovery * delta))

	var vertical_speed := vertical_follow_speed
	if _player != null and not _player.is_on_floor():
		vertical_speed = airborne_vertical_follow_speed

	var mark := target.global_position + Vector2(_look_ahead, 0.0)
	global_position = Vector2(
		lerpf(global_position.x, mark.x, 1.0 - exp(-follow_speed * delta)),
		lerpf(global_position.y, mark.y, 1.0 - exp(-vertical_speed * delta))
			+ _kick)
