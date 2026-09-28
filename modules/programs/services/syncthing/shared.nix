# What every Syncthing device in this repo agrees on. Read by home.nix (desktop,
# laptop, Mac) and programs/server/syncthing.nix (jia).
#
# Device IDs aren't secret: global discovery and relays are off, so devices
# only find each other by Tailscale name or on the LAN, and a connection still
# needs both sides to list each other.
{lib}: let
  # null until the device has generated its identity, and left out of every
  # config until then. `syncthing device-id`, or Actions → Show ID in the GUI.
  devices = {
    DESKTOP-DYLAN = "P6LPAYV-7O3C5G6-GKO2KR3-ADUIW73-ZEG4WU7-RHT4RKI-ZPH7JPA-6BT3OAA";
    jia-opena0 = "AHJ7HAM-LHYYFTU-3FVFJEK-7SFRZRR-TS6CQFR-M7FBDBS-LVYBNWD-TXL3JQC";
  };
in {
  # Folder ID = directory under ~ on personal devices.
  folders = {
    documents = "Documents";
    pictures = "Pictures";
    videos = "Videos";
  };

  options = {
    globalAnnounceEnabled = false;
    natEnabled = false;
    relaysEnabled = false;
    urAccepted = -1;
  };

  # Every other device with an ID, as `settings.devices`.
  peersOf = self:
    lib.mapAttrs (name: id: {
      id = id;
      addresses = ["tcp://${lib.toLower name}.tailc7b8fd.ts.net:22000"];
    }) (lib.filterAttrs (name: id: id != null && name != self) devices);
}
