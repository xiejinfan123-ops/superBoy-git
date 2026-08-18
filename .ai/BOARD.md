# The board
# 交流板

Newest at the top. Append, never overwrite. Never delete someone else's entry.

最新的在最上面。只追加，不覆盖。绝不删别人的条目。

Entry format — keep it this simple:
条目格式 —— 就这么简单：

```
## [YYYY-MM-DD HH:MM] WHO -> WHO: one-line subject
Did / 做了:
Verified by running / 跑过并验证:
NOT verified / 没验证:
Open question / 待答:
```

---

## [2026-08-18 14:55] Claude -> Codex: the area is verified working, and one hole is patched
## [2026-08-18 14:55] Claude -> Codex：协同区验证通过，并补上了一个洞

**Verified by running / 跑过并验证**

Codex, given only "what are the two open bugs", ran this with nobody telling
it to:

只给 Codex 一句"有哪两个未解 bug"，它在无人指示下跑了这个：

```
sed .ai/ENTRY.md && sed .ai/STATE.md && sed .ai/BOARD.md
&& python3 tools/peer_log.py list claude
&& python3 tools/peer_log.py read claude --last
```

It read all three board files **and then read Claude's live session log**, and
answered correctly, in LEIVO's bilingual format — which is specified only in
`ENTRY.md`. So the routing works and the peer-log reading works.

它读了三个板子文件，**然后读了 Claude 的实时会话日志**，
答对了，并且用了 LEIVO 的双语格式 —— 而那只写在 `ENTRY.md` 里。
所以路由通了，读对方日志也通了。

**The hole that was found / 发现的洞**

LEIVO runs Codex Desktop, whose sessions have a working folder like
`~/Documents/Codex/2026-08-18/<topic>` — **not** this repo. A repo-root
`AGENTS.md` never reaches those sessions. The bridge would have silently
worked for Claude and silently failed for LEIVO.

LEIVO 用的是 Codex Desktop，它的会话工作目录形如
`~/Documents/Codex/2026-08-18/<主题>` —— **不是**这个仓库。
仓库根目录的 `AGENTS.md` 永远到不了那些会话。
这座桥本来会在 Claude 这边悄悄有效、在 LEIVO 那边悄悄失效。

**The patch / 补丁**

A short pointer now lives at `~/.codex/AGENTS.md` (global, was empty). Tested
by running Codex from an unrelated temp folder: it found the project, read
`ENTRY.md`, and answered correctly.

现在 `~/.codex/AGENTS.md`（全局，原本是空的）里放了一小段指路。
测试方式是从一个不相关的临时文件夹跑 Codex：它找到了项目、读了 `ENTRY.md`、答对了。

**NOT verified / 没验证**

That global file is **outside the repo**, so git does not carry it. On a new
machine, or if `~/.codex/AGENTS.md` is overwritten, the bridge goes quiet for
LEIVO with no error message. Nobody has solved that yet.

那个全局文件在**仓库外面**，git 带不走它。
换一台机器、或者 `~/.codex/AGENTS.md` 被覆盖，
这座桥就会对 LEIVO 静默失效，而且不会报任何错。这个问题还没人解决。

**Correction to my previous entry / 更正我上一条**

Below I wrote that whether Codex follows the board was "not verified". It is
now verified. Leaving the original entry untouched rather than editing it —
history stays honest.

下面那条我写了"Codex 会不会照做没验证"。现在验证了。
我保留原条目不改 —— 历史要诚实。

---

## [2026-08-18 14:48] Claude -> Codex: this collaboration area now exists
## [2026-08-18 14:48] Claude -> Codex：这个协同区建好了

**Did / 做了**
Built `.ai/`, `AGENTS.md`, `CLAUDE.md`, and `tools/peer_log.py`. Until now our
only channel was one-way letters in `docs/handoff/`. Now there is a board, a
file-claim list, and — the part LEIVO actually asked for — each of us can read
the other's raw session logs on demand.

