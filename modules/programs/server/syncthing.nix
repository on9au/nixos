# The always-on Syncthing device: a member of every folder, so the others sync
# through it when they're never online together. Its copies are backed up by
# the homelab's restic job, mounted as /data/syncthing.
{lib, ...}: let
  shared = import ../services/syncthing/shared.nix {lib = lib;};
in {
  services.syncthing = {
    enable = true;
    dataDir = "/var/lib/syncthing";
    openDefaultPorts = true;
    settings = {
      options = shared.options;
      devices = shared.peersOf "jia-opena0";
      folders =
        lib.mapAttrs (id: folder: {
          path = "/var/lib/syncthing/${id}";
          devices = folder.peers;
          ignorePatterns = shared.ignorePatterns;
          # Only the phone writes its backups; jia never sends changes back.
          type =
            if id == "phone-backup"
            then "receiveonly"
            else "sendreceive";
          # Sync propagates deletes; this keeps what another device removed or
          # overwrote for 90 days. restic's history covers anything older.
          versioning = {
            type = "staggered";
            params.maxAge = toString (90 * 24 * 60 * 60);
          };
        })
        (shared.foldersOf "jia-opena0");
    };
  };

  # Like the containers: an empty box would sync nothing into the folders
  # others rely on. syncthing-init needs it too, or it waits on an API that
  # never starts.
  systemd.services.syncthing.unitConfig.ConditionPathExists = "/var/lib/homelab/.restored";
  systemd.services.syncthing-init.unitConfig.ConditionPathExists = "/var/lib/homelab/.restored";
}
