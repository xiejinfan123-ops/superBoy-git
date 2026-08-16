@tool
extends Control

const ContourTracer = preload("res://addons/breakable_2d_sprites/contour_tracer.gd")
const TracePreview = preload("res://addons/breakable_2d_sprites/preview_control.gd")
const Fracture = preload("res://addons/breakable_2d_sprites/fracture.gd")
const BreakableItemScript = preload("res://addons/breakable_2d_sprites/breakable_item.gd")

const BUILT_SCENES_DIR := "res://built_items"

const ALPHA_THRESHOLD_TOOLTIP := "Pixels with alpha above this fraction (0-1) count as part of\nthe silhouette; below it, they're treated as transparent.\nRaise it to ignore soft glows/halos around a sprite; lower it\ntoward 0 if a soft-edged sprite is losing detail at its\nboundary. Rarely needs changing for clean sprite art (fully\nopaque or fully transparent, no soft edges)."
const EPSILON_TOOLTIP := "Douglas-Peucker simplification distance, in source-texture\npixels, applied to the raw pixel-boundary trace before\ncentering/scaling. Higher = fewer points but a coarser, more\nangular outline (can round off small features); 0 keeps every\npixel-grid corner (hundreds of points). Auto-raised by Max\nPoints when that's set above 0, so you mostly only need this\ndirectly if you want a specific simplification level rather\nthan a specific point count."

var _texture_picker: EditorResourcePicker
var _name_edit: LineEdit
var _threshold_spin: SpinBox
var _epsilon_spin: SpinBox
var _radius_spin: SpinBox
var _max_points_spin: SpinBox
var _trace_button: Button
var _stats_label: Label
var _preview: TracePreview
var _shard_count_spin: SpinBox
var _shatter_seed_spin: SpinBox
var _reroll_button: Button
var _shatter_stats_label: Label
var _build_scene_button: Button
var _build_scene_label: Label

var _last_result: Dictionary = {}
var _last_shards: Array[PackedVector2Array] = []
var _current_texture: Texture2D = null

## True until the user actually types into Item Name — while true, a new
## texture keeps auto-filling the name; once the user edits it by hand, a
## texture change no longer overwrites their choice.
var _name_is_auto := true
var _setting_name_programmatically := false

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	custom_minimum_size = Vector2(300, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 6)
	scroll.add_child(root)

	root.add_child(_margin(6))
	root.add_child(_labeled_row("Texture", _make_texture_picker()))
	root.add_child(_labeled_row("Item Name", _make_name_edit()))
	root.add_child(_labeled_row("Max Points (0 = unlimited)", _make_max_points_spin()))
	root.add_child(_labeled_row("Target Scale (px) (0 = keep native pixel size)", _make_radius_spin()))
	root.add_child(_build_advanced_section())

	root.add_child(HSeparator.new())

	root.add_child(_labeled_row("Shard Count", _make_shard_count_spin()))

	var seed_row := HBoxContainer.new()
	_shatter_seed_spin = SpinBox.new()
	_shatter_seed_spin.min_value = 0
	_shatter_seed_spin.max_value = 999999
	_shatter_seed_spin.step = 1
	_shatter_seed_spin.value = 0
	_shatter_seed_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shatter_seed_spin.value_changed.connect(_on_shatter_param_changed)
	seed_row.add_child(_shatter_seed_spin)
	_reroll_button = Button.new()
	_reroll_button.text = "Reroll"
	_reroll_button.pressed.connect(_on_reroll_pressed)
	seed_row.add_child(_reroll_button)
	root.add_child(_labeled_row("Random Seed", seed_row))

	_trace_button = Button.new()
	_trace_button.text = "Generate Pieces"
	_trace_button.pressed.connect(_on_trace_pressed)
	root.add_child(_trace_button)

	_build_scene_button = Button.new()
	_build_scene_button.text = "Build Scene"
	_build_scene_button.disabled = true
	_build_scene_button.pressed.connect(_on_build_scene_pressed)
	root.add_child(_build_scene_button)

	root.add_child(HSeparator.new())

	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.text = "No trace yet."
	root.add_child(_stats_label)

	_preview = TracePreview.new()
	_preview.custom_minimum_size = Vector2(280, 280)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_preview)

	_shatter_stats_label = Label.new()
	_shatter_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shatter_stats_label.visible = false
	root.add_child(_shatter_stats_label)

	_build_scene_label = Label.new()
	_build_scene_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_scene_label.text = "Needs an Item Name and generated pieces. Builds a placeable .tscn under %s using addons/breakable_2d_sprites/breakable_item.gd (StaticBody2D, hittable — see that script's hit_detection_mask / take_hit())." % BUILT_SCENES_DIR
	root.add_child(_build_scene_label)

	root.add_child(_margin(6))

