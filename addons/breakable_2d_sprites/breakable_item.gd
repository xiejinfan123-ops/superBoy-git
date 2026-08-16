extends StaticBody2D
class_name ItemShapeBreakableItem

## Consumes the plugin's "breakable" export format (a `points` outer
## silhouette + `shards` array, each shard `{points, centroid, uv}`)
## and turns it into a placeable, hittable scene object: the intact item is
## a solid StaticBody2D (renders as one textured Polygon2D, blocks movement
## via a CollisionPolygon2D) with a separate Area2D "hitbox" that can trigger
## breaking. On break, it swaps to one RigidBody2D per shard — each with its
## own textured Polygon2D + CollisionPolygon2D — flung outward from wherever
## the break happened.
##
## Two ways to trigger a break:
## - take_hit(global_position): call directly from any weapon/bullet script
##   (hitscan, Area2D, RigidBody2D — doesn't matter), works regardless of
##   physics layer setup.
## - Automatic: set hit_detection_mask to the physics layer your
##   bullets/projectiles are on (0 = disabled, the default, so an unconfigured
##   instance won't break itself against the floor it's resting on).
##
## `outer_points`/`item_scale`/`shards` are meant to be built by the Item
## Shape Tool dock's "Build Scene" button (see built_items/) — not
## hand-authored.
##
## Resizing after building (via this node's Transform/Scale) is supported —
## the intact sprite/collision scale normally through the node hierarchy,
## and break_apart() reads this node's actual global_transform when spawning
## pieces, so both piece placement/size and the outward break impulse scale
## proportionally too.

signal broken(shard_count: int)

@export_group("Shape Data")
## Points-space -> pixel-space conversion factor from the trace (the
## "scale" field of the exported entry). Only used the one time the intact
## Sprite's UV gets computed (at Build Scene time, or on first _ready() for
## a bare/unbuilt node) — once that Sprite child exists, _ready() reuses it
## and never recomputes UV, so editing this afterward has no visible
## effect. Hidden from the Inspector (via @export_storage, not @export) so
## it doesn't look like a live control; still serialized/functional.
@export_storage var item_scale: float = 1.0
@export var texture: Texture2D
@export var outer_points: PackedVector2Array = PackedVector2Array()
## Array of Dictionary: {"points": PackedVector2Array, "centroid": Vector2,
## "uv": PackedVector2Array}. Left untyped (not Array[Dictionary]) because
## generated data is assigned via `object.shards = ...` at runtime, and
## Godot only auto-converts a plain Array to a typed Array[T] for
## compile-time-typed `var`s — not for a dynamic property assignment like
## this one, which would otherwise fail with a type-mismatch error.
@export var shards: Array = []

@export_group("Hit Detection")
## Physics layer(s) that can trigger an automatic break. 0 = disabled (the
## safe default — an instance resting on a layer-1 floor won't immediately
## break itself; set this to match your bullets/projectiles).
@export_flags_2d_physics var hit_detection_mask: int = 0
## Number of qualifying hits before it breaks.
@export var hits_to_break: int = 1
## If non-empty, an automatic hit only counts when the other body/area is
## also in this group (extra filtering beyond the physics mask).
@export var required_group: String = ""

@export_group("Break Physics")
## Weakest outward push a piece can get when the item breaks, in pixel-unit
## impulse. Each piece rolls its own random value between this and
## max_impulse. Scales automatically with this item's own Transform scale,
## so a resized item's pieces still separate proportionally.
@export var min_impulse := 80.0
## Strongest outward push a piece can get when the item breaks — see
## min_impulse. Raise both together for a bigger, more violent burst;
## lower both for pieces that just tumble apart nearby.
@export var max_impulse := 220.0
## Maximum random spin applied to each piece when it breaks (0 = no
## break-induced spin, though pieces can still rotate from later physics
## collisions). Scales with impulse strength like min/max_impulse do.
@export var piece_angular_impulse := 4.0
## Gravity multiplier for spawned pieces, relative to the project's default
## 2D gravity (Project Settings). 0 = pieces aren't pulled down at all —
## they just drift outward on their break impulse; 1 = normal gravity.
@export var piece_gravity_scale := 0.6
## Seconds before a spawned piece is freed. 0 = never (pieces stay forever
## — watch performance if a lot of items break over time).
@export var piece_lifetime := 6.0

