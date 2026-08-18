class_name CapeCloth
extends Polygon2D

## The cape as simulated cloth: a 2D verlet lattice skinned onto this
## Polygon2D, textured with the cape art.
##
## Simulated in WORLD space, rendered in local space — when the body moves,
## turns or falls, the cloth lags a frame behind and trailing, whipping,
## lifting and settling all emerge from the sim.
##
## Four decisions carry the liveliness; all four exist because their opposites
## were tried and read as stiff:
##
## 1. Only the COLLAR is pinned (~13 px), not the cloth's whole top edge.
##    Welding the full top row makes the upper half of the cape rigid.
## 2. Constraints are ONE-SIDED: stretching is resisted firmly, compression
##    barely — real fabric buckles instead of pushing back. This is what lets
##    the cloth furl on a turn rather than stay a plank.
## 3. Damping is light, so swings overshoot and oscillate. The authored drape
##    is preserved by a soft shape-memory pull toward the rest pose instead of
##    by strangling the motion.
## 4. Wind force depends on each segment's ORIENTATION (quadratic normal
##    drag), so flapping arises as aerodynamic feedback, not a scripted sine.
##
## Two guards keep the chaos temporary, because with buckling this free a
## crossed pair of columns is otherwise a STABLE equilibrium the shape-memory
## spring cannot escape — tangles used to be permanent:
##
## 5. Adjacent columns may fold close but never pass through each other,
##    corrected gradually so a turn still reads as a swirl, not a snap.
## 6. Standing still ramps up a gentle homing that glides the cloth back to
##    the authored drape; any movement kills it instantly, so it never
##    dampens motion — it only guarantees the return.
##
## Nothing else may drive this node's transform — the sim owns the cape.

@export_group("Fabric")
## Lattice resolution. Columns give folds; rows give drape smoothness.
@export_range(3, 7) var cols: int = 5
@export_range(4, 12) var rows: int = 8
## Physics substeps per frame. Livelier parameters need two for stability.
@export_range(1, 4) var substeps: int = 2
## Constraint passes per substep.
@export_range(1, 8) var iterations: int = 3
## Fraction of velocity kept each substep. High = momentum survives, cloth
## overshoots and oscillates. The shape-memory pull is what stops it drifting.
## 0.978: heavy fabric bleeds energy through internal friction — LEIVO asked
## for a cape with weight, and the earlier 0.985 read as silk.
@export_range(0.9, 1.0, 0.005) var damping: float = 0.978
## Cloth gravity, px/s². This is what the airflow has to defeat before the
## cape can lift, so it IS the weight of the fabric. 300 with shape_memory 80
## sags the drape ~4 px below the drawn silhouette, which homing then closes.
@export var cloth_gravity: float = 300.0
## Mass factor at the hem relative to the collar. A real cape is cut with a
## weighted hem: air shoves the shoulders around, the hem swings late and
## low. Applied to air and kicks only — gravity accelerates all mass alike.
@export_range(1.0, 2.5, 0.05) var hem_mass: float = 1.45
## How firmly compressed edges resist. ~0 = fabric buckles freely (silk),
## higher = stiffer weave. Stretch is always resisted at full strength.
@export_range(0.0, 1.0, 0.05) var compression_resist: float = 0.15
## Diagonal (shear) stiffness while stretching.
@export_range(0.0, 1.0, 0.05) var shear: float = 0.25
## Soft pull toward the authored drape, in 1/s². Strong enough that the cape
## settles back into the drawn silhouette, weak enough that motion dominates.
@export var shape_memory: float = 80.0
## One-sided vertical stiffness: a column resists FOLDING (second neighbours
## closing in) but not straightening. Heavy woven cloth holds a smooth arc
## instead of crumpling; this is most of what fabric "body" looks like.
@export_range(0.0, 0.6, 0.05) var bend_stiffness: float = 0.15

