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

    services.pipewire.wireplumber.extraConfig."51-apple-dongle"."monitor.alsa.rules" = [{
      matches = [{ "device.name" = "alsa_card.usb-Apple__Inc._USB-C_to_3.5mm_Headphone_Jack_Adapter_DWH5373010Z2FN3AQ-00"; }];
      actions.update-props = {
        "device.profile" = "pro-audio";
        "api.alsa.period-size" = 64;
        "api.alsa.period-num" = 3;
        "audio.rate" = 48000;
      };
    } {
      # Period size and rate are read from the nodes, not the device.
      matches = [{ "node.name" = "~alsa_.*\\.usb-Apple__Inc\\._USB-C_to_3\\.5mm_Headphone_Jack_Adapter_DWH5373010Z2FN3AQ-00\\..*"; }];
      actions.update-props = {
        "api.alsa.period-size" = 64;
        "api.alsa.period-num" = 3;
        "audio.rate" = 48000;
      };
    }];
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
      # Don't export GTK_IM_MODULE/QT_IM_MODULE; Wayland apps use text-input-v3 (see uwsm/env).
      fcitx5.waylandFrontend = true;
      # Default groups for a fresh ~/.config/fcitx5/profile.
      fcitx5.settings.inputMethod = {
        GroupOrder."0" = "Default";
        "Groups/0" = {
          Name = "Default";
          "Default Layout" = "us";
          DefaultIM = "pinyin";
        };
        "Groups/0/Items/0".Name = "keyboard-us";
        "Groups/0/Items/1".Name = "pinyin";
        "Groups/0/Items/2".Name = "mozc";
      };
    };

    programs.kdeconnect.enable = true;

    services.power-profiles-daemon.enable = true;

    # Caps Lock: Ctrl held, Esc tapped; Shift+Caps is a real Caps Lock.
    services.keyd = {
      enable = true;
      keyboards.default = {
        ids = [ "*" ];
        settings = {
          main.capslock = "overload(control, esc)";
          shift.capslock = "capslock";
        };
      };
    };

    hardware.bluetooth.enable = true;
    services.blueman.enable = true;

    services.printing = {
      enable = true;
      drivers = with pkgs; [ gutenprint foomatic-db-ppds ];
    };
    programs.system-config-printer.enable = true;
    # Network printers, AirPlay and .local names.
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    hardware.opentabletdriver.enable = true;

    # Yubico Authenticator's OATH codes go over CCID; FIDO2 ssh keys don't need this.
    services.pcscd.enable = true;

    services.tailscale.enable = true;
    services.mullvad-vpn = {
      enable = true;
      gui.enable = true;
    };

    # Spotify Connect local discovery.
    networking.firewall.allowedTCPPorts = [ 57621 ];

    fonts.packages = with pkgs; [ nerd-fonts.fira-code noto-fonts-color-emoji noto-fonts-cjk-sans noto-fonts-cjk-serif ];
  };
}
