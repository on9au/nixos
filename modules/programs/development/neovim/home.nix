{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    fd
    lazygit
    neovim
    ripgrep
    sqlite
    tree-sitter
  ];

  xdg.configFile = {
    "mermaid".source = config.lib.dotfiles.link ./mermaid;
    "nvim".source = config.lib.dotfiles.link ./config;
  };
}
