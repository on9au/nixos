# What every Syncthing device in this repo agrees on. Read by home.nix (desktop,
# laptop, Mac) and programs/server/syncthing.nix (jia).
#
# Device IDs aren't secret: global discovery and relays are off, so devices
# only find each other by Tailscale name or on the LAN, and a connection still
# needs both sides to list each other.
{lib}: let
  # Keyed by networking.hostName, or the Tailscale name for the phone. null
  # until the device has generated its identity, and left out of every config
  # until then. `syncthing device-id`, or Actions → Show ID in the GUI.
  devices = {
    DESKTOP-DYLAN = "P6LPAYV-7O3C5G6-GKO2KR3-ADUIW73-ZEG4WU7-RHT4RKI-ZPH7JPA-6BT3OAA";
    jia-opena0 = "AHJ7HAM-LHYYFTU-3FVFJEK-7SFRZRR-TS6CQFR-M7FBDBS-LVYBNWD-TXL3JQC";
    LAPTOP-ON9AU = null;
    MBP-DYLAN = "6QM6RNS-VAAUGR7-2RSERXG-DDQGL5A-U25FHT5-YNQ6HA2-3XSEJ77-662OZQU";
    oneplus-cph2653 = "GEU4R4Y-XRZXBRG-2UUOJDK-PI7SGBQ-YWM6CVT-3PIMEUU-QECDH7Q-3OQJYQ2";
  };

  computers = ["DESKTOP-DYLAN" "jia-opena0" "LAPTOP-ON9AU" "MBP-DYLAN"];

  # dir is the directory under ~ on personal devices; darwinDir where macOS
  # names it differently.
  folders = {
    documents = {
      dir = "Documents";
      devices = computers;
    };
    pictures = {
      dir = "Pictures";
      devices = computers;
    };
    videos = {
      dir = "Videos";
      darwinDir = "Movies";
      devices = computers;
    };
    # Neo Backup's archives. Only jia keeps a copy.
    phone-backup.devices = ["jia-opena0" "oneplus-cph2653"];
  };

  hasId = name: devices.${name} != null;

  # The folders `self` is in that have a peer with an ID, `peers` naming them.
  foldersOf = self:
    lib.filterAttrs (_: folder: folder.peers != []) (
      lib.mapAttrs (_: folder:
        folder
        // {
          peers = lib.filter (name: name != self && hasId name) folder.devices;
        })
      (lib.filterAttrs (_: folder: lib.elem self folder.devices) folders)
    );
in {
  foldersOf = foldersOf;

  # On every folder of every device this repo manages.
  ignorePatterns = [
    "(?d).DS_Store"
    # Apple Photos keeps its library in ~/Pictures: a database, not files to sync.
    "Photos Library.photoslibrary"
  ];

  options = {
    globalAnnounceEnabled = false;
    natEnabled = false;
    relaysEnabled = false;
    urAccepted = -1;
  };

  # The devices `self` shares a folder with, as `settings.devices`.
  peersOf = self:
    lib.genAttrs (lib.unique (lib.concatMap (folder: folder.peers) (lib.attrValues (foldersOf self)))) (name: {
      id = devices.${name};
      addresses = ["tcp://${lib.toLower name}.tailc7b8fd.ts.net:22000"];
    });
}
