@tool
class_name ItemShapeContourTracer
extends RefCounted

## Traces a texture's alpha-channel silhouette into an ordered polygon,
## using the engine's own BitMap.opaque_to_polygons (the same alpha-contour
## walk Godot uses for "Create CollisionPolygon2D Sibling"). Points are
## always re-centered on the texture; if `target_radius` > 0 they're also
## scaled so the farthest vertex sits at that radius from the origin, giving
## consistently-sized items regardless of source texture dimensions —
## points[i] can be mapped back to pixel space via
## `points[i] / scale + texture_size * 0.5`. `target_radius == 0` skips that
## scaling entirely (scale stays 1.0), leaving points in native pixel size.

const DEFAULT_ALPHA_THRESHOLD := 0.1
const DEFAULT_EPSILON := 1.0
const DEFAULT_TARGET_RADIUS := 0.0 ## 0 = no scaling, keep native pixel size
const DEFAULT_MAX_POINTS := 0 ## 0 = unlimited

## Returns a Dictionary. On success: {polygons, main_index, points, scale,
## max_radius, texture_size, epsilon_used}. On failure: {error: String}.
## `max_points`, when > 0, auto-raises the simplification epsilon (via binary
## search) until the traced contour has at most that many points. Some
## shapes have a floor above max_points regardless of epsilon — in that case
## the closest achievable result is returned (check points.size()).
static func trace(image: Image, alpha_threshold: float = DEFAULT_ALPHA_THRESHOLD, epsilon: float = DEFAULT_EPSILON, target_radius: float = DEFAULT_TARGET_RADIUS, max_points: int = DEFAULT_MAX_POINTS) -> Dictionary:
	var working := image
	if working.is_compressed():
		working = working.duplicate()
		working.decompress()

	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(working, alpha_threshold)

	var rect := Rect2(Vector2.ZERO, working.get_size())
	var polygons: Array[PackedVector2Array] = bitmap.opaque_to_polygons(rect, epsilon)

	if polygons.is_empty():
		return {"error": "No pixels above the alpha threshold — nothing to trace."}

	var main_index := _main_polygon_index(polygons)
	var used_epsilon := epsilon

	if max_points > 0 and polygons[main_index].size() > max_points:
		var reduced := _reduce_to_point_limit(bitmap, rect, epsilon, max_points, polygons, main_index)
		polygons = reduced["polygons"]
		main_index = reduced["main_index"]
		used_epsilon = reduced["epsilon"]

	var texture_size := working.get_size()
	var half_size := Vector2(texture_size) * 0.5
	var raw_points: PackedVector2Array = polygons[main_index]

	var max_radius := 0.0
	for p in raw_points:
		max_radius = maxf(max_radius, (p - half_size).length())

	if max_radius <= 0.0:
		return {"error": "Traced polygon has zero extent."}

	var scale := 1.0
	if target_radius > 0.0:
		scale = snappedf(target_radius / max_radius, 0.00001)

	var points := PackedVector2Array()
	points.resize(raw_points.size())
	for i in raw_points.size():
		var centered := (raw_points[i] - half_size) * scale
		points[i] = Vector2(snappedf(centered.x, 0.1), snappedf(centered.y, 0.1))

	return {
		"polygons": polygons,
		"main_index": main_index,
		"points": points,
		"scale": scale,
		"max_radius": max_radius,
		"texture_size": texture_size,
		"epsilon_used": used_epsilon,
	}

static func _main_polygon_index(polygons: Array[PackedVector2Array]) -> int:
	var main_index := 0
	var best_area := 0.0
	for i in polygons.size():
		var a := absf(_polygon_area(polygons[i]))
		if a > best_area:
			best_area = a
			main_index = i
	return main_index

