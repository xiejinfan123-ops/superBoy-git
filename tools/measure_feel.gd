extends SceneTree

## Measures the character's movement feel inside the real main scene and prints
## the numbers a human would otherwise have to eyeball. Read-only; changes
## nothing. Run with:
##   godot --headless --path <project> --script res://tools/measure_feel.gd

const STEP := 1.0 / 60.0


func _initialize() -> void:
	_main()


func _main() -> void:
	await physics_frame

	var packed: PackedScene = load("res://node_2d.tscn")
	var world: Node = packed.instantiate()
	get_root().add_child(world)
	var player: PlayerController = world.get_node("Player")
	var fake := FakeInput.new()
	player.input = fake

	# Settle on the ground.
	for _i in range(120):
		await physics_frame

	print("CHARACTER_HEIGHT_PX=%.1f" % 78.75)
	print("GROUND_Y=%.2f" % (player.global_position.y + 39.375))

	# --- Run: how long to reach top speed, and how far that is ---
	fake.move_axis = 1.0
	var frames_to_90pct := -1
	var start_x := player.global_position.x
	for i in range(240):
		await physics_frame
		if frames_to_90pct < 0 and absf(player.velocity.x) >= player.max_run_speed * 0.9:
			frames_to_90pct = i + 1
	print("TOP_SPEED_PX_PER_S=%.0f" % absf(player.velocity.x))
	print("TIME_TO_90PCT_SPEED_S=%.3f" % (frames_to_90pct * STEP))
	print("RUN_DISTANCE_4S_PX=%.0f" % absf(player.global_position.x - start_x))

	# --- Stop: how long to come to rest ---
	fake.move_axis = 0.0
	var stop_frames := 0
	for i in range(240):
		await physics_frame
		if absf(player.velocity.x) < 1.0:
			stop_frames = i + 1
			break
	print("TIME_TO_STOP_S=%.3f" % (stop_frames * STEP))

	# --- Full jump: height and airtime ---
	var jump_start_y := player.global_position.y
	var highest := jump_start_y
	fake.jump_just_pressed = true
	fake.jump_held = true
	await physics_frame
	fake.clear_edges()
	var airtime := 1
	for _i in range(300):
		await physics_frame
		airtime += 1
		highest = minf(highest, player.global_position.y)
		if player.is_on_floor():
			break
	print("FULL_JUMP_HEIGHT_PX=%.0f" % (jump_start_y - highest))
	print("FULL_JUMP_AIRTIME_S=%.3f" % (airtime * STEP))
	fake.jump_held = false

	for _i in range(60):
		await physics_frame

	# --- Tap jump: height and airtime ---
	var tap_start_y := player.global_position.y
	var tap_highest := tap_start_y
	fake.jump_just_pressed = true
	fake.jump_held = true
	await physics_frame
	fake.clear_edges()
	fake.jump_held = false
	var tap_airtime := 1
	for _i in range(300):
		await physics_frame
		tap_airtime += 1
		tap_highest = minf(tap_highest, player.global_position.y)
		if player.is_on_floor():
			break
	print("TAP_JUMP_HEIGHT_PX=%.0f" % (tap_start_y - tap_highest))
	print("TAP_JUMP_AIRTIME_S=%.3f" % (tap_airtime * STEP))

	quit()
