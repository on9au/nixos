{config, ...}: {
  # The directory, not karabiner.json: Karabiner replaces the file on save.
  xdg.configFile."karabiner".source = config.lib.dotfiles.link ./config;
}
