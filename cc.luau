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

-- ── backend seam: normalize at the boundary ──────────────────────────────────
-- Everything downstream consumes this vocabulary, never raw backend output.
local EVENT = {
  turn_start = "turn_start", text = "text", tool_start = "tool_start",
  tool_end = "tool_end", needs_attention = "needs_attention",
  turn_end = "turn_end", error = "error",
}

-- claude only. [CEILING]: no registry — add a backends table + a second parse()
-- branch when ollama/router lands; this is the seam, zero call-site change needed.
local function backend_command(prompt)
  -- Claude Code: -p (print/non-interactive) requires --verbose for stream-json.
  return "claude --output-format stream-json --verbose -p " .. shq(prompt)
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
    if type(content) == "table" then
      for _, block in ipairs(content) do
        if type(block) == "table" and block.type == "tool_use" then
          return { kind = EVENT.tool_start }
        end
      end
    end
    return { kind = EVENT.text }
  elseif t == "result" then
    local err = msg.is_error == true or msg.subtype == "error_during_execution"
    return { kind = err and EVENT.error or EVENT.turn_end, text = msg.result }
  end
  return nil
end

-- publish agent state for the pulse widget (cross-VM channel via shared state).
local function set_state(s) noctalia.state.set("cc.state", s) end

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
  if ask and ask ~= "" then
    launcher.setResults(query, {
      { id = "ask:" .. ask, title = "Ask Claude (one-shot)", subtitle = ask, glyph = "message-dots" },
    })
    return
  end
  launcher.setResults(query, {
    { id = "task:" .. text, title = "Launch Claude Code", subtitle = text, glyph = "robot" },
  })
end

function onActivate(id)
  if id == "continue" then
    set_state(EVENT.turn_start)
    noctalia.runInTerminal("claude --continue")
    return
  end
  local task = id:match("^task:(.*)$")
  if task then
    set_state(EVENT.turn_start)
    -- [CEILING]: env-context injection goes here via --append-system-prompt once the
    -- MCP shim can gather senses. Upgrade = prepend shim-gathered context.
    noctalia.runInTerminal("claude " .. shq(task))
    return
  end
  local ask = id:match("^ask:(.*)$")
  if ask then
    set_state(EVENT.turn_start)
    local answer = nil
    noctalia.runStream(backend_command(ask), function(line)
      local ev = parse(line)
      if not ev then return end
      set_state(ev.kind)
      if ev.text and ev.text ~= "" then answer = ev.text end
      if ev.kind == EVENT.turn_end then
        noctalia.notify("Claude", answer or "(no output)")
      elseif ev.kind == EVENT.error then
        noctalia.notifyError("Claude", answer or "ask failed")
      end
    end)
    return
  end
end
