{config, ...}: {
  xdg.configFile."borders".source = config.lib.dotfiles.link ./config;
}
