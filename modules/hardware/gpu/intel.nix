{pkgs, ...}: {
  imports = [
    ./graphics.nix
  ];

  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
  ];
}
