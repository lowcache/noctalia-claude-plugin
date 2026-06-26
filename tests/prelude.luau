-- Test prelude — stubs the noctalia widget API so pulse.luau runs headless.
-- Concatenated BEFORE pulse.luau (see nix/flake.nix mkRunner), so these globals
-- exist when the widget's top-level apply("idle") and onIpc definition execute.
-- The stubs record the last applied glyph/color/tooltip for the spec to assert on.

__tt = nil
__glyph = nil
__color = nil

barWidget = {
  setGlyph = function(g) __glyph = g end,
  setGlyphColor = function(c) __color = c end,
  setTooltip = function(t) __tt = t end,
}

-- watch() is invoked at load with ("cc.state", callback); the headless test
-- drives state through onIpc instead, so the registration is a no-op here.
noctalia = { state = { watch = function(_key, _cb) end } }

-- tiny assertion harness (full report, then non-zero exit via error()).
local failures = 0
function expect(label, got, want)
  if got ~= want then
    failures = failures + 1
    print(string.format("FAIL %s\n  got : %q\n  want: %q", label, tostring(got), tostring(want)))
  else
    print("ok   " .. label)
  end
end
function done()
  if failures > 0 then error(failures .. " test failure(s)", 0) end
  print("all specs passed")
end
