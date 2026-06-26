#!/usr/bin/env python3
"""noctalia-mcp — stdio MCP shim bridging Claude Code <-> the Noctalia shell.

SENSES (shell -> Claude): query the env directly — niri msg, playerctl, /sys,
                          and `noctalia msg status` for shell-internal state.
HANDS  (Claude -> shell): `noctalia msg <action>` (request/response; reply on
                          stdout, "error:" prefix on failure). Desktop notifications
                          go through notify-send: noctalia exposes no generic notify
                          IPC (notifications are shell-internal / luau-only).

MCP transport: newline-delimited JSON-RPC 2.0 over stdio (one message per line,
no embedded newlines) — the stdio transport Claude Code speaks. Spawned by Claude
via --mcp-config; no daemon to babysit.

[CEILING]: prototype in Python to prove the bridge end-to-end; port to a Rust
`noctalia-mcp` for release. Tool set is the low/medium perception tier only —
high-tier senses (clipboard/screen/files) stay gated until a local backend lands
(privacy couples to model locality; see decision #26).
"""
import datetime
import json
import os
import re
import subprocess
import sys

PROTOCOL_VERSION = "2024-11-05"
SERVER_INFO = {"name": "noctalia-mcp", "version": "0.1.0"}


def sh(args, timeout=5):
    """Run argv (no shell), return stdout or an 'error: ...' string."""
    try:
        out = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return (out.stdout or out.stderr).strip()
    except Exception as e:  # noqa: BLE001
        return f"error: {e}"


def _remember(a):
    """Persist a durable fact to GLOBAL memory's inbox; memd distills ~/.memory.

    The membrane (decision #25): ephemeral senses -> noctalia.state; durable
    learnings -> global memd. This is the durable side. Notes are routed:global
    so memd's curator files them into the system-wide store, not a project."""
    # Coerce: a model may send a non-string (number/list) — str() keeps the
    # handler (and the server) from raising on .strip()/.lower().
    text = str(a.get("text") or "").strip()
    if not text:
        return "error: 'text' is required"
    slug = re.sub(r"[^a-z0-9]+", "-", str(a.get("topic") or "note").lower()).strip("-") or "note"
    inbox = os.path.expanduser("~/.memory/inbox")
    try:
        os.makedirs(inbox, exist_ok=True)
        ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        path = os.path.join(inbox, f"{ts}-{slug}.md")
        with open(path, "w") as f:
            f.write(
                f"---\nrouted: global\ntopic: {slug}\n"
                f"date: {datetime.date.today()}\nsource: noctalia-mcp/remember\n---\n\n"
                f"{text}\n"
            )
        return f"remembered -> {path}"
    except OSError as e:
        return f"error: {e}"


