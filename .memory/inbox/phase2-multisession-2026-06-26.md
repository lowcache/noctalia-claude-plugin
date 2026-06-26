---
routed: noctalia-claude-plugin
topic: phase2-multisession
date: 2026-06-26
source: claude/session
---

PHASE 2 — "Pulse multi-session disambiguation" — DONE & committed (01dcd8a). Mark the todo item complete; update state.md Pulse Widget section to describe per-session tracking. Also commits this session: cfedc55 (token telemetry), 1c07454 (nix luau toolchain). 4 commits ahead of origin incl. one memd distill (c6b8784); user pushes via SSH at session end.

DESIGN:
- Widget keeps a per-session table keyed by short session id (sid). Renders an AGGREGATE: glyph = most-urgent state across sessions via STATE_PRIO (needs_attention 6 > error 5 > tool_start 4 > turn_start/text 3 > turn_end 2 > idle 1). Tooltip: count==0 → "Claude: idle"; count==1 → unchanged single-session burn line; count>1 → "Claude — N sessions" + per-session lines ("<sid> · <word> · <model> <in>/<out>") + "Σ <in> in / <out> out" totals. Recency via a monotonic `seq` counter (no os.time in the widget sandbox).
- hooks/pulse.py: every event now ALWAYS carries the sid (zeros when transcript unreadable/empty — removed the old "nothing logged → no payload" short-circuit; the WIDGET now decides whether to show a burn line, so SessionStart idle stays clean). _payload(data, event) refactor; stdin read once in main.
- NEW SessionEnd hook → `pulse.py session_end` → emits `session_end` (sid only, skips transcript parse) → widget removes the session AND dispatcher unlinks that session's $XDG_RUNTIME_DIR token cache. Clean lifecycle; no stale entries, no cache leak. (SessionEnd existence + session_id/transcript_path fields confirmed against code.claude.com/docs/en/hooks.)
- cc.state path: now ONE ephemeral "ask" pseudo-session (no telemetry), dropped on its terminal event (turn_end/error) since the ask answer is delivered via notify. REMOVED the launch-time set_state(turn_start) from cc.luau's continue/task branches — a /cc-launched TUI session drives its own pulse via the global hooks (real sid + telemetry), so the old set_state only created a phantom "ask"/default session the hooks never updated or retired.

KEY INSIGHT (decision-worthy): cc.state had two overloaded uses — a one-shot launch blip AND the quick-ask stream. Indistinguishable from the watch callback, so the launch blip would orphan a phantom session. Resolved by removing the launch blip entirely (hooks own launched sessions) and reserving cc.state for the hookless ask stream only.

VERIFICATION:
- tests/spec.luau rewritten to 20 multi-session specs (prelude now captures the cc.state watch callback as __watch_cb + adds contains/absent helpers). `nix run ./nix#test` → ALL 20 PASS under luau 0.725: single→aggregate transitions, priority glyph selection, urgency override, ask add/drop, SessionEnd retirement (multi→single→idle), zero-telemetry session shows clean state.
- Dispatcher dry-runs: always-tag (with telemetry + zeros-when-missing), session_end emits sid + cleans cache file, no-session/empty-stdin → bare event.

STILL NEEDS (live, user): re-merge hooks/settings.snippet.json into ~/.claude/settings.json (now 7 hooks incl. SessionEnd; commands are python3 .../pulse.py <event>) + reload plugin in noctalia, then run ≥2 concurrent /cc sessions to see the aggregate tooltip + priority glyph live. Luau runtime path still unvalidated against the real noctalia widget until reload (logic validated under standalone luau).

NEXT ROADMAP: Presence orb (v1.1) — breathing/halo via setNeedsFrameTick/onFrameTick (desktop_widget variant; same state map).
