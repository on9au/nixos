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
    xrdb
  ];

  # XCURSOR_THEME in hypr/env.lua only reaches X11 clients that inherit it.
  # This adds what the rest fall back to: a `default` theme in ~/.icons, the
  # Xcursor.* resources (loaded by hypr/autostart.lua) and the GTK setting.
  home.pointerCursor = {
    enable = true;
    name = "Posy_Cursor_Black";
    package = pkgs.posy-cursors;
    size = 32;
    gtk.enable = true;
    x11.enable = true;
  };

  xdg.configFile = {
    "hypr".source = link ./config/hypr;
    "uwsm".source = link ./config/uwsm;
    "xdg-desktop-portal".source = link ./config/xdg-desktop-portal;
  };

  home.file = lib.listToAttrs (map
    (name: lib.nameValuePair ".local/bin/${name}" {source = link (./bin + "/${name}");})
    ["cliphist-store" "colorpicker" "emoji" "nolock" "powermenu"]);

  # Discord and Steam recreate these when their launch-on-startup toggle is
  # used; uwsm would start a second copy alongside hypr/hosts/*/autostart.lua.
  home.activation.removeDuplicateAutostart = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run rm -f $VERBOSE_ARG \
      "${config.xdg.configHome}/autostart/discord.desktop" \
      "${config.xdg.configHome}/autostart/steam.desktop"
  '';
}