@export_group("Recovery")
## Adjacent columns may fold to this fraction of their rest spacing, measured
## along the row's rest axis, but never closer — folding stays free,
## passing through does not. This is what makes tangles impossible to keep.
@export_range(0.0, 0.6, 0.05) var min_lateral_frac: float = 0.3
## Fraction of an ordering violation corrected per substep. Below 1.0 the
## un-crossing is spread over several frames, so a direction flip still
## swirls the fabric around him instead of snapping it to the other side.
@export_range(0.05, 1.0, 0.05) var uncross_rate: float = 0.25
## Extra pull toward the authored drape while he stands calm, in 1/s.
## The spring alone can be trapped by a fold; this guarantees the way home.
@export var settle_homing: float = 3.5
## Seconds of standing still before the homing reaches full strength.
@export var settle_ramp_time: float = 0.5
## Below this speed, in px/s, he counts as standing still for homing.
@export var settle_speed_threshold: float = 30.0

@export_group("Air")
## Quadratic normal-drag coefficient. The force on each cloth segment is along
## its normal and grows with the square of the airflow across it — orientation
## feedback, which is where flapping comes from. At 0.007 the wind at run
## speed was 7-14x gravity and the whole cape planed out flat; 0.0035 with
## the airflow cap keeps the peak near 1.2x, so it streams but hangs.
@export var aero_coefficient: float = 0.0035
## Airflow saturation, px/s. Across-flow above this contributes no extra
## force — quadratic drag must not grow without bound with his top speed.
@export var airflow_cap: float = 320.0
## Upward aero force allowed, as a fraction of cloth_gravity. Pure normal
## drag turns a trailing cape into a KITE — tilted segments generate steady
## lift, collar tension is the string, and the hem parks above the collar.
## Real fabric luffs: it flutters and dumps that lift. Streaming backward is
## unrestricted; holding the cloth UP is not.
@export_range(0.0, 1.0, 0.05) var max_lift_fraction: float = 0.3
## Mild always-on turbulence as a fraction of airflow, so a steady run still
## shimmers. Two incommensurate frequencies, so no visible rhythm.
@export_range(0.0, 0.5, 0.01) var turbulence: float = 0.16
## Hem sway injected at footfalls, so each step ripples down the fabric.
## Heavy cloth ripples visibly but does not jump.
@export var footfall_kick: float = 10.0
## How strongly folds darken. 0 = flat colour.
@export_range(0.0, 0.6, 0.05) var fold_shading: float = 0.3

# The lattice covers the cape texture's FULL content rectangle. Fitting a
# narrower patch to the garment's silhouette clips the artwork's wide drape
# out of existence; transparent cells cost nothing.
#
# This geometry is DERIVED at load (_derive_geometry): the content rectangle
# from the texture's own alpha, the alignment from the Torso sprite the cape
# sits on. Codex rebuilds the character art repeatedly; hardcoded pixel
# numbers go stale the moment that starts. These constants are the fallback
# for when derivation cannot run, and match the 2026-08-18 art.
const TEX_LEFT := 352.0
const TEX_TOP := 920.0
const TEX_RIGHT := 1626.0
const TEX_BOTTOM := 1696.0
# Where the garment is sewn to him, as FRACTIONS of the content width —
# fractions survive a redraw, absolute pixels do not. Authored collar span
# 930..1290 inside content 352..1626.
const COLLAR_LEFT_FRAC := 0.4537
const COLLAR_RIGHT_FRAC := 0.7362
const SPRITE_SCALE := 0.040698
const SPRITE_OFFSET := Vector2(1.424, -39.07)  # Torso sprite position in VisualRoot.

