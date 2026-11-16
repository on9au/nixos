{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    # gdbus, for config/scripts/kdeconnect.sh.
    glib
    # For config/scripts/privacy.sh.
    jq
    waybar
  ];

  xdg.configFile."waybar".source = config.lib.dotfiles.link ./config;
}