const SPRITE_NODE_NAME := "Sprite"
const COLLISION_NODE_NAME := "Collision"
const HIT_AREA_NODE_NAME := "HitArea"
const HIT_SHAPE_NODE_NAME := "HitShape"

var _broken := false
var _hit_count := 0
var _whole_polygon: Polygon2D
var _collision: CollisionPolygon2D
var _hit_area: Area2D

## Builds Sprite/Collision/HitArea the first time this node is ever readied
## (whether that's a bare node with just the Shape Data properties set, or
## one instanced straight into a running game). If those children already
## exist — because this scene was built by the dock's "Build Scene" button,
## which pre-builds and packs them so the item is visible/placeable in the
## editor, not just at runtime — reuses them instead of duplicating.
func _ready() -> void:
	_build_whole_sprite()
	_build_collision()
	_build_hit_area()

func _build_whole_sprite() -> void:
	var existing := get_node_or_null(SPRITE_NODE_NAME)
	if existing is Polygon2D:
		_whole_polygon = existing
		return
	if outer_points.is_empty():
		return
	_whole_polygon = Polygon2D.new()
	_whole_polygon.name = SPRITE_NODE_NAME
	_whole_polygon.polygon = outer_points
	_whole_polygon.texture = texture
	_whole_polygon.uv = _compute_outer_uv()
	add_child(_whole_polygon)
	_whole_polygon.owner = owner if owner != null else self

func _build_collision() -> void:
	var existing := get_node_or_null(COLLISION_NODE_NAME)
	if existing is CollisionPolygon2D:
		_collision = existing
		return
	if outer_points.is_empty():
		return
	_collision = CollisionPolygon2D.new()
	_collision.name = COLLISION_NODE_NAME
	_collision.polygon = outer_points
	_collision.visible = false # just the debug outline — collision still works invisible
	add_child(_collision)
	_collision.owner = owner if owner != null else self

func _build_hit_area() -> void:
	var existing := get_node_or_null(HIT_AREA_NODE_NAME)
	if existing is Area2D:
		_hit_area = existing
		_hit_area.collision_mask = hit_detection_mask
		if not _hit_area.body_entered.is_connected(_on_hit_body_entered):
			_hit_area.body_entered.connect(_on_hit_body_entered)
		if not _hit_area.area_entered.is_connected(_on_hit_area_entered):
			_hit_area.area_entered.connect(_on_hit_area_entered)
		return
	if outer_points.is_empty():
		return

	var scene_owner := owner if owner != null else self

	_hit_area = Area2D.new()
	_hit_area.name = HIT_AREA_NODE_NAME
	_hit_area.collision_layer = 0
	_hit_area.collision_mask = hit_detection_mask
	add_child(_hit_area)
	_hit_area.owner = scene_owner

	var hit_shape := CollisionPolygon2D.new()
	hit_shape.name = HIT_SHAPE_NODE_NAME
	hit_shape.polygon = outer_points
	hit_shape.visible = false # just the debug outline — detection still works invisible
	_hit_area.add_child(hit_shape)
	hit_shape.owner = scene_owner

	_hit_area.body_entered.connect(_on_hit_body_entered)
	_hit_area.area_entered.connect(_on_hit_area_entered)

func _compute_outer_uv() -> PackedVector2Array:
	var uv := PackedVector2Array()
	uv.resize(outer_points.size())
	if texture == null or item_scale == 0.0:
		return uv
	var half_size := Vector2(texture.get_size()) * 0.5
	for i in outer_points.size():
		uv[i] = outer_points[i] / item_scale + half_size
	return uv

func _on_hit_body_entered(body: Node2D) -> void:
	_maybe_register_hit(body)

func _on_hit_area_entered(area: Area2D) -> void:
	_maybe_register_hit(area)