var _player: PlayerController
var _visual_root: Node2D
# Geometry derived at load; initialised to the fallback constants.
var _tex_left := TEX_LEFT
var _tex_top := TEX_TOP
var _tex_right := TEX_RIGHT
var _tex_bottom := TEX_BOTTOM
var _collar_left := 930.0
var _collar_right := 1290.0
var _canvas_center := Vector2(1024.0, 1024.0)
var _align_offset := SPRITE_OFFSET
var _align_scale := SPRITE_SCALE
var _pos: Array[Vector2] = []
var _prev: Array[Vector2] = []
var _pinned: Array[bool] = []
var _rest_local: Array[Vector2] = []
var _rest_uv: PackedVector2Array = PackedVector2Array()
var _len_down: Array[float] = []
var _len_across: Array[float] = []
var _len_diag: Array[float] = []
var _len_bend: Array[float] = []
var _mass: Array[float] = []
var _time: float = 0.0
## 0..1, how long he has been standing still, ramped over settle_ramp_time.
var _calm: float = 0.0


func _ready() -> void:
	# Unlit: his lantern glow sits dead-centre on the fabric and its additive
	# light washes the dark cloth pale (measured 59 -> 181).
	light_mask = 0
	_visual_root = get_parent() as Node2D
	_player = _visual_root.get_parent() as PlayerController

	var visuals := _visual_root as PlayerVisuals
	if visuals != null:
		visuals.footfall.connect(_on_footfall)

	_derive_geometry()
	_build_rest_lattice()
	_reset_cloth()


## Reads the lattice geometry from the assets themselves instead of trusting
## hardcoded numbers: the content rectangle from the cape texture's alpha,
## the alignment from the Torso sprite this cape must sit on. Survives art
## rebuilds. Falls back to the authored constants when anything is missing.
func _derive_geometry() -> void:
	if texture != null:
		var img := texture.get_image()
		if img != null:
			var used := Rect2(img.get_used_rect())
			# A sane cape occupies a real region, not a sliver or the void.
			if used.size.x > 50.0 and used.size.y > 50.0:
				_tex_left = used.position.x
				_tex_top = used.position.y
				_tex_right = used.end.x
				_tex_bottom = used.end.y
				_canvas_center = Vector2(img.get_width(), img.get_height()) * 0.5
	var width := _tex_right - _tex_left
	_collar_left = _tex_left + width * COLLAR_LEFT_FRAC
	_collar_right = _tex_left + width * COLLAR_RIGHT_FRAC

	var torso := _visual_root.get_node_or_null("Torso") as Sprite2D
	if torso != null:
		_align_offset = torso.position
		_align_scale = absf(torso.scale.x)


func _idx(r: int, c: int) -> int:
	return r * cols + c


func _build_rest_lattice() -> void:
	_rest_local.clear()
	_rest_uv = PackedVector2Array()
	_pinned.clear()
	_mass.clear()
	for r in range(rows):
		var v := float(r) / float(rows - 1)
		for c in range(cols):
			var u := float(c) / float(cols - 1)
			var src := Vector2(lerpf(_tex_left, _tex_right, u),
				lerpf(_tex_top, _tex_bottom, v))
			var rest := _src_to_local(src)
			_rest_local.append(rest)
			_rest_uv.append(src)
			# Sewn to him only along the collar span of the top edge.
			_pinned.append(r == 0 and src.x >= _collar_left and src.x <= _collar_right)
			# A weighted hem, like a real cape: air pushes the heavy lower
			# rows around far less than the light fabric at the shoulders.
			# Gravity is untouched — weight changes response to wind, not
			# how fast things fall.
			_mass.append(lerpf(1.0, hem_mass, v))

	if not _pinned.has(true):
		# Whatever the lattice resolution, the garment must attach somewhere:
		# fall back to the top-row point nearest the collar's centre.
		var best := 0
		var best_distance := INF
		for c in range(cols):
			var d: float = absf(_rest_uv[c].x - (_collar_left + _collar_right) * 0.5)
			if d < best_distance:
				best_distance = d
				best = c
		_pinned[best] = true

	_len_down.clear()
	_len_across.clear()
	_len_diag.clear()
	_len_bend.clear()
	for r in range(rows - 1):
		for c in range(cols):
			_len_down.append(_rest_local[_idx(r, c)].distance_to(_rest_local[_idx(r + 1, c)]))
	for r in range(rows):
		for c in range(cols - 1):
			_len_across.append(_rest_local[_idx(r, c)].distance_to(_rest_local[_idx(r, c + 1)]))
	for r in range(rows - 1):
		for c in range(cols - 1):
			_len_diag.append(_rest_local[_idx(r, c)].distance_to(_rest_local[_idx(r + 1, c + 1)]))
			_len_diag.append(_rest_local[_idx(r, c + 1)].distance_to(_rest_local[_idx(r + 1, c)]))
	for r in range(rows - 2):
		for c in range(cols):
			_len_bend.append(_rest_local[_idx(r, c)].distance_to(_rest_local[_idx(r + 2, c)]))


