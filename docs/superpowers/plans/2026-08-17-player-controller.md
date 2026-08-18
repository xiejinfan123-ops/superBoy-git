# Player Character Controller Implementation Plan
# 玩家角色控制器实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `simple_player.gd` (a 20-line top-down WASD stub) into a polished
side-scrolling platformer character using the real character art, with
inertia-based running, variable-height jumping, forgiveness windows, and
code-driven squash/stretch animation.

**目标:** 把 `simple_player.gd` (20行的俯视角 WASD 占位代码) 变成打磨过的横版平台
角色，用正式角色图，带惯性跑动、可控高度跳跃、手感宽容窗口、以及代码驱动的
压扁拉伸动画。

**Architecture:** The player becomes a standalone `B/player.tscn` scene with three
layers: `player_controller.gd` (physics + state), `player_visuals.gd` (cosmetic
only, reads controller state), and `player_input.gd` (input polling, swappable
for a fake in tests). Squash/stretch and lean pivot at the feet via a `VisualRoot`
node placed at the collider's bottom edge.

**结构:** 玩家独立成 `B/player.tscn` 场景，分三层: `player_controller.gd` (物理+状态)、
`player_visuals.gd` (纯视觉，只读控制器状态)、`player_input.gd` (输入轮询，测试时可换成
假输入)。压扁拉伸和倾斜以脚底为轴 — 靠放在碰撞框底边的 `VisualRoot` 节点实现。

**Tech Stack:** Godot 4.7.1 (GDScript), headless test runner (no external test framework).

---

## Global Constraints
## 全局约束

- Godot version: **4.7.1 stable**. Binary at
  `C:/Users/Administrator/Documents/Codex/2026-08-17/https-github-com-xiejinfan123-ops-superboy/work/repo/tools/Godot_v4.7.1-stable_win64_console.exe`
- Project root: `C:/Users/Administrator/Documents/Codex/2026-08-17/https-github-com-xiejinfan123-ops-superboy/outputs/superBoy-git-main`
- Hand-written `.tscn` files use `format=3` (Godot reads it; avoids the
  `unique_id` bookkeeping that `format=4` requires).
- All feel-tuning numbers are `@export` so they are adjustable in the Godot
  inspector without editing code.
- Tabs for indentation (GDScript standard, matches existing files).
- Every task ends with a passing headless test run and a commit.
- **After creating any new script that declares `class_name`, run an import pass
  before running tests.** Verified: a headless `--script` run cannot resolve a
  newly added `class_name` until the project's global class cache is rebuilt, and
  fails with `Parse Error: Identifier "X" not declared in the current scope`.
  The import pass is the fix:

  ```bash
  "C:/Users/Administrator/Documents/Codex/2026-08-17/https-github-com-xiejinfan123-ops-superboy/work/repo/tools/Godot_v4.7.1-stable_win64_console.exe" --headless --path "C:/Users/Administrator/Documents/Codex/2026-08-17/https-github-com-xiejinfan123-ops-superboy/outputs/superBoy-git-main" --import
  ```
- Do **not** modify anything under `addons/` — those are the SpriteForge and
  Breakable 2D Sprites editor plugins, out of scope.
- Do **not** touch the `1786820354134.png` copy inside the background
  `Parallax2D` layer of `node_2d.tscn` — that is scenery, not the player.

### Measured facts (already verified headlessly — do not re-derive)
### 实测数据 (已用无界面模式验证过，不用重新推导)

| Fact | Value |
|---|---|
| Tile size | 16 × 16 px, tilemap scale 1.0 |
| Ground surface (top) | world Y = 16 |
| Ground X extent | -2320 → 768 |
| Player collider size | 35 × 78.75 px |
| Player collider world pos | (-1830.5, -43) |
| Character texture | `C/1786820354134.png`, 2048 × 2048 |
| Character opaque bounds in texture | x 350→1628, y 49→1984 (1278 × 1935 px) |
| Sprite scale so character height == collider height | **0.040698** |
| Character on-screen width at that scale | 52.0 px |
| Character faces | **right** in the source image |
| Project default gravity | 980 (unused — controller has its own) |

### Frame-stepping semantics (verified — do not re-derive)
### 帧步进语义 (已验证，不用重新推导)

`SceneTree.physics_frame` fires **before** `_physics_process` runs, so the very
first `await physics_frame` inside `_initialize()` advances the simulation by
**zero** processed frames. Once the main loop is turning, every subsequent
`await physics_frame` equals **exactly one** processed frame.

Consequence: the test runner performs **one priming await** at the top of
`_main()`, and after that `_step(n)` advances exactly `n` frames. Do not add
per-call `+1` compensation — that double-counts.

---

### Shell command shape
### 命令写法

Run tests with (from any directory):

```bash
"C:/Users/Administrator/Documents/Codex/2026-08-17/https-github-com-xiejinfan123-ops-superboy/work/repo/tools/Godot_v4.7.1-stable_win64_console.exe" --headless --path "C:/Users/Administrator/Documents/Codex/2026-08-17/https-github-com-xiejinfan123-ops-superboy/outputs/superBoy-git-main" --script res://tests/run_tests.gd
```

Syntax-check every script with:

```bash
"C:/Users/Administrator/Documents/Codex/2026-08-17/https-github-com-xiejinfan123-ops-superboy/work/repo/tools/Godot_v4.7.1-stable_win64_console.exe" --headless --path "C:/Users/Administrator/Documents/Codex/2026-08-17/https-github-com-xiejinfan123-ops-superboy/outputs/superBoy-git-main" --check-only --script res://B/player_controller.gd
```

---

## File Structure
## 文件结构

| File | Responsibility |
|---|---|
| `B/player_input.gd` (create) | Polls Godot input actions into plain fields. Swappable. |
| `B/player_controller.gd` (create) | Physics: gravity, run, jump, coyote/buffer. Owns state. |
| `B/player_visuals.gd` (create) | Cosmetic only: facing, squash/stretch, lean, breathing. |
| `B/player.tscn` (create) | The player scene: body + collider + VisualRoot + sprite + light. |
| `B/simple_player.gd` (delete, Task 8) | Replaced by the above. |
| `tools/setup_input_map.gd` (create) | One-shot: writes `move_left`/`move_right`/`jump` into `project.godot`. |
| `tests/fake_input.gd` (create) | Test double for `PlayerInput`. |
| `tests/run_tests.gd` (create, grown each task) | Headless test runner + world builders. |
| `node_2d.tscn` (modify, Task 8) | Swap inline `CharacterBody2D` for a `player.tscn` instance; fix camera target. |
| `project.godot` (modify, Task 1) | Gains `[input]` section. |

---

## Task 1: Input actions and the test harness
## 任务 1: 输入动作 + 测试框架

The project currently has **no** `[input]` section — `simple_player.gd` reads raw
`KEY_W` constants. Define real actions, and stand up the headless test runner that
every later task depends on.

项目现在**没有** `[input]` 段 — `simple_player.gd` 直接读 `KEY_W` 常量。定义正式输入
动作，并搭好后续每个任务都要用的无界面测试框架。

**Files:**
- Create: `B/player_input.gd`
- Create: `tools/setup_input_map.gd`
- Create: `tests/fake_input.gd`
- Create: `tests/run_tests.gd`
- Modify: `project.godot` (via the setup script, not by hand)

**Interfaces:**
- Produces: `PlayerInput` class with fields `move_axis: float`,
  `jump_just_pressed: bool`, `jump_held: bool`, and method `poll() -> void`.
- Produces: `FakeInput extends PlayerInput` whose `poll()` is a no-op, so tests
  set the fields directly.
