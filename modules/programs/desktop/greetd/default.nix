{
  config,
  lib,
  pkgs,
  ...
}: let
  greeterConfig = pkgs.replaceVars ./hyprland.lua {
    regreet = "${config.services.displayManager.regreet.package}/bin/regreet";
  };
in {
  services.displayManager.regreet = {
    enable = true;

    font = {
      name = "Noto Sans";
      size = 12;
    };

    settings = {
      background = lib.mkIf (config.greeterWallpaper != null) {
        fit = "Cover";
        path = config.greeterWallpaper;
      };
      commands = {
        poweroff = ["systemctl" "poweroff"];
        reboot = ["systemctl" "reboot"];
      };
      GTK.application_prefer_dark_theme = true;
    };

    cursorTheme = {
      name = "Posy_Cursor_Black";
      package = pkgs.posy-cursors;
    };
  };

  services.greetd.settings.default_session.command =
    lib.mkForce "${pkgs.hyprland}/bin/Hyprland --config ${greeterConfig}";
}
