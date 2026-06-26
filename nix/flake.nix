{
  description = "luau dev/test toolchain for the noctalia-claude plugin widgets (pulse.luau et al.)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});

      # Headless test runner: concatenates the API stub prelude, the real widget
      # source, and the spec into one luau chunk and runs it. Operates on the
      # working tree at $1 (default $PWD) rather than a sealed flake copy, so it
      # tests the actual files you are editing — and sidesteps the fact that a
      # flake living under nix/ cannot reference ../pulse.luau for a pure check.
      mkRunner =
        pkgs:
        pkgs.writeShellApplication {
          name = "pulse-test";
          runtimeInputs = [ pkgs.luau ];
          text = ''
            root="''${1:-$PWD}"
            for f in tests/prelude.luau pulse.luau tests/spec.luau; do
              if [ ! -f "$root/$f" ]; then
                echo "pulse-test: missing $root/$f (run from the repo root, or pass it as \$1)" >&2
                exit 2
              fi
            done
            tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
            cat "$root/tests/prelude.luau" "$root/pulse.luau" "$root/tests/spec.luau" > "$tmp"
            luau "$tmp"
          '';
        };
    in
    {
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.luau
            (mkRunner pkgs)
          ];
          shellHook = ''
            echo "luau toolchain ready. Run the widget specs:  pulse-test   (from the repo root)"
          '';
        };
      });

      # `nix run ./nix#test` from the repo root runs the widget specs.
      apps = forAll (
        pkgs:
        let
          runner = mkRunner pkgs;
        in
        {
          default = {
            type = "app";
            program = "${runner}/bin/pulse-test";
          };
          test = {
            type = "app";
            program = "${runner}/bin/pulse-test";
          };
        }
      );

      packages = forAll (pkgs: {
        pulse-test = mkRunner pkgs;
      });
    };
}