- Produces: `run_tests.gd` helpers `_make_floor(top_y, left_x, right_x) -> StaticBody2D`,
  `_spawn_player(pos: Vector2) -> PlayerController`, `_step(frames: int) -> void`.
- Produces: input actions named `move_left`, `move_right`, `jump`.

- [ ] **Step 1: Write `B/player_input.gd`**

```gdscript
class_name PlayerInput
extends RefCounted

## Reads the project's input actions into plain fields once per physics frame.
## Tests replace this object with a FakeInput and write the fields directly.

var move_axis: float = 0.0
## True only on the frame the jump button went down.
var jump_just_pressed: bool = false
## True for as long as the jump button is down. Drives the variable jump height.
var jump_held: bool = false


func poll() -> void:
	move_axis = Input.get_axis("move_left", "move_right")
	jump_just_pressed = Input.is_action_just_pressed("jump")
	jump_held = Input.is_action_pressed("jump")
```

- [ ] **Step 2: Write `tests/fake_input.gd`**

```gdscript
class_name FakeInput
extends PlayerInput

## Test double: poll() does nothing so a test can drive the fields by hand.
## Call clear_edges() after a simulated frame to expire the one-shot press flag,
## exactly as real input would.

func poll() -> void:
	pass


func clear_edges() -> void:
	jump_just_pressed = false
```

- [ ] **Step 3: Write `tools/setup_input_map.gd`**

```gdscript
extends SceneTree

## One-shot: writes the player's input actions into project.godot.
## Run once; re-running is harmless (it overwrites with the same values).

func _initialize() -> void:
	_apply()


func _make_key(physical: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	return event


func _set_action(action_name: String, keys: Array) -> void:
	var events: Array = []
	for k in keys:
		events.append(_make_key(k))
	ProjectSettings.set_setting("input/" + action_name, {
		"deadzone": 0.2,
		"events": events,
	})


func _apply() -> void:
	_set_action("move_left", [KEY_A, KEY_LEFT])
	_set_action("move_right", [KEY_D, KEY_RIGHT])
	_set_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	var err := ProjectSettings.save()
	print("SAVE_RESULT=", err)
	quit(0 if err == OK else 1)
```

- [ ] **Step 4: Run the setup script**

Run:

```bash
"C:/Users/Administrator/Documents/Codex/2026-08-17/https-github-com-xiejinfan123-ops-superboy/work/repo/tools/Godot_v4.7.1-stable_win64_console.exe" --headless --path "C:/Users/Administrator/Documents/Codex/2026-08-17/https-github-com-xiejinfan123-ops-superboy/outputs/superBoy-git-main" --script res://tools/setup_input_map.gd
```

Expected: `SAVE_RESULT=0`, and `git diff project.godot` shows a new `[input]`
section containing `move_left`, `move_right`, `jump`.

- [ ] **Step 5: Write the test runner `tests/run_tests.gd`**

```gdscript
extends SceneTree

## Headless test runner. Run with:
##   godot --headless --path <project> --script res://tests/run_tests.gd
## Exits 0 when everything passes, 1 otherwise.

const FLOOR_TOP := 100.0
const COLLIDER_HALF_HEIGHT := 39.375

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_main()


func _main() -> void:
	# Priming await. physics_frame fires before _physics_process, so this first
	# one advances zero processed frames. Every await after it is worth exactly
	# one frame, which is what _step() relies on.
	await physics_frame

	await _run("harness boots and physics steps", _test_harness_boots)
	print("RESULT passed=%d failed=%d" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run(label: String, fn: Callable) -> void:
	var errors: Array[String] = []
	await fn.call(errors)
	if errors.is_empty():
		_passed += 1
		print("PASS %s" % label)
	else:
		_failed += 1
		for e in errors:
			print("FAIL %s :: %s" % [label, e])
	await _clear_world()


func _clear_world() -> void:
	for child in get_root().get_children():
		get_root().remove_child(child)
		child.queue_free()
	await physics_frame


## Advances the simulation by exactly `frames` physics frames, with their
## _physics_process results visible on return. Valid only after _main()'s
## priming await — see the plan's frame-stepping note.
func _step(frames: int) -> void:
	for _i in range(frames):
		await physics_frame


func _make_floor(top_y: float, left_x: float, right_x: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(right_x - left_x, 400.0)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = Vector2((left_x + right_x) * 0.5, top_y + 200.0)
	get_root().add_child(body)
	return body


# --- Tests ---

func _test_harness_boots(errors: Array) -> void:
	_make_floor(FLOOR_TOP, -500.0, 500.0)
	var probe := CharacterBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(35.0, 78.75)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	probe.add_child(collider)
	get_root().add_child(probe)
	probe.global_position = Vector2(0.0, -100.0)

	for _i in range(180):
		await physics_frame
		probe.velocity.y += 980.0 / 60.0
		probe.move_and_slide()
		if probe.is_on_floor():
			break

	if not probe.is_on_floor():
		errors.append("probe never landed, y=%f" % probe.global_position.y)
		return
	var feet := probe.global_position.y + COLLIDER_HALF_HEIGHT
	if absf(feet - FLOOR_TOP) > 1.0:
		errors.append("feet expected ~%f, got %f" % [FLOOR_TOP, feet])
```

- [ ] **Step 6: Rebuild the class cache, then run the test runner**

`PlayerInput` and `FakeInput` are brand-new `class_name` declarations, so the
import pass is mandatory here or the runner will fail to parse.

```bash
"C:/Users/Administrator/Documents/Codex/2026-08-17/https-github-com-xiejinfan123-ops-superboy/work/repo/tools/Godot_v4.7.1-stable_win64_console.exe" --headless --path "C:/Users/Administrator/Documents/Codex/2026-08-17/https-github-com-xiejinfan123-ops-superboy/outputs/superBoy-git-main" --import
```

Then run the test runner command from Global Constraints.

Expected: `PASS harness boots and physics steps` and `RESULT passed=1 failed=0`.

- [ ] **Step 7: Commit**

```bash
git add B/player_input.gd tools/setup_input_map.gd tests/fake_input.gd tests/run_tests.gd project.godot
git commit -m "feat: add player input actions and headless test harness"
```

---

## Task 2: Player scene with the real character art
## 任务 2: 玩家场景 + 正式角色图

Build `B/player.tscn` as a standalone scene with the feet-pivoted visual
hierarchy, using the real character design instead of the draft.

把 `B/player.tscn` 建成独立场景，视觉层级以脚底为轴，用正式角色设计图而不是草稿。

**Files:**
- Create: `B/player.tscn`
- Create: `B/player_controller.gd` (stub — physics arrives in Task 3)
- Create: `B/player_visuals.gd` (stub — animation arrives in Task 7)
- Modify: `tests/run_tests.gd` (add `_spawn_player` and a geometry test)

**Interfaces:**
- Consumes: `PlayerInput` from Task 1.
- Produces: `PlayerController extends CharacterBody2D` with `var input: PlayerInput`.
- Produces: `PlayerVisuals extends Node2D`.
- Produces: `res://B/player.tscn` whose root is a `PlayerController` named `Player`,
  with children `CollisionShape2D`, `VisualRoot` (a `PlayerVisuals`), and `PointLight2D`.
- Produces: `run_tests.gd` helper `_spawn_player(pos: Vector2) -> PlayerController`.

**Node layout and why the numbers are what they are:**

