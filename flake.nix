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
            runtimeInputs = [ pkgs.coreutils ];
            text = ''exec ${pkgs.nushell}/bin/nu --no-config-file ${./scripts/picker-call.nu} "$@"'';
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
            pkgs.runCommand "session-tree-provider-tests" { nativeBuildInputs = [ pkgs.nushell pkgs.coreutils ]; }
              ''
                nu --no-config-file ${./tests/provider.nu} ${./scripts/picker-call.nu} ${./tests/provider-fixture.nu}
                touch $out
              '';
          catalog = pkgs.runCommand "session-tree-catalog" { nativeBuildInputs = [ pkgs.lua5_4 ]; } ''
            lua ${./tests/catalog.lua} ${./plugin}
            lua ${./tests/switcher.lua} ${./plugin}
            lua ${./tests/popup.lua} ${./plugin}
            lua ${./tests/tree.lua} ${./plugin}
            lua ${./tests/sessions.lua} ${./plugin}
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
              pkgs.nushell
              pkgs.nufmt
              pkgs.coreutils
              pkgs.wezterm
            ];
          };
        }
      );
      formatter = each (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
