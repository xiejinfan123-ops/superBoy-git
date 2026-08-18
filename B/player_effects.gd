class_name PlayerEffects
extends Node2D

## Everything that punctuates a moment: dust at each footfall, a kick of dust on
## landing, and the sound effects.
##
## Audio degrades to silence rather than to an error. The files are produced
## separately, so if they are absent this node simply plays nothing and the game
## keeps running — nothing here is load-bearing for movement.

const STEP_SOUNDS: Array[String] = [
	"res://Audio/step_a.ogg",
	"res://Audio/step_b.ogg",
	"res://Audio/step_c.ogg",
]
const LAND_SOFT_SOUND := "res://Audio/land_soft.ogg"
const LAND_HARD_SOUND := "res://Audio/land_hard.ogg"
const JUMP_SOUND := "res://Audio/jump.ogg"

@export_group("Dust")
## Particles kicked up by a footfall at a full run. A walk emits fewer.
@export var step_dust_amount: int = 5
## Particles thrown out by the hardest possible landing.
@export var land_dust_amount: int = 14
## Below this fraction of top speed a step raises no dust at all — he is
## treading, not running.
@export var dust_speed_threshold: float = 0.35

@export_group("Volume")
## Decibels at a full-speed step, scaling down towards silence as he slows.
@export var step_volume_db: float = -6.0
## Extra decibels of range applied across the speed scale.
@export var step_volume_range_db: float = 12.0

var _player: PlayerController
var _dust: CPUParticles2D
var _step_player: AudioStreamPlayer2D
var _land_player: AudioStreamPlayer2D
var _jump_player: AudioStreamPlayer2D

var _step_streams: Array[AudioStream] = []
var _land_soft: AudioStream
var _land_hard: AudioStream
var _last_step_index: int = -1


func _ready() -> void:
	_player = get_parent() as PlayerController
	_dust = get_node_or_null("Dust")
	_step_player = get_node_or_null("StepSound")
	_land_player = get_node_or_null("LandSound")
	_jump_player = get_node_or_null("JumpSound")

	for path in STEP_SOUNDS:
		if ResourceLoader.exists(path):
			_step_streams.append(load(path))
	if ResourceLoader.exists(LAND_SOFT_SOUND):
		_land_soft = load(LAND_SOFT_SOUND)
	if ResourceLoader.exists(LAND_HARD_SOUND):
		_land_hard = load(LAND_HARD_SOUND)
	if ResourceLoader.exists(JUMP_SOUND) and _jump_player != null:
		_jump_player.stream = load(JUMP_SOUND)

	var visuals: PlayerVisuals = get_parent().get_node_or_null("VisualRoot")
	if visuals != null:
		visuals.footfall.connect(_on_footfall)


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	if _player.just_jumped:
		_play(_jump_player, _jump_player.stream if _jump_player else null, 0.0)
	if _player.just_landed:
		_on_landed(_player.landing_impact)


func _on_footfall(strength: float) -> void:
	if strength > dust_speed_threshold and _dust != null:
		# Scale the burst with speed so a slow walk does not throw up the same
		# cloud as a sprint.
		var span := 1.0 - dust_speed_threshold
		var scaled := (strength - dust_speed_threshold) / maxf(span, 0.001)
		_burst(maxi(int(round(step_dust_amount * scaled)), 1))

	if _step_streams.is_empty() or _step_player == null:
		return
	# Never the same take twice running: one repeated sample at four steps a
	# second stops sounding like footsteps and starts sounding like a machine gun.
	var index := randi() % _step_streams.size()
	if _step_streams.size() > 1 and index == _last_step_index:
		index = (index + 1) % _step_streams.size()
	_last_step_index = index
	_play(_step_player, _step_streams[index],
		step_volume_db - step_volume_range_db * (1.0 - strength))


func _on_landed(impact: float) -> void:
	if _dust != null and impact > 0.02:
		_burst(maxi(int(round(land_dust_amount * impact)), 2))
	if _land_player == null:
		return
	var stream := _land_hard if impact > 0.45 else _land_soft
	_play(_land_player, stream, -8.0 + 8.0 * impact)


func _burst(amount: int) -> void:
	_dust.amount = amount
	_dust.restart()


func _play(player: AudioStreamPlayer2D, stream: AudioStream, volume_db: float) -> void:
	if player == null or stream == null:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.play()
