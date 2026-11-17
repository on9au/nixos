# The monitors' USB hub, a Microchip USB7206: 0424:4206 is its USB 2 side and
# 0424:7206 its USB 3 side. Behind it are the keyboard, mouse, webcam, the IEMs'
# adapter, a YubiKey and the monitor's Ethernet port (unused; the network is
# enp8s0). While monitor-usb-off runs, all of it is cut off; server mode
# (programs/desktop/hyprland/bin/server-mode) starts and stops it.
{
  config,
  lib,
  pkgs,
  ...
}: let
  hubs = ["0424:4206" "0424:7206"];

  # By ID rather than port path, which changes with the socket the cable is in.
  # Deauthorising a hub drops everything below it, and authorising it again
  # enumerates them afresh.
  authorize = value:
    pkgs.writeShellScript "monitor-usb-authorize-${value}" ''
      for d in /sys/bus/usb/devices/*; do
        [ -e "$d/idVendor" ] || continue
        case "$(cat "$d/idVendor"):$(cat "$d/idProduct")" in
        ${lib.concatStringsSep "|" hubs}) echo ${value} >"$d/authorized" ;;
        esac
      done
    '';
in {
  systemd.services.monitor-usb-off = {
    description = "The monitors' USB hub, cut off";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = authorize "0";
      ExecStop = authorize "1";
    };
  };

  # server-mode runs as the user.
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "monitor-usb-off.service" &&
          subject.user == "${config.primaryUser}") {
        return polkit.Result.YES;
      }
    });
  '';
}
