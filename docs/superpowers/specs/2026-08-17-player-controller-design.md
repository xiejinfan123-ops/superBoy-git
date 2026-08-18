# superBoy — Player Character Controller Design
# superBoy — 玩家角色控制器设计

Date: 2026-08-17
日期: 2026-08-17

Goal: a highly finished character. Movement, physics, and feel come first,
before levels, enemies, or UI.

目标: 高度完成的角色。移动、物理、手感优先，
关卡/敌人/UI 都排在后面。

---

## Scope
## 范围

Rebuild `B/simple_player.gd` (top-down WASD stub) into a full
side-scrolling platformer controller.

把 `B/simple_player.gd` (现在只是俯视角 WASD 占位代码) 重写成
完整的横版平台跳跃控制器。

Swap the player sprite from the draft (`C/57A36F8DAE9E4B0F6519CADD30570ED5.png`)
to the real design (`C/1786820354134.png`).

把玩家的图从草稿 (`C/57A36F8DAE9E4B0F6519CADD30570ED5.png`)
换成正式设计 (`C/1786820354134.png`)。

Not in this round: level design, enemies, UI, sound,
cut-up cape/arm layered animation (v2).

这轮不做: 关卡设计、敌人、UI、音效、
斗篷/手臂分层独立摆动 (二期)。

---

## 1. Movement physics
## 1. 移动物理

### Ground movement — inertia
### 地面移动 — 惯性

Acceleration toward top speed, not instant snap.
Friction decelerates on release, not a dead stop.
Turning around brakes faster than normal friction (snappy direction change).

按方向键逐渐加速到顶速，不是瞬间到顶。
松开靠摩擦减速，不是瞬间停死。
反向转身时刹车比普通摩擦快 (换向要跟手)。

### Jump — variable height
### 跳跃 — 可控高度

Hold jump = full height. Release early = cut jump short (Mario-style).
Rising gravity is lighter than falling gravity —
falls feel weighty, jumps feel floaty at the peak.

按住跳满高度，提前松手就矮跳 (马里奥式)。
上升时重力轻、下落时重力重 —
下落有分量感，顶点处有一瞬滞空感。

Falling speed is capped (terminal velocity) so long falls stay controllable.

下落速度有上限 (终端速度)，长距离下落不会失控。

### Feel forgiveness
### 手感宽容度

Coyote time: ~0.1s after walking off a ledge, jump still works.
Jump buffer: pressing jump slightly before landing still triggers on touch.

土狼时间: 走出边缘后约 0.1 秒内按跳仍然生效。
跳跃缓冲: 落地前一点点按跳，落地瞬间自动起跳。

### Air control
### 空中控制

Left/right steering mid-air, slightly weaker than ground acceleration.

空中可以左右调整，但加速度比地面稍弱。

### Input
### 输入

Proper input actions (move_left / move_right / jump) mapped to
A/D + Space, plus arrow keys. Replaces the raw KEY_W checks.

用正式的输入动作 (move_left / move_right / jump) 映射到
A/D + 空格，方向键也支持。替换掉现在写死的按键检查。

### Tuning
### 数值调参

All feel numbers (speeds, accelerations, gravity, jump velocity,
coyote/buffer windows) exposed as @export variables,
adjustable live in the Godot inspector without touching code.

所有手感数值 (速度/加速度/重力/跳跃力度/
土狼与缓冲窗口) 全部用 @export 暴露出来，
在 Godot 检查器里就能实时调，不用改代码。

---

## 2. Character art swap
## 2. 角色图更换

Player sprite becomes `C/1786820354134.png`, scaled and offset to fit
the existing 35 × 78.75 px collision box, feet on the box bottom.

玩家图换成 `C/1786820354134.png`，缩放和位置对齐
现有的 35 × 78.75 像素碰撞框，脚底贴框底。

Sprite flips horizontally to face movement direction.
The art faces right in the source image, so flip logic accounts for that.

图会水平翻转朝向移动方向。
原图是朝右的，翻转逻辑按这个基准来。

The copy of the same image in the background Parallax2D layer stays —
it is scenery, unrelated to the player.

背景 Parallax2D 图层里那张同图不动 —
那是布景，跟玩家无关。

The PointLight2D currently on the draft sprite moves to the new sprite.

现在挂在草稿图上的 PointLight2D 移到新图上。

---

## 3. Procedural animation (v1 — whole body)
## 3. 程序化动画 (第一版 — 整体身体)

All driven by code on the single sprite. No new art needed.

