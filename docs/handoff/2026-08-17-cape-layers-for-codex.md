# Art task for Codex — split the cape onto its own layer
# 给 Codex 的美术任务 — 把斗篷分离成独立图层

Written by Claude Code, 2026-08-17. This is a request, not an order —
if you see a better way to hit the acceptance test, take it and say so.

Claude Code 写于 2026-08-17。这是需求不是命令 —
如果你有更好的办法满足验收标准，就用你的办法，并说明一下。

---

## What we are building
## 我们在做什么

The player character is being rigged as a cut-out puppet so he actually walks
instead of sliding. His legs are already cut and working — those were separated
by position (everything below the hip line), which is lossless and needs no art
work. The cape is the problem.

玩家角色正在被做成剪纸木偶式的骨架，让他真的走路而不是滑行。腿已经切好并且能用了 —
腿是按位置切的(胯线以下全归腿)，无损，不需要美术工作。问题出在斗篷。

## The problem: double outlines
## 问题: 双重描边

I tried separating the cape by colour. The cape's grey fill is RGB ~(55,55,55)
and the body is ~(253,253,253), so the fills separate cleanly. But the cape's
**black outline is RGB (0,0,0)** — identical to every other outline on the
character — so it stayed attached to the body layer. When the cape rotates, its
fill moves and its outline does not. You see both edges at once.

我尝试按颜色分离斗篷。斗篷灰色填充是 RGB ~(55,55,55)，身体是 ~(253,253,253)，
填充能干净分开。但斗篷的**黑色描边是 RGB (0,0,0)** — 跟角色身上其他描边完全一样 —
所以它留在了身体图层上。斗篷一转，填充动了、描边没动，两条边同时可见。

See `reference/ghosting_demo.gif` and `reference/ghosting_frames.png` —
watch the cape edge as it swings.

看 `reference/ghosting_demo.gif` 和 `reference/ghosting_frames.png` —
注意斗篷摆动时的边缘。

There is a second problem colour-sorting cannot solve: the body behind the cape
was never drawn. Move the cape and you expose a hole.

还有第二个颜色分拣解决不了的问题: 斗篷背后的身体从来没被画过。
斗篷一移开就露出空洞。

## Input
## 输入

```
C/1786820354134.png        2048 x 2048, RGBA, transparent background
```

Opaque content occupies x 350–1628, y 49–1984. The character faces right.

不透明内容位于 x 350–1628, y 49–1984。角色朝右。

## Required output
## 需要的产出

Two PNGs, both **2048 x 2048**, both **pixel-aligned to the input** (do not
crop, do not recentre — a pixel at (x,y) in the source must be at (x,y) here):

两张 PNG，都是 **2048 x 2048**，都要**与输入像素对齐**(不要裁剪、不要重新居中 —
源图 (x,y) 的像素在这里也必须在 (x,y)):

| File | Contents |
|---|---|
| `C/char_cape.png` | The cape only, **including the black outline that belongs to the cape**. Everything else fully transparent. |
| `C/char_body_no_cape.png` | The whole character **minus** the cape, with the body that the cape used to cover drawn in and its outline closed. Legs may stay attached — we cut those ourselves. |

## Acceptance test
## 验收标准

1. **Recomposition.** `char_cape.png` under `char_body_no_cape.png` must look
   like the original. Small anti-aliasing differences are fine.
   **重组**: `char_cape.png` 放在 `char_body_no_cape.png` 下层，合成后要跟原图一样。
   轻微的抗锯齿差异可以接受。

2. **Rotation, the one that actually matters.** Rotate `char_cape.png` by ±8°
   about roughly (1080, 950) and composite again. There must be **no hole in the
   body** and **no doubled outline**. This is the test the current colour-sorted
   version fails.
   **旋转，这条才是关键**: 把 `char_cape.png` 以大约 (1080, 950) 为中心旋转 ±8° 再合成。
   必须**身体上没有空洞**、**没有双重描边**。现在按颜色分拣的版本就是卡在这一条。

3. Line weight and style must match the original — same black, same thickness.
   He is a flat two-tone character, so this should not need shading.
   线条粗细和风格要跟原图一致 — 同样的黑、同样的粗细。
   他是平涂双色角色，不需要做阴影。

## Ground rules
## 注意事项

- Write only the two new files into `C/`. The repo is under git and everything
  else is committed work — please do not modify other files.
  只往 `C/` 里写这两个新文件。仓库有 git，其他都是已提交的成果，请不要改动别的文件。

- Do **not** overwrite `C/1786820354134.png`. It is the source of truth and the
  leg cutting script depends on its exact pixel coordinates.
  **不要**覆盖 `C/1786820354134.png`。它是唯一真实来源，切腿的脚本依赖它精确的像素坐标。

- The arms are thin lines drawn over both the body and the cape. They are **not**
  part of this task — we deliberately deferred them. If splitting the cape
  happens to make the arms easy to isolate too, mention it, but do not
  unilaterally add a third layer.
  手臂是画在身体和斗篷之上的细线。它们**不属于**本任务 — 我们有意推迟了。
  如果分离斗篷时顺带发现手臂也容易分出来，说一声，但别自作主张加第三个图层。

## Not blocking
## 不阻塞

Claude Code is building the leg rig now with the cape left attached to the body,
which produces zero ghosting and a character that genuinely walks. Dropping
these two layers in afterwards is a small follow-up, not a rework — so there is
no time pressure here. Getting the rotation test right matters more than speed.

Claude Code 这边正在做腿部骨架，斗篷暂时保持跟身体连在一起，这样零虚影而且角色真的会走。
之后把这两个图层接进来只是个小补丁，不是返工 — 所以不用赶时间。
把旋转那条验收做对，比快更重要。

## Full context if you want it
## 需要完整背景的话

The whole design conversation is in the Claude Code transcript at
`C:\Users\Administrator\.claude\projects\C--Users-Administrator\832b669e-e1ea-4e2e-8362-2d4632d9b06a.jsonl`
— but it is 4.6 MB of raw jsonl covering the entire player-controller build, so
read it only if this brief leaves something genuinely unclear.

完整的设计对话在 Claude Code 的记录里:
`C:\Users\Administrator\.claude\projects\C--Users-Administrator\832b669e-e1ea-4e2e-8362-2d4632d9b06a.jsonl`
— 但那是 4.6 MB 原始 jsonl，覆盖整个玩家控制器的开发过程，
只在这份需求真的有讲不清楚的地方时才去读。