# name -> (description, inputSchema properties, handler). Commands verified against
# noctalia 5.0.0 (`noctalia msg --help`) and `niri msg --help`.
TOOLS = {
    # ── senses (low/medium tier) ──────────────────────────────────────────────
    "get_workspace": (
        "Focused niri output (connector, mode, current workspace) as JSON.",
        {},
        lambda a: sh(["niri", "msg", "-j", "focused-output"]),
    ),
    "get_window": (
        "Focused window (app_id/class and title) as JSON.",
        {},
        lambda a: sh(["niri", "msg", "-j", "focused-window"]),
    ),
    "get_media": (
        "Now-playing media (artist - title), or empty if nothing is playing.",
        {},
        lambda a: sh(["playerctl", "metadata", "--format", "{{artist}} - {{title}}"]),
    ),
    "get_shell_state": (
        "Noctalia shell-internal state (active panel, theme mode, etc.) as JSON.",
        {},
        lambda a: sh(["noctalia", "msg", "status"]),
    ),
    # ── memory (durable, cross-session) ───────────────────────────────────────
    "remember": (
        "Persist a durable fact, preference, or system detail to GLOBAL memory "
        "(system-wide, cross-project) so future sessions know it. Use for things "
        "true beyond the current task; memd distills it into ~/.memory.",
        {
            "text": {"type": "string", "required": True,
                     "description": "The durable fact/preference, 1-2 sentences."},
            "topic": {"type": "string",
                      "description": "Short kebab-case slug for the note (optional)."},
        },
        _remember,
    ),
    # ── hands ─────────────────────────────────────────────────────────────────
    "notify": (
        "Post a desktop notification.",
        {
            "title": {"type": "string", "description": "Notification title"},
            "body": {"type": "string", "description": "Notification body"},
        },
        lambda a: sh(["notify-send", a.get("title", "Claude"), a.get("body", "")]),
    ),
    "set_theme_mode": (
        "Set the shell light/dark mode.",
        {"mode": {"type": "string", "enum": ["dark", "light", "auto"]}},
        lambda a: sh(["noctalia", "msg", "theme-mode-set", a.get("mode", "auto")]),
    ),
    "set_color_scheme": (
        "Set the active color palette.",
        {
            "source": {
                "type": "string",
                "description": "builtin | wallpaper | community | custom",
            },
            "name": {"type": "string", "description": "Scheme name/id for that source"},
        },
        lambda a: sh(["noctalia", "msg", "color-scheme-set", a.get("source", "builtin"), a.get("name", "")]),
    ),
}


def _tool_list():
    tools = []
    for name, (desc, props, _fn) in TOOLS.items():
        # `required` is a control flag in our table, not a JSON Schema property
        # keyword — lift it to the object-level `required` array and strip it
        # from each property def so strict MCP validators accept the schema.
        clean = {k: {pk: pv for pk, pv in spec.items() if pk != "required"}
                 for k, spec in props.items()}
        tools.append({
            "name": name,
            "description": desc,
            "inputSchema": {
                "type": "object",
                "properties": clean,
                "required": [k for k, v in props.items() if v.get("required")],
            },
        })
    return tools


def _dispatch(method, params):
    """Return (result, error) for a request; result is None for notifications."""
    if method == "initialize":
        return {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {"tools": {}},
            "serverInfo": SERVER_INFO,
        }, None
    if method == "tools/list":
        return {"tools": _tool_list()}, None
    if method == "tools/call":
        name = params.get("name")
        args = params.get("arguments") or {}
        entry = TOOLS.get(name)
        if not entry:
            return None, {"code": -32602, "message": f"unknown tool: {name}"}
        try:
            text = entry[2](args if isinstance(args, dict) else {})
        except Exception as e:  # noqa: BLE001 — a tool bug must not crash the server
            return None, {"code": -32603, "message": f"tool '{name}' failed: {e}"}
        is_error = isinstance(text, str) and text.startswith("error:")
        return {"content": [{"type": "text", "text": str(text)}], "isError": is_error}, None
    return None, {"code": -32601, "message": f"method not found: {method}"}


def _emit(out, payload):
    out.write(json.dumps(payload) + "\n")
    out.flush()


def main():
    out = sys.stdout
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError:
            _emit(out, {"jsonrpc": "2.0", "id": None,
                        "error": {"code": -32700, "message": "parse error"}})
            continue
        if not isinstance(req, dict):
            _emit(out, {"jsonrpc": "2.0", "id": None,
                        "error": {"code": -32600, "message": "invalid request"}})
            continue
        mid = req.get("id")
        method = req.get("method", "")
        # Notifications (no id) — e.g. notifications/initialized: ack by ignoring.
        if mid is None:
            continue
        try:
            result, error = _dispatch(method, req.get("params") or {})
        except Exception as e:  # noqa: BLE001 — never let a handler kill the loop
            result, error = None, {"code": -32603, "message": f"internal error: {e}"}
        resp = {"jsonrpc": "2.0", "id": mid}
        if error is not None:
            resp["error"] = error
        else:
            resp["result"] = result
        _emit(out, resp)


if __name__ == "__main__":
    main()