```
Player (CharacterBody2D, player_controller.gd)
├── CollisionShape2D      local (0, 0)          35 × 78.75
├── VisualRoot (Node2D, player_visuals.gd)
│   │                     local (0, 39.375)     ← collider's BOTTOM edge = feet pivot
│   └── Sprite2D          local (1.424, -39.07) scale 0.040698
└── PointLight2D          local (-4.6, 12.3)    scale (2, 1.91)
```

- `39.375` is half of the collider height 78.75, so `VisualRoot` sits exactly at
  the feet. Scaling and rotating `VisualRoot` therefore pivots at the feet — the
  character compresses *into the ground*, not around its waist.
- `0.040698` = 78.75 / 1935 makes the drawn character exactly as tall as the collider.
- The sprite offsets recentre the artwork: the opaque pixels are not centred in the
  2048×2048 texture (they sit 35 px left of centre, and the feet are 960 px below
  centre). `x = +1.424` puts the character's horizontal centre at `VisualRoot`'s
  x = 0, so flipping via `scale.x = -1` produces **no sideways jump**.
  `y = -39.07` puts the feet on `VisualRoot`'s origin.
- The light moves off the sprite and onto the body so squash/stretch does not
  distort the glow. `scale (2, 1.91)` preserves the glow's current world size
  (previously `23.05 × 22.01` under a sprite scaled `0.0869`).

- [ ] **Step 1: Write the controller stub `B/player_controller.gd`**

```gdscript
class_name PlayerController
extends CharacterBody2D

## Physics and state for the player character.
## Visuals live in player_visuals.gd and only read from here.

var input: PlayerInput = PlayerInput.new()

## +1 facing right, -1 facing left. Read by the visuals layer.
var facing: int = 1
```

- [ ] **Step 2: Write the visuals stub `B/player_visuals.gd`**

```gdscript
class_name PlayerVisuals
extends Node2D

## Cosmetic layer. Reads PlayerController state and drives sprite transform.
## Deleting this node changes nothing about physics.

var _player: PlayerController


func _ready() -> void:
	_player = get_parent() as PlayerController
```

- [ ] **Step 3: Write `B/player.tscn`**

```
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://B/player_controller.gd" id="1_ctrl"]
[ext_resource type="Script" path="res://B/player_visuals.gd" id="2_vis"]
[ext_resource type="Texture2D" path="res://C/1786820354134.png" id="3_art"]
[ext_resource type="Texture2D" path="res://B/lantern_glow_019.png" id="4_glow"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_player"]
size = Vector2(35, 78.75)

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1_ctrl")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_player")

[node name="VisualRoot" type="Node2D" parent="."]
position = Vector2(0, 39.375)
script = ExtResource("2_vis")

[node name="Sprite2D" type="Sprite2D" parent="VisualRoot"]
position = Vector2(1.424, -39.07)
scale = Vector2(0.040698, 0.040698)
texture = ExtResource("3_art")

[node name="PointLight2D" type="PointLight2D" parent="."]
position = Vector2(-4.6, 12.3)
scale = Vector2(2, 1.91)
color = Color(0.92024887, 0.9172649, 0.9132015, 1)
energy = 2.41
texture = ExtResource("4_glow")
texture_scale = 1.5
```

- [ ] **Step 4: Add the failing geometry test to `tests/run_tests.gd`**

Add the `_spawn_player` helper immediately after `_make_floor`:

```gdscript
func _spawn_player(pos: Vector2) -> PlayerController:
	var packed: PackedScene = load("res://B/player.tscn")
	var player: PlayerController = packed.instantiate()
	get_root().add_child(player)
	player.global_position = pos
	player.input = FakeInput.new()
	return player
```

Add this test method at the end of the file:

```gdscript
func _test_player_scene_geometry(errors: Array) -> void:
	var player := _spawn_player(Vector2(0.0, 0.0))
	var visual_root: Node2D = player.get_node("VisualRoot")
	var sprite: Sprite2D = player.get_node("VisualRoot/Sprite2D")

	if absf(visual_root.position.y - COLLIDER_HALF_HEIGHT) > 0.01:
		errors.append("VisualRoot must sit at the feet (%f), got %f"
			% [COLLIDER_HALF_HEIGHT, visual_root.position.y])

	if sprite.texture.resource_path != "res://C/1786820354134.png":
		errors.append("sprite must use the real character art, got %s"
			% sprite.texture.resource_path)

	# The artwork's opaque centre must land on VisualRoot's x = 0 so that
	# flipping via scale.x = -1 does not shift the character sideways.
	var opaque_centre_x: float = sprite.position.x + (989.0 - 1024.0) * sprite.scale.x
	if absf(opaque_centre_x) > 0.05:
		errors.append("artwork centre should be at x=0, got %f" % opaque_centre_x)

	# The artwork's feet must land on VisualRoot's origin.
	var feet_y: float = sprite.position.y + (1984.0 - 1024.0) * sprite.scale.y
	if absf(feet_y) > 0.05:
		errors.append("artwork feet should be at y=0, got %f" % feet_y)

	# Drawn height must match the collider height.
	var drawn_height: float = 1935.0 * sprite.scale.y
	if absf(drawn_height - 78.75) > 0.5:
		errors.append("drawn height should be 78.75, got %f" % drawn_height)
```

Register it in `_main`, after the harness test:

```gdscript
	await _run("player scene geometry", _test_player_scene_geometry)
```

- [ ] **Step 5: Rebuild the class cache, then run tests**

`PlayerController` and `PlayerVisuals` are new `class_name` declarations, so run
the `--import` command from Global Constraints first, then the test runner.

Expected: `PASS harness boots and physics steps`, `PASS player scene geometry`,
`RESULT passed=2 failed=0`.

If `player scene geometry` fails on a path or node name, fix `player.tscn` — the
numbers in the test are the authority.

- [ ] **Step 6: Commit**

```bash
git add B/player.tscn B/player_controller.gd B/player_visuals.gd tests/run_tests.gd
git commit -m "feat: add player scene with real character art and feet-pivoted visual root"
```

---

## Task 3: Gravity, falling, and landing
## 任务 3: 重力、下落、落地

The core of "jump should fall down". Asymmetric gravity (heavier falling than
rising) is what makes a jump feel weighty rather than like a balloon.

"跳跃要掉下来"的核心。非对称重力 (下落比上升重) 是让跳跃有分量感而不是像气球的关键。

**Files:**
- Modify: `B/player_controller.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `PlayerController`, `FakeInput` from Tasks 1–2.
- Produces: `PlayerController` exports `gravity_rise: float`, `gravity_fall: float`,
  `max_fall_speed: float`; and state `just_landed: bool`, `landing_impact: float`
  (0.0–1.0, how hard the landing was — Task 7 scales the squash by this).

- [ ] **Step 1: Write the failing tests**

Add to `tests/run_tests.gd`:

```gdscript
func _test_falls_under_gravity(errors: Array) -> void:
	_make_floor(FLOOR_TOP, -500.0, 500.0)
	var player := _spawn_player(Vector2(0.0, -200.0))
	await _step(3)
	if player.velocity.y <= 0.0:
		errors.append("expected downward velocity, got %f" % player.velocity.y)


func _test_lands_on_floor(errors: Array) -> void:
	_make_floor(FLOOR_TOP, -500.0, 500.0)
	var player := _spawn_player(Vector2(0.0, -200.0))
	await _step(180)
	if not player.is_on_floor():
		errors.append("expected to land, y=%f" % player.global_position.y)
		return
	var feet := player.global_position.y + COLLIDER_HALF_HEIGHT
	if absf(feet - FLOOR_TOP) > 1.0:
		errors.append("feet expected ~%f, got %f" % [FLOOR_TOP, feet])


