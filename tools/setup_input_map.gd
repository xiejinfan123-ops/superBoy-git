extends SceneTree

## One-shot: writes the player's input actions into project.godot.
## Run once; re-running is harmless (it overwrites with the same values).

func _initialize() -> void:
	_apply()


func _make_key(physical: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	return event


func _set_action(action_name: String, keys: Array) -> void:
	var events: Array = []
	for k in keys:
		events.append(_make_key(k))
	ProjectSettings.set_setting("input/" + action_name, {
		"deadzone": 0.2,
		"events": events,
	})


func _apply() -> void:
	_set_action("move_left", [KEY_A, KEY_LEFT])
	_set_action("move_right", [KEY_D, KEY_RIGHT])
	_set_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	var err := ProjectSettings.save()
	print("SAVE_RESULT=", err)
	quit(0 if err == OK else 1)
