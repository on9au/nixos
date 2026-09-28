# The always-on Syncthing device: a member of every folder, so the others sync
# through it when they're never online together. Its copies are backed up by
# the homelab's restic job, mounted as /data/syncthing.
{lib, ...}: let
  shared = import ../services/syncthing/shared.nix {lib = lib;};
  peers = shared.peersOf "jia-opena0";
in {
  services.syncthing = {
    enable = true;
    dataDir = "/var/lib/syncthing";
    openDefaultPorts = true;
    settings = {
      options = shared.options;
      devices = peers;
      folders =
        lib.mapAttrs (id: dir: {
          path = "/var/lib/syncthing/${id}";
          devices = lib.attrNames peers;
          # Sync propagates deletes; this keeps what another device removed or
          # overwrote for 90 days. restic's history covers anything older.
          versioning = {
            type = "staggered";
            params.maxAge = toString (90 * 24 * 60 * 60);
          };
        })
        shared.folders;
    };
  };

  # Like the containers: an empty box would sync nothing into the folders
  # others rely on. syncthing-init needs it too, or it waits on an API that
  # never starts.
  systemd.services.syncthing.unitConfig.ConditionPathExists = "/var/lib/homelab/.restored";
  systemd.services.syncthing-init.unitConfig.ConditionPathExists = "/var/lib/homelab/.restored";
}
