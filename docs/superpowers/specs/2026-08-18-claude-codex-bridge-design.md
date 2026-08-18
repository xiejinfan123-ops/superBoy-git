# Claude ↔ Codex collaboration bridge — design
# Claude ↔ Codex 协作桥 — 设计

Date: 2026-08-18. Author: Claude Code. Status: built, verified, then simplified same day.

日期：2026-08-18。作者：Claude Code。状态：已建成、已验证，当天又做了简化。

**2026-08-18, later the same day — simplified.** The first version (below)
added `.ai/BOARD.md` and `.ai/STATE.md`: a hand-maintained conversation log
and a file-claim table. LEIVO pointed out this was solving a problem his
actual workflow doesn't have — he runs one agent at a time, never both at
once, and git already records what changed between sessions for free. Manual
board-keeping was overhead with no matching benefit. `.ai/` was removed.
What remains: `AGENTS.md` / `CLAUDE.md` telling each agent to run `git log`
and `git status` before touching anything, plus `tools/peer_log.py` for the
one thing git commit messages don't capture — the reasoning behind a choice.
Both of those are zero-maintenance: neither requires a human, or an agent, to
remember to write anything down.

**2026-08-18，当天晚些时候 —— 做了简化。** 最初版本（见下文）加了
`.ai/BOARD.md` 和 `.ai/STATE.md`：一份手动维护的对话记录和一张文件占用表。
LEIVO 指出这是在解决一个他实际工作方式里不存在的问题 —— 他一次只跑一个
agent，从不同时跑两个，而 git 本来就免费记着两次干活之间改了什么。
手动记板子是有成本没收益的事。`.ai/` 被删除。剩下的是：`AGENTS.md` /
`CLAUDE.md` 告诉每个 agent 动手前先跑 `git log` 和 `git status`，
以及 `tools/peer_log.py` 用来补上 git 提交信息给不了的那一样东西 ——
一个决定背后的原因。这两样都是零维护：不需要人、也不需要 agent 记得手写下什么。

---

*Everything below this line describes the first version, kept for the record
of what was tried and why it changed.*

*以下内容描述的是最初版本，保留下来作为"试过什么、为什么改"的记录。*

---

## The problem
## 问题

Two agents work on superBoy — Claude Code and Codex (gpt-5.5) — on the same
Mac, in the same repo, often on the same files. Before this, the only channel
between them was one-way letters in `docs/handoff/`: Claude wrote specs, Codex
wrote back a report. Neither could see how the other reasoned, and they had
already nearly collided over `Audio/` — Codex's integration note of 2026-08-18
records it deliberately not overwriting Claude's concurrent edits.

有两个 agent 在做 superBoy —— Claude Code 和 Codex（gpt-5.5）——
同一台 Mac、同一个仓库、经常动同一批文件。
在此之前它们之间唯一的渠道是 `docs/handoff/` 里的单向信件：
Claude 写需求，Codex 回报告。双方都看不到对方是怎么推理的，
而且已经因为 `Audio/` 差点撞车 —— Codex 2026-08-18 的集成说明里
记录了它刻意避开覆盖 Claude 同时在改的文件。

## What LEIVO asked for
## LEIVO 要的是什么

In his words: both sides should know they can see each other, that it is all
open, and should go look freely to understand each other better — **and not
assume that reading the board means they understand.**

他的原话：让双方知道他们都可以看到彼此，都是公开的，随意去查看，多去了解彼此，
**别只看板子就觉得懂完了。**

That last clause is the design constraint. It rules out a system where a tidy
summary substitutes for the raw record.

最后那句是设计约束。它排除了"用整洁摘要替代原始记录"的做法。

## Approaches considered
## 考虑过的方案

**A — copy both sides' logs into a shared folder.** Rejected: duplicates go
stale, and it would push LEIVO's unrelated personal conversations to OpenAI.
He explicitly said not to dump everything in.

**A —— 把双方日志复制进共享文件夹。** 否决：副本会过期，
而且会把 LEIVO 无关的私人对话推给 OpenAI。他明确说了不用全部丢进去。

**C — board only, no log access.** Rejected: this is precisely the failure
mode he named.

**C —— 只做板子，不给日志访问。** 否决：这正是他点名的那种失败。

**B — signposts, on demand. Chosen.** Nothing is copied. Each side knows where
the other's logs already sit, knows they are open, and reads them when it
matters.

**B —— 指路，按需读取。选定。** 什么都不复制。
双方知道对方日志本来在哪、知道是开放的、需要时去读。

## Architecture
## 架构

```
superBoy-git/
├── AGENTS.md              Codex auto-loads this when cwd is the repo
├── CLAUDE.md              Claude auto-loads this
├── .ai/
│   ├── ENTRY.md           rules + routing; carries the core norm
│   ├── BOARD.md           the conversation, append-only, newest on top
│   ├── STATE.md           who holds which files right now
│   └── PEER_LOGS.md       where the peer's raw logs live, how to read them
└── tools/peer_log.py      renders either side's raw sessions as plain text

~/.codex/AGENTS.md         global pointer — reaches Codex Desktop sessions
                           whose working folder is NOT the repo
```

Two doors into one room: each agent auto-reads only its own filename, and both
route to `.ai/ENTRY.md`.

两个门牌通向同一个房间：每个 agent 只会自动读自己那个文件名，两个都指向 `.ai/ENTRY.md`。

### `tools/peer_log.py`

One responsibility: turn either agent's raw session files into readable text.
It reads the logs in place and copies nothing.

单一职责：把任一 agent 的原始会话文件变成人能读的文字。就地读取，不复制。