func _src_to_local(src: Vector2) -> Vector2:
	return _align_offset + (src - _canvas_center) * _align_scale


func _reset_cloth() -> void:
	_pos.clear()
	_prev.clear()
	for rest in _rest_local:
		var world := _visual_root.to_global(rest)
		_pos.append(world)
		_prev.append(world)
	_refresh_polygon()


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var dt := delta / float(substeps)
	for _s in range(substeps):
		_step(dt)
	_refresh_polygon()


func _step(dt: float) -> void:
	_time += dt

	for i in range(_pos.size()):
		if _pinned[i]:
			_pos[i] = _visual_root.to_global(_rest_local[i])
			_prev[i] = _pos[i]

	# Airflow over the cloth: his motion through the air, plus a little
	# non-rhythmic turbulence so a steady run still shimmers.
	var wind := Vector2(-_player.velocity.x, -_player.velocity.y * 0.4)
	var gust := wind.length() * turbulence
	wind += Vector2(sin(_time * 7.3) + sin(_time * 11.9) * 0.5,
		sin(_time * 9.1) * 0.4) * gust * 0.5

	for r in range(rows):
		for c in range(cols):
			var i := _idx(r, c)
			if _pinned[i]:
				continue
			var current := _pos[i]
			var velocity := (current - _prev[i]) * damping
			_prev[i] = current

			# Quadratic normal drag: the force is along the cloth's local
			# normal and scales with the square of the airflow across it, so
			# a segment's orientation feeds back into its own motion.
			var below: Vector2 = _pos[_idx(mini(r + 1, rows - 1), c)]
			var above: Vector2 = _pos[_idx(maxi(r - 1, 0), c)]
			var along := (below - above)
			var aero := Vector2.ZERO
			if along.length_squared() > 0.0001:
				var normal := Vector2(along.y, -along.x).normalized()
				var across := clampf(wind.dot(normal), -airflow_cap, airflow_cap)
				# Divided by mass: the same gust barely moves the weighted
				# hem while it still ruffles the shoulders.
				aero = normal * across * absf(across) \
					* aero_coefficient / _mass[i]
				# Luffing: cloth cannot sustain aerodynamic lift beyond a
				# fraction of its own weight (negative y is up).
				aero.y = maxf(aero.y, -cloth_gravity * max_lift_fraction)

			# Soft shape memory toward the authored drape, in world space.
			# Because the target moves with his body, this also produces the
			# trailing lag — the cloth is always chasing where it "should" be.
			var target := _visual_root.to_global(_rest_local[i])
			var restore := (target - current) * shape_memory

			var acceleration := Vector2(0.0, cloth_gravity) + aero + restore
			_pos[i] = current + velocity + acceleration * dt * dt

	_solve_constraints()
	_collide()
	_keep_column_order()
	_settle_home(dt)


func _solve_constraints() -> void:
	for _pass in range(iterations):
		var k := 0
		for r in range(rows - 1):
			for c in range(cols):
				_relax(_idx(r, c), _idx(r + 1, c), _len_down[k], 1.0)
				k += 1
		k = 0
		for r in range(rows):
			for c in range(cols - 1):
				_relax(_idx(r, c), _idx(r, c + 1), _len_across[k], 1.0)
				k += 1
		k = 0
		for r in range(rows - 1):
			for c in range(cols - 1):
				_relax(_idx(r, c), _idx(r + 1, c + 1), _len_diag[k], shear)
				_relax(_idx(r, c + 1), _idx(r + 1, c), _len_diag[k + 1], shear)
				k += 2
		k = 0
		for r in range(rows - 2):
			for c in range(cols):
				_relax_bend(_idx(r, c), _idx(r + 2, c), _len_bend[k])
				k += 1


