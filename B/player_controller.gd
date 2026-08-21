class_name PlayerController
extends CharacterBody2D

## Emitted when the player takes a hit, with the direction the knockback
## pushes him (unit vector). The visuals/camera listen for the flash and shake.
signal hit(direction: Vector2)

## Physics and state for the player character.
## Visuals live in player_visuals.gd and only read from here.
##
## The movement profile is Hollow Knight's, converted into this character's
## scale (61.46 px per HK unit, from the ratio of collider heights). The
## extraction of every source number is documented in
## docs/reference/hollow-knight-extracted-values.md — change values there-first
## mentality: if a number here looks arbitrary, that file says where it came from.

const ProjectileScene := preload("res://B/projectile.tscn")

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

@export_group("Attack")
## Cooldown between shots, in seconds. The player cannot fire again until this
## elapses after the previous shot.
@export var attack_duration: float = 0.1
## Horizontal speed of the fired projectile, in px/s.
@export var projectile_speed: float = 900.0

@export_group("Hurt")
## Seconds of invincibility after taking a hit.
@export var i_frame_time: float = 0.7
## How long the white hurt-flash lasts, seconds.
@export var hit_flash_time: float = 0.18
## Seconds the whole game freezes on a hit (hit-stop).
@export var hit_stop_time: float = 0.08

## True while the player is invincible after a hit (blinking).
var invincible: bool = false

## True while the attack is cooling down. Read by anything that wants to show
## a fire-inhibited state.
var attacking: bool = false
## 0..1 progress through the current attack window.
var attack_progress: float = 0.0

var _attack_timer: float = 0.0
var _attacking: bool = false
var _was_grounded: bool = false
var _coyote_timer: float = 0.0
var _buffer_timer: float = 0.0
var _sustaining: bool = false
var _sustain_timer: float = 0.0
var _previous_velocity_x: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _hit_flash: float = 0.0
var _i_frame_timer: float = 0.0
var _has_i_frames: bool = false
var _hit_stop_timer: float = 0.0


func _ready() -> void:
	add_to_group("Player")


## Applies a burst of velocity away from `from`. The player is briefly driven
## by the knockback instead of the input axis.
func apply_knockback(from: Vector2, force: float) -> void:
	var dir := (global_position - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(-_facing_for_knockback(), 0.0)
	_knockback = dir * force
	velocity = _knockback
	_hit_flash = 0.18
	_has_i_frames = true
	_i_frame_timer = i_frame_time
	_hit_stop()
	hit.emit(dir)


func _facing_for_knockback() -> float:
	return -1.0 if facing == 1 else 1.0


func is_invincible() -> bool:
	return invincible


## Freezes the player's own movement for a beat so the impact reads as a hard
## hit. The knockback impulse is held (not decayed) during the freeze, then
## releases — so the player is clearly "staggered" rather than instantly
## flung. This avoids touching the global time scale, which can strand the
## player mid-frozen.
func _hit_stop() -> void:
	_hit_stop_timer = hit_stop_time


func _physics_process(delta: float) -> void:
	input.poll()
	just_landed = false
	just_jumped = false

	if _has_i_frames:
		_i_frame_timer = maxf(_i_frame_timer - delta, 0.0)
		if _i_frame_timer == 0.0:
			_has_i_frames = false
	invincible = _has_i_frames
	_hit_flash = maxf(_hit_flash - delta, 0.0)

	# Click fires a shot. If W (attack_up) is held at the moment of the click,
	# the shot goes straight up instead of horizontally.
	var want_fire := false
	var fire_dir := Vector2(facing, 0.0)
	if input.attack_just_pressed:
		want_fire = true
		if input.attack_up_held:
			fire_dir = Vector2.UP
	if want_fire and not _attacking:
		_attacking = true
		_attack_timer = attack_duration
		_fire_projectile(fire_dir)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if _attack_timer == 0.0:
		_attacking = false
	attacking = _attacking
	attack_progress = 1.0 - _attack_timer / maxf(attack_duration, 0.001)

	var grounded := is_on_floor()
	# Hit-stop: the player is staggered in place, holding the impact pose for
	# a beat. The knockback is held, then released to fling him after the
	# freeze — a hard "hit then knocked back" cadence.
	if _hit_stop_timer > 0.0:
		_hit_stop_timer = maxf(_hit_stop_timer - delta, 0.0)
		velocity = Vector2.ZERO
		_apply_gravity(delta)
	elif _knockback.length_squared() > 1.0:
		_knockback = _knockback.move_toward(Vector2.ZERO, 2400.0 * delta)
		velocity.x = _knockback.x
		_apply_gravity(delta)
	else:
		_knockback = Vector2.ZERO
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


func _fire_projectile(dir: Vector2) -> void:
	var shot := ProjectileScene.instantiate()
	get_tree().current_scene.add_child(shot)
	shot.speed = projectile_speed
	var muzzle := Vector2(0.0, -45.0)
	if dir.y != 0.0:
		muzzle = Vector2(0.0, -60.0)
	shot.fire(global_position + muzzle, dir)


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
