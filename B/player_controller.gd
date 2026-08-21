class_name PlayerController
extends CharacterBody2D

## Physics and state for the player character.
## Visuals live in player_visuals.gd and only read from here.
##
## The movement profile is Hollow Knight's, converted into this character's
## scale (61.46 px per HK unit, from the ratio of collider heights). The
## extraction of every source number is documented in
## docs/reference/hollow-knight-extracted-values.md — change values there-first
## mentality: if a number here looks arbitrary, that file says where it came from.

@export_group("Run")
## Top horizontal speed. HK: RUN_SPEED 8.3 u/s.
@export var max_run_speed: float = 310.0
## Ground speed build-up. HK sets velocity outright (no ramp); the finite ramp
## here is the deliberate Rain World half of the recipe — about 0.09 s to full.
## Raise it to approach HK exactly.
@export var ground_acceleration: float = 6000.0
## Ground speed bleed-off with no direction held. HK stops outright; same
## deliberate softening as ground_acceleration.
@export var ground_friction: float = 6000.0
## Extra braking when the held direction opposes current motion.
@export var turn_brake_multiplier: float = 2.0
## Mid-air steering. HK steers as strongly in the air as on the ground; kept
## slightly under the ground value so airborne drift still reads as airborne.
@export var air_acceleration: float = 4500.0
## Mid-air drag when no direction is held.
@export var air_friction: float = 1500.0

@export_group("Jump")
## Rise velocity pinned during the sustain phase. HK: JUMP_SPEED 16.65 u/s.
##
## HK's jump is a SUSTAIN, not an impulse: while the button is held the rise
## velocity is pinned here every physics step, between the min and max sustain
## times below. Gravity only takes over afterwards. This phase — not asymmetric
## gravity — is what makes the arc float on the way up and bite on the way down.
@export var jump_speed: float = 1023.0
## Sustain lasts at least this long even if the button is tapped.
## HK: JUMP_STEPS_MIN, 4 steps at 50 Hz.
@export var jump_sustain_min_time: float = 0.08
## Sustain ends here no matter how long the button is held.
## HK: JUMP_STEPS, 9 steps at 50 Hz.
@export var jump_sustain_max_time: float = 0.18
## Releasing after the minimum clamps any remaining rise to this.
## HK: MIN_JUMP_SPEED 3.0 u/s.
@export var jump_release_speed: float = 184.0
## Gravity. HK: 60 u/s² world gravity × 0.79 body scale = 47.4 u/s², and it is
## symmetric — the rise/fall feel difference comes from the sustain phase.
@export var gravity: float = 2913.0
## Terminal velocity. HK: MAX_FALL_VELOCITY 20 u/s.
@export var max_fall_speed: float = 1229.0

@export_group("Forgiveness")
## Grace period after walking off a ledge. HK: LEDGE_BUFFER_STEPS, 0.04 s.
@export var coyote_time: float = 0.04
## How long an early jump press is remembered. HK: JUMP_QUEUE_STEPS, 0.04 s.
@export var jump_buffer_time: float = 0.04

var input: PlayerInput = PlayerInput.new()

## +1 facing right, -1 facing left. Read by the visuals layer.
var facing: int = 1

## True for the single physics frame on which the player touched down.
var just_landed: bool = false
## 0.0–1.0 severity of that landing, as a fraction of max_fall_speed.
var landing_impact: float = 0.0

## True for the single physics frame on which the player left the ground.
var just_jumped: bool = false

## Horizontal acceleration this frame, in px/s². The visuals lean on this to
## produce a lurch when he sets off and a settle when he pulls up — anticipation
## that velocity alone cannot express, because velocity is identical whether he
## is speeding up into it or coasting down out of it.
var accel_x: float = 0.0

var _was_grounded: bool = false
var _coyote_timer: float = 0.0
var _buffer_timer: float = 0.0
var _sustaining: bool = false
var _sustain_timer: float = 0.0
var _previous_velocity_x: float = 0.0


func _physics_process(delta: float) -> void:
	input.poll()
	just_landed = false
	just_jumped = false

	var grounded := is_on_floor()
	_apply_horizontal(delta, grounded)
	_apply_jump(delta, grounded)
	_apply_gravity(delta)

	var impact_speed := velocity.y
	move_and_slide()

	# Sustaining into a ceiling would pin him against it for the rest of the
	# window; hitting one ends the rise on the spot.
	if _sustaining and is_on_ceiling():
		_sustaining = false
		velocity.y = 0.0

	var now_grounded := is_on_floor()
	if now_grounded and not _was_grounded:
		just_landed = true
		landing_impact = clampf(impact_speed / max_fall_speed, 0.0, 1.0)
	_was_grounded = now_grounded

	accel_x = (velocity.x - _previous_velocity_x) / delta
	_previous_velocity_x = velocity.x


func _apply_gravity(delta: float) -> void:
	if _sustaining:
		return
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)


func _apply_horizontal(delta: float, grounded: bool) -> void:
	var acceleration := ground_acceleration if grounded else air_acceleration
	var friction := ground_friction if grounded else air_friction

	if absf(input.move_axis) <= 0.01:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		return

	if signf(input.move_axis) != signf(velocity.x) and absf(velocity.x) > 1.0:
		acceleration *= turn_brake_multiplier

	velocity.x = move_toward(velocity.x, input.move_axis * max_run_speed,
		acceleration * delta)
	facing = 1 if input.move_axis > 0.0 else -1


func _apply_jump(delta: float, grounded: bool) -> void:
	if grounded:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if input.jump_just_pressed:
		_buffer_timer = jump_buffer_time
	else:
		_buffer_timer = maxf(_buffer_timer - delta, 0.0)

	if _buffer_timer > 0.0 and _coyote_timer > 0.0:
		_sustaining = true
		_sustain_timer = 0.0
		just_jumped = true
		_buffer_timer = 0.0
		_coyote_timer = 0.0

	if not _sustaining:
		return

	_sustain_timer += delta
	velocity.y = -jump_speed

	var min_served := _sustain_timer >= jump_sustain_min_time
	if _sustain_timer >= jump_sustain_max_time:
		_sustaining = false
	elif min_served and not input.jump_held:
		# Early release: the remaining rise is clamped, which is what separates
		# a tap from a full hold. A buffered jump can start with the button
		# already up, so this checks held-state, not a release edge.
		_sustaining = false
		velocity.y = -jump_release_speed