## The bending mirror of _relax: second vertical neighbours resist CLOSING
## (the column folding sharply) and ignore stretching. Gives the drape the
## smooth heavy arc of woven cloth instead of silk crumple.
func _relax_bend(a: int, b: int, rest: float) -> void:
	if bend_stiffness <= 0.0:
		return
	var span := _pos[b] - _pos[a]
	var dist := span.length()
	if dist < 0.001 or dist >= rest:
		return
	var correction := span * ((dist - rest) / dist) * bend_stiffness
	if _pinned[a] and _pinned[b]:
		return
	if _pinned[a]:
		_pos[b] -= correction
	elif _pinned[b]:
		_pos[a] += correction
	else:
		_pos[a] += correction * 0.5
		_pos[b] -= correction * 0.5


## One-sided distance constraint: stretch is corrected at `strength`,
## compression only at compression_resist — fabric buckles, it does not push.
func _relax(a: int, b: int, rest: float, strength: float) -> void:
	var span := _pos[b] - _pos[a]
	var dist := span.length()
	if dist < 0.001:
		return
	var effective := strength if dist > rest else strength * compression_resist
	var correction := span * ((dist - rest) / dist) * effective
	var a_pinned := _pinned[a]
	var b_pinned := _pinned[b]
	if a_pinned and b_pinned:
		return
	if a_pinned:
		_pos[b] -= correction
	elif b_pinned:
		_pos[a] += correction
	else:
		_pos[a] += correction * 0.5
		_pos[b] -= correction * 0.5


## Adjacent columns must keep their left-to-right order along each row.
## Measured against the ROW'S REST AXIS in world space, so a facing flip
## (which mirrors the rest lattice) is handled for free. Correction is
## fractional per substep: crossings heal over a few frames instead of
## snapping, which is what preserves the turn furl.
func _keep_column_order() -> void:
	for r in range(rows):
		for c in range(cols - 1):
			var a := _idx(r, c)
			var b := _idx(r, c + 1)
			if _pinned[a] and _pinned[b]:
				continue
			var rest_a := _visual_root.to_global(_rest_local[a])
			var rest_b := _visual_root.to_global(_rest_local[b])
			var axis := rest_b - rest_a
			var rest_len := axis.length()
			if rest_len < 0.001:
				continue
			axis /= rest_len
			var proj := (_pos[b] - _pos[a]).dot(axis)
			var min_sep := rest_len * min_lateral_frac
			if proj >= min_sep:
				continue
			var push := (min_sep - proj) * uncross_rate
			if _pinned[a]:
				_pos[b] += axis * push
			elif _pinned[b]:
				_pos[a] -= axis * push
			else:
				_pos[a] -= axis * push * 0.5
				_pos[b] += axis * push * 0.5


## While he stands still, glide every point back to the authored drape.
## Ramps in over settle_ramp_time; any movement resets it to zero instantly,
## so gameplay motion is never dampened. _prev is pulled by the same weight,
## which keeps the implied verlet velocity from spiking.
func _settle_home(dt: float) -> void:
	var standing := _player.is_on_floor() \
		and _player.velocity.length() < settle_speed_threshold
	if standing:
		_calm = minf(_calm + dt / maxf(settle_ramp_time, 0.01), 1.0)
	else:
		_calm = 0.0
		return
	var weight := 1.0 - exp(-settle_homing * _calm * dt)
	for i in range(_pos.size()):
		if _pinned[i]:
			continue
		var target := _visual_root.to_global(_rest_local[i])
		_pos[i] = _pos[i].lerp(target, weight)
		_prev[i] = _prev[i].lerp(target, weight)