func _maybe_register_hit(other: Node2D) -> void:
	if required_group != "" and not other.is_in_group(required_group):
		return
	take_hit(other.global_position)

## Registers a hit from `hit_global_position` (used to aim the impulse of
## whichever shard breaks nearest it). Breaks once hits_to_break is reached.
## Call this directly from weapon/bullet code to bypass physics-layer
## detection entirely.
func take_hit(hit_global_position: Vector2 = global_position) -> void:
	if _broken:
		return
	_hit_count += 1
	if _hit_count >= hits_to_break:
		break_apart(to_local(hit_global_position))

## Breaks the item apart. `impact_point` is in this node's local space
## (Vector2.ZERO is the item's own center, since shard centroids are
## texture-centered) — shards nearer to it fly harder. Spawned pieces are
## added as siblings (under this node's parent) so they survive this node's
## queue_free().
func break_apart(impact_point: Vector2 = Vector2.ZERO) -> void:
	if _broken or shards.is_empty():
		return
	_broken = true

	var parent := get_parent()
	var spawn_transform := global_transform
	if parent != null:
		for shard in shards:
			_spawn_piece(shard, impact_point, parent, spawn_transform)

	broken.emit(shards.size())
	queue_free()

func _spawn_piece(shard: Dictionary, impact_point: Vector2, parent: Node, spawn_transform: Transform2D) -> void:
	var local_points: PackedVector2Array = shard["points"]
	var centroid: Vector2 = shard["centroid"]
	var uv: PackedVector2Array = shard["uv"]
	if local_points.size() < 3:
		return

	# RigidBody2D doesn't reliably keep a scaled Transform once physics
	# simulation starts — the physics server resyncs the node's transform
	# from its own internal (unscaled) state after the first physics step,
	# silently resetting any scale we set. That both snaps a resized item's
	# pieces back to their unscaled size and throws off impulse-driven
	# velocity. So the spawned body is never itself scaled: this item's
	# current scale is baked directly into the piece's geometry instead,
	# and the body is positioned using only spawn_transform's
	# position/rotation.
	var node_scale := spawn_transform.get_scale()
	var scale_factor := (node_scale.x + node_scale.y) * 0.5

	var scaled_points := PackedVector2Array()
	scaled_points.resize(local_points.size())
	for i in local_points.size():
		scaled_points[i] = local_points[i] * node_scale
	var scaled_centroid := centroid * node_scale

	var body := RigidBody2D.new()
	body.gravity_scale = piece_gravity_scale

	var poly := Polygon2D.new()
	poly.polygon = scaled_points
	poly.texture = texture
	poly.uv = uv
	body.add_child(poly)

	var collision := CollisionPolygon2D.new()
	collision.polygon = scaled_points
	collision.visible = false # just the debug outline — collision still works invisible
	body.add_child(collision)

	parent.add_child(body)
	var unscaled_transform := Transform2D(spawn_transform.get_rotation(), spawn_transform.origin)
	body.global_transform = unscaled_transform * Transform2D(0.0, scaled_centroid)

	var away := centroid - impact_point
	if away.length() < 0.01:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	away = away.normalized()
	# `away` is computed in the item's own local (unrotated) points-space,
	# but apply_central_impulse() expects a world-space vector — without
	# rotating it by the item's actual orientation first, a rotated item's
	# pieces launch in directions that ignore that rotation entirely.
	away = away.rotated(spawn_transform.get_rotation())
	# min_impulse/max_impulse are tuned in unscaled pixel units — without
	# this, a resized item's debris still flies apart across the same
	# absolute distance a full-size item's would, scattering way out of
	# proportion to the shrunk (or oversized) sprite.
	var impulse_strength := randf_range(min_impulse, max_impulse) * scale_factor
	body.apply_central_impulse(away * impulse_strength)
	body.apply_torque_impulse(randf_range(-piece_angular_impulse, piece_angular_impulse) * impulse_strength)

	if piece_lifetime > 0.0:
		var tree := body.get_tree()
		if tree != null:
			tree.create_timer(piece_lifetime).timeout.connect(func():
				if is_instance_valid(body):
					body.queue_free()
			)
