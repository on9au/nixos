{config, ...}: {
  xdg.configFile."aerospace".source = config.lib.dotfiles.link ./config;
}
