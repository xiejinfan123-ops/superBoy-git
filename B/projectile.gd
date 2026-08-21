extends Area2D
## A projectile fired by the player's attack.
##
## The visual is layered to read as a bolt of energy:
##   - a hot white core
##   - a coloured mid halo (magenta 鈫?cyan, handed per shot)
##   - a wide soft atmosphere glow
##   - a trail of fading embers behind the shot
## A soft additive blend keeps the layers luminous, the whole bolt rotates to
## face its travel direction, and it pops into a burst on death.

@export var speed: float = 900.0
@export var max_lifetime: float = 1.6
## How strongly the shot homes toward the nearest enemy, rad/s of turn.
@export var turn_rate: float = 6.0

var _velocity: Vector2 = Vector2.RIGHT
var _life: float = 0.0
var _hue: float = 0.0
var _trail: CPUParticles2D
var _glow: Sprite2D
var _burst_emitted: bool = false
var _target: Area2D = null


func _ready() -> void:
	add_to_group("Projectile")
	# Layer 2 = projectile; mask 1 = player body/walls (body hits) + 4 = enemies.
	collision_layer = 2
	collision_mask = 1 | 4
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# The whole bolt turns to face its direction of travel; the children inherit
	# that rotation, so the trail always trails and the streak always streaks.
	_hue = randf()
	var core_color := Color(0.98, 0.97, 1.0, 1.0)
	var mid_color := Color.from_hsv(_hue, 0.85, 1.0, 0.85)
	var glow_color := Color.from_hsv(_hue, 0.6, 1.0, 0.3)

	var core := Sprite2D.new()
	core.texture = _make_circle_texture(16, core_color)
	core.material = _make_additive_material2d()
	add_child(core)

	var mid := Sprite2D.new()
	mid.texture = _make_circle_texture(26, mid_color)
	mid.material = _make_additive_material2d()
	add_child(mid)

	_glow = Sprite2D.new()
	_glow.texture = _make_circle_texture(44, glow_color)
	_glow.material = _make_additive_material2d()
	add_child(_glow)

	# Streak along the travel axis: drawn as a horizontal teardrop that the
	# bolt's rotation points down-range.
	var streak := Sprite2D.new()
	streak.texture = _make_streak_texture(mid_color)
	streak.offset = Vector2(24, 0)
	streak.material = _make_additive_material2d()
	add_child(streak)

	_trail = CPUParticles2D.new()
	_trail.emitting = true
	_trail.amount = 14
	_trail.direction = Vector2(-1, 0)
	_trail.spread = 30.0
	_trail.gravity = Vector2(0, 0)
	_trail.initial_velocity_min = 8.0
	_trail.initial_velocity_max = 40.0
	_trail.lifetime = 0.35
	_trail.scale_amount_min = 1.5
	_trail.scale_amount_max = 3.0
	_trail.color = mid_color
	_trail.material = _make_additive_material2d()
	add_child(_trail)


func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= max_lifetime:
		_burst()
		queue_free()
		return
	_home(delta)
	position += _velocity * speed * delta

	# Face the travel direction.
	rotation = _velocity.angle()

	# The glow breathes opposite the core: the outer halo swells as the bolt
	# surges, then the core pulses bright. Two-phase pulse reads as living
	# energy rather than a metronome.
	_glow.scale = Vector2(1.0, 1.0) * (1.0 + 0.18 * sin(_life * 22.0))


## Steers the shot toward the nearest living enemy. Picks a fresh target only
## occasionally so the bolt does not flit between foes every frame.
func _home(delta: float) -> void:
	if _target == null or not is_instance_valid(_target) or _target.is_queued_for_deletion():
		_target = _nearest_enemy()
	if _target == null:
		return
	var to_target := (_target.global_position - global_position).normalized()
	var angle_diff := _velocity.angle_to(to_target)
	_velocity = _velocity.rotated(clampf(angle_diff, -turn_rate * delta, turn_rate * delta)).normalized()


func _nearest_enemy() -> Area2D:
	var best: Area2D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("Hittable"):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		# Ignore enemies that are not live targets yet (hidden, not activated,
		# or already dead).
		if node.has_method("is_alive") and not node.is_alive():
			continue
		var dist := global_position.distance_squared_to(node.global_position)
		if dist < best_dist:
			best_dist = dist
			best = node
	return best


func fire(from: Vector2, dir: Vector2) -> void:
	global_position = from
	_velocity = dir.normalized()
	rotation = _velocity.angle()


func _burst() -> void:
	if _burst_emitted:
		return
	_burst_emitted = true
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 10
	burst.direction = _velocity.normalized()
	burst.spread = 180.0
	burst.gravity = Vector2(0, 0)
	burst.initial_velocity_min = 30.0
	burst.initial_velocity_max = 120.0
	burst.lifetime = 0.3
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 2.5
	burst.color = Color.from_hsv(_hue, 0.7, 1.0, 0.9)
	burst.material = _make_additive_material2d()
	add_child(burst)


func _make_circle_texture(radius: int, color: Color) -> ImageTexture:
	var size := radius * 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in size:
		for x in size:
			var dx := float(x - radius) / radius
			var dy := float(y - radius) / radius
			var d := dx * dx + dy * dy
			if d <= 1.0:
				# Smooth falloff, slightly faster at the rim so the edge is clean.
				var falloff := pow(1.0 - d, 1.6)
				img.set_pixel(x, y, Color(color.r, color.g, color.b,
					color.a * falloff))
	return ImageTexture.create_from_image(img)


func _make_streak_texture(color: Color) -> ImageTexture:
	# A horizontal teardrop: dense at the tail, tapering to a point at the tip.
	# Rendered 48 wide, centred, with the tip at the right edge.
	var w := 48
	var h := 18
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var t := float(x) / float(w - 1)
			var centre := float(y) / float(h - 1) - 0.5
			var tip := 1.0 - t
			var falloff := clampf(1.0 - absf(centre) * 2.2, 0.0, 1.0)
			falloff *= tip * tip * 1.8
			img.set_pixel(x, y, Color(color.r, color.g, color.b,
				color.a * falloff))
	return ImageTexture.create_from_image(img)


func _make_additive_material2d() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


func _on_body_entered(body: Node) -> void:
	if body is TileMapLayer or body is StaticBody2D:
		_burst()
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("Hittable"):
		_burst()
		queue_free()