func _test_fall_speed_is_capped(errors: Array) -> void:
	var player := _spawn_player(Vector2(0.0, -200.0))
	await _step(300)
	if player.velocity.y > player.max_fall_speed + 1.0:
		errors.append("fall speed %f exceeded cap %f"
			% [player.velocity.y, player.max_fall_speed])


func _test_landing_is_reported(errors: Array) -> void:
	_make_floor(FLOOR_TOP, -500.0, 500.0)
	var player := _spawn_player(Vector2(0.0, -200.0))
	var saw_landing := false
	var impact := 0.0
	for _i in range(180):
		await physics_frame
		if player.just_landed:
			saw_landing = true
			impact = player.landing_impact
			break
	if not saw_landing:
		errors.append("just_landed never fired")
		return
	if impact <= 0.0 or impact > 1.0:
		errors.append("landing_impact should be in (0,1], got %f" % impact)
```

Register all four in `_main`:

```gdscript
	await _run("falls under gravity", _test_falls_under_gravity)
	await _run("lands on floor", _test_lands_on_floor)
	await _run("fall speed is capped", _test_fall_speed_is_capped)
	await _run("landing is reported", _test_landing_is_reported)
```

- [ ] **Step 2: Run tests to verify they fail**

Run the test runner.
Expected: the four new tests FAIL (the controller has no `_physics_process` and no
`max_fall_speed`, so it never moves). A parse error on `player.max_fall_speed`
also counts as the expected failure.

- [ ] **Step 3: Implement gravity in `B/player_controller.gd`**

Replace the whole file with:

```gdscript
class_name PlayerController
extends CharacterBody2D

## Physics and state for the player character.
## Visuals live in player_visuals.gd and only read from here.

@export_group("Jump")
## Upward pull while rising. Lighter than gravity_fall so the jump hangs
## briefly at its peak.
@export var gravity_rise: float = 2100.0
## Downward pull while falling. Heavier than gravity_rise so falls feel weighty.
@export var gravity_fall: float = 3100.0
## Terminal velocity, so long drops stay steerable.
@export var max_fall_speed: float = 1400.0

var input: PlayerInput = PlayerInput.new()

## +1 facing right, -1 facing left. Read by the visuals layer.
var facing: int = 1

## True for the single physics frame on which the player touched down.
var just_landed: bool = false
## 0.0–1.0 severity of that landing, as a fraction of max_fall_speed.
var landing_impact: float = 0.0

var _was_grounded: bool = false


func _physics_process(delta: float) -> void:
	input.poll()
	just_landed = false

	_apply_gravity(delta)

	var impact_speed := velocity.y
	move_and_slide()

	var grounded := is_on_floor()
	if grounded and not _was_grounded:
		just_landed = true
		landing_impact = clampf(impact_speed / max_fall_speed, 0.0, 1.0)
	_was_grounded = grounded


func _apply_gravity(delta: float) -> void:
	var gravity := gravity_rise if velocity.y < 0.0 else gravity_fall
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
```

- [ ] **Step 4: Run tests to verify they pass**

Run the test runner.
Expected: `RESULT passed=6 failed=0`.

- [ ] **Step 5: Commit**

```bash
git add B/player_controller.gd tests/run_tests.gd
git commit -m "feat: add asymmetric gravity, terminal velocity, and landing detection"
```

---

## Task 4: Horizontal movement with inertia
## 任务 4: 带惯性的水平移动

The "惯性" requirement. Speed ramps up instead of snapping on, decays instead of
stopping dead, and reversing direction brakes harder than coasting does so turns
still feel responsive.

"惯性"这条要求。速度是渐进加速不是瞬间到顶，松手是渐进衰减不是瞬间停死，反向转身
刹车比自然滑行更快，所以换向依然跟手。

**Files:**
- Modify: `B/player_controller.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: everything from Task 3.
- Produces: `PlayerController` exports `max_run_speed`, `ground_acceleration`,
  `ground_friction`, `turn_brake_multiplier`, `air_acceleration`, `air_friction`.
- Produces: `facing` is now updated from input each frame.

- [ ] **Step 1: Write the failing tests**

Add to `tests/run_tests.gd`:

```gdscript
func _test_run_accelerates_gradually(errors: Array) -> void:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var fake: FakeInput = player.input
	await _step(2)
	fake.move_axis = 1.0

	await _step(1)
	var after_one := player.velocity.x
	if after_one <= 0.0:
		errors.append("expected rightward motion, got %f" % after_one)
		return
	if after_one >= player.max_run_speed * 0.9:
		errors.append("speed should ramp, not snap: %f after one frame" % after_one)

	await _step(60)
	if player.velocity.x < player.max_run_speed * 0.95:
		errors.append("should reach near top speed, got %f" % player.velocity.x)


func _test_friction_decelerates_gradually(errors: Array) -> void:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var fake: FakeInput = player.input
	fake.move_axis = 1.0
	await _step(60)
	fake.move_axis = 0.0

	await _step(1)
	if player.velocity.x <= 0.0:
		errors.append("should coast, not stop dead: %f" % player.velocity.x)

	await _step(60)
	if absf(player.velocity.x) > 1.0:
		errors.append("should come to rest, got %f" % player.velocity.x)


## Both halves are measured one at a time. Two CharacterBody2D instances share
## the default collision layer and would push each other around if they existed
## in the same world at the same time.
func _test_turning_brakes_faster_than_coasting(errors: Array) -> void:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var coasting := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var coast_input: FakeInput = coasting.input
	coast_input.move_axis = 1.0
	await _step(60)
	coast_input.move_axis = 0.0
	await _step(4)
	var coast_speed := coasting.velocity.x
	await _clear_world()

	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var turning := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var turn_input: FakeInput = turning.input
	turn_input.move_axis = 1.0
	await _step(60)
	turn_input.move_axis = -1.0
	await _step(4)
	var turn_speed := turning.velocity.x

	if turn_speed >= coast_speed:
		errors.append("turning (%f) should shed speed faster than coasting (%f)"
			% [turn_speed, coast_speed])


func _test_air_control_is_weaker_than_ground(errors: Array) -> void:
	var airborne := _spawn_player(Vector2(0.0, -400.0))
	var air_input: FakeInput = airborne.input
	air_input.move_axis = 1.0
	await _step(5)
	var air_speed := airborne.velocity.x
	await _clear_world()

	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var grounded := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var ground_input: FakeInput = grounded.input
	await _step(2)
	ground_input.move_axis = 1.0
	await _step(5)
	var ground_speed := grounded.velocity.x

	if air_speed >= ground_speed:
		errors.append("air accel (%f) should be weaker than ground (%f)"
			% [air_speed, ground_speed])


func _test_facing_follows_input(errors: Array) -> void:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var fake: FakeInput = player.input

	fake.move_axis = 1.0
	await _step(2)
	if player.facing != 1:
		errors.append("facing should be +1 moving right, got %d" % player.facing)

	fake.move_axis = -1.0
	await _step(2)
	if player.facing != -1:
		errors.append("facing should be -1 moving left, got %d" % player.facing)

	fake.move_axis = 0.0
	await _step(30)
	if player.facing != -1:
		errors.append("facing should persist when idle, got %d" % player.facing)
```

Register all five in `_main`.

- [ ] **Step 2: Run tests to verify they fail**

Run the test runner.
Expected: the five new tests FAIL — `velocity.x` never changes because no
horizontal code exists, and `max_run_speed` is undefined.

- [ ] **Step 3: Implement horizontal movement**

In `B/player_controller.gd`, add this export group directly above the existing
`@export_group("Jump")` block:

