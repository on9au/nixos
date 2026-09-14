{config, ...}: {
  xdg.configFile."winapps".source = config.lib.dotfiles.link ./config;
}
