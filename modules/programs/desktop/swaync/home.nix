{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    swaynotificationcenter
  ];

  # No "volume" widget in config.json: 0.12.6's binds to a sink at startup and
  # ignores later default-sink changes, so it controlled the wrong output.
  # Volume lives in waybar.
  xdg.configFile."swaync".source = config.lib.dotfiles.link ./config;
}