```gdscript
@export_group("Run")
## Top horizontal speed.
@export var max_run_speed: float = 260.0
## How fast speed builds on the ground. Higher = snappier, less icy.
@export var ground_acceleration: float = 1800.0
## How fast speed bleeds off on the ground when no direction is held.
@export var ground_friction: float = 2200.0
## Extra braking applied when the held direction opposes current motion,
## so turning around does not feel like skating.
@export var turn_brake_multiplier: float = 1.8
## Mid-air steering strength. Deliberately weaker than on the ground.
@export var air_acceleration: float = 1100.0
## Mid-air drag when no direction is held.
@export var air_friction: float = 700.0
```

Add the movement method after `_apply_gravity`:

```gdscript
func _apply_horizontal(delta: float, grounded: bool) -> void:
	var acceleration := ground_acceleration if grounded else air_acceleration
	var friction := ground_friction if grounded else air_friction

	if absf(input.move_axis) <= 0.01:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		return

	if signf(input.move_axis) != signf(velocity.x) and absf(velocity.x) > 1.0:
		acceleration *= turn_brake_multiplier

	velocity.x = move_toward(velocity.x, input.move_axis * max_run_speed,
		acceleration * delta)
	facing = 1 if input.move_axis > 0.0 else -1
```

Call it from `_physics_process` — the method becomes:

```gdscript
func _physics_process(delta: float) -> void:
	input.poll()
	just_landed = false

	_apply_horizontal(delta, is_on_floor())
	_apply_gravity(delta)

	var impact_speed := velocity.y
	move_and_slide()

	var grounded := is_on_floor()
	if grounded and not _was_grounded:
		just_landed = true
		landing_impact = clampf(impact_speed / max_fall_speed, 0.0, 1.0)
	_was_grounded = grounded
```

- [ ] **Step 4: Run tests to verify they pass**

Run the test runner.
Expected: `RESULT passed=11 failed=0`.

- [ ] **Step 5: Commit**

```bash
git add B/player_controller.gd tests/run_tests.gd
git commit -m "feat: add inertia-based horizontal movement with turn braking and air control"
```

---

## Task 5: Variable-height jump
## 任务 5: 可控高度跳跃

Holding the button jumps high; a quick tap gives a short hop. This single feature
is most of what separates a jump that feels good from one that feels robotic.

按住跳得高，轻点只是小跳。这一个特性基本决定了跳跃手感是舒适还是死板。

**Files:**
- Modify: `B/player_controller.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: everything from Task 4.
- Produces: `PlayerController` exports `jump_velocity: float` (positive magnitude,
  applied upward) and `jump_cut_multiplier: float`.
- Produces: state flag `just_jumped: bool`, true for the single frame of takeoff.

- [ ] **Step 1: Write the failing tests**

Add to `tests/run_tests.gd`:

```gdscript
## Presses jump for `hold_frames`, then releases, and returns the highest
## point reached (smallest y) measured from the starting height.
func _measure_jump_height(hold_frames: int) -> float:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var fake: FakeInput = player.input
	await _step(5)

	var start_y := player.global_position.y
	fake.jump_just_pressed = true
	fake.jump_held = true
	await _step(1)
	fake.clear_edges()

	for _i in range(hold_frames):
		await physics_frame
	fake.jump_held = false
	await _step(1)

	var highest := player.global_position.y
	for _i in range(180):
		await physics_frame
		highest = minf(highest, player.global_position.y)
		if player.is_on_floor():
			break
	return start_y - highest


func _test_jump_leaves_the_ground(errors: Array) -> void:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var fake: FakeInput = player.input
	await _step(5)
	if not player.is_on_floor():
		errors.append("setup failure: player should start grounded")
		return

	fake.jump_just_pressed = true
	fake.jump_held = true
	await _step(1)
	fake.clear_edges()

	if player.velocity.y >= 0.0:
		errors.append("expected upward velocity after jump, got %f" % player.velocity.y)
	await _step(3)
	if player.is_on_floor():
		errors.append("should have left the ground")


func _test_jump_reports_takeoff(errors: Array) -> void:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var fake: FakeInput = player.input
	await _step(5)
	fake.jump_just_pressed = true
	fake.jump_held = true
	await _step(1)
	if not player.just_jumped:
		errors.append("just_jumped should fire on the takeoff frame")


func _test_held_jump_goes_higher_than_tapped(errors: Array) -> void:
	var tapped: float = await _measure_jump_height(1)
	await _clear_world()
	var held: float = await _measure_jump_height(40)

	if tapped <= 0.0:
		errors.append("tap jump should still leave the ground, got %f" % tapped)
	if held <= tapped * 1.5:
		errors.append("held jump (%f) should clearly exceed tap jump (%f)"
			% [held, tapped])


func _test_jump_returns_to_ground(errors: Array) -> void:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var fake: FakeInput = player.input
	await _step(5)
	fake.jump_just_pressed = true
	fake.jump_held = true
	await _step(1)
	fake.clear_edges()

	var landed := false
	for _i in range(240):
		await physics_frame
		if player.just_landed:
			landed = true
			break
	if not landed:
		errors.append("player never came back down")
```

Register all five in `_main`.

- [ ] **Step 2: Run tests to verify they fail**

Run the test runner.
Expected: the five new tests FAIL — nothing reads `jump_just_pressed`, so the
player never leaves the ground.

- [ ] **Step 3: Implement the jump**

In `B/player_controller.gd`, add to the `@export_group("Jump")` block, above
`gravity_rise`:

```gdscript
## Upward launch speed, as a positive magnitude.
@export var jump_velocity: float = 740.0
## Letting go of the button mid-rise multiplies upward speed by this, cutting
## the jump short. Lower = bigger difference between a tap and a full hold.
@export var jump_cut_multiplier: float = 0.5
```

Add the state flags next to `just_landed`:

```gdscript
## True for the single physics frame on which the player left the ground.
var just_jumped: bool = false

var _jump_cut_pending: bool = false
```

Add the jump method after `_apply_horizontal`:

```gdscript
func _apply_jump(grounded: bool) -> void:
	if input.jump_just_pressed and grounded:
		velocity.y = -jump_velocity
		just_jumped = true
		_jump_cut_pending = true

	# Trim the arc the moment the button is no longer held, at most once per
	# jump. This tracks the button's *state* rather than its release edge: a
	# jump can fire after the release (see the buffer in Task 6), and an
	# edge-based cut would silently miss those and hand out a full-height jump
	# in response to a tap.
	if _jump_cut_pending:
		if velocity.y >= 0.0:
			_jump_cut_pending = false
		elif not input.jump_held:
			velocity.y *= jump_cut_multiplier
			_jump_cut_pending = false
```

Update `_physics_process` to clear the new flag and call the new method:

```gdscript
func _physics_process(delta: float) -> void:
	input.poll()
	just_landed = false
	just_jumped = false

	var grounded := is_on_floor()
	_apply_horizontal(delta, grounded)
	_apply_jump(grounded)
	_apply_gravity(delta)

	var impact_speed := velocity.y
	move_and_slide()

	var now_grounded := is_on_floor()
	if now_grounded and not _was_grounded:
		just_landed = true
		landing_impact = clampf(impact_speed / max_fall_speed, 0.0, 1.0)
	_was_grounded = now_grounded
