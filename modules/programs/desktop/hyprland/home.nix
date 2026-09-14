{
  config,
  lib,
  pkgs,
  ...
}: let
  link = config.lib.dotfiles.link;
in {
  home.packages = with pkgs; [
    awww
    bemoji
    brightnessctl
    cliphist
    htop
    hypridle
    hyprpicker
    hyprshot
    pavucontrol
    playerctl
    wtype
  ];

  xdg.configFile = {
    "hypr".source = link ./config/hypr;
    "uwsm".source = link ./config/uwsm;
    "xdg-desktop-portal".source = link ./config/xdg-desktop-portal;
  };

  home.file = lib.listToAttrs (map
    (name: lib.nameValuePair ".local/bin/${name}" {source = link (./bin + "/${name}");})
    ["colorpicker" "emoji" "nolock" "powermenu"]);

  # Discord and Steam recreate these when their launch-on-startup toggle is
  # used; uwsm would start a second copy alongside hypr/hosts/*/autostart.lua.
  home.activation.removeDuplicateAutostart = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run rm -f $VERBOSE_ARG \
      "${config.xdg.configHome}/autostart/discord.desktop" \
      "${config.xdg.configHome}/autostart/steam.desktop"
  '';
}
