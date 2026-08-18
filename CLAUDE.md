# superBoy — standing note for Claude Code
# superBoy — 给 Claude Code 的常驻说明

You are not working alone. Codex (gpt-5.5) works on this project too, on the
same Mac, often on the same files. LEIVO runs Codex himself — you do not call
it. Everything you want Codex to know has to be written down where it will
find it.

你不是一个人在做。Codex（gpt-5.5）也在这个项目上干活，同一台 Mac，经常动同一批文件。
Codex 由 LEIVO 亲自运行 —— 你不调用它。所有你想让 Codex 知道的事，
必须写在它会找到的地方。

**Read `.ai/ENTRY.md` before you start.** It is short.

**开工前先读 `.ai/ENTRY.md`。** 很短。

## The rule that matters most
## 最重要的一条

The board (`.ai/BOARD.md`) is a summary, not the truth. When you need to
understand *why* Codex did something, go read Codex's actual session log.
It is open to you:

板子（`.ai/BOARD.md`）是摘要，不是真相。想搞懂 Codex **为什么**那样做，
去读 Codex 的原始会话记录。它对你完全开放：

```bash
python3 tools/peer_log.py list codex
python3 tools/peer_log.py read codex --last
```

Reading the board and assuming you understand is the most common mistake here.

看完板子就以为自己懂了，是这里最常犯的错。

## Before you touch files
## 动文件之前

Check `.ai/STATE.md` for what Codex is currently holding, and add your own
claim.

查 `.ai/STATE.md` 看 Codex 当前占着哪些文件，并把你要动的也登记上。

## When you write a request for Codex
## 给 Codex 写需求时

Deep specs go in `docs/handoff/YYYY-MM-DD-topic.md`; the board links to them.
Write requests as proposals, not orders, and say what the acceptance test is.
Where a check can be a script, make it a script — the script is the real spec.

深度需求书放 `docs/handoff/YYYY-MM-DD-主题.md`，板子链接过去。
需求要写成建议而不是命令，并写清验收标准是什么。
能做成脚本的检查就做成脚本 —— 脚本才是真正的规格。

## Honesty about verification
## 关于验证的诚实

On the board, separate what you ran from what you believe. If you did not run
it, say so.

在板子上，把"你跑过的"和"你认为的"分开写。没跑过就说没跑过。
