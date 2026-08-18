extends SceneTree

## Headless test runner. Run with:
##   godot --headless --path <project> --script res://tests/run_tests.gd
## Exits 0 when everything passes, 1 otherwise.
##
## Every test returns bool and must `return true` on each exit path. A runtime
## error inside a coroutine aborts it silently and leaves its error list empty,
## which would otherwise be indistinguishable from success — the completion
## value is what separates "found nothing wrong" from "died before looking".
## Declaring the return type as bool makes GDScript reject any path that forgets.

const FLOOR_TOP := 100.0
const COLLIDER_HALF_HEIGHT := 39.375

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_main()


func _main() -> void:
	# Priming await. physics_frame fires before _physics_process, so this first
	# one advances zero processed frames. Every await after it is worth exactly
	# one frame, which is what _step() relies on.
	await physics_frame

	await _run("harness boots and physics steps", _test_harness_boots)
	await _run("harness detects aborted tests", _test_harness_detects_aborts)
	await _run("player scene geometry", _test_player_scene_geometry)
	await _run("falls under gravity", _test_falls_under_gravity)
	await _run("lands on floor", _test_lands_on_floor)
	await _run("fall speed is capped", _test_fall_speed_is_capped)
	await _run("landing is reported", _test_landing_is_reported)
	await _run("run accelerates gradually", _test_run_accelerates_gradually)
	await _run("friction decelerates gradually", _test_friction_decelerates_gradually)
	await _run("turning brakes faster than coasting", _test_turning_brakes_faster_than_coasting)
	await _run("air control is weaker than ground", _test_air_control_is_weaker_than_ground)
	await _run("facing follows input", _test_facing_follows_input)
	await _run("jump leaves the ground", _test_jump_leaves_the_ground)
	await _run("jump reports takeoff", _test_jump_reports_takeoff)
	await _run("held jump goes higher than tapped", _test_held_jump_goes_higher_than_tapped)
	await _run("jump returns to ground", _test_jump_returns_to_ground)
	await _run("coyote time allows late jump", _test_coyote_time_allows_late_jump)
	await _run("coyote time expires", _test_coyote_time_expires)
	await _run("jump buffer fires on landing", _test_jump_buffer_fires_on_landing)
	await _run("buffered tap stays short", _test_buffered_tap_stays_short)
	await _run("visual root flips with facing", _test_visual_root_flips_with_facing)
	await _run("landing squashes then recovers", _test_landing_squashes_then_recovers)
	await _run("jump stretches", _test_jump_stretches)
	await _run("running leans into direction", _test_running_leans_into_direction)
	await _run("idle breathes without drifting", _test_idle_breathes_without_drifting)
	await _run("legs swing in opposition", _test_legs_swing_in_opposition)
	await _run("stride is distance-driven", _test_stride_is_distance_driven_not_time_driven)
	await _run("airborne holds leg pose", _test_airborne_holds_leg_pose)
	await _run("idle returns legs to neutral", _test_idle_returns_legs_to_neutral)
	await _run("footfall fires twice per stride", _test_footfall_fires_twice_per_stride)
	await _run("footfall strength tracks speed", _test_footfall_strength_tracks_speed)
	await _run("acceleration produces a lurch", _test_acceleration_produces_a_lurch)
	await _run("footfall raises dust", _test_footfall_raises_dust)
	await _run("camera leads the direction of travel", _test_camera_leads_the_direction_of_travel)
	await _run("cape trails behind when running", _test_cape_trails_behind_when_running)
	await _run("cape settles when stopped", _test_cape_settles_when_stopped)
	await _run("cape never goes below the floor", _test_cape_never_goes_below_the_floor)
	await _run("cape stays finite under abuse", _test_cape_stays_finite_under_abuse)
	await _run("cape comes home untangled after abuse", _test_cape_comes_home_untangled)
	await _run("world scenery is wired", _test_world_scenery_is_wired)
	await _run("foliage bends when run through and recovers", _test_foliage_bends_when_run_through_and_recovers)
	await _run("main scene player stands on real ground", _test_main_scene_player_stands_on_real_ground)

	print("RESULT passed=%d failed=%d" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run(label: String, fn: Callable) -> void:
	var errors: Array[String] = []
	var completed: Variant = await fn.call(errors)
	if completed != true:
		errors.append("test aborted before completion — see the SCRIPT ERROR above")
	if errors.is_empty():
		_passed += 1
		print("PASS %s" % label)
	else:
		_failed += 1
		for e in errors:
			print("FAIL %s :: %s" % [label, e])
	await _clear_world()


func _clear_world() -> void:
	for child in get_root().get_children():
		get_root().remove_child(child)
		child.queue_free()
	await physics_frame


## Advances the simulation by exactly `frames` physics frames, with their
## _physics_process results visible on return. Valid only after _main()'s
## priming await.
func _step(frames: int) -> void:
	for _i in range(frames):
		await physics_frame


func _make_floor(top_y: float, left_x: float, right_x: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(right_x - left_x, 400.0)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = Vector2((left_x + right_x) * 0.5, top_y + 200.0)
	get_root().add_child(body)
	return body


func _spawn_player(pos: Vector2) -> PlayerController:
	var packed: PackedScene = load("res://B/player.tscn")
	var player: PlayerController = packed.instantiate()
	get_root().add_child(player)
	player.global_position = pos
	player.input = FakeInput.new()
	return player


# --- Harness self-checks ---

func _test_harness_boots(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -500.0, 500.0)
	var probe := CharacterBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(35.0, 78.75)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	probe.add_child(collider)
	get_root().add_child(probe)
	probe.global_position = Vector2(0.0, -100.0)

	for _i in range(180):
		await physics_frame
		probe.velocity.y += 980.0 / 60.0
		probe.move_and_slide()
		if probe.is_on_floor():
			break

	if not probe.is_on_floor():
		errors.append("probe never landed, y=%f" % probe.global_position.y)
		return true
	var feet := probe.global_position.y + COLLIDER_HALF_HEIGHT
	if absf(feet - FLOOR_TOP) > 1.0:
		errors.append("feet expected ~%f, got %f" % [FLOOR_TOP, feet])
	return true


## Proves the runner cannot be fooled by a test that dies part-way through.
## Sends a deliberately crashing callable down the same path _run uses and
## checks the abort is noticed. The SCRIPT ERROR this prints is expected output.
func _test_harness_detects_aborts(errors: Array) -> bool:
	var ignored: Array[String] = []
	var completed: Variant = await _deliberately_aborting_test(ignored)
	if completed == true:
		errors.append("a crashing test reported completion")
	return true


func _deliberately_aborting_test(_errors: Array) -> bool:
	await physics_frame
	var nothing: Node = null
	# Intentional null dereference: aborts this coroutine the way a real bug would.
	nothing.get_parent()
	return true


# --- Player scene ---

func _test_player_scene_geometry(errors: Array) -> bool:
	var player := _spawn_player(Vector2(0.0, 0.0))
	var visual_root: Node2D = player.get_node("VisualRoot")
	var sprite: Sprite2D = player.get_node("VisualRoot/Torso")

	if absf(visual_root.position.y - COLLIDER_HALF_HEIGHT) > 0.01:
		errors.append("VisualRoot must sit at the feet (%f), got %f"
			% [COLLIDER_HALF_HEIGHT, visual_root.position.y])

	if sprite.texture.resource_path != "res://C/char_torso.png":
		errors.append("torso must use the cut torso layer, got %s"
			% sprite.texture.resource_path)

	# The cape is simulated cloth (CapeCloth on a Polygon2D), not a sprite.
	var cape := player.get_node_or_null("VisualRoot/Cape") as CapeCloth
	if cape == null:
		errors.append("missing CapeCloth cape node")
	elif cape.texture == null or cape.texture.resource_path != "res://C/char_cape.png":
		errors.append("cape cloth must use the independent cape layer")

	# The artwork's opaque centre must land on VisualRoot's x = 0 so that
	# flipping via scale.x = -1 does not shift the character sideways.
	var opaque_centre_x: float = sprite.position.x + (989.0 - 1024.0) * sprite.scale.x
	if absf(opaque_centre_x) > 0.05:
		errors.append("artwork centre should be at x=0, got %f" % opaque_centre_x)

	# The artwork's feet must land on VisualRoot's origin.
	var feet_y: float = sprite.position.y + (1984.0 - 1024.0) * sprite.scale.y
	if absf(feet_y) > 0.05:
		errors.append("artwork feet should be at y=0, got %f" % feet_y)

	# Torso spans source y 49..1745; the legs carry the rest down to 1984.
	# Together they must still stand exactly as tall as the collider.
	var full_height: float = (1984.0 - 49.0) * sprite.scale.y
	if absf(full_height - 78.75) > 0.5:
		errors.append("character height should be 78.75, got %f" % full_height)

	for leg_path in ["VisualRoot/LegFar", "VisualRoot/LegNear"]:
		var leg: Node2D = player.get_node_or_null(leg_path)
		if leg == null:
			errors.append("missing %s" % leg_path)
			continue
		var leg_sprite: Sprite2D = leg.get_node_or_null("Sprite2D")
		if leg_sprite == null:
			errors.append("%s has no Sprite2D" % leg_path)
			continue
		# Each leg piece must line up with the torso as if never cut apart.
		var combined := leg.position + leg_sprite.position
		if combined.distance_to(sprite.position) > 0.01:
			errors.append("%s does not align with the torso: %s vs %s"
				% [leg_path, str(combined), str(sprite.position)])
	return true


# --- Gravity ---

func _test_falls_under_gravity(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -500.0, 500.0)
	var player := _spawn_player(Vector2(0.0, -200.0))
	await _step(3)
	if player.velocity.y <= 0.0:
		errors.append("expected downward velocity, got %f" % player.velocity.y)
	return true


func _test_lands_on_floor(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -500.0, 500.0)
	var player := _spawn_player(Vector2(0.0, -200.0))
	await _step(180)
	if not player.is_on_floor():
		errors.append("expected to land, y=%f" % player.global_position.y)
		return true
	var feet := player.global_position.y + COLLIDER_HALF_HEIGHT
	if absf(feet - FLOOR_TOP) > 1.0:
		errors.append("feet expected ~%f, got %f" % [FLOOR_TOP, feet])
	return true


func _test_fall_speed_is_capped(errors: Array) -> bool:
	var player := _spawn_player(Vector2(0.0, -200.0))
	await _step(300)
	if player.velocity.y > player.max_fall_speed + 1.0:
		errors.append("fall speed %f exceeded cap %f"
			% [player.velocity.y, player.max_fall_speed])
	return true


func _test_landing_is_reported(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -500.0, 500.0)
	var player := _spawn_player(Vector2(0.0, -200.0))
	var saw_landing := false
	var impact := 0.0
	for _i in range(180):
		await physics_frame
		if player.just_landed:
			saw_landing = true
			impact = player.landing_impact
			break
	if not saw_landing:
		errors.append("just_landed never fired")
		return true
	if impact <= 0.0 or impact > 1.0:
		errors.append("landing_impact should be in (0,1], got %f" % impact)
	return true


# --- Horizontal movement ---

func _test_run_accelerates_gradually(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var fake: FakeInput = player.input
	await _step(2)
	fake.move_axis = 1.0

	await _step(1)
	var after_one := player.velocity.x
	if after_one <= 0.0:
		errors.append("expected rightward motion, got %f" % after_one)
		return true
	if after_one >= player.max_run_speed * 0.9:
		errors.append("speed should ramp, not snap: %f after one frame" % after_one)

	await _step(60)
	if player.velocity.x < player.max_run_speed * 0.95:
		errors.append("should reach near top speed, got %f" % player.velocity.x)
	return true


func _test_friction_decelerates_gradually(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var fake: FakeInput = player.input
	fake.move_axis = 1.0
	await _step(60)
	fake.move_axis = 0.0

	await _step(1)
	if player.velocity.x <= 0.0:
		errors.append("should coast, not stop dead: %f" % player.velocity.x)

	await _step(60)
	if absf(player.velocity.x) > 1.0:
		errors.append("should come to rest, got %f" % player.velocity.x)
	return true


## Both halves are measured one at a time. Two CharacterBody2D instances share
## the default collision layer and would push each other around if they existed
## in the same world at the same time.
func _test_turning_brakes_faster_than_coasting(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var coasting := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var coast_input: FakeInput = coasting.input
	coast_input.move_axis = 1.0
	await _step(60)
	coast_input.move_axis = 0.0
	await _step(4)
	var coast_speed := coasting.velocity.x
	await _clear_world()

	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var turning := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var turn_input: FakeInput = turning.input
	turn_input.move_axis = 1.0
	await _step(60)
	turn_input.move_axis = -1.0
	await _step(4)
	var turn_speed := turning.velocity.x

	if turn_speed >= coast_speed:
		errors.append("turning (%f) should shed speed faster than coasting (%f)"
			% [turn_speed, coast_speed])
	return true


func _test_air_control_is_weaker_than_ground(errors: Array) -> bool:
	var airborne := _spawn_player(Vector2(0.0, -400.0))
	var air_input: FakeInput = airborne.input
	air_input.move_axis = 1.0
	await _step(5)
	var air_speed := airborne.velocity.x
	await _clear_world()

	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var grounded := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var ground_input: FakeInput = grounded.input
	await _step(2)
	ground_input.move_axis = 1.0
	await _step(5)
	var ground_speed := grounded.velocity.x

	if air_speed >= ground_speed:
		errors.append("air accel (%f) should be weaker than ground (%f)"
			% [air_speed, ground_speed])
	return true


func _test_facing_follows_input(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var fake: FakeInput = player.input

	fake.move_axis = 1.0
	await _step(2)
	if player.facing != 1:
		errors.append("facing should be +1 moving right, got %d" % player.facing)

	fake.move_axis = -1.0
	await _step(2)
	if player.facing != -1:
		errors.append("facing should be -1 moving left, got %d" % player.facing)

	fake.move_axis = 0.0
	await _step(30)
	if player.facing != -1:
		errors.append("facing should persist when idle, got %d" % player.facing)
	return true


# --- Jump ---

## Presses jump for `hold_frames`, then releases, and returns the highest
## point reached (smallest y) measured from the starting height.
func _measure_jump_height(hold_frames: int) -> float:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var fake: FakeInput = player.input
	await _step(5)

	var start_y := player.global_position.y
	# Sampled every frame from takeoff onward. A long hold can outlast the whole
	# flight, so waiting until after the hold to start looking would measure a
	# player who has already landed.
	var highest := start_y

	fake.jump_just_pressed = true
	fake.jump_held = true
	await _step(1)
	fake.clear_edges()
	highest = minf(highest, player.global_position.y)

	for _i in range(hold_frames):
		await physics_frame
		highest = minf(highest, player.global_position.y)
	fake.jump_held = false

	for _i in range(240):
		await physics_frame
		highest = minf(highest, player.global_position.y)
		if player.is_on_floor():
			break
	return start_y - highest


func _test_jump_leaves_the_ground(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var fake: FakeInput = player.input
	await _step(5)
	if not player.is_on_floor():
		errors.append("setup failure: player should start grounded")
		return true

	fake.jump_just_pressed = true
	fake.jump_held = true
	await _step(1)
	fake.clear_edges()

	if player.velocity.y >= 0.0:
		errors.append("expected upward velocity after jump, got %f" % player.velocity.y)
	await _step(3)
	if player.is_on_floor():
		errors.append("should have left the ground")
	return true


func _test_jump_reports_takeoff(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var fake: FakeInput = player.input
	await _step(5)
	fake.jump_just_pressed = true
	fake.jump_held = true
	await _step(1)
	if not player.just_jumped:
		errors.append("just_jumped should fire on the takeoff frame")
	return true


func _test_held_jump_goes_higher_than_tapped(errors: Array) -> bool:
	var tapped: float = await _measure_jump_height(1)
	await _clear_world()
	var held: float = await _measure_jump_height(40)

	if tapped <= 0.0:
		errors.append("tap jump should still leave the ground, got %f" % tapped)
	if held <= tapped * 1.5:
		errors.append("held jump (%f) should clearly exceed tap jump (%f)"
			% [held, tapped])
	return true


func _test_jump_returns_to_ground(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var fake: FakeInput = player.input
	await _step(5)
	fake.jump_just_pressed = true
	fake.jump_held = true
	await _step(1)
	fake.clear_edges()

	var landed := false
	for _i in range(240):
		await physics_frame
		if player.just_landed:
			landed = true
			break
	if not landed:
		errors.append("player never came back down")
	return true


# --- Forgiveness windows ---

## A floor that stops at x = 0, so a player running right walks off its edge.
func _test_coyote_time_allows_late_jump(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -2000.0, 0.0)
	var player := _spawn_player(Vector2(-100.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var fake: FakeInput = player.input
	fake.move_axis = 1.0

	var left_ground := false
	for _i in range(300):
		await physics_frame
		if not player.is_on_floor():
			left_ground = true
			break
	if not left_ground:
		errors.append("setup failure: player never walked off the ledge")
		return true

	# Jump one frame after losing the floor — inside the coyote window.
	fake.jump_just_pressed = true
	fake.jump_held = true
	await _step(1)
	fake.clear_edges()

	if not player.just_jumped:
		errors.append("coyote time should permit a jump just after leaving the ledge")
	return true


func _test_coyote_time_expires(errors: Array) -> bool:
	var player := _spawn_player(Vector2(0.0, -600.0))
	var fake: FakeInput = player.input
	# Fall for well over the coyote window with no ground anywhere.
	await _step(60)
	fake.jump_just_pressed = true
	fake.jump_held = true
	await _step(1)
	if player.just_jumped:
		errors.append("coyote time should have expired after a long fall")
	return true


func _test_jump_buffer_fires_on_landing(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT - 220.0))
	var fake: FakeInput = player.input

	var pressed := false
	for _i in range(300):
		await physics_frame
		var height_above := FLOOR_TOP - (player.global_position.y + COLLIDER_HALF_HEIGHT)
		if not pressed and height_above < 40.0:
			fake.jump_just_pressed = true
			fake.jump_held = true
			pressed = true
			continue
		if pressed:
			fake.clear_edges()
		if player.just_jumped:
			return true
		if player.is_on_floor():
			await physics_frame
			if player.just_jumped:
				return true
			errors.append("buffered jump did not fire on landing")
			return true
	if not pressed:
		errors.append("setup failure: never got close enough to the ground to press")
	else:
		errors.append("buffered jump never resolved")
	return true


## A buffered jump fires on a frame where the button is already released. The
## height cut must still apply, or a tap near the ground silently becomes a
## full-height jump.
func _test_buffered_tap_stays_short(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT - 220.0))
	var fake: FakeInput = player.input

	var pressed := false
	for _i in range(300):
		await physics_frame
		var height_above := FLOOR_TOP - (player.global_position.y + COLLIDER_HALF_HEIGHT)
		if not pressed and height_above < 40.0:
			# Tap: press and let go while still airborne.
			fake.jump_just_pressed = true
			fake.jump_held = true
			pressed = true
			continue
		if pressed:
			fake.clear_edges()
			fake.jump_held = false
		if player.just_jumped:
			# Under the sustain model launch velocity is identical for tap and
			# hold — the difference is how long it is maintained. So judge the
			# apex, not the launch: a buffered tap must stay well under half of
			# a full-hold jump (~364 px at shipped tuning).
			var start_y := player.global_position.y
			var apex := start_y
			for _j in range(240):
				await physics_frame
				apex = minf(apex, player.global_position.y)
				if player.is_on_floor():
					break
			var rise := start_y - apex
			if rise > 200.0:
				errors.append("buffered tap rose %f px, should stay well under a full jump" % rise)
			return true
	errors.append("buffered tap never produced a jump")
	return true


# --- Procedural visuals ---

func _test_visual_root_flips_with_facing(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var visual_root: Node2D = player.get_node("VisualRoot")
	var fake: FakeInput = player.input

	fake.move_axis = 1.0
	await _step(5)
	if visual_root.scale.x <= 0.0:
		errors.append("facing right should keep scale.x positive, got %f"
			% visual_root.scale.x)

	fake.move_axis = -1.0
	await _step(20)
	if visual_root.scale.x >= 0.0:
		errors.append("facing left should make scale.x negative, got %f"
			% visual_root.scale.x)
	return true


func _test_landing_squashes_then_recovers(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT - 400.0))
	var visual_root: Node2D = player.get_node("VisualRoot")

	var squashed := false
	for _i in range(240):
		await physics_frame
		if player.just_landed:
			await physics_frame
			if visual_root.scale.y < 0.95 and absf(visual_root.scale.x) > 1.02:
				squashed = true
			break
	if not squashed:
		errors.append("landing should squash: scale=%s" % str(visual_root.scale))
		return true

	await _step(90)
	if absf(visual_root.scale.y - 1.0) > 0.05:
		errors.append("squash should recover, scale.y=%f" % visual_root.scale.y)
	return true


func _test_jump_stretches(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var visual_root: Node2D = player.get_node("VisualRoot")
	var fake: FakeInput = player.input
	await _step(5)

	fake.jump_just_pressed = true
	fake.jump_held = true
	await _step(2)
	if visual_root.scale.y <= 1.02:
		errors.append("jump should stretch vertically, scale.y=%f" % visual_root.scale.y)
	return true


func _test_running_leans_into_direction(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var visual_root: Node2D = player.get_node("VisualRoot")
	var fake: FakeInput = player.input

	fake.move_axis = 1.0
	await _step(60)
	var right_lean := visual_root.rotation

	fake.move_axis = -1.0
	await _step(90)
	var left_lean := visual_root.rotation

	if right_lean <= 0.0:
		errors.append("running right should lean clockwise, got %f" % right_lean)
	if left_lean >= 0.0:
		errors.append("running left should lean anticlockwise, got %f" % left_lean)
	return true


func _test_idle_breathes_without_drifting(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var visual_root: Node2D = player.get_node("VisualRoot")
	await _step(10)

	var lowest := visual_root.scale.y
	var highest := visual_root.scale.y
	for _i in range(150):
		await physics_frame
		lowest = minf(lowest, visual_root.scale.y)
		highest = maxf(highest, visual_root.scale.y)

	if highest - lowest < 0.005:
		errors.append("idle should breathe, range was %f" % (highest - lowest))
	if highest > 1.10 or lowest < 0.90:
		errors.append("breathing should stay subtle, range %f..%f" % [lowest, highest])
	return true


# --- End to end, against the real level ---

func _test_main_scene_player_stands_on_real_ground(errors: Array) -> bool:
	var packed: PackedScene = load("res://node_2d.tscn")
	if packed == null:
		errors.append("main scene failed to load")
		return true
	var world: Node = packed.instantiate()
	get_root().add_child(world)

	var player := world.get_node_or_null("Player") as PlayerController
	if player == null:
		errors.append("main scene has no Player node of type PlayerController")
		return true

	var camera: Camera2D = world.get_node("Camera2D")
	if camera.target != player:
		errors.append("camera should follow the Player node")

	await _step(180)
	if not player.is_on_floor():
		errors.append("player should settle on the tilemap, y=%f"
			% player.global_position.y)
		return true

	# The tilemap's surface is at world y = 16.
	var feet := player.global_position.y + COLLIDER_HALF_HEIGHT
	if absf(feet - 16.0) > 1.5:
		errors.append("feet should rest on the tilemap surface (16), got %f" % feet)
	return true


# --- Leg rig ---

func _test_legs_swing_in_opposition(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -4000.0, 4000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var far: Node2D = player.get_node("VisualRoot/LegFar")
	var near: Node2D = player.get_node("VisualRoot/LegNear")
	var fake: FakeInput = player.input
	fake.move_axis = 1.0

	var saw_swing := false
	for _i in range(120):
		await physics_frame
		if absf(far.rotation) > 0.05:
			saw_swing = true
			if signf(far.rotation) == signf(near.rotation):
				errors.append("legs must swing opposite each other: far=%f near=%f"
					% [far.rotation, near.rotation])
				return true
	if not saw_swing:
		errors.append("legs never swung while running")
	return true


## The whole point of driving the stride by distance: at half the speed he must
## take the same number of steps over the same ground, just slower. On a timer
## the step count would scale with speed and his feet would skate.
func _test_stride_is_distance_driven_not_time_driven(errors: Array) -> bool:
	var counts: Array[int] = []
	var speeds: Array[float] = [260.0, 120.0]

	for speed in speeds:
		_make_floor(FLOOR_TOP, -4000.0, 4000.0)
		var player := _spawn_player(Vector2(-500.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
		player.max_run_speed = speed
		var far: Node2D = player.get_node("VisualRoot/LegFar")
		var fake: FakeInput = player.input
		fake.move_axis = 1.0

		var start_x := player.global_position.x
		var crossings := 0
		var previous := 0.0
		for _i in range(2000):
			await physics_frame
			var now := far.rotation
			if previous < 0.0 and now >= 0.0:
				crossings += 1
			previous = now
			if player.global_position.x - start_x >= 600.0:
				break
		counts.append(crossings)
		await _clear_world()

	if counts[0] != counts[1]:
		errors.append("over the same 600px he took %d strides at %.0f px/s but %d at %.0f px/s"
			% [counts[0], speeds[0], counts[1], speeds[1]])
	if counts[0] < 2:
		errors.append("expected several strides over 600px, counted %d" % counts[0])
	return true


func _test_airborne_holds_leg_pose(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -4000.0, 4000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var far: Node2D = player.get_node("VisualRoot/LegFar")
	var fake: FakeInput = player.input
	fake.move_axis = 1.0
	await _step(40)

	fake.jump_just_pressed = true
	fake.jump_held = true
	await _step(1)
	fake.clear_edges()
	# Let the pose fully settle first — the drift check below is about the
	# stride not advancing mid-air, not about the settling transient.
	await _step(20)

	var settled := far.rotation
	var drift := 0.0
	for _i in range(12):
		await physics_frame
		if player.is_on_floor():
			break
		drift = maxf(drift, absf(far.rotation - settled))
	if drift > 0.02:
		errors.append("legs kept cycling mid-jump, drifted %f rad" % drift)
	return true


func _test_idle_returns_legs_to_neutral(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -4000.0, 4000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var far: Node2D = player.get_node("VisualRoot/LegFar")
	var near: Node2D = player.get_node("VisualRoot/LegNear")
	var fake: FakeInput = player.input

	fake.move_axis = 1.0
	await _step(50)
	fake.move_axis = 0.0
	await _step(90)

	if absf(far.rotation) > 0.02 or absf(near.rotation) > 0.02:
		errors.append("legs should return to standing, got far=%f near=%f"
			% [far.rotation, near.rotation])
	return true


# --- Footfalls, lurch and camera ---

func _test_footfall_fires_twice_per_stride(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -6000.0, 6000.0)
	var player := _spawn_player(Vector2(-1000.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var visuals: PlayerVisuals = player.get_node("VisualRoot")
	var hits: Array[int] = [0]
	visuals.footfall.connect(func(_strength: float) -> void: hits[0] += 1)

	var fake: FakeInput = player.input
	fake.move_axis = 1.0
	var start_x := player.global_position.x
	for _i in range(1200):
		await physics_frame
		if player.global_position.x - start_x >= 620.0:
			break

	var travelled := player.global_position.x - start_x
	var expected := int(round(travelled / visuals.stride_length)) * 2
	if absi(hits[0] - expected) > 2:
		errors.append("over %.0f px expected about %d footfalls, got %d"
			% [travelled, expected, hits[0]])
	return true


func _test_footfall_strength_tracks_speed(errors: Array) -> bool:
	var readings: Array[float] = []
	for speed in [260.0, 90.0]:
		_make_floor(FLOOR_TOP, -6000.0, 6000.0)
		var player := _spawn_player(Vector2(-1000.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
		player.max_run_speed = speed
		var visuals: PlayerVisuals = player.get_node("VisualRoot")
		var last: Array[float] = [-1.0]
		visuals.footfall.connect(func(strength: float) -> void: last[0] = strength)
		var fake: FakeInput = player.input
		fake.move_axis = 1.0
		for _i in range(400):
			await physics_frame
			if last[0] >= 0.0 and absf(player.velocity.x) >= speed * 0.98:
				break
		readings.append(last[0])
		await _clear_world()

	for value in readings:
		if value < 0.0:
			errors.append("no footfall was reported at all")
			return true
	# Strength is a fraction of that character's own top speed, so both should
	# approach 1.0 once each is running flat out.
	for i in range(readings.size()):
		if readings[i] < 0.5:
			errors.append("strength at full speed should be high, got %f" % readings[i])
	return true


## Velocity alone cannot tell setting off from pulling up — it is the same
## number either way. The acceleration term is what separates them.
func _test_acceleration_produces_a_lurch(errors: Array) -> bool:
	const SAMPLE_SPEED := 120.0
	_make_floor(FLOOR_TOP, -6000.0, 6000.0)
	var player := _spawn_player(Vector2(-1000.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var visuals: Node2D = player.get_node("VisualRoot")
	var fake: FakeInput = player.input

	fake.move_axis = 1.0
	var accelerating_lean := 0.0
	for _i in range(300):
		await physics_frame
		if player.velocity.x >= SAMPLE_SPEED:
			accelerating_lean = visuals.rotation
			break

	await _step(60)
	fake.move_axis = 0.0
	var decelerating_lean := 0.0
	for _i in range(300):
		await physics_frame
		if player.velocity.x <= SAMPLE_SPEED:
			decelerating_lean = visuals.rotation
			break

	if accelerating_lean <= decelerating_lean:
		errors.append("at the same speed he should lean further forward while speeding up (%f) than while slowing down (%f)"
			% [accelerating_lean, decelerating_lean])
	return true


func _test_camera_leads_the_direction_of_travel(errors: Array) -> bool:
	var packed: PackedScene = load("res://node_2d.tscn")
	var world: Node = packed.instantiate()
	get_root().add_child(world)
	var player: PlayerController = world.get_node("Player")
	var camera: Camera2D = world.get_node("Camera2D")
	await _step(90)

	var fake := FakeInput.new()
	player.input = fake
	fake.move_axis = 1.0
	await _step(150)
	var lead_right := camera.global_position.x - player.global_position.x
	if lead_right <= 10.0:
		errors.append("camera should lead to the right while running right, lead=%f"
			% lead_right)

	fake.move_axis = -1.0
	await _step(240)
	var lead_left := camera.global_position.x - player.global_position.x
	if lead_left >= -10.0:
		errors.append("camera should lead to the left while running left, lead=%f"
			% lead_left)
	return true


func _test_footfall_raises_dust(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -6000.0, 6000.0)
	var player := _spawn_player(Vector2(-1000.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var dust: CPUParticles2D = player.get_node("Effects/Dust")
	if dust.emitting:
		errors.append("dust should start idle")
	var fake: FakeInput = player.input
	fake.move_axis = 1.0

	var seen := false
	for _i in range(400):
		await physics_frame
		if dust.emitting:
			seen = true
			break
	if not seen:
		errors.append("running should kick up dust")
	return true


# --- Cape cloth ---

func _test_cape_trails_behind_when_running(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -6000.0, 6000.0)
	var player := _spawn_player(Vector2(-1000.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var cape: CapeCloth = player.get_node("VisualRoot/Cape")
	var fake: FakeInput = player.input
	await _step(30)

	fake.move_axis = 1.0
	await _step(45)
	var hem := cape.hem_world_position()
	if hem.x >= player.global_position.x:
		errors.append("running right, the hem should trail to the left of him: hem %f vs body %f"
			% [hem.x, player.global_position.x])
	return true


func _test_cape_settles_when_stopped(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -6000.0, 6000.0)
	var player := _spawn_player(Vector2(-1000.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var cape: CapeCloth = player.get_node("VisualRoot/Cape")
	var fake: FakeInput = player.input

	fake.move_axis = 1.0
	await _step(60)
	fake.move_axis = 0.0
	await _step(120)

	var hem_before := cape.hem_world_position()
	await _step(30)
	var drift := (cape.hem_world_position() - hem_before).length()
	if drift > 2.0:
		errors.append("cape should settle at rest, still moving %f px per half second" % drift)
	return true


func _test_cape_never_goes_below_the_floor(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -6000.0, 6000.0)
	var player := _spawn_player(Vector2(-1000.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT - 300.0))
	var cape: CapeCloth = player.get_node("VisualRoot/Cape")

	# Fall, land, and give the fabric time to drape.
	await _step(150)
	if not player.is_on_floor():
		errors.append("setup failure: player should have landed")
		return true
	var hem := cape.hem_world_position()
	if hem.y > FLOOR_TOP + 1.5:
		errors.append("hem sits %f px below the floor surface" % (hem.y - FLOOR_TOP))
	return true


func _test_cape_stays_finite_under_abuse(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -6000.0, 6000.0)
	var player := _spawn_player(Vector2(-1000.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var cape: CapeCloth = player.get_node("VisualRoot/Cape")
	var fake: FakeInput = player.input

	# Whiplash: hard direction reversals with jumps mixed in.
	for cycle in range(6):
		fake.move_axis = 1.0 if cycle % 2 == 0 else -1.0
		fake.jump_just_pressed = cycle % 2 == 0
		fake.jump_held = cycle % 2 == 0
		await _step(15)
		fake.clear_edges()

	var hem := cape.hem_world_position()
	if not (is_finite(hem.x) and is_finite(hem.y)):
		errors.append("cape exploded to non-finite values")
		return true
	if (hem - player.global_position).length() > 200.0:
		errors.append("cape stretched absurdly far from the body: %f px"
			% (hem - player.global_position).length())
	return true


## The settle test above only proves the hem stops MOVING — a cape frozen in
## a tangled shape passes it. This one demands the actual return: after
## whiplash, standing still must bring every point back near the authored
## drape, with no pair of columns left crossed.
func _test_cape_comes_home_untangled(errors: Array) -> bool:
	_make_floor(FLOOR_TOP, -6000.0, 6000.0)
	var player := _spawn_player(Vector2(-1000.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var cape: CapeCloth = player.get_node("VisualRoot/Cape")
	var fake: FakeInput = player.input

	# Whiplash: hard direction reversals with jumps mixed in.
	for cycle in range(8):
		fake.move_axis = 1.0 if cycle % 2 == 0 else -1.0
		fake.jump_just_pressed = cycle % 2 == 0
		fake.jump_held = cycle % 2 == 0
		await _step(15)
		fake.clear_edges()

	# Then stand still and give it three seconds to come home.
	fake.move_axis = 0.0
	fake.jump_held = false
	await _step(180)

	if cape.columns_crossed():
		errors.append("cloth columns still crossed after settling")
	var deviation := cape.max_rest_deviation()
	if deviation > 10.0:
		errors.append("cape settled %f px from its drawn drape" % deviation)
	return true


# --- World reactions ---

func _test_world_scenery_is_wired(errors: Array) -> bool:
	var packed: PackedScene = load("res://node_2d.tscn")
	var world: Node = packed.instantiate()
	get_root().add_child(world)
	await _step(2)
	var reactions: WorldReactions = world.get_node_or_null("WorldReactions")
	if reactions == null:
		errors.append("main scene has no WorldReactions node")
		return true
	if reactions.blade_count() < 20:
		errors.append("expected the coral and grass along the path to register, got %d"
			% reactions.blade_count())
	return true


func _test_foliage_bends_when_run_through_and_recovers(errors: Array) -> bool:
	var packed: PackedScene = load("res://node_2d.tscn")
	var world: Node = packed.instantiate()
	get_root().add_child(world)
	var player: PlayerController = world.get_node("Player")
	var reactions: WorldReactions = world.get_node("WorldReactions")
	await _step(60)

	var fake := FakeInput.new()
	player.input = fake

	# There is a coral bush at about x = -1731, right of spawn (-1830).
	const BUSH_X := -1731.0
	fake.move_axis = 1.0
	var max_bend := 0.0
	for _i in range(200):
		await physics_frame
		max_bend = maxf(max_bend, absf(reactions.nearest_blade_angle(BUSH_X)))
		if player.global_position.x > BUSH_X + 200.0:
			break
	if max_bend < 0.05:
		errors.append("running through the bush should bend it, peak was %f rad" % max_bend)

	# Stop far past it and let the spring settle.
	fake.move_axis = 0.0
	await _step(150)
	var rest := absf(reactions.nearest_blade_angle(BUSH_X))
	if rest > 0.03:
		errors.append("the bush should spring back to rest, still bent %f rad" % rest)
	return true
