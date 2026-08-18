extends Camera2D

## Dead-zone follow (this repo's base approach) with a look-ahead lead and
## airborne tightening layered on top.
##
## Base behaviour, unchanged in spirit: the camera only moves once the target
## leaves a box centred `focus_offset` away from it. That's what keeps small
## movements from jittering the view.
##
## Layered on top: the box chases a point AHEAD of the player by his direction
## of travel, not the player's raw position, so a run builds up a lead before
## the dead zone even engages. And the vertical chase speed tightens sharply
## while airborne, because a full Hollow-Knight-scale jump (342 px) otherwise
## outruns the dead zone and pins him to the top of the frame.

@export var target: Node2D
@export var smoothing: float = 8.0
@export var dead_zone: Vector2 = Vector2(100, 80)
@export var focus_offset: Vector2 = Vector2(50, 0)

@export_group("Look ahead")
## Seconds of travel to lead by.
##
## Sized against this system's own tracking lag, not just against speed: a
## dead-zone camera that moves a fraction of its remaining distance every
## frame never fully catches a constantly-moving target, so it settles with a
## built-in lag of roughly dead_zone + velocity / smoothing. The look-ahead has
## to clear the static focus_offset AND that lag before the camera visibly
## leads rather than trails. Retune this if dead_zone changes materially — a
## looser zone shortens the lag, so less look-ahead is needed to net a lead.
@export var look_ahead_seconds: float = 0.8
## Ceiling on the lead, so a fast fall or a launch cannot fling the view away.
@export var max_look_ahead: float = 420.0
## How quickly the lead builds and releases.
@export var look_ahead_speed: float = 2.6

@export_group("Airborne")
## Vertical chase multiplier while off the ground. Higher = tighter.
@export var airborne_vertical_multiplier: float = 2.5

@export_group("Landing kick")
## Vertical nudge on the heaviest landing, in pixels.
@export var landing_kick: float = 5.0
## How quickly that nudge recovers.
@export var kick_recovery: float = 9.0

var _player: PlayerController
var _look_ahead: float = 0.0
var _kick: float = 0.0


func _physics_process(delta: float) -> void:
	if not target:
		return
	if _player == null:
		_player = target as PlayerController

	var desired_look := 0.0
	if _player != null:
		desired_look = clampf(_player.velocity.x * look_ahead_seconds,
			-max_look_ahead, max_look_ahead)
		if _player.just_landed:
			_kick = landing_kick * _player.landing_impact
	_look_ahead = lerpf(_look_ahead, desired_look,
		1.0 - exp(-look_ahead_speed * delta))
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-kick_recovery * delta))

	var lead_target := target.global_position + Vector2(_look_ahead, -_kick)
	var screen_pos := lead_target - (global_position + focus_offset)

	var vertical_multiplier := 1.0
	if _player != null and not _player.is_on_floor():
		vertical_multiplier = airborne_vertical_multiplier

	var move := Vector2.ZERO
	if absf(screen_pos.x) > dead_zone.x:
		move.x = screen_pos.x - signf(screen_pos.x) * dead_zone.x
	if absf(screen_pos.y) > dead_zone.y:
		move.y = (screen_pos.y - signf(screen_pos.y) * dead_zone.y) * vertical_multiplier

	global_position += move * clampf(smoothing * delta, 0.0, 1.0)
