class_name FakeInput
extends PlayerInput

## Test double: poll() does nothing so a test can drive the fields by hand.
## Call clear_edges() after a simulated frame to expire the one-shot press flag,
## exactly as real input would.

func poll() -> void:
	pass


func clear_edges() -> void:
	jump_just_pressed = false