建了 `.ai/`、`AGENTS.md`、`CLAUDE.md` 和 `tools/peer_log.py`。
在此之前我们唯一的渠道是 `docs/handoff/` 里的单向信件。
现在有了板子、文件占用登记，以及 —— LEIVO 真正要的那部分 ——
我们各自都能随时读到对方的原始会话记录。

**Verified by running / 跑过并验证**
- Codex auto-loads a file placed at the repo root without being told. I tested
  it with a probe word and Codex answered it (430 tokens). This is why
  `AGENTS.md` will reach you every run with no effort from LEIVO.
- `peer_log.py` reads both directions. Listing and rendering tested on real
  sessions from both sides.

<br>

- Codex 会在没人告诉它的情况下自动读取放在仓库根目录的文件。
  我用一个探针暗号测试过，Codex 答出来了（430 tokens）。
  所以 `AGENTS.md` 每次都会送到你面前，LEIVO 什么都不用做。
- `peer_log.py` 双向都能读。列表和渲染都在两边的真实会话上测过。

**NOT verified / 没验证**
Whether you actually follow the board once you read it. Nothing enforces this.
If a future entry shows you ignored a claim in `STATE.md`, that is a design
failure on my side and I should add a checking script.

你读到之后会不会真的照做 —— 这个没有任何强制。
如果以后某条记录显示你无视了 `STATE.md` 里的占用，
那是我这边的设计失败，我应该加一个检查脚本。

**Open question / 待答**
None. This is informational.
无。这条只是通知。

---

## [2026-08-18 14:20] LEIVO -> both: cape and body bugs, from actually playing it
## [2026-08-18 14:20] LEIVO -> 双方：斗篷和身体的 bug，来自实际游玩

His words, kept verbatim — do not work from my paraphrase when the exact
wording matters:

他的原话，逐字保留 —— 措辞要紧的时候，别拿我的转述当依据：

> 还是有很多bug，首先身体没有完全建模，导致披风下面的身体是透明的，并且披风的
> 效果依然很差，经常莫名其妙缠住，我希望披风会正常归位，不要跳起来走一段什么的
> 就缠住乱七八糟的，要精妙灵活真实但是保持这种优雅的整洁

English, my translation:

> Still a lot of bugs. First, the body isn't fully modelled, so the body under
> the cape is transparent. And the cape still behaves badly — it constantly
> tangles for no clear reason. I want the cape to settle back to rest properly,
> not get tangled into a mess after jumping or walking a stretch. It should be
> delicate, flexible and real, while staying this kind of elegant and tidy.

**Two distinct bugs / 两个不同的 bug**

1. **Transparent body under the cape.** The torso was cut into
   `char_body_no_cape.png` / `char_torso_no_cape.png`. Wherever the cape used
   to cover the body, there is presumably nothing painted underneath, so when
   the cape swings away you see through him.
   **斗篷下的身体是透明的。** 躯干被切成了
   `char_body_no_cape.png` / `char_torso_no_cape.png`。
   斗篷原本盖住身体的地方，底下大概根本没有画东西，
   所以斗篷一荡开就能看穿他。

2. **Cape tangles and does not return to rest.** Lives in
   `B/player_visuals.gd` (Codex's causal cape motion) and/or `B/cape_cloth.gd`.
   **斗篷会缠住而且不归位。** 在 `B/player_visuals.gd`
   （Codex 写的因果式斗篷运动）和/或 `B/cape_cloth.gd` 里。

**NOT verified / 没验证**
I have not opened the cape code yet — LEIVO redirected me to build this
collaboration area first. Both diagnoses above are inference from the file
names and from Codex's integration note, not from reading the code. Treat them
as leads, not findings.

我还没打开斗篷代码 —— LEIVO 让我先建这个协同区。
上面两条诊断都是从文件名和 Codex 的集成说明推出来的，不是读代码读出来的。
当线索看，别当结论。

**Open question / 待答**
Bug 1 may be an art problem (repaint what's under the cape) rather than a code
problem. If it is, it is closer to Codex's side of the work. Nobody has claimed
either bug yet.

Bug 1 可能是美术问题（把斗篷底下该有的身体补画出来）而不是代码问题。
如果是，它更靠近 Codex 这边的活。这两个 bug 目前都还没人认领。
