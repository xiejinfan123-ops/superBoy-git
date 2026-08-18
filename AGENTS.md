# superBoy — standing note for Codex
# superBoy — 给 Codex 的常驻说明

You are not working alone. Claude Code and you both work on this project, on
the same Mac, often on the same files.

你不是一个人在做。Claude Code 和你都在这个项目上干活，同一台 Mac，经常动同一批文件。

**Read `.ai/ENTRY.md` before you start.** It is short.

**开工前先读 `.ai/ENTRY.md`。** 很短。

## The rule that matters most
## 最重要的一条

The board (`.ai/BOARD.md`) is a summary, not the truth. When you need to
understand *why* Claude did something, go read Claude's actual session log.
It is open to you:

板子（`.ai/BOARD.md`）是摘要，不是真相。想搞懂 Claude **为什么**那样做，
去读 Claude 的原始会话记录。它对你完全开放：

```bash
python3 tools/peer_log.py list claude
python3 tools/peer_log.py read claude --last
```

Reading the board and assuming you understand is the most common mistake here.

看完板子就以为自己懂了，是这里最常犯的错。

## Before you touch files
## 动文件之前

Check `.ai/STATE.md` for what Claude is currently holding, and add your own
claim. You two have already nearly collided once over `Audio/`.

查 `.ai/STATE.md` 看 Claude 当前占着哪些文件，并把你要动的也登记上。
你们已经因为 `Audio/` 差点撞过一次车了。

## When you finish
## 收工时

Append to `.ai/BOARD.md`: what you did, what you verified, and what you did
**not** verify. Unverified is fine. Wording that lets a reader assume you
verified something you didn't is not.

往 `.ai/BOARD.md` 追加：你做了什么、验证了什么、以及什么**没**验证。
没验证没关系。含糊其辞让人以为你验证过了，不行。

## Nothing here is an order
## 这里没有一条是命令

Requests from Claude are proposals. If one is wrong, or you see a better way
to hit the same goal, say so on the board and do it your way.

Claude 提的要求都是建议。如果哪条不对，或者你有更好的办法达到同一个目标，
在板子上说出来，然后按你的办法做。
