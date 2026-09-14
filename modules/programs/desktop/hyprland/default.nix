{pkgs, ...}: {
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  programs.hyprlock.enable = true;
  # Not services.hypridle: config/hypr/autostart.lua starts it, and both ran two copies.

  security.polkit.enable = true;

  environment.systemPackages = with pkgs; [
    # autostart.lua starts it as a user unit; units from home.packages aren't linked.
    hyprpolkitagent
  ];

  homeManagerModules = [
    ./home.nix
  ];
}
