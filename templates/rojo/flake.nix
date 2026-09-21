{
  description = "Roblox project — Rojo and the Luau toolchain";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {nixpkgs, ...}: let
    forEachSystem = f:
      nixpkgs.lib.genAttrs ["aarch64-darwin" "x86_64-linux"]
      (system: f nixpkgs.legacyPackages.${system});
  in {
    devShells = forEachSystem (pkgs: {
      default = pkgs.mkShell {
        packages = with pkgs;
          [
            luau # `luau` and `luau-analyze`
            luau-lsp # language server, and `luau-lsp analyze` in CI
            lune # Luau runtime for build and test scripts
            rojo # `rojo serve` to sync into Studio, `rojo build` for an .rbxl
            selene # linter
            stylua # formatter
          ]
          # No darwin build in nixpkgs.
          ++ lib.optional stdenv.hostPlatform.isLinux wally;
      };
    });
  };
}
