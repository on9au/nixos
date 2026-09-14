{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    fuzzel
  ];

  xdg.configFile."fuzzel".source = config.lib.dotfiles.link ./config;
}
