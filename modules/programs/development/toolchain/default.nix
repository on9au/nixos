{pkgs, ...}: {
  # Not home.packages: gcc and clang both provide `cc`, which collides there.
  environment.systemPackages = with pkgs; [
    clang
    gcc
    gnumake
  ];

  homeManagerModules = [
    ./home.nix
  ];
}
