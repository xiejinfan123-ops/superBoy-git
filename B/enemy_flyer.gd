extends Area2D
## A flying enemy that hunts the player.
##
## Idles hidden until the player enters its trigger area, then appears and
## begins a cycle: hover in place with a gentle bobbing flight, telegraph a
## lunge toward the player's current position, then dash through that spot.
## The player's projectiles damage it; it dies after `max_health` hits.

signal died

@export_group("Flight")
## Speed at which the enemy orbits the player between lunges.
@export var chase_speed: float = 320.0
## Orbit radius around the player, px. The enemy circles at this distance and
## never parks on top of the player.
@export var chase_distance: float = 160.0
## Bob height of the hover, in px.
@export var hover_amplitude: float = 10.0
## Bob speed, in cycles per second.
@export var hover_speed: float = 1.6
## Maximum bank (tilt) while hovering, degrees.
@export var hover_bank_degrees: float = 8.0
## Body tilt during the lunge, degrees.
@export var lunge_tilt_degrees: float = 25.0

@export_group("Lunge")
## Seconds between lunge telegraphs (while the player is inside the trigger).
@export var lunge_interval: float = 2.2
## Length of the telegraph, seconds.
@export var telegraph_time: float = 0.6
## Dash speed, px/s.
@export var dash_speed: float = 1400.0
## How long the dash lasts, seconds.
@export var dash_time: float = 0.9

@export_group("Combat")
## Hits from a projectile needed to kill this enemy.
@export var max_health: int = 10

@export_group("Corpse")
## Gravity applied to the corpse while it falls, px/s².
@export var corpse_gravity: float = 1600.0
## How long the corpse stays before fading out, seconds.
@export var corpse_lifetime: float = 2.5

var _player: Node2D
var _sprite: Sprite2D
var _active: bool = false
var _dead: bool = false
var _health: int
var _phase: String = "hover"
var _state_time: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
var _hover_phase: float = 0.0
var _hurt_flash: float = 0.0
var _corpse_velocity: Vector2 = Vector2.ZERO
var _corpse_rot_speed: float = 0.0
var _fade_timer: float = 0.0
## Per-instance randomisation so a crowd of these does not move in lockstep.
var _r_chase_speed: float = 320.0
var _r_chase_distance: float = 160.0
var _r_lunge_interval: float = 2.2
var _r_telegraph_time: float = 0.6
var _r_hover_speed: float = 1.6
## The anchor point (relative to the player) this enemy hovers around while
## waiting to strike, and the direction it approaches that anchor from.
var _hover_dir: Vector2 = Vector2.UP


func _ready() -> void:
	add_to_group("Hittable")
	add_to_group("EnemyFlyer")
	collision_layer = 4
	collision_mask = 2 | 1
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://tp/1111.png")
	_sprite.centered = true
	add_child(_sprite)

	_health = max_health
	visible = false
	monitorable = false
	monitoring = false
	_randomise()


func _resolve_player() -> void:
	if _player != null:
		return
	_player = get_tree().get_first_node_in_group("Player")


## Rolls per-instance movement traits so a group of enemies orbits at different
## speeds, radii, directions and cadences instead of moving in lockstep.
func _randomise() -> void:
	_r_chase_speed = chase_speed * randf_range(0.7, 1.3)
	_r_chase_distance = chase_distance * randf_range(0.75, 1.35)
	_r_lunge_interval = lunge_interval * randf_range(0.7, 1.4)
	_r_telegraph_time = telegraph_time * randf_range(0.7, 1.3)
	_r_hover_speed = hover_speed * randf_range(0.7, 1.4)


## Chooses a random cardinal direction for the next hover position.
func _pick_hover_dir() -> void:
	var dirs := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	_hover_dir = dirs[randi() % dirs.size()]


