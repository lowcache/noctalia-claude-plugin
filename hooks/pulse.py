#!/usr/bin/env python3
"""Pulse hook dispatcher (lowcache/claude plugin).

Bridges a Claude Code lifecycle hook to the pulse bar widget, enriching the
event with live model + token-burn telemetry parsed from the session transcript.
Invoked by the hooks in settings.snippet.json as:

    pulse.py <event>           # event name, e.g. turn_start / tool_start / ...

Hook JSON arrives on stdin (transcript_path, session_id). The widget is driven via
noctalia's documented plugin IPC (`noctalia msg --help`):

    noctalia msg plugin lowcache/claude:pulse all <event> [payload]

`[payload]` is a single positional token, so the payload is a SPACE-FREE CSV the
widget (pulse.luau) parses:

    model,in,out,cacheCreate,cacheRead,session

Token accounting is incremental: a per-session cache in $XDG_RUNTIME_DIR stores the
last byte offset + running sums, so each hook reads only newly-appended transcript
lines (O(delta), not O(whole transcript)). Transcript JSONL only appends; if it
ever shrinks (context compaction rewrites it), the cache resets.

Fail-open by contract: ANY error (no stdin, malformed transcript, noctalia offline)
still fires the bare event with no payload and never exits non-zero — a hook must
never block Claude or surface an error.

[CEILING]: token-only telemetry; dollar cost needs a per-model price table (drifts;
deferred). The `session` field is wire-ready for multi-session disambiguation (next
roadmap item) but the widget aggregates a single session for now.
"""
import json
import os
import subprocess
import sys

PLUGIN = "lowcache/claude:pulse"
TARGET = "all"


def _cache_path(session):
    base = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
    safe = "".join(c for c in session if c.isalnum() or c in "-_") or "nosession"
    return os.path.join(base, f"noctalia-pulse-{safe}.json")


def _accumulate(transcript, session):
    """Sum usage over newly-appended transcript lines since the last call."""
    cache = _cache_path(session)
    st = {"offset": 0, "in": 0, "out": 0, "cc": 0, "cr": 0, "model": ""}
    try:
        with open(cache) as f:
            st.update(json.load(f))
    except (OSError, ValueError):
        pass

    if os.path.getsize(transcript) < st["offset"]:  # shrank (compaction) → reset
        st = {"offset": 0, "in": 0, "out": 0, "cc": 0, "cr": 0, "model": ""}

    with open(transcript) as f:
        f.seek(st["offset"])
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                msg = (json.loads(line).get("message") or {})
            except ValueError:
                continue
            u = msg.get("usage")
            if not u:
                continue
            st["in"] += u.get("input_tokens", 0) or 0
            st["out"] += u.get("output_tokens", 0) or 0
            st["cc"] += u.get("cache_creation_input_tokens", 0) or 0
            st["cr"] += u.get("cache_read_input_tokens", 0) or 0
            if msg.get("model"):
                st["model"] = msg["model"]
        st["offset"] = f.tell()

    tmp = cache + ".tmp"
    try:
        with open(tmp, "w") as f:
            json.dump(st, f)
        os.replace(tmp, cache)
    except OSError:
        pass
    return st


def _payload():
    """Build the CSV payload, or None when there is nothing meaningful to show."""
    try:
        raw = sys.stdin.read()
        data = json.loads(raw) if raw.strip() else {}
    except (ValueError, OSError):
        data = {}
    transcript = data.get("transcript_path") or ""
    session = data.get("session_id") or ""
    if not transcript or not os.path.isfile(transcript):
        return None
    try:
        st = _accumulate(transcript, session)
    except OSError:
        return None
    # Nothing logged yet (e.g. SessionStart before the first turn) → no payload,
    # so the widget shows a clean state line instead of "? · 0 in / 0 out".
    if not st["model"] and (st["in"] + st["out"] + st["cc"]) == 0:
        return None
    model = (st["model"] or "").replace("claude-", "") or "?"
    short = session.split("-")[0] if session else ""
    return f"{model},{st['in']},{st['out']},{st['cc']},{st['cr']},{short}"


def main():
    event = sys.argv[1] if len(sys.argv) > 1 else "idle"
    payload = _payload()
    argv = ["noctalia", "msg", "plugin", PLUGIN, TARGET, event]
    if payload:
        argv.append(payload)
    if os.environ.get("NOCTALIA_PULSE_DRYRUN"):
        print(" ".join(argv))
        return
    try:
        subprocess.run(argv, capture_output=True, timeout=3)
    except Exception:  # noqa: BLE001 — noctalia offline/missing must stay silent
        pass


if __name__ == "__main__":
    main()
