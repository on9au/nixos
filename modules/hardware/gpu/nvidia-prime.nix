{pkgs, ...}: {
  imports = [
    ./graphics.nix
  ];

  services.xserver.videoDrivers = ["modesetting" "nvidia"];

  hardware.nvidia = {
    # Blackwell needs the open kernel modules.
    open = true;
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = true;

    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
    };
  };

  environment.systemPackages = [
    # Arch's name for nvidia-offload, used in uwsm/env and the README.
    (pkgs.writeShellScriptBin "prime-run" ''exec nvidia-offload "$@"'')
  ];
}
