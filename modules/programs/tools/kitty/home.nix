{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    kitty
  ];

  xdg.configFile."kitty".source = config.lib.dotfiles.link ./config;
}
