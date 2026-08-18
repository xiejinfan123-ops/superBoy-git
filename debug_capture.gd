extends Node

## Drives the player through a scripted run/jump/turn sequence in the REAL
## renderer and saves numbered screenshots, so rendering bugs can be seen
## instead of guessed at. Temporary diagnostic; not part of the game.

var _frame: int = 0
var _shot: int = 0
var _player: PlayerController
var _fake: PlayerInput


func _ready() -> void:
	var world: Node = load("res://node_2d.tscn").instantiate()
	add_child(world)
	_player = world.get_node("Player")
	_fake = load("res://tests/fake_input.gd").new()
	_player.input = _fake
	DirAccess.make_dir_recursive_absolute("user://shots")


func _physics_process(_delta: float) -> void:
	_frame += 1
	# Script: settle, run right, jump mid-run, keep running, hard turn, stop.
	if _frame < 30:
		_fake.move_axis = 0.0
	elif _frame < 150:
		_fake.move_axis = 1.0
		if _frame == 80:
			_fake.jump_just_pressed = true
			_fake.jump_held = true
		elif _frame == 100:
			_fake.jump_held = false
		else:
			_fake.jump_just_pressed = false
	elif _frame < 210:
		_fake.move_axis = -1.0
	else:
		_fake.move_axis = 0.0

	if _frame % 6 == 0 and _frame <= 252:
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://shots/shot_%02d_f%03d.png" % [_shot, _frame])
		_shot += 1
	if _frame > 258:
		get_tree().quit()
