class_name PlayerInput
extends RefCounted

## Reads the project's input actions into plain fields once per physics frame.
## Tests replace this object with a FakeInput and write the fields directly.

var move_axis: float = 0.0
## True only on the frame the jump button went down.
var jump_just_pressed: bool = false
## True for as long as the jump button is down. Drives the variable jump height.
var jump_held: bool = false
## True only on the frame the attack button went down.
var attack_just_pressed: bool = false
## True while the upward-attack key (W) is held. Drives continuous upward fire.
var attack_up_held: bool = false


func poll() -> void:
	move_axis = Input.get_axis("move_left", "move_right")
	jump_just_pressed = Input.is_action_just_pressed("jump")
	jump_held = Input.is_action_pressed("jump")
	attack_just_pressed = Input.is_action_just_pressed("attack")
	attack_up_held = Input.is_action_pressed("attack_up")
