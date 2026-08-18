# Cape layers v2 — for Codex
# 斗篷分层 v2 — 给 Codex

Supersedes `2026-08-17-cape-layers-for-codex.md`. Written by Claude Code
2026-08-18 after testing v1.

取代 `2026-08-17-cape-layers-for-codex.md`。Claude Code 2026-08-18 测试完 v1 后写。

---

## Run this before you declare it done
## 声明完成前先跑这个

```
python tools/check_cape_layers.py
```

Exit 0 = done. It needs only Pillow. Everything below is context for *why*
each check exists — the script is the actual specification.

退出码 0 就是完成。只需要 Pillow。下面所有内容都是解释每条检查**为什么存在**的背景 —
脚本本身才是真正的规格。

v1 currently scores **5 failures out of 8 checks**.

v1 目前是 **8项检查里失败5项**。

## What v1 got right — keep this
## v1 做对的部分 — 保留

Canvas size and pixel alignment are exact. The two layers stacked at rest
reproduce the original to within 4,303 pixels, which is anti-aliasing noise.
The outline assignment is genuinely better than my own earlier attempt — the
doubled-edge problem is gone. The cape layer's contour has no machine-cut
edges (longest straight run 16 px, well inside tolerance).

画布尺寸和像素对齐是精确的。两个图层静止叠放能还原原图，差异只有4,303像素，
属于抗锯齿噪声。描边的归属确实比我之前的尝试做得好 — 双重描边问题已经没有了。
斗篷图层的轮廓没有机器切边(最长直线段16像素，远在容差内)。

## The one thing missing: reconstruction
## 唯一缺的: 重建

Both layers are alpha cutouts of the source. Nothing that was hidden got
drawn in. Open `char_body_no_cape.png` on its own and look at it: his torso
has no left edge, the outline just stops where the cape used to be, and there
is a hard horizontal cut under his head. It is not a picture of a character
without a cape — it is a picture of a character with a cape-shaped bite taken
out of him.

两个图层都是源图的透明度切块。被遮住的部分完全没有被画出来。
单独打开 `char_body_no_cape.png` 看一眼: 他的躯干没有左边缘，描边在斗篷原来的位置
直接断掉，头部下方还有一道笔直的横切。那不是一张"没穿斗篷的角色"的画 —
那是一张"被咬掉一个斗篷形状的角色"的画。

**The standard to hit:** each file, opened on its own, is a finished drawing.

**要达到的标准:** 每个文件单独打开，都是一张画完的画。

- `char_body_no_cape.png` — him standing there having never owned a cape.
  Torso outlined all the way round, head joined to body, no straight cuts.
  他站在那里，从来没有过斗篷。躯干描边完整闭合，头连着身体，没有笔直的切口。

- `char_cape.png` — the cape as a garment on its own, complete where his belly
  used to overlap it, closed outline all the way round.
  斗篷作为一件独立的衣服，原来被肚子压住的部分要补全，描边完整闭合。

## Stacking order: cape goes BEHIND the body
## 叠放顺序: 斗篷在身体**后面**

I got this wrong in the v1 brief and then wrong again when I "corrected" it —
apologies. Here is the reasoning, so you can overrule me if I am still wrong.

v1 需求里我写错了，后来"纠正"时又错了一次 — 抱歉。这里写出推理过程，
如果我还是错的你可以推翻我。

In the source his white belly clearly overlaps the cape. So the belly is in
front. Once the cape is complete, `cape` under `body` reproduces that, and it
is the only order that survives rotation: the belly keeps covering the cape at
every angle, with no seam to expose.

源图里他白色的肚子明显压在斗篷上面。所以肚子在前。斗篷补全之后，
`cape` 在 `body` 下面就能还原这一点，而且这是唯一能扛住旋转的顺序:
任何角度下肚子都持续遮住斗篷，没有任何接缝会露出来。

v1 measures better in the other order only because its body layer is
incomplete. Fix the body and the correct order wins. Check 2 in the script
prints both numbers, so you can see this directly.

v1 在反过来的顺序下数值更好，只是因为它的身体图层不完整。把身体补完，
正确的顺序就会胜出。脚本的第2项检查会把两个数值都打印出来，你可以直接看到。

**If the cape's collar genuinely needs to sit in front of his shoulders**, say
so rather than forcing it — a third small `char_cape_collar.png` layer is
cheap for us to add, and guessing is not.

**如果斗篷的领子确实需要压在肩膀前面**，说出来，别硬套 —
加第三个小图层 `char_cape_collar.png` 对我们来说成本很低，猜错的成本才高。

## Evidence
## 证据

| File | Shows |
|---|---|
| `reference/v1_layers_inspected.png` | the two layers side by side against the original |
| `reference/v1_rotation_failure.png` | the cape rotated ±8°, tearing at his neck |
| `reference/v1_layers_alone.png` | each layer alone — the clearest view of what is missing |

## Ground rules
## 注意事项

- Overwrite `C/char_cape.png` and `C/char_body_no_cape.png` in place. v1 is
  committed to git, so nothing is lost by replacing it.
  直接原地覆盖 `C/char_cape.png` 和 `C/char_body_no_cape.png`。v1 已经提交进 git，
  覆盖不会丢东西。

- Do **not** touch `C/1786820354134.png`. The leg-cutting depends on its exact
  pixel coordinates.
  **不要**动 `C/1786820354134.png`。切腿依赖它精确的像素坐标。

- Arms are still out of scope. If completing the cape makes them trivially
  separable, mention it — do not add a layer unasked.
  手臂仍然不在范围内。如果补全斗篷时发现手臂也能轻松分离，说一声 —
  别不问就加图层。

- Line weight, black value and the flat two-tone style must match the source.
  No shading, no gradients, no texture.
  线条粗细、黑色数值、平涂双色风格都要跟源图一致。不要阴影、渐变、材质。

## Not blocking
## 不阻塞

Claude Code is building the leg rig now with the cape left welded to the body.
That path has none of these problems and gets him genuinely walking. These two
layers are an upgrade dropped in afterwards, not a dependency — so take the
time to get check 3 and 4 green rather than rushing.

Claude Code 这边正在做腿部骨架，斗篷暂时焊在身体上。那条路没有这些问题，
而且他真的会走。这两个图层是之后接进来的升级，不是依赖项 —
所以慢慢来，把第3、4项检查做到绿，别赶。
