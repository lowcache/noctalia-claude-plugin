-- Specs for answer.luau — drive onOpen/update with staged claude.answer payloads
-- and walk the recorded ui tree (see tests/answer_prelude.luau for the stubs).

-- all label text in the rendered tree, depth-first
local function texts(node, out)
  out = out or {}
  if type(node) ~= "table" then return out end
  if node.type == "label" and type(node.props.text) == "string" then
    out[#out + 1] = node.props.text
  end
  for _, c in ipairs(node.children or {}) do texts(c, out) end
  return out
end
local function all_text() return table.concat(texts(__tree), "\n") end

-- first node of a type, depth-first
local function find(node, t)
  if type(node) ~= "table" then return nil end
  if node.type == t then return node end
  for _, c in ipairs(node.children or {}) do
    local hit = find(c, t)
    if hit then return hit end
  end
  return nil
end

-- 1. opened before any ask → placeholder, ticks armed for live refresh
onOpen("")
expect("open arms second ticks", __ticks, true)
expect("open renders once", __renders, 1)
contains("placeholder shown", all_text(), "No answers yet")
expect("open publishes visibility flag", __state["claude.answer.open"], true)
-- the root column must GROW to the panel height — without it the column takes
-- its natural (full-content) height, overflows, and the panel hard-clips the
-- answer with the scroll never engaging (the original clipping defect).
expect("root column grows to panel height", __tree.props.flexGrow, 1)

-- 2. an answer lands → next tick re-renders: question, timestamp, full text
__state["claude.answer"] = {
  q = "why is the sky blue",
  text = "Rayleigh scattering: shorter wavelengths scatter far more strongly.",
  error = false,
  at = "14:05",
}
update()
expect("tick re-renders on new answer", __renders, 2)
contains("question shown", all_text(), "why is the sky blue")
contains("timestamp shown", all_text(), "14:05")
contains("answer text shown", all_text(), "Rayleigh scattering")
local scroll = find(__tree, "scroll")
expect("body is scrollable", scroll ~= nil, true)
local body = find(scroll, "label")
expect("body lives in the scroll viewport", body ~= nil, true)
expect("normal answer keeps theme color", body.props.color, nil)
expect("body wraps (maxWidth set)", type(body.props.maxWidth), "number")

-- 3. unchanged state → tick is a no-op (an idle re-render would reset scroll)
update()
expect("no re-render when unchanged", __renders, 2)

-- 4. an error answer → body picks up the error accent
__state["claude.answer"] = { q = "broken ask", text = "ask failed", error = true, at = "14:06" }
update()
expect("tick re-renders on error answer", __renders, 3)
local ebody = find(find(__tree, "scroll"), "label")
expect("error answer gets the error accent", ebody.props.color, "#FF4D1F")

-- 5. closing clears the visibility flag (claude.luau falls back to the toast)
onClose()
expect("close clears visibility flag", __state["claude.answer.open"], false)

-- 6. reopening replays the latest answer immediately, no tick needed
onOpen("")
expect("reopen renders", __renders, 4)
contains("reopen shows the latest answer", all_text(), "ask failed")
expect("reopen republishes visibility flag", __state["claude.answer.open"], true)

done()
