{config, ...}: {
  xdg.configFile."sketchybar".source = config.lib.dotfiles.link ./config;
}
