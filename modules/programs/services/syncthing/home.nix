{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}: let
  shared = import ./shared.nix {lib = lib;};
  hostName = osConfig.networking.hostName;
in {
  services.syncthing = {
    enable = true;
    settings = {
      options = shared.options;
      devices = shared.peersOf hostName;
      folders =
        lib.mapAttrs (_: folder: {
          path = "${config.home.homeDirectory}/${
            if pkgs.stdenv.hostPlatform.isDarwin
            then folder.darwinDir or folder.dir
            else folder.dir
          }";
          devices = folder.peers;
          ignorePatterns = shared.ignorePatterns;
        })
        (shared.foldersOf hostName);
    };
  };
}
