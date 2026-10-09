{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    curl
    git
    pciutils
    usbutils
    vim
    wget
  ];

  # The index behind `apropos` and `man -k`.
  documentation.man.cache.enable = true;

  homeManagerModules = [
    ./home.nix
  ];
}
