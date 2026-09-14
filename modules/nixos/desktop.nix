# Hyprland desktop shared by DESKTOP-DYLAN and LAPTOP-ON9AU.
{ config, lib, pkgs, ... }:

let
  cfg = config.desktop;

  greeterConfig = pkgs.replaceVars ./greetd/hyprland.lua {
    regreet = "${config.services.displayManager.regreet.package}/bin/regreet";
  };
in
{
  imports = [ ./common.nix ];

  options.desktop.greeterWallpaper = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
  };

  config = {
    unfree.allow = [ "posy-cursors" "discord" "discord-unwrapped" "spotify" ];

    home-manager.users.djpro.imports = [ ../../home/desktop.nix ];

    users.users.djpro.extraGroups = [ "networkmanager" ];
    networking.networkmanager.enable = true;

    hardware.graphics.enable = true;
    hardware.graphics.enable32Bit = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
    security.rtkit.enable = true;

    programs.hyprland.enable = true;
    programs.hyprland.withUWSM = true;

    xdg.portal.enable = true;
    xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

    programs.hyprlock.enable = true;
    # Not services.hypridle: hypr/autostart.lua starts it, and both ran two copies.

    security.polkit.enable = true;

    environment.systemPackages = with pkgs; [
      # autostart.lua starts it as a user unit; units from home.packages aren't linked.
      hyprpolkitagent
      # uwsm/env finds the askpass helper with `command -v`; seahorse keeps it in libexec.
      (pkgs.writeShellScriptBin "ssh-askpass" ''exec ${pkgs.seahorse}/libexec/seahorse/ssh-askpass "$@"'')
    ];

    # Settings portal and gtk.* in home/desktop.nix read dconf.
    programs.dconf.enable = true;

    services.displayManager.regreet = {
      enable = true;

      font = { name = "Noto Sans"; size = 12; };

      settings = {
        background = lib.mkIf (cfg.greeterWallpaper != null) {
          path = cfg.greeterWallpaper;
          fit = "Cover";
        };
        GTK = {
          application_prefer_dark_theme = true;
        };
        commands = {
          reboot = [ "systemctl" "reboot" ];
          poweroff = [ "systemctl" "poweroff" ];
        };
      };

      cursorTheme = {
        package = pkgs.posy-cursors;
        name = "Posy_Cursor_Black";
      };
    };

    services.greetd.settings.default_session.command = lib.mkForce
      "${pkgs.hyprland}/bin/Hyprland --config ${greeterConfig}";

    services.gnome.gnome-keyring.enable = true;
    security.pam.services.greetd.enableGnomeKeyring = true;
    # Re-key the keyring when the login password changes.
    security.pam.services.passwd.enableGnomeKeyring = true;
    # No FIDO2 support; OpenSSH's agent below holds the YubiKey keys.
    services.gnome.gcr-ssh-agent.enable = false;

    programs.ssh = {
      startAgent = true;
      enableAskPassword = true;
      askPassword = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";
    };

    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.addons = with pkgs; [ fcitx5-mozc qt6Packages.fcitx5-chinese-addons fcitx5-gtk ];
    };

    programs.kdeconnect.enable = true;

    services.power-profiles-daemon.enable = true;

    fonts.packages = with pkgs; [ nerd-fonts.fira-code noto-fonts-color-emoji noto-fonts-cjk-sans noto-fonts-cjk-serif ];
  };
}