## Binary-searches epsilon upward from start_epsilon until the main contour's
## point count is at or below max_points. Douglas-Peucker simplification is
## monotonic (larger epsilon never increases point count), so this always
## converges — either to a fit, or (if the shape has a floor above
## max_points, or epsilon grows past the point where opaque_to_polygons
## stops returning anything) to the fewest points achieved along the way,
## which is always at least as good as the un-reduced trace.
static func _reduce_to_point_limit(bitmap: BitMap, rect: Rect2, start_epsilon: float, max_points: int, fallback_polygons: Array[PackedVector2Array], fallback_main: int) -> Dictionary:
	var best_polygons := fallback_polygons
	var best_main := fallback_main
	var best_epsilon := start_epsilon
	var best_count: int = fallback_polygons[fallback_main].size()

	var lo := start_epsilon # last epsilon tried that still exceeded max_points
	var hi := maxf(start_epsilon, 1.0)
	var found := false

	for _i in 24:
		var polys: Array[PackedVector2Array] = bitmap.opaque_to_polygons(rect, hi)
		if polys.is_empty():
			break # hi has simplified the shape out of existence; stop growing
		var main_i := _main_polygon_index(polys)
		var count: int = polys[main_i].size()
		if count < best_count:
			best_polygons = polys
			best_main = main_i
			best_epsilon = hi
			best_count = count
		if count <= max_points:
			found = true
			break
		lo = hi
		hi *= 2.0

	if found:
		var search_lo := lo
		var search_hi := hi
		for _i in 24:
			if search_hi - search_lo < 0.01:
				break
			var mid := (search_lo + search_hi) * 0.5
			var polys: Array[PackedVector2Array] = bitmap.opaque_to_polygons(rect, mid)
			if polys.is_empty():
				search_hi = mid
				continue
			var main_i := _main_polygon_index(polys)
			var count: int = polys[main_i].size()
			if count <= max_points:
				best_polygons = polys
				best_main = main_i
				best_epsilon = mid
				best_count = count
				search_hi = mid
			else:
				search_lo = mid

	return {"polygons": best_polygons, "main_index": best_main, "epsilon": best_epsilon}

static func _polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	var n := points.size()
	for i in n:
		var a := points[i]
		var b := points[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	return area * 0.5

## Converts raw pixel-space shard polygons into the shard data shape the
## dock's "Build Scene" button assigns directly onto an ItemShapeBreakableItem node.
## Each entry is a Dictionary: `points` (local, relative to the shard's own
## centroid — the piece's pivot when it's spawned standalone), `centroid`
## (that pivot's offset from the texture center, in the same points-space as
## the outer `points`), and `uv` (the shard's outline in raw source-texture
## pixel space, for sampling the correct crop of the original art).
## `shard_polygons` are raw pixel-space polygons (the same space as
## result["polygons"][result["main_index"]]) — typically from
## ItemShapeFracture.fracture().
static func build_shard_data(result: Dictionary, shard_polygons: Array[PackedVector2Array]) -> Array[Dictionary]:
	var texture_size: Vector2i = result["texture_size"]
	var half_size := Vector2(texture_size) * 0.5
	var scale: float = result["scale"]

	var shards: Array[Dictionary] = []
	for raw_shard in shard_polygons:
		var scaled := PackedVector2Array()
		scaled.resize(raw_shard.size())
		for i in raw_shard.size():
			scaled[i] = (raw_shard[i] - half_size) * scale

		var centroid: Vector2 = ItemShapeFracture.polygon_centroid(scaled)
		var local_points := PackedVector2Array()
		local_points.resize(scaled.size())
		for i in scaled.size():
			var local_point := scaled[i] - centroid
			local_points[i] = Vector2(snappedf(local_point.x, 0.1), snappedf(local_point.y, 0.1))
		var rounded_centroid := Vector2(snappedf(centroid.x, 0.1), snappedf(centroid.y, 0.1))

		var uv := PackedVector2Array()
		uv.resize(raw_shard.size())
		for i in raw_shard.size():
			uv[i] = Vector2(snappedf(raw_shard[i].x, 0.1), snappedf(raw_shard[i].y, 0.1))

		shards.append({"points": local_points, "centroid": rounded_centroid, "uv": uv})

	return shards
