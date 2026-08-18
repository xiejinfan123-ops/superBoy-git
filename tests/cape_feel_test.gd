extends SceneTree

## Standalone regression tests for how the cape FEELS: heavy, trailing,
## and reliably home. Run with:
##   godot --headless --path <project> --script res://tests/cape_feel_test.gd
## Exits 0 when everything passes, 1 otherwise.
##
## Lives outside run_tests.gd only because that file was mid-edit by Codex
## when these were written — fold them in whenever it is free.
##
## The story behind the numbers: the cape used to plane out flat during any
## run, hem parked 24 px above its drape. The lifter was an obsolete torso
## guard circle injecting ~900 px/s² of effective anti-gravity into the
## trailing cloth. With it gone and the fabric weighted, the hem stays
## within a few px of its rest height at full sprint.

const FLOOR_TOP := 100.0
const COLLIDER_HALF_HEIGHT := 39.375

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_main()


func _main() -> void:
	await physics_frame

	await _run("cape hangs heavy at full sprint", _test_hangs_heavy)
	await _run("cape still streams behind, not glued", _test_still_streams)
	await _run("cape comes home after the sprint", _test_comes_home)

	print("RESULT passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _run(label: String, test: Callable) -> void:
	var errors: Array = []
	var completed: bool = await test.call(errors)
	if not completed:
		errors.append("test aborted before finishing")
	if errors.is_empty():
		_passed += 1
		print("PASS %s" % label)
	else:
		_failed += 1
		for e in errors:
			print("FAIL %s :: %s" % [label, e])


func _step(frames: int) -> void:
	for _i in range(frames):
		await physics_frame


func _spawn() -> PlayerController:
	var floor_body := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(30000.0, 400.0)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	floor_body.add_child(collider)
	floor_body.position = Vector2(0.0, FLOOR_TOP + 200.0)
	get_root().add_child(floor_body)

	var player: PlayerController = (load("res://B/player.tscn") as PackedScene).instantiate()
	get_root().add_child(player)
	player.global_position = Vector2(-14000.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT)
	player.input = FakeInput.new()
	return player


func _rest_hem(cape: CapeCloth, visual_root: Node2D) -> Vector2:
	var left: Vector2 = visual_root.to_global(cape._rest_local[(cape.rows - 1) * cape.cols])
	var right: Vector2 = visual_root.to_global(
		cape._rest_local[(cape.rows - 1) * cape.cols + cape.cols - 1])
	return (left + right) * 0.5


func _test_hangs_heavy(errors: Array) -> bool:
	var player := _spawn()
	var cape: CapeCloth = player.get_node("VisualRoot/Cape")
	var visual_root: Node2D = player.get_node("VisualRoot")
	var fake: FakeInput = player.input
	await _step(40)

	fake.move_axis = 1.0
	var rise_sum := 0.0
	var samples := 0
	for f in range(150):
		await physics_frame
		if f < 40:
			continue
		var hem := cape.hem_world_position()
		rise_sum += _rest_hem(cape, visual_root).y - hem.y
		samples += 1
	var avg_rise := rise_sum / samples
	# 24 px meant "planed out flat". A heavy cape's hem barely leaves its
	# hanging height even at top speed.
	if avg_rise > 6.0:
		errors.append("hem floats %.1f px above its drape at full sprint" % avg_rise)
	return true


func _test_still_streams(errors: Array) -> bool:
	var player := _spawn()
	var cape: CapeCloth = player.get_node("VisualRoot/Cape")
	var fake: FakeInput = player.input
	await _step(40)

	fake.move_axis = 1.0
	await _step(90)
	var trail: float = player.global_position.x - cape.hem_world_position().x
	# Heavy must not mean dead: the hem still visibly trails him.
	if trail < 5.0:
		errors.append("hem only %.1f px behind him — cape reads as glued on" % trail)
	return true


func _test_comes_home(errors: Array) -> bool:
	var player := _spawn()
	var cape: CapeCloth = player.get_node("VisualRoot/Cape")
	var fake: FakeInput = player.input
	await _step(40)

	fake.move_axis = 1.0
	await _step(90)
	fake.move_axis = 0.0
	await _step(180)
	if cape.columns_crossed():
		errors.append("cloth columns crossed after settling")
	var deviation := cape.max_rest_deviation()
	if deviation > 10.0:
		errors.append("cape settled %.1f px from its drawn drape" % deviation)
	return true