```

- [ ] **Step 4: Run tests to verify they pass**

Run the test runner.
Expected: `RESULT passed=16 failed=0`.

- [ ] **Step 5: Commit**

```bash
git add B/player_controller.gd tests/run_tests.gd
git commit -m "feat: add variable-height jump with release cut"
```

---

## Task 6: Coyote time and jump buffering
## 任务 6: 土狼时间 + 跳跃缓冲

Two forgiveness windows. Without them a jump feels stiff and punishing even when
the gravity maths is perfect, because human timing is never frame-exact.

两个宽容窗口。没有它们，就算重力数值完全正确，跳跃依然显得死板难伺候 — 因为人的
手感永远精确不到帧。

**Files:**
- Modify: `B/player_controller.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: everything from Task 5.
- Produces: `PlayerController` exports `coyote_time: float`, `jump_buffer_time: float`.
- Changes: the jump trigger now consults the two timers instead of `grounded` directly.

- [ ] **Step 1: Write the failing tests**

Add to `tests/run_tests.gd`:

```gdscript
## A floor that stops at x = 0, so a player running right walks off its edge.
func _test_coyote_time_allows_late_jump(errors: Array) -> void:
	_make_floor(FLOOR_TOP, -2000.0, 0.0)
	var player := _spawn_player(Vector2(-100.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var fake: FakeInput = player.input
	fake.move_axis = 1.0

	var left_ground := false
	for _i in range(300):
		await physics_frame
		if not player.is_on_floor():
			left_ground = true
			break
	if not left_ground:
		errors.append("setup failure: player never walked off the ledge")
		return

	# Jump one frame after losing the floor — inside the coyote window.
	fake.jump_just_pressed = true
	fake.jump_held = true
	await _step(1)
	fake.clear_edges()

	if not player.just_jumped:
		errors.append("coyote time should permit a jump just after leaving the ledge")


func _test_coyote_time_expires(errors: Array) -> void:
	var player := _spawn_player(Vector2(0.0, -600.0))
	var fake: FakeInput = player.input
	# Fall for well over the coyote window with no ground anywhere.
	await _step(60)
	fake.jump_just_pressed = true
	fake.jump_held = true
	await _step(1)
	if player.just_jumped:
		errors.append("coyote time should have expired after a long fall")


func _test_jump_buffer_fires_on_landing(errors: Array) -> void:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT - 220.0))
	var fake: FakeInput = player.input

	# Press jump while still airborne but close to the ground, then release the
	# edge flag — the buffer must remember it until touchdown.
	var pressed := false
	for _i in range(300):
		await physics_frame
		var height_above := FLOOR_TOP - (player.global_position.y + COLLIDER_HALF_HEIGHT)
		if not pressed and height_above < 40.0:
			fake.jump_just_pressed = true
			fake.jump_held = true
			pressed = true
			continue
		if pressed:
			fake.clear_edges()
		if player.just_jumped:
			return  # buffered jump fired — success
		if player.is_on_floor() and not player.just_jumped:
			# Give the buffer one more frame to convert on touchdown.
			await physics_frame
			if player.just_jumped:
				return
			errors.append("buffered jump did not fire on landing")
			return
	if not pressed:
		errors.append("setup failure: never got close enough to the ground to press")
	else:
		errors.append("buffered jump never resolved")


## A buffered jump fires on a frame where the button is already released. The
## height cut must still apply, or a tap near the ground silently becomes a
## full-height jump.
func _test_buffered_tap_stays_short(errors: Array) -> void:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT - 220.0))
	var fake: FakeInput = player.input

	var pressed := false
	for _i in range(300):
		await physics_frame
		var height_above := FLOOR_TOP - (player.global_position.y + COLLIDER_HALF_HEIGHT)
		if not pressed and height_above < 40.0:
			# Tap: press and let go while still airborne.
			fake.jump_just_pressed = true
			fake.jump_held = true
			pressed = true
			continue
		if pressed:
			fake.clear_edges()
			fake.jump_held = false
		if player.just_jumped:
			await physics_frame
			var launch_speed := absf(player.velocity.y)
			var uncut := player.jump_velocity * 0.9
			if launch_speed >= uncut:
				errors.append("buffered tap launched at %f, should be cut well below %f"
					% [launch_speed, uncut])
			return
	errors.append("buffered tap never produced a jump")
```

Register all four in `_main`.

- [ ] **Step 2: Run tests to verify they fail**

Run the test runner.
Expected: `coyote time allows late jump`, `jump buffer fires on landing`, and
`buffered tap stays short` FAIL (the jump requires `grounded` on the exact
frame, so no buffered jump ever happens). `coyote time expires` may pass
already — that is fine, it is a guard against over-correcting in Step 3.

- [ ] **Step 3: Implement the forgiveness windows**

In `B/player_controller.gd`, add a new export group after the `Jump` group:

```gdscript
@export_group("Forgiveness")
## Grace period after walking off a ledge during which a jump still works.
@export var coyote_time: float = 0.10
## How long an early jump press is remembered and replayed on touchdown.
@export var jump_buffer_time: float = 0.12
```

Add the two timers next to `_was_grounded`:

```gdscript
var _coyote_timer: float = 0.0
var _buffer_timer: float = 0.0
```

Replace `_apply_jump` with a timer-driven version:

```gdscript
func _apply_jump(delta: float, grounded: bool) -> void:
	if grounded:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if input.jump_just_pressed:
		_buffer_timer = jump_buffer_time
	else:
		_buffer_timer = maxf(_buffer_timer - delta, 0.0)

	if _buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = -jump_velocity
		just_jumped = true
		_jump_cut_pending = true
		_buffer_timer = 0.0
		_coyote_timer = 0.0

	# Unchanged from Task 5, and this is exactly why it tracks jump_held rather
	# than a release edge: a buffered jump can fire on a frame where the button
	# was already let go, and the cut still has to apply.
	if _jump_cut_pending:
		if velocity.y >= 0.0:
			_jump_cut_pending = false
		elif not input.jump_held:
			velocity.y *= jump_cut_multiplier
			_jump_cut_pending = false
```

Update the call site in `_physics_process`:

```gdscript
	_apply_jump(delta, grounded)
```

- [ ] **Step 4: Run tests to verify they pass**

Run the test runner.
Expected: `RESULT passed=20 failed=0`.

- [ ] **Step 5: Commit**

```bash
git add B/player_controller.gd tests/run_tests.gd
git commit -m "feat: add coyote time and jump buffering"
```

---

## Task 7: Procedural squash, stretch, lean, and breathing
## 任务 7: 程序化压扁、拉伸、倾斜、呼吸

Bring the single static drawing to life with code only. Everything pivots at the
feet, so the character compresses into the ground rather than shrinking in place.

只用代码让这张静态图活过来。所有变形都以脚底为轴，所以角色是压向地面，
而不是原地缩小。

**Files:**
- Modify: `B/player_visuals.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `PlayerController` state `facing`, `velocity`, `just_landed`,
  `landing_impact`, `just_jumped`, `max_run_speed`, `is_on_floor()`.
- Produces: nothing other tasks depend on. This layer is purely cosmetic.

**Why rotation and flipping compose correctly:** Godot builds a Node2D's transform
as rotate-then-scale, so a negative `scale.x` mirrors the artwork without mirroring
the direction of `rotation`. Lean is driven by the sign of `velocity.x`, so it
tilts correctly whether the character faces left or right.

- [ ] **Step 1: Write the failing tests**

Add to `tests/run_tests.gd`:

```gdscript
func _test_visual_root_flips_with_facing(errors: Array) -> void:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var visual_root: Node2D = player.get_node("VisualRoot")
	var fake: FakeInput = player.input

	fake.move_axis = 1.0
	await _step(5)
	if visual_root.scale.x <= 0.0:
		errors.append("facing right should keep scale.x positive, got %f"
			% visual_root.scale.x)

	fake.move_axis = -1.0
	await _step(20)
	if visual_root.scale.x >= 0.0:
		errors.append("facing left should make scale.x negative, got %f"
			% visual_root.scale.x)


