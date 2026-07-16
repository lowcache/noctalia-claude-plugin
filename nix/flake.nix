{
  description = "luau dev/test toolchain for the Claude Companion (noctalia Claude Code companion) plugin widgets (pulse.luau, orb.luau)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});

      # Headless spec runner: concatenates an API-stub prelude, the real widget
      # source, and the spec into one luau chunk and runs it. Operates on the
      # working tree at $1 (default $PWD) rather than a sealed flake copy, so it
      # tests the actual files you are editing — and sidesteps the fact that a
      # flake living under nix/ cannot reference ../pulse.luau for a pure check.
      # `files` is the ordered concat list (prelude, widget, spec).
      mkRunner =
        pkgs: name: files:
        pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = [ pkgs.luau ];
          text = ''
            root="''${1:-$PWD}"
            files=(${nixpkgs.lib.concatStringsSep " " files})
            for f in "''${files[@]}"; do
              if [ ! -f "$root/$f" ]; then
                echo "${name}: missing $root/$f (run from the repo root, or pass it as \$1)" >&2
                exit 2
              fi
            done
            tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
            : > "$tmp"
            for f in "''${files[@]}"; do cat "$root/$f" >> "$tmp"; done
            luau "$tmp"
          '';
        };

      pulseRunner =
        pkgs:
        mkRunner pkgs "pulse-test" [
          "tests/prelude.luau"
          "pulse.luau"
          "tests/spec.luau"
        ];
      orbRunner =
        pkgs:
        mkRunner pkgs "orb-test" [
          "tests/orb_prelude.luau"
          "orb.luau"
          "tests/orb_spec.luau"
        ];
      answerRunner =
        pkgs:
        mkRunner pkgs "answer-test" [
          "tests/answer_prelude.luau"
          "answer.luau"
          "tests/answer_spec.luau"
        ];

      # Runs every widget suite in turn; the program every entrypoint resolves to.
      allRunner =
        pkgs:
        pkgs.writeShellApplication {
          name = "widget-test";
          runtimeInputs = [
            pkgs.luau
            pkgs.python3
          ];
          text = ''
            root="''${1:-$PWD}"
            echo "── pulse ──";  "${pulseRunner pkgs}/bin/pulse-test" "$root"
            echo "── orb ──";    "${orbRunner pkgs}/bin/orb-test" "$root"
            echo "── answer ──"; "${answerRunner pkgs}/bin/answer-test" "$root"
            echo "── shim (compositor abstraction) ──"; python3 "$root/tests/shim_spec.py"
          '';
        };
    in
    {
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.luau
            (pulseRunner pkgs)
            (orbRunner pkgs)
            (answerRunner pkgs)
            (allRunner pkgs)
          ];
          shellHook = ''
            echo "luau toolchain ready. Run the widget specs:  widget-test   (all)"
            echo "                                              pulse-test    (bar dot only)"
            echo "                                              orb-test      (presence orb only)"
            echo "                                              answer-test   (answer panel only)"
          '';
        };
      });

      # `nix run ./nix#test` (or bare `nix run ./nix`) runs every widget suite.
      # `nix run ./nix#pulse` / `#orb` / `#answer` run a single suite.
      apps = forAll (
        pkgs:
        let
          all = allRunner pkgs;
        in
        {
          default = {
            type = "app";
            program = "${all}/bin/widget-test";
          };
          test = {
            type = "app";
            program = "${all}/bin/widget-test";
          };
          pulse = {
            type = "app";
            program = "${pulseRunner pkgs}/bin/pulse-test";
          };
          orb = {
            type = "app";
            program = "${orbRunner pkgs}/bin/orb-test";
          };
          answer = {
            type = "app";
            program = "${answerRunner pkgs}/bin/answer-test";
          };
        }
      );

      packages = forAll (pkgs: {
        pulse-test = pulseRunner pkgs;
        orb-test = orbRunner pkgs;
        answer-test = answerRunner pkgs;
        widget-test = allRunner pkgs;
      });
    };
}
