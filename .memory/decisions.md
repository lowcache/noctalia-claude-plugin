---
type: decisions
project: noctalia-claude-plugin
last_updated: 2026-06-26
status: active
---

# Architecture Decisions

## D1. Native Design, Not a v4 Port (2026-06-24)
**Decided:** Design new v5 plugins inspired by v4, do NOT port v4 claude-code-panel (ACP/QML, 100+ KB).
**Why:** v5 (niri/Wayland) requires rethinking. Shell is Claude's desktop senses + actuators, not chat-UI reimplementation. Porting fights v5's medium (no stdin to processes → no true ACP), rebuilds degraded copy, high effort for lower fidelity.
**Constrains:** No QML, no UI-heavy approach; favors IPC + ambient. Deferred: `/cc <task>` launcher (real TUI via runInTerminal); quick-ask one-shot panel; status/token widget; bidirectional MCP (teach Claude `noctalia msg` via `--append-system-prompt`).

## D2. Three-Layer Memory Model (2026-06-24)
**Decided:** Memory at three scales: `~/.claude/CLAUDE.md` (policy/static), global `~/.memory/` (cross-project learnings), project `.memory/` (per-repo editorial).
**Why:** Isolates policy (fast/permanent), shared patterns (global sweep), project specifics (reviewable diffs). File model (not DB): git history, diffability, human-readable, curator ownership, inbox protocol, append-only mistakes.md, flock safety, redaction. Low-volume durable facts.
**Constrains:** Each layer has distinct curator discipline; prevents monolithic blob. Membrane: ephemeral senses → `noctalia.state` (never memd); durable learnings → memd.

## D3. Backend-Normalization Seam (2026-06-24)
**Decided:** Fixed event vocabulary + `backend.invoke()`/`backend.parse()` layer. Ship v1 claude-only, route ALL agent work through one choicepoint. Future backends (ollama/local) swap via seam with zero call-site changes.
**Why:** Privacy couples to backend locality; design for local-first fallback. Load-bearing seam = event vocabulary: parser emits `{turn_start, text_delta, tool_start, tool_end, usage, needs_attention, turn_end, error}`. Pulse + transcript consume ONLY vocabulary, never raw stream-json.
**Constrains:** All actor/perceiver code through backend abstraction. Config: `default_backend="claude"` + one `backends.claude` block (flags: `{agentic,tools,streaming,local}`). No registry/loader/selector (YAGNI). Adding ollama later = one config block + one parser fn. Privacy ceiling: remote → low/medium perception; local (ollama) → high tier (screen/clipboard/files) gated by `local` flag.

## D4. Debt Tracking via CEILING Markers (2026-06-24)
**Decided:** Mark intentional shortcuts in code with `CEILING: <limit condition> | upgrade via <path>`.
**Why:** Shortcut-heavy work needs tracking; prevents quiet permanent debt.
**Constrains:** All shortcuts logged; `/debt` skill harvests before releases. No new store.
