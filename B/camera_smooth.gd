extends Camera2D

## Follows the player with a lead in the direction of travel.
##
## A small dead zone keeps the camera still while the character shuffles
## around its centre, so the view reads as stable. When he commits to a
## direction, the camera eases ahead to show what he is running into, and
## eases back as he slows. Vertical follow is looser on the ground so hops do
## not heave the whole view up and down, but tightens while airborne so he
## does not outrun the frame on a full jump.

@export var target: Node2D

@export_group("Zoom")
## Camera zoom. Larger values zoom in (bigger sprites, smaller view).
## 1.0 = 100%, 2.0 = 200%, 0.5 = 50%.
@export var view_zoom: float = 1.0:
	set(value):
		view_zoom = value
		if is_inside_tree():
			zoom = Vector2(view_zoom, view_zoom)

@export_group("Dead zone")
## Half-size of the box around the camera centre where the player moves
## freely without moving the camera, in pixels.
@export var dead_zone: Vector2 = Vector2(40, 25)
## How hard the camera pushes to drag the player back into the dead zone
## once he steps out of it.
@export var dead_zone_return: float = 6.0

@export_group("Follow")
## How firmly the camera chases its mark horizontally. Higher = tighter.
@export var follow_speed: float = 9.0
## Vertical follow is deliberately looser, so small hops do not heave the
## whole view up and down.
@export var vertical_follow_speed: float = 4.5
## Vertical follow while airborne. Much tighter than on the ground: a full
## Hollow-Knight-scale jump climbs 342 px, and at the relaxed ground rate the
## player outruns the camera and presses against the top of the frame.
@export var airborne_vertical_follow_speed: float = 10.0

@export_group("Look ahead")
## Seconds of travel to lead by. At 260 px/s, 0.4 leads by about 104 px.
@export var look_ahead_seconds: float = 0.35
## Ceiling on the lead, so a fast fall or a launch cannot fling the view away.
@export var max_look_ahead: float = 130.0
## How quickly the lead builds and releases. Slower than the follow, so the
## camera eases outward instead of snapping the moment a key goes down.
@export var look_ahead_speed: float = 2.6

@export_group("Framing")
## How far above the player's centre the camera aims, in pixels. Positive
## values put the player below the middle of the screen (more view above).
@export var vertical_shift: float = 60.0

@export_group("Regions")
## When region nodes are present in the scene (nodes in the "CameraRegions"
## group, e.g. res://B/camera_region.tscn) the camera locks onto whichever
## region the player stands in and does not move until he steps into another
## region. Set to true to use region locking; set to false to keep the normal
## follow behaviour.
@export var use_regions: bool = false
## Parent node that holds the region nodes. The camera scans this node's
## children (recursively) for region nodes instead of relying on groups.
@export var regions_parent: NodePath
## How fast the camera glides between region centres.
@export var region_transition_speed: float = 6.0

var _player: PlayerController
var _look_ahead: float = 0.0
var _kick: float = 0.0
var _centred: bool = false
var _vertical_shift: float = 0.0
var _region_centre: Vector2 = Vector2.ZERO
var _regions: Array[Rect2] = []
var _locked_region: int = -1


func _ready() -> void:
	zoom = Vector2(view_zoom, view_zoom)
	_player = target as PlayerController
	_collect_regions()
	# The camera's built-in drag margins fight the region-lock centre, and any
	# residual drag offset from the follow mode would shift the view sideways
	# when a new region is locked. Disable them whenever regions are used.
	if use_regions:
		drag_horizontal_enabled = false
		drag_vertical_enabled = false
	if target != null:
		if use_regions and not _regions.is_empty():
			_locked_region = _region_index(target.global_position)
			if _locked_region >= 0:
				_region_centre = _regions[_locked_region].get_center()
				global_position = _region_centre
				force_update_scroll()
			else:
				global_position = target.global_position
			_centred = true
		else:
			global_position = target.global_position
			_centred = true