func _physics_process(_delta: float) -> void:
	# A dead enemy is a falling corpse: gravity, tumble, fade.
	if _dead:
		_process_corpse(_delta)
		return
	if not _active:
		return
	_resolve_player()
	if _player == null:
		return
	var delta := _delta
	_state_time += delta
	_hurt_flash = maxf(_hurt_flash - delta, 0.0)
	if _sprite != null:
		_sprite.modulate = Color(1, 0.5, 0.45, 1) if _hurt_flash > 0.0 else Color.WHITE
	_match_phase()

	match _phase:
		"reposition":
			# Fly to the chosen anchor (a direction around the player), then
			# settle into a hover there.
			var anchor := _player.global_position + _hover_dir * _r_chase_distance
			var to_anchor := anchor - global_position
			if to_anchor.length() <= 12.0:
				_phase = "hover"
				_state_time = 0.0
			else:
				position += to_anchor.normalized() * chase_speed * 1.4 * delta
				rotation = lerp_angle(rotation, to_anchor.angle(),
					clampf(6.0 * delta, 0.0, 1.0))
		"hover":
			_hover_phase += delta * _r_hover_speed * TAU
			# Keep station relative to the player: maintain the chosen direction
			# and distance (up/down/left/right), drifting with him so the enemy
			# stays threatening but never parks on his face.
			var anchor := _player.global_position + _hover_dir * _r_chase_distance
			var to_anchor := anchor - global_position
			position += to_anchor.normalized() * chase_speed * delta
			# A little lateral sway on top, so the hover reads as alive.
			var sway := Vector2(sin(_hover_phase), cos(_hover_phase)) * 6.0
			position += sway * delta
			rotation = lerp_angle(rotation, _hover_dir.angle(),
				clampf(4.0 * delta, 0.0, 1.0))
		"telegraph":
			# Wind up: bank into the aim line and tremble, facing the player.
			_telegraph(delta)
		"dash":
			position += _dash_dir * dash_speed * delta
			rotation = lerp_angle(rotation, _dash_dir.angle(),
				clampf(8.0 * delta, 0.0, 1.0))


func _match_phase() -> void:
	if _player == null:
		return
	match _phase:
		"hover":
			if _state_time >= _r_lunge_interval:
				_phase = "telegraph"
				_state_time = 0.0
		"telegraph":
			if _state_time >= _r_telegraph_time:
				_phase = "dash"
				_state_time = 0.0
				_dash_dir = (_player.global_position - global_position).normalized()
		"dash":
			if _state_time >= dash_time:
				_phase = "reposition"
				_state_time = 0.0
				_pick_hover_dir()


func _telegraph(delta: float) -> void:
	if _player == null:
		return
	var aim := (_player.global_position - global_position).normalized()
	rotation = lerp_angle(rotation, aim.angle(),
		clampf(6.0 * delta, 0.0, 1.0))
	# Tremble: small back-and-forth on the aim line, growing as the lunge nears.
	var t := _state_time / maxf(_r_telegraph_time, 0.001)
	position += aim * sin(t * 30.0) * 1.5 * t


## Called by the player's projectile when it hits this enemy.
func take_damage(amount: int = 1) -> void:
	if not _active or _health <= 0:
		return
	_health -= amount
	_hurt_flash = 0.12
	_spawn_hit_burst()
	# The lunge is not interrupted by hits; only death stops it.
	if _health <= 0:
		_die()


func _spawn_hit_burst() -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 8
	burst.direction = Vector2.RIGHT
	burst.spread = 180.0
	burst.gravity = Vector2(0, 0)
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 140.0
	burst.lifetime = 0.3
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 2.5
	burst.color = Color(0.95, 0.6, 0.9, 0.9)
	burst.material = _make_additive_material()
	add_child(burst)


func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


func _die() -> void:
	_active = false
	_dead = true
	died.emit()
	# Turn off all collision so the corpse neither blocks the player nor takes
	# further damage, and stop hunting.
	collision_layer = 0
	collision_mask = 0
	set_deferred("monitorable", false)
	set_deferred("monitoring", false)
	# The corpse tumbles under gravity and fades, then is freed.
	_corpse_velocity = Vector2(0.0, 60.0)
	_corpse_rot_speed = randf_range(-3.0, 3.0)
	_fade_timer = corpse_lifetime


func _process_corpse(delta: float) -> void:
	# Fall with gravity and tumble. Stops accelerating on the floor if we have
	# one, otherwise keeps falling.
	_corpse_velocity.y += corpse_gravity * delta
	position += _corpse_velocity * delta
	rotation += _corpse_rot_speed * delta

	# Fade out over the last part of the corpse lifetime, then free.
	_fade_timer -= delta
	if _fade_timer <= 0.0:
		queue_free()
		return
	if _sprite != null:
		var t := clampf(_fade_timer / maxf(corpse_lifetime * 0.35, 0.001), 0.0, 1.0)
		_sprite.modulate.a = t


func activate() -> void:
	_active = true
	visible = true
	_resolve_player()
	# These toggles are forbidden during an Area2D in/out signal callback (the
	# trigger fires body_entered), so defer them to the next idle frame.
	set_deferred("monitorable", true)
	set_deferred("monitoring", true)
	print("[EnemyFlyer] activated at ", global_position)
	if _player != null:
		print("[EnemyFlyer] player at ", _player.global_position)


func is_alive() -> bool:
	return _active and not _dead


func _on_body_entered(body: Node) -> void:
	# A dash that connects with the player throws them back. The knockback
	# originates from the enemy, so the player is flung away along the impact
	# line. Only during the dash phase — hover contact should not shove.
	if _phase != "dash":
		return
	if body.is_in_group("Player"):
		if body.has_method("is_invincible") and body.is_invincible():
			return
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position, 900.0)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("Projectile"):
		take_damage()
