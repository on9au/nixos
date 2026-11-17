{lib, ...}: {
  options.primaryUser = lib.mkOption {
    type = lib.types.str;
  };

  options.greeterWallpaper = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
  };

  options.homeManagerModules = lib.mkOption {
    type = lib.types.listOf lib.types.deferredModule;
    default = [];
  };

  # btrfs subvolumes programs/services/backup.nix snapshots and uploads.
  options.backupSubvolumes = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
  };

  # Run by that backup just before it takes the snapshots.
  options.backupPrepare = lib.mkOption {
    type = lib.types.lines;
    default = "";
  };
}
