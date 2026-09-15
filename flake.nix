{
  description = "Live WezTerm session tree and asynchronous provider pickers";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs =
    { self, nixpkgs }:
    let
      each = nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
    in
    {
      packages = each (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          runner = pkgs.writeShellApplication {
            name = "wezterm-picker-call";
            text = ''exec ${pkgs.python3}/bin/python3 ${./scripts/picker-call.py} "$@"'';
          };
          default = pkgs.runCommand "session-tree-wezterm" { } "mkdir -p $out; cp -r ${./plugin} $out/plugin";
        }
      );
      checks = each (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          native = pkgs.runCommand "session-tree-native" { nativeBuildInputs = [ pkgs.wezterm ]; } ''
            export HOME="$TMPDIR/home"
            mkdir -p "$HOME"
            export SESSION_TREE_SOURCE=${self}
            wezterm --config-file ${./tests/native.lua} show-keys --lua > keys.lua 2> startup.log
            cat startup.log
            if grep -E 'ERROR|Error|Cloned https' startup.log; then exit 1; fi
            touch $out
          '';
          provider =
            pkgs.runCommand "session-tree-provider-tests" { nativeBuildInputs = [ pkgs.python3 ]; }
              ''
                python3 -m unittest discover -s ${self}/tests -p 'test_*.py'
                touch $out
              '';
          catalog = pkgs.runCommand "session-tree-catalog" { nativeBuildInputs = [ pkgs.lua5_4 ]; } ''
            lua ${./tests/catalog.lua} ${./plugin}
            touch $out
          '';
        }
      );
      devShells = each (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.lua5_4
              pkgs.stylua
              pkgs.nixfmt
              pkgs.python3
              pkgs.wezterm
            ];
          };
        }
      );
      formatter = each (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
