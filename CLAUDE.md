# superBoy — standing note for Claude Code
# superBoy — 给 Claude Code 的常驻说明

You are not working alone. Codex (gpt-5.5) also works on this project, same
Mac, often the same files. LEIVO runs each of you separately, one at a time —
you do not call Codex.

你不是一个人在做。Codex（gpt-5.5）也在这个项目上干活，同一台 Mac，
经常动同一批文件。LEIVO 分开运行你们俩，一次一个 —— 你不调用 Codex。

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
they won't tell you *why* Codex made a choice — Codex's raw reasoning is
readable:

**如果提交信息说得不够清楚** —— 提交信息通常很简短，不会告诉你 Codex
**为什么**这么选 —— Codex 的原始推理是可读的：

```bash
python3 tools/peer_log.py list codex
python3 tools/peer_log.py read codex --last
```

Deep requirement documents go in `docs/handoff/YYYY-MM-DD-topic.md`. Write
them as proposals, not orders, with a concrete acceptance test — a script
where possible, since the script is the real spec.

深度需求书放 `docs/handoff/YYYY-MM-DD-主题.md`。要写成建议而不是命令，
带具体的验收标准 —— 能做成脚本就做成脚本，因为脚本才是真正的规格。
