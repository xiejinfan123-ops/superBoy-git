# Audio task for Codex — footsteps, landing, jump
# 给 Codex 的音效任务 — 脚步、落地、起跳

Written by Claude Code, 2026-08-18. Separate from the cape task; they do not
depend on each other.

Claude Code 2026-08-18 写。跟斗篷任务无关，两者互不依赖。

---

## Why
## 背景

The project currently contains **zero** audio files. The player character walks,
jumps and lands in complete silence, which is the largest single reason the
movement feels lifeless. The trigger logic, timing and volume scaling are
already built on the Claude Code side and are waiting for files — drop them in
and they play.

项目现在**一个**音频文件都没有。角色走路、跳跃、落地全程无声，
这是移动感觉没有生气的最大单一原因。触发逻辑、时机和音量缩放在 Claude Code
这边已经做好了，就等文件 — 放进去就会响。

## What is needed
## 需要什么

Put them in a new `Audio/` folder at the project root.

放在项目根目录下新建的 `Audio/` 文件夹里。

| File | Fires when | Notes |
|---|---|---|
| `step_a.ogg` | a foot plants while walking | |
| `step_b.ogg` | ditto | a **different** take, not a copy |
| `step_c.ogg` | ditto | a third take |
| `land_soft.ogg` | landing from a short hop | |
| `land_hard.ogg` | landing from a full-height fall | heavier, more body to it |
| `jump.ogg` | leaving the ground | |

Three step takes because the rig plays one per footfall and he takes roughly
four steps per second at a run. A single repeated sample turns into a machine
gun almost immediately — that is the specific failure to avoid.

三个脚步版本，因为骨架每次落脚播一个，而他跑起来大约每秒四步。
单一样本重复播放会立刻变成机关枪 — 这正是要避开的失败模式。

## Character and style
## 角色和风格

He is a cartoon character in a flat black-and-white world: a big egg-shaped
head, a cape, thin stick legs with oversized flat feet. The tone is comic and
slightly sinister, not realistic.

他是一个平涂黑白世界里的卡通角色: 蛋形大头、斗篷、细杆腿配夸张的大扁脚。
调性是滑稽中带点阴森，不是写实。

So: light, dry, cartoonish. Think a soft slap or a muted thud from those flat
feet — **not** boots on gravel, not a foley-realistic footstep library. Short
and clean, no reverb tail, no music, no voice.

所以: 轻、干、卡通。想象那双扁脚发出的轻拍声或闷响 —
**不要**碎石上的靴子声，不要写实拟音素材库那种脚步。短促干净，
没有混响尾巴，没有音乐，没有人声。

## Technical
## 技术要求

- Format `.ogg` (Vorbis). Mono. 44.1 kHz.
  格式 `.ogg` (Vorbis)。单声道。44.1 kHz。
- Steps under 200 ms. Landing and jump under 400 ms.
  脚步 200 毫秒以内。落地和起跳 400 毫秒以内。
- **Trim silence from the head of every file.** Leading silence turns into
  audible lag against the footfall, and the timing is frame-accurate.
  **每个文件开头的静音都要剪掉。** 开头的静音会变成相对落脚的可听延迟，
  而触发时机是精确到帧的。
- Normalise to about -6 dBFS peak. Volume is scaled at runtime by walking
  speed and landing force, so ship them at a consistent level rather than
  pre-mixed to taste.
  峰值归一化到约 -6 dBFS。运行时会按行走速度和落地力度缩放音量，
  所以请交付统一电平，不要预先按感觉混好。
- The three step takes should differ in attack and timbre, not merely in
  pitch — a pitch-shifted copy still reads as repetition.
  三个脚步版本要在起音和音色上不同，不能只是变调 —
  变调的副本听起来仍然是重复。

## Ground rules
## 注意事项

- Only add files under `Audio/`. Everything else in the repo is committed
  working code — please do not modify it.
  只往 `Audio/` 里加文件。仓库里其他东西都是已提交的可运行代码，请不要改动。
- No need to touch any `.tscn` or `.gd` file. Wiring is already done on this
  side and will pick the files up by name.
  不需要碰任何 `.tscn` 或 `.gd` 文件。接线这边已经做好了，会按文件名接入。
- If a name above is inconvenient, say so rather than renaming silently — the
  paths are referenced in code.
  如果上面某个文件名不方便，说一声，别默默改名 — 这些路径在代码里被引用。

## Not blocking
## 不阻塞

Everything else in the movement polish is code and is going in now. Silence is
simply silence until these land — nothing breaks, the players just have no
stream assigned.

移动手感打磨的其他部分都是代码，现在就在做。这些文件到位之前就是没声音而已 —
不会出错，只是播放器没有指定音频流。
