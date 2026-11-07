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

    # TEMP(nixpkgs#557063): nixpkgs builds regreet without glycin's loaders, so
    # the wallpaper fails to load as an image and regreet plays it as a looping
    # video instead. GStreamer leaks an fd per loop; at greetd's 1024 limit the
    # greeter hangs. glycin also needs the MIME database to identify the file,
    # which the greeter's environment may lack.
    package = assert lib.assertMsg (!lib.elem pkgs.glycin-loaders pkgs.regreet.buildInputs)
    "TEMP: nixpkgs' regreet has glycin-loaders now; drop the package override in programs/desktop/greetd/default.nix";
      pkgs.regreet.overrideAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [pkgs.libglycin.patchVendorHook];
        buildInputs = old.buildInputs ++ [pkgs.glycin-loaders pkgs.libglycin.setupHook];
        preFixup =
          (old.preFixup or "")
          + ''
            gappsWrapperArgs+=(--prefix XDG_DATA_DIRS : "${pkgs.shared-mime-info}/share")
          '';
      });

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
