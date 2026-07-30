#!/usr/bin/env python3
"""Emit a luau chunk that resolves noctalia.tr() from translations/en.json.

The spec suites assert rendered English ("Claude: idle", "Σ 1.2k in / …"), so the
harness needs a real tr(). Rather than hand-copy the strings into a prelude — which
would silently drift from en.json — the runner generates this chunk from en.json
itself on every run. The translations file is the single source of truth.

Unresolved keys raise instead of returning nil, so a typo'd or deleted key fails the
suite loudly at the call site rather than rendering an empty tooltip.

Usage: python3 tests/gen_tr_fixture.py <path-to-en.json>   (writes luau to stdout)
"""
import json
import sys


def flatten(node, prefix=""):
    """{"a": {"b": "x"}} -> {"a.b": "x"} — mirrors tr()'s dotted key form."""
    out = {}
    for key, value in node.items():
        dotted = f"{prefix}{key}"
        if isinstance(value, dict):
            out.update(flatten(value, dotted + "."))
        else:
            out[dotted] = value
    return out


def luau_string(s):
    escaped = (
        str(s)
        .replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )
    return f'"{escaped}"'


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: gen_tr_fixture.py <en.json>")
    with open(sys.argv[1], encoding="utf-8") as fh:
        table = flatten(json.load(fh))

    out = [
        "-- GENERATED at test time from translations/en.json by tests/gen_tr_fixture.py.",
        "-- Do not edit; edit the translations file instead.",
        "local __TR = {",
    ]
    for key in sorted(table):
        out.append(f"  [{luau_string(key)}] = {luau_string(table[key])},")
    out += [
        "}",
        "",
        "-- Mirrors noctalia.tr: dotted-key lookup plus {placeholder} interpolation.",
        "-- Raises on an unknown key so a bad key fails the spec at its call site.",
        "function __tr(key, args)",
        "  local s = __TR[key]",
        "  if s == nil then",
        '    error("tr: unresolved translation key \'" .. tostring(key) .. "\'", 2)',
        "  end",
        "  if type(args) == \"table\" then",
        "    for k, v in pairs(args) do",
        '      s = string.gsub(s, "{" .. tostring(k) .. "}", tostring(v))',
        "    end",
        "  end",
        "  return s",
        "end",
        "",
        "-- Every key present in en.json, for coverage assertions in the specs.",
        "__TR_KEYS = __TR",
        "",
    ]
    sys.stdout.write("\n".join(out))


if __name__ == "__main__":
    main()
