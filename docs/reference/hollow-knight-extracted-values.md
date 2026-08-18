# Hollow Knight movement values — extracted from the shipped game
# 空洞骑士移动数值 — 从游戏本体提取

Extracted 2026-08-18 from the local Steam install
(`E:\SteamLibrary\steamapps\common\Hollow Knight`, Unity 6000.0.61f1 build)
using System.Reflection.Metadata on Assembly-CSharp.dll (field inventory and
ctor IL) and UnityPy with a DLL-generated typetree on resources.assets (the
serialized Knight prefab, path_id 3916). These are the real shipped numbers,
not community approximations.

2026-08-18 从本机 Steam 安装提取，工具: System.Reflection.Metadata 读 DLL +
UnityPy 用 DLL 生成 typetree 解析 resources.assets 里序列化的 Knight prefab。
是真实出厂数值，不是社区近似值。

## Raw values / 原始数值

| Field | Value | Where |
|---|---|---|
| RUN_SPEED | 8.3 u/s | HeroController prefab |
| RUN_SPEED_CH (sprintmaster) | 10.0 u/s | prefab |
| WALK_SPEED | 6.0 u/s | prefab |
| JUMP_SPEED (sustain velocity) | 16.65 u/s | prefab |
| JUMP_STEPS (max sustain) | 9 steps @50Hz = 0.18 s | prefab |
| JUMP_STEPS_MIN (min sustain) | 4 steps @50Hz = 0.08 s | prefab |
| MIN_JUMP_SPEED (release clamp) | 3.0 u/s | prefab |
| MAX_FALL_VELOCITY | 20.0 u/s | prefab |
| DASH_SPEED / DASH_TIME | 20 u/s, 0.25 s | prefab |
| WALLSLIDE_SPEED | 8.0 u/s | prefab |
| WJ_KICKOFF_SPEED (walljump) | 16.0 u/s | prefab |
| Physics2D gravity | -60 u/s² | globalgamemanagers |
| Rigidbody2D gravity scale | 0.79 → effective 47.4 u/s² | prefab |
| Knight collider | 0.5 × 1.28125 u | BoxCollider2D |
| LEDGE_BUFFER_STEPS (coyote) | 2 steps = 0.04 s | ctor IL |
| JUMP_QUEUE_STEPS (buffer) | 2 steps = 0.04 s | ctor IL |
| LANDING_BUFFER_STEPS | 5 steps = 0.10 s | ctor IL |
| Ground acceleration | none — velocity set directly | HeroController code |

## The jump is a SUSTAIN, not an impulse
## 跳跃是"维持"模型，不是冲量模型

While jumping with the button held, vertical velocity is pinned at JUMP_SPEED
every physics step, for at least 0.08 s and at most 0.18 s. Gravity only takes
over after the sustain ends. Releasing early (after the minimum) clamps any
remaining rise to MIN_JUMP_SPEED. Rise/fall asymmetry comes from this phase —
gravity itself is symmetric.

按住按钮跳跃期间，垂直速度每物理帧被钉在 JUMP_SPEED，最少 0.08 秒、最多 0.18 秒。
维持结束后重力才接管。提前松手(过了最短时间后)会把剩余上升速度压到
MIN_JUMP_SPEED。升降的不对称感来自这个阶段 — 重力本身是对称的。

## Conversion to superBoy / 换算到 superBoy

Knight body 1.28125 u ↔ our collider 78.75 px → **61.46 px per unit**.

| Quantity | HK | superBoy target |
|---|---|---|
| Run speed | 8.3 u/s | 510 px/s |
| Gravity | 47.4 u/s² | 2913 px/s² |
| Jump sustain speed | 16.65 u/s | 1023 px/s |
| Sustain window | 0.08–0.18 s | same (time is scale-free) |
| Release clamp | 3.0 u/s | 184 px/s |
| Fall cap | 20 u/s | 1229 px/s |
| Coyote / buffer | 0.04 s / 0.04 s | same |
| Full jump apex | ~5.9 u ≈ 4.6 body heights | ~364 px |
| Dash (future) | 20 u/s × 0.25 s | 1229 px/s × 0.25 s ≈ 307 px |

One deliberate deviation: HK sets run velocity with no ramp at all. We keep a
~0.09 s ramp (acceleration 6000 px/s²) as the Rain World side of the recipe —
crisp hands, weighty body. Raising ground_acceleration further approaches HK
exactly; this is a tuning knob, not a structural difference.

一处有意的偏离: HK 的跑速完全没有加速过程，直接设定。我们保留约 0.09 秒的加速
(6000 px/s²)作为配方里雨世界的那一半 — 手上干脆，身上有分量。把
ground_acceleration 再调大就无限接近 HK；这是调参旋钮，不是结构差异。
