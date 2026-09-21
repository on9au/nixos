{pkgs, ...}: {
  home.packages = with pkgs; [
    luau # `luau` and `luau-analyze` for Luau outside a project
    luau-lsp # language server; the nvim side is plugins/luau.lua
    rojo # syncs the source tree into Studio, and writes sourcemap.json
    selene # linter
  ];
}
