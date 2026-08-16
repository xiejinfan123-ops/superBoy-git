@tool
class_name ItemShapeFracture
extends RefCounted

## Splits a silhouette polygon into irregular Voronoi-style shards for
## design-time "breakable item" authoring (e.g. a glass pot that shatters).
## Seed points are scattered inside the silhouette; each seed's Voronoi cell
## is built by clipping a large bounding rect against every other seed's
## perpendicular bisector (Geometry2D.intersect_polygons on two convex
## polygons always yields exactly one convex polygon), then every cell is
## clipped to the silhouette itself. A cell that spans a concave notch in
## the silhouette can legitimately split into more than one disconnected
## piece — all pieces are kept as separate shards, so the returned count
## can exceed shard_count.

const MIN_SEED_SEPARATION_FACTOR := 0.5 ## fraction of ideal spacing sqrt(area / count)

## Returns Array[PackedVector2Array] of shard polygons in the same
## coordinate space as `silhouette` (raw texture pixel space, in this
## plugin's usage).
static func fracture(silhouette: PackedVector2Array, shard_count: int, rng_seed: int) -> Array[PackedVector2Array]:
	var shards: Array[PackedVector2Array] = []
	if shard_count <= 1 or silhouette.size() < 3:
		shards.append(silhouette)
		return shards

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var seeds := _generate_seeds(silhouette, shard_count, rng)
	if seeds.size() <= 1:
		shards.append(silhouette)
		return shards

	var bounds := _polygon_bounds(silhouette)
	var diag := bounds.size.length()
	var half_len := diag * 4.0 + 10.0
	var start_cell := _rect_polygon(bounds.grow(diag))

	for i in seeds.size():
		var cell := start_cell
		for j in seeds.size():
			if i == j:
				continue
			cell = _clip_to_bisector(cell, seeds[i], seeds[j], half_len)
			if cell.is_empty():
				break
		if cell.is_empty():
			continue
		var clipped: Array[PackedVector2Array] = Geometry2D.intersect_polygons(cell, silhouette)
		for piece in clipped:
			if piece.size() >= 3:
				shards.append(piece)

	if shards.is_empty():
		shards.append(silhouette)
	return shards

static func _generate_seeds(polygon: PackedVector2Array, count: int, rng: RandomNumberGenerator) -> PackedVector2Array:
	var bounds := _polygon_bounds(polygon)
	var area := absf(_polygon_area(polygon))
	var min_dist := sqrt(area / maxf(float(count), 1.0)) * MIN_SEED_SEPARATION_FACTOR

	var seeds := PackedVector2Array()

	# Pass 1: rejection-sample with a minimum-spacing constraint so shards
	# come out reasonably even-sized instead of a cluster of slivers.
	var attempts := 0
	var max_attempts := count * 60
	while seeds.size() < count and attempts < max_attempts:
		attempts += 1
		var candidate := _random_point_in_rect(bounds, rng)
		if not Geometry2D.is_point_in_polygon(candidate, polygon):
			continue
		var ok := true
		for s in seeds:
			if s.distance_to(candidate) < min_dist:
				ok = false
				break
		if ok:
			seeds.append(candidate)

	# Pass 2: if the spacing constraint left us short (small/thin shapes),
	# fill the remainder with plain rejection sampling so shard_count is met
	# whenever the shape can geometrically fit that many seeds at all.
	attempts = 0
	max_attempts = count * 200
	while seeds.size() < count and attempts < max_attempts:
		attempts += 1
		var candidate := _random_point_in_rect(bounds, rng)
		if Geometry2D.is_point_in_polygon(candidate, polygon):
			seeds.append(candidate)

	return seeds

static func _random_point_in_rect(bounds: Rect2, rng: RandomNumberGenerator) -> Vector2:
	return Vector2(
		rng.randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
		rng.randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
	)

## Clips `polygon` down to the half-plane "closer to keep_point than to
## other_point" (i.e. one side of their perpendicular bisector).
static func _clip_to_bisector(polygon: PackedVector2Array, keep_point: Vector2, other_point: Vector2, half_len: float) -> PackedVector2Array:
	var mid := (keep_point + other_point) * 0.5
	var dir := (other_point - keep_point).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var half_plane := PackedVector2Array([
		mid + normal * half_len,
		mid + normal * half_len - dir * half_len,
		mid - normal * half_len - dir * half_len,
		mid - normal * half_len,
	])
	var result: Array[PackedVector2Array] = Geometry2D.intersect_polygons(polygon, half_plane)
	if result.is_empty():
		return PackedVector2Array()
	# Both inputs are convex so the intersection should be one convex piece;
	# guard against float-noise slivers by keeping the largest if not.
	var best := result[0]
	var best_area := absf(_polygon_area(best))
	for k in range(1, result.size()):
		var a := absf(_polygon_area(result[k]))
		if a > best_area:
			best_area = a
			best = result[k]
	return best

static func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	var r := Rect2(polygon[0], Vector2.ZERO)
	for p in polygon:
		r = r.expand(p)
	return r

static func _rect_polygon(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		r.position,
		Vector2(r.position.x + r.size.x, r.position.y),
		r.position + r.size,
		Vector2(r.position.x, r.position.y + r.size.y),
	])

static func _polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	var n := points.size()
	for i in n:
		var a := points[i]
		var b := points[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	return area * 0.5

## Area-weighted centroid (correct for concave simple polygons, unlike a
## plain vertex average).
static func polygon_centroid(points: PackedVector2Array) -> Vector2:
	var area := 0.0
	var cx := 0.0
	var cy := 0.0
	var n := points.size()
	for i in n:
		var a := points[i]
		var b := points[(i + 1) % n]
		var cross := a.x * b.y - b.x * a.y
		area += cross
		cx += (a.x + b.x) * cross
		cy += (a.y + b.y) * cross
	area *= 0.5
	if absf(area) < 0.0001:
		var sum := Vector2.ZERO
		for p in points:
			sum += p
		return sum / float(n)
	return Vector2(cx / (6.0 * area), cy / (6.0 * area))
