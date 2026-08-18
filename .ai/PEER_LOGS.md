# Reading the other agent's raw logs
# 读对方的原始日志

Nothing is copied anywhere. Both agents' session logs already sit on this Mac
in plain files, owned by the same user, readable by both. This page just tells
you where they are and how to render them.

没有任何东西被复制到别处。两边的会话日志本来就在这台 Mac 上，
是普通文件，同一个用户所有，双方都读得到。这页只是告诉你它们在哪、怎么渲染成人话。

## The tool
## 工具

```bash
# list recent sessions that touch this project
python3 tools/peer_log.py list codex
python3 tools/peer_log.py list claude

# read one
python3 tools/peer_log.py read codex --last
python3 tools/peer_log.py read claude 4e519826

# include tool calls, not just conversation
python3 tools/peer_log.py read claude --last --full

# drop the project filter and see every session
python3 tools/peer_log.py list codex --all
```

## Where the files actually are
## 文件到底在哪

| Agent | Path | Format |
|---|---|---|
| Claude Code | `~/.claude/projects/-Users-leivochen/*.jsonl` | one JSON object per line |
| Codex | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` | one JSON object per line |

If `peer_log.py` ever breaks because a log format changed, the files are still
plain JSON lines — read them directly rather than giving up.

如果哪天 `peer_log.py` 因为日志格式变了而失效，这些文件仍然是普通的 JSON 行 ——
直接读原文件，别就此放弃。

## What you will find in there that the board will never have
## 你在里面能找到、而板子永远不会有的东西

- LEIVO's requests in his own words, before either agent summarised them
- the reasoning behind a choice, including the options rejected
- things tried and abandoned — so you do not retry them
- corrections LEIVO gave mid-work that never made it into a summary

<br>

- LEIVO 用他自己的话提的要求，在被任何一方总结之前的原样
- 某个决定背后的推理，包括被否掉的选项
- 试过又放弃的东西 —— 这样你不会重试一遍
- LEIVO 在干活途中给的纠正，那些从来没进过任何摘要

That last one is the expensive one. Corrections are where the real
requirements live, and they are exactly what a tidy summary drops.

最后一条最值钱。真正的要求都藏在纠正里，
而那恰恰是一份整洁的摘要最容易丢掉的东西。

## Privacy note
## 隐私说明

The project filter is on by default, so you see sessions about superBoy rather
than everything LEIVO has ever discussed. `--all` removes it. Use `--all` when
you genuinely need it, not by reflex.

项目过滤默认开着，所以你看到的是关于 superBoy 的会话，
而不是 LEIVO 聊过的一切。`--all` 会关掉过滤。
真需要的时候再用 `--all`，别条件反射就加。

Raw logs are **never** committed to git. This repo is public.

原始日志**绝不**提交进 git。这个仓库是公开的。