全部由代码驱动这一张图。不需要新美术。

- Landing squash: brief flatten on touchdown, harder landings squash more.
  落地压扁: 触地瞬间短暂压扁，落得越重压得越扁。

- Jump stretch: slight vertical stretch while rising fast.
  跳跃拉伸: 快速上升时轻微纵向拉长。

- Run lean: sprite tilts a few degrees into the movement direction.
  跑动倾斜: 朝移动方向倾斜几度。

- Idle breathing: standing still, a slow subtle scale pulse.
  待机呼吸: 站立不动时缓慢轻微的起伏。

- All transitions smoothed (lerp/tween), nothing snaps.
  所有过渡都做平滑 (插值)，不允许生硬跳变。

Squash/stretch pivots at the feet, so the character compresses
into the ground, not into mid-air.

压扁/拉伸以脚底为轴心，角色是压向地面，
不是悬空缩放。

---

## 4. Architecture
## 4. 结构

Two scripts, clean separation:

两个脚本，职责分开:

- `B/player_controller.gd` — physics + input + state
  (grounded / airborne rising / airborne falling).
  物理 + 输入 + 状态 (在地 / 上升 / 下落)。

- `B/player_visuals.gd` — reads the controller's state each frame,
  drives sprite flip, squash/stretch, lean, breathing.
  Purely cosmetic; deleting it changes nothing about physics.
  每帧读控制器状态，驱动翻转/压扁拉伸/倾斜/呼吸。
  纯视觉层；删掉它物理完全不受影响。

- `B/player_input.gd` — polls the input actions into plain fields, so tests
  can substitute a fake and drive the character deterministically.
  把输入动作读进普通字段，测试时可以换成假输入，确定性地驱动角色。

`simple_player.gd` is replaced by these. `camera_smooth.gd` is not modified.

`simple_player.gd` 被这三个替代。`camera_smooth.gd` 不改。

The player keeps its CharacterBody2D + CollisionShape2D shape, but moves out of
`node_2d.tscn` into its own `B/player.tscn`, instanced back into the main scene.

玩家保持 CharacterBody2D + CollisionShape2D 的结构，但从 `node_2d.tscn` 里搬出来，
独立成 `B/player.tscn`，再实例化回主场景。

Two refinements decided while planning, both revisions to this spec:

规划过程中定下的两处调整，都是对本文档的修订:

1. The collider moves to the body's origin. It currently sits at a local offset
   of (-293.5, 89), which makes every visual and pivot calculation awkward.
   碰撞框移到 body 原点。它现在偏移在 (-293.5, 89)，让所有视觉和轴心计算都很别扭。

2. The camera's target is repointed at the new player node. This fixes an
   existing bug: it currently follows the body origin, which sits 293 px to the
   right of where the character is actually drawn, so the character has never
   been centred on screen.
   摄像机目标改指向新的玩家节点。这修掉一个现存 bug: 它现在跟的是 body 原点，
   而那个点在角色实际位置右边 293 像素，所以角色从来没在屏幕中间过。

---

## 5. Verification
## 5. 验证

- Headless: all scripts pass `godot --check-only`; main scene loads
  with no new errors.
  无界面检查: 所有脚本通过语法检查；主场景加载无新增报错。

- Headless physics probe: scripted run confirms gravity pulls down,
  jump rises then falls, walk-off-ledge falls, coyote/buffer windows fire.
  无界面物理探针: 脚本化运行确认重力向下、跳跃先升后降、
  走出边缘会掉落、土狼/缓冲窗口生效。

- Human feel test: user (or via Codex) plays in the Godot editor
  with A/D + Space and judges comfort. Tuning iterates on
  @export values based on that feedback.
  真人手感测试: 用户在 Godot 编辑器里用 A/D + 空格实际玩，
  判断舒适度。根据反馈直接调 @export 数值迭代。

---

## Open items for later rounds
## 留给后面轮次的事项

- Cut character art into layers (body / cape / dangling arms)
  for independent secondary motion. Codex can help generate/cut art.
  把角色图切分层 (身体/斗篷/吊臂) 做独立摆动。
  美术生成/切图可以让 Codex 帮忙。

- Dust/impact particles on land and run.
  落地和跑动的尘土/冲击粒子。

- Sound effects for footsteps, jump, land.
  脚步/跳跃/落地音效。

- Actions beyond movement: attack, dash, interact — decide later.
  移动之外的动作: 攻击/冲刺/互动 — 以后再定。
