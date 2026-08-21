extends Area2D
## A door that teleports the player to another scene when he stands in front
## of it and presses the "interact" action (E by default).
##
## The prompt is drawn in code on a CanvasLayer so no UI scene is needed. The
## prompt fades in while the player is inside the trigger area and fades out
## on exit. Pressing interact while the prompt is visible travels to
## `target_scene`.

@export var target_scene: String = ""
## How far above the door the prompt sits, in the door's local space.
@export var prompt_offset: Vector2 = Vector2(0, -60)

var _player_inside: bool = false

var _layer: CanvasLayer
var _prompt: Label
var _initialized: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_layer = CanvasLayer.new()
	_layer.layer = 100
	_layer.visible = false

	_prompt = Label.new()
	_prompt.text = "E"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_prompt.modulate = Color(1, 1, 1, 0.0)
	_layer.add_child(_prompt)


func _physics_process(delta: float) -> void:
	if not _player_inside:
		return
	if Input.is_action_just_pressed("interact") and not target_scene.is_empty():
		# Deferred so the scene is not torn down inside the physics callback.
		call_deferred("change_scene", target_scene)


func _process(_delta: float) -> void:
	# CanvasLayer must live under the viewport, not under an Area2D, so reparent
	# it to the scene root on the first frame.
	if not _initialized:
		if get_tree() == null or get_tree().current_scene == null:
			return
		get_tree().current_scene.add_child.call_deferred(_layer)
		_initialized = true
	if _layer == null or _prompt == null:
		return
	_layer.visible = _player_inside
	_prompt.position = to_global(prompt_offset)
	if _player_inside:
		_prompt.modulate.a = move_toward(_prompt.modulate.a, 1.0, 4.0 * _delta)
	else:
		_prompt.modulate.a = move_toward(_prompt.modulate.a, 0.0, 4.0 * _delta)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player") or body is CharacterBody2D:
		_player_inside = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player") or body is CharacterBody2D:
		_player_inside = false


func change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
