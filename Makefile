# Offline gates for the plugin. Everything here runs without Noctalia; the live
# shell is where behaviour is confirmed, this is where syntax and contract are.
# Inside `nix develop` (or direnv) the tools are on PATH; otherwise use `nix flake check`.

LUAU := $(filter-out noctalia.d.luau,$(wildcard *.luau))
SPECS := $(wildcard tests/*_spec.py)

.PHONY: help check syntax fmt specs i18n

help:
	@echo "check      syntax + specs + i18n  (the gates)"
	@echo "syntax     luau-analyze every entry against noctalia.d.luau"
	@echo "fmt        stylua the entries in place -- NOT part of check, see DEVELOPMENT.md"
	@echo "specs      the Python spec suites"
	@echo "i18n       every tr()/label_key resolves in translations/en.json"

check: syntax specs i18n

syntax:
	@echo "== luau-analyze"
	@luau-analyze --definitions=noctalia.d.luau $(LUAU)

fmt:
	@stylua $(LUAU)

specs:
	@echo "== specs"
	@for s in $(SPECS); do echo "-- $$s"; python3 $$s || exit 1; done

# Catches the failure mode a linter cannot see: a tr() key or a manifest label_key
# with no entry in en.json renders as the raw key in the UI and nothing errors.
i18n:
	@echo "== i18n"
	@python3 scripts/check-i18n.py
