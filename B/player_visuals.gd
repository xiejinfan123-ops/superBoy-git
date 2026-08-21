class_name PlayerVisuals
extends Node2D

## Emitted the instant a foot plants, twice per stride cycle. `strength` is
## 0..1 from a crawl to a full run. Dust, sound and the contact jolt all hang
## off this rather than off a timer, so they stay welded to the footfall.
signal footfall(strength: float)

## Cosmetic layer. Reads PlayerController state and drives the character's
## transform. Deleting this node changes nothing about physics.
##
## This node sits at the character's feet, so every scale and rotation applied
## here pivots there: he compresses into the ground and leans from his soles,
## rather than deforming around his middle.

@export_group("Stride")
## Ground distance covered by one complete two-step cycle.
##
## The stride is advanced by distance travelled rather than by elapsed time.
## On a timer the feet skate whenever his speed changes; on distance each step
## lands where the ground actually is, at any speed.
@export var stride_length: float = 120.0
## Peak swing of each leg away from vertical, at the extremes of a stride.
@export var max_leg_swing_degrees: float = 26.0
## Shapes the swing. 1.0 is a plain sine, which reads as a metronome because
## the leg is never still. Below 1.0 the leg reaches its extremes sooner and
## lingers there, which is what planting a foot looks like.
@export_range(0.4, 1.5, 0.05) var stride_curve: float = 0.72
## How quickly the legs settle to standing when he stops.
@export var leg_settle_speed: float = 12.0
## Vertical dip of the torso at the widest point of each stride.
@export var torso_bob: float = 1.6

@export_group("Airborne")
## Leg angles held while off the ground, in degrees. Legs that keep cycling
## mid-jump are the giveaway of a rig that is not paying attention.
@export var airborne_far_leg_degrees: float = 9.0
@export var airborne_near_leg_degrees: float = -7.0
## How quickly the legs adopt or leave the airborne pose.
@export var airborne_pose_speed: float = 14.0

@export_group("Squash and stretch")
## Peak widen-and-flatten on the hardest possible landing.
@export var max_land_squash: float = 0.28
## Peak narrow-and-lengthen at the moment of takeoff.
@export var max_jump_stretch: float = 0.16
## How quickly a squash or stretch relaxes back to normal. Higher = snappier.
@export var squash_recovery: float = 11.0

@export_group("Lean")
## Extra tilt from acceleration: forward as he sets off, backward as he pulls
## up. This is the anticipation and settle that makes starting and stopping
## read as effort rather than as a value changing.
@export var accel_lean_degrees: float = 7.0
## Acceleration treated as full lurch, in px/s squared.
@export var accel_lean_reference: float = 2400.0
## Maximum tilt into the direction of travel, at top speed.
@export var max_lean_degrees: float = 6.0
## Fraction of the ground lean applied while airborne.
@export var air_lean_scale: float = 0.5
## How quickly the lean follows changes in speed.
@export var lean_smoothing: float = 9.0

@export_group("Idle")
## Size of the standing-still breathing pulse.
@export var breath_amplitude: float = 0.015
## Breaths per second, roughly.
@export var breath_speed: float = 2.2
## Below this fraction of top speed the character counts as standing still.
@export var idle_speed_threshold: float = 0.05

var _player: PlayerController
var _leg_far: Node2D
var _leg_near: Node2D
var _torso: Node2D

## Positive = squashed (wider, shorter). Negative = stretched (narrower, taller).
var _squash: float = 0.0
var _lean: float = 0.0
var _breath_phase: float = 0.0
var _stride_phase: float = 0.0
var _far_angle: float = 0.0
var _near_angle: float = 0.0
var _torso_rest_y: float = 0.0
var _hurt_flash: float = 0.0


func _ready() -> void:
	_player = get_parent() as PlayerController
	_leg_far = get_node_or_null("LegFar")
	_leg_near = get_node_or_null("LegNear")
	_torso = get_node_or_null("Torso")
	if _torso != null:
		_torso_rest_y = _torso.position.y
	if _player != null:
		_player.hit.connect(_on_player_hit)


func _on_player_hit(_dir: Vector2) -> void:
	_hurt_flash = 1.0
	_apply_hurt()


func _apply_hurt() -> void:
	# Snap a hurt jolt into the squash: a sharp inward squeeze that reads as a
	# punch being taken, distinct from the soft landing squash.
	_squash = 0.22


