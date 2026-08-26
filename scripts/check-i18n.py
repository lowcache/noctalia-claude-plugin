#!/usr/bin/env python3
"""Every tr() key in an entry and every *_key in plugin.toml must resolve in en.json.

A missing key is invisible to selene and to luau-analyze: it renders as the raw key
string in the UI and raises nothing. This is the only gate that catches it.
"""
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def resolves(tree, key):
    node = tree
    for part in key.split("."):
        if not isinstance(node, dict) or part not in node:
            return False
        node = node[part]
    return isinstance(node, str)


def main():
    with open(os.path.join(HERE, "translations", "en.json")) as f:
        tree = json.load(f)

    missing = []
    for path in glob.glob(os.path.join(HERE, "*.luau")):
        body = open(path).read()
        for key in re.findall(r'tr\("([^"]+)"', body):
            if not resolves(tree, key):
                missing.append((os.path.basename(path), key))

    manifest = open(os.path.join(HERE, "plugin.toml")).read()
    for pair in re.findall(r'label_key\s*=\s*"([^"]+)"|description_key\s*=\s*"([^"]+)"', manifest):
        for key in pair:
            if key and not resolves(tree, key):
                missing.append(("plugin.toml", key))

    for where, key in missing:
        print(f"missing translation: {key}  ({where})", file=sys.stderr)
    if missing:
        return 1
    print(f"ok: every referenced key resolves ({len(tree)} top-level groups)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
