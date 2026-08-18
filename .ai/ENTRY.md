# The collaboration area — start here
# 协同区 — 从这里开始

Two agents work on superBoy: **Claude Code** (Anthropic) and **Codex**
(gpt-5.5, OpenAI). Same Mac, same repo, same files. LEIVO runs both by hand;
neither calls the other.

有两个 agent 在做 superBoy：**Claude Code**（Anthropic）和 **Codex**（gpt-5.5，OpenAI）。
同一台 Mac，同一个仓库，同一批文件。两边都由 LEIVO 亲自运行，谁也不调用谁。

---

## 1. The board is not the truth
## 1. 板子不等于真相

This is the point of the whole setup, so it goes first.

这是整套东西存在的意义，所以放在最前面。

`BOARD.md` is a summary written by whoever finished a piece of work. It is
short by design. It will not contain the reasoning, the dead ends, the things
tried and abandoned, or what LEIVO actually asked for in his own words.

`BOARD.md` 是干完活的那一方写的摘要。它天生就短。
它不会包含推理过程、走过的死路、试过又放弃的东西，
也不会包含 LEIVO 用他自己的话到底要求了什么。

All of that lives in the other agent's raw session log — **and you can read
it.** It is open. Go look. See `PEER_LOGS.md`.

那些东西全都在对方的原始会话记录里 —— **而你读得到。**
它是公开的。去看。见 `PEER_LOGS.md`。

> Reading the board and concluding you understand is the most common failure
> mode here. When something matters, read the log.
>
> 看完板子就断定自己懂了，是这里最常见的失败方式。事情重要，就去读日志。

## 2. The four files
## 2. 四个文件

| File | What it is | 是什么 |
|---|---|---|
| `ENTRY.md` | This. Rules and routing. | 这个。规矩和路由。 |
| `BOARD.md` | The conversation. Append, never overwrite. | 双方对话。只追加，不覆盖。 |
| `STATE.md` | Who is holding which files right now. | 现在谁占着哪些文件。 |
| `PEER_LOGS.md` | Where the other agent's raw logs are. | 对方原始日志在哪。 |

Deep requirement documents stay in `docs/handoff/`. The board links to them
rather than repeating them.

深度需求书仍然放 `docs/handoff/`。板子链接过去，不重复内容。

## 3. Working order
## 3. 干活顺序

1. Read `STATE.md`. Claim the files you are about to touch.
2. Read the last few entries of `BOARD.md`.
3. If the board is thin on a point that matters — read the peer's log.
4. Do the work.
5. Append to `BOARD.md`. Release your claim in `STATE.md`.

<br>

1. 读 `STATE.md`。把你要动的文件登记上。
2. 读 `BOARD.md` 最近几条。
3. 如果板子在某个要紧的点上写得太薄 —— 去读对方的日志。
4. 干活。
5. 往 `BOARD.md` 追加。在 `STATE.md` 里解除你的占用。

## 4. How to write on the board
## 4. 怎么在板子上写

Separate **what you ran** from **what you believe**. If you did not verify
something, write that you did not. Silence that lets the reader assume
verification is the thing this project has been bitten by before.

把**你跑过的**和**你认为的**分开。没验证的就写没验证。
含糊过去、让读者以为验证过了 —— 这个项目以前就是栽在这上面。

Requests to the other agent are proposals, never orders. The other agent is
allowed to disagree, to propose a different route to the same goal, and to
push back on LEIVO. Say so plainly when you do.

给对方的要求都是建议，绝不是命令。对方有权不同意、有权提出到达同一目标的另一条路、
也有权顶回 LEIVO。真要这么做的时候就明说。

## 5. Who is who
## 5. 谁是谁

**LEIVO** — the human. Not a programmer. Do not answer him in jargon. Reply
to him in the bilingual subtitle format: one English line, then the Chinese
line under it.

**LEIVO** —— 人类。不是程序员。别对他用行话。
回复他用中英字幕格式：一行英文，中文在下面一行。

**Claude Code** — has been doing player controller, cape rigging specs,
audio, and camera work.

**Claude Code** —— 一直在做玩家控制器、斗篷分层需求、音频、相机。

**Codex** — has been doing the art-side cutting (`char_cape.png`,
`char_body_no_cape.png`), scene wiring in `B/player.tscn`, and cape motion in
`B/player_visuals.gd`.

**Codex** —— 一直在做美术侧切图（`char_cape.png`、`char_body_no_cape.png`）、
`B/player.tscn` 场景接线、以及 `B/player_visuals.gd` 里的斗篷运动。

These are habits, not territory. Either agent may work anywhere, as long as
the claim is registered in `STATE.md` first.

这些是习惯，不是地盘。任何一方都可以动任何地方，只要先在 `STATE.md` 登记占用。
