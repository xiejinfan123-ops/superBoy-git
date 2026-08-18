#!/usr/bin/env python3
"""Read the other agent's raw session logs.

Nothing is copied anywhere. This reads the logs where they already live and
prints them as plain text, so Claude can read Codex's sessions and Codex can
read Claude's.

  python3 tools/peer_log.py list codex
  python3 tools/peer_log.py list claude
  python3 tools/peer_log.py read codex --last
  python3 tools/peer_log.py read claude --last --full
  python3 tools/peer_log.py read codex 01a01392

By default only sessions that touch this project are listed. Pass --all to
drop that filter.
"""

import argparse
import json
import os
import sys
from datetime import datetime
from glob import glob

HOME = os.path.expanduser("~")
CODEX_ROOT = os.path.join(HOME, ".codex", "sessions")
CLAUDE_ROOT = os.path.join(HOME, ".claude", "projects")
PROJECT_MARKERS = ("superboy", "char_cape", "player_visuals", "cape_cloth")


def iter_lines(path):
    """Yield parsed JSON objects, skipping anything unparseable."""
    try:
        with open(path, "r", errors="replace") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    yield json.loads(line)
                except (ValueError, TypeError):
                    continue
    except OSError as err:
        print(f"  ! cannot read {path}: {err}", file=sys.stderr)


def flatten(content):
    """Anthropic/OpenAI content blocks -> plain text."""
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    out = []
    for block in content:
        if isinstance(block, str):
            out.append(block)
        elif isinstance(block, dict):
            if block.get("type") in ("text", "input_text", "output_text"):
                out.append(block.get("text", ""))
            elif block.get("type") == "tool_use":
                out.append(f"[tool: {block.get('name', '?')}]")
            elif block.get("type") == "tool_result":
                out.append("[tool result]")
    return "\n".join(part for part in out if part)


# --- Codex -------------------------------------------------------------


def codex_sessions():
    for path in glob(os.path.join(CODEX_ROOT, "**", "rollout-*.jsonl"), recursive=True):
        meta = {}
        for obj in iter_lines(path):
            if obj.get("type") == "session_meta":
                meta = obj.get("payload", {})
            break
        yield {
            "path": path,
            "id": meta.get("session_id", os.path.basename(path)),
            "cwd": meta.get("cwd", "?"),
            "mtime": os.path.getmtime(path),
        }


def codex_turns(path, full=False):
    for obj in iter_lines(path):
        kind = obj.get("type")
        payload = obj.get("payload", {})
        if not isinstance(payload, dict):
            continue
        stamp = obj.get("timestamp", "")
        if kind == "event_msg":
            sub = payload.get("type")
            if sub == "user_message":
                yield stamp, "LEIVO", payload.get("message", "")
            elif sub == "agent_message":
                yield stamp, "CODEX", payload.get("message", "")
        elif full and kind == "response_item" and payload.get("type") == "message":
            role = payload.get("role", "?").upper()
            yield stamp, role, flatten(payload.get("content"))


# --- Claude ------------------------------------------------------------


def claude_sessions():
    for path in glob(os.path.join(CLAUDE_ROOT, "*", "*.jsonl")):
        cwd = "?"
        for obj in iter_lines(path):
            if obj.get("cwd"):
                cwd = obj["cwd"]
                break
        yield {
            "path": path,
            "id": os.path.basename(path).replace(".jsonl", ""),
            "cwd": cwd,
            "mtime": os.path.getmtime(path),
        }


def claude_turns(path, full=False):
    for obj in iter_lines(path):
        kind = obj.get("type")
        if kind not in ("user", "assistant"):
            continue
        message = obj.get("message")
        if not isinstance(message, dict):
            continue
        text = flatten(message.get("content"))
        if not full:
            text = "\n".join(
                line for line in text.split("\n")
                if not line.startswith("[tool")
            )
        if text.strip():
            who = "LEIVO" if kind == "user" else "CLAUDE"
            yield obj.get("timestamp", ""), who, text


SIDES = {
    "codex": (codex_sessions, codex_turns),
    "claude": (claude_sessions, claude_turns),
}


def touches_project(session, turn_reader):
    if "superboy" in session["cwd"].lower():
        return True
    scanned = 0
    for _, _, text in turn_reader(session["path"]):
        low = text.lower()
        if any(marker in low for marker in PROJECT_MARKERS):
            return True
        scanned += 1
        if scanned > 250:
            break
    return False


def pick(sessions, wanted, use_last):
    if use_last:
        return sessions[0] if sessions else None
    for session in sessions:
        if session["id"].startswith(wanted):
            return session
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["list", "read"])
    parser.add_argument("side", choices=sorted(SIDES))
    parser.add_argument("session", nargs="?", default="")
    parser.add_argument("--last", action="store_true", help="most recent session")
    parser.add_argument("--all", action="store_true", help="skip the project filter")
    parser.add_argument("--full", action="store_true", help="include tool calls")
    parser.add_argument("--limit", type=int, default=15, help="how many to list")
    args = parser.parse_args()

    lister, turn_reader = SIDES[args.side]
    sessions = sorted(lister(), key=lambda s: s["mtime"], reverse=True)
    if not sessions:
        print(f"No {args.side} sessions found.")
        return 1

    if not args.all:
        kept = [s for s in sessions[:60] if touches_project(s, turn_reader)]
        if kept:
            sessions = kept
        else:
            print(f"(no {args.side} session mentions this project; showing all)\n")

    if args.command == "list":
        print(f"{args.side} sessions — newest first\n")
        for session in sessions[: args.limit]:
            when = datetime.fromtimestamp(session["mtime"]).strftime("%Y-%m-%d %H:%M")
            size = os.path.getsize(session["path"]) // 1024
            print(f"  {when}  {session['id'][:8]}  {size:>6}KB  {session['cwd']}")
        print(f"\nRead one:  python3 tools/peer_log.py read {args.side} <id>")
        return 0

    if not args.session and not args.last:
        print("Give a session id, or --last.")
        return 1

    session = pick(sessions, args.session, args.last)
    if session is None:
        print(f"No {args.side} session matching '{args.session}'.")
        return 1

    when = datetime.fromtimestamp(session["mtime"]).strftime("%Y-%m-%d %H:%M")
    print(f"=== {args.side} session {session['id'][:8]} — {when} ===")
    print(f"=== working folder: {session['cwd']} ===\n")

    spoken = 0
    for stamp, who, text in turn_reader(session["path"], full=args.full):
        if not text.strip():
            continue
        clock = stamp[11:16] if len(stamp) > 16 else ""
        print(f"--- {who} {clock} ---")
        print(text.strip())
        print()
        spoken += 1
    if spoken == 0:
        print("(nothing readable in this session)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
