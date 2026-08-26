{
  description = "Claude Companion — a Noctalia v5 plugin. Dev shell and offline checks.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # The whole toolchain the entries need. Nothing here runs Noctalia: every
        # check below is offline and hermetic, which is the point — the live shell
        # is where behaviour is confirmed, this is where syntax and contract are.
        toolchain = [
          pkgs.luau # luau-analyze: parse + typecheck the entries
          pkgs.stylua # format the entries
          pkgs.python3 # the hooks, the shim, and the spec suites
        ];

        # Entries only: noctalia.d.luau is INPUT to the analyser, not a target of it.
        luauFiles = "answer.luau ask.luau barpulse.luau claude.luau consent.luau orb.luau pulse.luau pulse-svc.luau sessions.luau";
      in
      {
        devShells.default = pkgs.mkShell {
          packages = toolchain ++ [ pkgs.luau-lsp ];
          shellHook = ''
            echo "claude-companion dev shell"
            echo "  make check   luau-analyze + specs + i18n"
            echo "  make fmt     stylua (opt-in; not a gate -- see DEVELOPMENT.md)"
          '';
        };

        # `nix flake check` runs all three. Each is its own derivation so a failure
        # names which gate broke instead of one opaque script.
        checks = {
          # Parse and typecheck every entry. The gate that did not exist when a call to a not-yet-declared local shipped
          # and took pulse-svc down on load. Verified to catch that exact shape: the
          # call resolves to an unknown global and luau-analyze exits non-zero.
          luau-analyze = pkgs.runCommand "luau-analyze" { buildInputs = [ pkgs.luau ]; } ''
            cd ${./.}
            luau-analyze --definitions=noctalia.d.luau ${luauFiles}
            touch $out
          '';

          i18n = pkgs.runCommand "i18n" { buildInputs = [ pkgs.python3 ]; } ''
            cd ${./.}
            python3 scripts/check-i18n.py
            touch $out
          '';

          specs = pkgs.runCommand "specs" { buildInputs = [ pkgs.python3 ]; } ''
            cd ${./.}
            for spec in tests/*_spec.py; do
              echo "== $spec"
              python3 "$spec" || exit 1
            done
            touch $out
          '';

          # luau-analyze proves the entries parse; this proves they run. The
          # suites are older than this check -- they were reachable only via
          # nix/flake.nix, so no gate ran them and `nix flake check` was green
          # over a widget that could not load.
          widget-specs =
            pkgs.runCommand "widget-specs"
              {
                buildInputs = [
                  pkgs.luau
                  pkgs.python3
                  pkgs.bash
                ];
              }
              ''
                cd ${./.}
                bash scripts/run-widget-specs.sh .
                touch $out
              '';
        };

        formatter = pkgs.nixfmt-tree;
      }
    );
}