func _physics_process(delta: float) -> void:
	if _player == null:
		return

	_update_squash(delta)
	_update_lean(delta)
	var breath := _update_breath(delta)
	_update_stride(delta)

	_hurt_flash = maxf(_hurt_flash - delta * 4.0, 0.0)

	var horizontal := (1.0 + _squash) * float(_player.facing)
	var vertical := 1.0 - _squash + breath
	scale = Vector2(horizontal, vertical)
	rotation = _lean

	# White hurt flash, and a blink while invincible.
	var mod := Color(1, 1, 1, 1)
	if _hurt_flash > 0.0:
		mod = Color(1.0, 0.55, 0.45, 1.0)
	elif _player.invincible and int(Time.get_ticks_msec() / 90) % 2 == 0:
		mod.a = 0.45
	self_modulate = mod


func _update_squash(delta: float) -> void:
	if _player.just_landed:
		_squash = max_land_squash * _player.landing_impact
	elif _player.just_jumped:
		_squash = -max_jump_stretch
	# Frame-rate independent exponential relaxation back to neutral.
	_squash = lerpf(_squash, 0.0, 1.0 - exp(-squash_recovery * delta))


func _update_lean(delta: float) -> void:
	var speed_ratio := clampf(_player.velocity.x / maxf(_player.max_run_speed, 1.0),
		-1.0, 1.0)
	var target := deg_to_rad(max_lean_degrees) * speed_ratio
	var accel_ratio := clampf(_player.accel_x / maxf(accel_lean_reference, 1.0),
		-1.0, 1.0)
	target += deg_to_rad(accel_lean_degrees) * accel_ratio
	if not _player.is_on_floor():
		target *= air_lean_scale
	_lean = lerpf(_lean, target, 1.0 - exp(-lean_smoothing * delta))


func _update_breath(delta: float) -> float:
	var speed_ratio := absf(_player.velocity.x) / maxf(_player.max_run_speed, 1.0)
	if not _player.is_on_floor() or speed_ratio > idle_speed_threshold:
		_breath_phase = 0.0
		return 0.0
	_breath_phase += delta * breath_speed
	return sin(_breath_phase) * breath_amplitude



func _update_stride(delta: float) -> void:
	if _leg_far == null or _leg_near == null:
		return

	var grounded := _player.is_on_floor()
	var travelled := absf(_player.velocity.x) * delta
	var swing := deg_to_rad(max_leg_swing_degrees)
	var target_far: float
	var target_near: float
	var blend: float

	if not grounded:
		# Hold a fixed pose and leave the phase untouched, so he resumes the
		# stride where he left it instead of snapping on landing.
		target_far = deg_to_rad(airborne_far_leg_degrees)
		target_near = deg_to_rad(airborne_near_leg_degrees)
		blend = airborne_pose_speed
	elif travelled > 0.0001:
		var previous := _stride_phase
		_stride_phase = fposmod(
			_stride_phase + (travelled / maxf(stride_length, 0.001)) * TAU, TAU)
		_report_footfalls(previous, _stride_phase)
		var wave := sin(_stride_phase)
		target_far = swing * signf(wave) * pow(absf(wave), stride_curve)
		target_near = -target_far
		blend = 30.0
	else:
		# Standing: unwind to a neutral stance rather than freezing mid-step.
		_stride_phase = 0.0
		target_far = 0.0
		target_near = 0.0
		blend = leg_settle_speed

	var weight := 1.0 - exp(-blend * delta)
	_far_angle = lerpf(_far_angle, target_far, weight)
	_near_angle = lerpf(_near_angle, target_near, weight)
	_leg_far.rotation = _far_angle
	_leg_near.rotation = _near_angle

	if _torso != null:
		# Lowest when his legs are furthest apart, which is where a real stride
		# loses height.
		var dip := torso_bob * absf(sin(_stride_phase)) if grounded else 0.0
		_torso.position.y = lerpf(_torso.position.y, _torso_rest_y + dip, weight)


## A foot plants at each extreme of the swing, so the stride crosses PI/2 and
## 3*PI/2 exactly once per step. Checking for the crossing rather than sampling
## the angle means no step is ever missed at high speed, when a single frame can
## advance the phase a long way.
func _report_footfalls(previous: float, current: float) -> void:
	var strength := clampf(
		absf(_player.velocity.x) / maxf(_player.max_run_speed, 1.0), 0.0, 1.0)
	for mark in [PI * 0.5, PI * 1.5]:
		if _crossed(previous, current, mark):
			footfall.emit(strength)


func _crossed(previous: float, current: float, mark: float) -> bool:
	if current >= previous:
		return previous < mark and current >= mark
	# The phase wrapped past TAU this frame.
	return previous < mark or current >= mark
