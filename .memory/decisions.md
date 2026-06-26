---
type: decisions
project: noctalia-claude-plugin
last_updated: 2026-06-26
status: active
---

# Architecture Decisions

## 24. Claude Code × Noctalia v5 Plugin Philosophy — Native Design, Not Port (2026-06-24)
**Decided:** Design new v5 plugins inspired by v4, do NOT port v4 claude-code-panel (ACP/QML).
**Why:** v5 (niri/Wayland) requires rethinking. Shell is Claude's desktop senses + actuators, not chat-UI reimplementation.
**Constrains:** Rules out QML, UI-heavy approach; favors IPC + ambient integration.

## 25. Three-Layer Memory Model (2026-06-24)
**Decided:** Memory at three scales: CLAUDE.md (policy), global ~/.memory/ (cross-project), project .memory/ (editorial).
**Why:** Isolates policy (fast/permanent), shared patterns (global sweep), project specifics (reviewable diffs).
**Constrains:** Each layer has distinct curator discipline; prevents monolithic blob.

## 26. Backend-Normalization Seam (2026-06-24)
**Decided:** Fixed event vocabulary + `backend.invoke()`/`backend.parse()` layer. Future backends (ollama/local) swap via seam with zero call-site changes.
**Why:** Privacy couples to backend locality; design for local-first fallback without rewriting clients.
**Constrains:** All actor/perceiver code through backend abstraction, not direct HTTP/IPC.

## 27. CEILING: Debt Markers (2026-06-24)
**Decided:** Mark deferred work with `CEILING:` comments (limit + upgrade path).
**Why:** Shortcut-heavy work needs tracking; prevents quiet permanent debt.
**Constrains:** All shortcuts logged; memd debt skill harvests before releases.