func _region_index(pos: Vector2) -> int:
	for i in _regions.size():
		if _regions[i].has_point(pos):
			return i
	return -1


func _collect_regions() -> void:
	_regions.clear()
	if not regions_parent.is_empty():
		var parent_node := get_node_or_null(regions_parent)
		if parent_node != null:
			for child in parent_node.find_children("*", "Area2D", true, false):
				if child.has_method("get_region_rect"):
					_regions.append(child.get_region_rect())
	# Fall back to the group if no parent path was set or it was empty.
	if _regions.is_empty():
		for node in get_tree().get_nodes_in_group("CameraRegions"):
			if node.has_method("get_region_rect"):
				_regions.append(node.get_region_rect())


func _physics_process(delta: float) -> void:
	if target == null:
		return

	# Region mode: while the player stands inside a region the camera locks
	# onto that region's centre. Once he steps out of every region, the normal
	# follow behaviour below takes over so the camera chases him again.
	# The current region is remembered so two overlapping regions do not fight
	# over the camera: the camera only switches when the player has clearly
	# left the region it is locked to.
	if use_regions and not _regions.is_empty():
		if _locked_region >= 0:
			# Still inside the locked region: hold position.
			if _regions[_locked_region].has_point(target.global_position):
				global_position = global_position.lerp(_region_centre,
					clampf(region_transition_speed * delta, 0.0, 1.0))
				return
			# Left it: drop the lock and re-resolve.
			_locked_region = -1

		var idx := _region_index(target.global_position)
		if idx >= 0:
			# Stepped into a (new) region: lock it and glide smoothly to its
			# centre. The remembered lock stops overlapping regions fighting,
			# and forcing the scroll update clears any residual drag offset.
			if idx != _locked_region:
				_region_centre = _regions[idx].get_center()
				force_update_scroll()
			_locked_region = idx
			global_position = global_position.lerp(_region_centre,
				clampf(region_transition_speed * delta, 0.0, 1.0))
			return

	# Lead the view in the direction of travel, but only while the player is
	# actually moving, not while he is idling inside the dead zone.
	var desired_look := 0.0
	if _player != null:
		desired_look = clampf(_player.velocity.x * look_ahead_seconds,
			-max_look_ahead, max_look_ahead)
	_look_ahead = lerpf(_look_ahead, desired_look,
		1.0 - exp(-look_ahead_speed * delta))

	var vertical_speed := vertical_follow_speed
	var in_air := _player != null and not _player.is_on_floor()
	if in_air:
		vertical_speed = airborne_vertical_follow_speed

	# Keep the framing shift while grounded, but ease it out while airborne so
	# a jump does not shove the whole view upward.
	var shift := lerpf(_vertical_shift, 0.0 if in_air else vertical_shift,
		1.0 - exp(-4.0 * delta))
	_vertical_shift = shift

	var mark := target.global_position + Vector2(_look_ahead, -shift)

	var cam_offset := global_position - mark
	var correction := Vector2.ZERO

	# Only nudge the camera once the player steps out of the dead zone.
	if absf(cam_offset.x) > dead_zone.x:
		correction.x = cam_offset.x - signf(cam_offset.x) * dead_zone.x
	if absf(cam_offset.y) > dead_zone.y:
		correction.y = cam_offset.y - signf(cam_offset.y) * dead_zone.y

	global_position = Vector2(
		lerpf(global_position.x, global_position.x - correction.x,
			1.0 - exp(-follow_speed * delta)),
		lerpf(global_position.y, global_position.y - correction.y,
			1.0 - exp(-vertical_speed * delta)))

	# Landing kick: only on genuinely heavy landings, and a fraction of what
	# the old code did so it reads as weight, not camera shake.
	if _player != null and _player.just_landed:
		_kick = 3.0 * _player.landing_impact
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-9.0 * delta))
	global_position.y += _kick
