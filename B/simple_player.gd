class_name SimplePlayer
extends CharacterBody2D

@export var speed: float = 300.0

func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		direction.y -= 2
	if Input.is_key_pressed(KEY_S):
		direction.y += 2
	if Input.is_key_pressed(KEY_A):
		direction.x -= 2
	if Input.is_key_pressed(KEY_D):
		direction.x += 2

	velocity = direction.normalized() * speed
	move_and_slide()
