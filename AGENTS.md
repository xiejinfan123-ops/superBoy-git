# superBoy — standing note for Codex
# superBoy — 给 Codex 的常驻说明

You are not working alone. Claude Code also works on this project, same Mac,
often the same files. LEIVO runs each of you separately, one at a time.

你不是一个人在做。Claude Code 也在这个项目上干活，同一台 Mac，经常动同一批文件。
LEIVO 分开运行你们俩，一次一个。

**Before touching anything, run:**

**动手之前先跑：**

```bash
git log --oneline -15
git status
```

That tells you what changed since you last worked and whether anything is
mid-edit right now. Don't touch files `git status` shows as already modified
unless you know why they're modified.

这会告诉你自上次干活之后改了什么、现在有没有东西正改到一半。
`git status` 里显示已修改的文件，如果你不清楚为什么被改了，就别碰。

**If a commit message doesn't tell you enough** — commit messages are terse,
they won't tell you *why* Claude made a choice — Claude's raw reasoning is
readable:

**如果提交信息说得不够清楚** —— 提交信息通常很简短，不会告诉你 Claude
**为什么**这么选 —— Claude 的原始推理是可读的：

```bash
python3 tools/peer_log.py list claude
python3 tools/peer_log.py read claude --last
```

**Commit only the files you touched, named explicitly** — `git commit -- <files>`,
never a blanket `git add -A`. The other agent may have work staged or in the
tree; a blanket commit sweeps their files into your commit under your message.
This has already happened once (f64070a absorbed Claude's staged cape physics
into a camera commit).

**只提交你动过的文件，明确点名** —— `git commit -- <文件>`，
绝不要一揽子 `git add -A`。对方可能有工作在暂存区或工作区里；
一揽子提交会把他们的文件卷进你的提交、挂上你的信息。
这已经发生过一次（f64070a 把 Claude 暂存的披风物理卷进了一个相机提交）。

Requests from Claude in `docs/handoff/` are proposals, not orders. If one is
wrong, or you see a better way, say so and do it your way.

`docs/handoff/` 里 Claude 提的要求都是建议不是命令。如果哪条不对，
或者你有更好的办法，说出来，然后按你的办法做。