func _collide() -> void:
	# Ground: the fabric drapes on the floor instead of passing through.
	if _player.is_on_floor():
		var floor_y := _player.global_position.y + 39.375
		for i in range(_pos.size()):
			if not _pinned[i] and _pos[i].y > floor_y:
				_pos[i].y = floor_y
				_prev[i].y = lerpf(_prev[i].y, floor_y, 0.5)

	# No torso guard here, deliberately. One existed — a circle around his
	# belly — from the era when the body had a hole under the cape and cloth
	# sinking in exposed it. The BodyBack underlay ended that: cloth behind
	# a fully painted body is correct occlusion. What the circle actually
	# did afterwards was inject ~900 px/s² of effective anti-gravity into
	# the trailing cloth (0.06 px/substep of projection), which parked the
	# lower half in a floating wad 20 px above its drape during any run.


## Skins the lattice: one vertex per point, one convex quad per cell, UVs from
## the rest lattice. Quads darken as they compress — fold shading.
func _refresh_polygon() -> void:
	var verts := PackedVector2Array()
	var colors := PackedColorArray()

	for r in range(rows):
		for c in range(cols):
			var i := _idx(r, c)
			verts.append(_rest_local[i] if _pinned[i] else _visual_root.to_local(_pos[i]))

	for r in range(rows):
		for c in range(cols):
			var brightness := 1.0
			if fold_shading > 0.0 and c > 0 and c < cols - 1:
				var rest_span: float = _rest_local[_idx(r, c + 1)].distance_to(
					_rest_local[_idx(r, c - 1)])
				var now_span: float = verts[_idx(r, c + 1)].distance_to(
					verts[_idx(r, c - 1)])
				var compression := clampf(1.0 - now_span / maxf(rest_span, 0.001),
					0.0, 1.0)
				brightness = 1.0 - fold_shading * compression
			colors.append(Color(brightness, brightness, brightness, 1.0))

	var quads: Array = []
	for r in range(rows - 1):
		for c in range(cols - 1):
			quads.append(PackedInt32Array([
				_idx(r, c), _idx(r, c + 1), _idx(r + 1, c + 1), _idx(r + 1, c)]))

	polygon = verts
	uv = _rest_uv
	vertex_colors = colors
	polygons = quads


func _on_footfall(strength: float) -> void:
	# A step sends a small lateral ripple into the lower half of the fabric.
	# The weighted hem takes proportionally less of it.
	var kick := footfall_kick * strength * -signf(_player.velocity.x)
	for r in range(rows / 2, rows):
		var row_frac := float(r) / float(rows - 1)
		for c in range(cols):
			var i := _idx(r, c)
			if not _pinned[i]:
				_prev[i].x -= kick * row_frac * 0.016 / _mass[i]


## Test hook: world position of the hem's centre, for asserting trail/settle.
func hem_world_position() -> Vector2:
	var left: Vector2 = _pos[_idx(rows - 1, 0)]
	var right: Vector2 = _pos[_idx(rows - 1, cols - 1)]
	return (left + right) * 0.5


## Test hook: worst world-space distance between any free point and its
## authored drape position, for asserting the cape actually came home.
func max_rest_deviation() -> float:
	var worst := 0.0
	for i in range(_pos.size()):
		if _pinned[i]:
			continue
		var target := _visual_root.to_global(_rest_local[i])
		worst = maxf(worst, _pos[i].distance_to(target))
	return worst


## Test hook: true if any adjacent pair of columns has actually crossed —
## sits at or past zero separation along its row's rest axis.
func columns_crossed() -> bool:
	for r in range(rows):
		for c in range(cols - 1):
			var a := _idx(r, c)
			var b := _idx(r, c + 1)
			var axis := _visual_root.to_global(_rest_local[b]) \
				- _visual_root.to_global(_rest_local[a])
			if axis.length() < 0.001:
				continue
			if (_pos[b] - _pos[a]).dot(axis.normalized()) <= 0.0:
				return true
	return false
