{
  config,
  pkgs,
  ...
}: {
  # `:checkhealth` warns about `norg` forever: Snacks checks for a parser
  # nvim-treesitter doesn't have.
  home.packages = with pkgs; [
    # Pickers' file search.
    fd
    # Snacks.lazygit.
    lazygit
    neovim
    # Pickers' grep.
    ripgrep
    # sqlite3, for config/autocmds.lua.
    sqlite
    # The CLI nvim-treesitter builds parsers with, not the library nvim links.
    tree-sitter
  ];

  home.sessionVariables.MANPAGER = "nvim +Man!";

  xdg.configFile = {
    "mermaid".source = config.lib.dotfiles.link ./mermaid;
    "nvim".source = config.lib.dotfiles.link ./config;
  };
}