func _test_landing_squashes_then_recovers(errors: Array) -> void:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT - 400.0))
	var visual_root: Node2D = player.get_node("VisualRoot")

	var squashed := false
	for _i in range(240):
		await physics_frame
		if player.just_landed:
			await physics_frame
			if visual_root.scale.y < 0.95 and absf(visual_root.scale.x) > 1.02:
				squashed = true
			break
	if not squashed:
		errors.append("landing should squash: scale=%s" % str(visual_root.scale))
		return

	await _step(90)
	if absf(visual_root.scale.y - 1.0) > 0.05:
		errors.append("squash should recover, scale.y=%f" % visual_root.scale.y)


func _test_jump_stretches(errors: Array) -> void:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var visual_root: Node2D = player.get_node("VisualRoot")
	var fake: FakeInput = player.input
	await _step(5)

	fake.jump_just_pressed = true
	fake.jump_held = true
	await _step(2)
	if visual_root.scale.y <= 1.02:
		errors.append("jump should stretch vertically, scale.y=%f" % visual_root.scale.y)


func _test_running_leans_into_direction(errors: Array) -> void:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var visual_root: Node2D = player.get_node("VisualRoot")
	var fake: FakeInput = player.input

	fake.move_axis = 1.0
	await _step(60)
	var right_lean := visual_root.rotation

	fake.move_axis = -1.0
	await _step(90)
	var left_lean := visual_root.rotation

	if right_lean <= 0.0:
		errors.append("running right should lean clockwise, got %f" % right_lean)
	if left_lean >= 0.0:
		errors.append("running left should lean anticlockwise, got %f" % left_lean)


func _test_idle_breathes_without_drifting(errors: Array) -> void:
	_make_floor(FLOOR_TOP, -2000.0, 2000.0)
	var player := _spawn_player(Vector2(0.0, FLOOR_TOP - COLLIDER_HALF_HEIGHT))
	var visual_root: Node2D = player.get_node("VisualRoot")
	await _step(10)

	var lowest := visual_root.scale.y
	var highest := visual_root.scale.y
	for _i in range(150):
		await physics_frame
		lowest = minf(lowest, visual_root.scale.y)
		highest = maxf(highest, visual_root.scale.y)

	if highest - lowest < 0.005:
		errors.append("idle should breathe, range was %f" % (highest - lowest))
	if highest > 1.10 or lowest < 0.90:
		errors.append("breathing should stay subtle, range %f..%f" % [lowest, highest])
```

Register all five in `_main`.

- [ ] **Step 2: Run tests to verify they fail**

Run the test runner.
Expected: the five new tests FAIL — `player_visuals.gd` is still the Task 2 stub
and never touches `scale` or `rotation`.

- [ ] **Step 3: Implement the visuals**

Replace `B/player_visuals.gd` entirely:

```gdscript
class_name PlayerVisuals
extends Node2D

## Cosmetic layer. Reads PlayerController state and drives the sprite transform.
## Deleting this node changes nothing about physics.
##
## This node sits at the character's feet, so every scale and rotation here
## pivots there: the character compresses into the ground and leans from its
## soles, rather than deforming around its middle.

@export_group("Squash and stretch")
## Peak widen-and-flatten on the hardest possible landing.
@export var max_land_squash: float = 0.28
## Peak narrow-and-lengthen at the moment of takeoff.
@export var max_jump_stretch: float = 0.16
## How quickly a squash or stretch relaxes back to normal. Higher = snappier.
@export var squash_recovery: float = 11.0

@export_group("Lean")
## Maximum tilt into the direction of travel, at top speed.
@export var max_lean_degrees: float = 6.0
## Fraction of the ground lean applied while airborne.
@export var air_lean_scale: float = 0.5
## How quickly the lean follows changes in speed.
@export var lean_smoothing: float = 9.0

@export_group("Idle")
## Size of the standing-still breathing pulse.
@export var breath_amplitude: float = 0.015
## Breaths per second, roughly.
@export var breath_speed: float = 2.2
## Below this fraction of top speed the character counts as standing still.
@export var idle_speed_threshold: float = 0.05

var _player: PlayerController

## Positive = squashed (wider, shorter). Negative = stretched (narrower, taller).
var _squash: float = 0.0
var _lean: float = 0.0
var _breath_phase: float = 0.0


func _ready() -> void:
	_player = get_parent() as PlayerController


func _physics_process(delta: float) -> void:
	if _player == null:
		return

	_update_squash(delta)
	_update_lean(delta)
	var breath := _update_breath(delta)

	var horizontal := (1.0 + _squash) * float(_player.facing)
	var vertical := 1.0 - _squash + breath
	scale = Vector2(horizontal, vertical)
	rotation = _lean


func _update_squash(delta: float) -> void:
	if _player.just_landed:
		_squash = max_land_squash * _player.landing_impact
	elif _player.just_jumped:
		_squash = -max_jump_stretch
	# Frame-rate independent exponential relaxation back to neutral.
	_squash = lerpf(_squash, 0.0, 1.0 - exp(-squash_recovery * delta))


func _update_lean(delta: float) -> void:
	var speed_ratio := clampf(_player.velocity.x / maxf(_player.max_run_speed, 1.0),
		-1.0, 1.0)
	var target := deg_to_rad(max_lean_degrees) * speed_ratio
	if not _player.is_on_floor():
		target *= air_lean_scale
	_lean = lerpf(_lean, target, 1.0 - exp(-lean_smoothing * delta))


func _update_breath(delta: float) -> float:
	var speed_ratio := absf(_player.velocity.x) / maxf(_player.max_run_speed, 1.0)
	if not _player.is_on_floor() or speed_ratio > idle_speed_threshold:
		_breath_phase = 0.0
		return 0.0
	_breath_phase += delta * breath_speed
	return sin(_breath_phase) * breath_amplitude
```

- [ ] **Step 4: Run tests to verify they pass**

Run the test runner.
Expected: `RESULT passed=25 failed=0`.

If `landing squashes then recovers` fails narrowly, the landing squash is being
sampled a frame too late — check that `PlayerVisuals` runs after
`PlayerController` (it does by default, being a child node) rather than loosening
the test's thresholds.

- [ ] **Step 5: Commit**

```bash
git add B/player_visuals.gd tests/run_tests.gd
git commit -m "feat: add procedural squash, stretch, lean, and idle breathing"
```

---

## Task 8: Wire into the main scene and verify end to end
## 任务 8: 接入主场景并端到端验证

Replace the inline `CharacterBody2D` in `node_2d.tscn` with the new player scene.
This also fixes a real existing bug: the camera currently follows the body's
origin, which sits **293 px to the right** of where the character is actually
drawn, so the character has never been centred on screen.

用新的玩家场景替换 `node_2d.tscn` 里内联的 `CharacterBody2D`。这顺带修掉一个真实存在
的 bug: 摄像机现在跟的是 body 原点，而那个点在角色实际位置**右边 293 像素**，
所以角色从来就没在屏幕中间过。

**Files:**
- Modify: `node_2d.tscn` (lines 8829–8850 region, plus the ext_resource list and camera target)
- Delete: `B/simple_player.gd`, `B/simple_player.gd.uid`

**Interfaces:**
- Consumes: `res://B/player.tscn` from Task 2.
- Produces: a runnable main scene. Nothing downstream depends on it.

