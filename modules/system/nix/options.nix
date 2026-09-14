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
}
