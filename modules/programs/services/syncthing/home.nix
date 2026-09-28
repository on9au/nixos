{
  config,
  lib,
  osConfig,
  ...
}: let
  shared = import ./shared.nix {lib = lib;};
  peers = shared.peersOf osConfig.networking.hostName;
in {
  services.syncthing = {
    enable = true;
    settings = {
      options = shared.options;
      devices = peers;
      folders =
        lib.mapAttrs (_: dir: {
          path = "${config.home.homeDirectory}/${dir}";
          devices = lib.attrNames peers;
        })
        shared.folders;
    };
  };
}
