{
  lib,
  pkgs,
  ...
}: {
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  programs.hyprlock.enable = true;
  # config/hypr/autostart.lua starts hypridle; programs.hyprlock enables the unit
  # too. Two copies race on every lock, and the hyprlock that loses never exits,
  # so `pidof hyprlock` in lock_cmd stays true and later locks do nothing.
  services.hypridle.enable = lib.mkForce false;

  security.polkit.enable = true;

  environment.systemPackages = with pkgs; [
    # autostart.lua starts it as a user unit; units from home.packages aren't linked.
    hyprpolkitagent
  ];

  homeManagerModules = [
    ./home.nix
  ];
}