**Position arithmetic:** the old body sat at `(-1537, -132)` with its collider
offset to local `(-293.5, 89)`, putting the collider at world `(-1830.5, -43)`.
The new scene has its collider at local `(0, 0)`, so the instance goes directly at
**`(-1830.5, -43)`** to keep the character in exactly the same spot.

- [ ] **Step 1: Add the player scene as an ext_resource**

In `node_2d.tscn`, add this line to the `[ext_resource]` block near the top of the
file (after the last existing `ext_resource` line, before the first `[sub_resource]`):

```
[ext_resource type="PackedScene" path="res://B/player.tscn" id="20_player"]
```

Then increase the `load_steps` count in the `[gd_scene ...]` header line by 1.
(If the header has no `load_steps`, leave it alone — Godot recomputes it on save.)

- [ ] **Step 2: Replace the inline player node block**

Delete these lines from `node_2d.tscn` — the whole `CharacterBody2D` block and its
three descendants (currently lines 8829–8850, ending just before
`[node name="Parallax2D2" ...]`):

```
[node name="CharacterBody2D" type="CharacterBody2D" parent="." unique_id=658583964]
position = Vector2(-1537, -132)
script = ExtResource("4_d21ai")

[node name="CollisionShape2D" type="CollisionShape2D" parent="CharacterBody2D" unique_id=1127575017]
position = Vector2(-293.5, 89)
shape = SubResource("RectangleShape2D_jovdy")

[node name="57a36f8dae9e4b0f6519cadd30570ed5" type="Sprite2D" parent="CharacterBody2D" unique_id=1017535405]
modulate = Color(0.5211406, 0.5211406, 0.5211405, 1)
self_modulate = Color(0.8560673, 0.8560673, 0.85606724, 1)
position = Vector2(-290, 79.000015)
scale = Vector2(0.0868984, 0.0868984)
texture = ExtResource("4_kdubu")

[node name="PointLight2D" type="PointLight2D" parent="CharacterBody2D/57a36f8dae9e4b0f6519cadd30570ed5" unique_id=1120402369]
position = Vector2(-69.04614, 138.09212)
scale = Vector2(23.0498, 22.00711)
color = Color(0.92024887, 0.9172649, 0.9132015, 1)
energy = 2.41
texture = ExtResource("9_nr8wp")
texture_scale = 1.5
```

Replace them with:

```
[node name="Player" parent="." instance=ExtResource("20_player")]
position = Vector2(-1830.5, -43)
```

- [ ] **Step 3: Point the camera at the new node**

In the `Camera2D` node block near the top of the node list, change:

```
[node name="Camera2D" type="Camera2D" parent="." unique_id=365412144 node_paths=PackedStringArray("target")]
```
…leave that line as is, and change the target line from:

```
target = NodePath("../CharacterBody2D")
```

to:

```
target = NodePath("../Player")
```

- [ ] **Step 4: Remove the now-unused draft references**

Delete the two `ext_resource` lines for the old script and draft texture, which
nothing references any more:

```
[ext_resource type="Script" uid="uid://cjnxpn4xe7uxq" path="res://B/simple_player.gd" id="4_d21ai"]
[ext_resource type="Texture2D" uid="uid://bm82qw2k0srn3" path="res://C/57A36F8DAE9E4B0F6519CADD30570ED5.png" id="4_kdubu"]
```

Before deleting the texture line, confirm nothing else uses `ExtResource("4_kdubu")`:

```bash
grep -c '4_kdubu' node_2d.tscn
```

Expected: `2` (the definition plus the sprite you deleted in Step 2 — so after
Step 2 it should read `1`). If it reads higher, another node uses the draft
texture; leave the `ext_resource` line in place.

Then delete the old script file:

```bash
git rm B/simple_player.gd B/simple_player.gd.uid
```

- [ ] **Step 5: Write the end-to-end test**

Add to `tests/run_tests.gd` — this one loads the *real* main scene rather than a
synthetic floor:

```gdscript
func _test_main_scene_player_stands_on_real_ground(errors: Array) -> void:
	var packed: PackedScene = load("res://node_2d.tscn")
	if packed == null:
		errors.append("main scene failed to load")
		return
	var world: Node = packed.instantiate()
	get_root().add_child(world)

	var player := world.get_node_or_null("Player") as PlayerController
	if player == null:
		errors.append("main scene has no Player node of type PlayerController")
		return

	var camera: Camera2D = world.get_node("Camera2D")
	if camera.target != player:
		errors.append("camera should follow the Player node")

	await _step(180)
	if not player.is_on_floor():
		errors.append("player should settle on the tilemap, y=%f"
			% player.global_position.y)
		return

	# The tilemap's surface is at world y = 16.
	var feet := player.global_position.y + COLLIDER_HALF_HEIGHT
	if absf(feet - 16.0) > 1.5:
		errors.append("feet should rest on the tilemap surface (16), got %f" % feet)
```

Register it in `_main` as the last test.

- [ ] **Step 6: Run the full test suite**

Run the test runner.
Expected: `RESULT passed=26 failed=0`.

- [ ] **Step 7: Verify the whole project still imports cleanly**

Run:

```bash
"C:/Users/Administrator/Documents/Codex/2026-08-17/https-github-com-xiejinfan123-ops-superboy/work/repo/tools/Godot_v4.7.1-stable_win64_console.exe" --headless --path "C:/Users/Administrator/Documents/Codex/2026-08-17/https-github-com-xiejinfan123-ops-superboy/outputs/superBoy-git-main" --quit
```

Expected: exits without `SCRIPT ERROR` or `Failed to load` lines mentioning
`player`, `node_2d`, or `B/`. Pre-existing missing-resource errors about
`built_items/diamond.tscn` and `built_items/discoball.tscn` are known and unrelated
(they belong to the breakable-sprite add-on's sandbox scene) — leave them.

- [ ] **Step 8: Commit**

```bash
git add node_2d.tscn tests/run_tests.gd
git commit -m "feat: use the new player scene in the main scene and fix camera target"
```

- [ ] **Step 9: Hand over for the human feel test**

Report to the user that the controller is ready to play, and give them the import
path and the controls:

- Project folder to open in Godot: the project root above
- Controls: `A` / `D` or arrow keys to run, `Space` (or `W` / `Up`) to jump;
  hold jump for height, tap for a hop
- What to judge: does the run build up and settle naturally, does the jump feel
  weighty on the way down, does turning around feel responsive, does landing read
  as an impact
- Where to tune: select the `Player` node in the scene, and adjust the exported
  values under **Run**, **Jump**, and **Forgiveness**; select `VisualRoot` for
  **Squash and stretch**, **Lean**, and **Idle**

Feel tuning is iterative: expect to adjust `max_run_speed`, `jump_velocity`,
`gravity_fall`, and `max_land_squash` based on what the user reports.

---

## Deferred to later rounds (not in this plan)
## 留给后面轮次 (本计划不含)

- Cutting the character art into body / cape / arm layers for independent
  secondary motion. Needs image editing, so Codex is the better fit.
  把角色图切成身体/斗篷/手臂分层做独立摆动。需要改图，Codex 更合适。
- Dust and impact particles on landing and running.
  落地和跑动的尘土/冲击粒子。
- Footstep, jump, and landing sound effects.
  脚步/跳跃/落地音效。
- Actions beyond locomotion: attack, dash, interact.
  移动之外的动作: 攻击/冲刺/互动。
- Fixing the add-on's broken `breakable_sandbox.tscn` (two uncommitted scenes).
  修复插件里损坏的 `breakable_sandbox.tscn` (两个没提交的场景)。
