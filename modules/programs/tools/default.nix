{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    curl
    git
    pciutils
    usbutils
    vim
    wget
  ];

  homeManagerModules = [
    ./home.nix
  ];
}