| Side | Location | Format |
|---|---|---|
| Claude | `~/.claude/projects/-Users-leivochen/*.jsonl` | one JSON object per line |
| Codex | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` | one JSON object per line |

Both are owned by the same Unix user, so each side can already read the other's
files; the tool only handles rendering. Project filtering is on by default
(`--all` disables) so a reader sees superBoy sessions rather than everything
LEIVO has ever discussed. Malformed lines are skipped rather than fatal.

两边文件都属于同一个 Unix 用户，所以双方本来就读得到对方的文件；
工具只负责渲染。项目过滤默认开启（`--all` 关闭），
所以读者看到的是 superBoy 的会话而不是 LEIVO 聊过的一切。
格式损坏的行会跳过而不是崩溃。

## The core norm
## 核心规矩

Stated at the top of `ENTRY.md` and repeated in both door files:

写在 `ENTRY.md` 最前面，并在两个门牌文件里重复：

> The board is a summary, not the truth. When you need to understand *why* the
> other agent did something, read their actual session log. Reading the board
> and assuming you understand is the most common mistake here.
>
> 板子是摘要，不是真相。想搞懂对方**为什么**那样做，去读对方的原始会话记录。
> 看完板子就以为自己懂了，是这里最常犯的错。

`PEER_LOGS.md` names what the logs contain that a summary never will: LEIVO's
requests in his own words, rejected options, abandoned attempts, and
mid-work corrections. Corrections are where the real requirements live and are
exactly what a tidy summary drops.

`PEER_LOGS.md` 点明了日志里有而摘要永远没有的东西：
LEIVO 用自己的话提的要求、被否掉的选项、放弃的尝试、以及干活途中的纠正。
真正的要求都藏在纠正里，而那恰恰是整洁摘要最容易丢的。

## Collision prevention
## 防撞车

`STATE.md` holds a claims table: which files an agent is holding, since when,
and what for. Both sides claim on entry and release on exit. This is
discipline, not enforcement — no lock is taken.

`STATE.md` 有一张占用表：某个 agent 占着哪些文件、从什么时候起、干什么用。
双方开工时登记、收工时解除。这是纪律，不是强制 —— 没有加锁。

## Verification
## 验证

Everything below was run, not assumed.

以下每条都是跑出来的，不是假设的。

1. **Codex auto-loads a repo-root file.** A probe file with a secret word was
   placed at the repo root; Codex answered the word without being pointed at
   the file (430 tokens). Probe removed.
2. **`peer_log.py` reads both directions.** Listing and rendering tested
   against real sessions on both sides.
3. **Codex routes into the board unprompted.** Asked only "what are the two
   open bugs", Codex ran `sed .ai/ENTRY.md && sed .ai/STATE.md && sed
   .ai/BOARD.md && python3 tools/peer_log.py list claude && python3
   tools/peer_log.py read claude --last`, then answered correctly in the
   bilingual format that only `ENTRY.md` specifies.
4. **The global pointer works from outside the repo.** Codex run from an
   unrelated temp folder found the project, read `ENTRY.md`, and answered
   correctly.

<br>

1. **Codex 会自动读仓库根目录的文件。** 在仓库根目录放了一个含暗号的探针文件；
   没人指向该文件，Codex 就答出了暗号（430 tokens）。探针已删除。
2. **`peer_log.py` 双向可读。** 列表和渲染都在两边真实会话上测过。
3. **Codex 无需提示就会走进板子。** 只问"有哪两个未解 bug"，
   Codex 跑了上述命令链，然后用只写在 `ENTRY.md` 里的双语格式正确作答。
4. **全局指路在仓库外面也生效。** 从不相关的临时文件夹跑 Codex，
   它找到了项目、读了 `ENTRY.md`、答对了。

## Known weaknesses
## 已知弱点

**Nothing enforces compliance.** The design rests on auto-loaded files being
short enough to actually be followed. If a future board entry shows an agent
ignored a `STATE.md` claim, that is a design failure and a checking script
should be added.

**没有任何东西强制执行。** 整个设计依赖于自动加载的文件足够短、所以真的会被照做。
如果以后某条板子记录显示某个 agent 无视了 `STATE.md` 的占用，
那是设计失败，应该加一个检查脚本。

**`~/.codex/AGENTS.md` is outside the repo.** Git does not carry it. On a new
machine, or if that file is overwritten, the bridge goes quiet for LEIVO with
no error message. Unsolved.

**`~/.codex/AGENTS.md` 在仓库外面。** git 带不走它。
换机器、或该文件被覆盖，这座桥就会对 LEIVO 静默失效且不报错。未解决。

**Claude's repo-level `CLAUDE.md` is less reliable than Codex's `AGENTS.md`.**
Claude Code sessions here run with the home directory as cwd, so the repo file
is loaded when repo files are touched rather than guaranteed at session start.
A pointer in Claude's own memory index covers the gap.

**Claude 这边仓库级的 `CLAUDE.md` 不如 Codex 的 `AGENTS.md` 可靠。**
这里的 Claude Code 会话以主目录为工作目录，
所以仓库文件是在动到仓库文件时才加载，而不是会话一开始就保证加载。
在 Claude 自己的记忆索引里放一条指路来补这个缺口。

## What this deliberately does not change
## 刻意不动的东西

`docs/handoff/` remains the channel for deep requirement documents; the board
links to those rather than repeating them. Raw session logs are never
committed — this repo is public.

`docs/handoff/` 仍然是深度需求书的渠道；板子链接过去而不是重复内容。
原始会话日志绝不提交 —— 这个仓库是公开的。
