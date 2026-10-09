{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    brave
  ];

  homeManagerModules = [./home.nix];
}
