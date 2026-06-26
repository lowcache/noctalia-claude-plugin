-- /cc — the hands: launch Claude Code, or a quick one-shot ask.
--   /cc <task>   → real Claude Code TUI in the terminal (full fidelity)
--   /cc          → resume last session (claude --continue)
--   /cc ? <q>    → one-shot read-only ask, streamed; answer via notify
--
-- Holds the BACKEND CHOKEPOINT (invoke + parse). v5 plugins load each entry as a
-- single chunk (no module system), and cc is the only entry that talks to a model,
-- so the seam lives here, inlined. [CEILING]: single-file inline; if a second entry
-- ever needs the backend, add a cat-concat deploy step rather than duplicating.

-- noctalia.runInTerminal / runStream both exec via `/bin/sh -c <string>`, so every
-- interpolated value must be shell-quoted. Single-quote wrap + escape embedded
-- single quotes ('\'') is sh-safe for arbitrary text.
local function shq(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- A double-quoted sh argument: unlike shq it lets the shell expand $VAR (we need
-- $HOME in the shim path so nothing user-specific is hardcoded). ONLY use this on
-- fixed, trusted strings — never on user input, which must go through shq().
local function dq(s) return '"' .. tostring(s):gsub('"', '\\"') .. '"' end

-- ── backend seam: normalize at the boundary ──────────────────────────────────
-- Everything downstream consumes this vocabulary, never raw backend output.
local EVENT = {
  turn_start = "turn_start", text = "text", tool_start = "tool_start",
  tool_end = "tool_end", needs_attention = "needs_attention",
  turn_end = "turn_end", error = "error",
}

-- noctalia launches us with the GUI-session PATH, which lacks ~/.local/bin (it's
-- added by the user's shell profile, not the graphical session). Claude Code's
-- own session hooks live there (memd, agent-scaffold, …), so a /cc session would
-- hit "command not found" that a terminal-started one never does. Prepend it to
-- every launch so a /cc session inherits the same PATH as a terminal. Fixed,
-- trusted literal — $HOME/$PATH are meant to expand in the `/bin/sh -c` context.
local PATH_PREFIX = 'PATH="$HOME/.local/bin:$PATH" '

-- claude only. [CEILING]: no registry — add a backends table + a second parse()
-- branch when ollama/router lands; this is the seam, zero call-site change needed.
local function backend_command(prompt)
  -- Claude Code: -p (print/non-interactive) requires --verbose for stream-json.
  return PATH_PREFIX .. "claude --output-format stream-json --verbose -p " .. shq(prompt)
end

-- one stream-json line → an EVENT (or nil). Claude Code emits one JSON object per
-- line: type "system" (init), "assistant" (a message; content is an array of
-- text / tool_use blocks), "user" (tool_result), "result" (final). We map the
-- subset we care about and ignore the rest (version-defensive).
-- [CEILING]: the content-block shape can shift across claude versions — if events
-- stop firing, re-dump a live stream and re-check the field names here.
local function parse(line)
  local ok, msg = pcall(noctalia.json.decode, line)
  if not ok or type(msg) ~= "table" then return nil end
  local t = msg.type
  if t == "system" then
    return { kind = EVENT.turn_start }
  elseif t == "assistant" then
    local content = type(msg.message) == "table" and msg.message.content or msg.content
    local text = ""
    if type(content) == "table" then
      for _, block in ipairs(content) do
        if type(block) == "table" then
          if block.type == "tool_use" then
            return { kind = EVENT.tool_start }
          elseif block.type == "text" and type(block.text) == "string" then
            text = text .. block.text
          end
        end
      end
    end
    return { kind = EVENT.text, text = text }
  elseif t == "user" then
    -- a tool result came back; the model is thinking again (clears tool_start)
    return { kind = EVENT.turn_start }
  elseif t == "result" then
    local err = msg.is_error == true or msg.subtype == "error_during_execution"
    return { kind = err and EVENT.error or EVENT.turn_end, text = msg.result }
  end
  return nil
end

-- publish quick-ask state for the pulse widget (cross-VM channel via shared
-- state). Only the hookless `/cc ? <q>` stream uses this; the widget tracks it as
-- one ephemeral "ask" session and drops it when the ask ends.
local function set_state(s) noctalia.state.set("cc.state", s) end

-- ── context injection ────────────────────────────────────────────────────────
-- Make /cc-launched sessions desktop-AWARE (senses) and desktop-CAPABLE (hands)
-- by wiring the noctalia MCP shim and a role note into the launch.
--
-- We pass the shim via inline --mcp-config (not a file) so the terminal's cwd is
-- irrelevant: /cc opens in the user's project dir, not the plugin dir. We push a
-- role note, NOT a senses snapshot — a snapshot taken at launch is stale before
-- the first turn; instead Claude pulls fresh senses on demand via the tools.
-- [CEILING]: shim assumed at the canonical install path
-- ($HOME/.local/share/noctalia/plugins/<id>); if noctalia exposes a plugin-dir to
-- luau, derive the path from that instead. $HOME stays bare for the shell to
-- expand (portable; nothing user-specific is committed). The JSON is fixed and
-- trusted (no user input), so dq() is injection-safe here.
local SHIM = "$HOME/.local/share/noctalia/plugins/claude/shim/noctalia-mcp.py"
local MCP_JSON = '{"mcpServers":{"noctalia":{"command":"python3","args":["' .. SHIM .. '"]}}}'

local SYSTEM_NOTE = table.concat({
  "You are running inside the Noctalia desktop shell (niri/Wayland), launched from its Claude Code companion plugin.",
  "An MCP server named 'noctalia' gives you live desktop senses and hands:",
  "PERCEIVE — get_window (focused app/title), get_workspace (focused output + workspace), get_media (now playing), get_shell_state (shell status), get_power (battery/AC), get_network (connectivity/Wi-Fi), get_processes (top by CPU).",
  "ACT — notify (desktop toast), set_theme_mode (dark/light/auto), set_color_scheme, focus_window (by niri id), switch_workspace (by index/name), move_to_workspace (move focused column), set_wallpaper (path or random).",
  "MEMORY — remember (persist a durable fact for future sessions).",
  "Call the perceive tools when current desktop context matters instead of assuming it, and use notify for ambient status updates.",
}, " ")

-- Flags shared by every interactive launch (task + continue). Built once.
local CONTEXT_FLAGS =
  "--mcp-config " .. dq(MCP_JSON) .. " --append-system-prompt " .. shq(SYSTEM_NOTE)

-- ── /cc routing ──────────────────────────────────────────────────────────────
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

function onQuery(query)
  local text = trim(query)
  if text == "" then
    launcher.setResults(query, {
      { id = "continue", title = "Resume last Claude session", glyph = "robot" },
    })
    return
  end
  local ask = text:match("^%?%s*(.*)$")
  if ask ~= nil then
    if ask == "" then
      launcher.setResults(query, {
        { id = "_askhint", title = "Ask Claude (one-shot)", subtitle = "Type a question after ?", glyph = "message-dots" },
      })
    else
      launcher.setResults(query, {
        { id = "ask:" .. ask, title = "Ask Claude (one-shot)", subtitle = ask, glyph = "message-dots" },
      })
    end
    return
  end
  launcher.setResults(query, {
    { id = "task:" .. text, title = "Launch Claude Code", subtitle = text, glyph = "robot" },
  })
end

function onActivate(id)
  -- A launched TUI session drives the pulse itself via the global Claude Code
  -- hooks (with its own session id + token telemetry), so we DON'T set cc.state
  -- here — doing so would register a phantom session the hooks never update or
  -- retire. cc.state is only for the hookless quick-ask stream below.
  if id == "continue" then
    noctalia.runInTerminal(PATH_PREFIX .. "claude " .. CONTEXT_FLAGS .. " --continue")
    return
  end
  local task = id:match("^task:(.*)$")
  if task then
    noctalia.runInTerminal(PATH_PREFIX .. "claude " .. CONTEXT_FLAGS .. " " .. shq(task))
    return
  end
  local ask = id:match("^ask:(.*)$")
  if ask then
    set_state(EVENT.turn_start)
    -- Accumulate streamed assistant text; the final `result` event also carries
    -- the full text, so prefer it at turn_end and fall back to the accumulation.
    local acc = ""
    noctalia.runStream(backend_command(ask), function(line)
      local ev = parse(line)
      if not ev then return end
      set_state(ev.kind)
      if ev.kind == EVENT.text and ev.text and ev.text ~= "" then
        acc = acc .. ev.text
      elseif ev.kind == EVENT.turn_end then
        local final = (ev.text and ev.text ~= "") and ev.text or acc
        noctalia.notify("Claude", final ~= "" and final or "(no output)")
      elseif ev.kind == EVENT.error then
        local final = (ev.text and ev.text ~= "") and ev.text or acc
        noctalia.notifyError("Claude", final ~= "" and final or "ask failed")
      end
    end)
    return
  end
  -- "_askhint" and any other ids: no-op.
end