func _margin(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _labeled_row(label_text: String, control: Control, tooltip: String = "") -> Control:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	if tooltip != "":
		label.tooltip_text = tooltip
		control.tooltip_text = tooltip
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

## Collapsed by default: Alpha Threshold and Simplify are edge-case knobs
## (soft/glowy edges, or wanting a specific simplification level rather than
## a specific point count via Max Points) that most traces never need to
## touch — tucked away so the everyday controls aren't crowded.
func _build_advanced_section() -> Control:
	var wrapper := VBoxContainer.new()

	var toggle := Button.new()
	toggle.text = "▸ Advanced"
	toggle.toggle_mode = true
	toggle.flat = true
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	wrapper.add_child(toggle)

	var content := VBoxContainer.new()
	content.visible = false
	content.add_theme_constant_override("separation", 6)
	wrapper.add_child(content)

	content.add_child(_labeled_row("Alpha Threshold", _make_threshold_spin(), ALPHA_THRESHOLD_TOOLTIP))
	content.add_child(_labeled_row("Simplify (px)", _make_epsilon_spin(), EPSILON_TOOLTIP))

	toggle.toggled.connect(func(pressed: bool) -> void:
		content.visible = pressed
		toggle.text = "▾ Advanced" if pressed else "▸ Advanced"
	)

	return wrapper

func _make_texture_picker() -> Control:
	_texture_picker = EditorResourcePicker.new()
	_texture_picker.base_type = "Texture2D"
	_texture_picker.resource_changed.connect(_on_texture_changed)
	return _texture_picker

func _make_name_edit() -> Control:
	_name_edit = LineEdit.new()
	_name_edit.text_changed.connect(_on_name_changed)
	return _name_edit

func _make_threshold_spin() -> Control:
	_threshold_spin = SpinBox.new()
	_threshold_spin.min_value = 0.0
	_threshold_spin.max_value = 1.0
	_threshold_spin.step = 0.01
	_threshold_spin.value = ContourTracer.DEFAULT_ALPHA_THRESHOLD
	return _threshold_spin

func _make_epsilon_spin() -> Control:
	_epsilon_spin = SpinBox.new()
	_epsilon_spin.min_value = 0.0
	_epsilon_spin.max_value = 20.0
	_epsilon_spin.step = 0.1
	_epsilon_spin.value = ContourTracer.DEFAULT_EPSILON
	return _epsilon_spin

func _make_max_points_spin() -> Control:
	_max_points_spin = SpinBox.new()
	_max_points_spin.min_value = 0
	_max_points_spin.max_value = 2000
	_max_points_spin.step = 1
	_max_points_spin.value = ContourTracer.DEFAULT_MAX_POINTS
	return _max_points_spin

func _make_shard_count_spin() -> Control:
	_shard_count_spin = SpinBox.new()
	_shard_count_spin.min_value = 2
	_shard_count_spin.max_value = 200
	_shard_count_spin.step = 1
	_shard_count_spin.value = 10
	_shard_count_spin.value_changed.connect(_on_shatter_param_changed)
	return _shard_count_spin

func _make_radius_spin() -> Control:
	_radius_spin = SpinBox.new()
	_radius_spin.min_value = 0.0
	_radius_spin.max_value = 2000.0
	_radius_spin.step = 1.0
	_radius_spin.value = ContourTracer.DEFAULT_TARGET_RADIUS
	return _radius_spin

func _on_texture_changed(resource: Resource) -> void:
	_current_texture = resource as Texture2D
	_last_result = {}
	_last_shards = []
	_preview.clear_data()
	_shatter_stats_label.visible = false
	_build_scene_button.disabled = true
	if _current_texture != null:
		var res_path := _current_texture.resource_path
		if res_path != "" and (_name_is_auto or _name_edit.text.strip_edges() == ""):
			_setting_name_programmatically = true
			_name_edit.text = _humanize_filename(res_path)
			_setting_name_programmatically = false
			_name_is_auto = true
		_stats_label.text = "Ready to trace."
	else:
		_setting_name_programmatically = true
		_name_edit.text = ""
		_setting_name_programmatically = false
		_name_is_auto = true
		_stats_label.text = "No trace yet."

func _humanize_filename(path: String) -> String:
	var base := path.get_file().get_basename()
	base = base.replace("_", " ").replace("-", " ")
	var words := base.split(" ", false)
	var out := PackedStringArray()
	for w in words:
		if w.is_valid_int():
			continue
		out.append(w.capitalize())
	return " ".join(out)

func _on_trace_pressed() -> void:
	if _current_texture == null:
		_stats_label.text = "Pick a texture first."
		return

	var image := _current_texture.get_image()
	if image == null:
		_stats_label.text = "Couldn't read pixel data from this texture."
		return

	var max_points := int(_max_points_spin.value)
	var result := ContourTracer.trace(
		image,
		_threshold_spin.value,
		_epsilon_spin.value,
		_radius_spin.value,
		max_points
	)

	if result.has("error"):
		_stats_label.text = "Error: %s" % result["error"]
		_preview.clear_data()
		_shatter_stats_label.visible = false
		_build_scene_button.disabled = true
		_last_result = {}
		_last_shards = []
		return

	_last_result = result
	var polygons: Array[PackedVector2Array] = result["polygons"]
	_preview.set_data(_current_texture, polygons, result["main_index"])

	var contour_note := ""
	if polygons.size() > 1:
		contour_note = " (%d contours found, using the largest)" % polygons.size()

	var point_count := (result["points"] as PackedVector2Array).size()
	var limit_note := ""
	if max_points > 0:
		if point_count > max_points:
			limit_note = " · couldn't reach %d pts (shape's floor is higher)" % max_points
		elif not is_equal_approx(result["epsilon_used"], _epsilon_spin.value):
			limit_note = " · simplify auto-raised to %.2fpx to fit %d pts" % [result["epsilon_used"], max_points]

	_stats_label.text = "%d points%s · scale %.5f · max radius %.1fpx%s" % [
		point_count, contour_note, result["scale"], result["max_radius"], limit_note
	]

	_update_shatter()

func _on_name_changed(_new_text: String) -> void:
	if not _setting_name_programmatically:
		_name_is_auto = false
	_update_build_scene_button_state()

func _on_shatter_param_changed(_value: float) -> void:
	if not _last_result.is_empty():
		_update_shatter()

func _on_reroll_pressed() -> void:
	_shatter_seed_spin.value = randi() % 999999
	if not _last_result.is_empty():
		_update_shatter()

func _update_shatter() -> void:
	var raw_polygons: Array[PackedVector2Array] = _last_result["polygons"]
	var raw_main: PackedVector2Array = raw_polygons[_last_result["main_index"]]
	var shard_count := int(_shard_count_spin.value)
	var rng_seed := int(_shatter_seed_spin.value)

	_last_shards = Fracture.fracture(raw_main, shard_count, rng_seed)
	_preview.set_shards(_last_shards)
	_update_build_scene_button_state()

	_shatter_stats_label.visible = true
	if _last_shards.size() != shard_count:
		_shatter_stats_label.text = "%d shards (requested %d — concave splits or tight packing changed the count)" % [_last_shards.size(), shard_count]
	else:
		_shatter_stats_label.text = "%d shards" % _last_shards.size()

func _update_build_scene_button_state() -> void:
	_build_scene_button.disabled = _last_shards.is_empty() or _name_edit.text.strip_edges() == ""

## Builds a standalone, placeable .tscn: a single ItemShapeBreakableItem-scripted
## node with its Shape Data properties set, then momentarily enters the
## editor's live tree so _ready() builds the real Sprite/Collision/HitArea
## children (owned by this node) before packing — so the saved scene shows
## the actual sprite and is placeable/visible immediately when dragged into
## a game scene, instead of staying an empty node until the game runs and
## _ready() builds it fresh.
func _on_build_scene_pressed() -> void:
	if _last_result.is_empty() or _last_shards.is_empty() or _current_texture == null:
		_build_scene_label.text = "Trace a texture first (click Generate Pieces)."
		return

	var item_name := _name_edit.text.strip_edges()
	if item_name == "":
		_build_scene_label.text = "Enter an Item Name first."
		return
	var file_name := _sanitize_filename(item_name)

	var make_dir_err := DirAccess.make_dir_recursive_absolute(BUILT_SCENES_DIR)
	if make_dir_err != OK and make_dir_err != ERR_ALREADY_EXISTS:
		_build_scene_label.text = "Couldn't create %s (error %d)." % [BUILT_SCENES_DIR, make_dir_err]
		return

	var node := BreakableItemScript.new()
	node.name = file_name
	node.texture = _current_texture
	node.item_scale = _last_result["scale"]
	node.outer_points = _last_result["points"]
	node.shards = ContourTracer.build_shard_data(_last_result, _last_shards)

	get_tree().root.add_child(node) # triggers _ready(), building+owning the children
	get_tree().root.remove_child(node) # detach immediately, before packing

	var packed := PackedScene.new()
	var pack_err := packed.pack(node)
	node.free()

	if pack_err != OK:
		_build_scene_label.text = "Failed to pack scene (error %d)." % pack_err
		return

	var out_path := "%s/%s.tscn" % [BUILT_SCENES_DIR, file_name]
	var save_err := ResourceSaver.save(packed, out_path)
	if save_err != OK:
		_build_scene_label.text = "Failed to save %s (error %d)." % [out_path, save_err]
		return

	if Engine.is_editor_hint():
		var fs := EditorInterface.get_resource_filesystem()
		if fs != null:
			fs.scan()

	_build_scene_label.text = "Saved %s — instance it anywhere. Set hit_detection_mask (Inspector, Hit Detection group) to your bullets' physics layer, or call take_hit() directly from weapon code." % out_path

func _sanitize_filename(item_name: String) -> String:
	var out := ""
	for c in item_name.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
		elif out != "" and not out.ends_with("_"):
			out += "_"
	out = out.rstrip("_")
	if out == "":
		out = "item"
	return out
