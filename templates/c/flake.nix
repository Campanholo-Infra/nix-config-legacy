{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-darwin"
      ];
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages =
              with pkgs;
              [
                cmake
                pkg-config
                clang-tools
              ]
              # On aarch64-darwin nixpkgs' gdb only debugs x86_64 programs; macOS has lldb.
              ++ lib.optional stdenv.hostPlatform.isLinux gdb;
            # clangd reads build/compile_commands.json.
            env.CMAKE_EXPORT_COMPILE_COMMANDS = "ON";
          };
        }
      );
    };
}
