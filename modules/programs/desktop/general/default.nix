{
  inputs,
  pkgs,
  ...
}: {
  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };

  homeManagerModules = [
    ./home.nix
    inputs.betterfox-nix.homeModules.betterfox
  ];
}
